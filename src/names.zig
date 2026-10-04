//! The box as the network's own server of names (NAM-1).
//!
//! ## The ground
//!
//! RestoLean's B7 states it from the merchant's side, and it has nothing
//! to do with us: many boxes do not keep their register of leases across
//! a reboot, so the kitchen printer comes back on a different number and
//! somebody re-types it into the till. The answer there is a box that
//! hands out the addresses itself, reserves them all, and gives names --
//! `imprimante.makeen`.
//!
//! ## What is absent
//!
//! There is **no pool and no range**. A machine that declares a `DOMAIN`
//! on a link serves exactly the peers it declares and nobody else: an
//! undeclared device asking for an address is answered with silence, and
//! its own transcript says `no lease after 3 tries (no server answered
//! on this network)`, which is the truth.
//!
//! That removes the failure rather than handling it. The register of who
//! has what cannot be lost at a reboot, because there is no register --
//! there is the declaration, which is text, in git, judged by the court
//! before the image is built. A lease is offered as INFINITE (option 51,
//! 0xffffffff) for the same reason: the address is this device's because
//! it was declared, not because a timer has not run out yet.
//!
//! ## What it does not claim
//!
//! The box answers for its own link. It offers itself as the resolver
//! (option 6) and gives the domain (option 15), and it sends a router
//! option **only if it forwards** (`FORWARD`, FWD-1): a box that named
//! itself the way out without being one would be lying to every device
//! on the network. Forwarding is an act, and an act is declared; a
//! machine that declares it is the way to the other links it serves, is
//! offered as such, and answers for the full names on them -- and for
//! nothing else, so it stays silent about the rest of the world.
//!
//! A name that is not declared is answered `NXDOMAIN` -- a true
//! statement about this network -- never forwarded upstream. The box
//! speaks for what it knows and stays silent about the rest.

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");
const linux = std.os.linux;

// ---- DHCP ------------------------------------------------------------------

const dhcp_magic = [4]u8{ 99, 130, 83, 99 };
const OPT_MASK = 1;
const OPT_ROUTER = 3;
const OPT_DNS = 6;
const OPT_HOSTNAME = 12;
const OPT_DOMAIN = 15;
const OPT_REQUESTED_IP = 50;
const OPT_LEASE = 51;
const OPT_MSG_TYPE = 53;
const OPT_SERVER_ID = 54;
const OPT_END = 255;

const DISCOVER = 1;
const OFFER = 2;
const REQUEST = 3;
const ACK = 5;

const forever: u32 = 0xFFFFFFFF;

fn sockIn(ip: u32, port: u16) linux.sockaddr {
    const sin: linux.sockaddr.in = .{ .port = std.mem.nativeToBig(u16, port), .addr = std.mem.nativeToBig(u32, ip) };
    return @as(*const linux.sockaddr, @ptrCast(&sin)).*;
}

fn errOf(rc: usize) linux.E {
    return linux.E.init(rc);
}

/// The two sockets this machine serves its link from. Bound by PID 1, so
/// a refusal is reported where refusals belong -- in the boot's own
/// narration, by the process whose transcript is judged.
pub const Server = struct {
    dhcp_fd: i32,
    dns_fd: i32,
};

fn bindUdp(iface: []const u8, port: u16, broadcast: bool) !i32 {
    const rc = linux.socket(linux.AF.INET, linux.SOCK.DGRAM, 0);
    if (errOf(rc) != .SUCCESS) return error.NoSocket;
    const fd: i32 = @intCast(rc);
    errdefer _ = linux.close(fd);
    const one: i32 = 1;
    _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.REUSEADDR, @ptrCast(&one), @sizeOf(i32));
    if (broadcast) _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.BROADCAST, @ptrCast(&one), @sizeOf(i32));
    // the server answers on the link it was declared for and on no other
    _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.BINDTODEVICE, iface.ptr, @intCast(iface.len));
    const local = sockIn(0, port);
    if (errOf(linux.bind(fd, &local, @sizeOf(linux.sockaddr.in))) != .SUCCESS) return error.BindRefused;
    return fd;
}

/// Take the two ports. Called by PID 1 before it forks, so that "this
/// machine could not become the server it declared itself" is said by
/// the machine, in order, in the transcript that is judged.
pub fn open(iface: []const u8) !Server {
    const d = try bindUdp(iface, 67, true);
    errdefer _ = linux.close(d);
    const n = try bindUdp(iface, 53, false);
    return .{ .dhcp_fd = d, .dns_fd = n };
}

/// Who this link is for. `peers` is already narrowed to this network.
pub const Link = struct {
    self_ip: u32,
    mask: u32,
    domain: []const u8,
    peers: []const machine.Peer,
    /// The way out of this link, when this machine IS the way between links
    /// (FWD-1): offered as the router (option 3) to every device it leases an
    /// address to, and to nobody else. A machine that does not forward sends
    /// none: a box that named itself the way out without being one would be
    /// lying to every device on the link.
    router: ?u32 = null,
    /// The other links this machine serves and is the way to (FWD-1). Their
    /// names are answered here too, by the FULL name only: a bare `commons`
    /// is a name on THIS link, and the same word on another link is another
    /// device. Empty on a machine that does not forward, whose server speaks
    /// for its own link and is silent about every other.
    reach: []const Link = &.{},

    fn byMac(self: Link, mac: [6]u8) ?machine.Peer {
        for (self.peers) |p| if (std.mem.eql(u8, &p.hardware, &mac)) return p;
        return null;
    }

    /// `imprimante.makeen` and `imprimante` both name the printer;
    /// `makeen` names the box itself, which is the whole point of the
    /// clause -- the box IS the network's address. Beyond this link, only
    /// the links this machine is the way to, and only by their full names.
    fn byName(self: Link, q: []const u8) ?u32 {
        if (eqFold(q, self.domain)) return self.self_ip;
        for (self.peers) |p| {
            if (eqFold(q, p.name)) return p.ip;
            if (self.qualified(p, q)) return p.ip;
        }
        for (self.reach) |o| if (o.byFullName(q)) |ip| return ip;
        return null;
    }

    fn qualified(self: Link, p: machine.Peer, q: []const u8) bool {
        return q.len == p.name.len + 1 + self.domain.len and
            eqFold(q[0..p.name.len], p.name) and
            q[p.name.len] == '.' and
            eqFold(q[p.name.len + 1 ..], self.domain);
    }

    /// A name as another link's server would spell it: the link's domain, which
    /// is the machine itself on that link, or `peer.domain`.
    fn byFullName(self: Link, q: []const u8) ?u32 {
        if (eqFold(q, self.domain)) return self.self_ip;
        for (self.peers) |p| if (self.qualified(p, q)) return p.ip;
        return null;
    }
};

fn eqFold(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        const lx = if (x >= 'A' and x <= 'Z') x + 32 else x;
        const ly = if (y >= 'A' and y <= 'Z') y + 32 else y;
        if (lx != ly) return false;
    }
    return true;
}

fn putOpt(buf: []u8, i: *usize, code: u8, val: []const u8) void {
    if (i.* + 2 + val.len > buf.len) return;
    buf[i.*] = code;
    buf[i.* + 1] = @intCast(val.len);
    @memcpy(buf[i.* + 2 ..][0..val.len], val);
    i.* += 2 + val.len;
}

fn putIp(buf: []u8, i: *usize, code: u8, ip: u32) void {
    var b: [4]u8 = undefined;
    std.mem.writeInt(u32, &b, ip, .big);
    putOpt(buf, i, code, &b);
}

/// The answer to one BOOTREQUEST. Returns the length, or null when this
/// machine has nothing to say -- which is what an undeclared device is
/// told, and it is not an error, it is the design.
fn reply(out: *[576]u8, req: []const u8, link: Link) ?usize {
    if (req.len < 240) return null;
    if (req[0] != 1 or req[2] != 6) return null; // BOOTREQUEST, ethernet
    if (!std.mem.eql(u8, req[236..240], &dhcp_magic)) return null;

    var kind: u8 = 0;
    var requested: ?u32 = null;
    var i: usize = 240;
    while (i + 1 < req.len) {
        const code = req[i];
        if (code == OPT_END) break;
        if (code == 0) {
            i += 1;
            continue;
        }
        const len = req[i + 1];
        const end = i + 2 + @as(usize, len);
        if (end > req.len) break;
        const v = req[i + 2 .. end];
        switch (code) {
            OPT_MSG_TYPE => if (len >= 1) {
                kind = v[0];
            },
            OPT_REQUESTED_IP => if (len >= 4) {
                requested = std.mem.readInt(u32, v[0..4], .big);
            },
            else => {},
        }
        i = end;
    }
    const say: u8 = switch (kind) {
        DISCOVER => OFFER,
        REQUEST => ACK,
        else => return null,
    };

    var mac: [6]u8 = undefined;
    @memcpy(&mac, req[28..34]);
    const peer = link.byMac(mac) orelse return null;
    // a device that asks for an address other than the one declared for
    // it is not argued with and not NAKed: it is answered with the one
    // it has, which is the only one this machine will ever give it
    if (requested) |r| if (r != peer.ip and say == ACK) return null;

    @memset(out, 0);
    out[0] = 2; // BOOTREPLY
    out[1] = 1;
    out[2] = 6;
    @memcpy(out[4..8], req[4..8]); // xid
    @memcpy(out[10..12], req[10..12]); // flags, broadcast bit included
    std.mem.writeInt(u32, out[16..20], peer.ip, .big); // yiaddr
    std.mem.writeInt(u32, out[20..24], link.self_ip, .big); // siaddr
    @memcpy(out[28..34], &mac);
    @memcpy(out[236..240], &dhcp_magic);

    var j: usize = 240;
    putOpt(out, &j, OPT_MSG_TYPE, &[_]u8{say});
    putIp(out, &j, OPT_SERVER_ID, link.self_ip);
    putIp(out, &j, OPT_MASK, link.mask);
    // the resolver is this machine: the names it serves are only here
    putIp(out, &j, OPT_DNS, link.self_ip);
    putOpt(out, &j, OPT_DOMAIN, link.domain);
    putOpt(out, &j, OPT_HOSTNAME, peer.name);
    // infinite: the address is this device's because it was DECLARED,
    // not because a timer has not run out yet
    var life: [4]u8 = undefined;
    std.mem.writeInt(u32, &life, forever, .big);
    putOpt(out, &j, OPT_LEASE, &life);
    // a router only when this machine IS one: a box that named itself the
    // way out without being one would be lying to every device on the link
    // (and one that forwards names itself the way to the links it joins; a
    // device that wants only some of them says so in its own EGRESS)
    if (link.router) |r| putIp(out, &j, OPT_ROUTER, r);
    out[j] = OPT_END;
    j += 1;
    return if (j < 300) 300 else j;
}

// ---- DNS -------------------------------------------------------------------

/// Read a question's QNAME into `buf` as dotted text. Returns the name
/// and the offset just past the question. Compression pointers are not
/// followed: a question never carries one.
fn question(pkt: []const u8, buf: []u8) ?struct { name: []const u8, end: usize } {
    if (pkt.len < 12) return null;
    var i: usize = 12;
    var n: usize = 0;
    while (i < pkt.len) {
        const l = pkt[i];
        if (l == 0) {
            i += 1;
            break;
        }
        if (l >= 0xC0) return null;
        if (i + 1 + l > pkt.len or n + l + 1 > buf.len) return null;
        if (n > 0) {
            buf[n] = '.';
            n += 1;
        }
        @memcpy(buf[n..][0..l], pkt[i + 1 ..][0..l]);
        n += l;
        i += 1 + l;
    }
    if (i + 4 > pkt.len) return null;
    return .{ .name = buf[0..n], .end = i + 4 };
}

/// Build the answer to one query. A name this machine does not serve is
/// NXDOMAIN, never a referral: the box speaks for its own link, and for
/// the links it is the way to, and is silent about the rest of the world.
fn answer(out: []u8, req: []const u8, link: Link) ?usize {
    if (req.len < 12) return null;
    if (req[2] & 0x80 != 0) return null; // already a response
    if (std.mem.readInt(u16, req[4..6], .big) != 1) return null; // one question
    var nbuf: [256]u8 = undefined;
    const q = question(req, &nbuf) orelse return null;
    const qtype = std.mem.readInt(u16, req[q.end - 4 ..][0..2], .big);
    const qclass = std.mem.readInt(u16, req[q.end - 2 ..][0..2], .big);
    if (qclass != 1) return null; // IN, and nothing else exists here

    const body = q.end;
    if (body + 16 > out.len) return null;
    @memcpy(out[0..body], req[0..body]);
    out[2] = 0x84 | (req[2] & 0x01); // response, authoritative, rd echoed
    out[3] = 0;
    std.mem.writeInt(u16, out[6..8], 0, .big); // ancount
    std.mem.writeInt(u16, out[8..10], 0, .big);
    std.mem.writeInt(u16, out[10..12], 0, .big);

    const ip = link.byName(q.name) orelse {
        out[3] = 3; // NXDOMAIN: there is no such name on this network
        return body;
    };
    if (qtype != 1) return body; // the name exists; this machine keeps no other record for it

    var i = body;
    std.mem.writeInt(u16, out[i..][0..2], 0xC00C, .big); // the question's own name
    std.mem.writeInt(u16, out[i + 2 ..][0..2], 1, .big); // A
    std.mem.writeInt(u16, out[i + 4 ..][0..2], 1, .big); // IN
    std.mem.writeInt(u32, out[i + 6 ..][0..4], 60, .big); // ttl
    std.mem.writeInt(u16, out[i + 10 ..][0..2], 4, .big);
    std.mem.writeInt(u32, out[i + 12 ..][0..4], ip, .big);
    i += 16;
    std.mem.writeInt(u16, out[6..8], 1, .big);
    return i;
}

/// Write a query for `name` (A, IN). Returns its length.
pub fn query(out: []u8, id: u16, name: []const u8) ?usize {
    if (name.len + 18 > out.len) return null;
    @memset(out[0..12], 0);
    std.mem.writeInt(u16, out[0..2], id, .big);
    out[2] = 0x00; // no recursion asked: the box that serves this link is the one that knows
    std.mem.writeInt(u16, out[4..6], 1, .big);
    var i: usize = 12;
    var it = std.mem.splitScalar(u8, name, '.');
    while (it.next()) |label| {
        if (label.len == 0 or label.len > 63) return null;
        out[i] = @intCast(label.len);
        @memcpy(out[i + 1 ..][0..label.len], label);
        i += 1 + label.len;
    }
    out[i] = 0;
    i += 1;
    std.mem.writeInt(u16, out[i..][0..2], 1, .big); // A
    std.mem.writeInt(u16, out[i + 2 ..][0..2], 1, .big); // IN
    return i + 4;
}

pub const Answer = union(enum) { address: u32, no_such_name, malformed };

/// Read a reply to `query`. One A record is all this machine ever sends
/// and all this reads.
pub fn readAnswer(pkt: []const u8, id: u16) Answer {
    if (pkt.len < 12) return .malformed;
    if (std.mem.readInt(u16, pkt[0..2], .big) != id) return .malformed;
    if (pkt[2] & 0x80 == 0) return .malformed;
    if (pkt[3] & 0x0F == 3) return .no_such_name;
    if (pkt[3] & 0x0F != 0) return .malformed;
    var nbuf: [256]u8 = undefined;
    const q = question(pkt, &nbuf) orelse return .malformed;
    const count = std.mem.readInt(u16, pkt[6..8], .big);
    if (count == 0) return .no_such_name;
    var i = q.end;
    var k: u16 = 0;
    while (k < count) : (k += 1) {
        // the name: a pointer, or labels
        if (i + 2 > pkt.len) return .malformed;
        if (pkt[i] >= 0xC0) {
            i += 2;
        } else {
            while (i < pkt.len and pkt[i] != 0) i += 1 + pkt[i];
            i += 1;
        }
        if (i + 10 > pkt.len) return .malformed;
        const rtype = std.mem.readInt(u16, pkt[i..][0..2], .big);
        const rdlen = std.mem.readInt(u16, pkt[i + 8 ..][0..2], .big);
        i += 10;
        if (i + rdlen > pkt.len) return .malformed;
        if (rtype == 1 and rdlen == 4) return .{ .address = std.mem.readInt(u32, pkt[i..][0..4], .big) };
        i += rdlen;
    }
    return .no_such_name;
}

/// What one question to this machine's own resolver came to: the reading of
/// /etc/resolv.conf and the query in ONE place, so that `ask` (which says what
/// a name means) and `get` (which then goes there) can never disagree about
/// where a name is asked. Linux only, like every act that opens a socket.
pub const Looked = union(enum) {
    /// the name's address, and the server that gave it
    address: struct { ip: u32, server: u32 },
    /// the server that said there is no such name
    no_such_name: u32,
    /// the server that never answered, in three tries
    silent: u32,
    /// /etc/resolv.conf does not exist: nobody told this machine where to ask
    never_told,
    /// /etc/resolv.conf exists and names no server
    names_none,
    /// the kernel would not give a socket (the errno's name)
    no_socket: []const u8,
    /// not a name a question can be asked for
    not_a_name,
};

pub fn lookup(arena: std.mem.Allocator, want: []const u8) Looked {
    const conf = std.fs.cwd().readFileAlloc(arena, "/etc/resolv.conf", 1 << 16) catch return .never_told;
    var server: ?u32 = null;
    var lines = std.mem.splitScalar(u8, conf, '\n');
    while (lines.next()) |line| {
        const t = std.mem.trim(u8, line, " \t\r");
        if (!std.mem.startsWith(u8, t, "nameserver ")) continue;
        if (machine.parseIpv4(std.mem.trim(u8, t["nameserver ".len..], " \t\r"))) |ip| {
            server = ip;
            break;
        }
    }
    const sip = server orelse return .names_none;
    const rc_sock = linux.socket(linux.AF.INET, linux.SOCK.DGRAM, 0);
    if (errOf(rc_sock) != .SUCCESS) return .{ .no_socket = @tagName(errOf(rc_sock)) };
    const fd: i32 = @intCast(rc_sock);
    defer _ = linux.close(fd);
    const tv: linux.timeval = .{ .sec = 3, .usec = 0 };
    _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.RCVTIMEO, @ptrCast(&tv), @sizeOf(linux.timeval));
    var sa = std.posix.sockaddr.in{
        .family = linux.AF.INET,
        .port = std.mem.nativeToBig(u16, 53),
        .addr = std.mem.nativeToBig(u32, sip),
        .zero = [_]u8{0} ** 8,
    };
    var qbuf: [512]u8 = undefined;
    const id: u16 = 0x5A5A;
    const qn = query(&qbuf, id, want) orelse return .not_a_name;
    var rbuf: [1500]u8 = undefined;
    var tries: u8 = 0;
    while (tries < 3) : (tries += 1) {
        _ = linux.sendto(fd, &qbuf, qn, 0, @ptrCast(&sa), @sizeOf(@TypeOf(sa)));
        const r = linux.recvfrom(fd, &rbuf, rbuf.len, 0, null, null);
        if (errOf(r) != .SUCCESS) continue;
        switch (readAnswer(rbuf[0..r], id)) {
            .address => |ip| return .{ .address = .{ .ip = ip, .server = sip } },
            .no_such_name => return .{ .no_such_name = sip },
            .malformed => continue,
        }
    }
    return .{ .silent = sip };
}

// ---- the loop --------------------------------------------------------------

/// Serve this link until the machine stops. Never returns. The process
/// that runs this says NOTHING on the console: the transcript is PID 1's
/// and a server answering at its own pace would make it a different file
/// every boot (the ordering discipline of BDG-1).
pub fn run(srv: Server, link: Link) noreturn {
    var fds = [2]linux.pollfd{
        .{ .fd = srv.dhcp_fd, .events = linux.POLL.IN, .revents = 0 },
        .{ .fd = srv.dns_fd, .events = linux.POLL.IN, .revents = 0 },
    };
    var rbuf: [1500]u8 = undefined;
    var dbuf: [576]u8 = undefined;
    var abuf: [1500]u8 = undefined;
    while (true) {
        fds[0].revents = 0;
        fds[1].revents = 0;
        const pr = linux.poll(&fds, 2, -1);
        if (errOf(pr) != .SUCCESS) continue;
        if (fds[0].revents & linux.POLL.IN != 0) {
            const r = linux.recvfrom(srv.dhcp_fd, &rbuf, rbuf.len, 0, null, null);
            if (errOf(r) == .SUCCESS) {
                if (reply(&dbuf, rbuf[0..r], link)) |n| {
                    // to the broadcast address: the device has no address
                    // yet, so it cannot be answered at one
                    const to = sockIn(0xFFFFFFFF, 68);
                    _ = linux.sendto(srv.dhcp_fd, &dbuf, n, 0, &to, @sizeOf(linux.sockaddr.in));
                }
            }
        }
        if (fds[1].revents & linux.POLL.IN != 0) {
            var from: linux.sockaddr = undefined;
            var flen: linux.socklen_t = @sizeOf(linux.sockaddr);
            const r = linux.recvfrom(srv.dns_fd, &rbuf, rbuf.len, 0, &from, &flen);
            if (errOf(r) == .SUCCESS) {
                if (answer(&abuf, rbuf[0..r], link)) |n| {
                    _ = linux.sendto(srv.dns_fd, &abuf, n, 0, &from, flen);
                }
            }
        }
    }
}

// ---- judged beside the code ------------------------------------------------

const testing = std.testing;

fn testLink() Link {
    const peers = &[_]machine.Peer{
        .{ .name = "imprimante", .line = 0, .network = "lan", .hardware = .{ 0xb8, 0x27, 0xeb, 0x11, 0x22, 0x33 }, .hardware_text = "b8:27:eb:11:22:33", .ip = 0xC0A80A32, .address = "192.168.10.50", .rationale = "" },
        .{ .name = "caisse", .line = 0, .network = "lan", .hardware = .{ 0xb8, 0x27, 0xeb, 0x44, 0x55, 0x66 }, .hardware_text = "b8:27:eb:44:55:66", .ip = 0xC0A80A28, .address = "192.168.10.40", .rationale = "" },
    };
    return .{ .self_ip = 0xC0A80A01, .mask = 0xFFFFFF00, .domain = "makeen", .peers = peers };
}

test "a declared device is answered with the address it was declared, and an undeclared one with silence" {
    const link = testLink();
    var req: [576]u8 = undefined;
    @memset(&req, 0);
    req[0] = 1;
    req[1] = 1;
    req[2] = 6;
    std.mem.writeInt(u32, req[4..8], 0xDEADBEEF, .big);
    @memcpy(req[28..34], &[_]u8{ 0xb8, 0x27, 0xeb, 0x11, 0x22, 0x33 });
    @memcpy(req[236..240], &dhcp_magic);
    req[240] = OPT_MSG_TYPE;
    req[241] = 1;
    req[242] = DISCOVER;
    req[243] = OPT_END;

    var out: [576]u8 = undefined;
    const n = reply(&out, req[0..300], link) orelse return error.NoOffer;
    try testing.expect(n >= 300);
    try testing.expectEqual(@as(u8, 2), out[0]);
    try testing.expectEqual(@as(u32, 0xDEADBEEF), std.mem.readInt(u32, out[4..8], .big));
    try testing.expectEqual(@as(u32, 0xC0A80A32), std.mem.readInt(u32, out[16..20], .big));

    // the same request from a device this machine was never told about
    @memcpy(req[28..34], &[_]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55 });
    try testing.expect(reply(&out, req[0..300], link) == null);
}

test "an offer carries the resolver and the domain, an infinite lease, and no router" {
    const link = testLink();
    var req: [576]u8 = undefined;
    @memset(&req, 0);
    req[0] = 1;
    req[1] = 1;
    req[2] = 6;
    @memcpy(req[28..34], &[_]u8{ 0xb8, 0x27, 0xeb, 0x44, 0x55, 0x66 });
    @memcpy(req[236..240], &dhcp_magic);
    req[240] = OPT_MSG_TYPE;
    req[241] = 1;
    req[242] = DISCOVER;
    req[243] = OPT_END;
    var out: [576]u8 = undefined;
    const n = reply(&out, req[0..300], link) orelse return error.NoOffer;

    var saw_dns: ?u32 = null;
    var saw_domain: ?[]const u8 = null;
    var saw_host: ?[]const u8 = null;
    var saw_lease: ?u32 = null;
    var saw_router = false;
    var i: usize = 240;
    while (i + 1 < n and out[i] != OPT_END) {
        const code = out[i];
        const len = out[i + 1];
        const v = out[i + 2 ..][0..len];
        switch (code) {
            OPT_DNS => saw_dns = std.mem.readInt(u32, v[0..4], .big),
            OPT_DOMAIN => saw_domain = v,
            OPT_HOSTNAME => saw_host = v,
            OPT_LEASE => saw_lease = std.mem.readInt(u32, v[0..4], .big),
            3 => saw_router = true,
            else => {},
        }
        i += 2 + @as(usize, len);
    }
    try testing.expectEqual(@as(u32, 0xC0A80A01), saw_dns.?);
    try testing.expectEqualStrings("makeen", saw_domain.?);
    try testing.expectEqualStrings("caisse", saw_host.?);
    try testing.expectEqual(forever, saw_lease.?);
    try testing.expect(!saw_router);
}

test "the box answers for its peers and for itself, and says there is no such name for anything else" {
    const link = testLink();
    var q: [512]u8 = undefined;
    var a: [512]u8 = undefined;

    for ([_][]const u8{ "imprimante.makeen", "imprimante", "IMPRIMANTE.Makeen" }) |name| {
        const qn = query(&q, 0x1234, name).?;
        const an = answer(&a, q[0..qn], link).?;
        switch (readAnswer(a[0..an], 0x1234)) {
            .address => |ip| try testing.expectEqual(@as(u32, 0xC0A80A32), ip),
            else => return error.NotAnswered,
        }
    }
    // the box itself IS the domain
    const qs = query(&q, 7, "makeen").?;
    const as = answer(&a, q[0..qs], link).?;
    switch (readAnswer(a[0..as], 7)) {
        .address => |ip| try testing.expectEqual(@as(u32, 0xC0A80A01), ip),
        else => return error.NotAnswered,
    }
    // and nothing else, not even a referral
    const qn = query(&q, 9, "elsewhere.makeen").?;
    const an = answer(&a, q[0..qn], link).?;
    try testing.expectEqual(Answer.no_such_name, readAnswer(a[0..an], 9));

    const qw = query(&q, 11, "www.example.com").?;
    const aw = answer(&a, q[0..qw], link).?;
    try testing.expectEqual(Answer.no_such_name, readAnswer(a[0..aw], 11));
}

test "an answer to another question is not an answer" {
    const link = testLink();
    var q: [512]u8 = undefined;
    var a: [512]u8 = undefined;
    const qn = query(&q, 0x1234, "imprimante.makeen").?;
    const an = answer(&a, q[0..qn], link).?;
    try testing.expectEqual(Answer.malformed, readAnswer(a[0..an], 0x9999));
}

// ---- a box that is the way between two links (FWD-1) ----------------------

fn farLink() Link {
    const peers = &[_]machine.Peer{
        .{ .name = "commons", .line = 0, .network = "core", .hardware = .{ 0x52, 0x54, 0x00, 0x12, 0x35, 0x62 }, .hardware_text = "52:54:00:12:35:62", .ip = 0x0A140002, .address = "10.20.0.2", .rationale = "" },
    };
    return .{ .self_ip = 0x0A140001, .mask = 0xFFFFFF00, .domain = "core.makeen", .peers = peers };
}

fn asked(link: Link, name: []const u8) !Answer {
    var q: [512]u8 = undefined;
    var a: [512]u8 = undefined;
    const qn = query(&q, 0x4321, name).?;
    const an = answer(&a, q[0..qn], link).?;
    return readAnswer(a[0..an], 0x4321);
}

test "a box that forwards offers itself as the router, and one that does not offers none" {
    var req: [576]u8 = undefined;
    @memset(&req, 0);
    req[0] = 1;
    req[1] = 1;
    req[2] = 6;
    @memcpy(req[28..34], &[_]u8{ 0xb8, 0x27, 0xeb, 0x44, 0x55, 0x66 });
    @memcpy(req[236..240], &dhcp_magic);
    req[240] = OPT_MSG_TYPE;
    req[241] = 1;
    req[242] = DISCOVER;
    req[243] = OPT_END;

    var plain = testLink();
    var out: [576]u8 = undefined;
    var n = reply(&out, req[0..300], plain) orelse return error.NoOffer;
    try testing.expect(routerOf(out[0..n]) == null);

    plain.router = plain.self_ip;
    n = reply(&out, req[0..300], plain) orelse return error.NoOffer;
    try testing.expectEqual(@as(?u32, 0xC0A80A01), routerOf(out[0..n]));
    // and an undeclared device is still told nothing, router or no router
    @memcpy(req[28..34], &[_]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55 });
    try testing.expect(reply(&out, req[0..300], plain) == null);
}

fn routerOf(offer: []const u8) ?u32 {
    var i: usize = 240;
    while (i + 1 < offer.len and offer[i] != OPT_END) {
        const code = offer[i];
        const len = offer[i + 1];
        if (code == OPT_ROUTER and len >= 4) return std.mem.readInt(u32, offer[i + 2 ..][0..4], .big);
        i += 2 + @as(usize, len);
    }
    return null;
}

test "a box that forwards answers for the full names on the links it is the way to, and for nothing else" {
    const far = farLink();
    var near = testLink();
    near.reach = &[_]Link{far};

    // its own link, as before
    switch (try asked(near, "imprimante.makeen")) {
        .address => |ip| try testing.expectEqual(@as(u32, 0xC0A80A32), ip),
        else => return error.NotAnswered,
    }
    // the other link's server is the box on that link, and its peer is its peer
    switch (try asked(near, "core.makeen")) {
        .address => |ip| try testing.expectEqual(@as(u32, 0x0A140001), ip),
        else => return error.NotAnswered,
    }
    switch (try asked(near, "commons.core.makeen")) {
        .address => |ip| try testing.expectEqual(@as(u32, 0x0A140002), ip),
        else => return error.NotAnswered,
    }
    switch (try asked(near, "COMMONS.Core.Makeen")) {
        .address => |ip| try testing.expectEqual(@as(u32, 0x0A140002), ip),
        else => return error.NotAnswered,
    }
    // a bare word is a name on THIS link: the same word on the far link is
    // another device, and is not answered here
    try testing.expectEqual(Answer.no_such_name, try asked(near, "commons"));
    // and a name nobody declared on either link is still no such name
    try testing.expectEqual(Answer.no_such_name, try asked(near, "ghost.core.makeen"));
    try testing.expectEqual(Answer.no_such_name, try asked(near, "www.example.com"));

    // a box that does not forward knows nothing of the far link, and says so
    try testing.expectEqual(Answer.no_such_name, try asked(testLink(), "commons.core.makeen"));
    try testing.expectEqual(Answer.no_such_name, try asked(testLink(), "core.makeen"));
}
