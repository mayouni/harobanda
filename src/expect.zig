// expect.zig -- the boot, expected and judged by the machine itself (JDG-1).
//
// Until today every boot was judged from OUTSIDE: QEMU's serial transcript,
// normalised and diffed against machines/<name>.expected by a script. The
// machine did not know what its own boot should look like, so an A/B trial
// was committed on "every service is ready" and nothing else -- and the
// Makeen box's emulated trial committed with its network refused NODEV.
//
// This module closes the loop. `harb image` DERIVES the init lines a
// faithful boot prints -- from the plan and a LENS: the board's, or the
// emulator's, which lacks what the board has and says so per line -- and
// the image carries them as /etc/expected. PID 1 records what it says, and
// when every service is ready it judges its own ledger against that text,
// in its own words. A trial commits only on a match; a boot that differs
// names the lines, is not committed, and the next boot is the committed
// slot. The expectation, the ledger and the verdict are the same text a
// person reads on the console and an agent reads in the pinned transcript.
//
// Two rules keep the comparison honest without a timer or a diff:
//   - the pids the kernel hands out are normalised to N; `pid 1` stays
//     literal, because that init IS PID 1 is a claim the judge must be
//     able to convict (the script's judge keeps it for the same reason);
//   - a line the declaration cannot fully know (a dhcp lease) ends in `*`
//     in the expectation and matches by prefix. Nothing else is loose.
// The lines are compared as a SET, not a sequence: AFTER already enforces
// the order that matters, and two daemons signalling ready in either order
// are the same boot.
//
// Each judged line is worded ONCE, here: init prints with these and
// derive() writes the same. A line worded twice would drift, and a drift
// is exactly the false alarm a self-judging machine must never raise.

const std = @import("std");
const machine = @import("machine.zig");
const confine = @import("confine.zig");
const plan = @import("plan.zig");

pub const fmt_banner = "boot: harb init -- machine {s} ({s} / {s} / {s}) -- pid {d}{s}\n";
pub const fmt_console = "boot: console {s}\n";
/// PID 1 asked the kernel which device its console really is (TIOCGDEV)
/// and it is not the declared one: said, never smoothed over (CON-1). On a
/// card it is a boot that differs from its file; under the emulator's lens,
/// where QEMU cannot carry the board's port, it is the lack itself.
pub const fmt_console_elsewhere = "boot: console {s} -- declared, and the kernel speaks on {s}\n";
/// the kernel would not say: nothing is claimed, so nothing matches
pub const fmt_console_unknown = "boot: console {s} -- declared, and the kernel would not say which device it speaks on\n";
pub const fmt_slots = "boot: slots on {s} -- A and B\n";
pub const fmt_mount_done = "boot: mount {s} at {s} -- done\n";
pub const fmt_capability = "boot: {s} {s} ({s})\n";
pub const fmt_pin = "boot: pin {s} gpio {d} {s} -- declared; the hosted profile drives pins through the gpio capability of its services\n";
pub const fmt_network_nodev = "{s}network {s} -- {s}: no such interface (NODEV)\n";
pub const fmt_watchdog_armed = "boot: watchdog armed (/dev/watchdog)\n";
pub const fmt_watchdog_off = "boot: watchdog -- off by the boot line (the emulator resets on arming); a trial cannot roll back by hardware here\n";
pub const fmt_exited = "boot: {s} (pid {s}) exited {d}\n";
pub const fmt_ready = "boot: {s} -- ready ({s})\n";

/// the start line, in pieces: the service, its pid, its words, its identity
pub fn startLine(w: *std.Io.Writer, s: *const machine.Service, pid: []const u8) !void {
    try w.print("boot: start {s} -- pid {s} --", .{ s.name, pid });
    for (s.run) |word| try w.print(" {s}", .{word});
    if (s.user) |u| try w.print(" -- as {s} ({d}:{d})", .{ u.name, u.uid, u.gid });
    try w.print("\n", .{});
}

/// The standing HEALTH line: which worlds must keep saying they serve,
/// and how often. Worded ONCE here, like every judged line -- init
/// prints it and derive() writes it. Returns false when no world
/// declares a window, and then nothing is said at all.
pub fn healthLine(w: *std.Io.Writer, m: *const machine.Machine) !bool {
    var any = false;
    for (m.services) |s| {
        if (s.health != null) any = true;
    }
    if (!any) return false;
    try w.print("boot: health -- ", .{});
    var first = true;
    for (m.services) |s| {
        if (s.health) |h| {
            try w.print("{s}{s} every {d}s", .{ if (first) "" else ", ", s.name, h });
            first = false;
        }
    }
    try w.print("; a world that stops refreshing stops the watchdog\n", .{});
    return true;
}

/// The standing FORWARD line (FWD-1): which networks this machine is the
/// way between, and what it does not do. Worded ONCE here, like every
/// judged line -- init prints it once the kernel has been asked, and
/// derive() writes it. A machine that does not forward says nothing, and
/// its transcript is what it always was.
///
/// "Nothing here filters it" is the half of the claim a reader would
/// otherwise assume the other way: forwarding is decided by the interface
/// a packet ARRIVES on, so the kernel keeps no perimeter between the
/// networks a machine joins, and this machine does not keep one for it.
pub fn forwardLine(w: *std.Io.Writer, m: *const machine.Machine) !bool {
    if (!m.forward) return false;
    try w.print("boot: forward -- between ", .{});
    // the links, not a loopback: it is declared and it is not a way to anywhere
    const links = machine.countLinks(m.networks);
    var i: usize = 0;
    for (m.networks) |n| {
        if (machine.isLoopback(n)) continue;
        const sep = if (i == 0) "" else if (i + 1 == links) " and " else ", ";
        try w.print("{s}{s}", .{ sep, n.name });
        i += 1;
    }
    try w.print(": a packet that arrives on one may leave by another, and nothing here filters it\n", .{});
    return true;
}

/// This device's own name, said once. The FINGERPRINT is the one thing
/// a declaration cannot know -- it is made on the device, from the
/// device's own randomness, and a machine that could derive it from its
/// file would not have an identity at all -- so the derived line ends in
/// the wildcard and the transcript carries the rest. Everything before
/// it IS derived, and says what a reader needs: the algorithm and the
/// custody, never implied (MicroRing's law: the record names its
/// algorithm rather than assuming one).
pub fn identityLine(w: *std.Io.Writer, m: *const machine.Machine) !bool {
    const path = m.identity orelse return false;
    try w.print("boot: identity -- ed25519, custody a file at {s} -- *\n", .{path});
    return true;
}

/// What the KERNEL holds each world to, derived from its NEEDS and from
/// nothing else (NS-1). A world that declared everything this can refuse
/// says nothing here, and its transcript is what it always was.
pub fn confineLine(w: *std.Io.Writer, m: *const machine.Machine) !bool {
    // an arena, because a world that NARROWS its sight (SEE-1) needs the
    // complement of what it named built somewhere
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var any = false;
    for (m.services) |s| {
        if ((try confine.Confinement.ofAlloc(m.*, s, a)).confined()) any = true;
    }
    if (!any) return false;
    try w.print("boot: confine -- ", .{});
    var first = true;
    for (m.services) |s| {
        const c = try confine.Confinement.ofAlloc(m.*, s, a);
        if (!c.confined()) continue;
        var buf: [256]u8 = undefined;
        try w.print("{s}{s} has {s}", .{ if (first) "" else ", ", s.name, c.words(&buf) });
        first = false;
    }
    try w.print("; what a world did not declare, the kernel does not give it\n", .{});
    return true;
}

/// The standing BUDGET line: which worlds the kernel holds to a ceiling,
/// and to what. Worded ONCE here, like every judged line. Returns false
/// when no world declares one, and then nothing is said at all.
/// What no world may do, whatever it declared (SYS-1). Said once per
/// machine rather than once per world, because it is a fact about the
/// FLOOR and not about any declaration: the same sentence on every
/// machine, and a machine with no worlds has nobody to say it to.
pub fn floorLine(w: *std.Io.Writer, m: *const machine.Machine) !bool {
    if (m.services.len == 0) return false;
    try w.print("boot: floor -- the machine is not a world's to change: none may mount or unmount, set the clock, load a module, rename the host, make or enter a namespace, trace another process, or reboot the box\n", .{});
    return true;
}

pub fn budgetLine(w: *std.Io.Writer, m: *const machine.Machine) !bool {
    var any = false;
    for (m.services) |s| {
        if (s.memory_mb != null or s.cpu_percent != null or s.tasks != null) any = true;
    }
    if (!any) return false;
    try w.print("boot: budget -- ", .{});
    var first = true;
    for (m.services) |s| {
        if (s.memory_mb == null and s.cpu_percent == null and s.tasks == null) continue;
        try w.print("{s}{s} ", .{ if (first) "" else ", ", s.name });
        first = false;
        var said = false;
        if (s.memory_mb) |mb| {
            try w.print("{d} MiB", .{mb});
            said = true;
        }
        if (s.cpu_percent) |pct| {
            if (said) try w.print(" and ", .{});
            try w.print("{d}% of a core", .{pct});
            said = true;
        }
        if (s.tasks) |n| {
            if (said) try w.print(" and ", .{});
            try w.print("{d} tasks", .{n});
        }
    }
    try w.print("; the kernel holds the ceiling, not the world\n", .{});
    return true;
}

/// The EGRESS line: how far a granted network reaches. Worded ONCE
/// here, like every judged line -- netcfg prints it and derive() writes
/// it. Nothing is said for a network that declares no reach, so every
/// machine written before this seat has the transcript it always had.
/// The lines a machine says when it is its link's own server of names
/// (NAM-1): one for the link, one for every peer it will answer for.
///
/// The per-peer lines are here on purpose. The register of who has which
/// address is the thing a vendor's box keeps in a file and loses at a
/// reboot; here it is in the DECLARATION, so the boot can read it out in
/// full and the transcript that is judged carries it. An auditor reading
/// this file knows every device the network will admit.
pub fn namesLines(w: *std.Io.Writer, m: *const machine.Machine, n: *const machine.Network, prefix: []const u8) !bool {
    const dom = n.domain orelse return false;
    const self = switch (n.address) {
        .static => |s| s.text,
        .dhcp => return false,
    };
    var count: usize = 0;
    for (m.peers) |p| if (std.mem.eql(u8, p.network, n.name)) {
        count += 1;
    };
    try w.print("{s}names {s} -- {s}: this machine is {s}, {d} declared peer{s}, and no address for anyone else\n", .{
        prefix, n.name, dom, self, count, if (count == 1) "" else "s",
    });
    for (m.peers) |p| if (std.mem.eql(u8, p.network, n.name)) {
        try w.print("{s}names {s} -- {s}.{s} is {s} for {s}\n", .{ prefix, n.name, p.name, dom, p.address, p.hardware_text });
    };
    // A machine that is the way between its networks (FWD-1) is offered to
    // everyone it serves as the router, and speaks for the other links it
    // serves too -- by their full names, through itself, and for nothing else.
    // Said here, beside the server's own lines, because it is the server that
    // does it and a reader of this transcript has to be able to see the extent.
    if (m.forward) {
        try w.print("{s}names {s} -- this machine forwards, so it is offered as the router to everyone it serves here\n", .{ prefix, n.name });
        for (m.networks) |o| {
            if (std.mem.eql(u8, o.name, n.name) or machine.isLoopback(o)) continue;
            const odom = o.domain orelse continue;
            const oself: u32 = switch (o.address) {
                .static => |s| s.ip,
                .dhcp => continue,
            };
            var ob: [16]u8 = undefined;
            try w.print("{s}names {s} -- and for {s}, which this machine is the way to: {s} is {s}\n", .{ prefix, n.name, odom, odom, fmtIp(&ob, oself) });
            for (m.peers) |p| if (std.mem.eql(u8, p.network, o.name)) {
                try w.print("{s}names {s} -- {s}.{s} is {s}, through this machine\n", .{ prefix, n.name, p.name, odom, p.address });
            };
        }
    }
    return true;
}

pub fn egressLine(w: *std.Io.Writer, n: *const machine.Network, prefix: []const u8) !bool {
    switch (n.egress) {
        .unrestricted => return false,
        .none => {
            try w.print("{s}egress {s} -- none: the machine knows no way off its own link\n", .{ prefix, n.name });
            return true;
        },
        .to => |dests| {
            // A destination whose prefix is 0 IS a default route:
            // 0.0.0.0/0 through the declared gateway is bit for bit what
            // `unrestricted` installs. Announcing "and nowhere else: no
            // default route" over one would claim a perimeter the
            // machine is not keeping -- the same defect as NS-1 with the
            // sign flipped, since here the boot UNDERSTATES what the box
            // can reach. Found by a reader doing lesson 11 of the tour,
            // where `EGRESS ["0.0.0.0/0"]` made 8.8.8.8 reachable while
            // this line still said there was no way there.
            //
            // STZ-OS-RULING-06 then made the grammar REFUSE such a list,
            // in any spelling, so a declared machine never reaches this
            // branch. It stays, asking the grammar's own function: a boot
            // line must never be the place a coverage rule is re-derived.
            const everywhere = machine.coversEverything(dests);
            try w.print("{s}egress {s} -- ", .{ prefix, n.name });
            for (dests, 0..) |d, i| try w.print("{s}{s}", .{ if (i > 0) ", " else "", d.text });
            if (everywhere) {
                try w.print(": a DEFAULT route, so this machine knows a way anywhere\n", .{});
            } else {
                try w.print(" and nowhere else: no default route\n", .{});
            }
            return true;
        },
    }
}

pub const Watchdog = enum { armed, off };

/// Through which eyes the boot is expected. The board's lens is the
/// default: everything declared comes up. The emulator's lens names what
/// the emulator lacks, one field per lack, so the difference between the
/// two derived texts IS the list of the emulator's lacks -- printed at
/// build time, never inferred from a failing boot.
pub const Lens = struct {
    watchdog: Watchdog = .armed,
    /// the emulator has no NIC behind the declared interface: NODEV
    network_absent: bool = false,
    /// the device the emulator's kernel speaks on, when QEMU cannot carry
    /// the board's port (the rpi4's mini-UART): a declared console is then
    /// said to be elsewhere (CON-1)
    console: ?[]const u8 = null,

    /// whether this is an emulator's lens at all
    pub fn isEmulator(self: Lens) bool {
        return self.network_absent or self.watchdog == .off or self.console != null;
    }
};

fn fmtIp(buf: *[16]u8, ip: u32) []const u8 {
    return std.fmt.bufPrint(buf, "{d}.{d}.{d}.{d}", .{ ip >> 24 & 0xff, ip >> 16 & 0xff, ip >> 8 & 0xff, ip & 0xff }) catch "?";
}

/// The init lines a faithful boot prints, up to the point where every
/// service is ready -- the point where PID 1 judges and, on a trial,
/// commits. What comes after (the exits of daemons, the halt) is the
/// court's to judge, not the machine's.
pub fn derive(arena: std.mem.Allocator, p: plan.Plan, lens: Lens) ![]const u8 {
    var aw = std.Io.Writer.Allocating.init(arena);
    const w = &aw.writer;
    const m = p.machine;
    try w.print(fmt_banner, .{ m.name, @tagName(m.profile), @tagName(m.arch), @tagName(m.board), @as(i32, 1), "" });
    for (p.steps) |step| switch (step) {
        .console => |c| {
            // the kernel's own /dev/console names no port, so there is no
            // elsewhere for it to be; a declared port the emulator cannot
            // carry is said to be where the emulator's kernel speaks
            if (lens.console) |seen| {
                if (!std.mem.eql(u8, c, "/dev/console") and !std.mem.eql(u8, c, seen)) {
                    try w.print(fmt_console_elsewhere, .{ c, seen });
                    continue;
                }
            }
            try w.print(fmt_console, .{c});
        },
        .slots => |dev| try w.print(fmt_slots, .{dev}),
        .mount => |mt| try w.print(fmt_mount_done, .{ @tagName(mt.fs), mt.at }),
        .capability => |c| try w.print(fmt_capability, .{ if (c.granted) "grant" else "refuse", @tagName(c.name), @tagName(machine.kindOf(c.name)) }),
        .pin => |pn| try w.print(fmt_pin, .{ pn.name, pn.gpio, @tagName(pn.mode) }),
        .network => |n| {
            if (lens.network_absent) {
                try w.print(fmt_network_nodev, .{ "boot: ", n.name, n.interface });
            } else switch (n.address) {
                // the lease is the server's to give: the line is known up to it
                .dhcp => try w.print("boot: network {s} -- {s} up *\n", .{ n.name, n.interface }),
                // netcfg.zig prints the address it set, piece by piece; this
                // is the same wording, with the declared values in its place
                .static => |s| {
                    var ipb: [16]u8 = undefined;
                    try w.print("boot: network {s} -- {s} up {s}/{d}", .{ n.name, n.interface, fmtIp(&ipb, s.ip), s.prefix });
                    // a gateway becomes a default route only where no
                    // EGRESS narrows it; with one, the line says the
                    // address and the egress line says the reach
                    if (n.egress == .unrestricted) {
                        if (n.gateway) |g| {
                            var gb: [16]u8 = undefined;
                            try w.print(", gateway {s}", .{fmtIp(&gb, g.addr)});
                        }
                    }
                    if (n.dns.len > 0) {
                        try w.print(", dns [", .{});
                        for (n.dns, 0..) |d, i| try w.print("{s}{s}", .{ if (i > 0) ", " else "", d.text });
                        try w.print("]", .{});
                    }
                    try w.print("\n", .{});
                },
            }
            _ = try egressLine(w, n, "boot: ");
            // a machine with no NIC behind the declared interface cannot
            // be that link's server: under the emulator's lens it says
            // nothing here, and that difference is the emulator's lack
            if (!lens.network_absent) _ = try namesLines(w, m, n, "boot: ");
        },
        // the way between the networks, once every one of them is up
        .forward => _ = try forwardLine(w, m),
        .service => {},
    };
    // the slot's own state (a trial, or steady) is the CARD's to say, not
    // the declaration's: it is not expected and init does not record it.
    // The watchdog is: armed on the board, off in the emulator's lens.
    if (m.slots != null) switch (lens.watchdog) {
        .armed => try w.writeAll(fmt_watchdog_armed),
        .off => try w.writeAll(fmt_watchdog_off),
    };
    _ = try identityLine(w, m);
    _ = try budgetLine(w, m);
    _ = try healthLine(w, m);
    _ = try confineLine(w, m);
    _ = try floorLine(w, m);
    // every service starts; a one-shot is ready when it has exited 0, a
    // daemon when spawned or, if it declares READY, when it has signalled
    for (p.steps) |step| if (step == .service) {
        const s = step.service;
        try startLine(w, s, "N");
        switch (s.restart) {
            .never => try w.print(fmt_exited, .{ s.name, "N", @as(u32, 0) }),
            .always, .on_failure => if (s.ready) |path| try w.print(fmt_ready, .{ s.name, path }),
        }
    };
    return aw.written();
}

/// `pid <digits>` -> `pid N`, except `pid 1`, which stays literal
pub fn normalisePids(src: []const u8, dst: []u8) []const u8 {
    var o: usize = 0;
    var i: usize = 0;
    while (i < src.len and o < dst.len) {
        if (i + 4 < src.len and std.mem.eql(u8, src[i .. i + 4], "pid ") and std.ascii.isDigit(src[i + 4])) {
            var j = i + 4;
            while (j < src.len and std.ascii.isDigit(src[j])) : (j += 1) {}
            const rep: []const u8 = if (std.mem.eql(u8, src[i + 4 .. j], "1")) "pid 1" else "pid N";
            const n = @min(rep.len, dst.len - o);
            @memcpy(dst[o .. o + n], rep[0..n]);
            o += n;
            i = j;
            continue;
        }
        dst[o] = src[i];
        o += 1;
        i += 1;
    }
    return dst[0..o];
}

/// the same line: pids normalised on both sides, a trailing `*` on the
/// expected side matching whatever the world put there
pub fn same(expected: []const u8, said: []const u8) bool {
    var eb: [1024]u8 = undefined;
    var sb: [1024]u8 = undefined;
    const e = normalisePids(expected, &eb);
    const s = normalisePids(said, &sb);
    if (e.len > 0 and e[e.len - 1] == '*') return std.mem.startsWith(u8, s, e[0 .. e.len - 1]);
    return std.mem.eql(u8, e, s);
}

pub const Verdict = struct {
    expected: usize,
    said: usize,
    /// expected, not said
    missing: []const []const u8,
    /// said, not expected
    unexpected: []const []const u8,

    pub fn matches(v: Verdict) bool {
        return v.missing.len == 0 and v.unexpected.len == 0;
    }
};

fn lines(arena: std.mem.Allocator, text: []const u8) ![]const []const u8 {
    var list: std.ArrayList([]const u8) = .{};
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw| {
        const l = std.mem.trimRight(u8, raw, "\r");
        if (l.len > 0) try list.append(arena, l);
    }
    return list.toOwnedSlice(arena);
}

/// Judge what init said against what was expected: each expected line must
/// have been said once, and nothing else said. Order is not judged (AFTER
/// is enforced by init, not by this); count is.
pub fn judge(arena: std.mem.Allocator, expected: []const u8, said: []const u8) !Verdict {
    const exp = try lines(arena, expected);
    const got = try lines(arena, said);
    const used = try arena.alloc(bool, got.len);
    @memset(used, false);
    var missing: std.ArrayList([]const u8) = .{};
    var unexpected: std.ArrayList([]const u8) = .{};
    for (exp) |e| {
        var found = false;
        for (got, 0..) |s, i| {
            if (used[i]) continue;
            if (same(e, s)) {
                used[i] = true;
                found = true;
                break;
            }
        }
        if (!found) try missing.append(arena, e);
    }
    for (got, 0..) |s, i| if (!used[i]) try unexpected.append(arena, s);
    return .{
        .expected = exp.len,
        .said = got.len,
        .missing = try missing.toOwnedSlice(arena),
        .unexpected = try unexpected.toOwnedSlice(arena),
    };
}

/// The same judge, run from the HOST against a captured transcript
/// (OS-5). The machine judges its own ledger as it boots; this judges
/// the text a serial cable carried away, and the two are independent
/// witnesses to the same boot -- which is the whole reason to keep both.
///
/// A captured transcript is not a ledger: it carries the kernel's own
/// lines, the worlds' output, and the console-only lines PID 1 says
/// about the card (a trial, a commit, its verdict). So the comparison is
/// one-sided on purpose. Every EXPECTED line must have been said, and a
/// missing one is a finding; everything else the machine said is
/// printed, not judged, because a real boot legitimately says more than
/// its expectation.
pub fn judgeTranscript(arena: std.mem.Allocator, p: plan.Plan, lens: Lens, text: []const u8, label: []const u8, out: *std.Io.Writer) !u8 {
    const expected = try derive(arena, p, lens);
    const exp = try lines(arena, expected);

    // what PID 1 said, pulled out of whatever else rode on the wire: a
    // line may carry a firmware or kernel prefix, so the line starts
    // where `boot: ` starts. Its own verdict lines quote OTHER lines and
    // are never evidence (GRT-1).
    var said: std.ArrayList([]const u8) = .{};
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw| {
        const l = std.mem.trimRight(u8, raw, "\r");
        const at = std.mem.indexOf(u8, l, "boot: ") orelse continue;
        const line = l[at..];
        if (std.mem.startsWith(u8, line, "boot: judge --")) continue;
        try said.append(arena, line);
    }

    try out.print("judge {s} -- the boot this machine EXPECTS ({s} lens, {d} lines), against {s}\n", .{
        p.machine.name,
        if (lens.isEmulator()) "emulator" else "board",
        exp.len,
        label,
    });

    const used = try arena.alloc(bool, said.items.len);
    @memset(used, false);
    var missing: usize = 0;
    for (exp) |e| {
        var found = false;
        for (said.items, 0..) |g, i| {
            if (used[i]) continue;
            if (same(e, g)) {
                used[i] = true;
                found = true;
                break;
            }
        }
        if (!found) {
            if (missing == 0) try out.print("  EXPECTED, NOT SAID:\n", .{});
            missing += 1;
            try out.print("    {s}\n", .{bare(e)});
        }
    }
    if (missing == 0) try out.print("  every expected line was said\n", .{});

    var extra: usize = 0;
    for (said.items, 0..) |g, i| {
        if (used[i]) continue;
        if (extra == 0) try out.print("  ... and the machine also said (its own, not part of the expectation):\n", .{});
        extra += 1;
        try out.print("    {s}\n", .{bare(g)});
    }

    try out.print("{d} of {d} expected lines said\n", .{ exp.len - missing, exp.len });
    return if (missing == 0) 0 else 1;
}

/// a line as the verdict quotes it: without the `boot: ` the console shows
pub fn bare(line: []const u8) []const u8 {
    return if (std.mem.startsWith(u8, line, "boot: ")) line["boot: ".len..] else line;
}

// ---- tests: the derivation pinned, the judge and its negatives ------------

const box_src =
    \\DEFINE MACHINE box AS (
    \\  PROFILE hosted, ARCH aarch64, KERNEL linux, LIBC musl, BOARD rpi4,
    \\  CONSOLE "/dev/ttyS1", SLOTS "/dev/mmcblk0p1"
    \\) RATIONALE "the expectation, derived"
    \\DEFINE CAPABILITY network AS ( GRANT yes ) RATIONALE "wire"
    \\DEFINE CAPABILITY gpio AS ( GRANT no ) RATIONALE "no pins"
    \\DEFINE MOUNT data AS ( AT "/data", FS ext4, DEVICE "/dev/mmcblk0p2" ) RATIONALE "disk"
    \\DEFINE NETWORK lan AS ( INTERFACE "eth0", ADDRESS "192.168.10.1/24", GATEWAY "192.168.10.254", DNS ["1.1.1.1"] ) RATIONALE "static"
    \\DEFINE USER world AS ( UID 1000 ) RATIONALE "an identity"
    \\DEFINE SERVICE once AS ( RUN ["/harb", "id"], RESTART never, NEEDS [network], USER world ) RATIONALE "a one-shot"
    \\DEFINE SERVICE serve AS ( RUN ["/stzr", "/app/serve.luau"], RESTART always, AFTER [once], NEEDS [network], READY "/run/serve.ready", HEALTH 3 ) RATIONALE "a daemon"
    \\
;

fn boxPlan(arena: std.mem.Allocator) !plan.Plan {
    var refusal = machine.Refusal{};
    const m = try arena.create(machine.Machine);
    m.* = machine.declare(arena, box_src, &refusal) catch |e| {
        std.debug.print("refused (line {d}): {s}\n", .{ refusal.line, refusal.message });
        return e;
    };
    return plan.derive(arena, m);
}

test "the board's expectation is derived from the declaration, line for line" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const p = try boxPlan(arena);
    const text = try derive(arena, p, .{});
    try std.testing.expectEqualStrings(
        \\boot: harb init -- machine box (hosted / aarch64 / rpi4) -- pid 1
        \\boot: console /dev/ttyS1
        \\boot: slots on /dev/mmcblk0p1 -- A and B
        \\boot: mount proc at /proc -- done
        \\boot: mount sysfs at /sys -- done
        \\boot: mount devtmpfs at /dev -- done
        \\boot: mount ext4 at /data -- done
        \\boot: grant network (effectful)
        \\boot: refuse gpio (effectful)
        \\boot: network lan -- eth0 up 192.168.10.1/24, gateway 192.168.10.254, dns [1.1.1.1]
        \\boot: watchdog armed (/dev/watchdog)
        \\boot: health -- serve every 3s; a world that stops refreshing stops the watchdog
        \\boot: confine -- once has no sight of the other worlds and no way to start one and no sight of /data, serve has no sight of the other worlds and no way to start one and no sight of /data; what a world did not declare, the kernel does not give it
        \\boot: floor -- the machine is not a world's to change: none may mount or unmount, set the clock, load a module, rename the host, make or enter a namespace, trace another process, or reboot the box
        \\boot: start once -- pid N -- /harb id -- as world (1000:1000)
        \\boot: once (pid N) exited 0
        \\boot: start serve -- pid N -- /stzr /app/serve.luau
        \\boot: serve -- ready (/run/serve.ready)
        \\
    , text);
}

test "the emulator's lens differs from the board's exactly where the emulator lacks the hardware" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const p = try boxPlan(arena);
    const board = try derive(arena, p, .{});
    // the rpi4's lens: no NIC, no watchdog it may arm, and no mini-UART it
    // can carry, so its kernel speaks on the PL011 (CON-1)
    const emu = try derive(arena, p, .{ .watchdog = .off, .network_absent = true, .console = "/dev/ttyAMA0" });
    const v = try judge(arena, board, emu);
    try std.testing.expectEqual(@as(usize, 3), v.missing.len);
    try std.testing.expectEqual(@as(usize, 3), v.unexpected.len);
    try std.testing.expectEqualStrings("boot: console /dev/ttyS1", v.missing[0]);
    try std.testing.expectEqualStrings("boot: network lan -- eth0 up 192.168.10.1/24, gateway 192.168.10.254, dns [1.1.1.1]", v.missing[1]);
    try std.testing.expectEqualStrings("boot: watchdog armed (/dev/watchdog)", v.missing[2]);
    try std.testing.expectEqualStrings("boot: console /dev/ttyS1 -- declared, and the kernel speaks on /dev/ttyAMA0", v.unexpected[0]);
    try std.testing.expectEqualStrings("boot: network lan -- eth0: no such interface (NODEV)", v.unexpected[1]);
    try std.testing.expectEqualStrings(std.mem.trimRight(u8, fmt_watchdog_off, "\n"), v.unexpected[2]);
}

test "a lens that cannot carry the declared console has no elsewhere for /dev/console" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var refusal = machine.Refusal{};
    const m = try arena.create(machine.Machine);
    m.* = try machine.declare(arena, "DEFINE MACHINE d AS ( PROFILE hosted, ARCH aarch64, KERNEL linux, BOARD rpi4 ) RATIONALE \"the default console\"\n", &refusal);
    const p = try plan.derive(arena, m);
    // the kernel's own console names no port, so the emulator's lens has
    // nothing to say it is elsewhere from: the line is the same in both
    const board = try derive(arena, p, .{});
    const emu = try derive(arena, p, .{ .console = "/dev/ttyAMA0" });
    try std.testing.expect(std.mem.indexOf(u8, board, "boot: console /dev/console\n") != null);
    try std.testing.expectEqualStrings(board, emu);
}

test "a boot that said the expected lines matches, whatever pids the kernel gave and in whatever order daemons signalled" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const expected =
        \\boot: harb init -- machine m (hosted / x86_64 / qemu_pc) -- pid 1
        \\boot: start a -- pid N -- /a
        \\boot: a -- ready (/run/a)
        \\boot: start b -- pid N -- /b
        \\boot: b -- ready (/run/b)
        \\
    ;
    const said =
        \\boot: harb init -- machine m (hosted / x86_64 / qemu_pc) -- pid 1
        \\boot: start a -- pid 17 -- /a
        \\boot: start b -- pid 18 -- /b
        \\boot: b -- ready (/run/b)
        \\boot: a -- ready (/run/a)
        \\
    ;
    const v = try judge(arena, expected, said);
    try std.testing.expect(v.matches());
    try std.testing.expectEqual(@as(usize, 5), v.expected);
    try std.testing.expectEqual(@as(usize, 5), v.said);
}

test "a line said twice, a line not said, a line not expected: each is named" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const expected = "boot: mount ext4 at /data -- done\nboot: start a -- pid N -- /a\nboot: a (pid N) exited 0\n";
    const said = "boot: mount ext4 at /data -- refused by the kernel: NODEV\nboot: start a -- pid 5 -- /a\nboot: a (pid 5) exited 1\nboot: restart a (on_failure, 1/5) -- pid 6\nboot: a (pid 6) exited 0\n";
    const v = try judge(arena, expected, said);
    try std.testing.expect(!v.matches());
    try std.testing.expectEqual(@as(usize, 1), v.missing.len);
    try std.testing.expectEqualStrings("boot: mount ext4 at /data -- done", v.missing[0]);
    try std.testing.expectEqual(@as(usize, 3), v.unexpected.len);
    try std.testing.expectEqualStrings("boot: mount ext4 at /data -- refused by the kernel: NODEV", v.unexpected[0]);
    try std.testing.expectEqualStrings("boot: a (pid 5) exited 1", v.unexpected[1]);
    try std.testing.expectEqualStrings("boot: restart a (on_failure, 1/5) -- pid 6", v.unexpected[2]);
}

test "a dhcp lease matches by prefix; pid 1 is never normalised away" {
    try std.testing.expect(same("boot: network lan -- eth0 up *", "boot: network lan -- eth0 up 10.0.2.15/24, gateway 10.0.2.2 (dhcp), dns [10.0.2.3]"));
    try std.testing.expect(!same("boot: network lan -- eth0 up *", "boot: network lan -- eth0: no such interface (NODEV)"));
    try std.testing.expect(same("boot: start a -- pid N -- /a", "boot: start a -- pid 4711 -- /a"));
    try std.testing.expect(!same("boot: harb init -- pid 1", "boot: harb init -- pid 2"));
    try std.testing.expect(same("boot: harb init -- pid 1", "boot: harb init -- pid 1"));
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("a (pid N) and pid 1 and pid N.", normalisePids("a (pid 12) and pid 1 and pid 100.", &buf));
}

const two_links =
    \\DEFINE MACHINE gw AS (PROFILE hosted, ARCH x86_64, KERNEL linux, FORWARD yes) RATIONALE "x"
    \\DEFINE CAPABILITY network AS (GRANT yes) RATIONALE "x"
    \\DEFINE NETWORK front AS (INTERFACE "eth0", ADDRESS "192.168.20.1/24") RATIONALE "x"
    \\DEFINE NETWORK core AS (INTERFACE "eth1", ADDRESS "10.20.0.1/24") RATIONALE "x"
    \\
;

test "a machine that is the way between networks names them all, once, after the last is up; one that is not says nothing" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const forwards = try arena.create(machine.Machine);
    var refusal = machine.Refusal{};
    forwards.* = try machine.declare(arena, two_links, &refusal);
    const text = try derive(arena, try plan.derive(arena, forwards), .{});
    const n_front = std.mem.indexOf(u8, text, "boot: network front -- eth0 up 192.168.20.1/24\n").?;
    const n_core = std.mem.indexOf(u8, text, "boot: network core -- eth1 up 10.20.0.1/24\n").?;
    const fwd = std.mem.indexOf(u8, text, "boot: forward -- between front and core: a packet that arrives on one may leave by another, and nothing here filters it\n").?;
    try std.testing.expect(n_front < n_core and n_core < fwd);
    // once, however many networks
    try std.testing.expectEqual(std.mem.indexOf(u8, text, "boot: forward --").?, std.mem.lastIndexOf(u8, text, "boot: forward --").?);

    // three networks are joined with commas and an "and", the way every
    // other list in a boot line is
    const src3 = try std.fmt.allocPrint(arena, "{s}DEFINE NETWORK mgmt AS (INTERFACE \"eth2\", ADDRESS \"172.16.0.1/24\") RATIONALE \"x\"\n", .{two_links});
    const m3 = try arena.create(machine.Machine);
    m3.* = try machine.declare(arena, src3, &refusal);
    var aw = std.Io.Writer.Allocating.init(arena);
    try std.testing.expect(try forwardLine(&aw.writer, m3));
    try std.testing.expect(std.mem.startsWith(u8, aw.written(), "boot: forward -- between front, core and mgmt: "));

    // two networks and no FORWARD: nothing is said, and nothing is claimed
    const quiet_src = try std.mem.replaceOwned(u8, arena, two_links, ", FORWARD yes", "");
    const quiet = try arena.create(machine.Machine);
    quiet.* = try machine.declare(arena, quiet_src, &refusal);
    var aw2 = std.Io.Writer.Allocating.init(arena);
    try std.testing.expect(!try forwardLine(&aw2.writer, quiet));
    try std.testing.expectEqual(@as(usize, 0), aw2.written().len);
    const qtext = try derive(arena, try plan.derive(arena, quiet), .{});
    try std.testing.expect(std.mem.indexOf(u8, qtext, "boot: forward") == null);
}
