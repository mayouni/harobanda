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

const Child = struct {
    service: *const machine.Service,
    pid: i32,
    restarts: usize = 0,
    alive: bool = true,
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

    try out.print("boot: stzos init -- machine {s} ({s} / {s}) -- pid {d}{s}\n", .{ m.name, @tagName(m.profile), @tagName(m.arch), pid, if (is_pid1) "" else " (not PID 1)" });
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

    var children: std.ArrayList(Child) = .{};
    defer children.deinit(gpa);

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
        .service => |svc| {
            const child_pid = spawn(gpa, svc) catch |e| {
                try out.print("boot: start {s} -- could not spawn: {s}\n", .{ svc.name, @errorName(e) });
                continue;
            };
            try children.append(gpa, .{ .service = svc, .pid = child_pid });
            try out.print("boot: start {s} -- pid {d} --", .{ svc.name, child_pid });
            for (svc.run) |w| try out.print(" {s}", .{w});
            try out.print("\n", .{});
        },
    };
    try out.flush();

    // the reaper: PID 1's standing duty
    var turns: usize = 0;
    while (true) {
        var alive: usize = 0;
        for (children.items) |c| if (c.alive) {
            alive += 1;
        };
        if (alive == 0) {
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
        for (children.items) |*c| {
            if (c.pid != ended or !c.alive) continue;
            known = true;
            c.alive = false;
            const exited = linux.W.IFEXITED(status);
            const code: u32 = if (exited) linux.W.EXITSTATUS(status) else 0;
            if (exited) {
                try out.print("boot: {s} (pid {d}) exited {d}\n", .{ c.service.name, ended, code });
            } else if (linux.W.IFSIGNALED(status)) {
                try out.print("boot: {s} (pid {d}) killed by signal {d}\n", .{ c.service.name, ended, linux.W.TERMSIG(status) });
            } else {
                try out.print("boot: {s} (pid {d}) ended (status {d})\n", .{ c.service.name, ended, status });
            }
            const wants_restart = switch (c.service.restart) {
                .never => false,
                .always => true,
                .on_failure => !(exited and code == 0),
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
                    c.alive = true;
                    try out.print("boot: restart {s} ({s}, {d}/{d}) -- pid {d}\n", .{ c.service.name, @tagName(c.service.restart), c.restarts, opts.max_restarts, np });
                }
            }
            break;
        }
        if (!known) try out.print("boot: reaped orphan pid {d}\n", .{ended});
        try out.flush();
    }
    if (is_pid1 and !opts.rehearse) {
        // PID 1 may not exit (the kernel panics); it restarts the machine.
        // Under QEMU -no-reboot this is how a boot ends and the transcript
        // closes. Inside a user namespace the kernel refuses it (PERM) and
        // the transcript says so.
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

fn spawn(gpa: std.mem.Allocator, svc: *const machine.Service) !i32 {
    var child = std.process.Child.init(svc.run, gpa);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    return @intCast(child.id);
}
