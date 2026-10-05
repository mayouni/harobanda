// court.zig -- the fixture court. Reads declarative/machine/fixtures.json
// (pinned in PINNING.md beside it) and judges machine.zig + plan.zig
// against every case. Accepts carry structural expectations (identity,
// counts, service order, granted set, and for some the folded rationale);
// rejects carry the fragment the refusal must contain, so refusing for
// the wrong reason fails. Prints the scoreboard; returns the number of
// failures (0 = conforming).

const std = @import("std");
const machine = @import("machine.zig");
const plan = @import("plan.zig");
const fleet = @import("fleet.zig");
const pack = @import("pack.zig");

fn str(v: ?std.json.Value) ?[]const u8 {
    if (v) |x| return switch (x) {
        .string => |s| s,
        else => null,
    };
    return null;
}

fn int(v: ?std.json.Value) ?i64 {
    if (v) |x| return switch (x) {
        .integer => |i| i,
        else => null,
    };
    return null;
}

fn sameList(got: []const []const u8, want: std.json.Array) bool {
    if (got.len != want.items.len) return false;
    for (got, want.items) |g, w| {
        const ws = str(w) orelse return false;
        if (!std.mem.eql(u8, g, ws)) return false;
    }
    return true;
}

/// THE PIN IS A CLAIM, SO THE COURT JUDGES IT (PIN-1).
///
/// PINNING.md beside the fixtures says which fixtures.json these verdicts
/// are about, by sha256, and the rule since the grammar was born is to
/// re-pin in the same commit that changes the file. Nothing checked it:
/// a pin nobody reads is a verdict nobody receives. On 2026-09-20 a
/// rename changed one fixture and not the pin, and six days of green
/// courts were about a file the pin did not name.
///
/// The current pin is the first 64-hex run after "sha256:" -- the older
/// digests below it are history, kept for the record and never compared.
fn pinHolds(gpa: std.mem.Allocator, fixtures_path: []const u8, bytes: []const u8, out: *std.Io.Writer) !bool {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    var got: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&got, "{x}", .{&digest}) catch unreachable;

    const dir = std.fs.path.dirname(fixtures_path) orelse ".";
    const pin_path = try std.fmt.allocPrint(gpa, "{s}/PINNING.md", .{dir});
    defer gpa.free(pin_path);
    const text = std.fs.cwd().readFileAlloc(gpa, pin_path, 1 << 20) catch {
        try out.print("  FAIL pin -- {s} cannot be read: fixtures with no pin are verdicts about no particular file\n", .{pin_path});
        return false;
    };
    defer gpa.free(text);

    const at = std.mem.indexOf(u8, text, "sha256:") orelse {
        try out.print("  FAIL pin -- {s} names no sha256\n", .{pin_path});
        return false;
    };
    var i = at;
    var streak: usize = 0;
    while (i < text.len) : (i += 1) {
        const hex = switch (text[i]) {
            '0'...'9', 'a'...'f' => true,
            else => false,
        };
        streak = if (hex) streak + 1 else 0;
        if (streak == 64) break;
    }
    if (streak != 64) {
        try out.print("  FAIL pin -- {s} says sha256: and gives no digest after it\n", .{pin_path});
        return false;
    }
    const pinned = text[i + 1 - 64 .. i + 1];
    if (!std.mem.eql(u8, pinned, &got)) {
        try out.print("  FAIL pin -- {s} hashes to {s}, and {s} pins {s}: the fixtures changed and the pin did not, or the other way round -- re-pin in the commit that changes either\n", .{ fixtures_path, got[0..16], pin_path, pinned[0..16] });
        return false;
    }
    try out.print("  ok   pin -- {s} is the file {s} names (sha256 {s})\n", .{ fixtures_path, pin_path, got[0..16] });
    return true;
}

fn showList(out: *std.Io.Writer, l: []const []const u8) !void {
    try out.print("[", .{});
    for (l, 0..) |s, i| try out.print("{s}{s}", .{ if (i > 0) ", " else "", s });
    try out.print("]", .{});
}

pub fn run(gpa: std.mem.Allocator, fixtures_path: []const u8, out: *std.Io.Writer) !usize {
    const bytes = try std.fs.cwd().readFileAlloc(gpa, fixtures_path, 1 << 22);
    defer gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(std.json.Value, gpa, bytes, .{});
    defer parsed.deinit();
    const root = parsed.value.object;

    const grammar = str(root.get("grammar")) orelse return error.BadFixtureFile;
    const version = str(root.get("version")) orelse return error.BadFixtureFile;
    if (!std.mem.eql(u8, grammar, "machine")) return error.BadFixtureFile;
    try out.print("machine conformance -- grammar {s} v{s}, judged by {s}\n", .{ grammar, version, fixtures_path });
    const pin_ok = try pinHolds(gpa, fixtures_path, bytes, out);

    var failures: usize = 0;
    var total: usize = 0;

    const accepts = root.get("accepts").?.array;
    for (accepts.items) |case_v| {
        total += 1;
        const case = case_v.object;
        const id = str(case.get("id")).?;
        const name = str(case.get("name")).?;
        const source = str(case.get("source")).?;
        const expect = case.get("expect").?.object;

        var arena_state = std.heap.ArenaAllocator.init(gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        var refusal = machine.Refusal{};
        const m = machine.declare(arena, source, &refusal) catch |e| {
            failures += 1;
            try out.print("  FAIL {s} {s} -- refused: machine (line {d}): {s} [{s}]\n", .{ id, name, refusal.line, refusal.message, @errorName(e) });
            continue;
        };
        const p = try plan.derive(arena, &m);

        var why: ?[]const u8 = null;
        if (str(expect.get("name"))) |w| if (!std.mem.eql(u8, m.name, w)) {
            why = try std.fmt.allocPrint(arena, "name: expected {s} got {s}", .{ w, m.name });
        };
        if (str(expect.get("profile"))) |w| if (!std.mem.eql(u8, @tagName(m.profile), w)) {
            why = try std.fmt.allocPrint(arena, "profile: expected {s} got {s}", .{ w, @tagName(m.profile) });
        };
        if (str(expect.get("arch"))) |w| if (!std.mem.eql(u8, @tagName(m.arch), w)) {
            why = try std.fmt.allocPrint(arena, "arch: expected {s} got {s}", .{ w, @tagName(m.arch) });
        };
        if (str(expect.get("kernel"))) |w| if (!std.mem.eql(u8, @tagName(m.kernel), w)) {
            why = try std.fmt.allocPrint(arena, "kernel: expected {s} got {s}", .{ w, @tagName(m.kernel) });
        };
        if (str(expect.get("libc"))) |w| if (!std.mem.eql(u8, @tagName(m.libc), w)) {
            why = try std.fmt.allocPrint(arena, "libc: expected {s} got {s}", .{ w, @tagName(m.libc) });
        };
        if (str(expect.get("board"))) |w| if (!std.mem.eql(u8, @tagName(m.board), w)) {
            why = try std.fmt.allocPrint(arena, "board: expected {s} got {s}", .{ w, @tagName(m.board) });
        };
        if (str(expect.get("slots"))) |w| if (m.slots == null or !std.mem.eql(u8, m.slots.?, w)) {
            why = try std.fmt.allocPrint(arena, "slots: expected {s} got {s}", .{ w, m.slots orelse "none" });
        };
        if (expect.get("forward")) |fv| if (fv == .bool and fv.bool != m.forward) {
            why = try std.fmt.allocPrint(arena, "forward: expected {} got {}", .{ fv.bool, m.forward });
        };
        if (str(expect.get("console"))) |w| if (!std.mem.eql(u8, m.console, w)) {
            why = try std.fmt.allocPrint(arena, "console: expected {s} got {s}", .{ w, m.console });
        };
        if (str(expect.get("rationale"))) |w| if (!std.mem.eql(u8, m.rationale, w)) {
            why = try std.fmt.allocPrint(arena, "rationale: expected '{s}' got '{s}'", .{ w, m.rationale });
        };
        if (expect.get("counts")) |cv| {
            const c = cv.object;
            const got = [_]struct { k: []const u8, n: usize }{
                .{ .k = "services", .n = m.services.len },
                .{ .k = "capabilities", .n = m.capabilities.len },
                .{ .k = "mounts", .n = m.mounts.len },
                .{ .k = "pins", .n = m.pins.len },
                .{ .k = "networks", .n = m.networks.len },
                .{ .k = "users", .n = m.users.len },
            };
            for (got) |g| if (int(c.get(g.k))) |w| if (@as(i64, @intCast(g.n)) != w) {
                why = try std.fmt.allocPrint(arena, "{s}: expected {d} got {d}", .{ g.k, w, g.n });
            };
        }
        if (expect.get("order")) |ov| {
            const got = try p.order(arena);
            if (!sameList(got, ov.array)) why = try std.fmt.allocPrint(arena, "order differs (got {d} services)", .{got.len});
        }
        if (expect.get("granted")) |gv| {
            const got = try p.granted(arena);
            if (!sameList(got, gv.array)) why = try std.fmt.allocPrint(arena, "granted set differs (got {d})", .{got.len});
        }
        // the directories each named world owns (OWN-1), in the order it declared them; a
        // world the expectation does not name is not asked about, and one it names that the
        // machine does not declare is a failure
        if (expect.get("state")) |sv| {
            var it = sv.object.iterator();
            while (it.next()) |e| {
                var found = false;
                for (m.services) |s| if (std.mem.eql(u8, s.name, e.key_ptr.*)) {
                    found = true;
                    if (!sameList(s.state, e.value_ptr.array)) why = try std.fmt.allocPrint(arena, "state of {s} differs (got {d} directories)", .{ s.name, s.state.len });
                };
                if (!found) why = try std.fmt.allocPrint(arena, "state: no service {s}", .{e.key_ptr.*});
            }
        }
        // the time seat (TIME-1): the clock a machine has, whom it asks, and the port each link's authority answers on
        if (str(expect.get("clock"))) |w| if (m.clock == null or !std.mem.eql(u8, m.clock.?, w)) {
            why = try std.fmt.allocPrint(arena, "clock: expected {s} got {s}", .{ w, m.clock orelse "none" });
        };
        if (str(expect.get("time_from"))) |w| if (m.time_from == null or !std.mem.eql(u8, m.time_from.?.text, w)) {
            why = try std.fmt.allocPrint(arena, "time_from: expected {s} got {s}", .{ w, if (m.time_from) |tf| tf.text else "none" });
        };
        if (expect.get("time_authority")) |tv| {
            var it = tv.object.iterator();
            while (it.next()) |e| {
                var got: ?u16 = null;
                for (m.networks) |n| if (std.mem.eql(u8, n.name, e.key_ptr.*)) {
                    got = n.time_authority;
                };
                const want: i64 = switch (e.value_ptr.*) {
                    .integer => |i| i,
                    else => -1,
                };
                if (got == null or @as(i64, got.?) != want) why = try std.fmt.allocPrint(arena, "time_authority of {s}: expected {d}", .{ e.key_ptr.*, want });
            }
        }
        if (why) |w| {
            failures += 1;
            try out.print("  FAIL {s} {s} -- {s}\n", .{ id, name, w });
        } else {
            try out.print("  ok   {s} {s}\n", .{ id, name });
        }
    }

    const rejects = root.get("rejects").?.array;
    for (rejects.items) |case_v| {
        total += 1;
        const case = case_v.object;
        const id = str(case.get("id")).?;
        const name = str(case.get("name")).?;
        const source = str(case.get("source")).?;
        const fragment = str(case.get("refusal")).?;

        var arena_state = std.heap.ArenaAllocator.init(gpa);
        defer arena_state.deinit();
        var refusal = machine.Refusal{};
        if (machine.declare(arena_state.allocator(), source, &refusal)) |m| {
            failures += 1;
            try out.print("  FAIL {s} {s} -- accepted as machine '{s}', expected a refusal containing '{s}'\n", .{ id, name, m.name, fragment });
        } else |_| {
            if (std.mem.indexOf(u8, refusal.message, fragment) != null) {
                try out.print("  ok   {s} {s} -- line {d}: {s}\n", .{ id, name, refusal.line, refusal.message });
            } else {
                failures += 1;
                try out.print("  FAIL {s} {s} -- refused for the wrong reason: line {d}: {s} (expected '{s}')\n", .{ id, name, refusal.line, refusal.message, fragment });
            }
        }
    }

    try out.print("{d}/{d} -- {d} accepts, {d} rejects, {d} failures\n", .{ total - failures, total, accepts.items.len, rejects.items.len, failures });
    if (!pin_ok) try out.print("and the pin does not hold: these verdicts are about a file the pin does not name\n", .{});
    return failures + @intFromBool(!pin_ok);
}

// ---- the fleet court (FLT-1) -------------------------------------------
//
// The same shape, one file up: accepts carry the member count and the
// link, rejects carry the fragment their refusal must contain. What is
// different is that a fleet case is a SET, so each case carries the
// machine files it names inside itself (`files`), and the court hands
// those to the parser instead of the disk. A fixture stays one
// self-contained case and the court needs no scratch directory.

const Files = struct {
    obj: std.json.ObjectMap,

    fn read(context: *const anyopaque, path: []const u8) ?[]const u8 {
        const self: *const Files = @alignCast(@ptrCast(context));
        return str(self.obj.get(path));
    }
    fn resolver(self: *const Files) fleet.Resolver {
        return .{ .context = self, .readFn = read };
    }
};

pub fn runFleet(gpa: std.mem.Allocator, fixtures_path: []const u8, out: *std.Io.Writer) !usize {
    const bytes = try std.fs.cwd().readFileAlloc(gpa, fixtures_path, 1 << 22);
    defer gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(std.json.Value, gpa, bytes, .{});
    defer parsed.deinit();
    const root = parsed.value.object;

    const grammar = str(root.get("grammar")) orelse return error.BadFixtureFile;
    const version = str(root.get("version")) orelse return error.BadFixtureFile;
    if (!std.mem.eql(u8, grammar, "fleet")) return error.BadFixtureFile;
    try out.print("fleet conformance -- grammar {s} v{s}, judged by {s}\n", .{ grammar, version, fixtures_path });
    const pin_ok = try pinHolds(gpa, fixtures_path, bytes, out);

    var failures: usize = 0;
    var total: usize = 0;

    const accepts = root.get("accepts").?.array;
    for (accepts.items) |case_v| {
        total += 1;
        const case = case_v.object;
        const id = str(case.get("id")).?;
        const name = str(case.get("name")).?;
        const source = str(case.get("source")).?;
        const files = Files{ .obj = case.get("files").?.object };

        var arena_state = std.heap.ArenaAllocator.init(gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        var refusal = fleet.Refusal{};
        const f = fleet.declare(arena, source, files.resolver(), &refusal) catch {
            failures += 1;
            try out.print("  FAIL {s} {s} -- refused: fleet (line {d}): {s}\n", .{ id, name, refusal.line, refusal.message });
            continue;
        };

        var why: ?[]const u8 = null;
        const expect = case.get("expect").?.object;
        if (int(expect.get("members"))) |w| if (@as(i64, @intCast(f.members.len)) != w) {
            why = try std.fmt.allocPrint(arena, "members: expected {d} got {d}", .{ w, f.members.len });
        };
        // a retirement the parser dropped would still leave the fleet
        // accepted; an accept case that declares one says it was READ
        if (int(expect.get("retirements"))) |w| if (@as(i64, @intCast(f.retirements.len)) != w) {
            why = try std.fmt.allocPrint(arena, "retirements: expected {d} got {d}", .{ w, f.retirements.len });
        };
        if (expect.get("link")) |lv| switch (lv) {
            .string => |want| {
                const got = f.link() orelse "";
                if (!std.mem.eql(u8, got, want)) why = try std.fmt.allocPrint(arena, "link: expected {s} got '{s}'", .{ want, got });
            },
            .null => if (f.link()) |got| {
                why = try std.fmt.allocPrint(arena, "link: expected none, got {s}", .{got});
            },
            else => {},
        };
        // fleet v0.2 (FWD-1): the wires it declares, in order, and the ways between them
        if (expect.get("links")) |lv| if (lv == .array) {
            var same = lv.array.items.len == f.links.len;
            if (same) for (lv.array.items, f.links) |w, g| {
                if (w != .string or !std.mem.eql(u8, w.string, g)) same = false;
            };
            if (!same) why = try std.fmt.allocPrint(arena, "links: expected {d} named, got {d} (or another order)", .{ lv.array.items.len, f.links.len });
        };
        if (int(expect.get("routes"))) |w| if (@as(i64, @intCast(f.routes.len)) != w) {
            why = try std.fmt.allocPrint(arena, "routes: expected {d} got {d}", .{ w, f.routes.len });
        };
        // the member the fleet takes the time from (TIME-1)
        if (str(expect.get("time_authority"))) |w| if (f.time_authority == null or !std.mem.eql(u8, f.time_authority.?, w)) {
            why = try std.fmt.allocPrint(arena, "time_authority: expected {s} got {s}", .{ w, f.time_authority orelse "none" });
        };
        if (why) |w| {
            failures += 1;
            try out.print("  FAIL {s} {s} -- {s}\n", .{ id, name, w });
        } else {
            try out.print("  ok   {s} {s}\n", .{ id, name });
        }
    }

    const rejects = root.get("rejects").?.array;
    for (rejects.items) |case_v| {
        total += 1;
        const case = case_v.object;
        const id = str(case.get("id")).?;
        const name = str(case.get("name")).?;
        const source = str(case.get("source")).?;
        const fragment = str(case.get("refusal")).?;
        const files = Files{ .obj = case.get("files").?.object };

        var arena_state = std.heap.ArenaAllocator.init(gpa);
        defer arena_state.deinit();
        var refusal = fleet.Refusal{};
        if (fleet.declare(arena_state.allocator(), source, files.resolver(), &refusal)) |f| {
            failures += 1;
            try out.print("  FAIL {s} {s} -- accepted as fleet '{s}' ({d} members), expected a refusal containing '{s}'\n", .{ id, name, f.name, f.members.len, fragment });
        } else |_| {
            if (std.mem.indexOf(u8, refusal.message, fragment) != null) {
                try out.print("  ok   {s} {s} -- line {d}: {s}\n", .{ id, name, refusal.line, refusal.message });
            } else {
                failures += 1;
                try out.print("  FAIL {s} {s} -- refused for the wrong reason: line {d}: {s} (expected '{s}')\n", .{ id, name, refusal.line, refusal.message, fragment });
            }
        }
    }

    try out.print("{d}/{d} -- {d} accepts, {d} rejects, {d} failures\n", .{ total - failures, total, accepts.items.len, rejects.items.len, failures });
    if (!pin_ok) try out.print("and the pin does not hold: these verdicts are about a file the pin does not name\n", .{});
    return failures + @intFromBool(!pin_ok);
}

// ---- the pack court (PLC-1) ----------------------------------------------
//
// Same shape as the two above, and the same discipline: accepts carry what
// must be true of the placement, rejects carry the fragment their refusal
// must contain -- and, because a refusal that points at the wrong FILE or the
// wrong LINE sends a person to the wrong place, the file and the line it must
// name. A case is a machine and the packs placed on it, all inside the case:
// the machine is always `host.machine`, and each pack carries its own file
// name, so a fixture is self-contained and the court needs no scratch
// directory. Every accept is also judged for three things that must hold of
// ANY placement and would be tedious to write into each case: the placed
// text starts with the machine file as written, placing again gives the same
// bytes, and the placed machine has a boot plan.

const host_name = "host.machine";

fn packInputs(arena: std.mem.Allocator, case: std.json.ObjectMap) ![]pack.Input {
    const arr = case.get("packs").?.array;
    const list = try arena.alloc(pack.Input, arr.items.len);
    for (arr.items, 0..) |v, i| {
        const o = v.object;
        list[i] = .{ .name = str(o.get("path")).?, .source = str(o.get("source")).? };
    }
    return list;
}

pub fn runPack(gpa: std.mem.Allocator, fixtures_path: []const u8, out: *std.Io.Writer) !usize {
    const bytes = try std.fs.cwd().readFileAlloc(gpa, fixtures_path, 1 << 22);
    defer gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(std.json.Value, gpa, bytes, .{});
    defer parsed.deinit();
    const root = parsed.value.object;

    const grammar = str(root.get("grammar")) orelse return error.BadFixtureFile;
    const version = str(root.get("version")) orelse return error.BadFixtureFile;
    if (!std.mem.eql(u8, grammar, "pack")) return error.BadFixtureFile;
    try out.print("pack conformance -- grammar {s} v{s}, judged by {s}\n", .{ grammar, version, fixtures_path });
    const pin_ok = try pinHolds(gpa, fixtures_path, bytes, out);

    var failures: usize = 0;
    var total: usize = 0;

    const accepts = root.get("accepts").?.array;
    for (accepts.items) |case_v| {
        total += 1;
        const case = case_v.object;
        const id = str(case.get("id")).?;
        const name = str(case.get("name")).?;
        const host = str(case.get("machine")).?;

        var arena_state = std.heap.ArenaAllocator.init(gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        const inputs = try packInputs(arena, case);
        var refusal = pack.Refusal{};
        const placed = pack.place(arena, .{ .name = host_name, .source = host }, inputs, &refusal) catch {
            failures += 1;
            try out.print("  FAIL {s} {s} -- refused: {s} (line {d}): {s}\n", .{ id, name, refusal.file, refusal.line, refusal.message });
            continue;
        };

        var why: ?[]const u8 = null;
        const expect = case.get("expect").?.object;
        const m = placed.machine;
        if (expect.get("services")) |sv| {
            const got = try arena.alloc([]const u8, m.services.len);
            for (m.services, 0..) |s, i| got[i] = s.name;
            if (!sameList(got, sv.array)) why = "services: not the machine's own then the packs', in the order placed";
        }
        if (expect.get("users")) |uv| {
            const got = try arena.alloc([]const u8, m.users.len);
            for (m.users, 0..) |u, i| got[i] = u.name;
            if (!sameList(got, uv.array)) why = "users: not the machine's own then the packs'";
        }
        if (int(expect.get("packs"))) |w| if (@as(i64, @intCast(placed.packs.len)) != w) {
            why = try std.fmt.allocPrint(arena, "packs: expected {d} got {d}", .{ w, placed.packs.len });
        };
        if (!std.mem.startsWith(u8, placed.text, host)) why = "the placed text does not start with the machine file as written";
        var again = pack.Refusal{};
        if (pack.place(arena, .{ .name = host_name, .source = host }, inputs, &again)) |second| {
            if (!std.mem.eql(u8, second.text, placed.text)) why = "placing again gave different bytes";
        } else |_| why = "placing again was refused";
        _ = plan.derive(arena, &placed.machine) catch {
            why = "the placed machine has no boot plan";
        };
        if (why) |w| {
            failures += 1;
            try out.print("  FAIL {s} {s} -- {s}\n", .{ id, name, w });
        } else {
            try out.print("  ok   {s} {s}\n", .{ id, name });
        }
    }

    const rejects = root.get("rejects").?.array;
    for (rejects.items) |case_v| {
        total += 1;
        const case = case_v.object;
        const id = str(case.get("id")).?;
        const name = str(case.get("name")).?;
        const host = str(case.get("machine")).?;
        const fragment = str(case.get("refusal")).?;
        const want_in = str(case.get("in")).?;
        const want_line = int(case.get("line")).?;

        var arena_state = std.heap.ArenaAllocator.init(gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        const inputs = try packInputs(arena, case);
        var refusal = pack.Refusal{};
        if (pack.place(arena, .{ .name = host_name, .source = host }, inputs, &refusal)) |p| {
            failures += 1;
            try out.print("  FAIL {s} {s} -- placed ({d} service(s)), expected a refusal containing '{s}'\n", .{ id, name, p.machine.services.len, fragment });
        } else |_| {
            const in_ok = std.mem.eql(u8, refusal.file, want_in) and @as(i64, @intCast(refusal.line)) == want_line;
            const msg_ok = std.mem.indexOf(u8, refusal.message, fragment) != null;
            if (in_ok and msg_ok) {
                try out.print("  ok   {s} {s} -- {s} line {d}: {s}\n", .{ id, name, refusal.file, refusal.line, refusal.message });
            } else {
                failures += 1;
                try out.print("  FAIL {s} {s} -- refused as {s} line {d}: {s} (expected {s} line {d} containing '{s}')\n", .{ id, name, refusal.file, refusal.line, refusal.message, want_in, want_line, fragment });
            }
        }
    }

    try out.print("{d}/{d} -- {d} accepts, {d} rejects, {d} failures\n", .{ total - failures, total, accepts.items.len, rejects.items.len, failures });
    if (!pin_ok) try out.print("and the pin does not hold: these verdicts are about a file the pin does not name\n", .{});
    return failures + @intFromBool(!pin_ok);
}
