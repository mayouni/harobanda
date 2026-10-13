//! The reservation a world runs under (TIM-1): what PID 1 hands the kernel before the exec, and what
//! a world reads back from inside.
//!
//! A reservation is `SCHED_DEADLINE`: every `period`, `runtime` of it, done within `deadline` of the
//! period's start. The kernel holds it by its own admission -- a set that does not fit beside what is
//! already reserved on that core is refused (`EBUSY`), and one whose numbers contradict each other is
//! refused by the kernel's arithmetic (`EINVAL`) -- so a reservation is a promise the KERNEL keeps,
//! as a ceiling is since BDG-1. It is taken in PID 1's child, after the gate and BEFORE the filter,
//! because since PRI-1 `sched_setattr` is refused to every world: the world never sets its own place
//! in the queue, it is given one. `RESET_ON_FORK` makes everything the world spawns a normal task,
//! which is also the only way a deadline task may spawn at all: the reservation is the world's MAIN
//! THREAD's, and a control loop lives there.
//!
//! `harb reserved` is the witness: a world asks the kernel what it runs under and says it, as `own`
//! asks what it may write. A report and not an assertion, because a world with no reservation is a
//! true state too.

const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;
const machine = @import("machine.zig");

pub const SCHED_DEADLINE: u32 = 6;
pub const SCHED_FLAG_RESET_ON_FORK: u64 = 0x01;

/// The attribute the kernel is handed: the declaration's microseconds, as nanoseconds.
pub fn attrOf(r: machine.Reservation) linux.sched_attr {
    return .{
        .policy = SCHED_DEADLINE,
        .flags = SCHED_FLAG_RESET_ON_FORK,
        .runtime = r.runtime_us * 1000,
        .deadline = r.deadline_us * 1000,
        .period = r.period_us * 1000,
    };
}

pub const TakeError = error{
    /// the kernel's own arithmetic refused the numbers (runtime, deadline, period)
    Invalid,
    /// it does not fit beside what is already reserved where this task may run
    DoesNotFit,
    /// the caller may not reserve (it is not PID 1's child, or a filter is already up)
    NoPrivilege,
    NotLinux,
    Other,
};

/// Take the reservation for the CALLING task.
pub fn take(r: machine.Reservation) TakeError!void {
    if (builtin.os.tag != .linux) return error.NotLinux;
    const attr = attrOf(r);
    switch (linux.E.init(linux.sched_setattr(0, &attr, 0))) {
        .SUCCESS => {},
        .INVAL => return error.Invalid,
        .BUSY => return error.DoesNotFit,
        .PERM => return error.NoPrivilege,
        else => return error.Other,
    }
}

/// What the kernel says the calling task runs under.
pub const Reading = struct {
    policy: u32,
    runtime_ns: u64,
    deadline_ns: u64,
    period_ns: u64,
    reset_on_fork: bool,
    /// the lowest core this task may run on, and how many it may run on
    core: u32,
    cores: u32,
};

pub fn readBack() !Reading {
    if (builtin.os.tag != .linux) return error.NotLinux;
    var attr: linux.sched_attr = .{};
    switch (linux.E.init(linux.sched_getattr(0, &attr, @sizeOf(linux.sched_attr), 0))) {
        .SUCCESS => {},
        else => return error.KernelWouldNotSay,
    }
    // the cores: one bit per cpu, 1024 of them
    var set: [16]u64 = [_]u64{0} ** 16;
    const rc = linux.syscall3(.sched_getaffinity, 0, @sizeOf(@TypeOf(set)), @intFromPtr(&set));
    if (linux.E.init(rc) != .SUCCESS) return error.KernelWouldNotSay;
    var lowest: ?u32 = null;
    var count: u32 = 0;
    for (set, 0..) |word, wi| {
        var w = word;
        var bit: u32 = 0;
        while (w != 0) : (w >>= 1) {
            if (w & 1 == 1) {
                count += 1;
                if (lowest == null) lowest = @as(u32, @intCast(wi)) * 64 + bit;
            }
            bit += 1;
        }
    }
    return .{
        .policy = attr.policy,
        .runtime_ns = attr.runtime,
        .deadline_ns = attr.deadline,
        .period_ns = attr.period,
        .reset_on_fork = (attr.flags & SCHED_FLAG_RESET_ON_FORK) != 0,
        .core = lowest orelse 0,
        .cores = count,
    };
}

/// The witness's verb: say what this world runs under. Exit 0 either way: a report, never an assertion.
/// With `--stay <ready-path>` it then marks the path and stays, so that another world's reservation is
/// asked for BESIDE one the kernel already holds, after this one's word (the path is its last act, SRV-1).
pub fn run(args: []const []const u8, out: *std.Io.Writer) !u8 {
    var stay: ?[]const u8 = null;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--stay") and i + 1 < args.len) {
            i += 1;
            stay = args[i];
        } else {
            try out.print("reserved: takes nothing, or --stay <ready-path>; not '{s}'\n", .{args[i]});
            return 2;
        }
    }
    if (builtin.os.tag != .linux) {
        try out.print("reserved: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
        return 2;
    }
    const r = readBack() catch |e| {
        try out.print("reserved: the kernel would not say ({s})\n", .{@errorName(e)});
        return 1;
    };
    if (r.policy == SCHED_DEADLINE) {
        try out.print("reserved: SCHED_DEADLINE -- {d} us of every {d} us, within {d} us, on core {d}{s}: as the kernel reports it, and what this world spawns runs unreserved\n", .{
            r.runtime_ns / 1000, r.period_ns / 1000, r.deadline_ns / 1000, r.core,
            if (r.cores == 1) " and no other" else "",
        });
    } else {
        try out.print("reserved: no reservation -- this world runs under policy {d} on {d} core{s}, and gets what is left\n", .{ r.policy, r.cores, if (r.cores == 1) "" else "s" });
    }
    if (stay) |path| {
        try out.flush();
        const f = std.fs.cwd().createFile(path, .{}) catch |e| {
            try out.print("reserved: could not mark {s} ({s})\n", .{ path, @errorName(e) });
            return 1;
        };
        f.close();
        // a reserved task that sleeps spends none of its runtime; it stays until the machine ends
        while (true) std.Thread.sleep(std.time.ns_per_s);
    }
    return 0;
}

// ---- judged beside the code -------------------------------------------

const test_res = machine.Reservation{ .period_us = 1000, .deadline_us = 500, .runtime_us = 200, .core = 1, .line = 0 };

test "the attribute is the declaration in nanoseconds, resetting on fork (TIM-1)" {
    const a = attrOf(test_res);
    try std.testing.expectEqual(SCHED_DEADLINE, a.policy);
    try std.testing.expectEqual(@as(u64, 200_000), a.runtime);
    try std.testing.expectEqual(@as(u64, 500_000), a.deadline);
    try std.testing.expectEqual(@as(u64, 1_000_000), a.period);
    try std.testing.expect(a.flags & SCHED_FLAG_RESET_ON_FORK != 0);
    try std.testing.expectEqual(@as(u32, 48), a.size);
}

/// What a child answers: 0 when it took the reservation, read it back as given, and its own child ran
/// unreserved; 4 when the kernel would not let it reserve at all (no privilege: the question cannot be
/// asked here); 1..3 for each thing that was wrong.
fn childTakesAndReadsBack() u8 {
    take(test_res) catch |e| return if (e == error.NoPrivilege) 4 else 1;
    const r = readBack() catch return 2;
    if (r.policy != SCHED_DEADLINE or r.runtime_ns != 200_000 or r.deadline_ns != 500_000 or r.period_ns != 1_000_000 or !r.reset_on_fork) return 2;
    // what it spawns is a normal task, which is the only way it may spawn at all
    const pid = std.posix.fork() catch return 3;
    if (pid == 0) {
        const g = readBack() catch linux.exit(1);
        linux.exit(if (g.policy == SCHED_DEADLINE) 1 else 0);
    }
    var status: u32 = 0;
    _ = linux.wait4(pid, &status, 0, null);
    if (status & 0x7f != 0 or (status >> 8) & 0xff != 0) return 3;
    return 0;
}

fn inAChild(f: *const fn () u8) !u8 {
    const pid = try std.posix.fork();
    if (pid == 0) linux.exit(f());
    var status: u32 = 0;
    _ = linux.wait4(pid, &status, 0, null);
    if (status & 0x7f != 0) return error.ChildKilled;
    return @intCast((status >> 8) & 0xff);
}

test "a world takes its reservation, the kernel reads it back as given, and what it spawns runs unreserved (TIM-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const answer = try inAChild(childTakesAndReadsBack);
    if (answer == 4) return error.SkipZigTest; // no privilege here: the question cannot be asked
    try std.testing.expectEqual(@as(u8, 0), answer);
}

fn childAsksTheImpossible() u8 {
    // a runtime longer than its deadline: the court refuses this before any boot, and this is the
    // kernel's own arithmetic refusing it too, with its own word for it
    const bad = machine.Reservation{ .period_us = 1000, .deadline_us = 500, .runtime_us = 600, .core = 1, .line = 0 };
    take(bad) catch |e| return if (e == error.Invalid) 0 else 1;
    return 2; // the kernel took it, which it must not
}

test "the kernel's own arithmetic refuses a runtime longer than its deadline (TIM-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    // EINVAL comes before the privilege check in the kernel, so this holds for any caller
    try std.testing.expectEqual(@as(u8, 0), try inAChild(childAsksTheImpossible));
}
