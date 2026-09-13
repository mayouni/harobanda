// netcfg.zig -- bringing a declared NETWORK up. PID 1's act, like a mount:
// before any service runs, each NETWORK of the machine is configured here
// and every result is stated. Two ways to an address:
//
//   static  four ioctls on a datagram socket: exists, address, netmask, up;
//           a fifth (SIOCADDRT) for the default route when a GATEWAY is
//           declared
//   dhcp    a client of the protocol itself, in this file: DISCOVER,
//           OFFER, REQUEST, ACK over a broadcast UDP socket bound to the
//           interface, three tries, three seconds each; the lease's
//           address, mask, router and DNS servers are then applied as
//           the static case would
//
// No daemon, no lease renewal, no DNS resolver: the box takes its address
// once at boot (the seams are named in GRAMMAR.md). The emulator court
// judges the dhcp path against QEMU's user-mode network, whose built-in
// server leases 10.0.2.15 with router 10.0.2.2 and DNS 10.0.2.3 -- a
// deterministic oracle without hardware.
//
// Linux-only by comptime gate, like init.zig; `zig build cross` analyses it.

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");
const expect = @import("expect.zig");

const linux = std.os.linux;

// not in the Zig stdlib's linux tables
const SIOCGIFHWADDR: u32 = 0x8927;
const SIOCADDRT: u32 = 0x890B;
const RTF_UP: u16 = 0x0001;
const RTF_GATEWAY: u16 = 0x0002;

/// the kernel's struct rtentry (include/uapi/linux/route.h), 64-bit layout
const rtentry = extern struct {
    rt_pad1: usize = 0,
    rt_dst: linux.sockaddr,
    rt_gateway: linux.sockaddr,
    rt_genmask: linux.sockaddr,
    rt_flags: u16,
    rt_pad2: i16 = 0,
    rt_pad3: usize = 0,
    rt_pad4: ?*anyopaque = null,
    rt_metric: i16 = 0,
    rt_dev: ?[*:0]const u8 = null,
    rt_mtu: usize = 0,
    rt_window: usize = 0,
    rt_irtt: u16 = 0,
};

pub const Lease = struct {
    ip: u32,
    prefix: u6,
    gateway: ?u32,
    dns: [3]u32 = .{ 0, 0, 0 },
    ndns: u8 = 0,
};

fn sockIn(ip: u32, port: u16) linux.sockaddr {
    const sin: linux.sockaddr.in = .{ .port = std.mem.nativeToBig(u16, port), .addr = std.mem.nativeToBig(u32, ip) };
    return @as(*const linux.sockaddr, @ptrCast(&sin)).*;
}

fn errOf(rc: usize) linux.E {
    return linux.E.init(rc);
}

fn ifreqFor(name: []const u8) linux.ifreq {
    var ifr: linux.ifreq = std.mem.zeroes(linux.ifreq);
    @memcpy(ifr.ifrn.name[0..name.len], name);
    return ifr;
}

pub fn fmtIp(buf: []u8, ip: u32) []const u8 {
    return std.fmt.bufPrint(buf, "{d}.{d}.{d}.{d}", .{ ip >> 24 & 0xff, ip >> 16 & 0xff, ip >> 8 & 0xff, ip & 0xff }) catch "?";
}

/// Bring one declared network up and narrate it. Returns true when the
/// interface carries an address at the end.
pub fn bringUp(n: *const machine.Network, out: *std.Io.Writer, prefix: []const u8) !bool {
    if (builtin.os.tag != .linux) {
        try out.print("{s}network {s} -- {s}: a Linux act; this binary was built for {s}\n", .{ prefix, n.name, n.interface, @tagName(builtin.os.tag) });
        return false;
    }
    return bringUpLinux(n, out, prefix);
}

fn bringUpLinux(n: *const machine.Network, out: *std.Io.Writer, prefix: []const u8) !bool {
    const iface = n.interface;
    if (iface.len == 0 or iface.len >= linux.IFNAMESIZE) {
        try out.print("{s}network {s} -- '{s}' is not an interface name\n", .{ prefix, n.name, iface });
        return false;
    }
    const fd_rc = linux.socket(linux.AF.INET, linux.SOCK.DGRAM, 0);
    switch (errOf(fd_rc)) {
        .SUCCESS => {},
        else => |e| {
            try out.print("{s}network {s} -- {s}: no socket: {s} (the kernel has no INET?)\n", .{ prefix, n.name, iface, @tagName(e) });
            return false;
        },
    }
    const fd: i32 = @intCast(fd_rc);
    defer _ = linux.close(fd);

    var ifr = ifreqFor(iface);
    switch (errOf(linux.ioctl(fd, linux.SIOCGIFFLAGS, @intFromPtr(&ifr)))) {
        .SUCCESS => {},
        .NODEV => {
            try out.print(expect.fmt_network_nodev, .{ prefix, n.name, iface });
            return false;
        },
        else => |e| {
            try out.print("{s}network {s} -- {s}: flags refused: {s}\n", .{ prefix, n.name, iface, @tagName(e) });
            return false;
        },
    }

    const lease: Lease = switch (n.address) {
        .static => |s| .{ .ip = s.ip, .prefix = s.prefix, .gateway = if (n.gateway) |g| g.addr else null },
        .dhcp => blk: {
            // up first, without an address: DHCP speaks from 0.0.0.0
            if (!try setUp(fd, iface, out, prefix, n.name)) return false;
            const hw = hwaddr(fd, iface) orelse {
                try out.print("{s}network {s} -- {s} dhcp: no hardware address\n", .{ prefix, n.name, iface });
                return false;
            };
            break :blk (try dhcp(iface, hw, out, prefix, n.name)) orelse return false;
        },
    };

    // the address and the netmask
    ifr.ifru.addr = sockIn(lease.ip, 0);
    switch (errOf(linux.ioctl(fd, linux.SIOCSIFADDR, @intFromPtr(&ifr)))) {
        .SUCCESS => {},
        else => |e| {
            try out.print("{s}network {s} -- {s}: address refused: {s}\n", .{ prefix, n.name, iface, @tagName(e) });
            return false;
        },
    }
    const mask: u32 = if (lease.prefix == 0) 0 else ~@as(u32, 0) << @intCast(32 - @as(u8, lease.prefix));
    ifr.ifru.netmask = sockIn(mask, 0);
    switch (errOf(linux.ioctl(fd, linux.SIOCSIFNETMASK, @intFromPtr(&ifr)))) {
        .SUCCESS => {},
        else => |e| {
            try out.print("{s}network {s} -- {s}: netmask refused: {s}\n", .{ prefix, n.name, iface, @tagName(e) });
            return false;
        },
    }
    if (!try setUp(fd, iface, out, prefix, n.name)) return false;

    // The routes. What a machine may REACH is the declaration's to say
    // (EGR-1): with no EGRESS, a declared gateway becomes a default route
    // and the box can reach anything beyond its link, which is what every
    // machine did before this seat. With one, the default route is NOT
    // installed and each declared destination gets its own route instead
    // -- the box knows a way to those and to nowhere else. With `none`,
    // no route is added at all and the box knows no way off its own link.
    var gw_note: []const u8 = "";
    var gw_buf: [48]u8 = undefined;
    var egress_ok = true;
    switch (n.egress) {
        .none => {},
        .to => |dests| {
            for (dests) |dst| {
                const dmask: u32 = if (dst.prefix == 0) 0 else @as(u32, 0xFFFFFFFF) << @intCast(32 - @as(u6, dst.prefix));
                var rt: rtentry = .{
                    .rt_dst = sockIn(dst.ip, 0),
                    .rt_gateway = sockIn(lease.gateway orelse 0, 0),
                    .rt_genmask = sockIn(dmask, 0),
                    .rt_flags = if (lease.gateway != null) RTF_UP | RTF_GATEWAY else RTF_UP,
                };
                switch (errOf(linux.ioctl(fd, SIOCADDRT, @intFromPtr(&rt)))) {
                    .SUCCESS, .EXIST => {},
                    else => |e| {
                        egress_ok = false;
                        try out.print("{s}egress {s} -- {s}: the route refused: {s}\n", .{ prefix, n.name, dst.text, @tagName(e) });
                    },
                }
            }
        },
        .unrestricted => if (lease.gateway) |gw| {
            var rt: rtentry = .{
                .rt_dst = sockIn(0, 0),
                .rt_gateway = sockIn(gw, 0),
                .rt_genmask = sockIn(0, 0),
                .rt_flags = RTF_UP | RTF_GATEWAY,
            };
            var ipb: [16]u8 = undefined;
            const gws = fmtIp(&ipb, gw);
            switch (errOf(linux.ioctl(fd, SIOCADDRT, @intFromPtr(&rt)))) {
                .SUCCESS, .EXIST => gw_note = std.fmt.bufPrint(&gw_buf, ", gateway {s}", .{gws}) catch "",
                else => |e| gw_note = std.fmt.bufPrint(&gw_buf, ", gateway {s} REFUSED: {s}", .{ gws, @tagName(e) }) catch "",
            }
        },
    }

    var ipb: [16]u8 = undefined;
    try out.print("{s}network {s} -- {s} up {s}/{d}{s}", .{ prefix, n.name, iface, fmtIp(&ipb, lease.ip), lease.prefix, gw_note });
    if (n.address == .dhcp) {
        try out.print(" (dhcp)", .{});
        if (lease.ndns > 0) {
            try out.print(", dns [", .{});
            var i: u8 = 0;
            while (i < lease.ndns) : (i += 1) {
                var db: [16]u8 = undefined;
                try out.print("{s}{s}", .{ if (i > 0) ", " else "", fmtIp(&db, lease.dns[i]) });
            }
            try out.print("]", .{});
        }
    } else if (n.dns.len > 0) {
        try out.print(", dns [", .{});
        for (n.dns, 0..) |d, i| try out.print("{s}{s}", .{ if (i > 0) ", " else "", d.text });
        try out.print("]", .{});
    }
    try out.print("\n", .{});
    // the reach, said once and derived: a machine that declares none says
    // nothing here, and its transcript is what it always was
    if (egress_ok) _ = try expect.egressLine(out, n, prefix);
    return true;
}

fn setUp(fd: i32, iface: []const u8, out: *std.Io.Writer, prefix: []const u8, name: []const u8) !bool {
    var ifr = ifreqFor(iface);
    _ = linux.ioctl(fd, linux.SIOCGIFFLAGS, @intFromPtr(&ifr));
    ifr.ifru.flags.UP = true;
    switch (errOf(linux.ioctl(fd, linux.SIOCSIFFLAGS, @intFromPtr(&ifr)))) {
        .SUCCESS => return true,
        else => |e| {
            try out.print("{s}network {s} -- {s}: up refused: {s}\n", .{ prefix, name, iface, @tagName(e) });
            return false;
        },
    }
}

fn hwaddr(fd: i32, iface: []const u8) ?[6]u8 {
    var ifr = ifreqFor(iface);
    switch (errOf(linux.ioctl(fd, SIOCGIFHWADDR, @intFromPtr(&ifr)))) {
        .SUCCESS => {},
        else => return null,
    }
    var mac: [6]u8 = undefined;
    @memcpy(&mac, ifr.ifru.hwaddr.data[0..6]);
    return mac;
}

// ---- the DHCP client --------------------------------------------------------

const dhcp_magic = [4]u8{ 99, 130, 83, 99 };
const OPT_MASK = 1;
const OPT_ROUTER = 3;
const OPT_DNS = 6;
const OPT_REQUESTED_IP = 50;
const OPT_MSG_TYPE = 53;
const OPT_SERVER_ID = 54;
const OPT_PARAM_LIST = 55;
const OPT_END = 255;
const DISCOVER = 1;
const OFFER = 2;
const REQUEST = 3;
const ACK = 5;
const NAK = 6;

const Offer = struct { ip: u32, server: u32, mask: u32, router: ?u32, dns: [3]u32, ndns: u8, kind: u8 };

fn build(buf: *[576]u8, xid: u32, mac: [6]u8, kind: u8, requested: ?u32, server: ?u32) usize {
    @memset(buf, 0);
    buf[0] = 1; // BOOTREQUEST
    buf[1] = 1; // ethernet
    buf[2] = 6; // hlen
    std.mem.writeInt(u32, buf[4..8], xid, .big);
    std.mem.writeInt(u16, buf[10..12], 0x8000, .big); // broadcast flag: the reply comes to 255.255.255.255
    @memcpy(buf[28..34], &mac);
    @memcpy(buf[236..240], &dhcp_magic);
    var i: usize = 240;
    buf[i] = OPT_MSG_TYPE;
    buf[i + 1] = 1;
    buf[i + 2] = kind;
    i += 3;
    if (requested) |r| {
        buf[i] = OPT_REQUESTED_IP;
        buf[i + 1] = 4;
        std.mem.writeInt(u32, buf[i + 2 ..][0..4], r, .big);
        i += 6;
    }
    if (server) |s| {
        buf[i] = OPT_SERVER_ID;
        buf[i + 1] = 4;
        std.mem.writeInt(u32, buf[i + 2 ..][0..4], s, .big);
        i += 6;
    }
    buf[i] = OPT_PARAM_LIST;
    buf[i + 1] = 3;
    buf[i + 2] = OPT_MASK;
    buf[i + 3] = OPT_ROUTER;
    buf[i + 4] = OPT_DNS;
    i += 5;
    buf[i] = OPT_END;
    i += 1;
    // BOOTP minimum: pad to 300 bytes
    return if (i < 300) 300 else i;
}

fn parse(pkt: []const u8, xid: u32) ?Offer {
    if (pkt.len < 244 or pkt[0] != 2) return null;
    if (std.mem.readInt(u32, pkt[4..8], .big) != xid) return null;
    if (!std.mem.eql(u8, pkt[236..240], &dhcp_magic)) return null;
    var o = Offer{ .ip = std.mem.readInt(u32, pkt[16..20], .big), .server = 0, .mask = 0, .router = null, .dns = .{ 0, 0, 0 }, .ndns = 0, .kind = 0 };
    var i: usize = 240;
    while (i + 1 < pkt.len) {
        const code = pkt[i];
        if (code == OPT_END) break;
        if (code == 0) {
            i += 1;
            continue;
        }
        const len = pkt[i + 1];
        const start = i + 2;
        const end = start + len;
        if (end > pkt.len) break;
        const v = pkt[start..end];
        switch (code) {
            OPT_MSG_TYPE => if (len >= 1) {
                o.kind = v[0];
            },
            OPT_MASK => if (len >= 4) {
                o.mask = std.mem.readInt(u32, v[0..4], .big);
            },
            OPT_ROUTER => if (len >= 4) {
                o.router = std.mem.readInt(u32, v[0..4], .big);
            },
            OPT_DNS => {
                var k: usize = 0;
                while (k + 4 <= len and o.ndns < 3) : (k += 4) {
                    o.dns[o.ndns] = std.mem.readInt(u32, v[k..][0..4], .big);
                    o.ndns += 1;
                }
            },
            OPT_SERVER_ID => if (len >= 4) {
                o.server = std.mem.readInt(u32, v[0..4], .big);
            },
            else => {},
        }
        i = end;
    }
    if (o.kind == 0) return null;
    return o;
}

fn dhcp(iface: []const u8, mac: [6]u8, out: *std.Io.Writer, prefix: []const u8, name: []const u8) !?Lease {
    const fd_rc = linux.socket(linux.AF.INET, linux.SOCK.DGRAM, 0);
    switch (errOf(fd_rc)) {
        .SUCCESS => {},
        else => |e| {
            try out.print("{s}network {s} -- {s} dhcp: no socket: {s}\n", .{ prefix, name, iface, @tagName(e) });
            return null;
        },
    }
    const fd: i32 = @intCast(fd_rc);
    defer _ = linux.close(fd);
    const one: i32 = 1;
    _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.BROADCAST, @ptrCast(&one), @sizeOf(i32));
    _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.REUSEADDR, @ptrCast(&one), @sizeOf(i32));
    _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.BINDTODEVICE, iface.ptr, @intCast(iface.len));
    const tv: linux.timeval = .{ .sec = 3, .usec = 0 };
    _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.RCVTIMEO, @ptrCast(&tv), @sizeOf(linux.timeval));
    const local = sockIn(0, 68);
    switch (errOf(linux.bind(fd, &local, @sizeOf(linux.sockaddr.in)))) {
        .SUCCESS => {},
        else => |e| {
            try out.print("{s}network {s} -- {s} dhcp: bind refused: {s}\n", .{ prefix, name, iface, @tagName(e) });
            return null;
        },
    }
    const bcast = sockIn(0xffffffff, 67);
    var xid: u32 = @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())));
    xid ^= @as(u32, @intCast(linux.getpid())) << 16;

    var pkt: [576]u8 = undefined;
    var rbuf: [1024]u8 = undefined;
    var attempt: u8 = 0;
    while (attempt < 3) : (attempt += 1) {
        // DISCOVER
        const n = build(&pkt, xid, mac, DISCOVER, null, null);
        _ = linux.sendto(fd, &pkt, n, 0, &bcast, @sizeOf(linux.sockaddr.in));
        var offer: ?Offer = null;
        var deadline: u8 = 0;
        while (deadline < 2 and offer == null) : (deadline += 1) {
            const r = linux.recvfrom(fd, &rbuf, rbuf.len, 0, null, null);
            switch (errOf(r)) {
                .SUCCESS => {},
                .AGAIN => break, // timed out
                else => break,
            }
            if (parse(rbuf[0..r], xid)) |o| if (o.kind == OFFER) {
                offer = o;
            };
        }
        const o = offer orelse continue;
        // REQUEST what was offered
        const n2 = build(&pkt, xid, mac, REQUEST, o.ip, o.server);
        _ = linux.sendto(fd, &pkt, n2, 0, &bcast, @sizeOf(linux.sockaddr.in));
        var tries: u8 = 0;
        while (tries < 2) : (tries += 1) {
            const r = linux.recvfrom(fd, &rbuf, rbuf.len, 0, null, null);
            switch (errOf(r)) {
                .SUCCESS => {},
                else => break,
            }
            const a = parse(rbuf[0..r], xid) orelse continue;
            if (a.kind == ACK) {
                return .{ .ip = a.ip, .prefix = @intCast(@popCount(a.mask)), .gateway = a.router, .dns = a.dns, .ndns = a.ndns };
            }
            if (a.kind == NAK) break;
        }
    }
    try out.print("{s}network {s} -- {s} dhcp: no lease after 3 tries (no server answered on this network)\n", .{ prefix, name, iface });
    return null;
}
