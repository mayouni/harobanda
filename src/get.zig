//! `harb get <host> <port> [<path>]` -- a world asks a server one question (FWD-1).
//!
//! The till of the cloud ladder's second rung is a device that was told
//! nothing but its own address, asked a box for the NAME of a server on
//! another link, and now has to reach it. `ask` says what the name means;
//! this goes there. It is the one act that proves a packet crossed: a name
//! that resolves and a way that is closed look the same until somebody tries
//! to connect.
//!
//! `<host>` is an a.b.c.d address or a name, and a name is asked of the
//! resolver this machine's own lease named (`names.lookup`, the reading
//! `ask` uses, so the two cannot disagree about where a name goes). The
//! request is HTTP/1.0 and a closed connection: the answer is a status and
//! a first line of body, which is all anyone needs to see that the thing
//! asked is the thing that answered.
//!
//! It says one line and exits 0 whenever it performed the question, whatever
//! the answer was -- the line is the verdict, as `ask` and `reach` are --
//! and 1 only when it was not given a question. A one-shot that exited
//! non-zero would stop everything that comes AFTER it, and a transcript that
//! ends there says less than one that says what happened.
//!
//! With `--tls --ca <pem>` (FRONT-1) the same question is asked through a
//! TLS handshake: the server's certificate must be issued for the name asked
//! and chain to a root in the PEM file, which is the front's own root as the
//! scene seeded it, and nothing else is trusted -- no system store exists on
//! the floor, and the file is the whole of what this world trusts. The name
//! is the host when the host is one (a door is asked by its name, FRONT-2),
//! and `--name <host>` when the host is an address, which carries none. The
//! line then says the TLS version and the root's fingerprint, so the
//! transcript carries whose word the certificate was.

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");
const names = @import("names.zig");
const ready = @import("ready.zig");

/// The first 16 hex digits of the sha256 of the first certificate in a PEM file: the spelling
/// the fleet's keys use (`fingerprint <16 hex>`), so the judge's own normalisation reads it.
pub fn rootFingerprint(arena: std.mem.Allocator, pem: []const u8) ![16]u8 {
    const head = "-----BEGIN CERTIFICATE-----";
    const tail = "-----END CERTIFICATE-----";
    const b = std.mem.indexOf(u8, pem, head) orelse return error.NoCertificate;
    const start = b + head.len;
    const e = std.mem.indexOfPos(u8, pem, start, tail) orelse return error.NoCertificate;
    var clean: std.ArrayList(u8) = .{};
    for (pem[start..e]) |c| {
        if (!std.ascii.isWhitespace(c)) try clean.append(arena, c);
    }
    const dec = std.base64.standard.Decoder;
    const len = try dec.calcSizeForSlice(clean.items);
    const der = try arena.alloc(u8, len);
    try dec.decode(der, clean.items);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(der, &digest, .{});
    return std.fmt.bytesToHex(digest[0..8], .lower);
}

/// The three-digit status of an HTTP/1.x answer, or null if it is not one.
pub fn statusCode(answer: []const u8) ?u16 {
    if (answer.len < 12) return null;
    if (!std.mem.startsWith(u8, answer, "HTTP/1.")) return null;
    if (answer[8] != ' ') return null;
    if (answer.len > 12 and answer[12] != ' ' and answer[12] != '\r' and answer[12] != '\n') return null;
    return std.fmt.parseInt(u16, answer[9..12], 10) catch null;
}

/// The first line of the body: what follows the blank line, up to its end or
/// to `max` bytes. Anything that is not printable ASCII becomes `?`, so a
/// transcript never carries a byte somebody's terminal would obey.
pub fn firstBodyLine(answer: []const u8, out: []u8) []const u8 {
    const sep = std.mem.indexOf(u8, answer, "\r\n\r\n") orelse return out[0..0];
    const body = answer[sep + 4 ..];
    var n: usize = 0;
    for (body) |c| {
        if (c == '\r' or c == '\n') break;
        if (n == out.len) break;
        out[n] = if (c >= 0x20 and c < 0x7f) c else '?';
        n += 1;
    }
    return out[0..n];
}

/// Run it: the whole verb. Returns what `harb` exits with.
pub fn run(arena: std.mem.Allocator, args: []const []const u8, out: *std.Io.Writer) !u8 {
    if (builtin.os.tag != .linux) {
        try out.print("get: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
        return 2;
    }
    const usage = "harb: get <host> <port> [<path>] [--tls --ca <pem> [--name <host>]] -- a name or an a.b.c.d address, a port, a path that starts with a slash; over TLS, the root to trust and, for an address, the name the certificate must carry (a name asked is the name expected)\n";
    var pos: [3][]const u8 = undefined;
    var n_pos: usize = 0;
    var tls_on = false;
    var ca_path: ?[]const u8 = null;
    var tls_name: ?[]const u8 = null;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--tls")) {
            tls_on = true;
        } else if (std.mem.eql(u8, a, "--ca") and i + 1 < args.len) {
            i += 1;
            ca_path = args[i];
        } else if (std.mem.eql(u8, a, "--name") and i + 1 < args.len) {
            i += 1;
            tls_name = args[i];
        } else if (std.mem.startsWith(u8, a, "--") or n_pos == pos.len) {
            try out.print(usage, .{});
            return 1;
        } else {
            pos[n_pos] = a;
            n_pos += 1;
        }
    }
    if (n_pos < 2) {
        try out.print(usage, .{});
        return 1;
    }
    const host = pos[0];
    const port = std.fmt.parseInt(u16, pos[1], 10) catch 0;
    const path = if (n_pos == 3) pos[2] else "/";
    if (port == 0 or path.len == 0 or path[0] != '/') {
        try out.print(usage, .{});
        return 1;
    }
    if (tls_on and ca_path == null) {
        try out.print(usage, .{});
        return 1;
    }
    // the name the certificate must carry: the host itself when the host is a name
    // (a door is asked by its name, and that is the name it must answer to), and
    // said with --name when the host is an address, which carries none
    if (tls_on and tls_name == null) {
        if (machine.parseIpv4(host) != null) {
            try out.print(usage, .{});
            return 1;
        }
        tls_name = host;
    }
    if (!tls_on and (ca_path != null or tls_name != null)) {
        try out.print(usage, .{});
        return 1;
    }
    if (ca_path) |p| if (p.len == 0 or p[0] != '/') {
        try out.print(usage, .{});
        return 1;
    };
    var said: [200]u8 = undefined;
    const url = if (tls_on and std.mem.eql(u8, tls_name.?, host))
        std.fmt.bufPrint(&said, "https://{s}:{d}{s}", .{ host, port, path }) catch host
    else if (tls_on)
        std.fmt.bufPrint(&said, "https://{s}{s} at {s}:{d}", .{ tls_name.?, path, host, port }) catch host
    else
        std.fmt.bufPrint(&said, "http://{s}:{d}{s}", .{ host, port, path }) catch host;

    // an address, or a name asked of the resolver the lease named
    var ipbuf: [16]u8 = undefined;
    const ip: u32 = machine.parseIpv4(host) orelse switch (names.lookup(arena, host)) {
        .address => |a| a.ip,
        .no_such_name => {
            try out.print("get {s} -- the name does not exist on this network\n", .{url});
            return 0;
        },
        .silent => {
            try out.print("get {s} -- the resolver did not answer, so the name is not an address\n", .{url});
            return 0;
        },
        .never_told, .names_none => {
            try out.print("get {s} -- no resolver was named, so the name is not an address\n", .{url});
            return 0;
        },
        .no_socket => |why| {
            try out.print("get {s} -- no socket: {s}\n", .{ url, why });
            return 0;
        },
        .not_a_name => {
            try out.print("get {s} -- that is not a name this machine can ask for\n", .{url});
            return 0;
        },
    };
    const ipt = std.fmt.bufPrint(&ipbuf, "{d}.{d}.{d}.{d}", .{ ip >> 24, (ip >> 16) & 255, (ip >> 8) & 255, ip & 255 }) catch "?";

    const l = std.os.linux;
    const rc_sock = l.socket(l.AF.INET, l.SOCK.STREAM, 0);
    if (l.E.init(rc_sock) != .SUCCESS) {
        try out.print("get {s} -- no socket: {s}\n", .{ url, @tagName(l.E.init(rc_sock)) });
        return 0;
    }
    const fd: i32 = @intCast(rc_sock);
    defer _ = l.close(fd);
    const tv: l.timeval = .{ .sec = 3, .usec = 0 };
    _ = l.setsockopt(fd, l.SOL.SOCKET, l.SO.RCVTIMEO, @ptrCast(&tv), @sizeOf(l.timeval));
    _ = l.setsockopt(fd, l.SOL.SOCKET, l.SO.SNDTIMEO, @ptrCast(&tv), @sizeOf(l.timeval));
    var sa = std.posix.sockaddr.in{
        .family = l.AF.INET,
        .port = std.mem.nativeToBig(u16, port),
        .addr = std.mem.nativeToBig(u32, ip),
        .zero = [_]u8{0} ** 8,
    };
    switch (l.E.init(l.connect(fd, @ptrCast(&sa), @sizeOf(@TypeOf(sa))))) {
        .SUCCESS => {},
        // a blocking connect that outlasts its timeout reports one of these
        .INPROGRESS, .TIMEDOUT, .AGAIN => {
            try out.print("get {s} -- no answer from {s} within 3 seconds\n", .{ url, ipt });
            return 0;
        },
        .CONNREFUSED => {
            try out.print("get {s} -- {s} answered, and nothing listens on port {d}\n", .{ url, ipt, port });
            return 0;
        },
        .NETUNREACH, .HOSTUNREACH => {
            try out.print("get {s} -- no way to {s}\n", .{ url, ipt });
            return 0;
        },
        else => |e| {
            try out.print("get {s} -- no connection to {s}: {s}\n", .{ url, ipt, @tagName(e) });
            return 0;
        },
    }
    var req_buf: [512]u8 = undefined;
    const req = ready.request(&req_buf, path, if (tls_on) tls_name.? else host) orelse {
        try out.print("get {s} -- the request does not fit\n", .{url});
        return 0;
    };
    if (tls_on) return overTls(arena, fd, url, ipt, tls_name.?, ca_path.?, req, out);
    if (l.E.init(l.write(fd, req.ptr, req.len)) != .SUCCESS) {
        try out.print("get {s} -- {s} took the connection and not the question\n", .{ url, ipt });
        return 0;
    }
    var ans: [2048]u8 = undefined;
    var got: usize = 0;
    while (got < ans.len) {
        const n = l.read(fd, ans[got..].ptr, ans.len - got);
        if (l.E.init(n) != .SUCCESS or n == 0) break;
        got += n;
    }
    const answer = ans[0..got];
    const code = statusCode(answer) orelse {
        try out.print("get {s} -- {s} answered, and what it said is not HTTP\n", .{ url, ipt });
        return 0;
    };
    var line: [100]u8 = undefined;
    const body = firstBodyLine(answer, &line);
    if (body.len == 0) {
        try out.print("get {s} -- {d}\n", .{ url, code });
    } else {
        try out.print("get {s} -- {d} {s}\n", .{ url, code, body });
    }
    return 0;
}

/// The same question through a TLS handshake (FRONT-1): the certificate must be issued for
/// `name` and chain to a root in the PEM file at `ca_path`; nothing else is trusted. One line,
/// exit 0 whatever happened, as the plain path.
fn overTls(arena: std.mem.Allocator, fd: i32, url: []const u8, ipt: []const u8, name: []const u8, ca_path: []const u8, req: []const u8, out: *std.Io.Writer) !u8 {
    const tls = std.crypto.tls;
    const pem = std.fs.cwd().readFileAlloc(arena, ca_path, 1 << 16) catch |e| {
        try out.print("get {s} -- the root to trust could not be read from {s}: {s}\n", .{ url, ca_path, @errorName(e) });
        return 0;
    };
    const fp = rootFingerprint(arena, pem) catch {
        try out.print("get {s} -- {s} holds no certificate to trust\n", .{ url, ca_path });
        return 0;
    };
    var bundle: std.crypto.Certificate.Bundle = .{};
    bundle.addCertsFromFilePathAbsolute(arena, ca_path) catch |e| {
        try out.print("get {s} -- the root to trust could not be read from {s}: {s}\n", .{ url, ca_path, @errorName(e) });
        return 0;
    };
    const stream = std.net.Stream{ .handle = fd };
    const min = tls.Client.min_buffer_len;
    const sr_buf = try arena.alloc(u8, min);
    const sw_buf = try arena.alloc(u8, min);
    const tr_buf = try arena.alloc(u8, min + 4096);
    const tw_buf = try arena.alloc(u8, min);
    var sreader = stream.reader(sr_buf);
    var swriter = stream.writer(sw_buf);
    var tc = tls.Client.init(sreader.interface(), &swriter.interface, .{
        .host = .{ .explicit = name },
        .ca = .{ .bundle = bundle },
        .read_buffer = tr_buf,
        .write_buffer = tw_buf,
        // HTTP/1.0 with Connection: close -- the answer ends when the server closes, and a status line
        // that never came is what this reports; nothing here is parsed past its first body line
        .allow_truncation_attacks = true,
    }) catch |e| {
        try out.print("get {s} -- the handshake with {s} failed: {s}; the certificate must be for {s} and signed under the root fingerprint {s}\n", .{ url, ipt, @errorName(e), name, fp });
        return 0;
    };
    tc.writer.writeAll(req) catch {
        try out.print("get {s} -- {s} took the handshake and not the question\n", .{ url, ipt });
        return 0;
    };
    tc.writer.flush() catch {
        try out.print("get {s} -- {s} took the handshake and not the question\n", .{ url, ipt });
        return 0;
    };
    swriter.interface.flush() catch {
        try out.print("get {s} -- {s} took the handshake and not the question\n", .{ url, ipt });
        return 0;
    };
    var ans: [4096]u8 = undefined;
    const got = tc.reader.readSliceShort(&ans) catch |e| blk: {
        // a server that closes without close_notify after an HTTP/1.0 answer is an answer all the same
        if (e == error.ReadFailed) break :blk ans.len;
        break :blk 0;
    };
    const answer = if (got <= ans.len) ans[0..got] else ans[0..];
    const version: []const u8 = switch (tc.tls_version) {
        .tls_1_3 => "TLS 1.3",
        .tls_1_2 => "TLS 1.2",
        else => "TLS",
    };
    const code = statusCode(answer) orelse {
        try out.print("get {s} -- {s} answered over {s}, and what it said is not HTTP\n", .{ url, ipt, version });
        return 0;
    };
    var line: [100]u8 = undefined;
    const body = firstBodyLine(answer, &line);
    if (body.len == 0) {
        try out.print("get {s} -- {d} over {s}; the certificate is for {s}, signed under the root fingerprint {s}\n", .{ url, code, version, name, fp });
    } else {
        try out.print("get {s} -- {d} {s} over {s}; the certificate is for {s}, signed under the root fingerprint {s}\n", .{ url, code, body, version, name, fp });
    }
    return 0;
}

// ---- judged beside the code ----------------------------------------------

test "the root's fingerprint is the sha256 of the first certificate's DER, sixteen hex (FRONT-1)" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // the DER bytes 0x30 0x03 0x02 0x01 0x05 (any bytes: the fingerprint is of what is between the lines)
    const pem = "-----BEGIN CERTIFICATE-----\nMAMC\nAQU=\n-----END CERTIFICATE-----\n";
    const fp = try rootFingerprint(arena, pem);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&[_]u8{ 0x30, 0x03, 0x02, 0x01, 0x05 }, &digest, .{});
    try t.expectEqualStrings(&std.fmt.bytesToHex(digest[0..8], .lower), &fp);
    try t.expectError(error.NoCertificate, rootFingerprint(arena, "not a pem"));
}

test "a status is read from an HTTP/1.x answer and from nothing else" {
    const t = std.testing;
    try t.expectEqual(@as(?u16, 200), statusCode("HTTP/1.1 200 OK\r\ncontent-type: application/json\r\n\r\n{}"));
    try t.expectEqual(@as(?u16, 200), statusCode("HTTP/1.0 200\r\n\r\n"));
    try t.expectEqual(@as(?u16, 404), statusCode("HTTP/1.1 404 Not Found\r\n"));
    try t.expectEqual(@as(?u16, 503), statusCode("HTTP/1.1 503 Service Unavailable\r\n"));
    try t.expectEqual(@as(?u16, null), statusCode("HTTP/1.1 2000 OK\r\n"));
    try t.expectEqual(@as(?u16, null), statusCode("HTTP/1.1 20\r\n"));
    try t.expectEqual(@as(?u16, null), statusCode("HTTP/1.1 abc OK\r\n"));
    try t.expectEqual(@as(?u16, null), statusCode("SSH-2.0-OpenSSH_9.6\r\n"));
    try t.expectEqual(@as(?u16, null), statusCode(""));
}

test "the first line of the body is what follows the blank line, bounded and printable" {
    const t = std.testing;
    var buf: [100]u8 = undefined;
    try t.expectEqualStrings("{\"up\":true}", firstBodyLine("HTTP/1.1 200 OK\r\nx: y\r\n\r\n{\"up\":true}\nsecond line", &buf));
    // no body at all, and no blank line at all
    try t.expectEqualStrings("", firstBodyLine("HTTP/1.1 200 OK\r\nx: y\r\n\r\n", &buf));
    try t.expectEqualStrings("", firstBodyLine("HTTP/1.1 200 OK\r\nx: y\r\n", &buf));
    // a byte a terminal would obey is not carried into a transcript
    try t.expectEqualStrings("a?b", firstBodyLine("HTTP/1.1 200 OK\r\n\r\na\x1bb", &buf));
    // and a line longer than the room is cut, not refused
    var small: [4]u8 = undefined;
    try t.expectEqualStrings("abcd", firstBodyLine("HTTP/1.1 200 OK\r\n\r\nabcdefgh", &small));
}
