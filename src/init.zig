// init.zig -- the act: PID 1 of a hosted machine. Takes a judged plan and
// executes it step by step on Linux, narrating every step to the console
// as a boot transcript (the `boot:` lines). The transcript is the
// fixture: a machine that boots differently prints differently.
//
// What init does, and all it does:
//   1. mounts -- the profile's implicit proc/sys/dev, then the declared
//      mounts, each result stated (refused-by-the-kernel is a line, not
//      a hidden retry);
//   2. capabilities and pins -- stated as facts of the machine (the
//      enforcement of a refused capability belongs to the service's own
//      scope on stzr; init records the envelope);
//   3. services -- spawned as argv, never through a shell, in plan order;
//   4. reaping -- waits on every child of the machine (orphans included:
//      that is PID 1's duty), applies the declared RESTART policy, and
//      names each exit.
//
// `--rehearse` runs the same plan with the mounts narrated and not
// executed, from any pid -- the twin before the act, as stzlib's virtual
// system framework does for files and processes. `--turns N` stops
// after N reaped exits, so a rehearsal ends (a real init never does).
//
// Linux-only by comptime gate. The gate is real only if a Linux target is
// BUILT: `zig build cross` does that, because Zig analyses only the taken
// side of a comptime branch (the MicroRing injection finding, 2026-08-20).

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");
const plan = @import("plan.zig");
const netcfg = @import("netcfg.zig");
const names = @import("names.zig");
const confine = @import("confine.zig");
const expect = @import("expect.zig");
const journal = @import("journal.zig");

pub const Options = struct {
    rehearse: bool = false,
    turns: ?usize = null,
    max_restarts: usize = 5,
    /// the rollback instrument: on a trial boot, never commit and stop
    /// feeding the watchdog, so the hardware's answer is what follows
    hold: bool = false,
    /// the COURT's instrument, for a machine whose worlds SERVE: a
    /// daemon never exits, so a real init never halts and a transcript
    /// never closes. With this, PID 1 halts the moment the verdict is in
    /// -- every service ready and the boot judged (SRV-1). It is derived
    /// onto the EMULATOR's boot line only; a board keeps the box alive,
    /// and the card's cmdline.txt never carries it. No verdict is no
    /// halt: a daemon that never signals leaves the court's timeout to
    /// convict it, which is the same rule as "no expectation is no
    /// commit" seen from the other side.
    halt_on_verdict: bool = false,
};

// ---- A/B slots ------------------------------------------------------------
//
// The card's boot partition holds config.txt and two slots. config.txt
// names the committed slot in its os_prefix and, under [tryboot], the
// other; the firmware applies the [tryboot] section only on a boot asked
// for with the tryboot flag, once. PID 1 learns which slot it booted from
// the cmdline (harb.slot=), reads which one is committed, arms the
// hardware watchdog, and -- on a trial -- commits by rewriting config.txt
// only when every service is ready AND the boot matches the expectation
// the image carries (JDG-1: the machine judges its own boot). A trial that
// never gets there, or is judged different, is not committed: the watchdog
// is no longer fed, the board resets, and the firmware boots the committed
// slot. "Healthy" means "the boot the declaration expected"; a health seat
// beyond the boot (a service's own word later in its life) is a named seam.

const Slots = struct {
    dev: []const u8,
    booted: ?u8 = null, // 'A' or 'B'
    committed: ?u8 = null,
    mounted: bool = false,
    wd_fd: ?i32 = null,
    done: bool = false, // committed, or steady from the start
};

// ---- the ledger: what init said, to be judged against what was expected --
//
// Every judged line is printed THROUGH the ledger: written to it first,
// then echoed to the console, so the console and the record cannot
// disagree. Lines about the card's state (a trial, steady), the instrument
// (--hold) and the verdict itself go to the console alone: the expectation
// is derived from the declaration, which knows none of them.
const Ledger = struct {
    aw: std.Io.Writer.Allocating,
    out: *std.Io.Writer,
    mark: usize = 0,

    fn init(gpa: std.mem.Allocator, out: *std.Io.Writer) Ledger {
        return .{ .aw = std.Io.Writer.Allocating.init(gpa), .out = out };
    }
    fn deinit(self: *Ledger) void {
        self.aw.deinit();
    }
    fn w(self: *Ledger) *std.Io.Writer {
        return &self.aw.writer;
    }
    /// echo to the console what was recorded since the last echo
    fn echo(self: *Ledger) !void {
        const all = self.aw.written();
        try self.out.writeAll(all[self.mark..]);
        self.mark = all.len;
    }
    fn say(self: *Ledger, comptime fmt: []const u8, args: anytype) !void {
        try self.w().print(fmt, args);
        try self.echo();
    }
    fn said(self: *Ledger) []const u8 {
        return self.aw.written();
    }
    /// everything recorded so far, on the console, now. Called before a
    /// spawn: a world starts speaking the instant it is forked, and a
    /// reason still sitting in PID 1's buffer would be read AFTER the
    /// world it explains (BDG-1, where five restarts arrived out of
    /// order with the kills that caused them).
    fn flush(self: *Ledger) !void {
        try self.echo();
        try self.out.flush();
    }
};

/// the value after `<key>` on the kernel command line, or null
fn cmdlineValue(gpa: std.mem.Allocator, key: []const u8) ?[]u8 {
    const cmdline = std.fs.cwd().readFileAlloc(gpa, "/proc/cmdline", 4096) catch return null;
    defer gpa.free(cmdline);
    const i = std.mem.indexOf(u8, cmdline, key) orelse return null;
    const rest = cmdline[i + key.len ..];
    const end = std.mem.indexOfAny(u8, rest, " \n") orelse rest.len;
    if (end == 0) return null;
    return gpa.dupe(u8, rest[0..end]) catch null;
}

/// TIOCGDEV: the number of the tty behind /dev/console, asked of the
/// kernel -- not read off the boot line, and not assumed from the
/// declaration (CON-1). _IOR('T', 0x32, unsigned int): the same number on
/// x86_64 and aarch64, which share the generic ioctl encoding.
const TIOCGDEV: u32 = 0x80045432;

/// The console, said only as far as the kernel agrees (CON-1). Until then
/// PID 1 SAID the declared console and nothing made it so: a machine
/// declaring /dev/ttyS3 announced it while it spoke on ttyS0. The boot line
/// now follows the declaration, and this asks which device PID 1's own
/// standard output -- /dev/console -- really is. A declared port is said as
/// declared only when the kernel agrees; otherwise both are said, and a
/// boot that differs from its file is judged so. A rehearsal is not the
/// machine's console, and /dev/console names no port: neither is asked.
fn sayConsole(led: *Ledger, declared: []const u8, rehearse: bool) !void {
    if (rehearse or std.mem.eql(u8, declared, "/dev/console")) return led.say(expect.fmt_console, .{declared});
    var dev: u32 = 0;
    const rc = std.os.linux.ioctl(1, TIOCGDEV, @intFromPtr(&dev));
    if (std.os.linux.E.init(rc) != .SUCCESS) return led.say(expect.fmt_console_unknown, .{declared});
    var buf: [48]u8 = undefined;
    const actual = machine.consoleDevice(&buf, dev);
    if (std.mem.eql(u8, actual, declared)) return led.say(expect.fmt_console, .{declared});
    try led.say(expect.fmt_console_elsewhere, .{ declared, actual });
}

/// The machine judges its own boot: the ledger against /etc/expected -- or
/// /etc/expected.<lens> when the boot line names one with harb.expect=
/// (the emulator's court does; a card's cmdline.txt never does). The
/// verdict is said on the console, in the machine's words, and returned.
/// No expectation is no verdict: nothing to judge by is nothing to commit
/// on (JDG-1).
fn judgeBoot(gpa: std.mem.Allocator, led: *Ledger, out: *std.Io.Writer) !bool {
    var path_buf: [80]u8 = undefined;
    var path: []const u8 = "/etc/expected";
    if (cmdlineValue(gpa, "harb.expect=")) |lens| {
        defer gpa.free(lens);
        path = std.fmt.bufPrint(&path_buf, "/etc/expected.{s}", .{lens}) catch path;
    }
    const expected = std.fs.cwd().readFileAlloc(gpa, path, 1 << 20) catch |e| {
        try out.print("boot: judge -- no expectation at {s} ({s}); the boot is not judged\n", .{ path, @errorName(e) });
        return false;
    };
    defer gpa.free(expected);
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const v = try expect.judge(arena_state.allocator(), expected, led.said());
    if (v.matches()) {
        try out.print("boot: judge -- the boot matches its expectation ({s}, {d} lines)\n", .{ path, v.expected });
        return true;
    }
    try out.print("boot: judge -- the boot differs from its expectation ({s}): {d} line(s) expected and not said, {d} said and not expected\n", .{ path, v.missing.len, v.unexpected.len });
    const cap = 8;
    for (v.missing, 0..) |l, i| {
        if (i == cap) {
            try out.print("boot: judge -- ... and {d} more expected\n", .{v.missing.len - cap});
            break;
        }
        try out.print("boot: judge -- expected, not said: {s}\n", .{expect.bare(l)});
    }
    for (v.unexpected, 0..) |l, i| {
        if (i == cap) {
            try out.print("boot: judge -- ... and {d} more said\n", .{v.unexpected.len - cap});
            break;
        }
        try out.print("boot: judge -- said, not expected: {s}\n", .{expect.bare(l)});
    }
    return false;
}

fn bootedSlot(gpa: std.mem.Allocator) ?u8 {
    const cmdline = std.fs.cwd().readFileAlloc(gpa, "/proc/cmdline", 4096) catch return null;
    defer gpa.free(cmdline);
    const i = std.mem.indexOf(u8, cmdline, "harb.slot=") orelse return null;
    const c = cmdline[i + "harb.slot=".len ..];
    if (c.len == 0) return null;
    return if (c[0] == 'A' or c[0] == 'B') c[0] else null;
}

/// `harb.watchdog=off` on the cmdline: the emulator court's lens. QEMU's
/// raspi4b resets the board the moment the watchdog is ARMED (its
/// power-management model has no countdown and reads the driver's
/// "full reset on expiry" as "reset now"), so the emulator's boot line
/// says so and PID 1 states that a trial cannot roll back by hardware
/// there. The card's cmdline.txt never carries it.
fn watchdogOff(gpa: std.mem.Allocator) bool {
    const cmdline = std.fs.cwd().readFileAlloc(gpa, "/proc/cmdline", 4096) catch return false;
    defer gpa.free(cmdline);
    return std.mem.indexOf(u8, cmdline, "harb.watchdog=off") != null;
}

/// How PID 1 opens the hardware watchdog: write-only and CLOSE-ON-EXEC (WDG-1).
///
/// The second flag is why this has a name. A world is PID 1's child -- fork,
/// the envelope, `execve` -- and an exec keeps every descriptor that is not
/// close-on-exec. The watchdog is opened BEFORE the first world is spawned, so
/// one opened without the flag sits in every world's table, and a world that
/// holds it can write to it and keep the hardware fed while PID 1 has stopped
/// feeding it (HLT-1's rollback never comes), or write the magic `V` and close
/// it, on a driver that honours that, and disarm the rollback for good. The
/// floor refuses a world the calls that would change the machine (SYS-1); an
/// inherited descriptor needs none of them. With the flag the world that execs
/// holds nothing of PID 1's but its stdio, and the watchdog core lets one
/// process hold the device at a time, so it cannot open a second beside PID 1's.
const watchdog_flags: std.os.linux.O = .{ .ACCMODE = .WRONLY, .CLOEXEC = true };

fn openWatchdog(path: [*:0]const u8) usize {
    return std.os.linux.open(path, watchdog_flags, 0);
}

/// the committed slot: the first os_prefix=slots/X/ before [tryboot]
fn committedSlot(text: []const u8) ?u8 {
    const head = if (std.mem.indexOf(u8, text, "[tryboot]")) |t| text[0..t] else text;
    const i = std.mem.indexOf(u8, head, "os_prefix=slots/") orelse return null;
    const c = head[i + "os_prefix=slots/".len ..];
    if (c.len == 0) return null;
    return if (c[0] == 'A' or c[0] == 'B') c[0] else null;
}

/// rewrite config.txt so that `to` is committed and the other slot is the
/// tryboot one; returns the new text
fn commitText(gpa: std.mem.Allocator, text: []const u8, from: u8, to: u8) ![]u8 {
    const t = std.mem.indexOf(u8, text, "[tryboot]") orelse return error.NoTryboot;
    const head = try std.mem.replaceOwned(u8, gpa, text[0..t], &[_]u8{ 's', 'l', 'o', 't', 's', '/', from, '/' }, &[_]u8{ 's', 'l', 'o', 't', 's', '/', to, '/' });
    defer gpa.free(head);
    const tail = try std.mem.replaceOwned(u8, gpa, text[t..], &[_]u8{ 's', 'l', 'o', 't', 's', '/', to, '/' }, &[_]u8{ 's', 'l', 'o', 't', 's', '/', from, '/' });
    defer gpa.free(tail);
    return std.mem.concat(gpa, u8, &.{ head, tail });
}

// ---- this device's own key (IDN-1) ---------------------------------------
//
// The seed is 32 bytes on a declared persistent mount, and the pair is
// derived from it every boot: what is stored is the smallest thing that
// can be, and the public half is never written down at all. The private
// half never leaves -- there is no code in this repository that sends
// it, and no world can read it, because the file is the machine's own
// and a world that declares a USER is not the machine.
//
// Ed25519 on MicroRing's finding: signing is deterministic, so no nonce
// is drawn at signing time, and a board with no entropy source worth the
// name cannot leak its key by drawing a bad one. The algorithm and the
// custody are SAID, never implied, because custody and algorithm are
// coupled -- a key held in silicon may be a P-256 key -- and a record
// that assumed one would be the uniform pretence that design refuses.

const Identity = struct {
    pair: std.crypto.sign.Ed25519.KeyPair,
    fingerprint: [16]u8, // the first 8 bytes of sha256(public key), in hex
    created: bool,
};

// the fingerprint is worded once, in journal.zig, because the FLEET
// prints the same 16 hex from an enrolled public key and the two must
// be comparable by eye (FLT-1)
const fingerprintOf = journal.fingerprintOf;

/// Load this device's key, or make it the first time. A failure here is
/// said and not hidden: a machine that declares an identity and cannot
/// keep one has not booted as declared, and the ledger lacks the line
/// its expectation has -- so the verdict differs and a trial holds.
fn identityOf(m: *const machine.Machine, out: *std.Io.Writer) ?Identity {
    const path = m.identity orelse return null;
    const Ed = std.crypto.sign.Ed25519;
    var seed: [Ed.KeyPair.seed_length]u8 = undefined;
    var created = false;

    read: {
        const f = std.fs.cwd().openFile(path, .{}) catch break :read;
        defer f.close();
        const n = f.readAll(&seed) catch break :read;
        if (n != seed.len) break :read;
        const pair = Ed.KeyPair.generateDeterministic(seed) catch break :read;
        return .{ .pair = pair, .fingerprint = fingerprintOf(pair.public_key.toBytes()), .created = false };
    }

    std.crypto.random.bytes(&seed);
    created = true;
    const pair = Ed.KeyPair.generateDeterministic(seed) catch |e| {
        out.print("boot: identity -- the key could not be derived: {s}\n", .{@errorName(e)}) catch {};
        return null;
    };
    if (std.fs.cwd().createFile(path, .{ .truncate = true, .mode = 0o600 })) |f| {
        defer f.close();
        f.writeAll(&seed) catch |e| {
            out.print("boot: identity -- the key could not be written to {s}: {s}\n", .{ path, @errorName(e) }) catch {};
            return null;
        };
        f.sync() catch {};
    } else |e| {
        out.print("boot: identity -- {s} could not be created: {s}; this device has no name it can keep\n", .{ path, @errorName(e) }) catch {};
        return null;
    }
    return .{ .pair = pair, .fingerprint = fingerprintOf(pair.public_key.toBytes()), .created = created };
}

/// The machine's own record, written once per boot (JRN-1).
///
/// Verified BEFORE it is extended, and never extended when it does not
/// verify: an entry appended after a broken one would launder the
/// break, and inalterability is exactly the property that a change
/// cannot go unnoticed. A machine that cannot keep its record has not
/// booted as declared, so the trial that would have committed is held.
///
/// It runs after the verdict, because the verdict is what the entry is
/// worth recording: this device, this declaration, this judgement.
fn journalWrite(gpa: std.mem.Allocator, m: *const machine.Machine, id: ?Identity, matched: bool, judged: bool, out: *std.Io.Writer) bool {
    const path = m.journal orelse return true;
    const ident = id orelse {
        out.print("boot: journal -- this machine has no key this boot, so nothing can be signed\n", .{}) catch {};
        return false;
    };
    const existing = std.fs.cwd().readFileAlloc(gpa, path, 1 << 20) catch "";
    defer if (existing.len > 0) gpa.free(existing);
    const check = journal.verify(existing, ident.pair.public_key);
    if (check.broken_at) |n| {
        out.print("boot: journal -- entry {d} does not verify: {s}. The chain is broken and this boot will NOT extend it\n", .{ n, check.reason }) catch {};
        return false;
    }
    const decl = std.fs.cwd().readFileAlloc(gpa, "/etc/machine", 1 << 20) catch "";
    defer if (decl.len > 0) gpa.free(decl);
    const verdict: journal.Verdict = if (!judged) .unjudged else if (matched) .matched else .differed;
    const seq = journal.append(path, ident.pair, check, m.name, journal.declarationDigest(decl), verdict) catch |e| {
        out.print("boot: journal -- {s} could not be extended: {s}\n", .{ path, @errorName(e) }) catch {};
        return false;
    };
    if (check.verified == 0) {
        out.print("boot: journal -- {s}: the chain begins, entry {d} signed by this device (verdict {s})\n", .{ path, seq, verdict.text() }) catch {};
    } else {
        out.print("boot: journal -- {s}: {d} entr{s} verified, entry {d} appended and signed (verdict {s})\n", .{ path, check.verified, if (check.verified == 1) "y" else "ies", seq, verdict.text() }) catch {};
    }
    return true;
}

// ---- budgets, held by the kernel (BDG-1) ---------------------------------
//
// cgroup v2 is a filesystem: a group is a directory, and a ceiling is a
// line of text written into it. That is the whole machinery, which is
// why a budget costs this repository no daemon, no agent and no library.
// PID 1 stays in the root group (which is exempt from the no-internal-
// process rule), delegates the two controllers it uses to the children,
// makes one directory per budgeted world, writes the ceilings, and moves
// each world into its own on the way up.
//
// What the two ceilings do when they are reached is not the same, and
// the difference is the point: memory KILLS (the world is SIGKILLed
// inside its own group, and no other world feels it), cpu THROTTLES (the
// world waits for its next slice; nothing dies). The transcript shows
// the first as a signal and the second not at all, which is honest --
// a throttled world is a working world.

const BudgetState = enum { none, held, refused };

/// Everything cgroup v2 wants is a small string in a file it already
/// created. Errors are the caller's to state, never swallowed.
fn writeKernelFile(path: []const u8, data: []const u8) !void {
    const f = try std.fs.cwd().openFile(path, .{ .mode = .write_only });
    defer f.close();
    try f.writeAll(data);
}

/// What one served link is, for the server that speaks on it: its own address,
/// domain and declared peers. Null for a network that is not a served link.
fn linkOf(gpa: std.mem.Allocator, m: *const machine.Machine, n: *const machine.Network) !?names.Link {
    const dom = n.domain orelse return null;
    const self = switch (n.address) {
        .static => |s| s,
        .dhcp => return null,
    };
    var mine: std.ArrayList(machine.Peer) = .{};
    for (m.peers) |p| if (std.mem.eql(u8, p.network, n.name)) {
        try mine.append(gpa, p);
    };
    return .{
        .self_ip = self.ip,
        .mask = if (self.prefix == 0) 0 else ~@as(u32, 0) << @intCast(32 - @as(u6, self.prefix)),
        .domain = dom,
        .peers = mine.items,
    };
}

/// Become this link's own server of addresses and names (NAM-1).
///
/// PID 1 takes the two ports itself and forks only the loop, so a port
/// this machine could not take is reported by the process whose lines
/// are judged, in the order the boot happened. The child says nothing:
/// a server answering devices at its own pace would write a different
/// transcript every boot, and the transcript is the fixture (BDG-1).
///
/// The forked server is not a world. It is not declared, it has no
/// RESTART, and it is not waited on -- it is this machine being what it
/// said it was. If it dies, the reaper below says so by pid and the
/// boot no longer matches what was expected, which is the truth.
///
/// `forwarding` is whether this machine IS the way between its links: the kernel's switch has been
/// read back as on (FWD-1). Only then does the server offer the router and answer for the far
/// links, and only for `others`, the links it serves that are UP: a promise about the way is made
/// once the kernel has said there is one, never from the declaration alone.
fn serveNames(gpa: std.mem.Allocator, m: *const machine.Machine, n: *const machine.Network, led: *Ledger, forwarding: bool, others: []const *const machine.Network) !bool {
    const iface = try gpa.dupe(u8, n.interface);
    const srv = names.open(iface) catch |e| {
        try led.say("boot: names {s} -- {s} could not be served: {s} (the ports a server needs are 67 and 53)\n", .{ n.name, n.interface, @errorName(e) });
        return false;
    };
    var link = (try linkOf(gpa, m, n)) orelse return false;
    // A machine that is the way between its networks offers itself as the router to
    // those it serves, and answers for the full names on the other links it serves: the
    // front link's server knows what is behind it.
    if (forwarding) {
        link.router = link.self_ip;
        var far: std.ArrayList(names.Link) = .{};
        for (others) |o| {
            if (try linkOf(gpa, m, o)) |ol| try far.append(gpa, ol);
        }
        link.reach = try far.toOwnedSlice(gpa);
    }
    // everything this machine will say about the link is said BEFORE the
    // fork, so the two processes never contend for the console
    _ = try expect.namesLines(led.w(), m, n, "boot: ", forwarding, others);
    try led.echo();
    const pid = std.posix.fork() catch |e| {
        try led.say("boot: names {s} -- the server could not be started: {s}\n", .{ n.name, @errorName(e) });
        return false;
    };
    if (pid == 0) names.run(srv, link);
    // the parent keeps no fd to the ports: the child is the server
    std.posix.close(srv.dhcp_fd);
    std.posix.close(srv.dns_fd);
    return true;
}

/// Make this machine the way between its networks (FWD-1): the kernel's own
/// forwarding, switched on once every network is up and READ BACK before
/// anything is said. A line that says where the machine is, is said only after
/// asking (CON-1): a write the kernel ignored would otherwise announce a
/// machine that drops every packet it is asked to carry.
///
/// Forwarding is one switch for the whole machine, so the line names every
/// network it joined and not a pair; what that means for a reader is in the
/// line itself (`expect.forwardLine`).
fn forwardOn(m: *const machine.Machine, led: *Ledger) !bool {
    const path = "/proc/sys/net/ipv4/ip_forward";
    writeKernelFile(path, "1") catch |e| {
        try led.say("boot: forward -- the kernel would not be the way between networks: {s} ({s})\n", .{ @errorName(e), path });
        return false;
    };
    var held: [8]u8 = undefined;
    const got = blk: {
        const f = std.fs.cwd().openFile(path, .{}) catch |e| {
            try led.say("boot: forward -- the switch cannot be read back: {s} ({s})\n", .{ @errorName(e), path });
            return false;
        };
        defer f.close();
        break :blk f.read(&held) catch |e| {
            try led.say("boot: forward -- the switch cannot be read back: {s} ({s})\n", .{ @errorName(e), path });
            return false;
        };
    };
    if (got == 0 or held[0] != '1') {
        try led.say("boot: forward -- the kernel holds {s}, not 1: this machine is not the way between networks\n", .{std.mem.trim(u8, held[0..got], " \n")});
        return false;
    }
    _ = try expect.forwardLine(led.w(), m);
    return true;
}

/// Delegate the controllers and make one group per budgeted world. A
/// machine that declares no budget touches none of this and says
/// nothing: the plumbing a declaration did not ask for is not built.
fn cgroupPrepare(m: *const machine.Machine, out: *std.Io.Writer) BudgetState {
    var any = false;
    for (m.services) |s| {
        if (s.memory_mb != null or s.cpu_percent != null or s.tasks != null) any = true;
    }
    if (!any) return .none;

    writeKernelFile("/sys/fs/cgroup/cgroup.subtree_control", "+memory +cpu +pids") catch |e| {
        out.print("boot: budget -- the kernel would not delegate the controllers ({s}); no ceiling is held this boot\n", .{@errorName(e)}) catch {};
        return .refused;
    };
    for (m.services) |s| {
        if (s.memory_mb == null and s.cpu_percent == null and s.tasks == null) continue;
        var dbuf: [128]u8 = undefined;
        const dir = std.fmt.bufPrint(&dbuf, "/sys/fs/cgroup/{s}", .{s.name}) catch return .refused;
        std.fs.cwd().makeDir(dir) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => {
                out.print("boot: budget -- {s}: the group could not be made ({s}); no ceiling is held this boot\n", .{ s.name, @errorName(e) }) catch {};
                return .refused;
            },
        };
        var pbuf: [160]u8 = undefined;
        var vbuf: [48]u8 = undefined;
        if (s.memory_mb) |mb| {
            const path = std.fmt.bufPrint(&pbuf, "{s}/memory.max", .{dir}) catch return .refused;
            const val = std.fmt.bufPrint(&vbuf, "{d}", .{@as(u64, mb) * 1024 * 1024}) catch return .refused;
            writeKernelFile(path, val) catch |e| {
                out.print("boot: budget -- {s}: the memory ceiling was refused ({s}); no ceiling is held this boot\n", .{ s.name, @errorName(e) }) catch {};
                return .refused;
            };
        }
        if (s.tasks) |n| {
            // pids.max counts TASKS -- processes and threads together,
            // because that is the only number the kernel keeps. A fork or
            // a thread past it returns EAGAIN to the world rather than
            // killing it: a ceiling on how many, not a refusal to be
            // (THR-1).
            const path = std.fmt.bufPrint(&pbuf, "{s}/pids.max", .{dir}) catch return .refused;
            const val = std.fmt.bufPrint(&vbuf, "{d}", .{n}) catch return .refused;
            writeKernelFile(path, val) catch |e| {
                out.print("boot: budget -- {s}: the task ceiling was refused ({s}); no ceiling is held this boot\n", .{ s.name, @errorName(e) }) catch {};
                return .refused;
            };
        }
        if (s.cpu_percent) |pct| {
            // cpu.max is "<quota> <period>" in microseconds: a period of
            // 100 ms, and the slice of it the percentage asks for
            const path = std.fmt.bufPrint(&pbuf, "{s}/cpu.max", .{dir}) catch return .refused;
            const val = std.fmt.bufPrint(&vbuf, "{d} 100000", .{@as(u64, pct) * 1000}) catch return .refused;
            writeKernelFile(path, val) catch |e| {
                out.print("boot: budget -- {s}: the cpu ceiling was refused ({s}); no ceiling is held this boot\n", .{ s.name, @errorName(e) }) catch {};
                return .refused;
            };
        }
    }
    return .held;
}

/// Move a world into its own group. PID 1 does it after the fork, so the
/// one path serves a world that drops to a USER and one that does not:
/// a child that has already dropped its privileges could not write here.
fn cgroupJoin(svc: *const machine.Service, pid: i32) void {
    // every budget, or a world is left outside the group whose ceiling
    // was written for it -- which is what happened to the first TASKS
    // world: pids.max was set on a group nobody was in, and the boot
    // announced a ceiling it was not holding (THR-1). Third time a guard
    // has been narrower than the thing it guards.
    if (svc.memory_mb == null and svc.cpu_percent == null and svc.tasks == null) return;
    var pbuf: [160]u8 = undefined;
    const path = std.fmt.bufPrint(&pbuf, "/sys/fs/cgroup/{s}/cgroup.procs", .{svc.name}) catch return;
    var vbuf: [24]u8 = undefined;
    const val = std.fmt.bufPrint(&vbuf, "{d}", .{pid}) catch return;
    // a world that has already exited cannot be moved, and that is not
    // an error: the reaper's line is the one that matters
    writeKernelFile(path, val) catch {};
}

/// The wall clock in milliseconds. The machine sets no clock -- the
/// board has no RTC and there is no time protocol on the boot path --
/// so this reading only advances, and it comes from the same source as
/// the mtimes it is compared against. The day a machine sets its time,
/// this is the line to revisit (HLT-1).
fn nowMs() i64 {
    return std.time.milliTimestamp();
}

/// What a world's READY path is, if it is a SIGNAL: a regular file, and read WITHOUT following a
/// link. PID 1 reads this path as root, in a directory the world may own, and a world that owns a
/// directory can put a link there that points at a neighbour's heartbeat: it would be "ready" and
/// "fresh" on somebody else's word, which PID 1 followed as root. A link, a directory or anything
/// else at the path is no signal at all (OWN-1's review).
fn signalStat(path: []const u8) ?std.os.linux.Stat {
    const p = std.posix.toPosixPath(path) catch return null;
    var st: std.os.linux.Stat = undefined;
    // (`fstatat` with no-follow, not `lstat`: aarch64 has no such syscall, and the standard library's
    // wrapper names it anyway -- which only the cross build for that architecture can tell)
    if (std.os.linux.E.init(std.os.linux.fstatat(std.os.linux.AT.FDCWD, &p, &st, std.os.linux.AT.SYMLINK_NOFOLLOW)) != .SUCCESS) return null;
    if (!std.os.linux.S.ISREG(st.mode)) return null;
    return st;
}

/// When the world last touched its READY path, or null if the path is
/// gone: a world that deleted its own signal is not fresh either.
fn mtimeMs(path: []const u8) ?i64 {
    const st = signalStat(path) orelse return null;
    const t = st.mtime();
    return @as(i64, @intCast(t.sec)) * 1000 + @divTrunc(@as(i64, @intCast(t.nsec)), 1_000_000);
}

/// Take away a signal an earlier boot left, before the world that would make it exists. A signal is
/// THIS boot's word that the world serves: one left on a disk by the last boot would read as ready
/// before the world has run (RDY-1 named the trap; PID 1 closes it, so no script has to). `unlink`
/// removes what is there and never what a link points at.
fn removeStaleSignal(path: []const u8) !void {
    const p = try std.posix.toPosixPath(path);
    const rc = std.os.linux.unlink(&p);
    switch (std.os.linux.E.init(rc)) {
        .NOENT => {}, // nothing left over: the usual case
        .ISDIR => return error.IsADirectory,
        else => try kernel(rc),
    }
}

fn feedWatchdog(s: *Slots) void {
    if (s.wd_fd) |fd| _ = std.os.linux.write(fd, "\x00", 1);
}

/// What a child that has just exec'd holds open: `ls -l /proc/self/fd`, run as
/// a child of this process, with its stdin and stderr thrown away, so the only
/// things in its table are its stdio, the directory `ls` is reading, and
/// whatever this process left open across the exec. Null when there is no `ls`.
fn fdsAfterExec(gpa: std.mem.Allocator) !?[]u8 {
    var child = std.process.Child.init(&.{ "ls", "-l", "/proc/self/fd" }, gpa);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;
    child.spawn() catch return null;
    child.waitForSpawn() catch return null;
    const listing = try child.stdout.?.readToEndAlloc(gpa, 1 << 16);
    _ = try child.wait();
    return listing;
}

test "the watchdog's open flags are close-on-exec (WDG-1)" {
    // the declaration, on every host: write-only, and not inherited
    try std.testing.expect(watchdog_flags.CLOEXEC);
    try std.testing.expect(watchdog_flags.ACCMODE == .WRONLY);
}

test "a world that execs holds no watchdog descriptor (WDG-1)" {
    // The question that DECIDES (MNT-1), where there is a kernel to ask: what does a child that
    // exec's from here hold? The production open, on a device no stdio of the child will be. The
    // declaration above can stay true while the open ignores it, which is the defect this guards
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const sys = std.os.linux;
    const gpa = std.testing.allocator;
    const kept = openWatchdog("/dev/zero");
    try std.testing.expectEqual(sys.E.SUCCESS, sys.E.init(kept));
    defer _ = sys.close(@intCast(kept));
    const after = (try fdsAfterExec(gpa)) orelse return error.SkipZigTest;
    defer gpa.free(after);
    try std.testing.expect(std.mem.indexOf(u8, after, "/dev/zero") == null);

    // A judge that always convicts, or never does, is no judge (VDCT-1): the same descriptor opened
    // WITHOUT the flag is the one a world inherits, and the same question must see it
    const bare = sys.open("/dev/zero", .{ .ACCMODE = .WRONLY }, 0);
    try std.testing.expectEqual(sys.E.SUCCESS, sys.E.init(bare));
    defer _ = sys.close(@intCast(bare));
    const leaked = (try fdsAfterExec(gpa)).?;
    defer gpa.free(leaked);
    try std.testing.expect(std.mem.indexOf(u8, leaked, "/dev/zero") != null);
}

test "the committed slot is read from config.txt and a commit swaps the two prefixes" {
    const cfg = "arm_64bit=1\nos_prefix=slots/A/\n[tryboot]\nos_prefix=slots/B/\n";
    try std.testing.expectEqual(@as(?u8, 'A'), committedSlot(cfg));
    const after = try commitText(std.testing.allocator, cfg, 'A', 'B');
    defer std.testing.allocator.free(after);
    try std.testing.expectEqualStrings("arm_64bit=1\nos_prefix=slots/B/\n[tryboot]\nos_prefix=slots/A/\n", after);
    try std.testing.expectEqual(@as(?u8, 'B'), committedSlot(after));
    try std.testing.expectEqual(@as(?u8, null), committedSlot("kernel=kernel8.img\n"));
    try std.testing.expectError(error.NoTryboot, commitText(std.testing.allocator, "os_prefix=slots/A/\n", 'A', 'B'));
}

test "a world with a window is ready at its signal but PROVEN only one window later, and staleness latches" {
    const watched = machine.Service{
        .name = "kds",
        .line = 1,
        .run = &.{"/kds"},
        .restart = .always,
        .after = &.{},
        .needs = &.{},
        .ready = "/run/kds.ready",
        .health = 5,
        .memory_mb = null,
        .cpu_percent = null,
        .tasks = null,
        .user = null,
        .sees = null,
        .rationale = "a world that keeps saying it serves",
    };
    const unwatched = machine.Service{
        .name = "poste",
        .line = 2,
        .run = &.{"/poste"},
        .restart = .always,
        .after = &.{},
        .needs = &.{},
        .ready = "/run/poste.ready",
        .health = null,
        .memory_mb = null,
        .cpu_percent = null,
        .tasks = null,
        .user = null,
        .sees = null,
        .rationale = "a world that answers for its start and never again",
    };

    var s = Slot{ .service = &watched, .state = .running, .signalled_ready = true, .signalled_ms = 1_000 };
    // ready the moment it signals -- that is what AFTER waits for
    try std.testing.expect(s.ready());
    // ... and proven only one full window later -- that is what a TRIAL waits for
    try std.testing.expect(!s.proven(1_000));
    try std.testing.expect(!s.proven(5_999));
    try std.testing.expect(s.proven(6_000));

    // staleness latches: a world that stopped serving stays unproven,
    // because a feed that resumed on recovery would hide the very fault
    // the watchdog exists for
    s.stale = true;
    try std.testing.expect(!s.proven(60_000));

    // a world with no window owes nothing, and proves nothing
    const p = Slot{ .service = &unwatched, .state = .running, .signalled_ready = true, .signalled_ms = 1_000 };
    try std.testing.expect(p.proven(0));

    // and one that never signalled is neither ready nor proven
    const q = Slot{ .service = &watched, .state = .running };
    try std.testing.expect(!q.ready());
    try std.testing.expect(!q.proven(1_000_000));
}

const is_linux = builtin.os.tag == .linux;

// One slot per service, in plan order. AFTER waits for READINESS, and
// readiness depends on the kind of service the RESTART policy implies:
//   RESTART never       a one-shot -- ready when it has EXITED 0; if it
//                       exits otherwise, what waited on it never starts
//   always / on_failure a daemon  -- ready as soon as it has been SPAWNED,
//                       unless it declares READY "<path>", in which case
//                       it is ready when it CREATES that path: its own
//                       word that it is serving, not the kernel's word
//                       that it was started. A daemon that never signals
//                       never becomes ready: its dependents never start
//                       and an A/B trial never commits -- the safe
//                       outcome, and the reason there is no timer here
//                       (a timer would race a boot; the wait does not).
// (systemd's oneshot/simple distinction without a Type= seat; the OS-2
// transcripts interleaved because AFTER only ordered spawns, PROTOCOL.md.)
const State = enum { pending, running, exited, never };

const Slot = struct {
    service: *const machine.Service,
    /// what the kernel will hold this world to, read off the machine and
    /// the service together and settled ONCE, here, because the spawn
    /// path has the service and not the machine (NS-1)
    held: confine.Confinement = .{ .network = true, .process = true, .threads = true },
    state: State = .pending,
    pid: i32 = 0,
    code: u32 = 0,
    signaled: bool = false, // killed by a signal (the kernel's word)
    signalled_ready: bool = false, // its READY path has been seen (its own word)
    signalled_ms: i64 = 0, // when PID 1 saw that word
    stale: bool = false, // it stopped refreshing, and that latches
    restarts: usize = 0,

    fn ready(self: Slot) bool {
        return switch (self.service.restart) {
            .never => self.state == .exited and !self.signaled and self.code == 0,
            .always, .on_failure => if (self.service.ready != null)
                self.signalled_ready
            else
                self.state == .running or self.state == .exited,
        };
    }
    /// still waiting for a declared signal
    fn awaiting(self: Slot) bool {
        return self.service.ready != null and !self.signalled_ready and self.state == .running;
    }
    /// a one-shot that ended badly blocks its dependents for good
    fn failed(self: Slot) bool {
        return self.service.restart == .never and self.state == .exited and (self.signaled or self.code != 0);
    }
    /// A world with a declared window has PROVEN it serves only once a
    /// full window has passed since it signalled, and it is not stale.
    /// This is what a trial waits for: "serving" that survives one
    /// window is worth committing an update on; "serving" measured at
    /// the instant of the signal is not (HLT-1). A world with no window
    /// proves nothing and owes nothing.
    fn proven(self: Slot, now: i64) bool {
        const window = self.service.health orelse return true;
        if (!self.signalled_ready or self.stale) return false;
        return now - self.signalled_ms >= @as(i64, window) * 1000;
    }
};

/// Every world with a window must refresh its READY path within it. The
/// first that does not is said once and LATCHES: a world that stopped
/// serving has already cost the box its promise, and a feed that
/// resumed on recovery would hide exactly the fault the watchdog exists
/// for. Returns true when something went stale in this look.
fn checkHealth(slots: []Slot, out: *std.Io.Writer) !bool {
    var went_stale = false;
    const now = nowMs();
    for (slots) |*s| {
        const window = s.service.health orelse continue;
        if (!s.signalled_ready or s.stale) continue;
        const path = s.service.ready.?;
        const touched = mtimeMs(path) orelse {
            s.stale = true;
            went_stale = true;
            try out.print("boot: {s} -- stale: {s} is gone; a world that deletes its own signal is not serving\n", .{ s.service.name, path });
            continue;
        };
        const age = now - touched;
        if (age > @as(i64, window) * 1000) {
            s.stale = true;
            went_stale = true;
            try out.print("boot: {s} -- stale: {s} has not been refreshed for {d}s (window {d}s)\n", .{ s.service.name, path, @divTrunc(age, 1000), window });
        }
    }
    return went_stale;
}

pub fn run(gpa: std.mem.Allocator, p: plan.Plan, opts: Options, out: *std.Io.Writer) !u8 {
    if (!is_linux) {
        try out.print("boot: init is a Linux act; this binary was built for {s} -- use `harb plan` here, or `zig build cross`\n", .{@tagName(builtin.os.tag)});
        try out.flush();
        return 2;
    }
    return runLinux(gpa, p, opts, out);
}

fn runLinux(gpa: std.mem.Allocator, p: plan.Plan, opts: Options, out: *std.Io.Writer) !u8 {
    const linux = std.os.linux;
    const m = p.machine;
    const pid: i32 = @intCast(linux.getpid());
    const is_pid1 = pid == 1;
    var led = Ledger.init(gpa, out);
    defer led.deinit();

    try led.say(expect.fmt_banner, .{ m.name, @tagName(m.profile), @tagName(m.arch), @tagName(m.board), pid, if (is_pid1) "" else " (not PID 1)" });
    if (m.profile != .hosted) {
        try out.print("boot: refused -- init boots the hosted profile only; a {s} machine boots from its own substrate\n", .{@tagName(m.profile)});
        try out.flush();
        return 2;
    }
    if (!is_pid1 and !opts.rehearse) {
        try out.print("boot: refused -- init is PID 1's act; from pid {d} pass --rehearse to run the plan as a twin\n", .{pid});
        try out.flush();
        return 2;
    }
    if (opts.rehearse) try out.print("boot: rehearsal -- mounts are narrated, not executed; services are spawned\n", .{});
    // The initial filesystem is a tmpfs, and a tmpfs's root is mode 1777: until it is closed any identity
    // can make files in `/`. Found by `harb own`, the witness of OWN-1, the first time a world was asked
    // whether it could. The machine's root is the machine's. Silent when it works, because nothing here
    // claims it (the pinned boot of qemu_own is what shows it, from inside a world); a console line when
    // it does not, because an identity could then write the machine's root.
    if (!opts.rehearse) if (closeDir("/")) |why| try out.print("boot: root -- could not be closed: {s}; an identity could make files in /\n", .{why});

    var slots: std.ArrayList(Slot) = .{};
    defer slots.deinit(gpa);
    for (p.steps) |step| if (step == .service) try slots.append(gpa, .{
        .service = step.service,
        .held = try confine.Confinement.ofAlloc(m.*, step.service.*, gpa),
    });

    var ab: ?Slots = if (m.slots) |dev| Slots{ .dev = dev } else null;
    // the link this machine became the server of, if it declared one.
    // It is the reason a box with no running world is not a box with
    // nothing left to do (NAM-1).
    var serving: ?[]const u8 = null;
    var serving_buf: std.ArrayList(u8) = .{};
    // the links a machine that forwards will serve, up and waiting for the way (FWD-1)
    var await_way: std.ArrayList(*const machine.Network) = .{};
    // the mounts the kernel refused: a world's own directory (STATE) is never made on one (OWN-1)
    var unmounted: std.ArrayList([]const u8) = .{};
    var said_serving = false;
    if (opts.hold and ab != null) try out.print("boot: --hold: a trial will not be committed and the watchdog will not be fed -- the rollback instrument\n", .{});

    for (p.steps) |step| switch (step) {
        .console => |c| try sayConsole(&led, c, opts.rehearse),
        .slots => |dev| {
            if (opts.rehearse) {
                try out.print("boot: slots on {s} -- rehearsed, not read\n", .{dev});
                continue;
            }
            // proc is not mounted yet at this step: the cmdline is read after the mounts
            try led.say(expect.fmt_slots, .{dev});
        },
        .mount => |mt| {
            if (opts.rehearse) {
                try out.print("boot: mount {s} at {s} -- rehearsed, not executed\n", .{ @tagName(mt.fs), mt.at });
                continue;
            }
            const fstype: [:0]const u8 = switch (mt.fs) {
                .proc => "proc",
                .sysfs => "sysfs",
                .devtmpfs => "devtmpfs",
                .tmpfs => "tmpfs",
                .ext4 => "ext4",
                .vfat => "vfat",
                .littlefs => "littlefs",
                .cgroup2 => "cgroup2",
            };
            const dir = try gpa.dupeZ(u8, mt.at);
            defer gpa.free(dir);
            const special: [:0]const u8 = if (mt.device) |d| try gpa.dupeZ(u8, d) else fstype;
            defer if (mt.device != null) gpa.free(special);
            var flags: u32 = 0;
            for (mt.options) |o| flags |= switch (o) {
                .rw => @as(u32, 0),
                .ro => linux.MS.RDONLY,
                .noatime => linux.MS.NOATIME,
                .nosuid => linux.MS.NOSUID,
                .nodev => linux.MS.NODEV,
                .noexec => linux.MS.NOEXEC,
            };
            const rc = linux.mount(special.ptr, dir.ptr, fstype.ptr, flags, 0);
            switch (linux.E.init(rc)) {
                .SUCCESS => try led.say(expect.fmt_mount_done, .{ @tagName(mt.fs), mt.at }),
                .BUSY => try led.say("boot: mount {s} at {s} -- already mounted (EBUSY), kept\n", .{ @tagName(mt.fs), mt.at }),
                else => |e| {
                    try led.say("boot: mount {s} at {s} -- refused by the kernel: {s}\n", .{ @tagName(mt.fs), mt.at, @tagName(e) });
                    try unmounted.append(gpa, mt.at); // a directory a world is to own is never made on its mount point
                },
            }
        },
        .capability => |c| try led.say(expect.fmt_capability, .{ if (c.granted) "grant" else "refuse", @tagName(c.name), @tagName(machine.kindOf(c.name)) }),
        .pin => |pn| try led.say(expect.fmt_pin, .{ pn.name, pn.gpio, @tagName(pn.mode) }),
        .network => |n| {
            if (opts.rehearse) {
                try out.print("boot: network {s} -- {s} {s} -- rehearsed, not executed\n", .{ n.name, n.interface, if (n.address == .dhcp) "dhcp" else "static" });
                continue;
            }
            try out.flush();
            const up = try netcfg.bringUp(n, led.w(), "boot: ");
            // the machine becomes its link's own server of names, if it
            // declared itself one (NAM-1). The two ports are taken HERE,
            // by PID 1, so that "this machine could not become the server
            // it declared itself" is said in order in the transcript that
            // is judged; only the loop is forked.
            if (up and n.domain != null) {
                if (m.forward) {
                    // a machine that is the way between its links starts its servers once
                    // the kernel has said it is one (the forward step, below)
                    try await_way.append(gpa, n);
                } else if (try serveNames(gpa, m, n, &led, false, &.{})) {
                    // every link it serves, for the line it says at the end
                    if (serving_buf.items.len > 0) try serving_buf.appendSlice(gpa, " and ");
                    try serving_buf.appendSlice(gpa, n.domain.?);
                    serving = serving_buf.items;
                }
            }
            try led.echo();
        },
        // the way between the networks, once every one of them is up (FWD-1)
        .forward => if (opts.rehearse) {
            try out.print("boot: forward -- rehearsed, not executed\n", .{});
        } else {
            const on = try forwardOn(m, &led);
            try led.echo();
            // The servers speak for the way only now, and only if the switch read back as on
            // (CON-1, NS-1): a lease that names this machine the router, or a name answered
            // across a link, over a switch that did not turn on would be a promise made before
            // it could be kept. A box whose switch failed still serves each link its own names.
            for (await_way.items) |n| {
                var up_others: std.ArrayList(*const machine.Network) = .{};
                if (on) for (await_way.items) |o| if (o != n) try up_others.append(gpa, o);
                if (try serveNames(gpa, m, n, &led, on, up_others.items)) {
                    if (serving_buf.items.len > 0) try serving_buf.appendSlice(gpa, " and ");
                    try serving_buf.appendSlice(gpa, n.domain.?);
                    serving = serving_buf.items;
                }
                try led.echo();
            }
        },
        .service => {}, // started below, when what it comes AFTER is ready
    };
    // the slots, once proc and dev exist: which one booted, which is committed, the watchdog
    if (ab) |*s| if (!opts.rehearse) {
        s.booted = bootedSlot(gpa);
        if (s.booted == null) {
            try out.print("boot: slot -- no harb.slot on the cmdline: a single boot, nothing to commit\n", .{});
            s.done = true;
        } else {
            const devz = try gpa.dupeZ(u8, s.dev);
            defer gpa.free(devz);
            switch (linux.E.init(linux.mount(devz.ptr, "/boot", "vfat", 0, 0))) {
                .SUCCESS => s.mounted = true,
                else => |e| try out.print("boot: slot {c} -- the boot partition {s} refused: {s}; nothing can be committed\n", .{ s.booted.?, s.dev, @tagName(e) }),
            }
            if (s.mounted) {
                if (std.fs.cwd().readFileAlloc(gpa, "/boot/config.txt", 1 << 16)) |cfg| {
                    defer gpa.free(cfg);
                    s.committed = committedSlot(cfg);
                } else |e| try out.print("boot: slot {c} -- /boot/config.txt unreadable: {s}\n", .{ s.booted.?, @errorName(e) });
                if (s.committed) |c| {
                    if (c == s.booted.?) {
                        try out.print("boot: slot {c} -- committed, steady\n", .{c});
                        s.done = true;
                    } else {
                        try out.print("boot: slot {c} -- a trial (committed is {c}); the watchdog holds the rollback until the boot is judged\n", .{ s.booted.?, c });
                    }
                } else {
                    try out.print("boot: slot {c} -- config.txt names no committed slot; nothing can be committed\n", .{s.booted.?});
                    s.done = true;
                }
            } else s.done = true;
        }
        // the watchdog: armed by opening it; fed from the reaper loop; the
        // magic close disarms it before a clean restart. Everything said so
        // far is flushed first: arming is a hardware act, and a board that
        // resets on it must not take the transcript with it.
        try out.flush();
        if (watchdogOff(gpa)) {
            try led.say(expect.fmt_watchdog_off, .{});
        } else {
            const wd = openWatchdog("/dev/watchdog");
            switch (linux.E.init(wd)) {
                .SUCCESS => {
                    s.wd_fd = @intCast(wd);
                    try led.say(expect.fmt_watchdog_armed, .{});
                },
                else => |e| try led.say("boot: watchdog -- /dev/watchdog refused: {s}; a trial cannot roll back by hardware\n", .{@tagName(e)}),
            }
        }
        try out.flush();
    };

    // this device's own key, before anything that might want to use it
    const device = identityOf(m, out);
    if (device) |id| {
        try led.say("boot: identity -- ed25519, custody a file at {s} -- {s} on this device, fingerprint {s}\n", .{
            m.identity.?,
            if (id.created) "created" else "already",
            id.fingerprint,
        });
    }

    // the ceilings, before the first world runs: a world must never see
    // a boot in which its group did not exist yet (BDG-1)
    switch (cgroupPrepare(m, out)) {
        .none => {},
        .held => {
            _ = try expect.budgetLine(led.w(), m);
            try led.echo();
        },
        // refused: the console said why, and the ledger lacks the line
        // the expectation has -- so the verdict differs and a trial holds
        .refused => try out.flush(),
    }
    _ = try expect.healthLine(led.w(), m);
    // what the kernel will refuse each world, said before any of them runs
    _ = try expect.confineLine(led.w(), m);
    _ = try expect.floorLine(led.w(), m);
    try led.echo();
    // the directories the worlds own, made and handed over before any of them exists (OWN-1)
    try prepareState(m, slots.items, unmounted.items, opts.rehearse, &led, out);
    // ... and the signals an earlier boot left, which are not this boot's word (after the directories,
    // so that nothing is removed through a path that was not verified)
    try clearSignals(slots.items, opts.rehearse, out);
    try startReady(gpa, slots.items, &led);
    try out.flush();

    // the reaper: PID 1's standing duty -- polled, so the watchdog is fed
    // between exits and a trial is committed the moment it is earned
    var turns: usize = 0;
    var judged = false; // the verdict is given once
    var held = false; // a trial the judge refused: not committed, the watchdog no longer fed
    var starved = false; // a world stopped serving: the feed stops with it
    var has_health = false;
    for (slots.items) |sl| {
        if (sl.service.health != null) has_health = true;
    }
    while (true) {
        // the hardware is fed only while every world is fresh (HLT-1)
        if (ab) |*s| if (!opts.hold and !held and !starved) feedWatchdog(s);
        if (try checkHealth(slots.items, out) and !starved) {
            starved = true;
            if (ab) |*s| {
                if (s.wd_fd != null) {
                    try out.print("boot: the watchdog is no longer fed -- what follows is the board's reset, into the committed slot\n", .{});
                } else {
                    try out.print("boot: no watchdog is armed here to answer; on the board this is where the reset comes from\n", .{});
                }
                if (!s.done and !opts.hold) {
                    try out.print("boot: slot {c} -- held: a world stopped serving before the trial was committed; not committed, the next boot is {c}\n", .{ s.booted orelse '?', s.committed orelse '?' });
                    s.done = true;
                }
            } else {
                try out.print("boot: this machine declares no SLOTS and arms no watchdog; on a board a stale world is what resets it\n", .{});
            }
            try out.flush();
        }
        if (!judged and !opts.rehearse) {
            // the verdict comes when every service is READY -- a one-shot
            // exited 0, a daemon spawned or signalled -- never merely started:
            // a one-shot that fails, or a service its failure held back, keeps
            // a trial uncommitted, and the rollback is the answer. (Committing
            // on "started" also raced the last one-shot's output with the
            // commit line in the transcript.) Then the machine judges its own
            // ledger against the expectation the image carries, and a trial
            // is committed only on a match (JDG-1).
            var all_ready = true;
            for (slots.items) |sl| if (!sl.ready()) {
                all_ready = false;
            };
            // ... and, where a window is declared, ready THROUGH one of
            // them: a trial is not committed on a world that served for
            // an instant (HLT-1)
            const now = nowMs();
            var all_proven = true;
            for (slots.items) |sl| if (!sl.proven(now)) {
                all_proven = false;
            };
            if (all_ready and all_proven) {
                judged = true;
                const matches = try judgeBoot(gpa, &led, out);
                // the record, after the verdict and before the commit:
                // what this boot was is what the entry is worth (JRN-1)
                const recorded = journalWrite(gpa, m, device, matches, true, out);
                if (ab) |*s| if (!s.done and !opts.hold) {
                    if (matches and !recorded) {
                        held = true;
                        try out.print("boot: slot {c} -- held: the boot matched its expectation but this machine could not keep its own record; not committed, the next boot is {c}\n", .{ s.booted orelse '?', s.committed orelse '?' });
                        s.done = true;
                    } else if (matches) {
                        if (std.fs.cwd().readFileAlloc(gpa, "/boot/config.txt", 1 << 16)) |cfg| {
                            defer gpa.free(cfg);
                            if (commitText(gpa, cfg, s.committed.?, s.booted.?)) |new_cfg| {
                                defer gpa.free(new_cfg);
                                if (std.fs.cwd().createFile("/boot/config.txt", .{ .truncate = true })) |f| {
                                    defer f.close();
                                    f.writeAll(new_cfg) catch {};
                                    f.sync() catch {};
                                    linux.sync();
                                    // the rule this line states is the rule the loop enforced:
                                    // ready, past the window where one is declared (HLT-1), and
                                    // the boot recognised as this machine's own
                                    try out.print("boot: slot {c} -- committed: every service is ready{s} and the boot matches its expectation; config.txt now boots {c}, {c} is the fallback\n", .{ s.booted.?, if (has_health) " and has held its health window" else "", s.booted.?, s.committed.? });
                                } else |e| try out.print("boot: slot {c} -- commit refused: config.txt: {s}\n", .{ s.booted.?, @errorName(e) });
                            } else |e| try out.print("boot: slot {c} -- commit refused: {s}\n", .{ s.booted.?, @errorName(e) });
                        } else |e| try out.print("boot: slot {c} -- commit refused: config.txt unreadable: {s}\n", .{ s.booted.?, @errorName(e) });
                    } else {
                        // the judge's answer is the rollback's: the watchdog is
                        // no longer fed, the board resets, the firmware boots
                        // the committed slot (the emulator, which cannot arm
                        // it, runs on to the halt and boots it next)
                        held = true;
                        try out.print("boot: slot {c} -- held: every service is ready but the boot is not the one expected; not committed, the watchdog is no longer fed -- the next boot is {c}\n", .{ s.booted.?, s.committed.? });
                    }
                    s.done = true;
                };
                try out.flush();
            }
        }
        if (opts.halt_on_verdict and (judged or starved)) {
            // a real init would keep the machine alive here, for years --
            // or let the watchdog end it, which is the starved case
            if (judged) {
                try out.print("boot: --halt-on-verdict: every service is ready and the boot is judged; the court ends what a real init never would\n", .{});
            } else {
                try out.print("boot: --halt-on-verdict: a world stopped serving and the feed stopped with it; the court ends what the board's reset would end\n", .{});
            }
            break;
        }
        var alive: usize = 0;
        var pending: usize = 0;
        for (slots.items) |s| switch (s.state) {
            .running => alive += 1,
            .pending => pending += 1,
            else => {},
        };
        if (alive == 0) {
            if (pending > 0) {
                // nothing runs and something still waits: name it, and name
                // the declared signal that never came, if that is the reason
                for (slots.items) |*s| if (s.state == .pending) {
                    s.state = .never;
                    var why: []const u8 = "what it comes AFTER did not become ready";
                    for (s.service.after) |a| {
                        for (slots.items) |d| if (std.mem.eql(u8, d.service.name, a) and d.service.ready != null and !d.signalled_ready) {
                            why = "what it comes AFTER never signalled ready";
                        };
                    }
                    try led.say("boot: {s} never started -- {s}\n", .{ s.service.name, why });
                };
            }
            if (serving) |dom| {
                // A machine that is its link's server of names has not
                // finished when its last one-shot has. Every device on
                // this network asks it for an address at every boot and
                // for a name whenever somebody types one; a box that
                // stopped the moment nobody was asking would be a box
                // that works until it is needed (NAM-1).
                if (!said_serving) {
                    try out.print("boot: every service has ended -- and this machine is still {s}: a server stops when the machine stops, not when the asking does\n", .{dom});
                    said_serving = true;
                    try out.flush();
                }
            } else {
                try out.print("boot: every service has ended -- init has nothing left to keep alive\n", .{});
                break;
            }
        }
        if (opts.turns) |t| if (turns >= t) {
            try out.print("boot: --turns {d} reached with {d} service(s) still running -- the instrument ends what a real init never would\n", .{ turns, alive });
            // what the bound cut short: a service still waiting, and the
            // declared signal that never came, so the negative case is read
            // off the transcript rather than inferred from its silence
            for (slots.items) |s| if (s.state == .pending) {
                var why: []const u8 = "what it comes AFTER is not ready yet";
                for (s.service.after) |a| {
                    for (slots.items) |d| if (std.mem.eql(u8, d.service.name, a) and d.service.ready != null and !d.signalled_ready) {
                        why = "what it comes AFTER has not signalled ready";
                    };
                }
                try out.print("boot: {s} has not started -- {s}\n", .{ s.service.name, why });
            };
            break;
        };
        const poll = try pollReady(slots.items, &led);
        if (poll.signalled) {
            try startReady(gpa, slots.items, &led);
            try out.flush(); // the console, as it happens: a served machine
            // never reaches the reaper's flush, because no child exits
        }
        // When to POLL instead of blocking on wait4. A one-shot machine
        // could block: every change arrived as an exit. A machine whose
        // worlds SERVE cannot -- a daemon never exits, and blocking on
        // one costs the boot everything after it (SRV-1: the box's
        // second world never started, and the court's timeout was the
        // only thing that noticed). So poll while any of these is true:
        // the watchdog needs feeding, a declared signal is outstanding,
        // a service has not started yet (only a signal can start it), or
        // the court's instrument is still owed a verdict.
        const polling = ab != null or poll.awaiting or pending > 0 or has_health or (opts.halt_on_verdict and !judged);
        var status: u32 = 0;
        const rc = linux.wait4(-1, &status, if (polling) linux.W.NOHANG else 0, null);
        if (polling and rc == 0) {
            // nothing exited: feed, wait a quarter second, look again
            const ts: linux.timespec = .{ .sec = 0, .nsec = 250_000_000 };
            _ = linux.nanosleep(&ts, null);
            continue;
        }
        switch (linux.E.init(rc)) {
            .SUCCESS => {},
            .INTR => continue,
            .CHILD => {
                try out.print("boot: no child left to wait for\n", .{});
                break;
            },
            else => |e| {
                try out.print("boot: wait refused: {s}\n", .{@tagName(e)});
                break;
            },
        }
        const ended: i32 = @intCast(rc);
        turns += 1;
        var known = false;
        for (slots.items) |*c| {
            if (c.pid != ended or c.state != .running) continue;
            known = true;
            c.state = .exited;
            const exited = linux.W.IFEXITED(status);
            c.code = if (exited) linux.W.EXITSTATUS(status) else 0;
            c.signaled = !exited;
            var pb: [16]u8 = undefined;
            const pids = std.fmt.bufPrint(&pb, "{d}", .{ended}) catch "?";
            if (exited) {
                try led.say(expect.fmt_exited, .{ c.service.name, pids, c.code });
            } else if (linux.W.IFSIGNALED(status)) {
                try led.say("boot: {s} (pid {s}) killed by signal {d}\n", .{ c.service.name, pids, linux.W.TERMSIG(status) });
            } else {
                try led.say("boot: {s} (pid {s}) ended (status {d})\n", .{ c.service.name, pids, status });
            }
            const wants_restart = switch (c.service.restart) {
                .never => false,
                .always => true,
                .on_failure => !(exited and c.code == 0),
            };
            if (wants_restart) {
                if (c.restarts >= opts.max_restarts) {
                    try led.say("boot: {s} -- restart {s}, but gave up after {d} restarts\n", .{ c.service.name, @tagName(c.service.restart), c.restarts });
                } else {
                    c.restarts += 1;
                    const again = spawn(gpa, c.service, c.held) catch |e| {
                        try led.say("boot: restart {s} -- could not spawn: {s}\n", .{ c.service.name, @errorName(e) });
                        break;
                    };
                    c.pid = again.pid;
                    c.state = .running;
                    cgroupJoin(c.service, again.pid);
                    try led.say("boot: restart {s} ({s}, {d}/{d}) -- pid {d}\n", .{ c.service.name, @tagName(c.service.restart), c.restarts, opts.max_restarts, again.pid });
                    try led.flush();
                    release(again.gate);
                }
            }
            break;
        }
        if (!known) try led.say("boot: reaped orphan pid {d}\n", .{ended});
        // a one-shot that failed blocks what waited on it; a service whose
        // AFTER just became ready starts now
        for (slots.items) |*s| {
            if (s.state != .pending) continue;
            for (s.service.after) |a| {
                for (slots.items) |d| if (std.mem.eql(u8, d.service.name, a) and d.failed()) {
                    s.state = .never;
                    try led.say("boot: {s} never started -- it comes AFTER {s}, which exited {d}\n", .{ s.service.name, a, d.code });
                };
            }
        }
        try startReady(gpa, slots.items, &led);
        try out.flush();
    }
    if (is_pid1 and !opts.rehearse) {
        // PID 1 may not exit (the kernel panics); it restarts the machine.
        // Under QEMU -no-reboot this is how a boot ends and the transcript
        // closes. Inside a pid namespace the kernel does not reboot: it
        // sends this init SIGHUP and the namespace ends (reboot(2), "in a
        // pid namespace other than the initial one") -- the WSL transcript
        // stops at this line and unshare exits nonzero, by the kernel's
        // rule (PROTOCOL.md, OS-3 finding 4).
        if (ab) |*s| {
            if (opts.hold) {
                // the instrument: the trial is held -- never committed. With a
                // watchdog armed, it stays unfed and the hardware answers (a
                // reset, then the firmware boots the committed slot). Without
                // one, the trial ends as any uncommitted trial does: a restart,
                // and the next boot is the committed slot.
                try out.print("boot: --hold: the trial is held, not committed\n", .{});
                if (s.wd_fd != null) {
                    try out.print("boot: --hold: the watchdog stays armed and unfed; what follows is the hardware's answer\n", .{});
                    try out.flush();
                    while (true) {
                        const ts: linux.timespec = .{ .sec = 5, .nsec = 0 };
                        _ = linux.nanosleep(&ts, null);
                    }
                }
                try out.print("boot: --hold: no watchdog to answer here; the trial ends without a commit, the next boot is the committed slot\n", .{});
            } else if (s.wd_fd) |fd| {
                _ = linux.write(fd, "V", 1); // the magic close: disarmed before a clean restart
                _ = linux.close(fd);
            }
        }
        try out.print("boot: init halts the machine -- reboot(RESTART)\n", .{});
        try out.flush();
        linux.sync();
        const rc = linux.reboot(.MAGIC1, .MAGIC2, .RESTART, null);
        try out.print("boot: reboot refused by the kernel: {s} -- init exits\n", .{@tagName(linux.E.init(rc))});
        try out.flush();
        return 0;
    }
    try out.print("boot: init exits -- {s}\n", .{if (opts.rehearse) "rehearsal over" else "boot over"});
    try out.flush();
    return 0;
}

/// Look for the declared signals that have appeared since the last look,
/// and report BOTH facts the loop needs: whether one APPEARED (a service
/// that comes AFTER it can start now) and whether one is still
/// OUTSTANDING (a reason to keep polling rather than block on a child
/// that may never exit). Before daemons, one boolean sufficed because
/// every change arrived as an exit; SRV-1 is where that stopped being
/// true.
fn pollReady(slots: []Slot, led: *Ledger) !struct { signalled: bool, awaiting: bool } {
    var signalled = false;
    var awaiting = false;
    for (slots) |*s| {
        if (!s.awaiting()) continue;
        const path = s.service.ready.?;
        if (signalStat(path) != null) {
            s.signalled_ready = true;
            s.signalled_ms = nowMs();
            signalled = true;
            try led.say(expect.fmt_ready, .{ s.service.name, path });
        } else {
            awaiting = true;
        }
    }
    return .{ .signalled = signalled, .awaiting = awaiting };
}

/// Start every pending service whose AFTER services are all ready, in
/// plan order, until nothing more can start.
fn startReady(gpa: std.mem.Allocator, slots: []Slot, led: *Ledger) !void {
    var progressed = true;
    while (progressed) {
        progressed = false;
        for (slots) |*s| {
            if (s.state != .pending) continue;
            var ok = true;
            for (s.service.after) |a| {
                for (slots) |d| if (std.mem.eql(u8, d.service.name, a) and !d.ready()) {
                    ok = false;
                };
            }
            if (!ok) continue;
            const started = spawn(gpa, s.service, s.held) catch |e| {
                s.state = .never;
                try led.say("boot: start {s} -- could not spawn: {s}\n", .{ s.service.name, @errorName(e) });
                progressed = true;
                continue;
            };
            s.pid = started.pid;
            s.state = .running;
            cgroupJoin(s.service, started.pid); // inside its ceiling before its first instruction
            progressed = true;
            var pb: [16]u8 = undefined;
            try expect.startLine(led.w(), s.service, std.fmt.bufPrint(&pb, "{d}", .{started.pid}) catch "?");
            try led.flush();
            release(started.gate);
        }
    }
}

/// A world, forked and HELD at the gate.
///
/// Between the fork and the exec the child blocks on a pipe, so PID 1
/// can put it in its cgroup and SAY that it started before the world
/// says anything at all. Without that gate the transcript's order is a
/// race between a fork and a print, and a fast world wins it often
/// enough to make a pinned transcript flap: `harb id` -- a static
/// binary that prints one line and exits -- overtook its own start line
/// the first time budgets changed the timing (BDG-1). A gate costs one
/// pipe and makes the order a fact.
///
/// It is also where a declared identity is dropped, which must happen
/// between fork and exec -- the one moment where the child is still
/// ours and not yet the program's. Group first, then user: after setuid
/// there is no privilege left to change the group with.
const Started = struct { pid: i32, gate: std.posix.fd_t };

fn spawn(gpa: std.mem.Allocator, svc: *const machine.Service, held: confine.Confinement) !Started {
    var argv = try gpa.alloc(?[*:0]const u8, svc.run.len + 1);
    defer gpa.free(argv);
    for (svc.run, 0..) |a, i| argv[i] = (try gpa.dupeZ(u8, a)).ptr;
    argv[svc.run.len] = null;
    const path = try gpa.dupeZ(u8, svc.run[0]);
    defer gpa.free(path);
    const envp = [_:null]?[*:0]const u8{null};

    const gate = try std.posix.pipe();
    const pid = try std.posix.fork();
    if (pid == 0) {
        // the child: any failure here must not return into init's loop
        std.posix.close(gate[1]);
        var latch: [1]u8 = undefined;
        _ = std.posix.read(gate[0], &latch) catch {}; // PID 1's word, or its death
        std.posix.close(gate[0]);
        // What the kernel will hold this world to, before it is a world
        // at all: the namespace it cannot leave and the filter it cannot
        // lift (NS-1). Both must happen BEFORE the exec, and the unshare
        // before the drop to a declared USER, which is the last moment
        // this child has the privilege to ask for a namespace.
        const applied = confine.apply(held);
        // NOT `held.confined() and ...`: since SYS-1 every world carries
        // the floor's own refusals, so a world that declared everything
        // still has an envelope, and a failure to build it is still a
        // promise the machine printed and did not keep. The narrower
        // guard let qemu_identity boot with the floor line on its
        // console and no filter behind it.
        if (applied.trouble != null) {
            // The machine said, in a line the court reads, that this
            // world would be held to what it declared. If the kernel
            // cannot do it, the promise is broken -- and a machine that
            // cannot keep a promise does not start the world and pretend.
            // The boot then differs from its expectation, which holds a
            // trial, which is the whole point of judging one's own boot.
            var msg: [320]u8 = undefined;
            const line = std.fmt.bufPrint(&msg, "boot: {s} -- NOT STARTED: the kernel cannot hold it to what it declared ({s}); the machine does not run a world whose envelope it could not build\n", .{ svc.name, applied.trouble.? }) catch "boot: a world could not be confined\n";
            _ = std.posix.write(1, line) catch {};
            std.posix.exit(125);
        }
        if (svc.user) |u| {
            std.posix.setgid(u.gid) catch std.posix.exit(126);
            std.posix.setuid(u.uid) catch std.posix.exit(126);
        }
        std.posix.execveZ(path, @ptrCast(argv.ptr), &envp) catch {};
        std.posix.exit(127); // the program was not there, or not runnable as this identity
    }
    std.posix.close(gate[0]);
    return .{ .pid = pid, .gate = gate[1] };
}

/// Let the world run: everything PID 1 owed it first -- its group, its
/// line in the transcript -- is done.
fn release(gate: std.posix.fd_t) void {
    _ = std.posix.write(gate, "\x00") catch {};
    std.posix.close(gate);
}

// ---- a world's own directory (OWN-1) ---------------------------------------
//
// A world that runs as a declared identity can write only where something was
// handed to it, and `STATE` says what: directories PID 1 makes and gives to
// that identity before the world exists. The machine's own directories stay the
// machine's, so the first server runs as itself and keeps its database and its
// signal in a place of its own instead of as root.

/// Close a directory the machine owns to everyone but its owner's group and others' writing: mode 0755.
/// Null when the kernel did it, else the kernel's word for why not. (The initial filesystem's root is a
/// tmpfs's, which is 1777; see `runLinux`.)
fn closeDir(path: []const u8) ?[]const u8 {
    const p = std.posix.toPosixPath(path) catch return "the path is too long";
    return switch (std.os.linux.E.init(std.os.linux.chmod(&p, 0o755))) {
        .SUCCESS => null,
        else => |e| @tagName(e),
    };
}

/// What the kernel answered, as an error this file names. The raw calls are used and not
/// the standard library's wrappers, which call EINVAL and EBADF `unreachable`: in the
/// ReleaseSafe build this binary ships in that is a PANIC in PID 1, where a refusal in a
/// line was owed. EINVAL is what a chown answers for an identity the caller's user
/// namespace has no number for -- which the repository's own rehearsal harness
/// (`unshare -Urpf`) is.
fn kernel(rc: usize) !void {
    return switch (std.os.linux.E.init(rc)) {
        .SUCCESS => {},
        .PERM, .ACCES => error.PermissionDenied,
        .INVAL => error.NoSuchIdentity,
        .ROFS => error.ReadOnlyFileSystem,
        .IO => error.InputOutput,
        .NOTDIR => error.NotADirectory,
        else => error.Unexpected,
    };
}

/// A directory ABOVE the one a world is to own must be the machine's: owned by whoever runs this
/// act (PID 1), and not writable by anyone else unless the sticky bit stops them taking what is
/// not theirs. The owner of a directory can replace what is in it, so a directory left on a disk
/// by an earlier boot's identity would let that identity swap the new world's directory for its
/// own. The ways down that this act made itself are root's; a mount's root is root's; a tmpfs's
/// is 1777, and the sticky bit is what makes that safe.
fn theMachinesOwn(fd: i32, me: u32) !void {
    var st: std.os.linux.Stat = undefined;
    try kernel(std.os.linux.fstat(fd, &st));
    // PID 1 is root, so this is root's. (Whoever runs the act is let in beside root so that a test
    // run by an ordinary user, whose own directories sit under other people's, can ask the question.)
    if (st.uid != me and st.uid != 0) return error.AncestorNotTheMachines;
    const open_to_others = st.mode & 0o022 != 0;
    const sticky = st.mode & 0o1000 != 0;
    if (open_to_others and !sticky) return error.AncestorNotTheMachines;
}

/// Give the directory the descriptor holds to `u`, close it to everyone else, and READ IT BACK:
/// the owner and the mode as the kernel says them, not as this function asked for them.
fn handOver(fd: i32, u: *const machine.User) !void {
    try kernel(std.os.linux.fchown(fd, u.uid, u.gid));
    try kernel(std.os.linux.fchmod(fd, 0o700));
    var st: std.os.linux.Stat = undefined;
    try kernel(std.os.linux.fstat(fd, &st));
    if (!std.os.linux.S.ISDIR(st.mode)) return error.NotADirectory;
    if (st.uid != u.uid or st.gid != u.gid) return error.NotOwnedAsDeclared;
    if (st.mode & 0o7777 != 0o700) return error.ModeNotKept;
}

/// Make `dir` -- and every directory above it that is missing, as root's -- give it to `u`, close
/// it to every other identity, and read it back. Returns an error for anything that is not exactly
/// what was declared.
///
/// Walked from the root with no symlink followed. A directory on a disk that outlives the boot can
/// hold whatever a world, or anyone who held the disk, once put there, and an owner given to
/// whatever a link points at would be an owner given to somebody else's directory. `O_NOFOLLOW` on
/// every step makes a link anywhere on the way a refusal and not a destination, and every
/// directory above the last must be the machine's (`theMachinesOwn`).
fn ownDir(dir: []const u8, u: *const machine.User, unmounted: []const []const u8) !void {
    // a mount the kernel refused left its mount point behind, in RAM: a directory made
    // there would hold what a world writes until the power goes, and say nothing. (Any refused
    // mount the directory lies inside refuses it: a wider question than the court's innermost
    // holder, so it can refuse more than the court passed and never less.)
    for (unmounted) |at| if (machine.within(dir, at)) return error.MountRefused;
    // whoever runs this act: the machine's identity, and the only owner the ways down may have
    const me = std.os.linux.getuid();
    // `iterate`: a directory opened without it is a path-only descriptor on Linux, and the kernel
    // answers EBADF to a chown or a chmod on one
    var cur = try std.fs.openDirAbsolute("/", .{ .no_follow = true, .iterate = true });
    var parts = std.mem.tokenizeScalar(u8, dir, '/');
    while (parts.next()) |name| {
        cur.makeDir(name) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => {
                cur.close();
                return e;
            },
        };
        const next = cur.openDir(name, .{ .no_follow = true, .iterate = true }) catch |e| {
            cur.close();
            return e;
        };
        cur.close();
        cur = next;
        if (parts.peek() != null) theMachinesOwn(cur.fd, me) catch |e| {
            cur.close();
            return e;
        };
    }
    defer cur.close();
    try handOver(cur.fd, u);
}

/// What a person reads when a directory was not handed over: the kernel's reason where
/// it gave one, and in words where the reason is this function's own.
fn stateReason(e: anyerror) []const u8 {
    return switch (e) {
        error.MountRefused => "the mount it lies on was refused by the kernel",
        error.NotADirectory => "what is there is not a directory",
        error.NotOwnedAsDeclared => "the kernel reads it back as somebody else's",
        error.ModeNotKept => "the kernel reads it back with another mode than 0700",
        error.AncestorNotTheMachines => "a directory above it is not the machine's, and its owner could replace it",
        error.NoSuchIdentity => "the kernel has no such identity here (a user namespace that maps none)",
        error.PermissionDenied => "the kernel refused (permission denied)",
        error.ReadOnlyFileSystem => "the filesystem is read-only",
        else => @errorName(e),
    };
}

/// What PID 1 owes the worlds that declared STATE, before any of them starts. The
/// line the boot says (`expect.stateLine`) is said only if every directory was made
/// and read back as declared. One that was not is said on the console alone, with the
/// kernel's reason; the world that was to own it does not start (NS-1: a promise the
/// machine cannot keep is refused, never announced), and the boot lacks the line its
/// expectation has. Such a world is never READY, so the boot is never judged and a
/// trial is never committed (RDY-1's safe outcome, which is no timer's): the console
/// says why, and no verdict does.
fn prepareState(m: *const machine.Machine, slots: []Slot, unmounted: []const []const u8, rehearse: bool, led: *Ledger, out: *std.Io.Writer) !void {
    var any = false;
    var ok = true;
    for (slots) |*s| {
        const svc = s.service;
        if (svc.state.len == 0) continue;
        any = true;
        if (rehearse) continue;
        const u = svc.user orelse continue; // the court refuses a STATE with no USER
        for (svc.state) |dir| {
            ownDir(dir, u, unmounted) catch |e| {
                ok = false;
                s.state = .never;
                try out.print("boot: state -- {s} was not given {s}: {s}; a world that owns a directory it was not given does not start\n", .{ svc.name, dir, stateReason(e) });
                break;
            };
        }
    }
    if (!any) return;
    if (rehearse) {
        try out.print("boot: state -- rehearsed, not executed\n", .{});
    } else if (ok) {
        _ = try expect.stateLine(led.w(), m);
        try led.echo();
    }
    try out.flush();
}

/// A signal is THIS boot's word that a world serves, so what an earlier boot left at a READY path
/// is taken away before any world starts: on a disk it would read as ready before the world has run,
/// and a trial could commit on it. A world whose directory was not handed over (`.never`) is not
/// started, and nothing is removed for it. One whose stale signal cannot be cleared is not started
/// either, and the console says why.
fn clearSignals(slots: []Slot, rehearse: bool, out: *std.Io.Writer) !void {
    if (rehearse) return;
    for (slots) |*s| {
        if (s.state != .pending) continue;
        const path = s.service.ready orelse continue;
        removeStaleSignal(path) catch |e| {
            s.state = .never;
            try out.print("boot: {s} -- a signal left at {s} by an earlier boot could not be cleared: {s}; it would read as ready before the world has run, so the world does not start\n", .{ s.service.name, path, stateReason(e) });
        };
    }
    try out.flush();
}

test "a directory the machine owns is closed to everyone's writing, as the initial root must be (OWN-2)" {
    // Linux only: the kernel is the one being asked what mode the directory has afterwards
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const gpa = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realpathAlloc(gpa, ".");
    defer gpa.free(base);
    var d = try tmp.dir.openDir(".", .{ .iterate = true });
    defer d.close();
    // open to everyone, as a tmpfs's root is until it is closed
    try d.chmod(0o1777);
    try std.testing.expect((try d.stat()).mode & 0o7777 == 0o1777);
    try std.testing.expect(closeDir(base) == null);
    try std.testing.expectEqual(@as(u32, 0o755), (try d.stat()).mode & 0o7777);
    // and a directory that is not there is the kernel's refusal, said in its word
    const gone = try std.fmt.allocPrint(gpa, "{s}/nowhere", .{base});
    defer gpa.free(gone);
    try std.testing.expectEqualStrings("NOENT", closeDir(gone).?);
}

test "a signal an earlier boot left is cleared, a link is not followed, and only a regular file is a signal (OWN-1)" {
    // The questions that decide, asked of a kernel: what does PID 1 read at a READY path, and what is
    // left there after it clears one? Linux only, like the directory test, and run by the same probe.
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const gpa = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realpathAlloc(gpa, ".");
    defer gpa.free(base);
    const ready = try std.fmt.allocPrint(gpa, "{s}/ready", .{base});
    defer gpa.free(ready);

    // nothing there is not a signal, and clearing nothing is not an error
    try std.testing.expect(signalStat(ready) == null);
    try removeStaleSignal(ready);

    // a regular file is a signal, and clearing takes it away
    try tmp.dir.writeFile(.{ .sub_path = "ready", .data = "serving\n" });
    try std.testing.expect(signalStat(ready) != null);
    try std.testing.expect(mtimeMs(ready) != null);
    try removeStaleSignal(ready);
    try std.testing.expect(signalStat(ready) == null);

    // a link is no signal, whatever it points at: it would be "ready" on somebody else's word. Clearing
    // removes the link and leaves what it points at
    try tmp.dir.writeFile(.{ .sub_path = "neighbour", .data = "serving\n" });
    const neighbour = try std.fmt.allocPrint(gpa, "{s}/neighbour", .{base});
    defer gpa.free(neighbour);
    try tmp.dir.symLink(neighbour, "ready", .{});
    try std.testing.expect(signalStat(neighbour) != null);
    try std.testing.expect(signalStat(ready) == null);
    try std.testing.expect(mtimeMs(ready) == null);
    try removeStaleSignal(ready);
    try std.testing.expect(signalStat(neighbour) != null);

    // a directory is no signal either, and it is not removed (a world cannot say it serves by making one)
    try tmp.dir.makeDir("ready");
    try std.testing.expect(signalStat(ready) == null);
    try std.testing.expectError(error.IsADirectory, removeStaleSignal(ready));
}

test "a world's own directory is made, handed over and read back, and no link is followed (OWN-1)" {
    // The question that decides (MNT-1), where there is a kernel to ask: what does the kernel say
    // the directory IS, once it was made? Linux only; `zig build test` on another host skips it, and
    // experiment/state_probe.sh runs it on Linux against mutants.
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const gpa = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realpathAlloc(gpa, ".");
    defer gpa.free(base);
    // The identity the directory is handed to. As root (the Linux probe runs as root) it is a DIFFERENT
    // one, 2000, so that a hand-over which did not chown is convicted by the kernel's readback. As anyone
    // else it is the test's own: giving a directory to the identity that already owns it asks for no
    // privilege, and the readback is the kernel's all the same; the different owner is then the boot's
    // to show, in its transcript and on the disk it leaves behind.
    const root = std.os.linux.getuid() == 0;
    const me = machine.User{
        .name = "me",
        .line = 1,
        .uid = if (root) 2000 else std.os.linux.getuid(),
        .gid = if (root) 2000 else std.os.linux.getgid(),
        .rationale = "x",
    };

    // made, with the directories above it that were missing
    const dir = try std.fmt.allocPrint(gpa, "{s}/a/b/state", .{base});
    defer gpa.free(dir);
    try ownDir(dir, &me, &.{});
    var d = try std.fs.openDirAbsolute(dir, .{ .iterate = true });
    defer d.close();
    // loosened, as a world that owns it could, then handed over again: closed again, and it is the SAME
    // directory, so what a world kept in it before the reboot is kept
    try d.writeFile(.{ .sub_path = "kept", .data = "x" });
    try d.chmod(0o777);
    try ownDir(dir, &me, &.{});
    const st = try std.posix.fstat(d.fd);
    try std.testing.expectEqual(@as(u32, 0o700), st.mode & 0o7777);
    try std.testing.expectEqual(me.uid, st.uid);
    _ = try d.statFile("kept");

    // A link anywhere on the way is a refusal, not a destination: nothing is made, and nothing is
    // given, behind it. This is the half a declaration cannot show (NAME-1: a guard that reads the
    // declaration does not judge the act).
    var other = std.testing.tmpDir(.{});
    defer other.cleanup();
    const elsewhere = try other.dir.realpathAlloc(gpa, ".");
    defer gpa.free(elsewhere);
    try tmp.dir.symLink(elsewhere, "link", .{ .is_directory = true });
    const through = try std.fmt.allocPrint(gpa, "{s}/link/x", .{base});
    defer gpa.free(through);
    try std.testing.expect(std.meta.isError(ownDir(through, &me, &.{})));
    try std.testing.expectError(error.FileNotFound, other.dir.openDir("x", .{}));
    // ... also as the last name, where the directory itself should be
    const last = try std.fmt.allocPrint(gpa, "{s}/link", .{base});
    defer gpa.free(last);
    try std.testing.expect(std.meta.isError(ownDir(last, &me, &.{})));
    // ... and a file where a directory should be
    try tmp.dir.writeFile(.{ .sub_path = "plain", .data = "x" });
    const file = try std.fmt.allocPrint(gpa, "{s}/plain", .{base});
    defer gpa.free(file);
    try std.testing.expect(std.meta.isError(ownDir(file, &me, &.{})));
    // ... and a directory on a mount the kernel refused: that is the mount point, in RAM. (Under the
    // test's own directory, so a defect that lets it through makes a directory nobody has to clean up.)
    const mnt = try std.fmt.allocPrint(gpa, "{s}/mnt", .{base});
    defer gpa.free(mnt);
    const on_mnt = try std.fmt.allocPrint(gpa, "{s}/mnt/x", .{base});
    defer gpa.free(on_mnt);
    try std.testing.expectError(error.MountRefused, ownDir(on_mnt, &me, &.{mnt}));
    try std.testing.expectError(error.FileNotFound, tmp.dir.openDir("mnt", .{}));
    // a mount point that only SHARES a prefix with the directory is not that mount
    const near = try std.fmt.allocPrint(gpa, "{s}/mntx", .{base});
    defer gpa.free(near);
    try ownDir(near, &me, &.{mnt});

    // Every directory ABOVE the last must be the machine's: one that others can write into, without
    // the sticky bit that stops them taking what is not theirs, lets them replace the world's directory
    try tmp.dir.makeDir("open");
    var od = try tmp.dir.openDir("open", .{ .iterate = true });
    defer od.close();
    try od.chmod(0o777);
    const under_open = try std.fmt.allocPrint(gpa, "{s}/open/x", .{base});
    defer gpa.free(under_open);
    try std.testing.expectError(error.AncestorNotTheMachines, ownDir(under_open, &me, &.{}));
    try std.testing.expectError(error.FileNotFound, od.openDir("x", .{})); // and nothing was made under it
    // ... and with the sticky bit it is the safe shape a tmpfs mount's root has
    try od.chmod(0o1777);
    try ownDir(under_open, &me, &.{});
    // ... and one left by another identity -- here the one this world would be, standing for an earlier
    // boot's -- is not the machine's: its owner could swap what is below it. Only root can make one
    if (root) {
        try tmp.dir.makeDir("theirs");
        var td = try tmp.dir.openDir("theirs", .{ .iterate = true });
        defer td.close();
        try td.chown(2000, 2000);
        try td.chmod(0o755);
        const under_theirs = try std.fmt.allocPrint(gpa, "{s}/theirs/x", .{base});
        defer gpa.free(under_theirs);
        try std.testing.expectError(error.AncestorNotTheMachines, ownDir(under_theirs, &me, &.{}));
    }
}
