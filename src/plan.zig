// plan.zig -- the boot plan, derived from a judged machine declaration.
// Pure: no allocation beyond the arena, no syscall. The plan is what
// `stzos plan` prints, what the court judges (service order, granted
// set), and what init.zig executes step by step. A plan is legible
// before it is run -- stzlib's stzUpdatePlan law (rehearse, narrate,
// then commit) carried down to the boot of a machine.

const std = @import("std");
const machine = @import("machine.zig");
const Machine = machine.Machine;

pub const Step = union(enum) {
    console: []const u8,
    slots: []const u8,
    mount: struct { at: []const u8, fs: machine.Fs, device: ?[]const u8, options: []const machine.MountOption, implicit: bool },
    capability: struct { name: machine.Capability, granted: bool },
    pin: struct { name: []const u8, gpio: u32, mode: machine.PinMode },
    network: *const machine.Network,
    service: *const machine.Service,
};

pub const Plan = struct {
    machine: *const Machine,
    steps: []const Step,

    /// The services in start order (the topological order the court judges).
    pub fn order(self: Plan, arena: std.mem.Allocator) ![]const []const u8 {
        var names: std.ArrayList([]const u8) = .{};
        for (self.steps) |s| if (s == .service) try names.append(arena, s.service.name);
        return names.toOwnedSlice(arena);
    }

    /// The granted capabilities, sorted by name (what the court judges).
    pub fn granted(self: Plan, arena: std.mem.Allocator) ![]const []const u8 {
        var names: std.ArrayList([]const u8) = .{};
        for (self.machine.capabilities) |c| if (c.granted) try names.append(arena, @tagName(c.name));
        const slice = try names.toOwnedSlice(arena);
        std.mem.sort([]const u8, slice, {}, lessThan);
        return slice;
    }
};

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

/// Derive the plan. Order: console, the profile's implicit mounts, the
/// declared mounts in declaration order, every capability (granted and
/// refused -- a refusal is a fact of the machine, stated not hidden), the
/// pins, then the services in AFTER order (declaration order breaks ties;
/// declare() already proved the order exists).
pub fn derive(arena: std.mem.Allocator, m: *const Machine) !Plan {
    var steps: std.ArrayList(Step) = .{};
    try steps.append(arena, .{ .console = m.console });
    if (m.slots) |dev| try steps.append(arena, .{ .slots = dev });

    if (m.profile == .hosted) {
        try steps.append(arena, .{ .mount = .{ .at = "/proc", .fs = .proc, .device = null, .options = &.{}, .implicit = true } });
        try steps.append(arena, .{ .mount = .{ .at = "/sys", .fs = .sysfs, .device = null, .options = &.{}, .implicit = true } });
        try steps.append(arena, .{ .mount = .{ .at = "/dev", .fs = .devtmpfs, .device = null, .options = &.{}, .implicit = true } });
    }
    for (m.mounts) |mt| try steps.append(arena, .{ .mount = .{ .at = mt.at, .fs = mt.fs, .device = mt.device, .options = mt.options, .implicit = false } });
    for (m.capabilities) |c| try steps.append(arena, .{ .capability = .{ .name = c.name, .granted = c.granted } });
    for (m.networks) |*n| try steps.append(arena, .{ .network = n });
    for (m.pins) |p| try steps.append(arena, .{ .pin = .{ .name = p.name, .gpio = p.gpio, .mode = p.mode } });

    const started = try arena.alloc(bool, m.services.len);
    @memset(started, false);
    var count: usize = 0;
    while (count < m.services.len) {
        var progressed = false;
        for (m.services, 0..) |*s, i| {
            if (started[i]) continue;
            var ready = true;
            for (s.after) |a| {
                for (m.services, 0..) |t, j| if (std.mem.eql(u8, t.name, a) and !started[j]) {
                    ready = false;
                };
            }
            if (ready) {
                started[i] = true;
                count += 1;
                progressed = true;
                try steps.append(arena, .{ .service = s });
                break;
            }
        }
        if (!progressed) return error.Cycle; // declare() refuses this earlier; kept as the mechanism's own guard
    }
    return .{ .machine = m, .steps = try steps.toOwnedSlice(arena) };
}

/// Render the plan as text, one step per line. This text is judged by the
/// human and, through `order`/`granted`, by the court; it is never stored
/// (the StzNarration law: outputs are rendered from the run, not kept).
pub fn render(plan: Plan, out: *std.Io.Writer) !void {
    const m = plan.machine;
    try out.print("machine {s} -- {s} / {s} / board {s} / kernel {s} / libc {s}\n", .{ m.name, @tagName(m.profile), @tagName(m.arch), @tagName(m.board), @tagName(m.kernel), @tagName(m.libc) });
    try out.print("  rationale: {s}\n", .{m.rationale});
    for (plan.steps) |s| switch (s) {
        .console => |c| try out.print("console {s}\n", .{c}),
        .slots => |dev| try out.print("slots on {s} -- A and B; the committed one boots, the other is tried under the watchdog\n", .{dev}),
        .mount => |mt| {
            try out.print("mount {s}", .{@tagName(mt.fs)});
            if (mt.device) |d| try out.print(" {s}", .{d});
            try out.print(" at {s}", .{mt.at});
            if (mt.options.len > 0) {
                try out.print(" [", .{});
                for (mt.options, 0..) |o, i| try out.print("{s}{s}", .{ if (i > 0) "," else "", @tagName(o) });
                try out.print("]", .{});
            }
            if (mt.implicit) try out.print(" (implicit, {s})", .{@tagName(m.profile)});
            try out.print("\n", .{});
        },
        .capability => |c| try out.print("{s} {s} ({s})\n", .{ if (c.granted) "grant" else "refuse", @tagName(c.name), @tagName(machine.kindOf(c.name)) }),
        .pin => |p| try out.print("pin {s} gpio {d} {s}\n", .{ p.name, p.gpio, @tagName(p.mode) }),
        .network => |n| {
            try out.print("network {s} -- {s} ", .{ n.name, n.interface });
            switch (n.address) {
                .dhcp => try out.print("dhcp", .{}),
                .static => |st| try out.print("static {s}", .{st.text}),
            }
            if (n.gateway) |g| try out.print(" gateway {s}", .{g.text});
            if (n.dns.len > 0) {
                try out.print(" dns [", .{});
                for (n.dns, 0..) |d, i| try out.print("{s}{s}", .{ if (i > 0) ", " else "", d.text });
                try out.print("]", .{});
            }
            try out.print("\n", .{});
        },
        .service => |svc| {
            try out.print("start {s} --", .{svc.name});
            for (svc.run) |w| try out.print(" {s}", .{w});
            try out.print(" -- restart {s}", .{@tagName(svc.restart)});
            if (svc.after.len > 0) {
                try out.print(" -- after [", .{});
                for (svc.after, 0..) |a, i| try out.print("{s}{s}", .{ if (i > 0) ", " else "", a });
                try out.print("]", .{});
            }
            if (svc.needs.len > 0) {
                try out.print(" -- needs [", .{});
                for (svc.needs, 0..) |n, i| try out.print("{s}{s}", .{ if (i > 0) ", " else "", @tagName(n) });
                try out.print("]", .{});
            }
            if (svc.ready) |r| try out.print(" -- ready on {s}", .{r});
            if (svc.user) |u| try out.print(" -- as {s} ({d}:{d})", .{ u.name, u.uid, u.gid });
            try out.print("\n", .{});
        },
    };
}

test "AFTER orders services, declaration order breaks ties" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var r = machine.Refusal{};
    const src =
        \\DEFINE MACHINE m AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE "x"
        \\DEFINE SERVICE c AS (RUN ["c"], AFTER [a, b]) RATIONALE "x"
        \\DEFINE SERVICE b AS (RUN ["b"], AFTER [a]) RATIONALE "x"
        \\DEFINE SERVICE a AS (RUN ["a"]) RATIONALE "x"
    ;
    const m = try machine.declare(arena, src, &r);
    const p = try derive(arena, &m);
    const o = try p.order(arena);
    try std.testing.expectEqual(@as(usize, 3), o.len);
    try std.testing.expectEqualStrings("a", o[0]);
    try std.testing.expectEqualStrings("b", o[1]);
    try std.testing.expectEqualStrings("c", o[2]);
}
