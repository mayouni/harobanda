// net.zig -- `stzos net <iface> <a.b.c.d>/<prefix> [gateway]` and
// `stzos net <iface> dhcp`: the same act PID 1 performs for a declared
// NETWORK (src/netcfg.zig), reachable by hand from the one binary. Every
// result stated. The parsing lives in machine.zig so the court judges it.

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");
const netcfg = @import("netcfg.zig");

pub fn run(arena: std.mem.Allocator, args: []const []const u8, out: *std.Io.Writer) !u8 {
    if (builtin.os.tag != .linux) {
        try out.print("net: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
        return 2;
    }
    if (args.len < 2) {
        try out.print("net: usage -- stzos net <iface> <a.b.c.d>/<prefix> [gateway] | stzos net <iface> dhcp\n", .{});
        return 1;
    }
    var n = machine.Network{
        .name = "cli",
        .line = 0,
        .interface = args[0],
        .address = .dhcp,
        .gateway = null,
        .dns = &.{},
        // by hand is by hand: this verb does what it is told and narrows
        // nothing. A reach is a machine's to declare (EGR-1).
        .egress = .unrestricted,
        .rationale = "",
    };
    if (!std.mem.eql(u8, args[1], "dhcp")) {
        const c = machine.parseCidr(args[1]) orelse {
            try out.print("net: '{s}' is not an address/prefix (a.b.c.d/n)\n", .{args[1]});
            return 1;
        };
        n.address = .{ .static = .{ .text = args[1], .ip = c.ip, .prefix = c.prefix } };
        if (args.len > 2) {
            const g = machine.parseIpv4(args[2]) orelse {
                try out.print("net: '{s}' is not an address (a.b.c.d)\n", .{args[2]});
                return 1;
            };
            n.gateway = .{ .text = args[2], .addr = g };
        }
    }
    _ = arena;
    return if (try netcfg.bringUp(&n, out, "net: ")) 0 else 2;
}

test "cidr and address parsing, with their negative siblings" {
    const ok = machine.parseCidr("192.168.10.1/24").?;
    try std.testing.expectEqual(@as(u32, 0xC0A80A01), ok.ip);
    try std.testing.expectEqual(@as(u6, 24), ok.prefix);
    try std.testing.expect(machine.parseCidr("192.168.10.1") == null);
    try std.testing.expect(machine.parseCidr("192.168.10/24") == null);
    try std.testing.expect(machine.parseCidr("192.168.10.1/33") == null);
    try std.testing.expect(machine.parseCidr("300.1.1.1/8") == null);
    try std.testing.expectEqual(@as(u32, 0x0A000202), machine.parseIpv4("10.0.2.2").?);
    try std.testing.expect(machine.parseIpv4("10.0.2") == null);
    try std.testing.expect(machine.parseIpv4("10.0.2.2/24") == null);
}
