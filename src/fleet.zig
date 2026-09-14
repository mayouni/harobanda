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
//! `stzos fleet`, as a member whose record nobody can verify yet. The
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

pub const Fleet = struct {
    name: []const u8,
    line: usize,
    /// the wire these machines share. Saying it is what turns a list of
    /// machines into a NETWORK whose coherence can be judged: within one
    /// fleet, every member's network of this name is the same link.
    /// Without it a fleet is an estate and not a wire, and only the
    /// identity checks apply.
    link: ?[]const u8,
    members: []const Member,
    rationale: []const u8,

    pub fn member(self: Fleet, name: []const u8) ?Member {
        for (self.members) |m| if (std.mem.eql(u8, m.name, name)) return m;
        return null;
    }

    /// The link's server of names, if the fleet declares a link and a
    /// member serves it.
    pub fn server(self: Fleet) ?Member {
        const link = self.link orelse return null;
        for (self.members) |m| {
            for (m.machine.networks) |n| {
                if (!std.mem.eql(u8, n.name, link)) continue;
                if (n.domain != null) return m;
            }
        }
        return null;
    }
};

fn hexKey(text: []const u8) ?Ed25519.PublicKey {
    if (text.len != 64) return null;
    var raw: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&raw, text) catch return null;
    return Ed25519.PublicKey.fromBytes(raw) catch null;
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
    for (decls.items) |d| switch (d.kind) {
        .FLEET, .MEMBER => {},
        else => return ctx.refuse(d.line, "{s} belongs to a machine file, not a fleet file: a fleet says which machines are one estate, never what any one of them is", .{@tagName(d.kind)}),
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
    var link: ?[]const u8 = null;
    if (machine.find(fd, "LINK")) |c| link = try machine.wantIdent(&ctx, c);

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
            if (key_text != null and e.key_text != null and std.mem.eql(u8, key_text.?, e.key_text.?)) {
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

    const f = Fleet{
        .name = fd.name,
        .line = fd.line,
        .link = link,
        .members = try members.toOwnedSlice(arena),
        .rationale = fd.rationale,
    };

    // ---- the checks no single machine can make ----------------------
    if (link) |wire| {
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

    return f;
}

// ---- attribution: one machine verifying another's record ---------------

/// The peer the link's server promises this member an address as, if
/// the member says which device it is and the server has it in its
/// register. It is the join HDW-1 exists to make.
pub fn promisedTo(f: Fleet, m: Member) ?machine.Peer {
    const wire = f.link orelse return null;
    const hw = m.hardware orelse return null;
    const sv = f.server() orelse return null;
    if (std.mem.eql(u8, sv.name, m.name)) return null;
    for (sv.machine.peers) |p| {
        if (!std.mem.eql(u8, p.network, wire)) continue;
        if (std.mem.eql(u8, &p.hardware, &hw)) return p;
    }
    return null;
}

pub const Attribution = union(enum) {
    /// the record is this member's, entire and in order
    verified: journal.Check,
    /// the record does not verify, and the check says where and why
    broken: journal.Check,
    /// the member exists and nobody has enrolled its key
    not_enrolled,
    no_such_member,
};

/// Verify a member's signed boot record using ONLY what the fleet holds:
/// the member's public key. No private key takes part, so this is an act
/// any holder of the fleet file can perform -- another box on the wire,
/// the court on a laptop, an auditor years later.
pub fn attribute(f: Fleet, member_name: []const u8, record: []const u8) Attribution {
    const m = f.member(member_name) orelse return .no_such_member;
    const key = m.key orelse return .not_enrolled;
    const check = journal.verify(record, key);
    return if (check.broken_at == null) .{ .verified = check } else .{ .broken = check };
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
