//! The fleet court (FLT-1): a set of machine declarations judged TOGETHER.
//!
//! ## Why a second file and not a bigger one
//!
//! Every check until now could be made by reading one machine. Some
//! cannot be made that way at all: two boxes that each declare themselves
//! the server of `salle` are both perfectly legal machines and the
//! network they make is broken. Two machines that each take
//! `192.168.10.7` are each correct alone. A till that asks for an address
//! on a link nobody serves is a till that never gets one.
//!
//! Those are facts about a SET, so they are declared in a file about a
//! set. It is the same language -- the same tokenizer, the same clause
//! machinery, the same refusal channel -- and a file is judged by which
//! kinds it may contain. A machine file that declares a FLEET is refused,
//! and a fleet file that declares a MACHINE is refused, each by name.
//!
//! ## What a fleet is FOR
//!
//! Two things, and the second is why the seat was queued.
//!
//! **Coherence.** The checks above, which no single declaration can make.
//!
//! **Attribution.** A device makes its own Ed25519 key on first boot and
//! never sends the private half anywhere (IDN-1), and it signs its own
//! boot record with it (JRN-1). Until now only that device could verify
//! its own record, which is attribution nobody else can check. A fleet
//! records each member's PUBLIC key, so any holder of the fleet file can
//! verify any member's record -- one box verifying ANOTHER device's
//! signature, with no secret anywhere in the act.
//!
//! ## Enrolment is not prophecy
//!
//! A `KEY` is absent until the device exists. It cannot be otherwise: the
//! key is made on the device, on its first boot, from its own randomness,
//! and a declaration written beforehand cannot know it. So `KEY` is
//! optional and a member without one is not refused -- it is REPORTED, by
//! `harb fleet`, as a member whose record nobody can verify yet. The
//! court refuses what is wrong; the roll says what is incomplete.
//!
//! The enrolled key implies the fingerprint the device prints on its own
//! console at every boot (`sha256(public)[0..8]`), so the roll prints it
//! beside the member and an operator can compare the two by eye. That is
//! the whole of enrolment, and it is deliberately manual: a fleet that
//! enrolled whatever key answered would attribute records to whatever
//! device happened to be plugged in.

const std = @import("std");
const machine = @import("machine.zig");
const journal = @import("journal.zig");

const Ed25519 = std.crypto.sign.Ed25519;
const Allocator = std.mem.Allocator;

pub const Error = machine.Error;
pub const Refusal = machine.Refusal;

/// How a fleet file finds the machine files it names. The CLI reads the
/// disk beside the fleet file; the court hands over the fixture's own
/// texts, so a fixture is one self-contained case and the court needs no
/// scratch directory.
pub const Resolver = struct {
    context: *const anyopaque,
    readFn: *const fn (context: *const anyopaque, path: []const u8) ?[]const u8,

    pub fn read(self: Resolver, path: []const u8) ?[]const u8 {
        return self.readFn(self.context, path);
    }
};

/// The CLI's resolver: paths are relative to the fleet file's own
/// directory, because a fleet file and the machines it names travel
/// together.
pub const Disk = struct {
    arena: Allocator,
    base: []const u8,

    pub fn resolver(self: *const Disk) Resolver {
        return .{ .context = self, .readFn = readDisk };
    }

    fn readDisk(context: *const anyopaque, path: []const u8) ?[]const u8 {
        const self: *const Disk = @alignCast(@ptrCast(context));
        const full = if (self.base.len == 0)
            self.arena.dupe(u8, path) catch return null
        else
            std.fs.path.join(self.arena, &.{ self.base, path }) catch return null;
        return std.fs.cwd().readFileAlloc(self.arena, full, 1 << 20) catch null;
    }
};

pub const Member = struct {
    name: []const u8,
    line: usize,
    /// the path as written, relative to the fleet file
    declaration: []const u8,
    /// the enrolled public key, absent until the device has booted once
    key: ?Ed25519.PublicKey,
    key_text: ?[]const u8,
    /// WHICH PHYSICAL UNIT this member is, on the wire (HDW-1).
    ///
    /// It belongs here and not in the machine file for the same reason
    /// the key does: a machine file is a DESIGN that can image many
    /// devices, and a hardware address is a fact about one of them. Both
    /// are things a deployment learns, never things a design states.
    ///
    /// With it, the fleet can check the one thing NAM-1 and FLT-1 left
    /// to a shell script: that the addresses a server promises and the
    /// members that will ask for them are the same devices.
    hardware: ?[6]u8,
    hardware_text: ?[]const u8,
    /// the fingerprint that key implies -- the same 16 hex the device
    /// prints on its own console, so the two can be compared by eye
    fingerprint: ?[16]u8,
    machine: machine.Machine,
    rationale: []const u8,
};

/// A key a member USED to have (RET-1): what a device rebuilt on a new
/// card needs if the records its old card signed are to stay checkable.
///
/// It is trusted THROUGH one entry and not one further. The need that
/// queued the seat was a card that DIED; the danger is a card that was
/// STOLEN, which goes on signing with the same key. A date would draw the
/// line, and this floor has no trusted clock, so the chain draws it: the
/// entry named here fixes every entry before it, and whatever the key
/// signs afterwards can only extend the chain -- which is refused.
///
/// A declaration of its own rather than a clause on the member, because
/// every declaration must say WHY it is there, and why a key was retired
/// -- a card that failed, a card that went missing -- is the one fact an
/// auditor reading this file years later will need.
pub const Retirement = struct {
    name: []const u8,
    line: usize,
    /// the member this key belonged to
    member: []const u8,
    key: Ed25519.PublicKey,
    key_text: []const u8,
    fingerprint: [16]u8,
    /// the hash of the last entry the fleet trusts this key for, exactly
    /// as `harb fleet ... verify` printed it once that record verified
    through: []const u8,
    rationale: []const u8,
};

/// A way between links (FWD-1, fleet v0.2): the links it joins and the member
/// that is the way.
///
/// It is a declaration of its own, as RETIREMENT is, because every declaration
/// must say WHY it is there, and why two links are joined -- the front link
/// reaches the servers behind it -- is the fact an auditor reading this file
/// will need. And it is the fleet's, because "which links may be joined" is a
/// fact about a SET: the machine that forwards says it can (FORWARD), and only
/// the fleet can say it was meant to.
pub const Route = struct {
    name: []const u8,
    line: usize,
    /// the links it joins: at least two, each declared by the fleet
    between: []const []const u8,
    /// the member that is the way: on every one of those links, and it forwards
    through: []const u8,
    rationale: []const u8,
};

pub const Fleet = struct {
    name: []const u8,
    line: usize,
    /// the wires these machines share. Saying them is what turns a list of
    /// machines into NETWORKS whose coherence can be judged: within one
    /// fleet, every member's network of this name is the same link.
    /// Without any a fleet is an estate and not a wire, and only the
    /// identity checks apply. One (`LINK`) is fleet v0.1; several (`LINKS`)
    /// are what a way between them is declared over.
    links: []const []const u8,
    members: []const Member,
    /// the keys members USED to have, each trusted through one entry
    retirements: []const Retirement,
    /// the ways between links, each through one member
    routes: []const Route,
    /// the member whose word about the time the fleet takes (TIME-1, STZ-OS-RULING-07): enrolled
    /// like any member, so what it signs is checked with a public key by anyone who holds this file.
    /// Null is a fleet that has no time, and whose records are ORDERED and UNDATED.
    time_authority: ?[]const u8 = null,
    time_line: usize = 0,
    rationale: []const u8,

    pub fn member(self: Fleet, name: []const u8) ?Member {
        for (self.members) |m| if (std.mem.eql(u8, m.name, name)) return m;
        return null;
    }

    /// The fleet's one link, when it declares exactly one: fleet v0.1's `LINK`
    pub fn link(self: Fleet) ?[]const u8 {
        return if (self.links.len == 1) self.links[0] else null;
    }

    /// The server of names on a link, if a member serves it.
    pub fn serverOf(self: Fleet, link_name: []const u8) ?Member {
        for (self.members) |m| {
            for (m.machine.networks) |n| {
                if (!std.mem.eql(u8, n.name, link_name)) continue;
                if (n.domain != null) return m;
            }
        }
        return null;
    }

    /// The server of the fleet's one link (v0.1).
    pub fn server(self: Fleet) ?Member {
        return self.serverOf(self.link() orelse return null);
    }

    /// Whether some route joins these two links
    pub fn joined(self: Fleet, a: []const u8, b: []const u8) bool {
        for (self.routes) |r| if (has(r.between, a) and has(r.between, b)) return true;
        return false;
    }
};

fn has(list: []const []const u8, name: []const u8) bool {
    for (list) |x| if (std.mem.eql(u8, x, name)) return true;
    return false;
}

/// whether this name is one of those names (a link, in the roll)
pub fn hasName(list: []const []const u8, name: []const u8) bool {
    return has(list, name);
}

fn hexKey(text: []const u8) ?Ed25519.PublicKey {
    if (text.len != 64) return null;
    var raw: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&raw, text) catch return null;
    return Ed25519.PublicKey.fromBytes(raw) catch null;
}

/// One key, however it is spelled. Hex is case-blind and a text
/// comparison is not, so `aa..` and `AA..` read as two keys to a check
/// that compared the TEXT -- and FR5, one key one place, did exactly that.
fn sameKey(a: Ed25519.PublicKey, b: Ed25519.PublicKey) bool {
    return std.mem.eql(u8, &a.toBytes(), &b.toBytes());
}

/// A head is compared byte for byte against the hash the journal WROTE,
/// which is lowercase, so the court holds it to exactly that spelling:
/// a head that differs only in case would never be reached, and the
/// refusal would come at verify time, years later, for the wrong reason.
fn isHead(t: []const u8) bool {
    if (t.len != 64) return false;
    for (t) |ch| switch (ch) {
        '0'...'9', 'a'...'f' => {},
        else => return false,
    };
    return true;
}

/// the network of this name on this machine, or null
fn linkOf(m: machine.Machine, link: []const u8) ?machine.Network {
    for (m.networks) |n| if (std.mem.eql(u8, n.name, link)) return n;
    return null;
}

pub fn declare(arena: Allocator, src: []const u8, resolver: Resolver, refusal: *Refusal) Error!Fleet {
    var ctx = machine.Ctx{ .arena = arena, .src = src, .refusal = refusal };
    try ctx.tokenize();

    var decls: std.ArrayList(machine.Decl) = .{};
    while (ctx.peek().tag != .eof) try decls.append(arena, try machine.parseDecl(&ctx));
    if (decls.items.len == 0) return ctx.refuse(1, "A fleet file declares exactly one FLEET; this file declares nothing", .{});

    // the mirror of the machine file's own rule: one language, and a file
    // is judged by which kinds it may carry
    for (decls.items) |d| if (!machine.belongsToFleet(d.kind)) {
        return ctx.refuse(d.line, "{s} belongs to a machine file, not a fleet file: a fleet says which machines are one estate, never what any one of them is", .{@tagName(d.kind)});
    };

    var fleets: usize = 0;
    for (decls.items) |d| if (d.kind == .FLEET) {
        fleets += 1;
    };
    if (fleets != 1) return ctx.refuse(decls.items[0].line, "A fleet file declares exactly one FLEET (found {d})", .{fleets});
    if (decls.items[0].kind != .FLEET) return ctx.refuse(decls.items[0].line, "The FLEET declaration comes first", .{});

    for (decls.items, 0..) |d, i| {
        for (decls.items[0..i]) |e| if (std.mem.eql(u8, d.name, e.name)) {
            return ctx.refuse(d.line, "'{s}' is already declared (line {d}); one namespace, no duplicates", .{ d.name, e.line });
        };
    }

    const fd = decls.items[0];
    // the wires: `LINK x` is the one wire of fleet v0.1, `LINKS [x, y]` several
    var links: std.ArrayList([]const u8) = .{};
    if (machine.find(fd, "LINK")) |c| {
        if (machine.find(fd, "LINKS")) |c2| return ctx.refuse(c2.line, "LINK and LINKS say the same thing twice: LINK names the one wire these machines share and LINKS names several, and a fleet declares one or the other", .{});
        try links.append(arena, try machine.wantIdent(&ctx, c));
    } else if (machine.find(fd, "LINKS")) |c| {
        const names = try machine.wantNames(&ctx, c);
        if (names.len == 0) return ctx.refuse(c.line, "an empty LINKS is not a declaration: a fleet that names no wire says nothing about wires, by declaring neither LINK nor LINKS", .{});
        for (names, 0..) |nm, i| {
            for (names[0..i]) |e| if (std.mem.eql(u8, e, nm)) return ctx.refuse(c.line, "LINKS names {s} twice: one link, one name", .{nm});
            try links.append(arena, nm);
        }
    }

    var members: std.ArrayList(Member) = .{};
    for (decls.items) |d| if (d.kind == .MEMBER) {
        const dc = try machine.required(&ctx, d, "DECLARATION");
        const path = try machine.wantString(&ctx, dc);
        if (path.len == 0) return ctx.refuse(dc.line, "DECLARATION names a machine file, not an empty string", .{});

        var key: ?Ed25519.PublicKey = null;
        var key_text: ?[]const u8 = null;
        var fingerprint: ?[16]u8 = null;
        if (machine.find(d, "KEY")) |c| {
            const t = try machine.wantString(&ctx, c);
            key = hexKey(t) orelse return ctx.refuse(c.line, "KEY is an ed25519 public key -- 64 hex characters, the half a device may publish -- and '{s}' is not one", .{t});
            key_text = t;
            fingerprint = journal.fingerprintOf(key.?.toBytes());
        }

        var hardware: ?[6]u8 = null;
        var hardware_text: ?[]const u8 = null;
        if (machine.find(d, "HARDWARE")) |c| {
            const t = try machine.wantString(&ctx, c);
            hardware = machine.parseMac(t) orelse return ctx.refuse(c.line, "HARDWARE is six pairs of hex separated by colons (52:54:00:12:34:61), and '{s}' is not: it is what a server recognises this device by, so it is the device's and not a word for it", .{t});
            hardware_text = t;
        }

        const text = resolver.read(path) orelse return ctx.refuse(d.line, "MEMBER {s} names {s}, which cannot be read from beside this fleet file", .{ d.name, path });
        var inner = Refusal{};
        const m = machine.declare(arena, text, &inner) catch |e| switch (e) {
            // a fleet is no better than the machines in it, and a member's
            // own refusal is reported WITH the member, because "line 3" in
            // a file the reader did not open is not an answer
            error.Refused => return ctx.refuse(d.line, "MEMBER {s} is refused: {s} (line {d} of {s})", .{ d.name, inner.message, inner.line, path }),
            else => return e,
        };

        for (members.items) |e| {
            if (std.mem.eql(u8, e.declaration, path)) {
                return ctx.refuse(d.line, "{s} is already {s}'s declaration: one declaration, one member, or the fleet counts one device twice", .{ path, e.name });
            }
            if (std.mem.eql(u8, e.machine.name, m.name)) {
                return ctx.refuse(d.line, "{s} and {s} both declare the machine {s}: a signed record names its machine, and two of them would be one name", .{ d.name, e.name, m.name });
            }
            if (key != null and e.key != null and sameKey(key.?, e.key.?)) {
                return ctx.refuse(d.line, "this key is already {s}'s key: two members cannot be the same device, and a key that appears twice attributes one device's records to two", .{e.name});
            }
            if (hardware != null and e.hardware != null and std.mem.eql(u8, &hardware.?, &e.hardware.?)) {
                return ctx.refuse(d.line, "{s} is already {s}'s hardware: one device, one member", .{ hardware_text.?, e.name });
            }
        }

        try members.append(arena, .{
            .name = d.name,
            .line = d.line,
            .declaration = path,
            .key = key,
            .key_text = key_text,
            .hardware = hardware,
            .hardware_text = hardware_text,
            .fingerprint = fingerprint,
            .machine = m,
            .rationale = d.rationale,
        });
    };

    // ---- the keys a member USED to have (RET-1) ------------------------
    var retirements: std.ArrayList(Retirement) = .{};
    for (decls.items) |d| if (d.kind == .RETIREMENT) {
        const mc = try machine.required(&ctx, d, "MEMBER");
        const who = try machine.wantIdent(&ctx, mc);
        var owner: ?Member = null;
        for (members.items) |m| if (std.mem.eql(u8, m.name, who)) {
            owner = m;
        };
        const o = owner orelse return ctx.refuse(mc.line, "RETIREMENT {s} retires a key of {s}, and no MEMBER {s} is declared: a key is retired FROM a device", .{ d.name, who, who });

        const kc = try machine.required(&ctx, d, "KEY");
        const kt = try machine.wantString(&ctx, kc);
        const key = hexKey(kt) orelse return ctx.refuse(kc.line, "KEY is an ed25519 public key -- 64 hex characters, the half a device may publish -- and '{s}' is not one", .{kt});

        // THROUGH is the whole of the safety, so its absence is refused in
        // words that say why, not as one more missing clause
        const tc = machine.find(d, "THROUGH") orelse return ctx.refuse(d.line, "RETIREMENT {s} names no THROUGH: a retired key with no entry it is trusted through vouches for whatever its holder signs next, and a card that was stolen rather than broken goes on signing", .{d.name});
        const through = try machine.wantString(&ctx, tc);
        if (!isHead(through)) return ctx.refuse(tc.line, "THROUGH is the hash of the last entry the fleet trusts this key for -- 64 lowercase hex, exactly as `harb fleet ... verify` prints it once that record has verified -- and '{s}' is not one", .{through});

        if (o.key) |cur| if (sameKey(cur, key)) {
            return ctx.refuse(kc.line, "{s} still holds this key: a key is the device's or it is retired, never both", .{o.name});
        };
        // one key, one place in the fleet, held or retired: FR5's rule,
        // which a retirement must not become a way around
        for (members.items) |m| if (m.key) |mk| if (sameKey(mk, key)) {
            return ctx.refuse(kc.line, "this key is already {s}'s key: a key that appears twice attributes one device's records to two", .{m.name});
        };
        for (retirements.items) |r| if (sameKey(r.key, key)) {
            return ctx.refuse(kc.line, "this key is already retired as {s}: a key is retired once, from one device", .{r.name});
        };

        try retirements.append(arena, .{
            .name = d.name,
            .line = d.line,
            .member = o.name,
            .key = key,
            .key_text = kt,
            .fingerprint = journal.fingerprintOf(key.toBytes()),
            .through = through,
            .rationale = d.rationale,
        });
    };

    // ---- the ways between links (FWD-1) ------------------------------
    var routes: std.ArrayList(Route) = .{};
    for (decls.items) |d| if (d.kind == .ROUTE) {
        if (links.items.len == 0) return ctx.refuse(d.line, "ROUTE {s} joins links, and this fleet declares none: a route is between wires, and a fleet that declares no wire has nothing to join", .{d.name});
        const bc = try machine.required(&ctx, d, "BETWEEN");
        const between = try machine.wantNames(&ctx, bc);
        for (between, 0..) |b, i| {
            if (!has(links.items, b)) return ctx.refuse(bc.line, "ROUTE {s} joins {s}, and this fleet declares no link of that name: only a link the fleet declares can be joined to another", .{ d.name, b });
            for (between[0..i]) |e| if (std.mem.eql(u8, e, b)) return ctx.refuse(bc.line, "ROUTE {s} names {s} twice: a link is joined to another, never to itself", .{ d.name, b });
        }
        if (between.len < 2) return ctx.refuse(bc.line, "ROUTE {s} joins {d} link{s}: a route is between at least two", .{ d.name, between.len, if (between.len == 1) "" else "s" });
        const tc = try machine.required(&ctx, d, "THROUGH");
        const via = try machine.wantIdent(&ctx, tc);
        var way: ?Member = null;
        for (members.items) |m| if (std.mem.eql(u8, m.name, via)) {
            way = m;
        };
        const p = way orelse return ctx.refuse(tc.line, "ROUTE {s} goes THROUGH {s}, and no MEMBER {s} is declared: a way is a machine of this fleet", .{ d.name, via, via });
        // the way is ON every link it joins, with an address the others can send to
        for (between) |b| {
            const n = linkOf(p.machine, b) orelse return ctx.refuse(tc.line, "ROUTE {s} goes THROUGH {s}, which has no network on {s}: a way that is not on a link is not a way to it", .{ d.name, via, b });
            if (n.address != .static) return ctx.refuse(tc.line, "ROUTE {s} goes THROUGH {s}, which asks for its address on {s} by dhcp: a way is an address somebody else sends to, so it declares one", .{ d.name, via, b });
        }
        if (!p.machine.forward) return ctx.refuse(tc.line, "ROUTE {s} goes THROUGH {s}, and {s} does not FORWARD: a way that does not forward is a wall, and a route over it is a promise nothing keeps", .{ d.name, via, via });
        // one way between two links: a second would give a member two
        // gateways for one wire, and its one GATEWAY cannot be both
        for (routes.items) |r| for (between, 0..) |a, i| for (between[i + 1 ..]) |b| {
            if (has(r.between, a) and has(r.between, b)) return ctx.refuse(d.line, "{s} and {s} are already joined by the route {s}: one way between two links, because a member on either has one gateway and cannot be sent through two", .{ a, b, r.name });
        };
        try routes.append(arena, .{ .name = d.name, .line = d.line, .between = between, .through = via, .rationale = d.rationale });
    };

    // ---- the time authority (TIME-1) ---------------------------------
    var time_authority: ?[]const u8 = null;
    var time_line: usize = fd.line;
    if (machine.find(fd, "TIME_AUTHORITY")) |c| {
        time_authority = try machine.wantIdent(&ctx, c);
        time_line = c.line;
    }

    const f = Fleet{
        .name = fd.name,
        .line = fd.line,
        .links = try links.toOwnedSlice(arena),
        .members = try members.toOwnedSlice(arena),
        .retirements = try retirements.toOwnedSlice(arena),
        .routes = try routes.toOwnedSlice(arena),
        .time_authority = time_authority,
        .time_line = time_line,
        .rationale = fd.rationale,
    };

    // ---- the checks no single machine can make ----------------------
    for (f.links) |wire| {
        // one link, one server of names
        var serves: ?Member = null;
        for (f.members) |m| {
            const n = linkOf(m.machine, wire) orelse continue;
            if (n.domain == null) continue;
            if (serves) |s| return ctx.refuse(m.line, "{s} already serves {s}: one link, one server of names, or two machines hand out the same addresses and neither is wrong alone", .{ s.name, wire });
            serves = m;
        }

        // one address, one machine
        for (f.members, 0..) |m, i| {
            const n = linkOf(m.machine, wire) orelse continue;
            const mine = switch (n.address) {
                .static => |s| s,
                .dhcp => continue,
            };
            for (f.members[0..i]) |e| {
                const en = linkOf(e.machine, wire) orelse continue;
                const theirs = switch (en.address) {
                    .static => |s| s,
                    .dhcp => continue,
                };
                if (mine.ip == theirs.ip) {
                    return ctx.refuse(m.line, "{s} is already {s}'s address on {s}: one address, one machine", .{ mine.text, e.name, wire });
                }
            }
        }

        // Now that a member can say WHICH DEVICE it is, the promise and
        // the machine can be held against each other. This is the check
        // the seat exists for: until HDW-1 the only thing connecting the
        // address a server promises to the device that will claim it was
        // a `-device ...,mac=` flag in a shell script.
        if (serves) |sv| {
            for (f.members) |m| {
                const hw = m.hardware orelse continue;
                const mine = linkOf(m.machine, wire) orelse continue;
                var promised: ?machine.Peer = null;
                for (sv.machine.peers) |p| {
                    if (!std.mem.eql(u8, p.network, wire)) continue;
                    if (std.mem.eql(u8, &p.hardware, &hw)) promised = p;
                }
                if (std.mem.eql(u8, m.name, sv.name)) {
                    // the server answering its own register would be a
                    // machine handing itself an address it already has
                    if (promised) |p| return ctx.refuse(m.line, "{s} serves {s} and cannot be its own peer: {s} is declared as {s}, and a server does not ask itself for an address", .{ m.name, wire, m.hardware_text.?, p.name });
                    continue;
                }
                switch (mine.address) {
                    .dhcp => if (promised == null) {
                        return ctx.refuse(m.line, "{s} promises no address to {s}: a device that asks on {s} and is in nobody's register will never get one, and no pool exists to fall back on", .{ sv.name, m.hardware_text.?, wire });
                    },
                    .static => |st| if (promised) |p| {
                        return ctx.refuse(m.line, "{s} is promised {s} by {s} and takes {s} itself: one device, one address, written in one place", .{ m.hardware_text.?, p.address, sv.name, st.text });
                    },
                }
            }
        }

        // an address the server has PROMISED is not free to take: the
        // fleet has one place where each address is spoken for, and a
        // second claim on it is a second source of truth
        if (serves) |s| {
            for (f.members) |m| {
                if (std.mem.eql(u8, m.name, s.name)) continue;
                const n = linkOf(m.machine, wire) orelse continue;
                const mine = switch (n.address) {
                    .static => |st| st,
                    .dhcp => continue,
                };
                for (s.machine.peers) |p| {
                    if (!std.mem.eql(u8, p.network, wire)) continue;
                    if (p.ip == mine.ip) {
                        return ctx.refuse(m.line, "{s} is promised to {s} by {s}: an address the server hands out is not free for a member to take, and the promise is the one place it is written", .{ mine.text, p.name, s.name });
                    }
                }
            }
        } else {
            // somebody asking and nobody serving
            for (f.members) |m| {
                const n = linkOf(m.machine, wire) orelse continue;
                if (n.address != .dhcp) continue;
                return ctx.refuse(m.line, "{s} asks for its address on {s} and no member serves {s}: a fleet that declares a link declares who answers on it", .{ m.name, wire, wire });
            }
        }
    }

    try checkRoutes(&ctx, f);
    try checkTime(&ctx, f);

    return f;
}

// ---- the time authority (TIME-1) ----------------------------------------

/// The facts about time that no single machine can know (STZ-OS-RULING-07): who the fleet takes the
/// time from, that what that member signs can be CHECKED (it is enrolled), that its machine can
/// answer, and that everyone who asks asks it -- the address, the key and a way there. Each is a case
/// where every machine in the fleet is faultless alone.
fn checkTime(ctx: *machine.Ctx, f: Fleet) machine.Error!void {
    // who answers the time: every member whose machine says it does
    var answerer: ?Member = null;
    for (f.members) |m| {
        var answers = false;
        for (m.machine.networks) |n| if (n.time_authority != null) {
            answers = true;
        };
        if (!answers) continue;
        if (answerer) |first| return ctx.refuse(m.line, "{s} answers the time too, and {s} already does: a fleet has one time authority, or a record would be dated by whoever the asker happened to reach", .{ m.name, first.name });
        answerer = m;
    }
    const who = f.time_authority orelse {
        if (answerer) |a| return ctx.refuse(a.line, "{s} answers the time, and this fleet declares no TIME_AUTHORITY: a statement from a member the fleet never named is one nobody was declared to trust", .{a.name});
        for (f.members) |m| if (m.machine.time_from) |tf| {
            return ctx.refuse(m.line, "{s} asks {s} for the time of its record, and this fleet declares no time authority: a question nobody was declared to answer", .{ m.name, tf.text });
        };
        return;
    };
    const am = f.member(who) orelse return ctx.refuse(f.time_line, "TIME_AUTHORITY names {s}, and no MEMBER {s} is declared: an authority is a machine of this fleet", .{ who, who });
    if (am.key == null) return ctx.refuse(f.time_line, "{s} is the fleet's time authority and has no KEY: a statement nobody can check against a key is a claim and not a time, so the authority is enrolled like every member whose record is verified", .{who});
    var net: ?machine.Network = null;
    for (am.machine.networks) |n| if (n.time_authority != null) {
        net = n;
    };
    const wire = net orelse return ctx.refuse(f.time_line, "{s} is the fleet's time authority, and its machine declares no NETWORK with TIME_AUTHORITY: it cannot answer", .{who});
    const at = switch (wire.address) {
        .static => |s| s,
        .dhcp => unreachable, // the machine court refuses a TIME_AUTHORITY on a leased address
    };
    for (f.members) |m| {
        if (std.mem.eql(u8, m.name, am.name)) continue;
        const tf = m.machine.time_from orelse continue;
        if (tf.ip != at.ip or tf.port != wire.time_authority.?) {
            return ctx.refuse(m.line, "{s} asks {s} for the time, and the fleet's time authority {s} answers on {s}:{d}: it would ask somebody who is not the authority", .{ m.name, tf.text, who, at.text[0 .. std.mem.indexOfScalar(u8, at.text, '/') orelse at.text.len], wire.time_authority.? });
        }
        if (!std.mem.eql(u8, &tf.key, &am.key.?.toBytes())) {
            return ctx.refuse(m.line, "{s} takes the time from the key {s}, and the fleet's time authority {s} is enrolled as {s}: the word it takes is not the authority's", .{ m.name, tf.key_text, who, am.key_text.? });
        }
        // a way to the authority: its link, or one a ROUTE joins to it -- judged only where the fleet names wires
        if (f.links.len > 0) {
            var reach = false;
            for (m.machine.networks) |n| {
                if (machine.isLoopback(n)) continue;
                if (std.mem.eql(u8, n.name, wire.name) or f.joined(n.name, wire.name)) reach = true;
            }
            if (!reach) return ctx.refuse(m.line, "{s} asks the time of {s}, which answers on {s}, and {s} is on no link that is {s} or that a ROUTE joins to it: a question with no way there", .{ m.name, who, wire.name, m.name, wire.name });
        }
    }
}

// ---- the ways between links (FWD-1) ------------------------------------

/// A prefix: the network address and how many bits of it are the network's
const Prefix = struct {
    net: u32,
    bits: u6,
    /// a member's own words for its address on the link (10.20.0.1/24): what that member said
    text: []const u8,
    /// the link's own prefix (10.20.0.0/24): what a message about the LINK, and not about one
    /// machine's address on it, prints
    net_text: []const u8,
};

fn maskOf(bits: u6) u32 {
    return if (bits == 0) 0 else ~@as(u32, 0) << @intCast(32 - @as(u6, bits));
}

/// Whether the destination D and the prefix P share an address: D names the
/// link, or a part of it (a /32 to the one server), or the link is a part of D
fn overlaps(d: machine.Destination, p: Prefix) bool {
    const bits = @min(d.prefix, p.bits);
    return (p.net & maskOf(bits)) == (d.ip & maskOf(bits));
}

/// Whether two links' prefixes share an address
fn sharePrefix(a: Prefix, b: Prefix) bool {
    const bits = @min(a.bits, b.bits);
    return (a.net & maskOf(bits)) == (b.net & maskOf(bits));
}

/// What a link's prefix is: read off every member's STATIC address on it, and
/// the members must agree where it ends. A wire has one prefix, and a pair of
/// machines that each think it ends in another place are each faultless alone.
fn prefixOf(ctx: *machine.Ctx, f: Fleet, wire: []const u8) machine.Error!?Prefix {
    var got: ?Prefix = null;
    var first: []const u8 = "";
    for (f.members) |m| {
        const n = linkOf(m.machine, wire) orelse continue;
        const st = switch (n.address) {
            .static => |s| s,
            .dhcp => continue,
        };
        const net = st.ip & maskOf(st.prefix);
        const here = Prefix{
            .net = net,
            .bits = st.prefix,
            .text = st.text,
            .net_text = try std.fmt.allocPrint(ctx.arena, "{d}.{d}.{d}.{d}/{d}", .{ net >> 24, (net >> 16) & 255, (net >> 8) & 255, net & 255, st.prefix }),
        };
        if (got) |g| {
            if (g.net != here.net or g.bits != here.bits) return ctx.refuse(m.line, "{s} says {s} is {s} and {s} says it is {s}: one wire has one prefix, or two machines on it do not agree where it ends", .{ first, wire, g.text, m.name, here.text });
        } else {
            got = here;
            first = m.name;
        }
    }
    return got;
}

/// The checks a way between links makes possible, and that no single machine
/// can fail (FWD-1): that the door is declared, that everyone on a joined link
/// takes the way, and that nothing is routed to a link nobody joins. Each is a
/// fact about two machines at once -- a till whose route is right and a server
/// with no way back are each faultless alone -- which is what a fleet is for.
fn checkRoutes(ctx: *machine.Ctx, f: Fleet) machine.Error!void {
    // every link's prefix, once, and the members agreeing on it
    const arena = ctx.arena;
    const prefixes = try arena.alloc(?Prefix, f.links.len);
    for (f.links, 0..) |wire, i| prefixes[i] = try prefixOf(ctx, f, wire);
    const prefixFor = struct {
        fn of(links: []const []const u8, ps: []const ?Prefix, wire: []const u8) ?Prefix {
            for (links, 0..) |l, i| if (std.mem.eql(u8, l, wire)) return ps[i];
            return null;
        }
    }.of;

    // TWO LINKS, TWO PREFIXES. A wire has one prefix (above); two wires that share
    // addresses are one address space with two ends, and a machine on both has two
    // connected routes for it: the court would call them joined and reachable, and no
    // packet could use the way.
    for (f.links, 0..) |a, i| for (f.links[i + 1 ..], i + 1..) |b, j| {
        const pa = prefixes[i] orelse continue;
        const pb = prefixes[j] orelse continue;
        if (sharePrefix(pa, pb)) return ctx.refuse(f.line, "{s} is {s} and {s} is {s}, and the two share addresses: one address would be on either wire, and a machine on both has two connected routes for it", .{ a, pa.net_text, b, pb.net_text });
    };

    // THE DOOR. A machine that forwards joins every one of its links, whether
    // or not anybody meant it to: so the fleet must have said it was meant to,
    // for every pair, and a forwarder no route goes through is a door nobody
    // agreed to.
    for (f.members) |p| {
        if (!p.machine.forward) continue;
        var through: usize = 0;
        for (f.routes) |r| if (std.mem.eql(u8, r.through, p.name)) {
            through += 1;
        };
        if (through == 0) return ctx.refuse(p.line, "{s} forwards between its networks, and no ROUTE goes through it: a machine that is the way between links is a door, and a door nobody declared is one nobody agreed to", .{p.name});
        var names: std.ArrayList([]const u8) = .{};
        for (p.machine.networks) |n| if (!machine.isLoopback(n)) try names.append(arena, n.name);
        for (names.items, 0..) |a, i| for (names.items[i + 1 ..]) |b| {
            var said = false;
            for (f.routes) |r| if (std.mem.eql(u8, r.through, p.name) and has(r.between, a) and has(r.between, b)) {
                said = true;
            };
            if (!said) return ctx.refuse(p.line, "{s} forwards among all its networks, and no ROUTE through it joins {s} and {s}: the machine joins them whether or not the fleet says so", .{ p.name, a, b });
        };
    }

    // EVERYONE ON A JOINED LINK TAKES THE WAY. A route is a way both ways -- no
    // filter exists to make it one-way, and an answer needs a way back as much
    // as a question needs a way there -- so a member of a joined link either has
    // the way to the others or has put itself on a link that is not joined.
    for (f.routes) |r| {
        const p = f.member(r.through).?;
        for (f.members) |m| {
            if (std.mem.eql(u8, m.name, p.name)) continue;
            for (m.machine.networks) |n| {
                if (machine.isLoopback(n) or !has(r.between, n.name)) continue;
                const way = linkOf(p.machine, n.name).?.address.static;
                switch (n.address) {
                    .static => {
                        const g = n.gateway orelse return ctx.refuse(m.line, "{s} is on {s}, which the route {s} joins to the others, and declares no GATEWAY: a member of a joined link needs the way {s} to reach the rest", .{ m.name, n.name, r.name, p.name });
                        if (g.addr != way.ip) return ctx.refuse(m.line, "{s}'s gateway on {s} is {s}, and the way is {s} at {s}: a gateway that is not the way sends a packet where nothing forwards it", .{ m.name, n.name, g.text, p.name, way.text });
                    },
                    .dhcp => {
                        const sv = f.serverOf(n.name);
                        if (sv == null or !std.mem.eql(u8, sv.?.name, p.name)) return ctx.refuse(m.line, "{s} asks for its address on {s} by dhcp, and the way {s} does not serve {s}: only the link's own server can offer the way in a lease, so {s} would be told no router", .{ m.name, n.name, p.name, n.name, m.name });
                    },
                }
                switch (n.egress) {
                    .none => return ctx.refuse(m.line, "{s} says EGRESS none for {s}, which the route {s} joins to the others: a member of a joined link takes the way, or sits on a link that is not joined", .{ m.name, n.name, r.name }),
                    .unrestricted => {},
                    .to => |dests| for (r.between) |other| {
                        if (std.mem.eql(u8, other, n.name)) continue;
                        const pf = prefixFor(f.links, prefixes, other) orelse continue;
                        var seen = false;
                        for (dests) |d| if (overlaps(d, pf)) {
                            seen = true;
                        };
                        if (!seen) return ctx.refuse(m.line, "{s}'s EGRESS for {s} does not reach {s} ({s}), which the route {s} joins to it: a perimeter that touches nothing on the other link has a way there and no way back, or the reverse", .{ m.name, n.name, other, pf.net_text, r.name });
                    },
                }
            }
        }
    }

    // NOTHING IS ROUTED TO A LINK NOBODY JOINS. A destination that is a declared
    // link, written in a machine's EGRESS, is a claim that the way to it exists:
    // the fleet is the one place that knows whether it does.
    for (f.members) |m| {
        for (m.machine.networks) |n| {
            if (machine.isLoopback(n)) continue;
            const dests = switch (n.egress) {
                .to => |d| d,
                else => continue,
            };
            for (dests) |d| for (f.links, 0..) |other, i| {
                if (std.mem.eql(u8, other, n.name)) continue;
                const pf = prefixes[i] orelse continue;
                if (!overlaps(d, pf)) continue;
                if (!f.joined(n.name, other)) return ctx.refuse(m.line, "{s} routes {s} through {s}, and that is the {s} link, which no ROUTE joins to {s}: a route to nowhere", .{ m.name, d.text, n.name, other, n.name });
            };
        }
    }
}

// ---- attribution: one machine verifying another's record ---------------

/// The peer the link's server promises this member an address as, if
/// the member says which device it is and the server has it in its
/// register. It is the join HDW-1 exists to make.
pub fn promisedTo(f: Fleet, m: Member) ?machine.Peer {
    const hw = m.hardware orelse return null;
    // the first link whose server has this device in its register: a device
    // is one device on every link it is on
    for (f.links) |wire| {
        const sv = f.serverOf(wire) orelse continue;
        if (std.mem.eql(u8, sv.name, m.name)) continue;
        for (sv.machine.peers) |p| {
            if (!std.mem.eql(u8, p.network, wire)) continue;
            if (std.mem.eql(u8, &p.hardware, &hw)) return p;
        }
    }
    return null;
}

/// A record heard under a key its member no longer holds.
pub const Retired = struct {
    retirement: Retirement,
    through: journal.Through,
};

pub const Attribution = union(enum) {
    /// the record is this member's, entire and in order
    verified: journal.Check,
    /// the record does not verify, and the check says where and why
    broken: journal.Check,
    /// the record is a chain this member signed with a key it has since
    /// retired: entire, and ending exactly at the entry the fleet trusts
    /// that key through
    retired_verified: Retired,
    /// signed with a retired key, and not the chain the fleet vouched for:
    /// it goes past the head, never reaches it, or breaks on the way
    retired_broken: Retired,
    /// the member holds no key today, and none it has held signed this
    unsigned,
    /// the record carries no entry at all: there is nothing to attribute
    empty,
    /// the member exists and nobody has enrolled its key
    not_enrolled,
    no_such_member,
};

/// Verify a member's signed boot record using ONLY what the fleet holds:
/// the member's public keys, the one it holds and the ones it has retired.
/// No private key takes part, so this is an act any holder of the fleet
/// file can perform -- another box on the wire, the court on a laptop, an
/// auditor years later.
pub fn attribute(f: Fleet, member_name: []const u8, record: []const u8) Attribution {
    const m = f.member(member_name) orelse return .no_such_member;
    // NS-1's rule at the verifier: a claim that would be EMPTY is not made
    if (journal.entryCount(record) == 0) return .empty;

    // The key it holds first: it is the device's word today, and a record
    // it signed is heard exactly as it was before retirements existed.
    if (m.key) |key| {
        if (journal.firstSignedBy(record, key)) {
            const check = journal.verify(record, key);
            return if (check.broken_at == null) .{ .verified = check } else .{ .broken = check };
        }
    }
    // Then every key it USED to have. A chain has one signer, so its first
    // entry says whose chain it is, and that one retirement decides.
    for (f.retirements) |r| {
        if (!std.mem.eql(u8, r.member, m.name)) continue;
        if (!journal.firstSignedBy(record, r.key)) continue;
        const t = journal.verifyThrough(record, r.key, r.through);
        const heard = Retired{ .retirement = r, .through = t };
        return if (t.kept()) .{ .retired_verified = heard } else .{ .retired_broken = heard };
    }
    // No key it has held signed the first entry. Heard under the key it
    // holds, so the refusal reads exactly as it always did -- an altered
    // first entry is named as altered, a foreign one as unsigned.
    if (m.key) |key| {
        const check = journal.verify(record, key);
        return if (check.broken_at == null) .{ .verified = check } else .{ .broken = check };
    }
    for (f.retirements) |r| {
        if (std.mem.eql(u8, r.member, m.name)) return .unsigned;
    }
    return .not_enrolled;
}

// ---- judged beside the code -------------------------------------------

const testing = std.testing;

const T = struct {
    files: []const [2][]const u8,

    fn read(context: *const anyopaque, path: []const u8) ?[]const u8 {
        const self: *const T = @alignCast(@ptrCast(context));
        for (self.files) |f| if (std.mem.eql(u8, f[0], path)) return f[1];
        return null;
    }
    fn resolver(self: *const T) Resolver {
        return .{ .context = self, .readFn = read };
    }
};

const box_src =
    \\DEFINE MACHINE box AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE "x"
    \\DEFINE CAPABILITY network AS (GRANT yes) RATIONALE "x"
    \\DEFINE NETWORK salle AS (INTERFACE "eth0", ADDRESS "192.168.10.1/24", DOMAIN "makeen") RATIONALE "x"
    \\DEFINE PEER caisse AS (NETWORK salle, HARDWARE "52:54:00:12:34:61", ADDRESS "192.168.10.40") RATIONALE "x"
    \\
;
const till_src =
    \\DEFINE MACHINE till AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE "x"
    \\DEFINE CAPABILITY network AS (GRANT yes) RATIONALE "x"
    \\DEFINE NETWORK salle AS (INTERFACE "eth0", ADDRESS dhcp) RATIONALE "x"
    \\
;

test "a box verifies another device's record holding nothing but its public key" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // the till's own key, made on the till and never leaving it
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, 0x42);
    const till_pair = try Ed25519.KeyPair.generateDeterministic(seed);

    // three boots of the till, signed by the till
    var record: std.ArrayList(u8) = .{};
    var check = journal.Check{};
    var digest: [16]u8 = undefined;
    @memcpy(&digest, "a48c59fbf8070f67");
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const line = try journal.entry(arena, till_pair, check, "till", digest, .matched);
        try record.appendSlice(arena, line);
        check = journal.verify(record.items, till_pair.public_key);
    }

    // the fleet holds only the PUBLIC half
    var pub_hex: [64]u8 = undefined;
    _ = try std.fmt.bufPrint(&pub_hex, "{x}", .{till_pair.public_key.toBytes()});
    const src = try std.fmt.allocPrint(arena,
        \\DEFINE FLEET salle_makeen AS (LINK salle) RATIONALE "x"
        \\DEFINE MEMBER box AS (DECLARATION "box.machine") RATIONALE "x"
        \\DEFINE MEMBER till AS (DECLARATION "till.machine", KEY "{s}") RATIONALE "x"
        \\
    , .{pub_hex});

    const t = T{ .files = &.{ .{ "box.machine", box_src }, .{ "till.machine", till_src } } };
    var refusal = Refusal{};
    const f = try declare(arena, src, t.resolver(), &refusal);
    try testing.expectEqual(@as(usize, 2), f.members.len);

    switch (attribute(f, "till", record.items)) {
        .verified => |c| try testing.expectEqual(@as(usize, 3), c.verified),
        else => return error.NotAttributed,
    }

    // the box has no key enrolled, so nobody can speak for its records
    try testing.expectEqual(Attribution.not_enrolled, attribute(f, "box", record.items));
    try testing.expectEqual(Attribution.no_such_member, attribute(f, "imprimante", record.items));
}

test "a record altered after the fact is refused, and so is one signed by another device" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, 0x42);
    const till_pair = try Ed25519.KeyPair.generateDeterministic(seed);
    @memset(&seed, 0x99);
    const other = try Ed25519.KeyPair.generateDeterministic(seed);

    var digest: [16]u8 = undefined;
    @memcpy(&digest, "a48c59fbf8070f67");
    const line = try journal.entry(arena, till_pair, .{}, "till", digest, .matched);

    var pub_hex: [64]u8 = undefined;
    _ = try std.fmt.bufPrint(&pub_hex, "{x}", .{till_pair.public_key.toBytes()});
    const src = try std.fmt.allocPrint(arena,
        \\DEFINE FLEET f AS () RATIONALE "x"
        \\DEFINE MEMBER till AS (DECLARATION "till.machine", KEY "{s}") RATIONALE "x"
        \\
    , .{pub_hex});
    const t = T{ .files = &.{.{ "till.machine", till_src }} };
    var refusal = Refusal{};
    const f = try declare(arena, src, t.resolver(), &refusal);

    // the verdict is exactly the word somebody would want to change
    const tampered = try std.mem.replaceOwned(u8, arena, line, "verdict=matched", "verdict=differed");
    switch (attribute(f, "till", tampered)) {
        .broken => |c| try testing.expectEqual(@as(?usize, 1), c.broken_at),
        else => return error.TamperNotCaught,
    }

    // and the same record offered as another device's
    var other_hex: [64]u8 = undefined;
    _ = try std.fmt.bufPrint(&other_hex, "{x}", .{other.public_key.toBytes()});
    const src2 = try std.fmt.allocPrint(arena,
        \\DEFINE FLEET f AS () RATIONALE "x"
        \\DEFINE MEMBER till AS (DECLARATION "till.machine", KEY "{s}") RATIONALE "x"
        \\
    , .{other_hex});
    const f2 = try declare(arena, src2, t.resolver(), &refusal);
    switch (attribute(f2, "till", line)) {
        .broken => |c| try testing.expectEqual(@as(?usize, 1), c.broken_at),
        else => return error.ForeignKeyAccepted,
    }
}

test "the promise and the machine are held against each other once a member says which device it is" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const t = T{ .files = &.{ .{ "box.machine", box_src }, .{ "till.machine", till_src } } };
    var refusal = Refusal{};

    // the till IS the device the box promises 192.168.10.40 to
    const good =
        \\DEFINE FLEET f AS (LINK salle) RATIONALE "x"
        \\DEFINE MEMBER boitier AS (DECLARATION "box.machine", HARDWARE "52:54:00:12:34:01") RATIONALE "x"
        \\DEFINE MEMBER caisse AS (DECLARATION "till.machine", HARDWARE "52:54:00:12:34:61") RATIONALE "x"
        \\
    ;
    const f = try declare(arena, good, t.resolver(), &refusal);
    const till = f.member("caisse").?;
    const p = promisedTo(f, till) orelse return error.NotJoined;
    try testing.expectEqualStrings("caisse", p.name);
    try testing.expectEqualStrings("192.168.10.40", p.address);
    // the box is the server, so it is promised nothing
    try testing.expect(promisedTo(f, f.member("boitier").?) == null);

    // the same fleet with a device the box has never heard of
    const stranger =
        \\DEFINE FLEET f AS (LINK salle) RATIONALE "x"
        \\DEFINE MEMBER boitier AS (DECLARATION "box.machine") RATIONALE "x"
        \\DEFINE MEMBER etranger AS (DECLARATION "till.machine", HARDWARE "52:54:00:77:77:77") RATIONALE "x"
        \\
    ;
    try testing.expectError(error.Refused, declare(arena, stranger, t.resolver(), &refusal));
    try testing.expect(std.mem.indexOf(u8, refusal.message, "promises no address to") != null);
}

test "the fleet refuses what no single machine can be wrong about" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const second_server =
        \\DEFINE MACHINE box2 AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE "x"
        \\DEFINE CAPABILITY network AS (GRANT yes) RATIONALE "x"
        \\DEFINE NETWORK salle AS (INTERFACE "eth0", ADDRESS "192.168.10.2/24", DOMAIN "makeen") RATIONALE "x"
        \\
    ;
    const t = T{ .files = &.{ .{ "box.machine", box_src }, .{ "box2.machine", second_server } } };
    const src =
        \\DEFINE FLEET f AS (LINK salle) RATIONALE "x"
        \\DEFINE MEMBER un AS (DECLARATION "box.machine") RATIONALE "x"
        \\DEFINE MEMBER deux AS (DECLARATION "box2.machine") RATIONALE "x"
        \\
    ;
    var refusal = Refusal{};
    // both machines are judged and faultless on their own
    var inner = Refusal{};
    _ = try machine.declare(arena, box_src, &inner);
    _ = try machine.declare(arena, second_server, &inner);
    // together they are a network with two servers
    try testing.expectError(error.Refused, declare(arena, src, t.resolver(), &refusal));
    try testing.expect(std.mem.indexOf(u8, refusal.message, "already serves salle") != null);
}

// ---- retirement (RET-1) ---------------------------------------------------

/// `n` boots of the till, signed by `pair`, each chained to the one before
fn chainOf(arena: Allocator, pair: Ed25519.KeyPair, n: usize, verdict: journal.Verdict) ![]const u8 {
    return extend(arena, "", pair, n, verdict);
}

/// `n` more entries on `text`, signed by `pair` -- which is what a card
/// does when it boots, and what a stolen card goes on doing
fn extend(arena: Allocator, text: []const u8, pair: Ed25519.KeyPair, n: usize, verdict: journal.Verdict) ![]const u8 {
    var record: std.ArrayList(u8) = .{};
    try record.appendSlice(arena, text);
    var digest: [16]u8 = undefined;
    @memcpy(&digest, "a48c59fbf8070f67");
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const check = journal.verify(record.items, pair.public_key);
        const line = try journal.entry(arena, pair, check, "till", digest, verdict);
        try record.appendSlice(arena, line);
    }
    return record.items;
}

fn keyHex(pair: Ed25519.KeyPair) [64]u8 {
    var out: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&out, "{x}", .{pair.public_key.toBytes()}) catch unreachable;
    return out;
}

fn pairOf(fill: u8) !Ed25519.KeyPair {
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, fill);
    return Ed25519.KeyPair.generateDeterministic(seed);
}

/// a till whose first card signed `old`'s chain and was retired through
/// `head`, and whose second card holds `new`
fn rebuilt(arena: Allocator, old: Ed25519.KeyPair, new: ?Ed25519.KeyPair, head: []const u8) !Fleet {
    const old_hex = keyHex(old);
    const src = if (new) |n| blk: {
        const new_hex = keyHex(n);
        break :blk try std.fmt.allocPrint(arena,
            \\DEFINE FLEET f AS () RATIONALE "x"
            \\DEFINE MEMBER till AS (DECLARATION "till.machine", KEY "{s}") RATIONALE "x"
            \\DEFINE RETIREMENT carte_1 AS (MEMBER till, KEY "{s}", THROUGH "{s}") RATIONALE "the first card failed"
            \\
        , .{ new_hex, old_hex, head });
    } else try std.fmt.allocPrint(arena,
        \\DEFINE FLEET f AS () RATIONALE "x"
        \\DEFINE MEMBER till AS (DECLARATION "till.machine") RATIONALE "x"
        \\DEFINE RETIREMENT carte_1 AS (MEMBER till, KEY "{s}", THROUGH "{s}") RATIONALE "the first card failed"
        \\
    , .{ old_hex, head });
    const t = T{ .files = &.{.{ "till.machine", till_src }} };
    var refusal = Refusal{};
    return declare(arena, src, t.resolver(), &refusal);
}

test "a card rebuilt: the old card's chain is heard through its head, the new card's in full" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const old = try pairOf(0x42);
    const new = try pairOf(0x43);
    const old_chain = try chainOf(arena, old, 3, .matched);
    const head = journal.verify(old_chain, old.public_key).last_hash;
    const new_chain = try chainOf(arena, new, 2, .matched);

    const f = try rebuilt(arena, old, new, &head);
    try testing.expectEqual(@as(usize, 1), f.retirements.len);

    switch (attribute(f, "till", old_chain)) {
        .retired_verified => |r| {
            try testing.expectEqual(@as(usize, 3), r.through.check.verified);
            try testing.expectEqual(@as(?usize, 3), r.through.head_at);
            try testing.expectEqualStrings("carte_1", r.retirement.name);
        },
        else => return error.RetiredChainNotHeard,
    }
    switch (attribute(f, "till", new_chain)) {
        .verified => |c| try testing.expectEqual(@as(usize, 2), c.verified),
        else => return error.NewChainNotHeard,
    }
}

test "a stolen card goes on signing, and the first entry past its head is refused by position" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const old = try pairOf(0x42);
    const new = try pairOf(0x43);
    const old_chain = try chainOf(arena, old, 3, .matched);
    const head = journal.verify(old_chain, old.public_key).last_hash;
    const f = try rebuilt(arena, old, new, &head);

    // two more boots of the OLD card, after the fleet retired it. They
    // chain perfectly and the key really did sign them: nothing in the
    // record itself is wrong, which is why only the head can refuse them.
    const stolen = try extend(arena, old_chain, old, 2, .matched);
    try testing.expectEqual(@as(?usize, null), journal.verify(stolen, old.public_key).broken_at);

    switch (attribute(f, "till", stolen)) {
        .retired_broken => |r| {
            // named by POSITION: entry 4 is the first past the head
            try testing.expectEqual(@as(?usize, 4), r.through.check.broken_at);
            try testing.expectEqual(@as(usize, 3), r.through.check.verified);
            // and the evidence that the key's holder went on signing
            try testing.expectEqual(@as(usize, 2), r.through.signed_after);
        },
        else => return error.StolenCardHeard,
    }
}

test "a record that never reaches the head is not trusted, even when every entry in it verifies" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const old = try pairOf(0x42);
    const old_chain = try chainOf(arena, old, 3, .matched);
    const head = journal.verify(old_chain, old.public_key).last_hash;
    const f = try rebuilt(arena, old, null, &head);

    // the device's own first two entries, really written by it...
    const shorter = try chainOf(arena, old, 2, .matched);
    // ...and a different three-entry chain the key's holder wrote since,
    // saying the boots it recorded did NOT match. Both verify under the
    // key; neither reaches the head; they cannot be told apart, so both
    // are refused.
    const rewritten = try chainOf(arena, old, 3, .differed);
    try testing.expectEqual(@as(?usize, null), journal.verify(rewritten, old.public_key).broken_at);

    for ([_][]const u8{ shorter, rewritten }) |rec| {
        switch (attribute(f, "till", rec)) {
            .retired_broken => |r| {
                try testing.expectEqual(@as(?usize, null), r.through.head_at);
                try testing.expectEqual(@as(?usize, null), r.through.check.broken_at);
                try testing.expect(!r.through.kept());
            },
            else => return error.HeadlessChainTrusted,
        }
    }
}

test "a record no key of the member ever signed is refused, whatever keys it has held" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const old = try pairOf(0x42);
    const new = try pairOf(0x43);
    const stranger = try pairOf(0x99);
    const old_chain = try chainOf(arena, old, 3, .matched);
    const head = journal.verify(old_chain, old.public_key).last_hash;
    const foreign = try chainOf(arena, stranger, 2, .matched);

    // holding a key today: the refusal reads as it did before RET-1
    const f = try rebuilt(arena, old, new, &head);
    switch (attribute(f, "till", foreign)) {
        .broken => |c| try testing.expectEqual(@as(?usize, 1), c.broken_at),
        else => return error.ForeignAccepted,
    }
    // holding none, between the old card and the new one
    const g = try rebuilt(arena, old, null, &head);
    try testing.expectEqual(Attribution.unsigned, attribute(g, "till", foreign));
}

test "a record of nothing is not attributed to anybody" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const old = try pairOf(0x42);
    const new = try pairOf(0x43);
    const old_chain = try chainOf(arena, old, 3, .matched);
    const head = journal.verify(old_chain, old.public_key).last_hash;
    const f = try rebuilt(arena, old, new, &head);

    // an export that failed, a file truncated to nothing, blank lines:
    // every one of them used to come back "0 entries verified", exit 0
    for ([_][]const u8{ "", "\n", "\r\n\r\n" }) |nothing| {
        try testing.expectEqual(Attribution.empty, attribute(f, "till", nothing));
    }
}

test "one key is one key however it is spelled, held or retired" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const t = T{ .files = &.{ .{ "box.machine", box_src }, .{ "till.machine", till_src } } };
    var refusal = Refusal{};

    // FR5 compared the TEXT, so the same key in two cases passed it
    const twice = "DEFINE FLEET salle_makeen AS (LINK salle) RATIONALE \"x\"\n" ++
        "DEFINE MEMBER box AS (DECLARATION \"box.machine\", KEY \"" ++ ("aa" ** 32) ++ "\") RATIONALE \"x\"\n" ++
        "DEFINE MEMBER till AS (DECLARATION \"till.machine\", KEY \"" ++ ("AA" ** 32) ++ "\") RATIONALE \"x\"\n";
    try testing.expectError(error.Refused, declare(arena, twice, t.resolver(), &refusal));
    try testing.expect(std.mem.indexOf(u8, refusal.message, "is already box's key") != null);

    // and a retirement cannot be the way round it
    refusal = Refusal{};
    const held = "DEFINE FLEET salle_makeen AS (LINK salle) RATIONALE \"x\"\n" ++
        "DEFINE MEMBER box AS (DECLARATION \"box.machine\", KEY \"" ++ ("aa" ** 32) ++ "\") RATIONALE \"x\"\n" ++
        "DEFINE MEMBER till AS (DECLARATION \"till.machine\") RATIONALE \"x\"\n" ++
        "DEFINE RETIREMENT old AS (MEMBER till, KEY \"" ++ ("AA" ** 32) ++ "\", THROUGH \"" ++ ("0" ** 64) ++ "\") RATIONALE \"x\"\n";
    try testing.expectError(error.Refused, declare(arena, held, t.resolver(), &refusal));
    try testing.expect(std.mem.indexOf(u8, refusal.message, "is already box's key") != null);
}
