//! The ports a world may bind, and no other (PORT-1): what PID 1 holds a world to before the exec,
//! and what a world reads back from inside.
//!
//! A port below 1024 is the kernel's to give: it refuses the bind to any task without
//! `CAP_NET_BIND_SERVICE`, ONE capability for all of them. A declaration says a world may bind 443,
//! so the floor gives the capability -- kept through the drop of identity (`keepCaps`), made the
//! task's only one and raised into its ambient set (`raiseBind`), which an exec keeps even under
//! no_new_privs -- and HOLDS the world to the ports it declared with a Landlock rule set
//! (`restrict`): TCP bind is handled, the declared ports are allowed, and every other port is
//! refused with EACCES, below 1024 or above. The capability alone would be a grant to every port
//! below 1024 under a line that named one (EGR-2's shape); the rule set is what makes the line true.
//! Both are set on the task that will exec the world, after the filter (Landlock needs the
//! no_new_privs the filter set) and around the drop to its USER.
//!
//! `harb bound` is the witness: a world asks the kernel, as the identity it runs as, to bind each
//! port it was told it may and each it was told it may not, and asserts the answers -- exit 1 on a
//! wrong one, as `own` does, so the machine's own judge convicts the boot (JDG-1).

const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;

/// Landlock, as the kernel's uapi names it: the one access this seat handles, the ruleset's
/// version query, and the rule kind that names a port.
pub const LANDLOCK_ACCESS_NET_BIND_TCP: u64 = 1 << 0;
const LANDLOCK_CREATE_RULESET_VERSION: usize = 1;
const LANDLOCK_RULE_NET_PORT: usize = 2;
const RulesetAttr = extern struct { handled_access_fs: u64, handled_access_net: u64 };
const NetPortAttr = extern struct { allowed_access: u64, port: u64 };

/// The Landlock ABI this kernel speaks: 0 when it speaks none. Network rules came with ABI 4.
pub fn landlockAbi() u32 {
    if (builtin.os.tag != .linux) return 0;
    const rc = linux.syscall3(.landlock_create_ruleset, 0, 0, LANDLOCK_CREATE_RULESET_VERSION);
    return switch (linux.E.init(rc)) {
        .SUCCESS => @intCast(rc),
        else => 0,
    };
}

/// Hold the CALLING task to `ports`: it may bind these TCP ports, and no other -- above 1024 or
/// below. Null when the kernel holds it; otherwise the kernel's own word for why it cannot, which
/// PID 1 prints beside NOT STARTED.
pub fn restrict(ports: []const u16) ?[]const u8 {
    if (builtin.os.tag != .linux) return "not linux";
    const abi = landlockAbi();
    if (abi == 0) return "no landlock";
    if (abi < 4) return "landlock without network rules";
    const attr = RulesetAttr{ .handled_access_fs = 0, .handled_access_net = LANDLOCK_ACCESS_NET_BIND_TCP };
    const made = linux.syscall3(.landlock_create_ruleset, @intFromPtr(&attr), @sizeOf(RulesetAttr), 0);
    if (linux.E.init(made) != .SUCCESS) return @tagName(linux.E.init(made));
    const fd: usize = made;
    defer _ = linux.close(@intCast(fd));
    for (ports) |p| {
        const rule = NetPortAttr{ .allowed_access = LANDLOCK_ACCESS_NET_BIND_TCP, .port = p };
        const added = linux.syscall4(.landlock_add_rule, fd, LANDLOCK_RULE_NET_PORT, @intFromPtr(&rule), 0);
        if (linux.E.init(added) != .SUCCESS) return @tagName(linux.E.init(added));
    }
    const held = linux.syscall2(.landlock_restrict_self, fd, 0);
    if (linux.E.init(held) != .SUCCESS) return @tagName(linux.E.init(held));
    return null;
}

/// Whether any of the ports is one the kernel gives only with a capability.
pub fn needsPrivilege(ports: []const u16) bool {
    for (ports) |p| if (p < 1024) return true;
    return false;
}

const PR_CAP_AMBIENT_RAISE: usize = 2;
const LINUX_CAPABILITY_VERSION_3: u32 = 0x20080522;

/// Before the identity is dropped: keep the permitted capabilities across the setuid, which would
/// otherwise clear them all. Null when kept; the kernel's word otherwise.
pub fn keepCaps() ?[]const u8 {
    if (builtin.os.tag != .linux) return "not linux";
    const rc = linux.prctl(@intFromEnum(linux.PR.SET_KEEPCAPS), 1, 0, 0, 0);
    return if (linux.E.init(rc) == .SUCCESS) null else @tagName(linux.E.init(rc));
}

/// After the identity is dropped: make `CAP_NET_BIND_SERVICE` the task's only capability --
/// permitted, effective and inheritable -- and raise it into the ambient set, which the exec keeps.
/// Null when raised; the kernel's word otherwise.
pub fn raiseBind() ?[]const u8 {
    if (builtin.os.tag != .linux) return "not linux";
    var hdr = linux.cap_user_header_t{ .version = LINUX_CAPABILITY_VERSION_3, .pid = 0 };
    const bit: u32 = 1 << linux.CAP.NET_BIND_SERVICE;
    // version 3 carries two words of 32 capabilities each; the one that matters is in the first
    const data = [2]linux.cap_user_data_t{
        .{ .effective = bit, .permitted = bit, .inheritable = bit },
        .{ .effective = 0, .permitted = 0, .inheritable = 0 },
    };
    const set = linux.capset(&hdr, &data[0]);
    if (linux.E.init(set) != .SUCCESS) return @tagName(linux.E.init(set));
    const raised = linux.prctl(@intFromEnum(linux.PR.CAP_AMBIENT), PR_CAP_AMBIENT_RAISE, linux.CAP.NET_BIND_SERVICE, 0, 0);
    if (linux.E.init(raised) != .SUCCESS) return @tagName(linux.E.init(raised));
    return null;
}

/// What the kernel answered a bind: let, or its own word for why not.
pub const Answer = union(enum) {
    allowed,
    refused: []const u8,
};

/// Ask to bind a TCP socket to `port` on every address, and give it back at once.
pub fn tryBind(port: u16) Answer {
    if (builtin.os.tag != .linux) return .{ .refused = "not linux" };
    const made = linux.socket(linux.AF.INET, linux.SOCK.STREAM | linux.SOCK.CLOEXEC, 0);
    if (linux.E.init(made) != .SUCCESS) return .{ .refused = @tagName(linux.E.init(made)) };
    const fd: i32 = @intCast(made);
    defer _ = linux.close(fd);
    const one: u32 = 1;
    _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.REUSEADDR, @ptrCast(&one), @sizeOf(u32));
    const addr = linux.sockaddr.in{ .port = std.mem.nativeToBig(u16, port), .addr = 0 };
    const rc = linux.bind(fd, @ptrCast(&addr), @sizeOf(linux.sockaddr.in));
    return if (linux.E.init(rc) == .SUCCESS) .allowed else .{ .refused = @tagName(linux.E.init(rc)) };
}

/// `harb bound <port>... [--not <port>]...`: bind each port before `--not`, and be refused each after.
pub fn run(args: []const []const u8, out: *std.Io.Writer) !u8 {
    var must: [16]u16 = undefined;
    var n_must: usize = 0;
    var not: [16]u16 = undefined;
    var n_not: usize = 0;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        var into: *[16]u16 = &must;
        var count: *usize = &n_must;
        if (std.mem.eql(u8, args[i], "--not")) {
            if (i + 1 >= args.len) {
                try out.print("bound: --not takes a port\n", .{});
                return 2;
            }
            i += 1;
            into = &not;
            count = &n_not;
        }
        const p = std.fmt.parseInt(u16, args[i], 10) catch 0;
        if (p == 0) {
            try out.print("bound: '{s}' is not a port (1 to 65535)\n", .{args[i]});
            return 2;
        }
        if (count.* == into.len) {
            try out.print("bound: takes at most {d} ports on each side\n", .{into.len});
            return 2;
        }
        into[count.*] = p;
        count.* += 1;
    }
    if (n_must == 0 and n_not == 0) {
        try out.print("bound: takes <port>... [--not <port>]...\n", .{});
        return 2;
    }
    if (builtin.os.tag != .linux) {
        try out.print("bound: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
        return 2;
    }
    const uid = linux.getuid();
    var wrong = false;
    for (must[0..n_must]) |p| switch (tryBind(p)) {
        .allowed => try out.print("bound: {d} -- bound as uid {d}: the kernel let this world bind it\n", .{ p, uid }),
        .refused => |why| {
            wrong = true;
            try out.print("bound: {d} -- REFUSED ({s}) as uid {d}: this world was told it may bind it, and the kernel did not let it\n", .{ p, why, uid });
        },
    };
    for (not[0..n_not]) |p| switch (tryBind(p)) {
        .refused => |why| try out.print("bound: {d} -- refused ({s}) as uid {d}: the kernel did not let this world bind it\n", .{ p, why, uid }),
        .allowed => {
            wrong = true;
            try out.print("bound: {d} -- BOUND as uid {d}: this world was told it may NOT bind it, and the kernel let it\n", .{ p, uid });
        },
    };
    if (wrong) {
        try out.print("bound: an answer was NOT the one this world was told to expect\n", .{});
        return 1;
    }
    try out.print("bound: every answer was the one this world was told to expect\n", .{});
    return 0;
}

// ---- judged beside the code -------------------------------------------

test "a port below 1024 needs the kernel's privilege, one above does not (PORT-1)" {
    try std.testing.expect(needsPrivilege(&.{443}));
    try std.testing.expect(needsPrivilege(&.{ 8443, 80 }));
    try std.testing.expect(!needsPrivilege(&.{ 8210, 8443 }));
    try std.testing.expect(!needsPrivilege(&.{}));
}

/// What a child answers: 0 when, held to port 18443 and no other, it bound 18443 and was refused
/// 18444; 4 when the kernel speaks no Landlock with network rules (the question cannot be asked
/// here); 1 when the rule set did not hold.
fn childHeldToOnePort() u8 {
    if (landlockAbi() < 4) return 4;
    // Landlock needs no_new_privs, as the floor's filter sets it before this
    _ = linux.prctl(@intFromEnum(linux.PR.SET_NO_NEW_PRIVS), 1, 0, 0, 0);
    if (restrict(&.{18443}) != null) return 4;
    if (tryBind(18443) != .allowed) return 1;
    if (tryBind(18444) == .allowed) return 1;
    return 0;
}

test "a world held to one port binds it and is refused the next one, by the kernel (PORT-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const pid = try std.posix.fork();
    if (pid == 0) linux.exit(childHeldToOnePort());
    var status: u32 = 0;
    _ = linux.wait4(pid, &status, 0, null);
    if (status & 0x7f != 0) return error.ChildKilled;
    const answer: u8 = @intCast((status >> 8) & 0xff);
    if (answer == 4) return error.SkipZigTest;
    try std.testing.expectEqual(@as(u8, 0), answer);
}

/// What a child answers about the privilege: it drops to an ordinary identity the way PID 1 does
/// -- keeping its capabilities, becoming uid 65534, raising the one for the ports -- and binds
/// a port below 1024; 0 when the kernel let it, 4 when the question cannot be asked here (not
/// root), 1 when the kernel refused it.
fn childDropsAndBinds() u8 {
    if (linux.getuid() != 0) return 4;
    if (keepCaps() != null) return 1;
    if (linux.E.init(linux.setgid(65534)) != .SUCCESS) return 4;
    if (linux.E.init(linux.setuid(65534)) != .SUCCESS) return 4;
    if (raiseBind() != null) return 1;
    return if (tryBind(1023) == .allowed) 0 else 1;
}

/// The control: the same drop with nothing raised, which must be refused the port.
fn childDropsAndIsRefused() u8 {
    if (linux.getuid() != 0) return 4;
    if (linux.E.init(linux.setgid(65534)) != .SUCCESS) return 4;
    if (linux.E.init(linux.setuid(65534)) != .SUCCESS) return 4;
    return if (tryBind(1023) == .allowed) 1 else 0;
}

fn askInAChild(f: *const fn () u8) !u8 {
    const pid = try std.posix.fork();
    if (pid == 0) linux.exit(f());
    var status: u32 = 0;
    _ = linux.wait4(pid, &status, 0, null);
    if (status & 0x7f != 0) return error.ChildKilled;
    return @intCast((status >> 8) & 0xff);
}

test "the privilege for a port below 1024 is kept through the drop of identity and raised, and without it the port is refused (PORT-1)" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const control = try askInAChild(childDropsAndIsRefused);
    if (control == 4) return error.SkipZigTest; // not root here: the question cannot be asked
    try std.testing.expectEqual(@as(u8, 0), control);
    try std.testing.expectEqual(@as(u8, 0), try askInAChild(childDropsAndBinds));
}
