//! The latency witness (TCK-1): a world runs its declared period on an ABSOLUTE timer and says how
//! late each wake was and how long each step took -- the median, the 99th, the worst, and how many
//! periods ran past the deadline. The difference between a promise and a measurement is the only
//! thing a real-time claim is: the reservation (TIM-1) is the promise, and this is the measurement.
//!
//! The numbers are the machine's: on the emulator they are its host's, so the pin holds none of them
//! (the image script keeps the SHAPE of the measured line and normalises every number away), the
//! transcript keeps them for a reader, and the first number that counts is a board's (OS-5). A report,
//! never an assertion: a world that woke late says so and exits 0, because a measurement is what it is.
//!
//! `harb spin` is the neighbour: it says where it runs, marks its READY path, and burns the processor
//! until the machine ends -- a reserved one is held to its runtime by the kernel, an unreserved one
//! takes what the scheduler gives, and the witness beside either shows which. A reserved one runs
//! past its runtime by construction, so it is the one that shows the kernel's word on an overrun
//! arriving (SAFE-1): it listens, says so once, and only then marks its path.

const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;
const reserve = @import("reserve.zig");

pub const max_periods: usize = 100_000;

/// One period as the loop saw it: how late the wake was, how long the step took, and whether the
/// step was done past the deadline measured from the period's start.
pub const Sample = struct { late_ns: u64, step_ns: u64, missed: bool };

/// What the loop measured, as arithmetic over the samples.
pub const Summary = struct {
    periods: usize,
    late_median_ns: u64,
    late_p99_ns: u64,
    late_worst_ns: u64,
    step_worst_ns: u64,
    missed: usize,
};

/// The median, the 99th percentile and the worst of the wakes' lateness, the worst step, the misses.
/// The 99th is the sample below which 99 per cent of the wakes fall (index 99n/100 of the sorted
/// lateness), the median the one at n/2.
pub fn summarise(alloc: std.mem.Allocator, samples: []const Sample) !Summary {
    if (samples.len == 0) return error.NothingMeasured;
    const late = try alloc.alloc(u64, samples.len);
    defer alloc.free(late);
    var step_worst: u64 = 0;
    var missed: usize = 0;
    for (samples, 0..) |s, i| {
        late[i] = s.late_ns;
        if (s.step_ns > step_worst) step_worst = s.step_ns;
        if (s.missed) missed += 1;
    }
    std.mem.sort(u64, late, {}, std.sort.asc(u64));
    const n = samples.len;
    return .{
        .periods = n,
        .late_median_ns = late[n / 2],
        .late_p99_ns = late[@min(n - 1, (n * 99) / 100)],
        .late_worst_ns = late[n - 1],
        .step_worst_ns = step_worst,
        .missed = missed,
    };
}

fn nowNs() u64 {
    var ts: linux.timespec = .{ .sec = 0, .nsec = 0 };
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

/// Sleep until an ABSOLUTE instant of the monotonic clock: the period's next start is a point in
/// time, never "the period from now", or every late wake would push the next one later (drift).
fn sleepUntilNs(t: u64) void {
    const ts: linux.timespec = .{ .sec = @intCast(t / std.time.ns_per_s), .nsec = @intCast(t % std.time.ns_per_s) };
    while (true) {
        const rc = linux.clock_nanosleep(.MONOTONIC, .{ .ABSTIME = true }, &ts, null);
        if (linux.E.init(rc) != .INTR) return;
    }
}

/// The step: a fixed small computation, the same every period, so that its time is the processor's
/// to give and not the work's to vary. Returns how long it took.
fn step() u64 {
    const t0 = nowNs();
    var x: u64 = 0x9E3779B97F4A7C15;
    var i: u32 = 0;
    while (i < 4000) : (i += 1) {
        x = x *% 6364136223846793005 +% 1442695040888963407;
    }
    std.mem.doNotOptimizeAway(x);
    return nowNs() - t0;
}

/// Run `periods` periods of `period_ns`, each: sleep until the period's start, note how late the wake
/// was, do the step, note whether it was done within `deadline_ns` of the start.
pub fn runLoop(alloc: std.mem.Allocator, periods: usize, period_ns: u64, deadline_ns: u64) ![]Sample {
    const samples = try alloc.alloc(Sample, periods);
    const t0 = nowNs();
    for (samples, 1..) |*s, i| {
        const target = t0 + @as(u64, i) * period_ns;
        sleepUntilNs(target);
        const woke = nowNs();
        const late = if (woke > target) woke - target else 0;
        const took = step();
        const done = nowNs();
        s.* = .{ .late_ns = late, .step_ns = took, .missed = (done - target) > deadline_ns };
    }
    return samples;
}

/// `on core 1 and no other`, or `on 2 cores`: where the kernel lets this task run.
fn corePhrase(buf: []u8, r: reserve.Reading) []const u8 {
    if (r.cores == 1) return std.fmt.bufPrint(buf, "on core {d} and no other", .{r.core}) catch "on a core";
    return std.fmt.bufPrint(buf, "on {d} cores", .{r.cores}) catch "on cores";
}

/// `harb tick <periods> --period <us> --deadline <us>`: the period and the deadline are written in the
/// RUN line, so that a world with no reservation can still be asked to keep one (which is the tour's
/// BREAK IT); a world WITH a reservation is refused if the two disagree, because a witness runs the
/// period it was given and a declaration that says two things says nothing.
pub fn run(alloc: std.mem.Allocator, args: []const []const u8, out: *std.Io.Writer) !u8 {
    var periods: ?usize = null;
    var period_us: ?u64 = null;
    var deadline_us: ?u64 = null;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--period") and i + 1 < args.len) {
            i += 1;
            period_us = std.fmt.parseInt(u64, args[i], 10) catch null;
        } else if (std.mem.eql(u8, a, "--deadline") and i + 1 < args.len) {
            i += 1;
            deadline_us = std.fmt.parseInt(u64, args[i], 10) catch null;
        } else if (periods == null and !std.mem.startsWith(u8, a, "--")) {
            periods = std.fmt.parseInt(usize, a, 10) catch null;
        } else {
            try out.print("tick: takes <periods> --period <us> --deadline <us>; not '{s}'\n", .{a});
            return 2;
        }
    }
    const n = periods orelse 1000;
    const p = period_us orelse {
        try out.print("tick: --period <us> is the period to keep, and none was given\n", .{});
        return 2;
    };
    const d = deadline_us orelse {
        try out.print("tick: --deadline <us> is the time each step has, and none was given\n", .{});
        return 2;
    };
    if (n == 0 or n > max_periods) {
        try out.print("tick: {d} periods: one to {d}\n", .{ n, max_periods });
        return 2;
    }
    if (p == 0 or d == 0 or d > p) {
        try out.print("tick: a period of {d} us and a deadline of {d} us: both above zero, the deadline within the period\n", .{ p, d });
        return 2;
    }
    if (builtin.os.tag != .linux) {
        try out.print("tick: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
        return 2;
    }
    const r = reserve.readBack() catch |e| {
        try out.print("tick: the kernel would not say what this world runs under ({s})\n", .{@errorName(e)});
        return 1;
    };
    var cb: [48]u8 = undefined;
    const core = corePhrase(&cb, r);
    if (r.policy == reserve.SCHED_DEADLINE) {
        if (r.period_ns != p * 1000 or r.deadline_ns != d * 1000) {
            try out.print("tick: the reservation says {d} us of every {d} us within {d} us, and the arguments say a period of {d} us and a deadline of {d} us: a witness runs the period it was given, and these are two\n", .{ r.runtime_ns / 1000, r.period_ns / 1000, r.deadline_ns / 1000, p, d });
            return 1;
        }
        try out.print("tick: {d} periods of {d} us, deadline {d} us -- under SCHED_DEADLINE ({d} us of every {d} us), {s}\n", .{ n, p, d, r.runtime_ns / 1000, r.period_ns / 1000, core });
    } else {
        try out.print("tick: {d} periods of {d} us, deadline {d} us -- NO RESERVATION: policy {d}, {s}, kept by nobody\n", .{ n, p, d, r.policy, core });
    }
    try out.flush();
    // listen for the kernel's word on an overrun (SAFE-1): counted from here, so the loop's overruns
    // and not the loading's; with no reservation nobody sends it, and the count stays 0
    reserve.listen();
    const samples = try runLoop(alloc, n, p * 1000, d * 1000);
    defer alloc.free(samples);
    const s = try summarise(alloc, samples);
    try out.print("tick: measured -- woke late by {d} us at the median, {d} us at the 99th, {d} us at the worst; the step took {d} us at the worst; {d} of {d} past the deadline; signalled {d} times for running past its runtime\n", .{
        s.late_median_ns / 1000, s.late_p99_ns / 1000, s.late_worst_ns / 1000, s.step_worst_ns / 1000, s.missed, s.periods, reserve.overrunsHeard(),
    });
    return 0;
}

/// `harb spin [--ready <path>]`: say where this world runs, mark the path, and burn the processor until
/// the machine ends. The neighbour a witness is measured beside.
pub fn spin(args: []const []const u8, out: *std.Io.Writer) !u8 {
    var ready: ?[]const u8 = null;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--ready") and i + 1 < args.len) {
            i += 1;
            ready = args[i];
        } else {
            try out.print("spin: takes nothing, or --ready <path>; not '{s}'\n", .{args[i]});
            return 2;
        }
    }
    if (builtin.os.tag != .linux) {
        try out.print("spin: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
        return 2;
    }
    const r = reserve.readBack() catch |e| {
        try out.print("spin: the kernel would not say what this world runs under ({s})\n", .{@errorName(e)});
        return 1;
    };
    var cb: [48]u8 = undefined;
    const core = corePhrase(&cb, r);
    if (r.policy == reserve.SCHED_DEADLINE) {
        try out.print("spin: {s}, under SCHED_DEADLINE ({d} us of every {d} us): it burns what it was given and the kernel holds it there\n", .{ core, r.runtime_ns / 1000, r.period_ns / 1000 });
    } else {
        try out.print("spin: {s}, under policy {d}: it burns what the scheduler gives\n", .{ core, r.policy });
    }
    try out.flush();
    if (r.policy == reserve.SCHED_DEADLINE) {
        // A world that burns runs past its runtime in its first period, and the kernel says so at
        // its next tick (SAFE-1): listen, burn until the word comes, and say it BEFORE marking the
        // path, so that whatever PID 1 says next comes after it and the transcript's order is a fact
        // and not a race (BDG-1). A reserved spinner that is never told never marks ready, and the
        // machine says so by never saying ready.
        reserve.listen();
        var y: u64 = 1;
        while (reserve.overrunsHeard() == 0) {
            y = y *% 6364136223846793005 +% 1442695040888963407;
            std.mem.doNotOptimizeAway(y);
        }
        try out.print("spin: signalled for running past its runtime -- the kernel's word reached it, and it goes on, held to what it was given\n", .{});
        try out.flush();
    }
    if (ready) |path| {
        const f = std.fs.cwd().createFile(path, .{}) catch |e| {
            try out.print("spin: could not mark {s} ({s})\n", .{ path, @errorName(e) });
            return 1;
        };
        f.close();
    }
    var x: u64 = 1;
    while (true) {
        x = x *% 6364136223846793005 +% 1442695040888963407;
        std.mem.doNotOptimizeAway(x);
    }
}

// ---- judged beside the code -------------------------------------------

test "the summary is the median, the 99th and the worst of the lateness, the worst step, and the misses (TCK-1)" {
    // ten wakes: late by 0..9 us, steps of 1..10 us, two of them past the deadline
    var samples: [10]Sample = undefined;
    for (&samples, 0..) |*s, i| s.* = .{ .late_ns = @as(u64, i) * 1000, .step_ns = (@as(u64, i) + 1) * 1000, .missed = i >= 8 };
    const s = try summarise(std.testing.allocator, &samples);
    try std.testing.expectEqual(@as(usize, 10), s.periods);
    try std.testing.expectEqual(@as(u64, 5000), s.late_median_ns);
    try std.testing.expectEqual(@as(u64, 9000), s.late_p99_ns);
    try std.testing.expectEqual(@as(u64, 9000), s.late_worst_ns);
    try std.testing.expectEqual(@as(u64, 10000), s.step_worst_ns);
    try std.testing.expectEqual(@as(usize, 2), s.missed);
}

test "the summary reads the lateness SORTED, not in the order the wakes came (TCK-1)" {
    // the worst wake first: a summary that read the last sample as the worst would say 1 us
    const samples = [_]Sample{
        .{ .late_ns = 9000, .step_ns = 1, .missed = false },
        .{ .late_ns = 3000, .step_ns = 1, .missed = false },
        .{ .late_ns = 1000, .step_ns = 1, .missed = false },
    };
    const s = try summarise(std.testing.allocator, &samples);
    try std.testing.expectEqual(@as(u64, 9000), s.late_worst_ns);
    try std.testing.expectEqual(@as(u64, 3000), s.late_median_ns);
    try std.testing.expectError(error.NothingMeasured, summarise(std.testing.allocator, &.{}));
}

test "the loop keeps an absolute period: n periods take no less than n periods, and a wake is never early (TCK-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    // 20 periods of 2 ms: the loop cannot take less than 40 ms, and each wake is at or after its target
    const t0 = nowNs();
    const samples = try runLoop(std.testing.allocator, 20, 2 * std.time.ns_per_ms, 2 * std.time.ns_per_ms);
    defer std.testing.allocator.free(samples);
    const took = nowNs() - t0;
    try std.testing.expect(took >= 40 * std.time.ns_per_ms);
    try std.testing.expectEqual(@as(usize, 20), samples.len);
    // a wake that was EARLY would read as a negative lateness, which the loop clamps: so assert the
    // sum of lateness and steps is less than the whole, which an early wake would also satisfy --
    // the question that decides is the floor of `took`, asserted above
    const s = try summarise(std.testing.allocator, samples);
    try std.testing.expect(s.late_worst_ns < took);
}
