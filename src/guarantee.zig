// guarantee.zig -- `harb guarantees <file.machine> <text>`: the hosted
// profile's four standing promises, judged by name (GRT-1).
//
// Their provenance is a restaurant, not a specification. RestoLean's
// Makeen thread wrote them as a sheet that "imposes itself over whatever
// host is underneath" -- MakeenOS as a posture, never a marriage -- and
// Amor wrote them in four words each: toujours joignable, nom stable,
// journal local durable, traverse la coupure. They were a brochure. This
// verb makes them a verdict.
//
// The four are the hosted profile's, not one customer's: a box behind a
// counter, an NGO's hub in Diffa, a bank's server and a school's machine
// all make the same four promises or say they make none. So the judge
// reads the DECLARATION for what is promised and a TEXT -- a transcript,
// or the expectation the image carries -- for what is kept, and states
// three things per promise: not claimed, claimed and kept, claimed and
// not kept. A machine that claims none is a machine that makes none of
// the box's promises, which is a fine thing to be: `qemu_hello` is one.
//
// Nothing here restates the declaration as evidence. A promise is kept
// only if a line of the text says so, and the line is quoted.

const std = @import("std");
const machine = @import("machine.zig");

pub const Verdict = enum { not_claimed, kept, broken };

const Finding = struct {
    name: []const u8,
    promise: []const u8,
    verdict: Verdict,
    /// what the declaration promised with, or why nothing is promised
    claim: []const u8,
    /// the line that keeps it, or what was looked for and not found
    evidence: []const u8,
};

/// The lines that can be EVIDENCE, and only those.
///
/// A transcript carries more than one boot's worth of text: the court
/// runs the same card again held, and again through another lens, and
/// prefixes those (`hold: `, `unmet: `). It also carries PID 1 QUOTING
/// lines it expected and did not say. Both answer a substring search and
/// neither is evidence about this boot -- the first is another boot, the
/// second is a quotation. So evidence is what PID 1 said about THIS
/// boot: a line that begins `boot: ` and is not the judge quoting.
///
/// Found the hard way (GRT-1): before this filter, a promise was judged
/// KEPT by the very line that said it was missing.
fn lines(arena: std.mem.Allocator, text: []const u8) ![]const []const u8 {
    var list: std.ArrayList([]const u8) = .{};
    var it = std.mem.splitScalar(u8, text, 10);
    while (it.next()) |raw| {
        const l = std.mem.trimRight(u8, raw, "\r");
        if (!std.mem.startsWith(u8, l, "boot: ")) continue;
        if (std.mem.startsWith(u8, l, "boot: judge --")) continue;
        try list.append(arena, l);
    }
    return list.toOwnedSlice(arena);
}

/// where the first world was started; every promise about the floor must
/// be kept BEFORE that line, because a world that starts on a floor that
/// is not ready has already been told a lie
fn firstStart(ls: []const []const u8) usize {
    for (ls, 0..) |l, i| {
        if (std.mem.indexOf(u8, l, "boot: start ") != null) return i;
    }
    return ls.len;
}

fn find(ls: []const []const u8, needle: []const u8) ?usize {
    for (ls, 0..) |l, i| {
        if (std.mem.indexOf(u8, l, needle) != null) return i;
    }
    return null;
}

/// A network only the machine itself can reach: its loopback, which `machine.zig`
/// defines once. A promise to be FOUND, or about an address others LEARN, is not
/// kept by one -- a sentence written for a wire and printed for an interface that
/// goes nowhere is a lie in the second case (EGR-2). It was, until SRV-2 declared
/// one: a machine whose only network was `lo` read "always reachable: KEPT".
const isLoopback = machine.isLoopback;

/// the first network somebody else could reach the box by
fn firstReachable(m: *const machine.Machine) ?machine.Network {
    for (m.networks) |n| if (!isLoopback(n)) return n;
    return null;
}

pub fn judge(arena: std.mem.Allocator, m: *const machine.Machine, text: []const u8, label: []const u8, out: *std.Io.Writer) !u8 {
    const ls = try lines(arena, text);
    const start = firstStart(ls);
    var f: std.ArrayList(Finding) = .{};

    // ---- 1. always reachable ------------------------------------------
    if (firstReachable(m) == null) {
        try f.append(arena, .{
            .name = "always reachable",
            .promise = "whoever needs the box finds it, without being told where it went",
            .verdict = .not_claimed,
            .claim = if (m.networks.len == 0) "the machine declares no NETWORK" else "the machine's only NETWORK is its own loopback, which nothing outside it can reach",
            .evidence = "",
        });
    } else {
        const n = firstReachable(m).?;
        const up = try std.fmt.allocPrint(arena, "network {s} -- {s} up ", .{ n.name, n.interface });
        if (find(ls, up)) |i| {
            if (i < start) {
                try f.append(arena, .{
                    .name = "always reachable",
                    .promise = "whoever needs the box finds it, without being told where it went",
                    .verdict = .kept,
                    .claim = try std.fmt.allocPrint(arena, "NETWORK {s} on {s}", .{ n.name, n.interface }),
                    .evidence = ls[i],
                });
            } else {
                try f.append(arena, .{
                    .name = "always reachable",
                    .promise = "whoever needs the box finds it, without being told where it went",
                    .verdict = .broken,
                    .claim = try std.fmt.allocPrint(arena, "NETWORK {s} on {s}", .{ n.name, n.interface }),
                    .evidence = try std.fmt.allocPrint(arena, "the wire came up AFTER a world had started: {s}", .{ls[i]}),
                });
            }
        } else {
            const said = if (find(ls, try std.fmt.allocPrint(arena, "network {s} --", .{n.name}))) |i| ls[i] else "nothing about it at all";
            try f.append(arena, .{
                .name = "always reachable",
                .promise = "whoever needs the box finds it, without being told where it went",
                .verdict = .broken,
                .claim = try std.fmt.allocPrint(arena, "NETWORK {s} on {s}", .{ n.name, n.interface }),
                .evidence = try std.fmt.allocPrint(arena, "the wire never came up -- {s}", .{said}),
            });
        }
    }

    // ---- 2. a stable name ---------------------------------------------
    {
        var static: ?machine.Network = null;
        for (m.networks) |n| {
            if (n.address == .static and static == null and !isLoopback(n)) static = n;
        }
        if (static) |n| {
            const addr = n.address.static.text;
            if (find(ls, addr)) |i| {
                try f.append(arena, .{
                    .name = "a stable name",
                    .promise = "the address the phones learned yesterday is the address today",
                    .verdict = .kept,
                    .claim = try std.fmt.allocPrint(arena, "ADDRESS {s}, declared, not leased", .{addr}),
                    .evidence = ls[i],
                });
            } else {
                try f.append(arena, .{
                    .name = "a stable name",
                    .promise = "the address the phones learned yesterday is the address today",
                    .verdict = .broken,
                    .claim = try std.fmt.allocPrint(arena, "ADDRESS {s}, declared, not leased", .{addr}),
                    .evidence = try std.fmt.allocPrint(arena, "no line carries {s}", .{addr}),
                });
            }
        } else if (firstReachable(m) != null) {
            try f.append(arena, .{
                .name = "a stable name",
                .promise = "the address the phones learned yesterday is the address today",
                .verdict = .not_claimed,
                .claim = "every declared NETWORK takes a lease (ADDRESS dhcp): the box is found at whatever address it was given",
                .evidence = "",
            });
        } else if (m.networks.len > 0) {
            try f.append(arena, .{
                .name = "a stable name",
                .promise = "the address the phones learned yesterday is the address today",
                .verdict = .not_claimed,
                .claim = "the machine's only NETWORK is its own loopback: there is no address anyone else learns",
                .evidence = "",
            });
        } else {
            try f.append(arena, .{
                .name = "a stable name",
                .promise = "the address the phones learned yesterday is the address today",
                .verdict = .not_claimed,
                .claim = "the machine declares no NETWORK",
                .evidence = "",
            });
        }
    }

    // ---- 3. a durable log ---------------------------------------------
    {
        var persistent: ?machine.Mount = null;
        for (m.mounts) |mt| {
            if ((mt.fs == .ext4 or mt.fs == .vfat) and persistent == null) persistent = mt;
        }
        if (persistent) |mt| {
            const done = try std.fmt.allocPrint(arena, "mount {s} at {s} -- done", .{ @tagName(mt.fs), mt.at });
            if (find(ls, done)) |i| {
                if (i < start) {
                    try f.append(arena, .{
                        .name = "a durable log",
                        .promise = "what the box wrote down is still there after the power comes back",
                        .verdict = .kept,
                        .claim = try std.fmt.allocPrint(arena, "MOUNT {s}, {s} on {s}", .{ mt.name, @tagName(mt.fs), mt.device orelse "the board's own" }),
                        .evidence = ls[i],
                    });
                } else {
                    try f.append(arena, .{
                        .name = "a durable log",
                        .promise = "what the box wrote down is still there after the power comes back",
                        .verdict = .broken,
                        .claim = try std.fmt.allocPrint(arena, "MOUNT {s}", .{mt.name}),
                        .evidence = try std.fmt.allocPrint(arena, "mounted AFTER a world had started: {s}", .{ls[i]}),
                    });
                }
            } else {
                try f.append(arena, .{
                    .name = "a durable log",
                    .promise = "what the box wrote down is still there after the power comes back",
                    .verdict = .broken,
                    .claim = try std.fmt.allocPrint(arena, "MOUNT {s}", .{mt.name}),
                    .evidence = try std.fmt.allocPrint(arena, "no line says '{s}'", .{done}),
                });
            }
        } else {
            try f.append(arena, .{
                .name = "a durable log",
                .promise = "what the box wrote down is still there after the power comes back",
                .verdict = .not_claimed,
                .claim = "the machine declares no persistent MOUNT: everything it holds dies with the power",
                .evidence = "",
            });
        }
    }

    // ---- 4. survives the cut ------------------------------------------
    if (m.slots == null) {
        try f.append(arena, .{
            .name = "survives the cut",
            .promise = "a breaker, a technician, a bad update: the box comes back by itself",
            .verdict = .not_claimed,
            .claim = "the machine declares no SLOTS: an update is not a trial, and nothing rolls back",
            .evidence = "",
        });
    } else {
        // the watchdog is what makes the promise mechanical rather than
        // hopeful, and a wedged world must reach it: since HLT-1 that
        // means every world which signals also declares a window
        var signalling: usize = 0;
        var watched: usize = 0;
        for (m.services) |s| {
            if (s.ready != null) signalling += 1;
            if (s.health != null) watched += 1;
        }
        const armed = find(ls, "watchdog armed");
        const decided = find(ls, "-- committed:") orelse find(ls, "-- committed, steady") orelse find(ls, "-- held:");
        if (armed != null and decided != null and signalling == watched) {
            try f.append(arena, .{
                .name = "survives the cut",
                .promise = "a breaker, a technician, a bad update: the box comes back by itself",
                .verdict = .kept,
                .claim = try std.fmt.allocPrint(arena, "SLOTS {s}, and every world that signals also declares a HEALTH window", .{m.slots.?}),
                .evidence = ls[armed.?],
            });
        } else {
            const why = if (armed == null)
                (if (find(ls, "watchdog --")) |i| ls[i] else "no line arms the watchdog")
            else if (decided == null)
                "this text carries no slot decision -- an EXPECTATION stops where the verdict begins (the card's state is the card's to say), so a commit or a hold is a TRANSCRIPT's evidence"
            else
                try std.fmt.allocPrint(arena, "{d} world(s) signal that they serve and only {d} declare a HEALTH window: a wedged world would keep feeding the watchdog", .{ signalling, watched });
            try f.append(arena, .{
                .name = "survives the cut",
                .promise = "a breaker, a technician, a bad update: the box comes back by itself",
                .verdict = .broken,
                .claim = try std.fmt.allocPrint(arena, "SLOTS {s}", .{m.slots.?}),
                .evidence = why,
            });
        }
    }

    // ---- the sheet ----------------------------------------------------
    try out.print("guarantees {s} -- the hosted profile's four standing promises, judged against {s}\n", .{ m.name, label });
    var claimed: usize = 0;
    var kept: usize = 0;
    for (f.items) |x| {
        const word = switch (x.verdict) {
            .not_claimed => "not promised",
            .kept => "KEPT",
            .broken => "NOT KEPT",
        };
        if (x.verdict != .not_claimed) claimed += 1;
        if (x.verdict == .kept) kept += 1;
        try out.print("\n  {s} -- {s}\n", .{ x.name, x.promise });
        try out.print("    promised by: {s}\n", .{x.claim});
        try out.print("    {s}", .{word});
        if (x.evidence.len > 0) try out.print(" -- {s}", .{x.evidence});
        try out.print("\n", .{});
    }
    try out.print("\n{d} of 4 promised, {d} kept\n", .{ claimed, kept });
    return if (claimed == kept) 0 else 1;
}

// ---- judged beside the code ----------------------------------------------

const loopback_only =
    \\DEFINE MACHINE m AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE "x"
    \\DEFINE CAPABILITY network AS (GRANT yes) RATIONALE "x"
    \\DEFINE NETWORK lo AS (INTERFACE "lo", ADDRESS "127.0.0.1/8") RATIONALE "x"
    \\
;

const on_a_wire =
    \\DEFINE MACHINE m AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE "x"
    \\DEFINE CAPABILITY network AS (GRANT yes) RATIONALE "x"
    \\DEFINE NETWORK lan AS (INTERFACE "eth0", ADDRESS "192.168.10.1/24") RATIONALE "x"
    \\
;

const both =
    \\DEFINE MACHINE m AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE "x"
    \\DEFINE CAPABILITY network AS (GRANT yes) RATIONALE "x"
    \\DEFINE NETWORK lo AS (INTERFACE "lo", ADDRESS "127.0.0.1/8") RATIONALE "x"
    \\DEFINE NETWORK lan AS (INTERFACE "eth0", ADDRESS "192.168.10.1/24") RATIONALE "x"
    \\
;

fn sheet(arena: std.mem.Allocator, src: []const u8, transcript: []const u8) ![]const u8 {
    var refusal = machine.Refusal{};
    const m = try machine.declare(arena, src, &refusal);
    var aw = std.Io.Writer.Allocating.init(arena);
    _ = try judge(arena, &m, transcript, "t", &aw.writer);
    return aw.written();
}

test "a machine whose only network is its own loopback promises nothing to anyone outside it" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const said = "boot: network lo -- lo up 127.0.0.1/8\nboot: start s -- pid 2 -- /s\n";
    const s = try sheet(arena, loopback_only, said);
    try t.expect(std.mem.indexOf(u8, s, "the machine's only NETWORK is its own loopback, which nothing outside it can reach") != null);
    try t.expect(std.mem.indexOf(u8, s, "there is no address anyone else learns") != null);
    // and the line that said the interface was up is not offered as evidence of either promise
    try t.expect(std.mem.indexOf(u8, s, "KEPT -- boot: network lo") == null);
    try t.expect(std.mem.indexOf(u8, s, "0 of 4 promised, 0 kept") != null);
}

test "a machine on a wire still keeps both, and a loopback beside it is not the one judged" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const said = "boot: network lan -- eth0 up 192.168.10.1/24\nboot: start s -- pid 2 -- /s\n";
    for ([_][]const u8{ on_a_wire, both }) |src| {
        const s = try sheet(arena, src, said);
        try t.expect(std.mem.indexOf(u8, s, "promised by: NETWORK lan on eth0\n    KEPT -- boot: network lan -- eth0 up 192.168.10.1/24") != null);
        try t.expect(std.mem.indexOf(u8, s, "promised by: ADDRESS 192.168.10.1/24, declared, not leased\n    KEPT") != null);
    }
}
