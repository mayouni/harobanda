// timeserve.zig -- the acts of the time seat that need a kernel (TIME-1, STZ-OS-RULING-07).
//
// timeattest.zig is the statement and its judgement, and needs nothing. This is what touches the machine:
// reading the clock a machine was declared to have, answering a question on a link, and asking one. It is
// Linux code, and everything here that cannot be run on another host says so by being reached only from
// PID 1 (`harb time verify` is timeaudit.zig's, and needs no kernel).
//
// THE CLOCK. A machine that is a time authority declares the clock it has (`CLOCK "/dev/rtc0"`) and the
// floor reads it through the kernel's RTC interface. It is read once at boot, before the machine says it
// answers, so that the line is said only after the hardware has answered (CON-1): a clock that is not
// there, or was never set, makes a machine that does not answer and says why. It is read again for every
// question, because the time a statement states is the time of its question. A clock that reads before
// `earliest` was never set -- the battery died, or the board never had one -- and its reading is the epoch
// wearing the authority of a date. The authority refuses to sign that, and says so.
//
// THE QUESTION. One datagram out (`time? entry=<64 hex>`), one back (the signed statement, or silence). It
// is UDP because a question is one packet and an answer is one, and because the asker's retry is the
// protocol: a lost datagram is a missing answer, and a missing answer is a record that stays ORDERED and
// UNDATED -- which is a true state, not an error. Anyone on the wire can send a datagram that looks like an
// answer; only the authority's signature makes it one, and the asker holds the key it takes the word of
// (`TIME_KEY`), so a forged answer is refused at the door. What the asker KEEPS is the statement and
// nothing that came with it: an answer is one line of at most `max_line` bytes, with one line end at most,
// or it is not that statement -- PID 1 reads this off the wire and must never be taken down by what it reads.
//
// THE RESPONDER is PID 1's own code in a child that is forked and never exec'd, so close-on-exec does not
// reach it (WDG-1's flag is for worlds): `closeInherited` is what it is given instead, and it keeps nothing
// of PID 1's but its stdio and its one socket.

const std = @import("std");
const builtin = @import("builtin");
const Ed25519 = std.crypto.sign.Ed25519;
const timeattest = @import("timeattest.zig");

const linux = std.os.linux;

/// The kernel's `struct rtc_time`: the broken-down time an RTC reports, in the clock's own timezone, which
/// for a machine that keeps its RTC in UTC is UTC. `tm_year` counts from 1900 and `tm_mon` from 0.
pub const RtcTime = extern struct {
    sec: i32,
    min: i32,
    hour: i32,
    mday: i32,
    mon: i32,
    year: i32,
    wday: i32,
    yday: i32,
    isdst: i32,
};

/// _IOR('p', 0x09, struct rtc_time): read direction, 36 bytes, the RTC's type letter, request 9. The same
/// number on every architecture this binary boots on (the generic ioctl encoding).
const RTC_RD_TIME: u32 = 0x80247009;

/// A reading before this is a clock that was never set, or whose battery died, and not a time. (A bound on the
/// clock, not a claim about the date: the authority refuses to sign a time that cannot be this decade, and a
/// clock set wrongly to a later one is the authority's to have set right -- an authority is enrolled by hand,
/// and so is its hardware.) It is the statement's own constant: the one who signs and the one who reads ask
/// one question.
pub const earliest: i64 = timeattest.earliest;

/// Whether a reading can be a time at all.
pub fn plausible(t: i64) bool {
    return t >= earliest;
}

pub const ClockError = error{ NoClock, ClockRefused, ClockNotSet };

/// Read the clock at `path` as seconds since 1970 UTC.
pub fn readRtc(path: []const u8) ClockError!i64 {
    if (builtin.os.tag != .linux) return error.NoClock;
    const p = std.posix.toPosixPath(path) catch return error.NoClock;
    const rc = linux.open(&p, .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    switch (linux.E.init(rc)) {
        .SUCCESS => {},
        else => return error.NoClock,
    }
    const fd: i32 = @intCast(rc);
    defer _ = linux.close(fd);
    var tm: RtcTime = undefined;
    if (linux.E.init(linux.ioctl(fd, RTC_RD_TIME, @intFromPtr(&tm))) != .SUCCESS) return error.ClockRefused;
    if (tm.mon < 0 or tm.mon > 11 or tm.mday < 1 or tm.mday > 31 or tm.hour < 0 or tm.hour > 23 or tm.min < 0 or tm.min > 59 or tm.sec < 0 or tm.sec > 60) return error.ClockRefused;
    const t = timeattest.unixFromCivil(@as(i64, tm.year) + 1900, @intCast(tm.mon + 1), @intCast(tm.mday), @intCast(tm.hour), @intCast(tm.min), @intCast(tm.sec));
    if (!plausible(t)) return error.ClockNotSet;
    return t;
}

/// What a person reads when the clock would not answer.
pub fn clockWords(e: ClockError) []const u8 {
    return switch (e) {
        error.NoClock => "there is no such device (does the board have one, and has the kernel its driver?)",
        error.ClockRefused => "the kernel would not read it",
        error.ClockNotSet => "it reads a time before this decade: the clock was never set, or its battery died",
    };
}

// ---- the authority: a socket, and the loop that answers ----------------------------------------------

fn sockIn(ip: u32, port: u16) linux.sockaddr.in {
    return .{
        .family = linux.AF.INET,
        .port = std.mem.nativeToBig(u16, port),
        .addr = std.mem.nativeToBig(u32, ip),
        .zero = [_]u8{0} ** 8,
    };
}

/// A UDP socket bound to `ip:port` on the link `iface`, and on no other link. Taken by PID 1 before it forks
/// the loop, so that "this machine could not become the authority it declared itself" is said by the machine,
/// in order, in the transcript that is judged.
pub fn bind(ip: u32, port: u16, iface: []const u8) !i32 {
    const rc = linux.socket(linux.AF.INET, linux.SOCK.DGRAM | linux.SOCK.CLOEXEC, 0);
    if (linux.E.init(rc) != .SUCCESS) return error.NoSocket;
    const fd: i32 = @intCast(rc);
    errdefer _ = linux.close(fd);
    if (linux.E.init(linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.BINDTODEVICE, iface.ptr, @intCast(iface.len))) != .SUCCESS) return error.NoSuchLink;
    const local = sockIn(ip, port);
    if (linux.E.init(linux.bind(fd, @ptrCast(&local), @sizeOf(linux.sockaddr.in))) != .SUCCESS) return error.BindRefused;
    return fd;
}

/// The answer to one datagram, or null if it asks nothing this authority answers. Pure: the loop gives it the
/// reading, a test gives it a number.
pub fn answer(out: []u8, datagram: []const u8, pair: Ed25519.KeyPair, t: i64) ?[]const u8 {
    const entry = timeattest.parseRequest(datagram) orelse return null;
    return timeattest.sign(out, pair, &entry, t) catch null;
}

/// The answer to one datagram, with the time read from the clock at `clock` at the moment of the question:
/// silence if the datagram asks nothing, and silence if the clock will not answer, or reads a time before this
/// decade. A time the authority could not read is never replaced by one it made up: a statement is an upper
/// bound, and a made-up time earlier than the real one would be a false statement over a true signature.
pub fn respond(out: []u8, datagram: []const u8, pair: Ed25519.KeyPair, clock: []const u8) ?[]const u8 {
    if (timeattest.parseRequest(datagram) == null) return null;
    const t = readRtc(clock) catch return null;
    return answer(out, datagram, pair, t);
}

/// What the responder is given in place of close-on-exec, in the child, right after the fork: everything PID 1
/// holds open is closed but stdio and `except`. The responder is not a world and is never exec'd, so the flag
/// that keeps a world from inheriting the hardware watchdog (WDG-1) does not reach it, and a process that
/// parses datagrams and holds the device's key should not also hold a writable descriptor to the watchdog, to
/// a pipe, or to a file PID 1 had open at the moment it forked. A raw `close`, whose answer is ignored: the
/// standard library's call makes a closed descriptor `unreachable`, which is a panic.
pub fn closeInherited(except: i32) void {
    var fd: i32 = 3;
    while (fd < 1024) : (fd += 1) {
        if (fd != except) _ = linux.close(fd);
    }
}

/// The loop PID 1 forks: read a question, read the clock, sign, answer. It says nothing -- a server that
/// wrote to the console at the pace of whoever asked would write a different transcript every boot -- and it
/// answers nothing it cannot stand behind (`respond`).
pub fn serve(fd: i32, pair: Ed25519.KeyPair, clock: []const u8) noreturn {
    var rbuf: [512]u8 = undefined;
    var sbuf: [timeattest.max_line]u8 = undefined;
    while (true) {
        var from: linux.sockaddr = undefined;
        var flen: linux.socklen_t = @sizeOf(linux.sockaddr);
        const r = linux.recvfrom(fd, &rbuf, rbuf.len, 0, &from, &flen);
        if (linux.E.init(r) != .SUCCESS) continue;
        const line = respond(&sbuf, rbuf[0..r], pair, clock) orelse continue;
        _ = linux.sendto(fd, line.ptr, line.len, 0, &from, flen);
    }
}

// ---- the statements a machine keeps ------------------------------------------------------------------

/// Keep a statement as received: one more line at the end of `name` in `dir`, which only this machine can write.
/// A power cut in the middle of an earlier append leaves a last line with no end, and the next statement must not
/// join it (two statements run together are two refused ones): so a file that does not end in a newline is ended
/// first, and the cut line stays what it is, a line that is not a statement.
pub fn keepIn(dir: std.fs.Dir, name: []const u8, line: []const u8) !void {
    const f = dir.openFile(name, .{ .mode = .read_write }) catch |e| switch (e) {
        error.FileNotFound => try dir.createFile(name, .{ .read = true, .mode = 0o600 }),
        else => return e,
    };
    defer f.close();
    const end = try f.getEndPos();
    if (end > 0) {
        var last: [1]u8 = undefined;
        if ((try f.preadAll(&last, end - 1)) == 1 and last[0] != '\n') {
            try f.seekTo(end);
            try f.writeAll("\n");
        }
    }
    try f.seekFromEnd(0);
    try f.writeAll(line);
    try f.writeAll("\n");
    f.sync() catch {};
}

/// `keepIn` at a path (absolute on a machine).
pub fn keep(path: []const u8, line: []const u8) !void {
    return keepIn(std.fs.cwd(), path, line);
}

// ---- the asker ---------------------------------------------------------------------------------------

pub const Asked = union(enum) {
    /// a statement from the authority, about the entry asked: the line as it is kept (one line, no end), and what it says
    answered: struct { line: [timeattest.max_line]u8, len: usize, t: i64, authority: [16]u8 },
    /// nobody answered, in every try: the record stays ORDERED and UNDATED, which is true
    silent,
    /// something answered, and it is not the authority's word: why
    refused: timeattest.Verdict,
    /// the authority's word, about another entry
    wrong_entry,
    no_socket,
};

/// Ask `ip:port` for the time of `entry`, up to `tries` times, `wait_ms` apiece, and take the answer only if
/// `key` verifies it and it is about `entry`.
pub fn ask(ip: u32, port: u16, entry: []const u8, key: Ed25519.PublicKey, tries: u32, wait_ms: i32) Asked {
    if (builtin.os.tag != .linux) return .no_socket;
    const rc = linux.socket(linux.AF.INET, linux.SOCK.DGRAM | linux.SOCK.CLOEXEC, 0);
    if (linux.E.init(rc) != .SUCCESS) return .no_socket;
    const fd: i32 = @intCast(rc);
    defer _ = linux.close(fd);
    // connected, so that only the authority's address can answer: a datagram from anywhere else never arrives
    const peer = sockIn(ip, port);
    if (linux.E.init(linux.connect(fd, @ptrCast(&peer), @sizeOf(linux.sockaddr.in))) != .SUCCESS) return .no_socket;
    var qbuf: [128]u8 = undefined;
    const q = timeattest.request(&qbuf, entry) catch return .no_socket;
    var refused: ?timeattest.Verdict = null;
    var other_entry = false;
    var n: u32 = 0;
    while (n < tries) : (n += 1) {
        _ = linux.sendto(fd, q.ptr, q.len, 0, null, 0);
        var fds = [1]linux.pollfd{.{ .fd = fd, .events = linux.POLL.IN, .revents = 0 }};
        if (linux.E.init(linux.poll(&fds, 1, wait_ms)) != .SUCCESS or fds[0].revents & linux.POLL.IN == 0) continue;
        var rbuf: [512]u8 = undefined;
        const r = linux.recvfrom(fd, &rbuf, rbuf.len, 0, null, null);
        if (linux.E.init(r) != .SUCCESS) continue;
        const datagram = rbuf[0..r];
        switch (timeattest.verify(datagram, key)) {
            .ok => {
                // verified, so it parsed: one line of at most `max_line` bytes, which is all that is kept
                const kept = timeattest.trimTerminator(datagram);
                const st = timeattest.parse(kept).?;
                if (!std.mem.eql(u8, &st.entry, entry)) {
                    other_entry = true;
                    continue;
                }
                var out: Asked = .{ .answered = .{ .line = undefined, .len = kept.len, .t = st.t, .authority = st.authority } };
                @memcpy(out.answered.line[0..kept.len], kept);
                return out;
            },
            else => |v| refused = v,
        }
    }
    if (other_entry) return .wrong_entry;
    if (refused) |v| return .{ .refused = v };
    return .silent;
}

// ---- tests ---------------------------------------------------------------------------------------

test "a reading is a time only if it can be this decade (TIME-1)" {
    try std.testing.expect(!plausible(0));
    try std.testing.expect(!plausible(946_684_800)); // 2000-01-01: a dead battery's idea of now
    try std.testing.expect(!plausible(earliest - 1));
    try std.testing.expect(plausible(earliest));
    try std.testing.expect(plausible(timeattest.unixFromCivil(2026, 10, 5, 12, 0, 0)));
    // the constant is what it says it is
    try std.testing.expectEqual(timeattest.unixFromCivil(2026, 1, 1, 0, 0, 0), earliest);
}

test "the answer to one datagram is a signed statement, or nothing at all (TIME-1)" {
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, 3);
    const pair = try Ed25519.KeyPair.generateDeterministic(seed);
    const entry = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210";
    var out: [timeattest.max_line]u8 = undefined;
    const line = answer(&out, "time? entry=" ++ entry, pair, 1_790_000_000).?;
    try std.testing.expectEqual(timeattest.Verdict.ok, timeattest.verify(line, pair.public_key));
    try std.testing.expectEqualStrings(entry, &timeattest.parse(line).?.entry);
    // a datagram that asks nothing is not answered: no reflection, no error to leak
    try std.testing.expect(answer(&out, "GET / HTTP/1.0\r\n\r\n", pair, 1_790_000_000) == null);
    try std.testing.expect(answer(&out, "time? entry=abc", pair, 1_790_000_000) == null);
    try std.testing.expect(answer(&out, "", pair, 1_790_000_000) == null);
    // ... and neither is a question that names its subject any other way: what is asked about is an entry's digest
    try std.testing.expect(answer(&out, "time? head=" ++ entry, pair, 1_790_000_000) == null);
}

test "a statement is kept as a line of its own, even after a write the power cut short (TIME-1)" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try keepIn(tmp.dir, "journal.time", "first");
    try keepIn(tmp.dir, "journal.time", "second");
    // a power cut in the middle of the third: no end to the line
    {
        const f = try tmp.dir.openFile("journal.time", .{ .mode = .write_only });
        defer f.close();
        try f.seekFromEnd(0);
        try f.writeAll("thi");
    }
    try keepIn(tmp.dir, "journal.time", "fourth");
    var buf: [128]u8 = undefined;
    const kept = try tmp.dir.readFile("journal.time", &buf);
    // the cut line stays a line that is not a statement, and the next is not run onto it
    try std.testing.expectEqualStrings("first\nsecond\nthi\nfourth\n", kept);
}

test "a clock that will not answer makes silence, and never a time the authority made up (TIME-1)" {
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, 4);
    const pair = try Ed25519.KeyPair.generateDeterministic(seed);
    var out: [timeattest.max_line]u8 = undefined;
    const question = "time? entry=" ++ "ab" ** 32;
    // no such device: on every host, the question is a good one and the clock is not there
    try std.testing.expect(respond(&out, question, pair, "/dev/no-such-clock-for-this-test") == null);
    // and a datagram that asks nothing is not answered by anything, clock or no clock
    try std.testing.expect(respond(&out, "GET / HTTP/1.0", pair, "/dev/no-such-clock-for-this-test") == null);
}

test "the responder keeps nothing of PID 1's but its stdio and its socket (TIME-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    // what PID 1 holds across the fork: a file opened with no close-on-exec (the hardware watchdog is opened
    // before the responder is forked), and the socket the responder is given
    const held_rc = linux.open("/dev/null", .{ .ACCMODE = .WRONLY }, 0);
    try std.testing.expectEqual(linux.E.SUCCESS, linux.E.init(held_rc));
    const kept_rc = linux.open("/dev/null", .{ .ACCMODE = .RDONLY }, 0);
    try std.testing.expectEqual(linux.E.SUCCESS, linux.E.init(kept_rc));
    const held: i32 = @intCast(held_rc);
    const kept: i32 = @intCast(kept_rc);
    defer _ = linux.close(held);
    defer _ = linux.close(kept);
    const pid = try std.posix.fork();
    if (pid == 0) {
        // the child asks the kernel what it has: only the kernel's answer is evidence, and it must not write
        // anything (the test runner's stdout is a channel to the process that runs it)
        closeInherited(kept);
        const gone = linux.E.init(linux.fcntl(held, linux.F.GETFD, 0)) == .BADF;
        const still = linux.E.init(linux.fcntl(kept, linux.F.GETFD, 0)) == .SUCCESS;
        const stdio = linux.E.init(linux.fcntl(1, linux.F.GETFD, 0)) == .SUCCESS;
        linux.exit_group(if (gone and still and stdio) 0 else 1);
    }
    const res = std.posix.waitpid(pid, 0);
    try std.testing.expect(std.posix.W.IFEXITED(res.status));
    try std.testing.expectEqual(@as(u8, 0), std.posix.W.EXITSTATUS(res.status));
}

/// Answer `n` questions on `fd` with a fixed time, then return: the authority's loop, in a thread, for a test.
fn serveFor(fd: i32, pair: Ed25519.KeyPair, t: i64, n: usize) void {
    var rbuf: [512]u8 = undefined;
    var sbuf: [timeattest.max_line]u8 = undefined;
    var served: usize = 0;
    while (served < n) {
        var from: linux.sockaddr = undefined;
        var flen: linux.socklen_t = @sizeOf(linux.sockaddr);
        const r = linux.recvfrom(fd, &rbuf, rbuf.len, 0, &from, &flen);
        if (linux.E.init(r) != .SUCCESS) return;
        served += 1;
        const line = answer(&sbuf, rbuf[0..r], pair, t) orelse continue;
        _ = linux.sendto(fd, line.ptr, line.len, 0, &from, flen);
    }
}

/// An authority that answers ONE question with its word about `entry` whatever it was asked: a buggy one, or
/// one replaying an old answer.
fn serveOtherEntry(fd: i32, pair: Ed25519.KeyPair, t: i64, entry: []const u8) void {
    var rbuf: [512]u8 = undefined;
    var sbuf: [timeattest.max_line]u8 = undefined;
    var from: linux.sockaddr = undefined;
    var flen: linux.socklen_t = @sizeOf(linux.sockaddr);
    const r = linux.recvfrom(fd, &rbuf, rbuf.len, 0, &from, &flen);
    if (linux.E.init(r) != .SUCCESS) return;
    const line = timeattest.sign(&sbuf, pair, entry, t) catch return;
    _ = linux.sendto(fd, line.ptr, line.len, 0, &from, flen);
}

/// A datagram that carries the authority's GENUINE answer to the question asked, and twenty line ends after it:
/// what somebody on the wire sends who has seen the real answer go by and sends it again with more on the end.
/// It is longer than the buffer a statement is kept in.
fn serveRespelled(fd: i32, pair: Ed25519.KeyPair, t: i64) void {
    var rbuf: [512]u8 = undefined;
    var sbuf: [512]u8 = undefined;
    var from: linux.sockaddr = undefined;
    var flen: linux.socklen_t = @sizeOf(linux.sockaddr);
    const r = linux.recvfrom(fd, &rbuf, rbuf.len, 0, &from, &flen);
    if (linux.E.init(r) != .SUCCESS) return;
    const entry = timeattest.parseRequest(rbuf[0..r]) orelse return;
    const line = timeattest.sign(&sbuf, pair, &entry, t) catch return;
    @memset(sbuf[line.len .. line.len + 20], '\n');
    _ = linux.sendto(fd, &sbuf, line.len + 20, 0, &from, flen);
}

fn loopbackServer(pair: Ed25519.KeyPair, t: i64, n: usize) !struct { port: u16, thread: std.Thread, fd: i32 } {
    const fd = try bind(0x7F000001, 0, "lo");
    var local: linux.sockaddr.in = undefined;
    var len: linux.socklen_t = @sizeOf(linux.sockaddr.in);
    try std.testing.expectEqual(linux.E.SUCCESS, linux.E.init(linux.getsockname(fd, @ptrCast(&local), &len)));
    const th = try std.Thread.spawn(.{}, serveFor, .{ fd, pair, t, n });
    return .{ .port = std.mem.bigToNative(u16, local.port), .thread = th, .fd = fd };
}

test "asked over a wire, the authority's word is taken, and nobody else's (TIME-1)" {
    // Linux only: it binds a loopback socket and asks it. `bind` wants a link by name and loopback is `lo`;
    // asking nothing of the clock hardware, which only a machine has.
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, 5);
    const authority = try Ed25519.KeyPair.generateDeterministic(seed);
    @memset(&seed, 6);
    const impostor = try Ed25519.KeyPair.generateDeterministic(seed);
    const entry = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const other = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    const t: i64 = timeattest.unixFromCivil(2026, 10, 5, 12, 0, 7);

    // the authority answers, and its word is taken: the time, who said it, and the line as kept
    const srv = try loopbackServer(authority, t, 1);
    defer _ = linux.close(srv.fd);
    switch (ask(0x7F000001, srv.port, entry, authority.public_key, 2, 1000)) {
        .answered => |a| {
            try std.testing.expectEqual(t, a.t);
            try std.testing.expectEqual(timeattest.Verdict.ok, timeattest.verify(a.line[0..a.len], authority.public_key));
        },
        else => return error.TestUnexpectedResult,
    }
    srv.thread.join();

    // an impostor answers the same question: the asker holds the AUTHORITY's key, so the answer is refused
    const bad = try loopbackServer(impostor, t, 1);
    defer _ = linux.close(bad.fd);
    switch (ask(0x7F000001, bad.port, entry, authority.public_key, 1, 1000)) {
        .refused => |v| try std.testing.expectEqual(timeattest.Verdict.wrong_authority, v),
        else => return error.TestUnexpectedResult,
    }
    bad.thread.join();

    // the authority's own word about ANOTHER entry is not an answer to this question, and is not taken
    const fd = try bind(0x7F000001, 0, "lo");
    defer _ = linux.close(fd);
    var wl: linux.sockaddr.in = undefined;
    var wlen: linux.socklen_t = @sizeOf(linux.sockaddr.in);
    try std.testing.expectEqual(linux.E.SUCCESS, linux.E.init(linux.getsockname(fd, @ptrCast(&wl), &wlen)));
    const th = try std.Thread.spawn(.{}, serveOtherEntry, .{ fd, authority, t, other });
    switch (ask(0x7F000001, std.mem.bigToNative(u16, wl.port), entry, authority.public_key, 1, 1000)) {
        .wrong_entry => {},
        else => return error.TestUnexpectedResult,
    }
    th.join();

    // the authority's GENUINE answer with twenty line ends after it is not that statement, and is longer than the
    // buffer a statement is kept in: it is refused, and PID 1, which asks, is not taken down by reading it
    const fd2 = try bind(0x7F000001, 0, "lo");
    defer _ = linux.close(fd2);
    var wl2: linux.sockaddr.in = undefined;
    var wlen2: linux.socklen_t = @sizeOf(linux.sockaddr.in);
    try std.testing.expectEqual(linux.E.SUCCESS, linux.E.init(linux.getsockname(fd2, @ptrCast(&wl2), &wlen2)));
    const th2 = try std.Thread.spawn(.{}, serveRespelled, .{ fd2, authority, t });
    switch (ask(0x7F000001, std.mem.bigToNative(u16, wl2.port), entry, authority.public_key, 1, 1000)) {
        .refused => |v| try std.testing.expectEqual(timeattest.Verdict.malformed, v),
        else => return error.TestUnexpectedResult,
    }
    th2.join();

    // nobody listening: silence in every try, which is a true state and not an error
    const dead = try bind(0x7F000001, 0, "lo");
    var local: linux.sockaddr.in = undefined;
    var len: linux.socklen_t = @sizeOf(linux.sockaddr.in);
    try std.testing.expectEqual(linux.E.SUCCESS, linux.E.init(linux.getsockname(dead, @ptrCast(&local), &len)));
    const dead_port = std.mem.bigToNative(u16, local.port);
    switch (ask(0x7F000001, dead_port, entry, authority.public_key, 2, 100)) {
        .silent => {},
        else => return error.TestUnexpectedResult,
    }
    _ = linux.close(dead);
}
