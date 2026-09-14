// stzos -- one static binary, every role. On the host it is the CLI
// (check, plan, court); on a hosted machine the same binary is PID 1
// (init). Cross-compiling it for the machine is one flag (`zig build
// cross`), and the image carries nothing else on its boot path: no
// shell, no service manager, no package manager -- the declared machine
// IS the system.
//
//   stzos check  <file.machine>                 judge a declaration
//   stzos plan   <file.machine>                 print the boot plan
//   stzos court  [declarative/machine/fixtures.json]
//   stzos init   <file.machine> [--rehearse] [--turns N]
//   stzos version

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");
const plan = @import("plan.zig");
const court = @import("court.zig");
const init = @import("init.zig");
const image = @import("image.zig");
const net = @import("net.zig");
const update = @import("update.zig");
const project = @import("project.zig");
const guarantee = @import("guarantee.zig");
const expect = @import("expect.zig");

pub const version = "0.1.0";
const default_fixtures = "declarative/machine/fixtures.json";

fn usage(out: *std.Io.Writer) !void {
    try out.print(
        \\stzos {s} -- the declared machine ({s}-{s})
        \\  stzos check  <file.machine>
        \\  stzos plan   <file.machine>
        \\  stzos court  [fixtures.json]        (default: {s})
        \\  stzos init   <file.machine> [--rehearse] [--turns N] [--hold] [--halt-on-verdict]
        \\  stzos update <dir> [--boot <mountpoint>] [--no-reboot]   (write the other slot, try it once)
        \\  stzos image  <file.machine> --root <staging dir> --out <image dir>
        \\  stzos project <file.machine> --out <dir>     (an edge machine, onto MicroRing's substrate)
        \\  stzos guarantees <file.machine> <text>       (the hosted profile's four promises, judged)
        \\  stzos judge  <file.machine> <transcript> [--lens emulator]   (a captured boot, against what the machine expects)
        \\  stzos net    <iface> <a.b.c.d>/<prefix> [gateway] | <iface> dhcp   (by hand, what init does for a NETWORK)
        \\  stzos id                                     (uid and gid, from inside a machine)
        \\  stzos reach  <a.b.c.d>                       (does this machine know a way there? from inside it)
        \\  stzos attest [file.machine]                  (sign with this device's key and verify it, from inside it)
        \\  stzos version
        \\
    , .{ version, @tagName(builtin.cpu.arch), @tagName(builtin.os.tag), default_fixtures });
}

fn load(arena: std.mem.Allocator, path: []const u8, out: *std.Io.Writer) !?machine.Machine {
    const src = std.fs.cwd().readFileAlloc(arena, path, 1 << 20) catch |e| {
        try out.print("stzos: cannot read {s}: {s}\n", .{ path, @errorName(e) });
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

    if (std.mem.eql(u8, verb, "version")) {
        try out.print("stzos {s}\n", .{version});
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
    if (std.mem.eql(u8, verb, "attest")) {
        // The witness of the IDENTITY seat, as `reach` is EGRESS's and
        // `id` is USER's: it uses the device's own key and shows both
        // halves of what a signature is worth -- that it verifies, and
        // that it stops verifying the moment the message changes. The
        // second half is the one worth printing: a signature nobody
        // tried to break is a claim, not evidence.
        const path = if (args.len > 2) args[2] else "/etc/machine";
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
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&pair.public_key.toBytes(), &digest, .{});
        var hex: [16]u8 = undefined;
        _ = std.fmt.bufPrint(&hex, "{x}", .{digest[0..8]}) catch {};
        try out.print("attest {s} -- ed25519, fingerprint {s}\n", .{ m.name, hex });
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
    if (std.mem.eql(u8, verb, "reach")) {
        // The witness of the EGRESS seat, as `stzos id` is the USER
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
            try out.print("stzos: reach takes an address (a.b.c.d)\n", .{});
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
        const path = if (args.len > 2) args[2] else default_fixtures;
        const failures = try court.run(gpa, path, out);
        return if (failures == 0) 0 else 1;
    }
    if (std.mem.eql(u8, verb, "judge")) {
        if (args.len < 4) {
            try out.print("stzos: judge needs <file.machine> and a captured transcript\n", .{});
            return 1;
        }
        var lens = expect.Lens{};
        if (args.len > 5 and std.mem.eql(u8, args[4], "--lens") and std.mem.eql(u8, args[5], "emulator")) {
            lens = .{ .watchdog = .off, .network_absent = true };
        }
        const m = (try load(arena, args[2], out)) orelse return 1;
        const text = std.fs.cwd().readFileAlloc(arena, args[3], 1 << 20) catch |e| {
            try out.print("stzos: cannot read {s}: {s}\n", .{ args[3], @errorName(e) });
            return 1;
        };
        const p = try plan.derive(arena, &m);
        return expect.judgeTranscript(arena, p, lens, text, args[3], out);
    }
    if (std.mem.eql(u8, verb, "guarantees")) {
        if (args.len < 4) {
            try out.print("stzos: guarantees needs <file.machine> and the text to judge (a transcript, or the expectation an image carries)\n", .{});
            return 1;
        }
        const m = (try load(arena, args[2], out)) orelse return 1;
        const text = std.fs.cwd().readFileAlloc(arena, args[3], 1 << 20) catch |e| {
            try out.print("stzos: cannot read {s}: {s}\n", .{ args[3], @errorName(e) });
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
            try out.print("machine {s} -- {s} / {s} / kernel {s} -- {d} service(s), {d} capabilit{s}, {d} mount(s), {d} pin(s), {d} network(s) -- judged, no refusal\n", .{
                m.name, @tagName(m.profile), @tagName(m.arch), @tagName(m.kernel), m.services.len, m.capabilities.len, if (m.capabilities.len == 1) "y" else "ies", m.mounts.len, m.pins.len, m.networks.len,
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
                    try out.print("stzos: unknown option '{s}'\n", .{args[j]});
                    return 1;
                }
            }
            if (out_dir == null) {
                try out.print("stzos: project needs --out <dir>\n", .{});
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
                    try out.print("stzos: unknown option '{s}'\n", .{args[j]});
                    return 1;
                }
            }
            if (root == null or out_dir == null) {
                try out.print("stzos: image needs --root <staging dir> and --out <image dir>\n", .{});
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
                    try out.print("stzos: --turns takes a number\n", .{});
                    return 1;
                };
            } else {
                try out.print("stzos: unknown option '{s}'\n", .{args[i]});
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
}
