// harb -- one static binary, every role. On the host it is the CLI
// (check, plan, court); on a hosted machine the same binary is PID 1
// (init). Cross-compiling it for the machine is one flag (`zig build
// cross`), and the image carries nothing else on its boot path: no
// shell, no service manager, no package manager -- the declared machine
// IS the system.
//
//   harb check  <file.machine>                 judge a declaration
//   harb plan   <file.machine>                 print the boot plan
//   harb court  [declarative/machine/fixtures.json]
//   harb init   <file.machine> [--rehearse] [--turns N]
//   harb version

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");
const plan = @import("plan.zig");
const court = @import("court.zig");
const init = @import("init.zig");
const image = @import("image.zig");
const net = @import("net.zig");
const netcfg = @import("netcfg.zig");
const names = @import("names.zig");
const update = @import("update.zig");
const project = @import("project.zig");
const guarantee = @import("guarantee.zig");
const journal = @import("journal.zig");
const learn = @import("learn.zig");
const docs = @import("docs.zig");
const fleet = @import("fleet.zig");
const pack = @import("pack.zig");
const confine = @import("confine.zig");
const expect = @import("expect.zig");

pub const version = "0.1.0";
const default_fixtures = "declarative/machine/fixtures.json";
const default_fleet_fixtures = "declarative/fleet/fixtures.json";
const default_pack_fixtures = "declarative/pack/fixtures.json";

fn usage(out: *std.Io.Writer) !void {
    try out.print(
        \\harb {s} -- the declared machine ({s}-{s})
        \\  harb check  <file.machine>
        \\  harb plan   <file.machine>
        \\  harb court  [fixtures.json]        (default: {s})
        \\  harb init   <file.machine> [--rehearse] [--turns N] [--hold] [--halt-on-verdict]
        \\  harb update <dir> [--boot <mountpoint>] [--no-reboot]   (write the other slot, try it once)
        \\  harb image  <file.machine> --root <staging dir> --out <image dir>
        \\  harb project <file.machine> --out <dir>     (an edge machine, onto MicroRing's substrate)
        \\  harb guarantees <file.machine> <text>       (the hosted profile's four promises, judged)
        \\  harb judge  <file.machine> <transcript> [--lens emulator]   (a captured boot, against what the machine expects)
        \\  harb net    <iface> <a.b.c.d>/<prefix> [gateway] | <iface> dhcp   (by hand, what init does for a NETWORK)
        \\  harb id                                     (uid and gid, from inside a machine)
        \\  harb reach  <a.b.c.d>                       (does this machine know a way there? from inside it)
        \\  harb confined [iface] [path...]             (what can this WORLD see and do? from inside one)
        \\  harb swarm  [n]                             (ask for n tasks and say where the kernel stopped; from inside a world)
        \\  harb ask    <name>                          (what does a name mean on this network? from inside a device on it)
        \\  harb attest [file.machine]                  (sign with this device's key and verify it, from inside it)
        \\  harb journal [file.machine]                 (this machine's own record: every entry verified, or the one that broke)
        \\  harb fleet  <file.fleet> [verify <member> <record> | hardware <member>]   (machines judged together; one device's record checked by another)
        \\  harb court  --fleet [declarative/fleet/fixtures.json]
        \\  harb place  <file.machine> <file.pack>... [--out <file>]   (a solution's services, placed on a machine and judged as one)
        \\  harb court  --pack [declarative/pack/fixtures.json]
        \\  harb learn  [n] [--all] [--words] [--run] [--check]   (the guided tour: what this machine does, and how to break it)
        \\  harb docs   --check                         (every page's code fits its column, and every machine it shows is accepted)
        \\  harb version
        \\
    , .{ version, @tagName(builtin.cpu.arch), @tagName(builtin.os.tag), default_fixtures });
}

/// The first argument that is not a flag. A verb that takes an optional
/// file AND optional flags must not read "--export" as a filename, which
/// is how the fleet witness first failed: the device refused to publish
/// and said FileNotFound about a flag (FLT-1).
fn firstPath(args: []const []const u8) ?[]const u8 {
    for (args) |a| if (!std.mem.startsWith(u8, a, "--")) return a;
    return null;
}

fn load(arena: std.mem.Allocator, path: []const u8, out: *std.Io.Writer) !?machine.Machine {
    const src = std.fs.cwd().readFileAlloc(arena, path, 1 << 20) catch |e| {
        try out.print("harb: cannot read {s}: {s}\n", .{ path, @errorName(e) });
        return null;
    };
    var refusal = machine.Refusal{};
    const m = machine.declare(arena, src, &refusal) catch |e| switch (e) {
        error.Refused => {
            try out.print("machine (line {d}): {s}\n", .{ refusal.line, refusal.message });
            return null;
        },
        else => return e,
    };
    return m;
}

pub fn main() !u8 {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Streaming, not positional: on a seekable stdout (a redirected
    // transcript) the default writer starts at offset 0 and overwrites what
    // the shell wrote before it -- found on the first WSL transcript
    // (experiment/PROTOCOL.md, OS-1 finding 2). A console never shows it;
    // a redirected file always does.
    var buf: [8192]u8 = undefined;
    var w = std.fs.File.stdout().writerStreaming(&buf);
    const out = &w.interface;
    defer out.flush() catch {};

    const args = try std.process.argsAlloc(arena);
    if (args.len < 2) {
        try usage(out);
        return 1;
    }
    const verb = args[1];

    if (std.mem.eql(u8, verb, "docs")) {
        // What a page SHOWS is a claim like any other: a code line the
        // reader has to scroll sideways to read, or a machine the court
        // would refuse, is the page lying about how it reads or about the
        // machine (DOC-1). Run from the repository root, as the court runs it.
        if (args.len != 3 or !std.mem.eql(u8, args[2], "--check")) {
            try out.print("harb: usage: harb docs --check  (from the repository root)\n", .{});
            return 1;
        }
        const bad = try docs.check(out);
        return if (bad == 0) 0 else 1;
    }

    if (std.mem.eql(u8, verb, "learn")) {
        // The tour lives in the binary, beside the verbs it teaches, so
        // `--check` can walk every path a lesson names and the court can
        // run that check. A tutorial in a document has no judge, and a
        // guarantee you have only seen SUCCEED is a claim (LRN-1).
        var n: ?usize = null;
        var want_all = false;
        var want_check = false;
        var want_run = false;
        var want_words = false;
        for (args[2..]) |a| {
            if (std.mem.eql(u8, a, "--all")) want_all = true
            else if (std.mem.eql(u8, a, "--check")) want_check = true
            else if (std.mem.eql(u8, a, "--run")) want_run = true
            else if (std.mem.eql(u8, a, "--words")) want_words = true
            else n = std.fmt.parseInt(usize, a, 10) catch null;
        }
        if (want_check) {
            const missing = try learn.check(out);
            return if (missing == 0) 0 else 1;
        }
        if (want_words) {
            try learn.glossary(out);
            return 0;
        }
        if (want_all) {
            try learn.all(out);
            return 0;
        }
        const which = n orelse {
            try learn.list(out);
            return 0;
        };
        if (which == 0 or which > learn.lessons.len) {
            try out.print("harb: there are {d} lessons\n", .{learn.lessons.len});
            return 1;
        }
        try learn.one(out, which);
        if (!want_run) return 0;
        const l = learn.lessons[which - 1];
        if (!l.runnable) {
            // the boots are WSL scripts and the read-only lessons have no
            // command at all: say which, rather than "copy the command
            // above" when there is none
            if (l.run[0] == '(') {
                try out.print("  (nothing to run -- this lesson reads the output of another one)\n\n", .{});
            } else {
                try out.print("  (not this binary's to run -- copy the command above into a terminal)\n\n", .{});
            }
            return 0;
        }
        // spawn OURSELVES with the lesson's own words, so what runs is
        // exactly what the lesson printed and not a paraphrase of it
        var it = std.mem.tokenizeScalar(u8, l.run[learn.exe.len + 1 ..], ' ');
        var argv: std.ArrayList([]const u8) = .{};
        try argv.append(arena, args[0]);
        while (it.next()) |word| try argv.append(arena, word);
        try out.print("  RUNNING\n\n", .{});
        try out.flush();
        var child = std.process.Child.init(argv.items, arena);
        _ = child.spawnAndWait() catch |e| {
            try out.print("  could not run it: {s}\n", .{@errorName(e)});
            return 1;
        };
        return 0;
    }
    if (std.mem.eql(u8, verb, "version")) {
        try out.print("harb {s}\n", .{version});
        return 0;
    }
    if (std.mem.eql(u8, verb, "id")) {
        // who a service actually runs as, from inside the machine: the
        // witness the USER seat is judged by (a machine has no coreutils)
        if (builtin.os.tag != .linux) {
            try out.print("id: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
            return 2;
        }
        try out.print("id: uid={d} gid={d}\n", .{ std.os.linux.getuid(), std.os.linux.getgid() });
        return 0;
    }
    if (std.mem.eql(u8, verb, "journal")) {
        // The record read back and checked, from inside the machine that
        // wrote it. An auditor reading this file elsewhere runs the same
        // check with the same public key; nothing here is privileged
        // except the private half, which never appears (JRN-1).
        const path = firstPath(args[2..]) orelse "/etc/machine";
        const m = (try load(arena, path, out)) orelse return 1;
        const rec_path = m.journal orelse {
            try out.print("journal: {s} declares no JOURNAL\n", .{m.name});
            return 1;
        };
        const key_path = m.identity orelse {
            try out.print("journal: {s} declares no IDENTITY, so nothing signed its record\n", .{m.name});
            return 1;
        };
        const Ed = std.crypto.sign.Ed25519;
        var seed: [Ed.KeyPair.seed_length]u8 = undefined;
        const kf = std.fs.cwd().openFile(key_path, .{}) catch |e| {
            try out.print("journal: cannot read {s}: {s}\n", .{ key_path, @errorName(e) });
            return 1;
        };
        defer kf.close();
        const kn = kf.readAll(&seed) catch 0;
        if (kn != seed.len) {
            try out.print("journal: {s} is not a seed\n", .{key_path});
            return 1;
        }
        const pair = Ed.KeyPair.generateDeterministic(seed) catch |e| {
            try out.print("journal: the key could not be derived: {s}\n", .{@errorName(e)});
            return 1;
        };
        const text = std.fs.cwd().readFileAlloc(arena, rec_path, 1 << 20) catch |e| switch (e) {
            // the first boot of a device has nothing to read: PID 1
            // writes this boot's entry after the verdict, which is after
            // every world has run. That is an order, not a fault.
            error.FileNotFound => {
                try out.print("journal {s} -- no record yet: this is the first boot, and its entry is written after the verdict\n", .{rec_path});
                return 0;
            },
            else => {
                try out.print("journal: cannot read {s}: {s}\n", .{ rec_path, @errorName(e) });
                return 1;
            },
        };
        // A record that cannot leave the machine can only be checked by
        // the machine, which is attribution nobody else can test. With
        // --export the entries come out as the exact bytes that were
        // signed, ready to be verified by any holder of the fleet file.
        for (args[2..]) |a| if (std.mem.eql(u8, a, "--export")) {
            var lines = std.mem.splitScalar(u8, text, '\n');
            while (lines.next()) |raw| {
                const line = std.mem.trimRight(u8, raw, "\r");
                if (line.len == 0) continue;
                try out.print("record {s}\n", .{line});
            }
        };
        const check = journal.verify(text, pair.public_key);
        if (check.broken_at) |n| {
            try out.print("journal {s} -- entry {d} does not verify: {s}\n", .{ rec_path, n, check.reason });
            try out.print("journal: {d} entr{s} verified before it\n", .{ check.verified, if (check.verified == 1) "y" else "ies" });
            return 1;
        }
        try out.print("journal {s} -- {d} entr{s}, every one chained to the one before it and signed by this device\n", .{ rec_path, check.verified, if (check.verified == 1) "y" else "ies" });
        var it = std.mem.splitScalar(u8, text, 10);
        while (it.next()) |raw| {
            const line = std.mem.trimRight(u8, raw, "\r");
            if (line.len == 0) continue;
            const cut = std.mem.indexOf(u8, line, " hash=") orelse line.len;
            try out.print("journal:   {s}\n", .{line[0..cut]});
        }
        return 0;
    }
    if (std.mem.eql(u8, verb, "attest")) {
        // The witness of the IDENTITY seat, as `reach` is EGRESS's and
        // `id` is USER's: it uses the device's own key and shows both
        // halves of what a signature is worth -- that it verifies, and
        // that it stops verifying the moment the message changes. The
        // second half is the one worth printing: a signature nobody
        // tried to break is a claim, not evidence.
        const path = firstPath(args[2..]) orelse "/etc/machine";
        const m = (try load(arena, path, out)) orelse return 1;
        const key_path = m.identity orelse {
            try out.print("attest: {s} declares no IDENTITY: this machine has no key to sign with\n", .{m.name});
            return 1;
        };
        const Ed = std.crypto.sign.Ed25519;
        var seed: [Ed.KeyPair.seed_length]u8 = undefined;
        const f = std.fs.cwd().openFile(key_path, .{}) catch |e| {
            try out.print("attest: cannot read {s}: {s}\n", .{ key_path, @errorName(e) });
            return 1;
        };
        defer f.close();
        const n = f.readAll(&seed) catch |e| {
            try out.print("attest: cannot read {s}: {s}\n", .{ key_path, @errorName(e) });
            return 1;
        };
        if (n != seed.len) {
            try out.print("attest: {s} is {d} bytes, and a seed is {d}\n", .{ key_path, n, seed.len });
            return 1;
        }
        const pair = Ed.KeyPair.generateDeterministic(seed) catch |e| {
            try out.print("attest: the key could not be derived: {s}\n", .{@errorName(e)});
            return 1;
        };
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "{s} attests", .{m.name}) catch "attests";
        const sig = pair.sign(msg, null) catch |e| {
            try out.print("attest: the signature failed: {s}\n", .{@errorName(e)});
            return 1;
        };
        const hex = journal.fingerprintOf(pair.public_key.toBytes());
        try out.print("attest {s} -- ed25519, fingerprint {s}\n", .{ m.name, hex });
        // ENROLMENT: the public half, in the form a fleet file takes.
        // A device may publish this and nothing else; the private half
        // has never left the partition it was made on. Behind a flag, so
        // the boots already pinned say exactly what they said before.
        for (args[2..]) |a| if (std.mem.eql(u8, a, "--export")) {
            try out.print("enrol {s} ed25519 {x} -- KEY for this machine's MEMBER in a fleet\n", .{ m.name, pair.public_key.toBytes() });
        };
        sig.verify(msg, pair.public_key) catch {
            try out.print("attest: the device's own signature did not verify -- this machine cannot prove it is itself\n", .{});
            return 1;
        };
        try out.print("attest: signed {d} bytes with this device's key and verified them against its public half\n", .{msg.len});
        // ... and the negative, which is the half that makes the first half mean anything
        var tampered_buf: [128]u8 = undefined;
        @memcpy(tampered_buf[0..msg.len], msg);
        tampered_buf[0] ^= 1;
        if (sig.verify(tampered_buf[0..msg.len], pair.public_key)) {
            try out.print("attest: A TAMPERED MESSAGE VERIFIED -- this signature proves nothing\n", .{});
            return 1;
        } else |_| {
            try out.print("attest: one bit flipped in the message, and the same signature is refused\n", .{});
        }
        return 0;
    }
    if (std.mem.eql(u8, verb, "fleet")) {
        // The fleet court on one file, and the act the fleet exists for.
        //
        // `harb fleet <file>` judges the set and prints the roll: who is
        // in it, what each one is, and -- the part that matters -- which
        // members nobody can yet speak for, because no key has been
        // enrolled. A refusal here is a fact about the SET; every machine
        // in it may be faultless alone (FLT-1).
        //
        // `harb fleet <file> verify <member> <record>` attributes a
        // signed boot record to a member using only the public key the
        // fleet holds. No secret takes part, so anyone holding the fleet
        // file can perform it: another box on the wire, the court here,
        // an auditor years from now.
        if (args.len < 3) {
            try out.print("harb: fleet takes a fleet file\n", .{});
            return 1;
        }
        const path = args[2];
        const src = std.fs.cwd().readFileAlloc(arena, path, 1 << 20) catch |e| {
            try out.print("harb: cannot read {s}: {s}\n", .{ path, @errorName(e) });
            return 1;
        };
        const dir = std.fs.path.dirname(path) orelse "";
        const disk = fleet.Disk{ .arena = arena, .base = dir };
        var refusal = fleet.Refusal{};
        const f = fleet.declare(arena, src, disk.resolver(), &refusal) catch |e| switch (e) {
            error.Refused => {
                try out.print("fleet (line {d}): {s}\n", .{ refusal.line, refusal.message });
                return 1;
            },
            else => return e,
        };

        if (args.len >= 4 and std.mem.eql(u8, args[3], "hardware")) {
            // One line, for a script that needs to plug this member in.
            // Before HDW-1 the hardware address of a device under test
            // was a constant in a shell script, which is the one place a
            // fact about a deployment must never live.
            if (args.len < 5) {
                try out.print("harb: fleet hardware takes a member\n", .{});
                return 1;
            }
            const m = f.member(args[4]) orelse {
                try out.print("fleet {s} -- there is no member called {s}\n", .{ f.name, args[4] });
                return 1;
            };
            const hw = m.hardware_text orelse {
                try out.print("fleet {s} -- {s} does not say which device it is\n", .{ f.name, args[4] });
                return 1;
            };
            try out.print("{s}\n", .{hw});
            return 0;
        }
        if (args.len >= 4 and std.mem.eql(u8, args[3], "verify")) {
            if (args.len < 6) {
                try out.print("harb: fleet verify takes a member and a record file\n", .{});
                return 1;
            }
            const who = args[4];
            const record = std.fs.cwd().readFileAlloc(arena, args[5], 1 << 20) catch |e| {
                try out.print("harb: cannot read {s}: {s}\n", .{ args[5], @errorName(e) });
                return 1;
            };
            switch (fleet.attribute(f, who, record)) {
                .verified => |c| {
                    const m = f.member(who).?;
                    try out.print("fleet {s} -- {s}: {d} entr{s} verified against the enrolled key (fingerprint {s}), and no secret took part\n", .{
                        f.name, who, c.verified, if (c.verified == 1) "y" else "ies", m.fingerprint.?[0..],
                    });
                    // The head is printed HERE and nowhere else: only after
                    // the chain has verified. A head copied out of a file
                    // nobody checked is a head somebody else may have
                    // chosen, and it is what a RETIREMENT would trust (RET-1).
                    if (c.has_last) try out.print("fleet {s} -- {s}: its head is entry {d}, hash={s} -- the entry a RETIREMENT of this key would be trusted THROUGH\n", .{
                        f.name, who, c.verified, c.last_hash[0..],
                    });
                    return 0;
                },
                .broken => |c| {
                    try out.print("fleet {s} -- {s}: entry {d} is not this device's: {s}\n", .{ f.name, who, c.broken_at.?, c.reason });
                    try out.print("fleet {s} -- {d} entr{s} verified before it\n", .{ f.name, c.verified, if (c.verified == 1) "y" else "ies" });
                    return 1;
                },
                .retired_verified => |r| {
                    const c = r.through.check;
                    try out.print("fleet {s} -- {s}: {d} entr{s} verified against a key it no longer holds (retired as {s}, fingerprint {s}), ending at the entry the fleet trusts that key through, and no secret took part\n", .{
                        f.name, who, c.verified, if (c.verified == 1) "y" else "ies", r.retirement.name, r.retirement.fingerprint[0..],
                    });
                    return 0;
                },
                .retired_broken => |r| {
                    const c = r.through.check;
                    if (c.broken_at) |at| {
                        try out.print("fleet {s} -- {s}: entry {d} is not this device's under the key retired as {s}: {s}\n", .{ f.name, who, at, r.retirement.name, c.reason });
                        // the stolen card, in its own words: entries the
                        // retired key REALLY signed, after it was retired
                        if (r.through.signed_after > 0) try out.print("fleet {s} -- {d} entr{s} from there on verif{s} under the retired key all the same: whoever still holds it signed after it was retired\n", .{
                            f.name, r.through.signed_after, if (r.through.signed_after == 1) "y" else "ies", if (r.through.signed_after == 1) "ies" else "y",
                        });
                        try out.print("fleet {s} -- {d} entr{s} verified before it\n", .{ f.name, c.verified, if (c.verified == 1) "y" else "ies" });
                    } else {
                        try out.print("fleet {s} -- {s}: every entry verifies under the key retired as {s}, and none is the entry the fleet trusts it through: a retired key vouches for one chain, the one that reaches its head, and a shorter record cannot be told from a chain its holder wrote since\n", .{ f.name, who, r.retirement.name });
                    }
                    return 1;
                },
                .empty => {
                    try out.print("fleet {s} -- {s}: the record carries no entry, so there is nothing to attribute: a verification of nothing is not one\n", .{ f.name, who });
                    return 1;
                },
                .unsigned => {
                    var held: usize = 0;
                    for (f.retirements) |r| {
                        if (std.mem.eql(u8, r.member, who)) held += 1;
                    }
                    try out.print("fleet {s} -- {s} holds no key today, and none of the {d} key{s} it has held signed this record\n", .{ f.name, who, held, if (held == 1) "" else "s" });
                    return 1;
                },
                .not_enrolled => {
                    try out.print("fleet {s} -- {s} has no KEY in this fleet: nobody can speak for its records until its own fingerprint is enrolled\n", .{ f.name, who });
                    return 1;
                },
                .no_such_member => {
                    try out.print("fleet {s} -- there is no member called {s}\n", .{ f.name, who });
                    return 1;
                },
            }
        }

        try out.print("fleet {s} -- {d} member{s}", .{ f.name, f.members.len, if (f.members.len == 1) "" else "s" });
        if (f.link) |l| {
            try out.print(" on {s}", .{l});
            if (f.server()) |s| try out.print(", served by {s}", .{s.name}) else try out.print(", served by nobody in this fleet", .{});
        } else try out.print(", no shared link declared", .{});
        try out.print(" -- judged, no refusal\n", .{});
        var unenrolled: usize = 0;
        for (f.members) |m| {
            try out.print("  {s} -- {s} ({s}", .{ m.name, m.machine.name, m.declaration });
            if (f.link) |l| for (m.machine.networks) |n| {
                if (!std.mem.eql(u8, n.name, l)) continue;
                switch (n.address) {
                    .static => |st| try out.print(", {s}", .{st.text}),
                    .dhcp => try out.print(", asks", .{}),
                }
                if (n.domain) |d| try out.print(", serves {s}", .{d});
            };
            try out.print(")", .{});
            // which physical unit, and which promise it answers to. The
            // join is the whole point of HARDWARE being here (HDW-1).
            if (m.hardware_text) |hw| {
                if (fleet.promisedTo(f, m)) |p| {
                    try out.print(" -- {s}, promised {s} as {s}", .{ hw, p.address, p.name });
                } else {
                    try out.print(" -- {s}", .{hw});
                }
            }
            if (m.fingerprint) |fp| {
                try out.print(" -- enrolled, fingerprint {s}\n", .{fp[0..]});
            } else if (m.machine.journal != null) {
                unenrolled += 1;
                try out.print(" -- KEEPS A RECORD AND IS NOT ENROLLED: nobody can verify what it signs\n", .{});
            } else {
                try out.print(" -- not enrolled\n", .{});
            }
            // the keys it USED to have, each with the one entry it is
            // trusted through (RET-1)
            for (f.retirements) |r| {
                if (!std.mem.eql(u8, r.member, m.name)) continue;
                try out.print("    retired {s} -- a key {s} held before, fingerprint {s}, trusted through hash={s}\n", .{ r.name, m.name, r.fingerprint[0..], r.through });
            }
        }
        if (unenrolled > 0) {
            try out.print("fleet {s} -- {d} member{s} {s} a signed record that no holder of this file can check; enrol from the line the device prints on its own console\n", .{
                f.name, unenrolled, if (unenrolled == 1) "" else "s", if (unenrolled == 1) "keeps" else "keep",
            });
        }
        return 0;
    }
    if (std.mem.eql(u8, verb, "ask")) {
        // The witness of the NAMES seat, and the whole point of it: a
        // device that was told nothing but its own address asks the
        // server that gave it that address what a NAME on this network
        // means, and says what came back. It is the till asking for the
        // printer.
        //
        // It reads /etc/resolv.conf, which this machine did not choose
        // and did not invent: the file its own dhcp client wrote from
        // the lease. A name the server does not serve comes back as "no
        // such name", never as a guess and never forwarded onward.
        if (builtin.os.tag != .linux) {
            try out.print("ask: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
            return 2;
        }
        if (args.len < 3) {
            try out.print("harb: ask takes a name (imprimante.makeen)\n", .{});
            return 1;
        }
        const want = args[2];
        const conf = std.fs.cwd().readFileAlloc(arena, "/etc/resolv.conf", 1 << 16) catch {
            try out.print("ask {s} -- no resolver: this machine was never told where to ask (/etc/resolv.conf)\n", .{want});
            return 0;
        };
        var server: ?u32 = null;
        var lines = std.mem.splitScalar(u8, conf, '\n');
        while (lines.next()) |line| {
            const t = std.mem.trim(u8, line, " \t\r");
            if (!std.mem.startsWith(u8, t, "nameserver ")) continue;
            if (machine.parseIpv4(std.mem.trim(u8, t["nameserver ".len..], " \t\r"))) |ip| {
                server = ip;
                break;
            }
        }
        const sip = server orelse {
            try out.print("ask {s} -- no resolver: /etc/resolv.conf names none\n", .{want});
            return 0;
        };
        var sbuf: [16]u8 = undefined;
        const stext = netcfg.fmtIp(&sbuf, sip);
        const l = std.os.linux;
        const rc_sock = l.socket(l.AF.INET, l.SOCK.DGRAM, 0);
        if (l.E.init(rc_sock) != .SUCCESS) {
            try out.print("ask {s} -- no socket: {s}\n", .{ want, @tagName(l.E.init(rc_sock)) });
            return 0;
        }
        const fd: i32 = @intCast(rc_sock);
        defer _ = l.close(fd);
        const tv: l.timeval = .{ .sec = 3, .usec = 0 };
        _ = l.setsockopt(fd, l.SOL.SOCKET, l.SO.RCVTIMEO, @ptrCast(&tv), @sizeOf(l.timeval));
        var sa = std.posix.sockaddr.in{
            .family = l.AF.INET,
            .port = std.mem.nativeToBig(u16, 53),
            .addr = std.mem.nativeToBig(u32, sip),
            .zero = [_]u8{0} ** 8,
        };
        var qbuf: [512]u8 = undefined;
        const id: u16 = 0x5A5A;
        const qn = names.query(&qbuf, id, want) orelse {
            try out.print("ask {s} -- that is not a name this machine can ask for\n", .{want});
            return 1;
        };
        var rbuf: [1500]u8 = undefined;
        var tries: u8 = 0;
        while (tries < 3) : (tries += 1) {
            _ = l.sendto(fd, &qbuf, qn, 0, @ptrCast(&sa), @sizeOf(@TypeOf(sa)));
            const r = l.recvfrom(fd, &rbuf, rbuf.len, 0, null, null);
            if (l.E.init(r) != .SUCCESS) continue;
            switch (names.readAnswer(rbuf[0..r], id)) {
                .address => |ip| {
                    var ab: [16]u8 = undefined;
                    try out.print("ask {s} -- {s} (from {s})\n", .{ want, netcfg.fmtIp(&ab, ip), stext });
                    return 0;
                },
                .no_such_name => {
                    try out.print("ask {s} -- no such name on this network (from {s})\n", .{ want, stext });
                    return 0;
                },
                .malformed => continue,
            }
        }
        try out.print("ask {s} -- {s} did not answer\n", .{ want, stext });
        return 0;
    }
    if (std.mem.eql(u8, verb, "swarm")) {
        // The witness of the TASKS seat: a world asking the kernel for
        // more of itself than the machine agreed to hold, and being told
        // no. It counts what it got rather than what it asked for,
        // because the ceiling is on the WORLD and the world already
        // occupies some of it -- the number that matters is where the
        // kernel stopped, not the difference from the declaration.
        if (builtin.os.tag != .linux) {
            try out.print("swarm: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
            return 2;
        }
        const want = if (args.len > 2) std.fmt.parseInt(u32, args[2], 10) catch 8 else 8;
        const l = std.os.linux;
        var made: u32 = 0;
        var stopped: ?[]const u8 = null;
        var kids: [64]i32 = undefined;
        while (made < want and made < kids.len) {
            try out.flush(); // a fork copies the buffer as well (NS-1)
            const rc = l.fork();
            switch (l.E.init(rc)) {
                .SUCCESS => {
                    if (rc == 0) {
                        // a child that only has to EXIST while the parent
                        // counts; it waits to be reaped and says nothing
                        var ts: l.timespec = .{ .sec = 2, .nsec = 0 };
                        _ = l.nanosleep(&ts, null);
                        l.exit(0);
                    }
                    kids[made] = @intCast(rc);
                    made += 1;
                },
                else => |e| {
                    stopped = @tagName(e);
                    break;
                },
            }
        }
        if (stopped) |why| {
            try out.print("swarm: {d} tasks made, and the kernel refused the next ({s}): this world is as many as the machine agreed to hold\n", .{ made, why });
        } else {
            try out.print("swarm: {d} tasks made, and the kernel refused none: this world was not sized\n", .{made});
        }
        var i: u32 = 0;
        while (i < made) : (i += 1) {
            _ = l.kill(kids[i], 9);
            var status: u32 = 0;
            _ = l.wait4(kids[i], &status, 0, null);
        }
        return 0;
    }
    if (std.mem.eql(u8, verb, "confined")) {
        // The witness of the NS-1 seat, as `harb id` is the USER seat's
        // and `harb reach` is the EGRESS seat's: it asks, FROM INSIDE A
        // WORLD, what that world can actually do -- and both questions
        // have a negative that only a confined world can give.
        //
        // The interface question is the sharp one. `reach` asks whether
        // the machine knows a WAY to an address; this asks whether the
        // interface exists AT ALL from where the caller stands. In an
        // empty network namespace it does not, and ENODEV is a different
        // answer from "no route" in the way that matters: there is
        // nothing here to be refused.
        if (builtin.os.tag != .linux) {
            try out.print("confined: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
            return 2;
        }
        const l = std.os.linux;
        const iface = if (args.len > 2) args[2] else "eth0";
        const rc_sock = l.socket(l.AF.INET, l.SOCK.DGRAM, 0);
        if (l.E.init(rc_sock) == .SUCCESS) {
            const fd: i32 = @intCast(rc_sock);
            defer _ = l.close(fd);
            var ifr: l.ifreq = std.mem.zeroes(l.ifreq);
            @memcpy(ifr.ifrn.name[0..iface.len], iface);
            switch (l.E.init(l.ioctl(fd, l.SIOCGIFFLAGS, @intFromPtr(&ifr)))) {
                .SUCCESS => try out.print("confined: {s} -- present: this world shares the machine's network\n", .{iface}),
                .NODEV => try out.print("confined: {s} -- no such interface from here: this world has a network namespace of its own and there is nothing in it\n", .{iface}),
                else => |e| try out.print("confined: {s} -- the kernel refused the question: {s}\n", .{ iface, @tagName(e) }),
            }
        } else {
            try out.print("confined: no socket at all: {s}\n", .{@tagName(l.E.init(rc_sock))});
        }

        // ... and what this world can see of the machine's OTHER worlds.
        // Asked BEFORE the fork below, or this world's own child would be
        // counted as company (PID-1).
        {
            const me = l.getpid();
            var others: usize = 0;
            if (std.fs.cwd().openDir("/proc", .{ .iterate = true })) |dir| {
                var d = dir;
                defer d.close();
                var it = d.iterate();
                while (it.next() catch null) |e| {
                    const n = std.fmt.parseInt(i32, e.name, 10) catch continue;
                    if (n != me) others += 1;
                }
            } else |_| {}
            if (others == 0) {
                try out.print("confined: processes -- this world is pid {d} and no other process exists here: a table of its own\n", .{me});
            } else {
                try out.print("confined: processes -- this world is pid {d} and can see the machine's other processes: one table for everybody\n", .{me});
            }
        }

        // ... and whether the machine's own storage is there. The world
        // keeps the image it was built from -- its binary is a file --
        // and a declared MOUNT is what a world that never asked for the
        // filesystem does not get to see (MNT-1).
        for (args[3..]) |path| {
            // ASK WHETHER IT IS A MOUNT POINT, not whether the path
            // exists. The directory is in the image so that PID 1 has
            // somewhere to mount onto, and it stays there after the
            // detach -- the first run of this witness reported "/data is
            // there" about an empty directory and called a kept promise
            // broken-looking (MNT-1). A path is a separate filesystem
            // exactly when its device id differs from its parent's, which
            // is what mountpoint(1) asks and the only honest question.
            //
            // fstatat, not stat: aarch64 has no stat syscall at all.
            var here: l.Stat = undefined;
            var root: l.Stat = undefined;
            const pz = try arena.dupeZ(u8, path);
            const ok_here = l.E.init(l.fstatat(l.AT.FDCWD, pz.ptr, &here, 0)) == .SUCCESS;
            const ok_root = l.E.init(l.fstatat(l.AT.FDCWD, "/", &root, 0)) == .SUCCESS;
            if (!ok_here) {
                try out.print("confined: {s} -- not even a directory here\n", .{path});
            } else if (!ok_root) {
                try out.print("confined: {s} -- the root could not be read\n", .{path});
            } else if (here.dev != root.dev) {
                try out.print("confined: {s} -- mounted here: this world can see the machine's storage\n", .{path});
            } else {
                try out.print("confined: {s} -- an empty directory and nothing mounted on it: this world has a mount namespace of its own and the machine's storage is not in it\n", .{path});
            }
        }

        // ... and whether this world can change the machine it runs on.
        // unshare is the safe one to actually TRY: if the filter is not
        // there, all that happens is this world gets a mount namespace of
        // its own and then exits. A witness must not damage the machine
        // in the case where the guard it is testing has failed (SYS-1).
        switch (l.E.init(l.unshare(l.CLONE.NEWNS))) {
            .PERM => try out.print("confined: the floor -- refused by the kernel (EPERM): this world cannot change the machine it runs on\n", .{}),
            .SUCCESS => try out.print("confined: the floor -- PERMITTED: this world just built itself a namespace, and the floor is not holding\n", .{}),
            else => |e| try out.print("confined: the floor -- {s}\n", .{@tagName(e)}),
        }

        // and whether this world may make another process. A permitted
        // fork is PROVEN by forking, not by the absence of an error: the
        // child says so and is reaped.
        //
        // FLUSH FIRST. A fork copies the buffer as well as the process,
        // and the child's own flush would say everything the parent had
        // not yet written -- which is how this witness first reported the
        // interface twice (NS-1).
        try out.flush();
        const rc_fork = l.fork();
        switch (l.E.init(rc_fork)) {
            .SUCCESS => {
                if (rc_fork == 0) {
                    try out.print("confined: fork -- permitted: this world started another process, and this line is the child speaking\n", .{});
                    try out.flush();
                    l.exit(0);
                }
                var status: u32 = 0;
                _ = l.wait4(@intCast(rc_fork), &status, 0, null);
            },
            .PERM => try out.print("confined: fork -- refused by the kernel (EPERM): this world cannot start another process\n", .{}),
            else => |e| try out.print("confined: fork -- {s}\n", .{@tagName(e)}),
        }
        return 0;
    }
    if (std.mem.eql(u8, verb, "reach")) {
        // The witness of the EGRESS seat, as `harb id` is the USER
        // seat's: it asks the KERNEL whether this machine knows a way to
        // an address, and says what it answered. A UDP connect() is the
        // whole question -- it performs the route lookup and sends
        // nothing at all, so a machine with no way there learns that
        // without a single packet leaving it, which is the point.
        if (builtin.os.tag != .linux) {
            try out.print("reach: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
            return 2;
        }
        if (args.len < 3) {
            try out.print("harb: reach takes an address (a.b.c.d)\n", .{});
            return 1;
        }
        const ip = machine.parseIpv4(args[2]) orelse {
            try out.print("reach: '{s}' is not an address (a.b.c.d)\n", .{args[2]});
            return 1;
        };
        const l = std.os.linux;
        const rc_sock = l.socket(l.AF.INET, l.SOCK.DGRAM, 0);
        if (l.E.init(rc_sock) != .SUCCESS) {
            try out.print("reach {s} -- no socket: {s} (has this machine a network at all?)\n", .{ args[2], @tagName(l.E.init(rc_sock)) });
            return 0;
        }
        const fd: i32 = @intCast(rc_sock);
        defer _ = l.close(fd);
        var sa = std.posix.sockaddr.in{
            .family = l.AF.INET,
            .port = std.mem.nativeToBig(u16, 53),
            .addr = std.mem.nativeToBig(u32, ip),
            .zero = [_]u8{0} ** 8,
        };
        const rc = l.connect(fd, @ptrCast(&sa), @sizeOf(@TypeOf(sa)));
        switch (l.E.init(rc)) {
            .SUCCESS => try out.print("reach {s} -- a route exists: this machine knows a way there\n", .{args[2]}),
            .NETUNREACH, .HOSTUNREACH => try out.print("reach {s} -- no route: this machine knows no way there\n", .{args[2]}),
            else => |e| try out.print("reach {s} -- the kernel refused the question: {s}\n", .{ args[2], @tagName(e) }),
        }
        return 0;
    }
    if (std.mem.eql(u8, verb, "net")) {
        return net.run(arena, args[2..], out);
    }
    if (std.mem.eql(u8, verb, "update")) {
        return update.run(gpa, args[2..], out);
    }
    if (std.mem.eql(u8, verb, "court")) {
        // two grammars, two fixture files, one court. The fleet's cases
        // carry the machine files they name inside themselves, so a
        // fixture is self-contained and needs no scratch directory.
        if (args.len > 2 and std.mem.eql(u8, args[2], "--fleet")) {
            const path = if (args.len > 3) args[3] else default_fleet_fixtures;
            const failures = try court.runFleet(gpa, path, out);
            return if (failures == 0) 0 else 1;
        }
        // and a third, for what a solution asks (PLC-1): each case is a
        // machine and the packs placed on it, carried inside the case
        if (args.len > 2 and std.mem.eql(u8, args[2], "--pack")) {
            const path = if (args.len > 3) args[3] else default_pack_fixtures;
            const failures = try court.runPack(gpa, path, out);
            return if (failures == 0) 0 else 1;
        }
        const path = if (args.len > 2) args[2] else default_fixtures;
        const failures = try court.run(gpa, path, out);
        return if (failures == 0) 0 else 1;
    }
    if (std.mem.eql(u8, verb, "place")) {
        // What a solution asks, placed on the machine that grants it
        // (PLC-1). Without --out it is a rehearsal: judged, nothing written.
        var out_path: ?[]const u8 = null;
        var paths: std.ArrayList([]const u8) = .{};
        var j: usize = 2;
        while (j < args.len) : (j += 1) {
            if (std.mem.eql(u8, args[j], "--out")) {
                j += 1;
                if (j >= args.len) {
                    try out.print("harb: --out needs a file to write\n", .{});
                    return 1;
                }
                out_path = args[j];
            } else try paths.append(arena, args[j]);
        }
        if (paths.items.len < 2) {
            try out.print("harb: place needs a <file.machine> and at least one <file.pack>\n", .{});
            return 1;
        }
        var inputs: std.ArrayList(pack.Input) = .{};
        for (paths.items) |p| {
            const bytes = std.fs.cwd().readFileAlloc(arena, p, 1 << 20) catch |e| {
                try out.print("harb: cannot read {s}: {s}\n", .{ p, @errorName(e) });
                return 1;
            };
            try inputs.append(arena, .{ .name = pack.fileName(p), .source = bytes });
        }
        var refusal = pack.Refusal{};
        const placed = pack.place(arena, inputs.items[0], inputs.items[1..], &refusal) catch |e| switch (e) {
            error.Refused => {
                try out.print("place: {s} (line {d}): {s}\n", .{ refusal.file, refusal.line, refusal.message });
                return 1;
            },
            else => return e,
        };
        for (placed.packs) |p| {
            try out.print("place {s} (sha256 {s}) -- {d} service(s), {d} user(s)\n", .{ p.name, p.digest[0..16], p.services.len, p.users.len });
        }
        const m = placed.machine;
        try out.print("on machine {s} -- {s} / {s} / kernel {s} -- {d} service(s) in all -- judged, no refusal\n", .{ m.name, @tagName(m.profile), @tagName(m.arch), @tagName(m.kernel), m.services.len });
        if (out_path) |op| {
            if (std.fs.path.dirname(op)) |dir| try std.fs.cwd().makePath(dir);
            try std.fs.cwd().writeFile(.{ .sub_path = op, .data = placed.text });
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(placed.text, &digest, .{});
            var hex: [64]u8 = undefined;
            _ = std.fmt.bufPrint(&hex, "{x}", .{&digest}) catch unreachable;
            try out.print("written {s} (sha256 {s}): harb check, plan, image and judge take it as any machine\n", .{ op, hex[0..16] });
        }
        return 0;
    }
    if (std.mem.eql(u8, verb, "judge")) {
        if (args.len < 4) {
            try out.print("harb: judge needs <file.machine> and a captured transcript\n", .{});
            return 1;
        }
        const m = (try load(arena, args[2], out)) orelse return 1;
        // the board's own emulator lens, from the one place it is written
        // (image.zig): this verb kept a second copy until CON-1, and the
        // copy would have judged the emulator without its console lack
        var lens = expect.Lens{};
        if (args.len > 5 and std.mem.eql(u8, args[4], "--lens") and std.mem.eql(u8, args[5], "emulator")) {
            lens = image.emulatorLens(m.board) orelse expect.Lens{};
        }
        const text = std.fs.cwd().readFileAlloc(arena, args[3], 1 << 20) catch |e| {
            try out.print("harb: cannot read {s}: {s}\n", .{ args[3], @errorName(e) });
            return 1;
        };
        const p = try plan.derive(arena, &m);
        return expect.judgeTranscript(arena, p, lens, text, args[3], out);
    }
    if (std.mem.eql(u8, verb, "guarantees")) {
        if (args.len < 4) {
            try out.print("harb: guarantees needs <file.machine> and the text to judge (a transcript, or the expectation an image carries)\n", .{});
            return 1;
        }
        const m = (try load(arena, args[2], out)) orelse return 1;
        const text = std.fs.cwd().readFileAlloc(arena, args[3], 1 << 20) catch |e| {
            try out.print("harb: cannot read {s}: {s}\n", .{ args[3], @errorName(e) });
            return 1;
        };
        return guarantee.judge(arena, &m, text, args[3], out);
    }
    if (std.mem.eql(u8, verb, "check") or std.mem.eql(u8, verb, "plan") or std.mem.eql(u8, verb, "init") or std.mem.eql(u8, verb, "image") or std.mem.eql(u8, verb, "project")) {
        if (args.len < 3) {
            try usage(out);
            return 1;
        }
        const m = (try load(arena, args[2], out)) orelse return 1;
        if (std.mem.eql(u8, verb, "check")) {
            try out.print("machine {s} -- {s} / {s} / kernel {s} -- {d} service(s), {d} capabilit{s}, {d} mount(s), {d} pin(s), {d} network(s), {d} peer(s) -- judged, no refusal\n", .{
                m.name, @tagName(m.profile), @tagName(m.arch), @tagName(m.kernel), m.services.len, m.capabilities.len, if (m.capabilities.len == 1) "y" else "ies", m.mounts.len, m.pins.len, m.networks.len, m.peers.len,
            });
            return 0;
        }
        const p = try plan.derive(arena, &m);
        if (std.mem.eql(u8, verb, "plan")) {
            try plan.render(p, out);
            return 0;
        }
        if (std.mem.eql(u8, verb, "project")) {
            var out_dir: ?[]const u8 = null;
            var j: usize = 3;
            while (j + 1 < args.len) : (j += 2) {
                if (std.mem.eql(u8, args[j], "--out")) {
                    out_dir = args[j + 1];
                } else {
                    try out.print("harb: unknown option '{s}'\n", .{args[j]});
                    return 1;
                }
            }
            if (out_dir == null) {
                try out.print("harb: project needs --out <dir>\n", .{});
                return 1;
            }
            return project.write(arena, p, .{ .out_dir = out_dir.? }, out);
        }
        if (std.mem.eql(u8, verb, "image")) {
            var root: ?[]const u8 = null;
            var out_dir: ?[]const u8 = null;
            var j: usize = 3;
            while (j + 1 < args.len) : (j += 2) {
                if (std.mem.eql(u8, args[j], "--root")) {
                    root = args[j + 1];
                } else if (std.mem.eql(u8, args[j], "--out")) {
                    out_dir = args[j + 1];
                } else {
                    try out.print("harb: unknown option '{s}'\n", .{args[j]});
                    return 1;
                }
            }
            if (root == null or out_dir == null) {
                try out.print("harb: image needs --root <staging dir> and --out <image dir>\n", .{});
                return 1;
            }
            return image.write(arena, p, .{ .out_dir = out_dir.?, .root = root.?, .machine_path = args[2] }, out);
        }
        var opts = init.Options{};
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--rehearse")) {
                opts.rehearse = true;
            } else if (std.mem.eql(u8, args[i], "--hold")) {
                opts.hold = true;
            } else if (std.mem.eql(u8, args[i], "--halt-on-verdict")) {
                opts.halt_on_verdict = true;
            } else if (std.mem.eql(u8, args[i], "--turns") and i + 1 < args.len) {
                i += 1;
                opts.turns = std.fmt.parseInt(usize, args[i], 10) catch {
                    try out.print("harb: --turns takes a number\n", .{});
                    return 1;
                };
            } else {
                try out.print("harb: unknown option '{s}'\n", .{args[i]});
                return 1;
            }
        }
        return init.run(gpa, p, opts, out);
    }
    try usage(out);
    return 1;
}

test {
    _ = machine;
    _ = plan;
    _ = net;
    _ = init;
    _ = expect;
    _ = journal;
    _ = confine;
    _ = names;
    _ = fleet;
    _ = pack;
    _ = learn;
    _ = docs;
}
