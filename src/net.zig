// net.zig -- `stzos net <iface> <addr>/<prefix>`: bring one interface up
// with one static address. A role of the one binary (the box's own
// service, declared in makeen_box.machine as RUN ["/stzos", "net", ...]),
// so the boot path still holds no third program. Four ioctls on a
// datagram socket, every result stated; no DHCP, no gateway, no DNS --
// those are the NETWORK kind's, queued (GRAMMAR.md, named seams).
//
// Linux-only by comptime gate, like init.zig; `zig build cross` is the
// gate that analyses it.

const std = @import("std");
const builtin = @import("builtin");

const is_linux = builtin.os.tag == .linux;

pub fn run(args: []const []const u8, out: *std.Io.Writer) !u8 {
    if (!is_linux) {
        try out.print("net: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
        return 2;
    }
    if (args.len < 2) {
        try out.print("net: usage -- stzos net <iface> <a.b.c.d>/<prefix>\n", .{});
        return 1;
    }
    return runLinux(args[0], args[1], out);
}

fn parseCidr(spec: []const u8) ?struct { ip: u32, prefix: u6 } {
    const slash = std.mem.indexOfScalar(u8, spec, '/') orelse return null;
    const prefix = std.fmt.parseInt(u6, spec[slash + 1 ..], 10) catch return null;
    if (prefix > 32) return null;
    var ip: u32 = 0;
    var it = std.mem.splitScalar(u8, spec[0..slash], '.');
    var n: usize = 0;
    while (it.next()) |part| : (n += 1) {
        if (n == 4) return null;
        const b = std.fmt.parseInt(u8, part, 10) catch return null;
        ip = (ip << 8) | b;
    }
    if (n != 4) return null;
    return .{ .ip = ip, .prefix = prefix };
}

fn runLinux(iface: []const u8, spec: []const u8, out: *std.Io.Writer) !u8 {
    const linux = std.os.linux;
    const cidr = parseCidr(spec) orelse {
        try out.print("net: '{s}' is not an address/prefix (a.b.c.d/n)\n", .{spec});
        return 1;
    };
    if (iface.len == 0 or iface.len >= linux.IFNAMESIZE) {
        try out.print("net: '{s}' is not an interface name\n", .{iface});
        return 1;
    }
    const fd_rc = linux.socket(linux.AF.INET, linux.SOCK.DGRAM, 0);
    switch (linux.E.init(fd_rc)) {
        .SUCCESS => {},
        else => |e| {
            try out.print("net: {s} -- no socket: {s} (the kernel has no INET?)\n", .{ iface, @tagName(e) });
            return 2;
        },
    }
    const fd: i32 = @intCast(fd_rc);
    defer _ = linux.close(fd);

    var ifr: linux.ifreq = std.mem.zeroes(linux.ifreq);
    @memcpy(ifr.ifrn.name[0..iface.len], iface);

    // does it exist?
    switch (linux.E.init(linux.ioctl(fd, linux.SIOCGIFFLAGS, @intFromPtr(&ifr)))) {
        .SUCCESS => {},
        .NODEV => {
            try out.print("net: {s} -- no such interface (NODEV)\n", .{iface});
            return 2;
        },
        else => |e| {
            try out.print("net: {s} -- flags refused: {s}\n", .{ iface, @tagName(e) });
            return 2;
        },
    }

    // the address, then the mask, then up
    var sin: linux.sockaddr.in = .{ .port = 0, .addr = std.mem.nativeToBig(u32, cidr.ip) };
    ifr.ifru.addr = @as(*const linux.sockaddr, @ptrCast(&sin)).*;
    switch (linux.E.init(linux.ioctl(fd, linux.SIOCSIFADDR, @intFromPtr(&ifr)))) {
        .SUCCESS => {},
        else => |e| {
            try out.print("net: {s} -- address refused: {s}\n", .{ iface, @tagName(e) });
            return 2;
        },
    }
    const mask: u32 = if (cidr.prefix == 0) 0 else ~@as(u32, 0) << @intCast(32 - @as(u8, cidr.prefix));
    sin.addr = std.mem.nativeToBig(u32, mask);
    ifr.ifru.netmask = @as(*const linux.sockaddr, @ptrCast(&sin)).*;
    switch (linux.E.init(linux.ioctl(fd, linux.SIOCSIFNETMASK, @intFromPtr(&ifr)))) {
        .SUCCESS => {},
        else => |e| {
            try out.print("net: {s} -- netmask refused: {s}\n", .{ iface, @tagName(e) });
            return 2;
        },
    }
    _ = linux.ioctl(fd, linux.SIOCGIFFLAGS, @intFromPtr(&ifr));
    ifr.ifru.flags.UP = true;
    switch (linux.E.init(linux.ioctl(fd, linux.SIOCSIFFLAGS, @intFromPtr(&ifr)))) {
        .SUCCESS => {},
        else => |e| {
            try out.print("net: {s} -- up refused: {s}\n", .{ iface, @tagName(e) });
            return 2;
        },
    }
    try out.print("net: {s} -- up, {s}\n", .{ iface, spec });
    return 0;
}

test "cidr parsing and its negative siblings" {
    const ok = parseCidr("192.168.10.1/24").?;
    try std.testing.expectEqual(@as(u32, 0xC0A80A01), ok.ip);
    try std.testing.expectEqual(@as(u6, 24), ok.prefix);
    try std.testing.expect(parseCidr("192.168.10.1") == null);
    try std.testing.expect(parseCidr("192.168.10/24") == null);
    try std.testing.expect(parseCidr("192.168.10.1/33") == null);
    try std.testing.expect(parseCidr("300.1.1.1/8") == null);
}
