// mirroraudit.zig -- a copy read back and judged, by something that never held the secret (MIR-1, STZ-OS-RULING-19).
//
// A copy that nobody can check is a file of the same name. The source signed a listing of what it gave; the
// destination kept that listing beside the copy; and this reads the two against each other. It needs no kernel and
// no secret: the source's PUBLIC key is the only thing that gives the listing weight, and the digests in it are the
// only thing that gives the files weight. There are two readers, and they share every question (`mirror.verify` for the
// listing, `mirror.verifyCopy` for the files):
//
//   `harb mirror check`    run as a world INSIDE the destination: it reads its own declaration for the key it
//                          was told and the place it keeps the copy, its own device key for the fingerprint the
//                          listing must have been cut for, and says whether the copy it holds is the source's
//                          word. It exits 0 only for a verified copy.
//   `harb mirror verify`   run on a host with the fleet file and the two things the destination holds (the listing
//                          and the directory): the fleet's keys are the only ones it needs.
//
// "No copy yet" and "a copy that does not match" are different sentences with the same exit code and a
// different cause, and so is "nobody answered": the line the puller keeps beside the copy says which, and is
// printed here in its own words.

const std = @import("std");
const fleet = @import("fleet.zig");
const machine = @import("machine.zig");
const mirror = @import("mirror.zig");
const journal = @import("journal.zig");
const Ed25519 = std.crypto.sign.Ed25519;
const Sha256 = std.crypto.hash.sha2.Sha256;
const builtin = @import("builtin");

fn exists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// "1 file", "2 files": a sentence a person reads is not "1 file(s)".
fn count(buf: []u8, n: u64, one: []const u8, many: []const u8) []const u8 {
    return std.fmt.bufPrint(buf, "{d} {s}", .{ n, if (n == 1) one else many }) catch "?";
}

/// What a copy comes to, in a sentence: the same words from both readers.
fn summary(out: *std.Io.Writer, where: []const u8, rep: mirror.CopyReport) !void {
    var fb: [48]u8 = undefined;
    var db: [48]u8 = undefined;
    var bb: [48]u8 = undefined;
    try out.print("mirror: {s} -- {s}, {s}, {s}: every file matches the digest the source signed, and nothing else is there\n", .{
        where,
        count(&fb, rep.files, "file", "files"),
        count(&db, rep.dirs, "directory", "directories"),
        count(&bb, rep.bytes, "byte", "bytes"),
    });
}

/// The line the puller keeps about its last attempt, or null if it has made none that was kept.
fn lastAttempt(arena: std.mem.Allocator, into: []const u8) ?[]const u8 {
    const path = std.fmt.allocPrint(arena, "{s}{s}", .{ into, mirror.kept_last_suffix }) catch return null;
    const text = std.fs.cwd().readFileAlloc(arena, path, 4096) catch return null;
    const t = std.mem.trim(u8, text, " \r\n");
    return if (t.len == 0) null else t;
}

/// The device key at `path`, or null: the seed is 32 bytes and nothing else.
fn deviceKey(path: []const u8) ?Ed25519.KeyPair {
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    const f = std.fs.cwd().openFile(path, .{}) catch return null;
    defer f.close();
    const n = f.readAll(&seed) catch return null;
    if (n != seed.len) return null;
    return Ed25519.KeyPair.generateDeterministic(seed) catch null;
}

/// What one reading of a kept copy comes to.
const Reading = union(enum) {
    /// no listing is kept: there is no copy
    none,
    /// a copy that is the listing's, exactly
    held: struct { listing: mirror.Manifest, rep: mirror.CopyReport },
    /// what is wrong with the listing or the copy, in a sentence
    problem: []const u8,
};

/// Read the kept listing against the key this machine was told, and the copy against the listing. No nonce is asked of
/// the listing, because the nonce was the request's and is not kept as one.
fn readCopy(arena: std.mem.Allocator, from: machine.MirrorFrom, man_path: []const u8, source: Ed25519.PublicKey, me: [16]u8) !Reading {
    const text = std.fs.cwd().readFileAlloc(arena, man_path, mirror.max_manifest_bytes + 1) catch |e| switch (e) {
        error.FileNotFound => return .none,
        else => return .{ .problem = try std.fmt.allocPrint(arena, "cannot read {s}: {s}", .{ man_path, @errorName(e) }) },
    };
    const listing = switch (mirror.verify(arena, text, source, me, null)) {
        .ok => |l| l,
        .bad => |v| return .{ .problem = try std.fmt.allocPrint(arena, "the listing kept in {s} {s}", .{ man_path, v.words() }) },
    };
    var dir = std.fs.cwd().openDir(from.into, .{ .iterate = true }) catch |e| {
        return .{ .problem = try std.fmt.allocPrint(arena, "{s} is not there as a directory: {s}", .{ from.into, @errorName(e) }) };
    };
    defer dir.close();
    const rep = try mirror.verifyCopy(arena, dir, listing);
    if (rep.problem) |why| return .{ .problem = try std.fmt.allocPrint(arena, "{s} does not match its listing -- {s}", .{ from.into, why }) };
    return .{ .held = .{ .listing = listing, .rep = rep } };
}

/// What `harb mirror check` was asked: how long to wait, and two ways of asking after the attempt the puller made.
///
/// Without either, a copy left by an earlier boot is judged as it stands, which is what a witness of a copy that outlives
/// the source wants. With `fresh` the witness waits for the puller to ask once more and then says what that attempt came
/// to -- `ok`, or `silent`, `refused`, `unverified`, `failed` -- beside the copy it judged: the exit code is the COPY's,
/// and a source that was down shows in the line and not in the code. With `follow` the attempt must also have reached the
/// source and come to `ok`, or the exit is 1: that is "the copy follows the source", told from "the copy is the one that
/// was there".
pub const Options = struct {
    wait_s: u32 = 0,
    fresh: bool = false,
    follow: bool = false,
};

/// Whether the line a puller keeps is that of an attempt that came to a verified copy.
fn cameToOk(line: []const u8) bool {
    if (!std.mem.startsWith(u8, line, mirror.attempt_ok)) return false;
    return line.len == mirror.attempt_ok.len or line[mirror.attempt_ok.len] == ' ';
}

/// Whether the line the puller keeps about its last attempt was written no earlier than `began` (nanoseconds since the
/// epoch, the clock the file's modification time is read from).
fn attemptedSince(arena: std.mem.Allocator, into: []const u8, began: i128) bool {
    const path = std.fmt.allocPrint(arena, "{s}{s}", .{ into, mirror.kept_last_suffix }) catch return false;
    const st = std.fs.cwd().statFile(path) catch return false;
    return st.mtime >= began;
}

/// `harb mirror check [<machine>] [--wait N] [--fresh | --follow]`: is the copy this machine keeps the source's word? Waits
/// up to N seconds for the first copy to arrive (a boot's first pull is a moment after the network comes up), or with
/// `--fresh` for the next attempt, and then says what there is. Exit 0 only for a copy that verifies, and with `--follow`
/// only for one that the attempt just made brought from the source.
pub fn check(arena: std.mem.Allocator, m: machine.Machine, opts: Options, out: *std.Io.Writer) !u8 {
    const began = std.time.nanoTimestamp();
    const fresh = opts.fresh or opts.follow;
    const from = m.mirror_from orelse {
        try out.print("mirror: {s} declares no MIRROR_FROM, so it keeps no copy to check\n", .{m.name});
        return 1;
    };
    const key_path = m.identity orelse {
        try out.print("mirror: {s} declares no IDENTITY, so nothing says which device a listing was cut for\n", .{m.name});
        return 1;
    };
    const pair = deviceKey(key_path) orelse {
        try out.print("mirror: cannot read this device's key at {s}\n", .{key_path});
        return 1;
    };
    const me = journal.fingerprintOf(pair.public_key.toBytes());
    const source = Ed25519.PublicKey.fromBytes(from.key) catch {
        try out.print("mirror: MIRROR_KEY is not a public key\n", .{});
        return 1;
    };

    const man_path = try std.fmt.allocPrint(arena, "{s}{s}", .{ from.into, mirror.kept_manifest_suffix });
    var waited: u32 = 0;
    while (waited < opts.wait_s) : (waited += 1) {
        if (if (fresh) attemptedSince(arena, from.into, began) else exists(man_path)) break;
        std.Thread.sleep(std.time.ns_per_s);
    }
    if (fresh and !attemptedSince(arena, from.into, began)) {
        try out.print("mirror: no attempt was made in the {d} s this witness waited: the puller is not running, or one pull takes longer than that\n", .{opts.wait_s});
        return 1;
    }
    // A copy is read twice before it is convicted: the puller swaps a new one in with renames, and a reading made across
    // the swap (the listing of one copy, the files of the other) is a mismatch that nothing is wrong with. A copy that is
    // really wrong is wrong a second later too.
    var reading = try readCopy(arena, from, man_path, source, me);
    if (reading == .problem) {
        std.Thread.sleep(std.time.ns_per_s);
        reading = try readCopy(arena, from, man_path, source, me);
    }
    switch (reading) {
        .none => {
            try out.print("mirror: no copy yet -- {s} is not there", .{man_path});
            if (lastAttempt(arena, from.into)) |l| try out.print("; last attempt -- {s}", .{l});
            try out.print("\n", .{});
            return 1;
        },
        .problem => |why| {
            try out.print("mirror: {s}\n", .{why});
            return 1;
        },
        .held => |h| {
            try summary(out, from.into, h.rep);
            try out.print("mirror: the listing was signed by {s} for this device ({s}), and verifies against the key this machine was told\n", .{ &h.listing.source, &me });
        },
    }
    const last = lastAttempt(arena, from.into);
    if (last) |l| try out.print("mirror: last attempt -- {s}\n", .{l});
    if (opts.follow and !(if (last) |l| cameToOk(l) else false)) {
        try out.print("mirror: --follow asked whether the copy follows the source, and the attempt made since this witness began did not bring it: the copy above is the source's word as of an earlier pull\n", .{});
        return 1;
    }
    return 0;
}

/// Read `harb mirror check`'s arguments: `--wait N`, `--fresh` and `--follow` (which is `--fresh` and more), in any order,
/// beside an optional machine file.
pub fn optionsOf(args: []const []const u8) Options {
    var o = Options{};
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--fresh")) o.fresh = true;
        if (std.mem.eql(u8, args[i], "--follow")) {
            o.follow = true;
            o.fresh = true;
        }
        if (std.mem.eql(u8, args[i], "--wait") and i + 1 < args.len) o.wait_s = std.fmt.parseInt(u32, args[i + 1], 10) catch 0;
    }
    return o;
}

/// `harb mirror verify <file.fleet> <mirror> <listing> <dir>`: is this directory the copy the fleet's MIRROR says it is?
/// The listing is judged against the key the fleet holds for the source and for the device it was cut for; the files
/// against the digests the listing carries. No secret takes part, and nothing is asked of the machines: it is what
/// anybody holding the fleet file, the listing and the directory can say. Exit 0 only for a copy that verifies.
pub fn verify(arena: std.mem.Allocator, args: []const []const u8, out: *std.Io.Writer) !u8 {
    if (args.len != 4) {
        try out.print("harb: mirror verify takes a fleet file, the name of one of its MIRRORs, the listing the keeper kept and the directory it keeps\n", .{});
        return 1;
    }
    const src = std.fs.cwd().readFileAlloc(arena, args[0], 1 << 20) catch |e| {
        try out.print("harb: cannot read {s}: {s}\n", .{ args[0], @errorName(e) });
        return 1;
    };
    const disk = fleet.Disk{ .arena = arena, .base = std.fs.path.dirname(args[0]) orelse "" };
    var refusal = fleet.Refusal{};
    const f = fleet.declare(arena, src, disk.resolver(), &refusal) catch |e| switch (e) {
        error.Refused => {
            try out.print("fleet (line {d}): {s}\n", .{ refusal.line, refusal.message });
            return 1;
        },
        else => return e,
    };
    var found: ?fleet.Mirror = null;
    for (f.mirrors) |mr| if (std.mem.eql(u8, mr.name, args[1])) {
        found = mr;
    };
    const mr = found orelse {
        try out.print("mirror: fleet {s} declares no MIRROR called {s}\n", .{ f.name, args[1] });
        return 1;
    };
    // the fleet court judged that both ends are members and that both are enrolled
    const sm = f.member(mr.from).?;
    const dm = f.member(mr.to).?;
    try out.print("mirror: fleet {s}, MIRROR {s} -- {s} (enrolled as {s}) gives {s} to {s} (enrolled as {s})\n", .{ f.name, mr.name, mr.from, sm.fingerprint.?[0..], sm.machine.mirror_of.?.dir, mr.to, dm.fingerprint.?[0..] });

    const text = std.fs.cwd().readFileAlloc(arena, args[2], mirror.max_manifest_bytes + 1) catch |e| {
        try out.print("harb: cannot read {s}: {s}\n", .{ args[2], @errorName(e) });
        return 1;
    };
    const listing = switch (mirror.verify(arena, text, sm.key.?, dm.fingerprint.?, null)) {
        .ok => |l| l,
        .bad => |v| {
            try out.print("mirror: the listing {s} {s}\n", .{ args[2], v.words() });
            return 1;
        },
    };
    var dir = std.fs.cwd().openDir(args[3], .{ .iterate = true }) catch |e| {
        try out.print("harb: cannot open {s}: {s}\n", .{ args[3], @errorName(e) });
        return 1;
    };
    defer dir.close();
    const rep = try mirror.verifyCopy(arena, dir, listing);
    if (rep.problem) |why| {
        try out.print("mirror: {s} does not match its listing -- {s}\n", .{ args[3], why });
        return 1;
    }
    try summary(out, args[3], rep);
    try out.print("mirror: the listing was signed by {s} for {s}, the two keys this fleet holds, and no secret took part\n", .{ &listing.source, &listing.puller });
    return 0;
}

// ---- tests ---------------------------------------------------------------------------------------------

fn pairOf(byte: u8) !Ed25519.KeyPair {
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, byte);
    return Ed25519.KeyPair.generateDeterministic(seed);
}

test "the arguments of check are read in any order, and --follow is --fresh and more (MIR-1)" {
    const o = optionsOf(&.{ "--wait", "60", "--follow" });
    try std.testing.expectEqual(@as(u32, 60), o.wait_s);
    try std.testing.expect(o.follow and o.fresh);
    const f = optionsOf(&.{ "--fresh", "/etc/machine", "--wait", "5" });
    try std.testing.expect(f.fresh and !f.follow);
    try std.testing.expectEqual(@as(u32, 5), f.wait_s);
    const none = optionsOf(&.{});
    try std.testing.expect(!none.fresh and !none.follow and none.wait_s == 0);
}

test "the word of an attempt that came to a copy is the puller's own, whole (MIR-1)" {
    try std.testing.expect(cameToOk("ok files=4 dirs=2 bytes=300066"));
    try std.testing.expect(cameToOk("ok"));
    try std.testing.expect(!cameToOk("okay"));
    try std.testing.expect(!cameToOk("silent nobody answered at 10.30.0.1:7400"));
    try std.testing.expect(!cameToOk("refused ok"));
    try std.testing.expect(!cameToOk(""));
}

/// Say `line` as the line about the last attempt, `delay_ms` from now: the puller of a machine, from a thread.
const LateLine = struct {
    fn run(path: []const u8, line: []const u8, delay_ms: u64) void {
        std.Thread.sleep(delay_ms * std.time.ns_per_ms);
        std.fs.cwd().writeFile(.{ .sub_path = path, .data = line }) catch {};
    }
};

test "check judges the copy as it stands, and only --follow asks whether the attempt reached the source (MIR-1)" {
    // the file modification time `--fresh` reads is the kernel's, and the tests that read it run where it is
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realpathAlloc(arena, ".");

    // the disk of a keeper after a pull: the device's key, the copy, and the listing the copy was verified against
    const source = try pairOf(0x41);
    const device = try pairOf(0x42);
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, 0x42);
    try tmp.dir.writeFile(.{ .sub_path = "device.key", .data = &seed });
    try tmp.dir.makePath("copy");
    try tmp.dir.writeFile(.{ .sub_path = "copy/f", .data = "data" });
    var digest: [32]u8 = undefined;
    Sha256.hash("data", &digest, .{});
    const entries = [_]mirror.Entry{.{ .kind = .file, .path = "f", .size = 4, .digest = digest }};
    var nonce: [mirror.nonce_len]u8 = undefined;
    @memset(&nonce, 3);
    const listing = try mirror.build(arena, source, journal.fingerprintOf(device.public_key.toBytes()), nonce, "/data/app", &entries);
    try tmp.dir.writeFile(.{ .sub_path = "copy.manifest", .data = listing });

    // the machine that keeps it, declared by the court, and then pointed at this directory
    const declared = try std.fmt.allocPrint(arena,
        \\DEFINE MACHINE k AS (PROFILE hosted, ARCH x86_64, KERNEL linux, IDENTITY "/data/device.key", MIRROR_FROM "10.30.0.9:7400", MIRROR_KEY "{x}", MIRROR_INTO "/data/copy") RATIONALE "x"
        \\DEFINE CAPABILITY network AS (GRANT yes) RATIONALE "x"
        \\DEFINE CAPABILITY filesystem AS (GRANT yes) RATIONALE "x"
        \\DEFINE MOUNT data AS (AT "/data", FS ext4, DEVICE "/dev/vda", OPTIONS [rw]) RATIONALE "x"
        \\DEFINE NETWORK lan AS (INTERFACE "eth0", ADDRESS "10.30.0.2/24") RATIONALE "x"
        \\
    , .{&source.public_key.toBytes()});
    var refusal = machine.Refusal{};
    var m = try machine.declare(arena, declared, &refusal);
    m.identity = try std.fmt.allocPrint(arena, "{s}/device.key", .{base});
    const into = try std.fmt.allocPrint(arena, "{s}/copy", .{base});
    m.mirror_from.?.into = into;
    const last = try std.fmt.allocPrint(arena, "{s}.last", .{into});

    // without --fresh: the copy as it stands, at once, and no attempt asked of
    {
        var aw = std.Io.Writer.Allocating.init(arena);
        const code = try check(arena, m, .{}, &aw.writer);
        try std.testing.expectEqual(@as(u8, 0), code);
        try std.testing.expect(std.mem.indexOf(u8, aw.written(), "every file matches the digest the source signed") != null);
    }
    // --follow with an attempt that came to a copy: followed
    {
        const t = try std.Thread.spawn(.{}, LateLine.run, .{ last, "ok files=1 dirs=0 bytes=4\n", 300 });
        defer t.join();
        var aw = std.Io.Writer.Allocating.init(arena);
        const code = try check(arena, m, .{ .wait_s = 5, .follow = true }, &aw.writer);
        try std.testing.expectEqual(@as(u8, 0), code);
        try std.testing.expect(std.mem.indexOf(u8, aw.written(), "last attempt -- ok files=1") != null);
    }
    // the source is down: the same copy, an attempt that reached nobody. --fresh says so and exits for the COPY; --follow
    // exits 1, because the copy is not the source's word as of now
    for ([_]bool{ false, true }) |follow| {
        const t = try std.Thread.spawn(.{}, LateLine.run, .{ last, "silent nobody answered at 10.30.0.9:7400\n", 300 });
        defer t.join();
        var aw = std.Io.Writer.Allocating.init(arena);
        const code = try check(arena, m, .{ .wait_s = 5, .fresh = !follow, .follow = follow }, &aw.writer);
        try std.testing.expectEqual(@as(u8, if (follow) 1 else 0), code);
        try std.testing.expect(std.mem.indexOf(u8, aw.written(), "last attempt -- silent nobody answered") != null);
        try std.testing.expectEqual(follow, std.mem.indexOf(u8, aw.written(), "--follow asked whether the copy follows the source") != null);
    }
    // no attempt at all in the time asked for: said, whichever of the two was asked
    try tmp.dir.deleteFile("copy.last");
    for ([_]bool{ false, true }) |follow| {
        var aw = std.Io.Writer.Allocating.init(arena);
        const code = try check(arena, m, .{ .wait_s = 1, .fresh = !follow, .follow = follow }, &aw.writer);
        try std.testing.expectEqual(@as(u8, 1), code);
        try std.testing.expect(std.mem.indexOf(u8, aw.written(), "no attempt was made in the 1 s") != null);
    }
}
