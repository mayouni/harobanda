//! The pack (PLC-1): what a solution asks, placed on the machine that grants it.
//!
//! ## Why a third file and not a bigger one
//!
//! A machine file says what ONE machine is and what it grants. A fleet file
//! says what a SET of machines is. Neither can say what a SOLUTION is: the
//! services it runs, the identities they run as, and what each of them needs
//! from whatever machine it lands on. Those facts are written once, by the
//! people who made the solution, and they must be placeable on a machine
//! somebody else declared -- a box in a restaurant, a server in a bank, a
//! virtual machine somebody rents. That is a pack.
//!
//! It is the same language -- the same tokenizer, the same clause machinery,
//! the same refusal channel -- and a file is judged by which kinds it may
//! contain (FLT-1's rule, applied again). A pack may carry SERVICE and USER
//! and nothing else.
//!
//! ## A pack asks, and the machine grants
//!
//! Everything a world may use is the machine's to say: its capabilities, its
//! mounts, its networks, its pins. A pack that could declare a CAPABILITY
//! would grant itself what it asks for, and the grant would mean nothing. So
//! a pack names what it NEEDS (`NEEDS [network]`), which mounts it SEES, which
//! user it runs as, which directories that user owns (`STATE`, OWN-1), and the
//! machine it is placed on either has those or refuses the placement, at the
//! line of the pack that asked.
//!
//! ## One reading of the rules
//!
//! The pack alone is judged only for what a pack is: its kinds, and its
//! names. Whether a service's NEEDS are granted, whether its READY path is
//! free, whether its AFTER resolves, whether its RUN is a shell -- those are
//! the machine court's rules, and a pack's services are judged by them in the
//! only place they mean anything, on a machine. `place` does not copy a rule;
//! it composes one machine text out of the machine file and the packs and
//! hands it to the one court (a generated artifact is judged by what
//! CONSUMES it, PRJ-2), then says where each refusal came from.
//!
//! The machine file is judged ALONE first, and refused by itself if it must
//! be: a refusal that arrives with the placement is then known to come from
//! the placement.
//!
//! ## Reproducible
//!
//! The placed text is the machine file as written, then each pack as written
//! in the order given, each under a one-line comment naming the pack by its
//! file name and its sha256. Same bytes in, same bytes out, on any machine:
//! no path is ever written into it, so the declaration digest the machine's
//! journal records (init.zig) names the pack that ran as well as the
//! machine.
//!
//! ## What this is not
//!
//! Not a package manager: nothing is fetched, versioned or resolved. Not a
//! service manager: PID 1 still starts what the court accepted. Not a
//! manifest a solution's own declaration projects into (stzp's server
//! target) -- that projection is not written; a pack is hand-written today.
//! Not a port or an egress list per world: a SERVICE has no such clause, and
//! a machine's reach is per NETWORK until it is per world (CLOUD.md, rung 6).

const std = @import("std");
const machine = @import("machine.zig");

const Allocator = std.mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const Error = machine.Error;

/// A refusal in terms of FILES. Placement judges several of them, so the
/// machine court's bare line number would not say which one it meant.
pub const Refusal = struct {
    file: []const u8 = "",
    line: usize = 0,
    message: []const u8 = "",
};

/// One file handed to `place`: the name it is known by -- its file name, never
/// a path, so the placed text is the same wherever it was made -- and its text.
pub const Input = struct {
    name: []const u8,
    source: []const u8,
};

/// What a pack declares, read from its own text.
pub const Pack = struct {
    name: []const u8,
    /// sha256 of the pack's bytes as read, lowercase hex
    digest: [64]u8,
    services: []const []const u8,
    users: []const []const u8,
};

pub const Placement = struct {
    /// the machine file, then each pack, as one machine text: what the court
    /// judged and what `harb image` would be handed
    text: []const u8,
    /// the machine that text declares
    machine: machine.Machine,
    packs: []const Pack,
};

/// The file name of a path as the user wrote it, either separator: what is
/// recorded in the placed text and in every refusal.
pub fn fileName(path: []const u8) []const u8 {
    var i = path.len;
    while (i > 0) : (i -= 1) {
        if (path[i - 1] == '/' or path[i - 1] == '\\') return path[i..];
    }
    return path;
}

const Read = struct {
    decls: []const machine.Decl,
};

fn refuseIn(r: *Refusal, file: []const u8, line: usize, message: []const u8) Error {
    r.* = .{ .file = file, .line = line, .message = message };
    return error.Refused;
}

/// every declaration of a text, by the machine language's own reader. A text
/// the language refuses is refused at the line the language names, in this
/// file's own numbering.
fn readDecls(arena: Allocator, input: Input, refusal: *Refusal) Error!Read {
    var inner = machine.Refusal{};
    var ctx = machine.Ctx{ .arena = arena, .src = input.source, .refusal = &inner };
    var decls: std.ArrayList(machine.Decl) = .{};
    const parsed: Error!void = blk: {
        ctx.tokenize() catch |e| break :blk e;
        while (ctx.peek().tag != .eof) {
            const d = machine.parseDecl(&ctx) catch |e| break :blk e;
            decls.append(arena, d) catch |e| break :blk e;
        }
        break :blk {};
    };
    parsed catch |e| switch (e) {
        error.Refused => return refuseIn(refusal, input.name, inner.line, inner.message),
        else => return e,
    };
    return .{ .decls = try decls.toOwnedSlice(arena) };
}

/// A pack on its own: the kinds it may carry, and its names.
fn readPack(arena: Allocator, input: Input, refusal: *Refusal) Error!Pack {
    const read = try readDecls(arena, input, refusal);
    if (read.decls.len == 0) {
        return refuseIn(refusal, input.name, 1, "A pack declares at least one SERVICE; this file declares nothing");
    }
    var services: std.ArrayList([]const u8) = .{};
    var users: std.ArrayList([]const u8) = .{};
    for (read.decls, 0..) |d, i| {
        // the kinds a pack may carry are asked of the language, and the
        // refusal says whose declaration the kind is
        if (machine.belongsToFleet(d.kind)) {
            return refuseIn(refusal, input.name, d.line, try std.fmt.allocPrint(arena, "{s} belongs to a fleet file, not a pack: a pack says what a solution asks, and no pack can say who else is in an estate", .{@tagName(d.kind)}));
        }
        switch (d.kind) {
            .SERVICE => try services.append(arena, d.name),
            .USER => try users.append(arena, d.name),
            else => return refuseIn(refusal, input.name, d.line, try std.fmt.allocPrint(arena, "{s} is the machine's to declare, not a pack's: a pack asks for what its services need, and the machine it is placed on grants it", .{@tagName(d.kind)})),
        }
        for (read.decls[0..i]) |e| if (std.mem.eql(u8, d.name, e.name)) {
            return refuseIn(refusal, input.name, d.line, try std.fmt.allocPrint(arena, "'{s}' is already declared (line {d}); one namespace, no duplicates", .{ d.name, e.line }));
        };
    }
    if (services.items.len == 0) {
        return refuseIn(refusal, input.name, read.decls[0].line, "A pack declares at least one SERVICE: a pack of identities alone places nothing");
    }
    var digest: [32]u8 = undefined;
    Sha256.hash(input.source, &digest, .{});
    var hex: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&hex, "{x}", .{&digest}) catch unreachable;
    return .{
        .name = input.name,
        .digest = hex,
        .services = try services.toOwnedSlice(arena),
        .users = try users.toOwnedSlice(arena),
    };
}

/// where a stretch of the placed text came from
const Region = struct {
    file: []const u8,
    /// first and last line of the stretch, in the PLACED text's numbering
    first: usize,
    last: usize,
    is_pack: bool,
};

fn countLines(text: []const u8) usize {
    return std.mem.count(u8, text, "\n");
}

const At = struct { region: Region, own: usize };

/// The stretch of the placed text a line belongs to, and the line in that
/// file's own numbering. The blank line and the banner above each pack belong
/// to no file.
fn locate(regions: []const Region, line: usize) ?At {
    for (regions) |r| if (line >= r.first and line <= r.last) return .{ .region = r, .own = line - r.first + 1 };
    return null;
}

/// A refusal of the placed text, said in terms of the file that wrote it. One
/// that lands in the machine's own lines, after the machine passed alone,
/// comes with what was placed on it, and says so.
fn attribute(arena: Allocator, regions: []const Region, line: usize, message: []const u8) Allocator.Error!Refusal {
    if (locate(regions, line)) |at| {
        const msg = if (at.region.is_pack) message else try std.fmt.allocPrint(arena, "{s} (the machine passes alone; this arose when the packs were placed on it)", .{message});
        return .{ .file = at.region.file, .line = at.own, .message = msg };
    }
    return .{ .file = "the placed text", .line = line, .message = message };
}

/// Place the packs on the machine, in the order given.
///
/// Refused: the machine, when it is refused on its own; a pack, when it is
/// not a pack; a name, when it is already taken by the machine or by a pack
/// before it; and anything the machine court refuses once the services are
/// there, reported at the line of the file that wrote it.
pub fn place(arena: Allocator, host: Input, packs: []const Input, refusal: *Refusal) Error!Placement {
    if (packs.len == 0) return refuseIn(refusal, host.name, 0, "Nothing to place: name at least one pack");

    // the machine, alone first: a refusal that comes later is the placement's
    var alone = machine.Refusal{};
    _ = machine.declare(arena, host.source, &alone) catch |e| switch (e) {
        error.Refused => return refuseIn(refusal, host.name, alone.line, try std.fmt.allocPrint(arena, "the machine is refused before anything is placed on it: {s}", .{alone.message})),
        else => return e,
    };

    // names taken, kind-blind, as the machine court's one namespace is
    const Taken = struct { name: []const u8, line: usize, file: []const u8 };
    var taken: std.ArrayList(Taken) = .{};
    var host_inner = Refusal{};
    for ((try readDecls(arena, host, &host_inner)).decls) |d| {
        try taken.append(arena, .{ .name = d.name, .line = d.line, .file = host.name });
    }

    var read: std.ArrayList(Pack) = .{};
    for (packs) |input| {
        const p = try readPack(arena, input, refusal);
        var again = Refusal{};
        for ((try readDecls(arena, input, &again)).decls) |d| {
            for (taken.items) |t| if (std.mem.eql(u8, d.name, t.name)) {
                return refuseIn(refusal, input.name, d.line, try std.fmt.allocPrint(arena, "'{s}' is already declared (line {d} of {s}); one namespace, no duplicates", .{ d.name, t.line, t.file }));
            };
            try taken.append(arena, .{ .name = d.name, .line = d.line, .file = input.name });
        }
        try read.append(arena, p);
    }

    // one text: the machine as written, then each pack as written under a line
    // that names it. Every part ends in a newline so the numbering is exact.
    var text: std.ArrayList(u8) = .{};
    var regions: std.ArrayList(Region) = .{};
    try text.appendSlice(arena, host.source);
    if (host.source.len == 0 or host.source[host.source.len - 1] != '\n') try text.append(arena, '\n');
    try regions.append(arena, .{ .file = host.name, .first = 1, .last = countLines(text.items), .is_pack = false });
    for (packs, read.items) |input, p| {
        try text.appendSlice(arena, "\n");
        try text.appendSlice(arena, try std.fmt.allocPrint(arena, "-- placed by harb place: {s} sha256:{s}\n", .{ p.name, p.digest[0..] }));
        const first = countLines(text.items) + 1;
        try text.appendSlice(arena, input.source);
        if (input.source.len == 0 or input.source[input.source.len - 1] != '\n') try text.append(arena, '\n');
        try regions.append(arena, .{ .file = input.name, .first = first, .last = countLines(text.items), .is_pack = true });
    }
    const placed = try text.toOwnedSlice(arena);

    var inner = machine.Refusal{};
    const m = machine.declare(arena, placed, &inner) catch |e| switch (e) {
        error.Refused => {
            refusal.* = try attribute(arena, regions.items, inner.line, inner.message);
            return error.Refused;
        },
        else => return e,
    };
    return .{ .text = placed, .machine = m, .packs = try read.toOwnedSlice(arena) };
}

// ---- judged beside the code ----------------------------------------------

const host_ok =
    \\DEFINE MACHINE m AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE "x"
    \\DEFINE CAPABILITY network AS (GRANT yes) RATIONALE "x"
    \\DEFINE CAPABILITY filesystem AS (GRANT yes) RATIONALE "x"
    \\DEFINE MOUNT data AS (AT "/data", FS tmpfs, OPTIONS [rw]) RATIONALE "x"
    \\DEFINE SERVICE kds AS (RUN ["/kds"], RESTART always, NEEDS [network]) RATIONALE "x"
    \\
;

const pack_ok =
    \\-- the Commons, asked for
    \\DEFINE USER commons_user AS (UID 2000) RATIONALE "x"
    \\DEFINE SERVICE commons AS (
    \\  RUN ["/commons"],
    \\  RESTART always,
    \\  AFTER [kds],
    \\  NEEDS [network, filesystem],
    \\  SEES [data],
    \\  USER commons_user
    \\) RATIONALE "x"
    \\
;

fn placeOne(arena: Allocator, host: []const u8, pack_src: []const u8, refusal: *Refusal) Error!Placement {
    return place(arena, .{ .name = "host.machine", .source = host }, &.{.{ .name = "commons.pack", .source = pack_src }}, refusal);
}

test "a pack is placed after the machine's own services, and the text is the machine then the pack" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var r = Refusal{};
    const p = try placeOne(arena, host_ok, pack_ok, &r);
    try t.expectEqual(@as(usize, 2), p.machine.services.len);
    try t.expectEqualStrings("kds", p.machine.services[0].name);
    try t.expectEqualStrings("commons", p.machine.services[1].name);
    // the machine file as written is the start of the placed text, byte for byte
    try t.expect(std.mem.startsWith(u8, p.text, host_ok));
    // the pack is there as written, after a line that names it and its digest
    try t.expect(std.mem.endsWith(u8, p.text, pack_ok));
    var hex: [64]u8 = undefined;
    var digest: [32]u8 = undefined;
    Sha256.hash(pack_ok, &digest, .{});
    _ = try std.fmt.bufPrint(&hex, "{x}", .{&digest});
    const banner = try std.fmt.allocPrint(arena, "-- placed by harb place: commons.pack sha256:{s}\n", .{hex[0..]});
    try t.expect(std.mem.indexOf(u8, p.text, banner) != null);
    try t.expectEqualStrings(hex[0..], p.packs[0].digest[0..]);
}

test "placing twice gives the same bytes, and no path is written into them" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var r = Refusal{};
    const a = try placeOne(arena, host_ok, pack_ok, &r);
    const b = try placeOne(arena, host_ok, pack_ok, &r);
    try t.expectEqualStrings(a.text, b.text);
    // the name recorded is a file name: handed a path, the CLI keeps only that
    try t.expectEqualStrings("commons.pack", fileName("some/where/commons.pack"));
    try t.expectEqualStrings("commons.pack", fileName("C:\\some\\where\\commons.pack"));
    try t.expectEqualStrings("commons.pack", fileName("commons.pack"));
    try t.expect(std.mem.indexOfScalar(u8, a.text, '\\') == null);
}

test "a need the machine does not grant is refused at the line of the pack that asked" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var r = Refusal{};
    // the host grants no network, and the pack's NEEDS clause is on line 5 of the PACK
    const host = "DEFINE MACHINE m AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE \"x\"\n";
    const pack = "-- a\n-- b\n-- c\nDEFINE SERVICE s AS (\n  RUN [\"/s\"],\n  NEEDS [network]\n) RATIONALE \"x\"\n";
    try t.expectError(error.Refused, placeOne(arena, host, pack, &r));
    try t.expectEqualStrings("commons.pack", r.file);
    try t.expectEqual(@as(usize, 6), r.line);
    try t.expect(std.mem.indexOf(u8, r.message, "which no declaration grants") != null);
}

test "a name taken by the machine or by an earlier pack is refused in the pack's own terms" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var r = Refusal{};
    // a service with the machine's own service's name: kds is line 5 of the machine
    const pack = "DEFINE SERVICE kds AS (RUN [\"/other\"], NEEDS [network]) RATIONALE \"x\"\n";
    try t.expectError(error.Refused, placeOne(arena, host_ok, pack, &r));
    try t.expectEqualStrings("commons.pack", r.file);
    try t.expectEqual(@as(usize, 1), r.line);
    try t.expect(std.mem.indexOf(u8, r.message, "(line 5 of host.machine)") != null);
    // two packs that both declare `commons`: the second is refused, naming the first
    const two = [_]Input{
        .{ .name = "a.pack", .source = "\n\nDEFINE SERVICE commons AS (RUN [\"/a\"], NEEDS [network]) RATIONALE \"x\"\n" },
        .{ .name = "b.pack", .source = "DEFINE SERVICE commons AS (RUN [\"/b\"], NEEDS [network]) RATIONALE \"x\"\n" },
    };
    try t.expectError(error.Refused, place(arena, .{ .name = "host.machine", .source = host_ok }, &two, &r));
    try t.expectEqualStrings("b.pack", r.file);
    try t.expect(std.mem.indexOf(u8, r.message, "(line 3 of a.pack)") != null);
}

test "a pack carries SERVICE and USER and nothing else, and says whose the rest is" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var r = Refusal{};
    try t.expectError(error.Refused, placeOne(arena, host_ok, "DEFINE CAPABILITY network AS (GRANT yes) RATIONALE \"x\"\nDEFINE SERVICE s AS (RUN [\"/s\"]) RATIONALE \"x\"\n", &r));
    try t.expect(std.mem.indexOf(u8, r.message, "CAPABILITY is the machine's to declare") != null);
    try t.expectEqual(@as(usize, 1), r.line);
    try t.expectError(error.Refused, placeOne(arena, host_ok, "DEFINE FLEET f AS (LINK a) RATIONALE \"x\"\n", &r));
    try t.expect(std.mem.indexOf(u8, r.message, "belongs to a fleet file") != null);
    try t.expectError(error.Refused, placeOne(arena, host_ok, "-- nothing\n", &r));
    try t.expect(std.mem.indexOf(u8, r.message, "declares nothing") != null);
    try t.expectError(error.Refused, placeOne(arena, host_ok, "DEFINE USER u AS (UID 3000) RATIONALE \"x\"\n", &r));
    try t.expect(std.mem.indexOf(u8, r.message, "places nothing") != null);
}

test "a machine refused on its own is refused as the machine, before anything is placed" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var r = Refusal{};
    try t.expectError(error.Refused, placeOne(arena, "DEFINE MACHINE m AS (ARCH x86_64, KERNEL linux) RATIONALE \"x\"\n", pack_ok, &r));
    try t.expectEqualStrings("host.machine", r.file);
    try t.expect(std.mem.indexOf(u8, r.message, "refused before anything is placed on it") != null);
}

test "a refusal in a pack that starts after a machine of several lines is numbered in the pack's own lines" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var r = Refusal{};
    // the machine court refuses the LATER of two READY paths, which is the pack's
    const host = host_ok ++ "DEFINE SERVICE a AS (RUN [\"/a\"], RESTART always, READY \"/run/x.ready\") RATIONALE \"x\"\n";
    const pack = "DEFINE SERVICE b AS (\n  RUN [\"/b\"],\n  RESTART always,\n  READY \"/run/x.ready\"\n) RATIONALE \"x\"\n";
    try t.expectError(error.Refused, placeOne(arena, host, pack, &r));
    try t.expectEqualStrings("commons.pack", r.file);
    try t.expectEqual(@as(usize, 4), r.line);
}

test "a machine file with no final newline gets one, and each pack is set off by a blank line" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var r = Refusal{};
    const host = "DEFINE MACHINE m AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE \"x\"";
    const pack = "DEFINE SERVICE s AS (RUN [\"/s\"]) RATIONALE \"x\"";
    const p = try placeOne(arena, host, pack, &r);
    // the machine's last line ends, then one blank line, then the banner, then the pack's own text
    try t.expect(std.mem.indexOf(u8, p.text, "RATIONALE \"x\"\n\n-- placed by harb place: commons.pack sha256:") != null);
    try t.expect(std.mem.endsWith(u8, p.text, "RATIONALE \"x\"\n"));
}

test "a line of the placed text is found in the file that wrote it, and the banner belongs to none" {
    const t = std.testing;
    // a machine of 5 lines, a pack of 5 under a banner on 7, a second of 6 under one on 14
    const regions = [_]Region{
        .{ .file = "host.machine", .first = 1, .last = 5, .is_pack = false },
        .{ .file = "a.pack", .first = 8, .last = 12, .is_pack = true },
        .{ .file = "b.pack", .first = 15, .last = 20, .is_pack = true },
    };
    try t.expectEqualStrings("host.machine", locate(&regions, 1).?.region.file);
    try t.expectEqual(@as(usize, 5), locate(&regions, 5).?.own);
    try t.expect(locate(&regions, 6) == null); // the blank line
    try t.expect(locate(&regions, 7) == null); // the banner
    try t.expectEqual(@as(usize, 1), locate(&regions, 8).?.own);
    try t.expectEqualStrings("a.pack", locate(&regions, 12).?.region.file);
    try t.expectEqual(@as(usize, 5), locate(&regions, 12).?.own);
    try t.expect(locate(&regions, 13) == null);
    try t.expect(locate(&regions, 14) == null);
    try t.expectEqualStrings("b.pack", locate(&regions, 15).?.region.file);
    try t.expectEqual(@as(usize, 6), locate(&regions, 20).?.own);
    try t.expect(locate(&regions, 21) == null);
}

test "a refusal that lands in the machine's own lines says it came with the placement" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const regions = [_]Region{
        .{ .file = "host.machine", .first = 1, .last = 5, .is_pack = false },
        .{ .file = "a.pack", .first = 8, .last = 12, .is_pack = true },
    };
    const in_host = try attribute(arena, &regions, 3, "x is refused");
    try t.expectEqualStrings("host.machine", in_host.file);
    try t.expectEqual(@as(usize, 3), in_host.line);
    try t.expect(std.mem.indexOf(u8, in_host.message, "the machine passes alone") != null);
    // in a pack it is the court's own words, untouched
    const in_pack = try attribute(arena, &regions, 10, "x is refused");
    try t.expectEqualStrings("a.pack", in_pack.file);
    try t.expectEqual(@as(usize, 3), in_pack.line);
    try t.expectEqualStrings("x is refused", in_pack.message);
    // and one that lands on no file's line is not pinned on one
    const nowhere = try attribute(arena, &regions, 7, "x is refused");
    try t.expectEqualStrings("the placed text", nowhere.file);
    try t.expectEqual(@as(usize, 7), nowhere.line);
}
