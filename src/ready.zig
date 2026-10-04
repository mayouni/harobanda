//! The readiness adapter (SRV-2): a program's word that it is serving, said for it.
//!
//! A daemon on this floor says it is serving by creating the path its SERVICE
//! declares as READY, and says it is serving STILL by refreshing that path
//! inside HEALTH's window (SRV-1, HLT-1). A program written for this floor
//! does that itself. A program written for the world does not: RingServ
//! answers `/health` and writes no file.
//!
//! `harb ready` is the program a world runs in its place. It starts the server,
//! asks the server's own URL on a rhythm, and creates the path when the answer
//! is a 200 and rewrites it only while the answer stays a 200. It is the
//! readiness probe of every other supervisor, with the one difference that the
//! floor already measures the word: PID 1 sees the path appear, and reads its
//! age against the window.
//!
//! ```
//! harb ready <ready-path> <a.b.c.d:port> [--url /health] [--every N]
//!            -- <program> [args...]
//! ```
//!
//! ## What it does not say
//!
//! It is silent while it works. PID 1 already prints that the path exists
//! (`boot: <name> -- ready (<path>)`), and a line of its own would race that
//! one for the console: a transcript whose order depends on which process
//! reaches it first is a margin, not a fixture (BDG-1). It speaks only when it
//! cannot do its job -- the program would not start, the path cannot be
//! written -- and then it says so once, with its own name in front.
//!
//! ## What it does not do
//!
//! It does not delete the path when the program dies. A world that dies and is
//! restarted inside its window keeps its health: the path ages, the
//! restarted adapter refreshes it, and nobody is told a thing. One that is
//! not restarted in time goes stale and stays stale (HLT-1), which is the
//! right answer for a world that did not come back.
//!
//! It does not make `/health` mean more than it does. `/health` on RingServ
//! never enters the Ring VM (docs/FUSION.md: 0.18 ms), so a worker wedged in
//! the VM would not be seen; that is the server's to grow, and the probe asks
//! whatever URL it is told.
//!
//! It does not retire. When a server says it is serving by itself -- a
//! `--ready-file` of its own -- the pack changes one line and this verb is
//! unused, which is the point of keeping it a verb and not a part of PID 1.
//!
//! It is a Linux act: it forks, signals and opens a TCP socket, and the one
//! way to prove it is a boot (the pinned transcript of a pack that uses it).

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");

pub const default_url = "/health";
pub const default_every: u32 = 1;

/// What the command line asked for.
pub const Spec = struct {
    ready_path: []const u8,
    ip: u32,
    port: u16,
    url: []const u8,
    every: u32,
    /// the program and its arguments, as the world would have run it itself
    argv: []const []const u8,
};

/// Read a command line (after the verb): `<ready-path> <a.b.c.d:port>
/// [--url /p] [--every N] -- <program> [args...]`.
pub fn parse(arena: std.mem.Allocator, args: []const []const u8) error{ Refused, OutOfMemory }!Spec {
    var sep: ?usize = null;
    for (args, 0..) |a, i| if (std.mem.eql(u8, a, "--")) {
        sep = i;
        break;
    };
    const cut = sep orelse return error.Refused;
    const head = args[0..cut];
    const argv = args[cut + 1 ..];
    if (argv.len == 0) return error.Refused;
    if (head.len < 2) return error.Refused;

    const ready_path = head[0];
    if (ready_path.len == 0 or ready_path[0] != '/') return error.Refused;

    const colon = std.mem.lastIndexOfScalar(u8, head[1], ':') orelse return error.Refused;
    const ip = machine.parseIpv4(head[1][0..colon]) orelse return error.Refused;
    const port = std.fmt.parseInt(u16, head[1][colon + 1 ..], 10) catch return error.Refused;
    if (port == 0) return error.Refused;

    var url: []const u8 = default_url;
    var every: u32 = default_every;
    var i: usize = 2;
    while (i < head.len) : (i += 1) {
        if (std.mem.eql(u8, head[i], "--url") and i + 1 < head.len) {
            i += 1;
            url = head[i];
            if (url.len == 0 or url[0] != '/') return error.Refused;
        } else if (std.mem.eql(u8, head[i], "--every") and i + 1 < head.len) {
            i += 1;
            every = std.fmt.parseInt(u32, head[i], 10) catch return error.Refused;
            if (every == 0 or every > 3600) return error.Refused;
        } else return error.Refused;
    }

    const copy = try arena.alloc([]const u8, argv.len);
    for (argv, 0..) |a, k| copy[k] = a;
    return .{ .ready_path = ready_path, .ip = ip, .port = port, .url = url, .every = every, .argv = copy };
}

/// Is this the start of an HTTP answer whose status is 200? Nothing else is
/// serving: a 404 is a server that is up and a service that is not the one
/// asked, a 5xx is a server that cannot, and a refusal to connect is no server.
pub fn statusOk(answer: []const u8) bool {
    // "HTTP/1.x 200"
    if (answer.len < 12) return false;
    if (!std.mem.startsWith(u8, answer, "HTTP/1.")) return false;
    if (answer[8] != ' ') return false;
    return std.mem.eql(u8, answer[9..12], "200") and (answer.len == 12 or answer[12] == ' ' or answer[12] == '\r' or answer[12] == '\n');
}

/// The request it sends, in the buffer the caller gives. HTTP/1.0 and a closed
/// connection: the answer is one status line and the probe wants nothing else.
pub fn request(buf: []u8, url: []const u8, host: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "GET {s} HTTP/1.0\r\nHost: {s}\r\nConnection: close\r\nUser-Agent: harb-ready\r\n\r\n", .{ url, host }) catch null;
}

/// The exit status a world's parent reads for how a child ended.
pub fn exitCode(status: u32) u8 {
    const W = std.posix.W;
    if (W.IFEXITED(status)) return W.EXITSTATUS(status);
    if (W.IFSIGNALED(status)) return @intCast(128 + @as(u32, W.TERMSIG(status)));
    return 1;
}

/// Run it: the whole verb. Returns what `harb` exits with.
pub fn run(gpa: std.mem.Allocator, args: []const []const u8, out: *std.Io.Writer) !u8 {
    if (builtin.os.tag != .linux) {
        try out.print("ready: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
        return 2;
    }
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const spec = parse(arena_state.allocator(), args) catch |e| switch (e) {
        error.Refused => {
            try out.print("harb: ready <ready-path> <a.b.c.d:port> [--url /health] [--every N] -- <program> [args...]\n", .{});
            return 1;
        },
        else => return e,
    };
    try out.flush();
    return runLinux(gpa, spec);
}

var got_term = std.atomic.Value(bool).init(false);

fn onTerm(_: c_int) callconv(.c) void {
    got_term.store(true, .release);
}

fn runLinux(gpa: std.mem.Allocator, spec: Spec) !u8 {
    const posix = std.posix;
    const sa = posix.Sigaction{
        .handler = .{ .handler = onTerm },
        .mask = posix.sigemptyset(),
        .flags = 0,
    };
    posix.sigaction(posix.SIG.TERM, &sa, null);

    var child = std.process.Child.init(spec.argv, gpa);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    child.spawn() catch |e| {
        sayErr("ready: cannot start {s}: {s}\n", .{ spec.argv[0], @errorName(e) });
        return 127;
    };
    // `spawn` returns once the child exists; whether its exec worked is only
    // reported here (Zig 0.15 says so on `waitForSpawn`). Without this a
    // program that cannot start looks like one that started and died with 1.
    child.waitForSpawn() catch |e| {
        sayErr("ready: cannot start {s}: {s}\n", .{ spec.argv[0], @errorName(e) });
        _ = posix.waitpid(child.id, 0); // the child that failed its exec is a zombie until read
        return 127;
    };

    var host_buf: [24]u8 = undefined;
    const host = std.fmt.bufPrint(&host_buf, "{d}.{d}.{d}.{d}", .{ spec.ip >> 24, (spec.ip >> 16) & 255, (spec.ip >> 8) & 255, spec.ip & 255 }) catch unreachable;

    var warned_write = false;
    var termed = false;
    var ticks: u32 = 0;
    const per_probe: u32 = spec.every * 4; // the loop turns every 250 ms
    while (true) {
        const r = posix.waitpid(child.id, posix.W.NOHANG);
        if (r.pid != 0) return exitCode(r.status);

        if (got_term.load(.acquire) and !termed) {
            termed = true;
            posix.kill(child.id, posix.SIG.TERM) catch {};
        }
        if (ticks % per_probe == 0 and probe(spec, host)) {
            touch(spec.ready_path) catch |e| {
                if (!warned_write) {
                    warned_write = true;
                    sayErr("ready: {s} answers, and {s} cannot be written: {s}\n", .{ spec.url, spec.ready_path, @errorName(e) });
                }
            };
        }
        ticks +%= 1;
        std.Thread.sleep(250 * std.time.ns_per_ms);
    }
}

fn sayErr(comptime fmt: []const u8, args: anytype) void {
    var buf: [256]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, fmt, args) catch return;
    _ = std.posix.write(2, s) catch {};
}

/// Create the path, or rewrite it: its modification time is the word PID 1
/// reads against the window.
fn touch(path: []const u8) !void {
    var f = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer f.close();
    try f.writeAll("serving\n");
}

/// Ask the URL once and say whether the answer was a 200. Every failure is a
/// no: a program that is not listening yet is not serving yet.
fn probe(spec: Spec, host: []const u8) bool {
    const l = std.os.linux;
    const rc_sock = l.socket(l.AF.INET, l.SOCK.STREAM | l.SOCK.CLOEXEC, 0);
    if (l.E.init(rc_sock) != .SUCCESS) return false;
    const fd: i32 = @intCast(rc_sock);
    defer _ = l.close(fd);
    const tv: l.timeval = .{ .sec = 1, .usec = 0 };
    _ = l.setsockopt(fd, l.SOL.SOCKET, l.SO.RCVTIMEO, @ptrCast(&tv), @sizeOf(l.timeval));
    _ = l.setsockopt(fd, l.SOL.SOCKET, l.SO.SNDTIMEO, @ptrCast(&tv), @sizeOf(l.timeval));
    var sa = std.posix.sockaddr.in{
        .family = l.AF.INET,
        .port = std.mem.nativeToBig(u16, spec.port),
        .addr = std.mem.nativeToBig(u32, spec.ip),
        .zero = [_]u8{0} ** 8,
    };
    if (l.E.init(l.connect(fd, @ptrCast(&sa), @sizeOf(@TypeOf(sa)))) != .SUCCESS) return false;
    var req_buf: [256]u8 = undefined;
    const req = request(&req_buf, spec.url, host) orelse return false;
    if (l.E.init(l.write(fd, req.ptr, req.len)) != .SUCCESS) return false;
    var ans: [64]u8 = undefined;
    const n = l.read(fd, &ans, ans.len);
    if (l.E.init(n) != .SUCCESS) return false;
    return statusOk(ans[0..n]);
}

// ---- judged beside the code ----------------------------------------------

test "a command line is read: path, address, the URL and the rhythm, then the program" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const a = [_][]const u8{ "/run/s.ready", "127.0.0.1:8210", "--every", "2", "--url", "/up", "--", "/ringserv", "run", "/app/app.ring" };
    const s = try parse(arena_state.allocator(), &a);
    try t.expectEqualStrings("/run/s.ready", s.ready_path);
    try t.expectEqual(@as(u32, 0x7f000001), s.ip);
    try t.expectEqual(@as(u16, 8210), s.port);
    try t.expectEqualStrings("/up", s.url);
    try t.expectEqual(@as(u32, 2), s.every);
    try t.expectEqual(@as(usize, 3), s.argv.len);
    try t.expectEqualStrings("/ringserv", s.argv[0]);
    // the defaults are the documented ones
    const b = [_][]const u8{ "/run/s.ready", "10.0.2.15:80", "--", "/x" };
    const d = try parse(arena_state.allocator(), &b);
    try t.expectEqualStrings(default_url, d.url);
    try t.expectEqual(default_every, d.every);
}

test "a command line that cannot be read is refused, each for one reason" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cases = [_][]const []const u8{
        &.{ "/r", "127.0.0.1:80", "/x" }, // no separator
        &.{ "/r", "127.0.0.1:80", "--" }, // no program
        &.{ "/r", "--", "/x" }, // no address
        &.{ "r", "127.0.0.1:80", "--", "/x" }, // a relative ready path
        &.{ "/r", "localhost:80", "--", "/x" }, // a name, not an address
        &.{ "/r", "127.0.0.1:0", "--", "/x" }, // port zero
        &.{ "/r", "127.0.0.1:99999", "--", "/x" }, // a port no one has
        &.{ "/r", "127.0.0.1", "--", "/x" }, // no port
        &.{ "/r", "127.0.0.1:80", "--every", "0", "--", "/x" }, // a rhythm of never
        &.{ "/r", "127.0.0.1:80", "--url", "health", "--", "/x" }, // a URL with no root
        &.{ "/r", "127.0.0.1:80", "--nope", "1", "--", "/x" }, // an option nobody has
    };
    for (cases) |c| try t.expectError(error.Refused, parse(arena, c));
}

test "only a 200 is serving" {
    const t = std.testing;
    try t.expect(statusOk("HTTP/1.1 200 OK\r\ncontent-type: application/json\r\n"));
    try t.expect(statusOk("HTTP/1.0 200 OK\r\n"));
    try t.expect(statusOk("HTTP/1.1 200\r\n"));
    // up, but not serving what was asked; or unable; or something else entirely
    try t.expect(!statusOk("HTTP/1.1 404 Not Found\r\n"));
    try t.expect(!statusOk("HTTP/1.1 500 Internal Server Error\r\n"));
    try t.expect(!statusOk("HTTP/1.1 503 Service Unavailable\r\n"));
    try t.expect(!statusOk("HTTP/1.1 2000 OK\r\n"));
    try t.expect(!statusOk("HTTP/1.1 20\r\n"));
    try t.expect(!statusOk("SSH-2.0-OpenSSH_9.6\r\n"));
    try t.expect(!statusOk(""));
}

test "the request asks for the URL and closes" {
    const t = std.testing;
    var buf: [256]u8 = undefined;
    const r = request(&buf, "/health", "127.0.0.1").?;
    try t.expect(std.mem.startsWith(u8, r, "GET /health HTTP/1.0\r\n"));
    try t.expect(std.mem.indexOf(u8, r, "Host: 127.0.0.1\r\n") != null);
    try t.expect(std.mem.indexOf(u8, r, "Connection: close\r\n") != null);
    try t.expect(std.mem.endsWith(u8, r, "\r\n\r\n"));
    // a buffer too small for it says so rather than cutting it
    var tiny: [8]u8 = undefined;
    try t.expect(request(&tiny, "/health", "127.0.0.1") == null);
}
