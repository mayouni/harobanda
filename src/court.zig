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
    return failures;
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
        if (expect.get("link")) |lv| switch (lv) {
            .string => |want| {
                const got = f.link orelse "";
                if (!std.mem.eql(u8, got, want)) why = try std.fmt.allocPrint(arena, "link: expected {s} got '{s}'", .{ want, got });
            },
            .null => if (f.link) |got| {
                why = try std.fmt.allocPrint(arena, "link: expected none, got {s}", .{got});
            },
            else => {},
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
    return failures;
}
