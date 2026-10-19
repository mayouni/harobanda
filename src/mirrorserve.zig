// mirrorserve.zig -- the acts of the mirror seat that need a kernel (MIR-1, STZ-OS-RULING-19).
//
// mirror.zig is the messages, the manifest and its judgement, and needs nothing. This is what touches the machine:
// a socket a source gives a copy on, the walk of a world's directory, the files streamed, and on the other end the
// socket a copy is asked of, the files written and read back, and the swap that makes a copy the copy. It is Linux
// code, reached only from PID 1 (`harb mirror` is mirroraudit.zig's, and needs no kernel).
//
// THE SOURCE gives the files of ONE directory to ONE device. PID 1 binds the socket before it forks (so that "this
// machine could not become the source it declared itself" is said by the machine, in order, in the transcript that
// is judged), and the child accepts one connection at a time. A connection is asked who it is before it is told
// anything: the source sends a challenge, and only a request signed by the key the machine was declared to give the
// copy to, over THAT challenge, is answered -- everything else is closed on without a word, because an asker that
// has not proved it is the device has been told nothing it could use. The device that has is told the truth,
// including why it is being refused.
//
// THE WALK IS THE DANGEROUS PART. The floor reads a world's directory as root, and the world owns that directory
// (OWN-1): it can put anything in it. A floor that followed a link there would hand the machine's own key to the
// link in the first copy anyone pulled. So the walk follows NO link anywhere -- every component below the root is
// opened with O_NOFOLLOW from a descriptor, so a name that is a link is a refusal and not a way somewhere else --
// and it gives a file only if the WORLD owns it: a hard link to a file of the machine's is a regular file with
// another owner, and is refused for it. A pipe, a socket and a device are refused; so is a directory on another
// filesystem than the one it lies in. Whatever is wrong with ONE name makes the whole directory unmirrorable, and
// says which: fail closed, never a copy with a hole in it that verifies.
//
// THE PULLER asks every `every` seconds. It receives the files into a staging place beside the copy, holds each to
// the digest the SIGNED manifest states while it writes it, reads the whole of what it wrote back against the
// manifest, and only then swaps the staging place in for the copy it has. The swap is renames and nothing else, and
// a power cut at any point between two of them leaves a state the next pull knows how to finish or undo (`recover`):
// the machine always has the last COMPLETE copy, or none. Beside the copy it keeps the signed manifest it was
// verified against (the commit record: a reader with the source's public key can verify the copy forever, with no
// secret) and one line about the last attempt, so that "nobody answered" and "an answer was refused" are told apart
// from "everything is as it was".
//
// BOTH CHILDREN are PID 1's own code in a process that is forked and never exec'd, so close-on-exec does not reach
// them: `timeserve.closeInherited` is what they are given instead (the hardware watchdog above all, WDG-1). They
// say nothing: a server that wrote to the console at the pace of whoever asked would write a different transcript
// every boot. What they did is told by the line beside the copy and by `harb mirror check`.

const std = @import("std");
const builtin = @import("builtin");
const Ed25519 = std.crypto.sign.Ed25519;
const Sha256 = std.crypto.hash.sha2.Sha256;
const machine = @import("machine.zig");
const mirror = @import("mirror.zig");
const journal = @import("journal.zig");
const timeserve = @import("timeserve.zig");

const linux = std.os.linux;
const posix = std.posix;

// ---- the limits of patience, in one place ---------------------------------------------------------------

/// From a connection to a request that verifies: an asker that has not shown who it is by then is closed on.
pub const auth_ms: i64 = 15_000;
/// How long a puller waits for a source to count and hash a directory before the first line of its answer.
pub const listing_ms: i64 = 300_000;
/// How long either end waits for the next bytes of a file before it gives the copy up.
pub const stall_ms: i64 = 30_000;
/// How long a puller waits for a connection to be made.
pub const connect_ms: i64 = 5_000;
/// How deep a directory may be nested and still be given: a limit on the walk, not on any real tree.
pub const max_depth: usize = 64;

// ---- time, and a connection with a patience -------------------------------------------------------------

fn nowMs() i64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(linux.CLOCK.MONOTONIC, &ts);
    return @as(i64, @intCast(ts.sec)) * 1000 + @divTrunc(@as(i64, @intCast(ts.nsec)), 1_000_000);
}

/// Whether `fd` is ready for `events` within `ms`: false is a timeout.
fn ready(fd: i32, events: i16, ms: i64) bool {
    if (ms <= 0) return false;
    var fds = [1]linux.pollfd{.{ .fd = fd, .events = events, .revents = 0 }};
    const wait: i32 = @intCast(@min(ms, 60_000));
    const rc = linux.poll(&fds, 1, wait);
    if (linux.E.init(rc) != .SUCCESS) return false;
    return rc == 1 and fds[0].revents != 0;
}

/// A connected socket, read and written with a deadline on every wait. The sockets are non-blocking and every wait is a
/// poll, so that a peer that stops answering costs the time it was given and not the machine's.
const Conn = struct {
    fd: i32,
    buf: [16384]u8 = undefined,
    pos: usize = 0,
    len: usize = 0,

    const Error = error{ Timeout, Closed, TooLong, Io };

    /// Bytes from the socket, waiting at most until `deadline` (an absolute time of `nowMs`).
    fn fill(self: *Conn, deadline: i64) Error!void {
        if (self.pos == self.len) {
            self.pos = 0;
            self.len = 0;
        }
        while (true) {
            const left = deadline - nowMs();
            if (left <= 0) return error.Timeout;
            if (!ready(self.fd, linux.POLL.IN, left)) {
                if (nowMs() >= deadline) return error.Timeout;
                continue;
            }
            const r = linux.recvfrom(self.fd, self.buf[self.len..].ptr, self.buf.len - self.len, 0, null, null);
            switch (linux.E.init(r)) {
                .SUCCESS => {},
                .AGAIN, .INTR => continue,
                else => return error.Io,
            }
            if (r == 0) return error.Closed;
            self.len += r;
            return;
        }
    }

    /// One line, without its end, at most `out.len` bytes of it.
    fn readLine(self: *Conn, out: []u8, deadline: i64) Error![]const u8 {
        while (true) {
            if (std.mem.indexOfScalar(u8, self.buf[self.pos..self.len], '\n')) |nl| {
                if (nl > out.len) return error.TooLong;
                @memcpy(out[0..nl], self.buf[self.pos .. self.pos + nl]);
                self.pos += nl + 1;
                return out[0..nl];
            }
            if (self.len - self.pos > out.len) return error.TooLong;
            // the room for the rest of the line: what is buffered moves to the front
            if (self.pos > 0) {
                std.mem.copyForwards(u8, self.buf[0 .. self.len - self.pos], self.buf[self.pos..self.len]);
                self.len -= self.pos;
                self.pos = 0;
            }
            try self.fill(deadline);
        }
    }

    /// Exactly `dst.len` bytes, each wait bounded by `patience` and the whole by nothing but it.
    fn readExact(self: *Conn, dst: []u8, patience: i64) Error!void {
        var got: usize = 0;
        while (got < dst.len) {
            if (self.pos == self.len) try self.fill(nowMs() + patience);
            const n = @min(self.len - self.pos, dst.len - got);
            @memcpy(dst[got .. got + n], self.buf[self.pos .. self.pos + n]);
            self.pos += n;
            got += n;
        }
    }

    /// All of `bytes`, no wait longer than `patience`. MSG_NOSIGNAL: a peer that went away is an error here and not a
    /// signal that ends the process.
    fn sendAll(self: *Conn, bytes: []const u8, patience: i64) Error!void {
        var sent: usize = 0;
        while (sent < bytes.len) {
            const r = linux.sendto(self.fd, bytes[sent..].ptr, bytes.len - sent, linux.MSG.NOSIGNAL, null, 0);
            switch (linux.E.init(r)) {
                .SUCCESS => sent += r,
                .AGAIN, .INTR => {
                    if (!ready(self.fd, linux.POLL.OUT, patience)) return error.Timeout;
                },
                .PIPE, .CONNRESET => return error.Closed,
                else => return error.Io,
            }
        }
    }

    fn sendLine(self: *Conn, line: []const u8, patience: i64) Error!void {
        try self.sendAll(line, patience);
        try self.sendAll("\n", patience);
    }
};

fn sockIn(ip: u32, port: u16) linux.sockaddr.in {
    return .{
        .family = linux.AF.INET,
        .port = std.mem.nativeToBig(u16, port),
        .addr = std.mem.nativeToBig(u32, ip),
        .zero = [_]u8{0} ** 8,
    };
}

// ---- the source: a socket, a walk, and the loop that gives --------------------------------------------

/// A TCP socket listening on `ip:port` of the link `iface`, and on no other link. Taken by PID 1 before it forks the loop.
pub fn listen(ip: u32, port: u16, iface: []const u8) !i32 {
    const rc = linux.socket(linux.AF.INET, linux.SOCK.STREAM | linux.SOCK.CLOEXEC, 0);
    if (linux.E.init(rc) != .SUCCESS) return error.NoSocket;
    const fd: i32 = @intCast(rc);
    errdefer _ = linux.close(fd);
    const one: c_int = 1;
    _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.REUSEADDR, std.mem.asBytes(&one).ptr, @sizeOf(c_int));
    // a link is named on a machine; a test on a host names none, and a socket with none is bound to the address alone
    if (iface.len > 0 and linux.E.init(linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.BINDTODEVICE, iface.ptr, @intCast(iface.len))) != .SUCCESS) return error.NoSuchLink;
    const local = sockIn(ip, port);
    if (linux.E.init(linux.bind(fd, @ptrCast(&local), @sizeOf(linux.sockaddr.in))) != .SUCCESS) return error.BindRefused;
    if (linux.E.init(linux.listen(fd, 4)) != .SUCCESS) return error.ListenRefused;
    return fd;
}

/// The port a listening socket was given, for a socket that was asked for port 0 (a test: the kernel picks a free one).
pub fn boundPort(fd: i32) !u16 {
    var local: linux.sockaddr.in = undefined;
    var len: linux.socklen_t = @sizeOf(linux.sockaddr.in);
    if (linux.E.init(linux.getsockname(fd, @ptrCast(&local), &len)) != .SUCCESS) return error.NoName;
    return std.mem.bigToNative(u16, local.port);
}

/// What a walk of a directory comes to: the entries, sorted and with their digests, or why it cannot be given.
pub const Scan = struct {
    entries: []mirror.Entry = &.{},
    problem: ?[]const u8 = null,
};

const open_dir: posix.O = .{ .ACCMODE = .RDONLY, .DIRECTORY = true, .NOFOLLOW = true, .CLOEXEC = true };
const open_file: posix.O = .{ .ACCMODE = .RDONLY, .NOFOLLOW = true, .NONBLOCK = true, .CLOEXEC = true };

fn fdcwd() posix.fd_t {
    return @as(posix.fd_t, linux.AT.FDCWD);
}

/// The directory at `path` (absolute), opened component by component with no link followed anywhere.
pub fn openRoot(path: []const u8) !posix.fd_t {
    if (path.len < 2 or path[0] != '/') return error.BadPath;
    var cur = try posix.openat(fdcwd(), "/", .{ .ACCMODE = .RDONLY, .DIRECTORY = true, .CLOEXEC = true }, 0);
    var it = std.mem.splitScalar(u8, path[1..], '/');
    while (it.next()) |comp| {
        const next = posix.openat(cur, comp, open_dir, 0) catch |e| {
            posix.close(cur);
            return e;
        };
        posix.close(cur);
        cur = next;
    }
    return cur;
}

/// A file at `rel` below `root`, opened with no link followed in any component.
fn openFileRel(root: posix.fd_t, rel: []const u8) !posix.fd_t {
    var cur: posix.fd_t = root;
    var own = false;
    errdefer if (own) posix.close(cur);
    var rest = rel;
    while (std.mem.indexOfScalar(u8, rest, '/')) |slash| {
        const next = try posix.openat(cur, rest[0..slash], open_dir, 0);
        if (own) posix.close(cur);
        cur = next;
        own = true;
        rest = rest[slash + 1 ..];
    }
    const fd = try posix.openat(cur, rest, open_file, 0);
    if (own) posix.close(cur);
    return fd;
}

const Walker = struct {
    alloc: std.mem.Allocator,
    uid: u32,
    dev: u64,
    list: std.ArrayList(mirror.Entry) = .{},
    bytes: u64 = 0,
    problem: ?[]const u8 = null,

    const Stop = error{ Refused, OutOfMemory };

    fn refuse(self: *Walker, comptime fmt: []const u8, args: anytype) Stop {
        if (self.problem == null) self.problem = std.fmt.allocPrint(self.alloc, fmt, args) catch "the directory cannot be given";
        return error.Refused;
    }

    fn walk(self: *Walker, fd: posix.fd_t, prefix: []const u8, depth: usize) Stop!void {
        if (depth > max_depth) return self.refuse("{s} is nested deeper than {d} directories", .{ prefix, max_depth });
        var d = std.fs.Dir{ .fd = fd };
        var it = d.iterate();
        while (true) {
            const ent = (it.next() catch |e| return self.refuse("{s} could not be listed: {s}", .{ if (prefix.len == 0) "the directory" else prefix, @errorName(e) })) orelse break;
            const rel = if (prefix.len == 0) try self.alloc.dupe(u8, ent.name) else try std.fmt.allocPrint(self.alloc, "{s}/{s}", .{ prefix, ent.name });
            if (!mirror.safeRelPath(rel)) return self.refuse("a name in {s} cannot be carried in a listing (a control byte, a backslash, or too long)", .{if (prefix.len == 0) "the directory" else prefix});
            if (self.list.items.len >= mirror.max_entries) return self.refuse("more than {d} entries: a listing carries at most that", .{mirror.max_entries});
            const st = posix.fstatat(fd, ent.name, linux.AT.SYMLINK_NOFOLLOW) catch |e| return self.refuse("{s} could not be examined: {s}", .{ rel, @errorName(e) });
            // a link is named as a link whoever made it: the world may well have, and the sentence that helps is
            // the one that says what it is; the owner is asked of everything else
            if (linux.S.ISLNK(st.mode)) return self.refuse("{s} is a symbolic link: a copy holds files and directories, and a link is a way to somewhere else", .{rel});
            if (st.uid != self.uid) return self.refuse("{s} belongs to uid {d} and the world's is {d}: the floor gives only what the world owns", .{ rel, st.uid, self.uid });
            if (linux.S.ISDIR(st.mode)) {
                if (@as(u64, @intCast(st.dev)) != self.dev) return self.refuse("{s} is on another filesystem than the directory it lies in", .{rel});
                try self.list.append(self.alloc, .{ .kind = .dir, .path = rel });
                const child = posix.openat(fd, ent.name, open_dir, 0) catch |e| return self.refuse("{s} could not be opened: {s}", .{ rel, @errorName(e) });
                defer posix.close(child);
                try self.walk(child, rel, depth + 1);
            } else if (linux.S.ISREG(st.mode)) {
                const ffd = posix.openat(fd, ent.name, open_file, 0) catch |e| return self.refuse("{s} could not be opened: {s}", .{ rel, @errorName(e) });
                defer posix.close(ffd);
                // the file that was opened is the file that was examined, and still the world's
                const st2 = posix.fstat(ffd) catch |e| return self.refuse("{s} could not be examined: {s}", .{ rel, @errorName(e) });
                if (!linux.S.ISREG(st2.mode) or st2.ino != st.ino or st2.dev != st.dev or st2.uid != self.uid) return self.refuse("{s} changed while it was being examined", .{rel});
                // what a copy can still carry is what a file may be: one longer is refused before it is read, and one that grows
                // while it is read is refused when it passes that -- the world owns the file, and the floor reads it as root
                const room = mirror.max_total_bytes - self.bytes;
                if (@as(u64, @intCast(st2.size)) > room) return self.refuse("{s} is longer than the {d} bytes a copy still has room for: a copy carries at most {d} bytes of files", .{ rel, room, mirror.max_total_bytes });
                const h = mirror.hashFileLimit(std.fs.File{ .handle = ffd }, room) catch |e| switch (e) {
                    error.FileTooLarge => return self.refuse("{s} grew past the {d} bytes a copy still has room for while it was read", .{ rel, room }),
                    else => return self.refuse("{s} could not be read: {s}", .{ rel, @errorName(e) }),
                };
                self.bytes += h.size;
                try self.list.append(self.alloc, .{ .kind = .file, .path = rel, .size = h.size, .digest = h.digest });
            } else return self.refuse("{s} is not a file or a directory (a pipe, a socket or a device)", .{rel});
        }
    }
};

/// Walk the world's directory `root` (open, no link followed to reach it) and say what it holds, every file hashed.
pub fn scan(alloc: std.mem.Allocator, root: posix.fd_t, uid: u32) Scan {
    const rst = posix.fstat(root) catch |e| return .{ .problem = std.fmt.allocPrint(alloc, "the directory could not be examined: {s}", .{@errorName(e)}) catch "the directory cannot be given" };
    var w = Walker{ .alloc = alloc, .uid = uid, .dev = @intCast(rst.dev) };
    if (rst.uid != uid) return .{ .problem = std.fmt.allocPrint(alloc, "the directory belongs to uid {d} and the world's is {d}: the floor gives only what the world owns", .{ rst.uid, uid }) catch "the directory cannot be given" };
    w.walk(root, "", 0) catch |e| switch (e) {
        error.Refused => return .{ .problem = w.problem },
        error.OutOfMemory => return .{ .problem = "out of memory while the directory was listed" },
    };
    mirror.sortEntries(w.list.items);
    if (mirror.entriesProblem(alloc, w.list.items) catch null) |why| return .{ .problem = why };
    return .{ .entries = w.list.items };
}

/// Words that are safe to put on the wire in a refusal: one line, no control byte.
fn safeWords(out: []u8, text: []const u8) []const u8 {
    const n = @min(out.len, text.len);
    for (text[0..n], 0..) |c, i| out[i] = if (c < 0x20 or c == 0x7f) '?' else c;
    return out[0..n];
}

/// Everything a source says to one connection, and everything it does.
fn handle(conn: *Conn, alloc: std.mem.Allocator, pair: Ed25519.KeyPair, of: machine.MirrorOf, allowed: Ed25519.PublicKey) void {
    var nonce_a: [mirror.nonce_len]u8 = undefined;
    std.crypto.random.bytes(&nonce_a);
    var cb: [mirror.max_line]u8 = undefined;
    const ch = mirror.challenge(&cb, nonce_a) catch return;
    const t0 = nowMs();
    conn.sendLine(ch, auth_ms) catch return;
    var rb: [mirror.max_line + 2]u8 = undefined;
    const line = conn.readLine(&rb, t0 + auth_ms) catch return;
    // nothing is said to an asker that is not the device: silence, and the close
    const req = mirror.verifyRequest(line, allowed, nonce_a) orelse return;

    const root = openRoot(of.dir) catch |e| {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "mirror-refused {s} cannot be opened: {s}", .{ of.dir, @errorName(e) }) catch return;
        conn.sendLine(msg, stall_ms) catch {};
        return;
    };
    defer posix.close(root);
    const sc = scan(alloc, root, of.uid);
    if (sc.problem) |why| {
        var sw: [300]u8 = undefined;
        var buf: [360]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "mirror-refused {s}", .{safeWords(&sw, why)}) catch return;
        conn.sendLine(msg, stall_ms) catch {};
        return;
    }
    const puller_fp = journal.fingerprintOf(req.key);
    const text = mirror.build(alloc, pair, puller_fp, req.b, of.dir, sc.entries) catch return;
    conn.sendAll(text, stall_ms) catch return;

    // the bytes, in the order the signed listing states them, each held to the digest it was signed with as it goes
    var block: [65536]u8 = undefined;
    for (sc.entries) |e| {
        if (e.kind != .file) continue;
        const ffd = openFileRel(root, e.path) catch return;
        defer posix.close(ffd);
        const st = posix.fstat(ffd) catch return;
        if (!linux.S.ISREG(st.mode) or st.uid != of.uid) return;
        var h = Sha256.init(.{});
        var left: u64 = e.size;
        while (left > 0) {
            const want: usize = @intCast(@min(left, block.len));
            const n = posix.read(ffd, block[0..want]) catch return;
            // a file that ended early is no longer the file that was listed: close, and the puller sees a short copy
            if (n == 0) return;
            h.update(block[0..n]);
            conn.sendAll(block[0..n], stall_ms) catch return;
            left -= n;
        }
        var d: [32]u8 = undefined;
        h.final(&d);
        if (!std.mem.eql(u8, &d, &e.digest)) return;
    }
}

/// The source's loop, forked by PID 1: accept one connection, hear it out, close it. It says nothing.
pub fn serve(listen_fd: i32, pair: Ed25519.KeyPair, of: machine.MirrorOf) noreturn {
    const allowed = Ed25519.PublicKey.fromBytes(of.for_key) catch std.process.exit(1);
    while (true) {
        const rc = linux.accept4(listen_fd, null, null, linux.SOCK.NONBLOCK | linux.SOCK.CLOEXEC);
        if (linux.E.init(rc) != .SUCCESS) {
            std.Thread.sleep(100 * std.time.ns_per_ms);
            continue;
        }
        const fd: i32 = @intCast(rc);
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var conn = Conn{ .fd = fd };
        handle(&conn, arena.allocator(), pair, of, allowed);
        arena.deinit();
        _ = linux.close(fd);
    }
}

// ---- the destination: what a pull comes to, and the copy it keeps ------------------------------------

pub const Outcome = union(enum) {
    /// a copy was received, verified against the signed listing, and swapped in
    ok: struct { files: u64, dirs: u64, bytes: u64 },
    /// nobody answered
    silent: []const u8,
    /// the source answered, and would not give: why, in its words
    refused: []const u8,
    /// something answered and it is not the source's word, or the copy it gave did not match the listing it signed
    unverified: []const u8,
    /// this machine could not keep the copy
    failed: []const u8,

    /// The line kept beside the copy and read by `harb mirror check`. Deterministic: no time, no counter.
    pub fn line(self: Outcome, buf: []u8) []const u8 {
        var sw: [300]u8 = undefined;
        return (switch (self) {
            .ok => |o| std.fmt.bufPrint(buf, "ok files={d} dirs={d} bytes={d}", .{ o.files, o.dirs, o.bytes }),
            .silent => |w| std.fmt.bufPrint(buf, "silent {s}", .{safeWords(&sw, w)}),
            .refused => |w| std.fmt.bufPrint(buf, "refused {s}", .{safeWords(&sw, w)}),
            .unverified => |w| std.fmt.bufPrint(buf, "unverified {s}", .{safeWords(&sw, w)}),
            .failed => |w| std.fmt.bufPrint(buf, "failed {s}", .{safeWords(&sw, w)}),
        }) catch "failed (too long to say)";
    }
};

/// `path` with `suffix`: one of the names the floor makes for a copy (`machine.mirror_family`).
fn named(alloc: std.mem.Allocator, into: []const u8, suffix: []const u8) ![]u8 {
    return std.fmt.allocPrint(alloc, "{s}{s}", .{ into, suffix });
}

fn exists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// Finish or undo what a swap that was cut short left, before anything else is done. A swap is these renames in
/// this order: the copy to `.old`, the staging place to the copy, the new record to the record, and then `.old` is
/// removed. Which of them happened is told by which names exist, and every state has one reading:
///
///   the copy is missing and `.old` is there      -> the first rename happened and the second did not: put it back
///   the copy is there, `.manifest.new` is there, and the staging place is not -> the second rename happened and the
///                                                   third did not: finish it (the new record describes the new copy)
///   anything else that is left over               -> a pull that was not finished: remove it, and pull again
pub fn recover(alloc: std.mem.Allocator, into: []const u8) void {
    const cwd = std.fs.cwd();
    const new = named(alloc, into, ".new") catch return;
    const old = named(alloc, into, ".old") catch return;
    const man = named(alloc, into, ".manifest") catch return;
    const man_new = named(alloc, into, ".manifest.new") catch return;
    const last_new = named(alloc, into, ".last.new") catch return;
    if (!exists(into) and exists(old)) cwd.rename(old, into) catch {};
    if (exists(man_new) and !exists(new) and exists(into)) cwd.rename(man_new, man) catch {};
    cwd.deleteTree(new) catch {};
    cwd.deleteFile(man_new) catch {};
    cwd.deleteFile(last_new) catch {};
    if (exists(into)) cwd.deleteTree(old) catch {};
}

fn syncDir(path: []const u8) void {
    const fd = posix.openat(fdcwd(), path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true, .CLOEXEC = true }, 0) catch return;
    defer posix.close(fd);
    posix.fsync(fd) catch {};
}

/// Replace `path` with `bytes`, whole or not at all: written beside it, flushed, renamed over it.
fn replaceFile(alloc: std.mem.Allocator, path: []const u8, bytes: []const u8) !void {
    const tmp = try named(alloc, path, ".new");
    {
        const f = try std.fs.cwd().createFile(tmp, .{ .truncate = true, .mode = 0o600 });
        defer f.close();
        try f.writeAll(bytes);
        try f.sync();
    }
    try std.fs.cwd().rename(tmp, path);
}

/// Say what the last attempt came to, beside the copy. A line that cannot be kept is not worth stopping for.
pub fn record(alloc: std.mem.Allocator, into: []const u8, out: Outcome) void {
    var buf: [400]u8 = undefined;
    const text = std.fmt.allocPrint(alloc, "{s}\n", .{out.line(&buf)}) catch return;
    const last = named(alloc, into, mirror.kept_last_suffix) catch return;
    replaceFile(alloc, last, text) catch return;
    // the rename is in the directory, and a directory is flushed on its own: a line a power cut can take back is a line
    // that says "ok" about a copy it was cut before
    if (std.fs.path.dirnamePosix(into)) |parent| syncDir(parent);
}

/// Ask once. Everything a pull does is here, and it returns what it came to.
pub fn attempt(alloc: std.mem.Allocator, pair: Ed25519.KeyPair, from: machine.MirrorFrom) Outcome {
    const source = Ed25519.PublicKey.fromBytes(from.key) catch return .{ .failed = "MIRROR_KEY is not a public key" };
    const me = journal.fingerprintOf(pair.public_key.toBytes());
    recover(alloc, from.into);
    if (std.fs.path.dirnamePosix(from.into)) |parent| std.fs.cwd().makePath(parent) catch |e| return .{ .failed = std.fmt.allocPrint(alloc, "{s} cannot be made: {s}", .{ parent, @errorName(e) }) catch "the place for the copy cannot be made" };

    // a connection, made without waiting longer than it is worth
    const rc = linux.socket(linux.AF.INET, linux.SOCK.STREAM | linux.SOCK.NONBLOCK | linux.SOCK.CLOEXEC, 0);
    if (linux.E.init(rc) != .SUCCESS) return .{ .failed = "no socket" };
    const fd: i32 = @intCast(rc);
    defer _ = linux.close(fd);
    const peer = sockIn(from.ip, from.port);
    const cr = linux.connect(fd, @ptrCast(&peer), @sizeOf(linux.sockaddr.in));
    switch (linux.E.init(cr)) {
        .SUCCESS => {},
        .INPROGRESS => {
            if (!ready(fd, linux.POLL.OUT, connect_ms)) return .{ .silent = std.fmt.allocPrint(alloc, "nobody answered at {s}", .{from.text}) catch "nobody answered" };
            var soerr: c_int = 0;
            var len: linux.socklen_t = @sizeOf(c_int);
            _ = linux.getsockopt(fd, linux.SOL.SOCKET, linux.SO.ERROR, @ptrCast(&soerr), &len);
            if (soerr != 0) return .{ .silent = std.fmt.allocPrint(alloc, "nobody answered at {s}", .{from.text}) catch "nobody answered" };
        },
        else => return .{ .silent = std.fmt.allocPrint(alloc, "nobody answered at {s}", .{from.text}) catch "nobody answered" },
    }
    var conn = Conn{ .fd = fd };

    // who is asking, and who is answering
    var lb: [mirror.max_line + 2]u8 = undefined;
    const t0 = nowMs();
    const ch = conn.readLine(&lb, t0 + auth_ms) catch return .{ .silent = std.fmt.allocPrint(alloc, "{s} accepted and said nothing", .{from.text}) catch "no challenge" };
    const nonce_a = mirror.parseChallenge(ch) orelse return .{ .unverified = "what answered was not a challenge from a source" };
    var nonce_b: [mirror.nonce_len]u8 = undefined;
    std.crypto.random.bytes(&nonce_b);
    var rq: [mirror.max_line]u8 = undefined;
    const req = mirror.request(&rq, pair, nonce_a, nonce_b) catch return .{ .failed = "the request could not be signed" };
    conn.sendLine(req, auth_ms) catch return .{ .silent = std.fmt.allocPrint(alloc, "{s} closed before it was asked", .{from.text}) catch "closed" };

    // the signed listing: lines up to the signature
    var text: std.ArrayList(u8) = .{};
    var ll: [2048]u8 = undefined;
    var first = true;
    while (true) {
        const deadline = nowMs() + (if (first) listing_ms else stall_ms);
        const l = conn.readLine(&ll, deadline) catch |e| return switch (e) {
            error.Timeout, error.Closed, error.Io => .{ .silent = std.fmt.allocPrint(alloc, "{s} gave no listing", .{from.text}) catch "no listing" },
            error.TooLong => .{ .unverified = "a line of the listing was longer than a line can be" },
        };
        if (first) {
            const refused = "mirror-refused ";
            if (std.mem.startsWith(u8, l, refused)) return .{ .refused = alloc.dupe(u8, l[refused.len..]) catch "refused" };
            first = false;
        }
        if (text.items.len + l.len + 1 > mirror.max_manifest_bytes) return .{ .unverified = "the listing is longer than a listing can be" };
        text.appendSlice(alloc, l) catch return .{ .failed = "out of memory" };
        text.append(alloc, '\n') catch return .{ .failed = "out of memory" };
        if (std.mem.startsWith(u8, l, "sig=")) break;
    }
    const m = switch (mirror.verify(alloc, text.items, source, me, nonce_b)) {
        .ok => |m| m,
        .bad => |v| return .{ .unverified = std.fmt.allocPrint(alloc, "the listing {s}", .{v.words()}) catch "the listing does not verify" },
    };

    // the files, into a place of their own beside the copy
    const new = named(alloc, from.into, ".new") catch return .{ .failed = "out of memory" };
    posix.mkdirat(fdcwd(), new, 0o700) catch |e| return .{ .failed = std.fmt.allocPrint(alloc, "{s} cannot be made: {s}", .{ new, @errorName(e) }) catch "the staging place cannot be made" };
    var keep = false;
    defer if (!keep) std.fs.cwd().deleteTree(new) catch {};
    const stage = posix.openat(fdcwd(), new, .{ .ACCMODE = .RDONLY, .DIRECTORY = true, .CLOEXEC = true }, 0) catch |e| return .{ .failed = std.fmt.allocPrint(alloc, "{s} cannot be opened: {s}", .{ new, @errorName(e) }) catch "the staging place cannot be opened" };
    defer posix.close(stage);

    var block: [65536]u8 = undefined;
    for (m.entries) |e| switch (e.kind) {
        .dir => posix.mkdirat(stage, e.path, 0o700) catch |er| return .{ .failed = std.fmt.allocPrint(alloc, "{s} cannot be made: {s}", .{ e.path, @errorName(er) }) catch "a directory cannot be made" },
        .file => {
            const wfd = posix.openat(stage, e.path, .{ .ACCMODE = .WRONLY, .CREAT = true, .EXCL = true, .NOFOLLOW = true, .CLOEXEC = true }, 0o600) catch |er| return .{ .failed = std.fmt.allocPrint(alloc, "{s} cannot be made: {s}", .{ e.path, @errorName(er) }) catch "a file cannot be made" };
            defer posix.close(wfd);
            var h = Sha256.init(.{});
            var left: u64 = e.size;
            while (left > 0) {
                const want: usize = @intCast(@min(left, block.len));
                conn.readExact(block[0..want], stall_ms) catch return .{ .unverified = std.fmt.allocPrint(alloc, "the source stopped before {s} was complete", .{e.path}) catch "the source stopped" };
                h.update(block[0..want]);
                var done: usize = 0;
                while (done < want) done += posix.write(wfd, block[done..want]) catch |er| return .{ .failed = std.fmt.allocPrint(alloc, "{s} cannot be written: {s}", .{ e.path, @errorName(er) }) catch "a file cannot be written" };
                left -= want;
            }
            var d: [32]u8 = undefined;
            h.final(&d);
            if (!std.mem.eql(u8, &d, &e.digest)) return .{ .unverified = std.fmt.allocPrint(alloc, "{s} does not match the digest the source signed for it", .{e.path}) catch "a file does not match its digest" };
            posix.fsync(wfd) catch {};
        },
    };

    // and what was written is read back from the disk, against the listing, before it is anything
    const sd = std.fs.Dir{ .fd = stage };
    const rep = mirror.verifyCopy(alloc, sd, m) catch |e| return .{ .failed = std.fmt.allocPrint(alloc, "the copy could not be read back: {s}", .{@errorName(e)}) catch "the copy could not be read back" };
    if (rep.problem) |why| return .{ .unverified = std.fmt.allocPrint(alloc, "what was written does not match the listing: {s}", .{why}) catch "what was written does not match the listing" };
    posix.fsync(stage) catch {};

    // the swap
    const old = named(alloc, from.into, ".old") catch return .{ .failed = "out of memory" };
    const man = named(alloc, from.into, mirror.kept_manifest_suffix) catch return .{ .failed = "out of memory" };
    const man_new = named(alloc, from.into, ".manifest.new") catch return .{ .failed = "out of memory" };
    {
        const f = std.fs.cwd().createFile(man_new, .{ .truncate = true, .mode = 0o600 }) catch |e| return .{ .failed = std.fmt.allocPrint(alloc, "{s} cannot be made: {s}", .{ man_new, @errorName(e) }) catch "the record cannot be made" };
        defer f.close();
        f.writeAll(text.items) catch |e| return .{ .failed = std.fmt.allocPrint(alloc, "{s} cannot be written: {s}", .{ man_new, @errorName(e) }) catch "the record cannot be written" };
        f.sync() catch {};
    }
    keep = true; // from here the staging place is the copy's to become, and recovery owns what is left
    const cwd = std.fs.cwd();
    if (exists(from.into)) cwd.rename(from.into, old) catch |e| return .{ .failed = std.fmt.allocPrint(alloc, "{s} cannot be set aside: {s}", .{ from.into, @errorName(e) }) catch "the old copy cannot be set aside" };
    cwd.rename(new, from.into) catch |e| return .{ .failed = std.fmt.allocPrint(alloc, "the copy cannot be put in place: {s}", .{@errorName(e)}) catch "the copy cannot be put in place" };
    cwd.rename(man_new, man) catch |e| return .{ .failed = std.fmt.allocPrint(alloc, "the record cannot be put in place: {s}", .{@errorName(e)}) catch "the record cannot be put in place" };
    if (std.fs.path.dirnamePosix(from.into)) |parent| syncDir(parent);
    cwd.deleteTree(old) catch {};
    return .{ .ok = .{ .files = rep.files, .dirs = rep.dirs, .bytes = rep.bytes } };
}

/// The puller's loop, forked by PID 1: ask, say what came of it beside the copy, wait, ask again. It says nothing.
pub fn pull(pair: Ed25519.KeyPair, from: machine.MirrorFrom) noreturn {
    while (true) {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const out = attempt(arena.allocator(), pair, from);
        record(arena.allocator(), from.into, out);
        arena.deinit();
        std.Thread.sleep(@as(u64, from.every) * std.time.ns_per_s);
    }
}

// ---- tests ---------------------------------------------------------------------------------------------

test "the names the floor makes for a copy are names the court knows (MIR-1)" {
    const known = machine.mirror_family;
    var found_manifest = false;
    var found_last = false;
    for (known) |s| {
        if (std.mem.eql(u8, s, mirror.kept_manifest_suffix)) found_manifest = true;
        if (std.mem.eql(u8, s, mirror.kept_last_suffix)) found_last = true;
    }
    try std.testing.expect(found_manifest and found_last);
    // and the ones this file makes, spelled where it makes them
    for ([_][]const u8{ ".new", ".old", ".manifest.new", ".last.new" }) |s| {
        var ok = false;
        for (known) |k| if (std.mem.eql(u8, k, s)) {
            ok = true;
        };
        try std.testing.expect(ok);
    }
}

test "an outcome is one line with no time in it, and a refusal's words cannot start a second line (MIR-1)" {
    var buf: [400]u8 = undefined;
    try std.testing.expectEqualStrings("ok files=3 dirs=1 bytes=120", (Outcome{ .ok = .{ .files = 3, .dirs = 1, .bytes = 120 } }).line(&buf));
    try std.testing.expectEqualStrings("silent nobody answered at 10.30.0.1:7400", (Outcome{ .silent = "nobody answered at 10.30.0.1:7400" }).line(&buf));
    const l = (Outcome{ .refused = "a\nb\x01c" }).line(&buf);
    try std.testing.expectEqualStrings("refused a?b?c", l);
}

// ---- tests that need a kernel ---------------------------------------------------------------------

fn put(dir: std.fs.Dir, path: []const u8, bytes: []const u8) !void {
    if (std.fs.path.dirnamePosix(path)) |parent| try dir.makePath(parent);
    try dir.writeFile(.{ .sub_path = path, .data = bytes });
}

fn pairOf(byte: u8) !Ed25519.KeyPair {
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, byte);
    return Ed25519.KeyPair.generateDeterministic(seed);
}

test "a walk gives what the world owns, sorted and hashed, and says what it cannot give (MIR-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const uid = linux.getuid();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try put(tmp.dir, "a.txt", "alpha");
    try put(tmp.dir, "d/e/b.bin", "beta");
    try tmp.dir.makePath("empty");
    const path = try tmp.dir.realpathAlloc(arena, ".");
    const root = try openRoot(path);
    defer posix.close(root);
    const sc = scan(arena, root, uid);
    try std.testing.expect(sc.problem == null);
    const want = [_][]const u8{ "a.txt", "d", "d/e", "d/e/b.bin", "empty" };
    try std.testing.expectEqual(want.len, sc.entries.len);
    for (want, sc.entries) |w, e| try std.testing.expectEqualStrings(w, e.path);
    try std.testing.expectEqual(mirror.Kind.file, sc.entries[0].kind);
    try std.testing.expectEqual(@as(u64, 5), sc.entries[0].size);
    var digest: [32]u8 = undefined;
    Sha256.hash("alpha", &digest, .{});
    try std.testing.expectEqualSlices(u8, &digest, &sc.entries[0].digest);
    try std.testing.expectEqual(mirror.Kind.dir, sc.entries[2].kind);

    // a file the world does not own is not the world's to give
    const other = scan(arena, root, uid +% 1);
    try std.testing.expect(other.problem != null);
    try std.testing.expect(std.mem.indexOf(u8, other.problem.?, "the floor gives only what the world owns") != null);

    // the order is the listing's, whatever order the filesystem lists in: names made in a scrambled order, so that neither a
    // filesystem that lists the newest first nor one that lists by hash happens to list them sorted
    var scrambled = std.testing.tmpDir(.{});
    defer scrambled.cleanup();
    const names = [_][]const u8{ "k", "c", "x", "a", "m", "f", "z", "b", "q", "d", "t", "h" };
    for (names) |n| try put(scrambled.dir, n, n);
    const sroot = try openRoot(try scrambled.dir.realpathAlloc(arena, "."));
    defer posix.close(sroot);
    const ss = scan(arena, sroot, uid);
    try std.testing.expect(ss.problem == null);
    try std.testing.expectEqual(names.len, ss.entries.len);
    for (ss.entries[1..], 0..) |e, i| try std.testing.expect(std.mem.lessThan(u8, ss.entries[i].path, e.path));
}

test "a link, a pipe, or a name that cannot be carried makes the whole directory unmirrorable, and says which (MIR-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const uid = linux.getuid();

    // a symbolic link, to a file that is the machine's and not the world's
    {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        try put(tmp.dir, "fine.txt", "x");
        try put(tmp.dir, "sub/deeper/ok.txt", "y");
        try tmp.dir.symLink("/etc/passwd", "sub/deeper/key", .{});
        const root = try openRoot(try tmp.dir.realpathAlloc(arena, "."));
        defer posix.close(root);
        const sc = scan(arena, root, uid);
        try std.testing.expect(sc.problem != null);
        try std.testing.expect(std.mem.indexOf(u8, sc.problem.?, "sub/deeper/key is a symbolic link") != null);
        try std.testing.expectEqual(@as(usize, 0), sc.entries.len);
    }
    // a link in the directory's own path is not followed to reach it either
    {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        try put(tmp.dir, "real/x.txt", "x");
        try tmp.dir.symLink("real", "viaLink", .{});
        const base = try tmp.dir.realpathAlloc(arena, ".");
        const through = try std.fmt.allocPrint(arena, "{s}/viaLink", .{base});
        // refused whichever way the kernel words it (a link is not a directory, and it will not be followed)
        if (openRoot(through)) |fd| {
            posix.close(fd);
            return error.AFollowedLinkWasOpened;
        } else |_| {}
    }
    // a pipe
    {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        try put(tmp.dir, "fine.txt", "x");
        const rc = linux.mknodat(tmp.dir.fd, "pipe", linux.S.IFIFO | 0o600, 0);
        try std.testing.expectEqual(linux.E.SUCCESS, linux.E.init(rc));
        const root = try openRoot(try tmp.dir.realpathAlloc(arena, "."));
        defer posix.close(root);
        const sc = scan(arena, root, uid);
        try std.testing.expect(sc.problem != null);
        try std.testing.expect(std.mem.indexOf(u8, sc.problem.?, "pipe is not a file or a directory") != null);
    }
    // a name with a backslash in it, which a listing cannot carry as one line of one path
    {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        try put(tmp.dir, "a\\b", "x");
        const root = try openRoot(try tmp.dir.realpathAlloc(arena, "."));
        defer posix.close(root);
        const sc = scan(arena, root, uid);
        try std.testing.expect(sc.problem != null);
        try std.testing.expect(std.mem.indexOf(u8, sc.problem.?, "cannot be carried in a listing") != null);
    }
}

/// A source running in a child of the test process, on a socket the kernel picked, and the means to end it.
const TestSource = struct {
    fd: i32,
    port: u16,
    pid: posix.pid_t,
    running: bool = true,

    fn start(of: machine.MirrorOf, pair: Ed25519.KeyPair) !TestSource {
        const fd = try listen(0x7f000001, 0, "");
        const port = try boundPort(fd);
        const pid = try posix.fork();
        if (pid == 0) serve(fd, pair, of);
        return .{ .fd = fd, .port = port, .pid = pid };
    }

    /// Another source on the same socket: the first one is ended, and the next one answers.
    fn replace(self: *TestSource, of: machine.MirrorOf, pair: Ed25519.KeyPair) !void {
        self.stopChild();
        const pid = try posix.fork();
        if (pid == 0) serve(self.fd, pair, of);
        self.pid = pid;
        self.running = true;
    }

    fn stopChild(self: *TestSource) void {
        if (!self.running) return;
        _ = linux.kill(self.pid, linux.SIG.KILL);
        _ = posix.waitpid(self.pid, 0);
        self.running = false;
    }

    fn stop(self: *TestSource) void {
        self.stopChild();
        _ = linux.close(self.fd);
        self.fd = -1;
    }
};

fn readAll(alloc: std.mem.Allocator, dir: std.fs.Dir, path: []const u8) ![]u8 {
    return dir.readFileAlloc(alloc, path, 1 << 20);
}

test "a source gives its directory to the one device it was told and a puller keeps exactly that, or nothing (MIR-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const uid = linux.getuid();

    var src = std.testing.tmpDir(.{});
    defer src.cleanup();
    var dst = std.testing.tmpDir(.{});
    defer dst.cleanup();
    try put(src.dir, "app.db", "rows rows rows");
    try put(src.dir, "logs/today.log", "line one\nline two\n");
    try src.dir.makePath("empty");
    const src_path = try src.dir.realpathAlloc(arena, ".");
    const dst_path = try dst.dir.realpathAlloc(arena, ".");
    const into = try std.fmt.allocPrint(arena, "{s}/mirror/app", .{dst_path});

    const source = try pairOf(0x51);
    const puller = try pairOf(0x52);
    const stranger = try pairOf(0x53);
    const of = machine.MirrorOf{ .dir = src_path, .for_text = "", .for_key = puller.public_key.toBytes(), .world = "app", .uid = uid, .gid = linux.getgid(), .line = 1 };
    var server = try TestSource.start(of, source);
    defer server.stop();
    const addr = try std.fmt.allocPrint(arena, "127.0.0.1:{d}", .{server.port});
    const from = machine.MirrorFrom{ .text = addr, .ip = 0x7f000001, .port = server.port, .key_text = "", .key = source.public_key.toBytes(), .into = into, .every = 5, .line = 1 };

    // the first pull: a copy, a record, a line about the attempt
    var out = attempt(arena, puller, from);
    try std.testing.expect(out == .ok);
    try std.testing.expectEqual(@as(u64, 2), out.ok.files);
    try std.testing.expectEqual(@as(u64, 2), out.ok.dirs);
    var copy = try std.fs.cwd().openDir(into, .{ .iterate = true });
    defer copy.close();
    try std.testing.expectEqualStrings("rows rows rows", try readAll(arena, copy, "app.db"));
    try std.testing.expectEqualStrings("line one\nline two\n", try readAll(arena, copy, "logs/today.log"));
    const man_path = try std.fmt.allocPrint(arena, "{s}{s}", .{ into, mirror.kept_manifest_suffix });
    const man_text = try std.fs.cwd().readFileAlloc(arena, man_path, 1 << 20);
    const me = journal.fingerprintOf(puller.public_key.toBytes());
    // the record verifies with the source's public key alone, for this device, with no secret and no nonce
    const kept = mirror.verify(arena, man_text, source.public_key, me, null);
    try std.testing.expect(kept == .ok);
    const rep = try mirror.verifyCopy(arena, copy, kept.ok);
    try std.testing.expect(rep.problem == null);
    // nothing of the staging is left
    try std.testing.expectError(error.FileNotFound, std.fs.cwd().access(try std.fmt.allocPrint(arena, "{s}.new", .{into}), .{}));
    try std.testing.expectError(error.FileNotFound, std.fs.cwd().access(try std.fmt.allocPrint(arena, "{s}.old", .{into}), .{}));

    // the source changes: the copy follows it, files added, changed and gone
    try put(src.dir, "app.db", "rows rows rows and more");
    try put(src.dir, "logs/tomorrow.log", "new");
    try src.dir.deleteFile("logs/today.log");
    out = attempt(arena, puller, from);
    try std.testing.expect(out == .ok);
    // the directory was swapped for a new one: the handle on the old one is closed and the path is opened again
    copy.close();
    copy = try std.fs.cwd().openDir(into, .{ .iterate = true });
    try std.testing.expectEqualStrings("rows rows rows and more", try readAll(arena, copy, "app.db"));
    try std.testing.expectError(error.FileNotFound, copy.access("logs/today.log", .{}));
    try std.testing.expectEqualStrings("new", try readAll(arena, copy, "logs/tomorrow.log"));

    // a link appears in the world's directory: the source will not give it, says so, and the copy stays as it was
    try src.dir.symLink("/etc/passwd", "stolen", .{});
    out = attempt(arena, puller, from);
    try std.testing.expect(out == .refused);
    try std.testing.expect(std.mem.indexOf(u8, out.refused, "stolen is a symbolic link") != null);
    try std.testing.expectEqualStrings("rows rows rows and more", try readAll(arena, copy, "app.db"));
    try src.dir.deleteFile("stolen");

    // a device that is not the one the copy is for is closed on, and told nothing
    out = attempt(arena, stranger, from);
    try std.testing.expect(out == .silent);
    try std.testing.expectEqualStrings("rows rows rows and more", try readAll(arena, copy, "app.db"));

    // somebody else answering at the address: its listing is not the source's, and nothing is kept
    try server.replace(of, stranger);
    out = attempt(arena, puller, from);
    try std.testing.expect(out == .unverified);
    try std.testing.expect(std.mem.indexOf(u8, out.unverified, "signed by somebody else") != null);
    try std.testing.expectEqualStrings("rows rows rows and more", try readAll(arena, copy, "app.db"));

    // nobody answering at all: said, and the copy stays the last one that verified
    server.stopChild();
    out = attempt(arena, puller, from);
    try std.testing.expect(out == .silent);
    try std.testing.expectEqualStrings("rows rows rows and more", try readAll(arena, copy, "app.db"));

    // and what was told is kept beside the copy, in the words the witness reads
    record(arena, into, out);
    const last = try std.fs.cwd().readFileAlloc(arena, try std.fmt.allocPrint(arena, "{s}{s}", .{ into, mirror.kept_last_suffix }), 4096);
    try std.testing.expect(std.mem.startsWith(u8, last, "silent "));
}

test "a swap cut short is finished or undone, whichever step the power left it at (MIR-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realpathAlloc(arena, ".");
    const into = try std.fmt.allocPrint(arena, "{s}/c", .{base});

    // after the copy was set aside and before the new one was put in place: put the old one back
    try put(tmp.dir, "c.old/f", "old");
    try put(tmp.dir, "c.new/f", "new");
    try put(tmp.dir, "c.manifest", "old record");
    try put(tmp.dir, "c.manifest.new", "new record");
    recover(arena, into);
    try std.testing.expectEqualStrings("old", try readAll(arena, tmp.dir, "c/f"));
    try std.testing.expectEqualStrings("old record", try readAll(arena, tmp.dir, "c.manifest"));
    for ([_][]const u8{ "c.old", "c.new", "c.manifest.new" }) |gone| try std.testing.expectError(error.FileNotFound, tmp.dir.access(gone, .{}));

    // after the new copy was put in place and before its record was: the record is finished, the old copy is dropped
    try tmp.dir.deleteTree("c");
    try put(tmp.dir, "c/f", "new");
    try put(tmp.dir, "c.old/f", "old");
    try put(tmp.dir, "c.manifest.new", "new record");
    recover(arena, into);
    try std.testing.expectEqualStrings("new", try readAll(arena, tmp.dir, "c/f"));
    try std.testing.expectEqualStrings("new record", try readAll(arena, tmp.dir, "c.manifest"));
    for ([_][]const u8{ "c.old", "c.manifest.new" }) |gone| try std.testing.expectError(error.FileNotFound, tmp.dir.access(gone, .{}));

    // a pull that was never finished: the staging place and the record that was waiting for it are removed, the copy is untouched
    try put(tmp.dir, "c.new/f", "half");
    try put(tmp.dir, "c.manifest.new", "record of a half");
    try put(tmp.dir, "c.last.new", "x");
    recover(arena, into);
    try std.testing.expectEqualStrings("new", try readAll(arena, tmp.dir, "c/f"));
    try std.testing.expectEqualStrings("new record", try readAll(arena, tmp.dir, "c.manifest"));
    for ([_][]const u8{ "c.new", "c.manifest.new", "c.last.new" }) |gone| try std.testing.expectError(error.FileNotFound, tmp.dir.access(gone, .{}));

    // after everything but dropping the old copy
    try put(tmp.dir, "c.old/f", "older");
    recover(arena, into);
    try std.testing.expectError(error.FileNotFound, tmp.dir.access("c.old", .{}));
    try std.testing.expectEqualStrings("new", try readAll(arena, tmp.dir, "c/f"));
}

test "a file inside the world's directory that another identity owns is refused, whatever its name (MIR-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    // giving a file to another identity is the machine's act and not a world's: only root can make the case
    if (linux.getuid() != 0) return error.SkipZigTest;
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try put(tmp.dir, "mine.txt", "mine");
    try put(tmp.dir, "sub/theirs.key", "the machine's own key, by another name");
    // the directory and the first file are the world's (uid 0 here); the second belongs to somebody else, as a hard
    // link to a file of the machine's does
    {
        const f = try tmp.dir.openFile("sub/theirs.key", .{});
        defer f.close();
        try posix.fchown(f.handle, 4242, 4242);
    }
    const root = try openRoot(try tmp.dir.realpathAlloc(arena, "."));
    defer posix.close(root);
    const sc = scan(arena, root, linux.getuid());
    try std.testing.expect(sc.problem != null);
    try std.testing.expect(std.mem.indexOf(u8, sc.problem.?, "sub/theirs.key belongs to uid 4242") != null);
    try std.testing.expectEqual(@as(usize, 0), sc.entries.len);
}

test "a file longer than a copy can carry is refused before it is read (MIR-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try put(tmp.dir, "small.txt", "x");
    {
        // a sparse file, one byte past what a copy carries: the world can make one of any size, and the floor reads the
        // world's files as root. No byte of it is written, and none of it should be read
        const f = try tmp.dir.createFile("huge.bin", .{});
        defer f.close();
        try f.setEndPos(mirror.max_total_bytes + 1);
    }
    const root = try openRoot(try tmp.dir.realpathAlloc(arena, "."));
    defer posix.close(root);
    const sc = scan(arena, root, linux.getuid());
    try std.testing.expect(sc.problem != null);
    try std.testing.expect(std.mem.indexOf(u8, sc.problem.?, "huge.bin is longer than the") != null);
    try std.testing.expectEqual(@as(usize, 0), sc.entries.len);
}

/// What a source that is not honest does after it has been asked by the one device it gives to.
const Tamper = enum { replay, wrong_bytes, truncated };

/// A source that answers the right device, with a listing of the right directory, and then does one wrong thing.
fn fakeHandle(conn: *Conn, alloc: std.mem.Allocator, pair: Ed25519.KeyPair, of: machine.MirrorOf, allowed: Ed25519.PublicKey, tamper: Tamper) void {
    var nonce_a: [mirror.nonce_len]u8 = undefined;
    std.crypto.random.bytes(&nonce_a);
    var cb: [mirror.max_line]u8 = undefined;
    const ch = mirror.challenge(&cb, nonce_a) catch return;
    const t0 = nowMs();
    conn.sendLine(ch, auth_ms) catch return;
    var rb: [mirror.max_line + 2]u8 = undefined;
    const line = conn.readLine(&rb, t0 + auth_ms) catch return;
    const req = mirror.verifyRequest(line, allowed, nonce_a) orelse return;
    const root = openRoot(of.dir) catch return;
    defer posix.close(root);
    const sc = scan(alloc, root, of.uid);
    if (sc.problem != null) return;
    // an old listing, answering another request, is what a replay is
    const nonce: [mirror.nonce_len]u8 = if (tamper == .replay) [_]u8{0x77} ** mirror.nonce_len else req.b;
    const text = mirror.build(alloc, pair, journal.fingerprintOf(req.key), nonce, of.dir, sc.entries) catch return;
    conn.sendAll(text, stall_ms) catch return;
    var block: [4096]u8 = undefined;
    for (sc.entries) |e| {
        if (e.kind != .file) continue;
        const ffd = openFileRel(root, e.path) catch return;
        defer posix.close(ffd);
        var left: u64 = e.size;
        var first = true;
        while (left > 0) {
            const want: usize = @intCast(@min(left, block.len));
            const n = posix.read(ffd, block[0..want]) catch return;
            if (n == 0) return;
            if (tamper == .wrong_bytes and first) block[0] ^= 1;
            if (tamper == .truncated) {
                // half of the first file, and the connection closed
                conn.sendAll(block[0 .. n / 2], stall_ms) catch {};
                return;
            }
            first = false;
            conn.sendAll(block[0..n], stall_ms) catch return;
            left -= n;
        }
    }
}

fn fakeServe(listen_fd: i32, pair: Ed25519.KeyPair, of: machine.MirrorOf, tamper: Tamper) noreturn {
    const allowed = Ed25519.PublicKey.fromBytes(of.for_key) catch std.process.exit(1);
    while (true) {
        const rc = linux.accept4(listen_fd, null, null, linux.SOCK.NONBLOCK | linux.SOCK.CLOEXEC);
        if (linux.E.init(rc) != .SUCCESS) {
            std.Thread.sleep(10 * std.time.ns_per_ms);
            continue;
        }
        const fd: i32 = @intCast(rc);
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var conn = Conn{ .fd = fd };
        fakeHandle(&conn, arena.allocator(), pair, of, allowed, tamper);
        arena.deinit();
        _ = linux.close(fd);
    }
}

test "a source that replays, lies about a file's bytes, or stops half way gives the keeper nothing to keep (MIR-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var src = std.testing.tmpDir(.{});
    defer src.cleanup();
    var dst = std.testing.tmpDir(.{});
    defer dst.cleanup();
    try put(src.dir, "a.db", "alpha alpha alpha alpha");
    try put(src.dir, "b/b.db", "beta beta beta");
    const src_path = try src.dir.realpathAlloc(arena, ".");
    const into = try std.fmt.allocPrint(arena, "{s}/copy", .{try dst.dir.realpathAlloc(arena, ".")});
    const source = try pairOf(0x61);
    const puller = try pairOf(0x62);
    const of = machine.MirrorOf{ .dir = src_path, .for_text = "", .for_key = puller.public_key.toBytes(), .world = "app", .uid = linux.getuid(), .gid = linux.getgid(), .line = 1 };

    for ([_]Tamper{ .replay, .wrong_bytes, .truncated }) |tamper| {
        const fd = try listen(0x7f000001, 0, "");
        defer _ = linux.close(fd);
        const port = try boundPort(fd);
        const pid = try posix.fork();
        if (pid == 0) fakeServe(fd, source, of, tamper);
        defer {
            _ = linux.kill(pid, linux.SIG.KILL);
            _ = posix.waitpid(pid, 0);
        }
        const from = machine.MirrorFrom{ .text = "127.0.0.1", .ip = 0x7f000001, .port = port, .key_text = "", .key = source.public_key.toBytes(), .into = into, .every = 5, .line = 1 };
        const out = attempt(arena, puller, from);
        try std.testing.expect(out == .unverified);
        const why = out.unverified;
        switch (tamper) {
            .replay => try std.testing.expect(std.mem.indexOf(u8, why, "answers another request") != null),
            .wrong_bytes => try std.testing.expect(std.mem.indexOf(u8, why, "does not match the digest the source signed") != null),
            .truncated => try std.testing.expect(std.mem.indexOf(u8, why, "the source stopped before") != null),
        }
        // nothing was kept, and nothing of the staging is left
        try std.testing.expectError(error.FileNotFound, std.fs.cwd().access(into, .{}));
        try std.testing.expectError(error.FileNotFound, std.fs.cwd().access(try std.fmt.allocPrint(arena, "{s}.new", .{into}), .{}));
    }
}

test "every public act of the seat is built when the seat is built for Linux (MIR-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    std.testing.refAllDecls(@This());
}
