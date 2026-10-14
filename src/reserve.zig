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
//! A world that runs past its runtime in a period is told so (SAFE-1): the reservation carries
//! `SCHED_FLAG_DL_OVERRUN`, so the kernel sends the task SIGXCPU at its next tick after an overrun,
//! and the floor HOLDS that word -- blocked in the process that execs the world, a mask the exec
//! keeps -- until the world listens for it (`listen`). Between the reservation and the world's first
//! instruction lie the filter, the identity, the exec and the loading, all on the world's own budget
//! and, on an emulator, many periods of it: delivered then, the word ended every reserved world
//! before it ran. A world that listens with a handler counts the word and goes on; one that listens
//! without a handler is ended by it; what it does with the word is the world's, as the ruling says.
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
/// The kernel's word on an overrun (SAFE-1): with this flag a task that runs past its runtime in a
/// period is sent SIGXCPU at its next tick, whose default is to end the task.
pub const SCHED_FLAG_DL_OVERRUN: u64 = 0x04;

/// The attribute the kernel is handed: the declaration's microseconds, as nanoseconds; resetting on
/// fork; signalled on overrun.
pub fn attrOf(r: machine.Reservation) linux.sched_attr {
    return .{
        .policy = SCHED_DEADLINE,
        .flags = SCHED_FLAG_RESET_ON_FORK | SCHED_FLAG_DL_OVERRUN,
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

/// Hold the kernel's word on overruns until the world listens for it (SAFE-1). Called in the process
/// that will exec the world, BEFORE `take`. A mask survives an exec, and so does one pending signal;
/// a world that wants the word unblocks it -- `listen` -- with a handler in place, or without one and
/// is ended by it.
pub fn holdOverruns() void {
    var set = std.posix.sigemptyset();
    std.posix.sigaddset(&set, linux.SIG.XCPU);
    std.posix.sigprocmask(linux.SIG.BLOCK, &set, null);
}

var overruns = std.atomic.Value(u32).init(0);

fn onOverrun(_: c_int) callconv(.c) void {
    _ = overruns.fetchAdd(1, .seq_cst);
}

/// Listen for the kernel's word: count each SIGXCPU and go on. The count starts at zero HERE -- a
/// word pending from before the world listened (its own loading, on the emulator) is delivered on
/// the unblock and dropped, so a witness counts the overruns of its loop and not of its start.
pub fn listen() void {
    const sa = std.posix.Sigaction{
        .handler = .{ .handler = onOverrun },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(linux.SIG.XCPU, &sa, null);
    var set = std.posix.sigemptyset();
    std.posix.sigaddset(&set, linux.SIG.XCPU);
    std.posix.sigprocmask(linux.SIG.UNBLOCK, &set, null);
    overruns.store(0, .seq_cst);
}

/// How many times the kernel said so since `listen`.
pub fn overrunsHeard() u32 {
    return overruns.load(.seq_cst);
}

/// What the kernel says the calling task runs under.
pub const Reading = struct {
    policy: u32,
    runtime_ns: u64,
    deadline_ns: u64,
    period_ns: u64,
    reset_on_fork: bool,
    /// the kernel signals this task when it runs past its runtime (SAFE-1)
    overrun_signalled: bool,
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
        .overrun_signalled = (attr.flags & SCHED_FLAG_DL_OVERRUN) != 0,
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
        try out.print("reserved: SCHED_DEADLINE -- {d} us of every {d} us, within {d} us, on core {d}{s}: as the kernel reports it, {s} if it runs past its runtime, and what this world spawns runs unreserved\n", .{
            r.runtime_ns / 1000, r.period_ns / 1000, r.deadline_ns / 1000, r.core,
            if (r.cores == 1) " and no other" else "",
            if (r.overrun_signalled) "signalled" else "NOT signalled",
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

pub const test_res = machine.Reservation{ .period_us = 1000, .deadline_us = 500, .runtime_us = 200, .core = 1, .line = 0 };

test "the attribute is the declaration in nanoseconds, resetting on fork, signalled on overrun (TIM-1, SAFE-1)" {
    const a = attrOf(test_res);
    try std.testing.expectEqual(SCHED_DEADLINE, a.policy);
    try std.testing.expectEqual(@as(u64, 200_000), a.runtime);
    try std.testing.expectEqual(@as(u64, 500_000), a.deadline);
    try std.testing.expectEqual(@as(u64, 1_000_000), a.period);
    try std.testing.expect(a.flags & SCHED_FLAG_RESET_ON_FORK != 0);
    try std.testing.expect(a.flags & SCHED_FLAG_DL_OVERRUN != 0);
    try std.testing.expectEqual(@as(u32, 48), a.size);
}

/// What a child answers: 0 when it took the reservation, read it back as given, and its own child ran
/// unreserved; 4 when the kernel would not let it reserve at all (no privilege: the question cannot be
/// asked here); 1..3 for each thing that was wrong.
fn childTakesAndReadsBack() u8 {
    take(test_res) catch |e| return if (e == error.NoPrivilege) 4 else 1;
    const r = readBack() catch return 2;
    if (r.policy != SCHED_DEADLINE or r.runtime_ns != 200_000 or r.deadline_ns != 500_000 or r.period_ns != 1_000_000 or !r.reset_on_fork or !r.overrun_signalled) return 2;
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

fn monotonicNs() u64 {
    var ts: linux.timespec = .{ .sec = 0, .nsec = 0 };
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

/// Burn the processor until the word is heard, or `ms` of wall time pass: true if heard.
fn burnUntilHeardOr(ms: u64) bool {
    const t0 = monotonicNs();
    var x: u64 = 1;
    while (overrunsHeard() == 0) {
        x = x *% 6364136223846793005 +% 1442695040888963407;
        std.mem.doNotOptimizeAway(x);
        if (monotonicNs() - t0 > ms * std.time.ns_per_ms) return false;
    }
    return true;
}

/// 0 when the word came and was counted; 4 when no reservation can be taken here; 1 when a burning
/// reserved task was never told in half a second of wall time; 3 when the reservation was refused.
fn childListensAndBurns() u8 {
    holdOverruns();
    take(test_res) catch |e| return if (e == error.NoPrivilege) 4 else 3;
    listen();
    return if (burnUntilHeardOr(500)) 0 else 1;
}

test "the kernel's word on an overrun reaches a world that listens, and is counted (SAFE-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const answer = try inAChild(childListensAndBurns);
    if (answer == 4) return error.SkipZigTest; // no privilege here: the question cannot be asked
    try std.testing.expectEqual(@as(u8, 0), answer);
}

/// Listen with no handler: the word's default is to end the task. This child burns and does not
/// come back -- or answers 1 after half a second, which means the word never came; 4 when no
/// reservation can be taken here.
fn childListensDeaf() u8 {
    holdOverruns();
    take(test_res) catch |e| return if (e == error.NoPrivilege) 4 else 3;
    var set = std.posix.sigemptyset();
    std.posix.sigaddset(&set, linux.SIG.XCPU);
    std.posix.sigprocmask(linux.SIG.UNBLOCK, &set, null);
    // nobody counts, so this runs its whole span and answers 1 -- unless the kernel ends it first
    return if (burnUntilHeardOr(500)) 2 else 1;
}

test "a world that listens without handling is ended by the word, and the word is SIGXCPU (SAFE-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const pid = try std.posix.fork();
    if (pid == 0) linux.exit(childListensDeaf());
    var status: u32 = 0;
    _ = linux.wait4(pid, &status, 0, null);
    if (status & 0x7f == 0) {
        const code: u8 = @intCast((status >> 8) & 0xff);
        if (code == 4) return error.SkipZigTest;
        return error.NotEndedByTheWord; // it burned on and answered
    }
    try std.testing.expectEqual(@as(u32, linux.SIG.XCPU), status & 0x7f);
}
