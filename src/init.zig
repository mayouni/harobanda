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

pub const Options = struct {
    rehearse: bool = false,
    turns: ?usize = null,
    max_restarts: usize = 5,
    /// the rollback instrument: on a trial boot, never commit and stop
    /// feeding the watchdog, so the hardware's answer is what follows
    hold: bool = false,
};

// ---- A/B slots ------------------------------------------------------------
//
// The card's boot partition holds config.txt and two slots. config.txt
// names the committed slot in its os_prefix and, under [tryboot], the
// other; the firmware applies the [tryboot] section only on a boot asked
// for with the tryboot flag, once. PID 1 learns which slot it booted from
// the cmdline (stzos.slot=), reads which one is committed, arms the
// hardware watchdog, and -- on a trial -- commits by rewriting config.txt
// only when every service has started. A trial that never gets there is
// not committed: the watchdog resets the board and the firmware boots the
// committed slot. Nothing here decides what "healthy" means beyond "every
// declared service started"; a health seat is a named seam.

const Slots = struct {
    dev: []const u8,
    booted: ?u8 = null, // 'A' or 'B'
    committed: ?u8 = null,
    mounted: bool = false,
    wd_fd: ?i32 = null,
    done: bool = false, // committed, or steady from the start
};

fn bootedSlot(gpa: std.mem.Allocator) ?u8 {
    const cmdline = std.fs.cwd().readFileAlloc(gpa, "/proc/cmdline", 4096) catch return null;
    defer gpa.free(cmdline);
    const i = std.mem.indexOf(u8, cmdline, "stzos.slot=") orelse return null;
    const c = cmdline[i + "stzos.slot=".len ..];
    if (c.len == 0) return null;
    return if (c[0] == 'A' or c[0] == 'B') c[0] else null;
}

/// `stzos.watchdog=off` on the cmdline: the emulator court's lens. QEMU's
/// raspi4b resets the board the moment the watchdog is ARMED (its
/// power-management model has no countdown and reads the driver's
/// "full reset on expiry" as "reset now"), so the emulator's boot line
/// says so and PID 1 states that a trial cannot roll back by hardware
/// there. The card's cmdline.txt never carries it.
fn watchdogOff(gpa: std.mem.Allocator) bool {
    const cmdline = std.fs.cwd().readFileAlloc(gpa, "/proc/cmdline", 4096) catch return false;
    defer gpa.free(cmdline);
    return std.mem.indexOf(u8, cmdline, "stzos.watchdog=off") != null;
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

fn feedWatchdog(s: *Slots) void {
    if (s.wd_fd) |fd| _ = std.os.linux.write(fd, "\x00", 1);
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
    state: State = .pending,
    pid: i32 = 0,
    code: u32 = 0,
    signaled: bool = false, // killed by a signal (the kernel's word)
    signalled_ready: bool = false, // its READY path has been seen (its own word)
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
};

pub fn run(gpa: std.mem.Allocator, p: plan.Plan, opts: Options, out: *std.Io.Writer) !u8 {
    if (!is_linux) {
        try out.print("boot: init is a Linux act; this binary was built for {s} -- use `stzos plan` here, or `zig build cross`\n", .{@tagName(builtin.os.tag)});
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

    try out.print("boot: stzos init -- machine {s} ({s} / {s} / {s}) -- pid {d}{s}\n", .{ m.name, @tagName(m.profile), @tagName(m.arch), @tagName(m.board), pid, if (is_pid1) "" else " (not PID 1)" });
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

    var slots: std.ArrayList(Slot) = .{};
    defer slots.deinit(gpa);
    for (p.steps) |step| if (step == .service) try slots.append(gpa, .{ .service = step.service });

    var ab: ?Slots = if (m.slots) |dev| Slots{ .dev = dev } else null;
    if (opts.hold and ab != null) try out.print("boot: --hold: a trial will not be committed and the watchdog will not be fed -- the rollback instrument\n", .{});

    for (p.steps) |step| switch (step) {
        .console => |c| try out.print("boot: console {s}\n", .{c}),
        .slots => |dev| {
            if (opts.rehearse) {
                try out.print("boot: slots on {s} -- rehearsed, not read\n", .{dev});
                continue;
            }
            // proc is not mounted yet at this step: the cmdline is read after the mounts
            try out.print("boot: slots on {s} -- A and B\n", .{dev});
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
                .SUCCESS => try out.print("boot: mount {s} at {s} -- done\n", .{ @tagName(mt.fs), mt.at }),
                .BUSY => try out.print("boot: mount {s} at {s} -- already mounted (EBUSY), kept\n", .{ @tagName(mt.fs), mt.at }),
                else => |e| try out.print("boot: mount {s} at {s} -- refused by the kernel: {s}\n", .{ @tagName(mt.fs), mt.at, @tagName(e) }),
            }
        },
        .capability => |c| try out.print("boot: {s} {s} ({s})\n", .{ if (c.granted) "grant" else "refuse", @tagName(c.name), @tagName(machine.kindOf(c.name)) }),
        .pin => |pn| try out.print("boot: pin {s} gpio {d} {s} -- declared; the hosted profile drives pins through the gpio capability of its services\n", .{ pn.name, pn.gpio, @tagName(pn.mode) }),
        .network => |n| {
            if (opts.rehearse) {
                try out.print("boot: network {s} -- {s} {s} -- rehearsed, not executed\n", .{ n.name, n.interface, if (n.address == .dhcp) "dhcp" else "static" });
                continue;
            }
            try out.flush();
            _ = try netcfg.bringUp(n, out, "boot: ");
        },
        .service => {}, // started below, when what it comes AFTER is ready
    };
    // the slots, once proc and dev exist: which one booted, which is committed, the watchdog
    if (ab) |*s| if (!opts.rehearse) {
        s.booted = bootedSlot(gpa);
        if (s.booted == null) {
            try out.print("boot: slot -- no stzos.slot on the cmdline: a single boot, nothing to commit\n", .{});
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
                        try out.print("boot: slot {c} -- a trial (committed is {c}); the watchdog holds the rollback until every service has started\n", .{ s.booted.?, c });
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
            try out.print("boot: watchdog -- off by the boot line (the emulator resets on arming); a trial cannot roll back by hardware here\n", .{});
        } else {
            const wd = linux.open("/dev/watchdog", .{ .ACCMODE = .WRONLY }, 0);
            switch (linux.E.init(wd)) {
                .SUCCESS => {
                    s.wd_fd = @intCast(wd);
                    try out.print("boot: watchdog armed (/dev/watchdog)\n", .{});
                },
                else => |e| try out.print("boot: watchdog -- /dev/watchdog refused: {s}; a trial cannot roll back by hardware\n", .{@tagName(e)}),
            }
        }
        try out.flush();
    };

    try startReady(gpa, slots.items, out);
    try out.flush();

    // the reaper: PID 1's standing duty -- polled, so the watchdog is fed
    // between exits and a trial is committed the moment it is earned
    var turns: usize = 0;
    while (true) {
        if (ab) |*s| {
            if (!opts.hold) feedWatchdog(s);
            if (!s.done and !opts.hold) {
                // the commit is earned when every service is READY -- a
                // one-shot exited 0, a daemon spawned -- never merely started:
                // a one-shot that fails, or a service its failure held back,
                // keeps the trial uncommitted, and the rollback is the answer.
                // (Committing on "started" also raced the last one-shot's
                // output with the commit line in the transcript.)
                var all_ready = true;
                for (slots.items) |sl| if (!sl.ready()) {
                    all_ready = false;
                };
                if (all_ready) {
                    if (std.fs.cwd().readFileAlloc(gpa, "/boot/config.txt", 1 << 16)) |cfg| {
                        defer gpa.free(cfg);
                        if (commitText(gpa, cfg, s.committed.?, s.booted.?)) |new_cfg| {
                            defer gpa.free(new_cfg);
                            if (std.fs.cwd().createFile("/boot/config.txt", .{ .truncate = true })) |f| {
                                defer f.close();
                                f.writeAll(new_cfg) catch {};
                                f.sync() catch {};
                                linux.sync();
                                try out.print("boot: slot {c} -- committed: every service is ready; config.txt now boots {c}, {c} is the fallback\n", .{ s.booted.?, s.booted.?, s.committed.? });
                            } else |e| try out.print("boot: slot {c} -- commit refused: config.txt: {s}\n", .{ s.booted.?, @errorName(e) });
                        } else |e| try out.print("boot: slot {c} -- commit refused: {s}\n", .{ s.booted.?, @errorName(e) });
                    } else |e| try out.print("boot: slot {c} -- commit refused: config.txt unreadable: {s}\n", .{ s.booted.?, @errorName(e) });
                    s.done = true;
                    try out.flush();
                }
            }
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
                    try out.print("boot: {s} never started -- {s}\n", .{ s.service.name, why });
                };
            }
            try out.print("boot: every service has ended -- init has nothing left to keep alive\n", .{});
            break;
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
        const awaiting = try pollReady(slots.items, out);
        if (awaiting) try startReady(gpa, slots.items, out);
        const polling = ab != null or awaiting;
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
            if (exited) {
                try out.print("boot: {s} (pid {d}) exited {d}\n", .{ c.service.name, ended, c.code });
            } else if (linux.W.IFSIGNALED(status)) {
                try out.print("boot: {s} (pid {d}) killed by signal {d}\n", .{ c.service.name, ended, linux.W.TERMSIG(status) });
            } else {
                try out.print("boot: {s} (pid {d}) ended (status {d})\n", .{ c.service.name, ended, status });
            }
            const wants_restart = switch (c.service.restart) {
                .never => false,
                .always => true,
                .on_failure => !(exited and c.code == 0),
            };
            if (wants_restart) {
                if (c.restarts >= opts.max_restarts) {
                    try out.print("boot: {s} -- restart {s}, but gave up after {d} restarts\n", .{ c.service.name, @tagName(c.service.restart), c.restarts });
                } else {
                    c.restarts += 1;
                    const np = spawn(gpa, c.service) catch |e| {
                        try out.print("boot: restart {s} -- could not spawn: {s}\n", .{ c.service.name, @errorName(e) });
                        break;
                    };
                    c.pid = np;
                    c.state = .running;
                    try out.print("boot: restart {s} ({s}, {d}/{d}) -- pid {d}\n", .{ c.service.name, @tagName(c.service.restart), c.restarts, opts.max_restarts, np });
                }
            }
            break;
        }
        if (!known) try out.print("boot: reaped orphan pid {d}\n", .{ended});
        // a one-shot that failed blocks what waited on it; a service whose
        // AFTER just became ready starts now
        for (slots.items) |*s| {
            if (s.state != .pending) continue;
            for (s.service.after) |a| {
                for (slots.items) |d| if (std.mem.eql(u8, d.service.name, a) and d.failed()) {
                    s.state = .never;
                    try out.print("boot: {s} never started -- it comes AFTER {s}, which exited {d}\n", .{ s.service.name, a, d.code });
                };
            }
        }
        try startReady(gpa, slots.items, out);
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

/// Look for the declared signals that have appeared since the last look.
/// Returns true if any service is still awaiting one.
fn pollReady(slots: []Slot, out: *std.Io.Writer) !bool {
    var awaiting = false;
    for (slots) |*s| {
        if (!s.awaiting()) continue;
        const path = s.service.ready.?;
        if (std.fs.cwd().access(path, .{})) |_| {
            s.signalled_ready = true;
            try out.print("boot: {s} -- ready ({s})\n", .{ s.service.name, path });
        } else |_| {
            awaiting = true;
        }
    }
    return awaiting;
}

/// Start every pending service whose AFTER services are all ready, in
/// plan order, until nothing more can start.
fn startReady(gpa: std.mem.Allocator, slots: []Slot, out: *std.Io.Writer) !void {
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
            const pid = spawn(gpa, s.service) catch |e| {
                s.state = .never;
                try out.print("boot: start {s} -- could not spawn: {s}\n", .{ s.service.name, @errorName(e) });
                progressed = true;
                continue;
            };
            s.pid = pid;
            s.state = .running;
            progressed = true;
            try out.print("boot: start {s} -- pid {d} --", .{ s.service.name, pid });
            for (s.service.run) |w| try out.print(" {s}", .{w});
            if (s.service.user) |u| try out.print(" -- as {s} ({d}:{d})", .{ u.name, u.uid, u.gid });
            try out.print("\n", .{});
        }
    }
}

fn spawn(gpa: std.mem.Allocator, svc: *const machine.Service) !i32 {
    const u = svc.user orelse {
        var child = std.process.Child.init(svc.run, gpa);
        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
        try child.spawn();
        return @intCast(child.id);
    };
    // a declared identity: fork by hand, drop the credentials in the child,
    // then exec. std.process.Child has no seat for a uid, and the drop must
    // happen between fork and exec -- the one moment where the child is
    // still ours and not yet the program's. Group first, then user: after
    // setuid there is no privilege left to change the group with.
    var argv = try gpa.alloc(?[*:0]const u8, svc.run.len + 1);
    defer gpa.free(argv);
    for (svc.run, 0..) |a, i| argv[i] = (try gpa.dupeZ(u8, a)).ptr;
    argv[svc.run.len] = null;
    const path = try gpa.dupeZ(u8, svc.run[0]);
    defer gpa.free(path);
    const envp = [_:null]?[*:0]const u8{null};

    const pid = try std.posix.fork();
    if (pid == 0) {
        // the child: any failure here must not return into init's loop
        std.posix.setgid(u.gid) catch std.posix.exit(126);
        std.posix.setuid(u.uid) catch std.posix.exit(126);
        std.posix.execveZ(path, @ptrCast(argv.ptr), &envp) catch {};
        std.posix.exit(127); // the program was not there, or not runnable as this identity
    }
    return pid;
}
