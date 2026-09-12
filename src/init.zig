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

pub const Options = struct {
    rehearse: bool = false,
    turns: ?usize = null,
    max_restarts: usize = 5,
};

const is_linux = builtin.os.tag == .linux;

// One slot per service, in plan order. AFTER waits for READINESS, and
// readiness depends on the kind of service the RESTART policy implies:
//   RESTART never       a one-shot -- ready when it has EXITED 0; if it
//                       exits otherwise, what waited on it never starts
//   always / on_failure a daemon  -- ready as soon as it has been SPAWNED
// (systemd's oneshot/simple distinction without a Type= seat; the OS-2
// transcripts interleaved because AFTER only ordered spawns, PROTOCOL.md).
const State = enum { pending, running, exited, never };

const Slot = struct {
    service: *const machine.Service,
    state: State = .pending,
    pid: i32 = 0,
    code: u32 = 0,
    signaled: bool = false,
    restarts: usize = 0,

    fn ready(self: Slot) bool {
        return switch (self.service.restart) {
            .never => self.state == .exited and !self.signaled and self.code == 0,
            .always, .on_failure => self.state == .running or self.state == .exited,
        };
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

    for (p.steps) |step| switch (step) {
        .console => |c| try out.print("boot: console {s}\n", .{c}),
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
        .service => {}, // started below, when what it comes AFTER is ready
    };
    try startReady(gpa, slots.items, out);
    try out.flush();

    // the reaper: PID 1's standing duty
    var turns: usize = 0;
    while (true) {
        var alive: usize = 0;
        var pending: usize = 0;
        for (slots.items) |s| switch (s.state) {
            .running => alive += 1,
            .pending => pending += 1,
            else => {},
        };
        if (alive == 0) {
            if (pending > 0) {
                // nothing runs and something still waits: name it, it will never start
                for (slots.items) |*s| if (s.state == .pending) {
                    s.state = .never;
                    try out.print("boot: {s} never started -- what it comes AFTER did not become ready\n", .{s.service.name});
                };
            }
            try out.print("boot: every service has ended -- init has nothing left to keep alive\n", .{});
            break;
        }
        if (opts.turns) |t| if (turns >= t) {
            try out.print("boot: --turns {d} reached with {d} service(s) still running -- the instrument ends what a real init never would\n", .{ turns, alive });
            break;
        };
        var status: u32 = 0;
        const rc = linux.wait4(-1, &status, 0, null);
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
            try out.print("\n", .{});
        }
    }
}

fn spawn(gpa: std.mem.Allocator, svc: *const machine.Service) !i32 {
    var child = std.process.Child.init(svc.run, gpa);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    return @intCast(child.id);
}
