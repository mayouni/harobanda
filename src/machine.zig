// machine.zig -- the machine declaration language, v0.1: tokenizer,
// parser and court-side checks. A `.machine` file DECLARES a machine
// (its profile, its services, its capabilities, its mounts, its pins);
// nothing here computes, mounts or spawns. The boot plan is derived in
// plan.zig; the act is init.zig's.
//
// Lexical form is the Grammar Commons (C6), adopted whole as stzu did:
// `--` comments, double-quoted strings that may span lines (leading
// whitespace on a continuation line folds to one space), lower_snake
// identifiers, UPPER_SNAKE keywords, a mixed-case word refused at the
// tokenizer, `[a, b, c,]` lists with a trailing comma allowed, CRLF
// never diagnosed.
//
// The refusal channel has one shape -- `machine (line N): message` --
// for tokenizer, parser and check refusals alike, and every refusal
// names its reason: the fixtures (declarative/machine/fixtures.json)
// carry the fragment each refusal must contain, so a runtime refusing
// for the WRONG reason fails (exemplar gap G8, applied from birth).

const std = @import("std");
const Allocator = std.mem.Allocator;

// ---- the closed menus --------------------------------------------------

pub const Profile = enum { hosted, edge, touch };
pub const Arch = enum { x86_64, aarch64, riscv32, riscv64, thumbv7em, thumbv8m };
pub const Kernel = enum { linux, none, android };
pub const Libc = enum { musl, none, bionic };
/// The board a machine is built for, hosted or edge. Each profile has its
/// own menu and its own emulator board, and a board of the other profile
/// is refused by name:
///   hosted: qemu_pc, qemu_virt (the emulator court) and rpi4, the
///           Raspberry Pi 4 Model B chosen 2026-09-12 (doc/PROVENANCE.md)
///   edge:   sim (MicroRing's own simulator board) and the boards its
///           tiers name -- pico2/pico2w (RP2350, tier 2, its flagship)
///           and esp32c6 (tier 3). A touch machine's device is the phone
///           and declares no board.
pub const Board = enum { qemu_pc, qemu_virt, rpi4, sim, pico2, pico2w, esp32c6 };

pub fn boardProfile(b: Board) Profile {
    return switch (b) {
        .qemu_pc, .qemu_virt, .rpi4 => .hosted,
        .sim, .pico2, .pico2w, .esp32c6 => .edge,
    };
}
pub const Restart = enum { never, always, on_failure };
pub const PinMode = enum { in, out };
pub const Fs = enum { proc, sysfs, devtmpfs, tmpfs, ext4, vfat, littlefs, cgroup2 };
pub const MountOption = enum { rw, ro, noatime, nosuid, nodev, noexec };

/// The capability vocabulary is stzlib's own (base/system/stzSystemProfile.ring):
/// nine names on a four-kind lattice. The name IS the capability; a
/// CAPABILITY declaration only says whether the machine grants it.
pub const Capability = enum {
    filesystem,
    process,
    network,
    environment,
    dynamic_load,
    gpio,
    threads,
    clock,
    inference,
};
pub const CapKind = enum { effectful, sensing, compute, inference };

pub fn kindOf(c: Capability) CapKind {
    return switch (c) {
        .filesystem, .process, .network, .environment, .dynamic_load, .gpio => .effectful,
        .threads => .compute,
        .clock => .sensing,
        .inference => .inference,
    };
}

/// A word that is a shell is refused as the first word of RUN. The real
/// guarantee is the image's (a profile ships no shell); this check is the
/// grammar's echo of that law, so the declaration cannot even ask.
const shells = [_][]const u8{ "sh", "bash", "dash", "ash", "zsh", "fish", "ksh", "csh", "tcsh" };

// ---- the declared structure --------------------------------------------

pub const Service = struct {
    name: []const u8,
    line: usize,
    run: []const []const u8,
    restart: Restart,
    after: []const []const u8,
    needs: []const Capability,
    /// a daemon's own signal that it is SERVING, not merely spawned: the
    /// path it creates when it is up. A one-shot has no use for it (its
    /// readiness is its exit 0) and is refused one.
    ready: ?[]const u8,
    /// the window, in seconds, within which the daemon must REFRESH that
    /// path -- its word that it is serving STILL. A world can be alive
    /// and wedged; the kernel cannot tell the difference and the
    /// watchdog was fed regardless until HLT-1. With a window declared,
    /// PID 1 feeds the hardware only while every world is fresh, and a
    /// trial commits only after each has proven one full window. Null is
    /// a world that answers for its start and never again.
    health: ?u32,
    /// the ceiling the KERNEL holds this world to, in mebibytes: the
    /// memory controller kills what goes past it, inside this world's
    /// own group, and no other world feels it (BDG-1). Null is a world
    /// that may take the whole box down with it.
    memory_mb: ?u32,
    /// the share of ONE core, as a percentage: 50 is half a core, 200 is
    /// two of them. The scheduler throttles past it rather than killing:
    /// a world that wants more time waits, and its neighbours do not.
    cpu_percent: ?u32,
    /// the declared identity this service runs as; null is the machine
    /// itself (root), which is what a service gets only by saying nothing
    user: ?*const User,
    rationale: []const u8,
};

pub const CapDecl = struct {
    name: Capability,
    granted: bool,
    line: usize,
    rationale: []const u8,
};

pub const Mount = struct {
    name: []const u8,
    line: usize,
    at: []const u8,
    fs: Fs,
    device: ?[]const u8,
    options: []const MountOption,
    rationale: []const u8,
};

pub const Pin = struct {
    name: []const u8,
    line: usize,
    gpio: u32,
    mode: PinMode,
    rationale: []const u8,
};

/// A declared identity. A machine has no /etc/passwd of its own until it
/// declares one: the image derives passwd and group from these, and PID 1
/// drops to the uid and gid before exec. uid 0 is refused -- root is the
/// machine itself, and a service that must be root simply declares no USER.
pub const User = struct {
    name: []const u8,
    line: usize,
    uid: u32,
    gid: u32,
    rationale: []const u8,
};

pub const Ipv4 = struct { text: []const u8, addr: u32 };
pub const Address = union(enum) {
    dhcp,
    static: struct { text: []const u8, ip: u32, prefix: u6 },
};

/// A declared network: one interface, one way to an address. PID 1 brings
/// it up before any service runs (a NETWORK is to the wire what a MOUNT is
/// to the disk). A static address may declare its GATEWAY and DNS; a dhcp
/// address learns them.
pub const Network = struct {
    name: []const u8,
    line: usize,
    interface: []const u8,
    address: Address,
    gateway: ?Ipv4,
    dns: []const Ipv4,
    rationale: []const u8,
};

pub fn parseIpv4(s: []const u8) ?u32 {
    var ip: u32 = 0;
    var it = std.mem.splitScalar(u8, s, '.');
    var n: usize = 0;
    while (it.next()) |part| : (n += 1) {
        if (n == 4 or part.len == 0) return null;
        const b = std.fmt.parseInt(u8, part, 10) catch return null;
        ip = (ip << 8) | b;
    }
    if (n != 4) return null;
    return ip;
}

pub fn parseCidr(spec: []const u8) ?struct { ip: u32, prefix: u6 } {
    const slash = std.mem.indexOfScalar(u8, spec, '/') orelse return null;
    const prefix = std.fmt.parseInt(u6, spec[slash + 1 ..], 10) catch return null;
    if (prefix > 32) return null;
    const ip = parseIpv4(spec[0..slash]) orelse return null;
    return .{ .ip = ip, .prefix = prefix };
}

pub const Machine = struct {
    name: []const u8,
    line: usize,
    profile: Profile,
    arch: Arch,
    kernel: Kernel,
    libc: Libc,
    board: Board,
    console: []const u8,
    /// the boot partition that holds config.txt and the two slots, when
    /// the machine updates A/B (SLOTS "/dev/mmcblk0p1"); null: single boot
    slots: ?[]const u8,
    rationale: []const u8,
    services: []const Service,
    capabilities: []const CapDecl,
    mounts: []const Mount,
    pins: []const Pin,
    networks: []const Network,
    users: []const User,

    pub fn granted(self: Machine, c: Capability) bool {
        for (self.capabilities) |d| if (d.name == c) return d.granted;
        return false;
    }
    pub fn service(self: Machine, name: []const u8) ?*const Service {
        for (self.services) |*s| if (std.mem.eql(u8, s.name, name)) return s;
        return null;
    }
};

pub const Refusal = struct {
    line: usize = 0,
    message: []const u8 = "",
};

pub const Error = error{ Refused, OutOfMemory };

// ---- tokens --------------------------------------------------------------

const Tag = enum { ident, keyword, string, number, lparen, rparen, lbracket, rbracket, comma, eof };

const Token = struct {
    tag: Tag,
    text: []const u8,
    line: usize,
};

fn isLower(c: u8) bool {
    return (c >= 'a' and c <= 'z') or c == '_' or (c >= '0' and c <= '9');
}
fn isUpper(c: u8) bool {
    return (c >= 'A' and c <= 'Z') or c == '_' or (c >= '0' and c <= '9');
}
fn isWordChar(c: u8) bool {
    return isLower(c) or isUpper(c);
}

const Ctx = struct {
    arena: Allocator,
    src: []const u8,
    refusal: *Refusal,
    toks: []Token = &.{},
    pos: usize = 0,

    fn refuse(self: *Ctx, line: usize, comptime fmt: []const u8, args: anytype) Error {
        self.refusal.line = line;
        self.refusal.message = std.fmt.allocPrint(self.arena, fmt, args) catch return error.OutOfMemory;
        return error.Refused;
    }

    fn tokenize(self: *Ctx) Error!void {
        var list: std.ArrayList(Token) = .{};
        var i: usize = 0;
        var line: usize = 1;
        const s = self.src;
        while (i < s.len) {
            const c = s[i];
            if (c == '\n') {
                line += 1;
                i += 1;
                continue;
            }
            if (c == ' ' or c == '\t' or c == '\r') {
                i += 1;
                continue;
            }
            if (c == '-' and i + 1 < s.len and s[i + 1] == '-') {
                while (i < s.len and s[i] != '\n') i += 1;
                continue;
            }
            if (c == '"') {
                const start_line = line;
                var buf: std.ArrayList(u8) = .{};
                i += 1;
                var closed = false;
                while (i < s.len) {
                    const d = s[i];
                    if (d == '"') {
                        closed = true;
                        i += 1;
                        break;
                    }
                    if (d == '\n') {
                        // C6 3.2: a continuation line's leading whitespace folds to one space
                        line += 1;
                        i += 1;
                        while (i < s.len and (s[i] == ' ' or s[i] == '\t' or s[i] == '\r')) i += 1;
                        try buf.append(self.arena, ' ');
                        continue;
                    }
                    if (d == '\r') {
                        i += 1;
                        continue;
                    }
                    try buf.append(self.arena, d);
                    i += 1;
                }
                if (!closed) return self.refuse(start_line, "Unterminated string", .{});
                try list.append(self.arena, .{ .tag = .string, .text = try buf.toOwnedSlice(self.arena), .line = start_line });
                continue;
            }
            if (c >= '0' and c <= '9') {
                const start = i;
                while (i < s.len and s[i] >= '0' and s[i] <= '9') i += 1;
                if (i < s.len and isWordChar(s[i])) {
                    return self.refuse(line, "'{s}' is neither a number nor a word", .{s[start .. i + 1]});
                }
                try list.append(self.arena, .{ .tag = .number, .text = s[start..i], .line = line });
                continue;
            }
            if (isWordChar(c)) {
                const start = i;
                while (i < s.len and isWordChar(s[i])) i += 1;
                const word = s[start..i];
                var all_lower = true;
                var all_upper = true;
                for (word) |w| {
                    if (w >= 'a' and w <= 'z') all_upper = false;
                    if (w >= 'A' and w <= 'Z') all_lower = false;
                }
                if (all_lower) {
                    try list.append(self.arena, .{ .tag = .ident, .text = word, .line = line });
                } else if (all_upper) {
                    try list.append(self.arena, .{ .tag = .keyword, .text = word, .line = line });
                } else {
                    return self.refuse(line, "'{s}' is neither a lower_snake identifier nor an UPPER_SNAKE keyword", .{word});
                }
                continue;
            }
            const punct: ?Tag = switch (c) {
                '(' => .lparen,
                ')' => .rparen,
                '[' => .lbracket,
                ']' => .rbracket,
                ',' => .comma,
                else => null,
            };
            if (punct) |p| {
                try list.append(self.arena, .{ .tag = p, .text = s[i .. i + 1], .line = line });
                i += 1;
                continue;
            }
            return self.refuse(line, "The character '{s}' is not part of the machine grammar", .{s[i .. i + 1]});
        }
        try list.append(self.arena, .{ .tag = .eof, .text = "", .line = line });
        self.toks = try list.toOwnedSlice(self.arena);
    }

    fn peek(self: *Ctx) Token {
        return self.toks[self.pos];
    }
    fn next(self: *Ctx) Token {
        const t = self.toks[self.pos];
        if (t.tag != .eof) self.pos += 1;
        return t;
    }
    fn expect(self: *Ctx, tag: Tag, what: []const u8) Error!Token {
        const t = self.next();
        if (t.tag != tag) return self.refuse(t.line, "Expected {s}, found '{s}'", .{ what, if (t.tag == .eof) "end of file" else t.text });
        return t;
    }
};

// ---- the clause layer ----------------------------------------------------

const Value = union(enum) {
    ident: []const u8,
    string: []const u8,
    number: u64,
    name_list: []const []const u8,
    string_list: []const []const u8,
};

const Clause = struct {
    name: []const u8,
    line: usize,
    value: Value,
};

const Kind = enum { MACHINE, SERVICE, CAPABILITY, MOUNT, PIN, NETWORK, USER };

const Decl = struct {
    kind: Kind,
    name: []const u8,
    line: usize,
    clauses: []const Clause,
    rationale: []const u8,
};

fn allowedClauses(kind: Kind) []const []const u8 {
    return switch (kind) {
        .MACHINE => &.{ "PROFILE", "ARCH", "KERNEL", "LIBC", "BOARD", "CONSOLE", "SLOTS" },
        .SERVICE => &.{ "RUN", "RESTART", "AFTER", "NEEDS", "READY", "HEALTH", "MEMORY", "CPU", "USER" },
        .CAPABILITY => &.{"GRANT"},
        .MOUNT => &.{ "AT", "FS", "DEVICE", "OPTIONS" },
        .PIN => &.{ "GPIO", "MODE" },
        .NETWORK => &.{ "INTERFACE", "ADDRESS", "GATEWAY", "DNS" },
        .USER => &.{ "UID", "GID" },
    };
}

fn joinNames(arena: Allocator, names: []const []const u8) Error![]const u8 {
    var buf: std.ArrayList(u8) = .{};
    for (names, 0..) |n, i| {
        if (i > 0) try buf.appendSlice(arena, ", ");
        try buf.appendSlice(arena, n);
    }
    return buf.toOwnedSlice(arena);
}

fn enumNames(arena: Allocator, comptime E: type) Error![]const u8 {
    const fields = @typeInfo(E).@"enum".fields;
    var names: [fields.len][]const u8 = undefined;
    inline for (fields, 0..) |f, i| names[i] = f.name;
    return joinNames(arena, &names);
}

fn parseValue(ctx: *Ctx) Error!Value {
    const t = ctx.next();
    switch (t.tag) {
        .ident => return .{ .ident = t.text },
        .string => return .{ .string = t.text },
        .number => return .{ .number = std.fmt.parseInt(u64, t.text, 10) catch return ctx.refuse(t.line, "'{s}' is not a number", .{t.text}) },
        .lbracket => {
            var names: std.ArrayList([]const u8) = .{};
            var strings: std.ArrayList([]const u8) = .{};
            while (true) {
                const e = ctx.peek();
                if (e.tag == .rbracket) {
                    _ = ctx.next();
                    break;
                }
                const item = ctx.next();
                switch (item.tag) {
                    .ident => try names.append(ctx.arena, item.text),
                    .string => try strings.append(ctx.arena, item.text),
                    else => return ctx.refuse(item.line, "A list holds words or strings, found '{s}'", .{if (item.tag == .eof) "end of file" else item.text}),
                }
                const sep = ctx.peek();
                if (sep.tag == .comma) {
                    _ = ctx.next();
                } else if (sep.tag != .rbracket) {
                    return ctx.refuse(sep.line, "Expected ',' or ']' in a list, found '{s}'", .{if (sep.tag == .eof) "end of file" else sep.text});
                }
            }
            if (names.items.len > 0 and strings.items.len > 0) return ctx.refuse(t.line, "A list is all words or all strings, never mixed", .{});
            if (strings.items.len > 0) return .{ .string_list = try strings.toOwnedSlice(ctx.arena) };
            return .{ .name_list = try names.toOwnedSlice(ctx.arena) };
        },
        else => return ctx.refuse(t.line, "Expected a clause value, found '{s}'", .{if (t.tag == .eof) "end of file" else t.text}),
    }
}

fn parseDecl(ctx: *Ctx) Error!Decl {
    const verb = ctx.next();
    if (!(verb.tag == .keyword and std.mem.eql(u8, verb.text, "DEFINE"))) {
        return ctx.refuse(verb.line, "Unknown verb '{s}': the machine verb set is closed (DEFINE)", .{verb.text});
    }
    const kind_tok = ctx.next();
    const kind = if (kind_tok.tag == .keyword) std.meta.stringToEnum(Kind, kind_tok.text) else null;
    if (kind == null) {
        return ctx.refuse(kind_tok.line, "Unknown kind '{s}': the machine kinds are closed (MACHINE, SERVICE, CAPABILITY, MOUNT, PIN, NETWORK, USER)", .{kind_tok.text});
    }
    const name = try ctx.expect(.ident, "a lower_snake name");
    const as_tok = ctx.next();
    if (!(as_tok.tag == .keyword and std.mem.eql(u8, as_tok.text, "AS"))) return ctx.refuse(as_tok.line, "Expected AS after the name, found '{s}'", .{as_tok.text});
    _ = try ctx.expect(.lparen, "'('");

    var clauses: std.ArrayList(Clause) = .{};
    const allowed = allowedClauses(kind.?);
    while (true) {
        const t = ctx.peek();
        if (t.tag == .rparen) {
            _ = ctx.next();
            break;
        }
        const cname = ctx.next();
        if (cname.tag != .keyword) return ctx.refuse(cname.line, "Expected a clause name, found '{s}'", .{if (cname.tag == .eof) "end of file" else cname.text});
        var ok = false;
        for (allowed) |a| if (std.mem.eql(u8, a, cname.text)) {
            ok = true;
        };
        if (!ok) return ctx.refuse(cname.line, "Unknown clause '{s}' for {s}: allowed are {s}", .{ cname.text, @tagName(kind.?), try joinNames(ctx.arena, allowed) });
        for (clauses.items) |c| if (std.mem.eql(u8, c.name, cname.text)) return ctx.refuse(cname.line, "Clause {s} given twice", .{cname.text});
        const value = try parseValue(ctx);
        try clauses.append(ctx.arena, .{ .name = cname.text, .line = cname.line, .value = value });
        const sep = ctx.peek();
        if (sep.tag == .comma) {
            _ = ctx.next();
        } else if (sep.tag != .rparen) {
            return ctx.refuse(sep.line, "Expected ',' or ')' after a clause, found '{s}'", .{if (sep.tag == .eof) "end of file" else sep.text});
        }
    }
    const rat = ctx.next();
    if (!(rat.tag == .keyword and std.mem.eql(u8, rat.text, "RATIONALE"))) {
        return ctx.refuse(rat.line, "RATIONALE is mandatory on every declaration ({s} {s} has none)", .{ @tagName(kind.?), name.text });
    }
    const rtext = try ctx.expect(.string, "the RATIONALE string");
    return .{ .kind = kind.?, .name = name.text, .line = name.line, .clauses = try clauses.toOwnedSlice(ctx.arena), .rationale = rtext.text };
}

// ---- typed clause readers ------------------------------------------------

fn find(d: Decl, name: []const u8) ?Clause {
    for (d.clauses) |c| if (std.mem.eql(u8, c.name, name)) return c;
    return null;
}

fn wantIdent(ctx: *Ctx, c: Clause) Error![]const u8 {
    return switch (c.value) {
        .ident => |s| s,
        else => ctx.refuse(c.line, "Clause {s} takes a word", .{c.name}),
    };
}
fn wantString(ctx: *Ctx, c: Clause) Error![]const u8 {
    return switch (c.value) {
        .string => |s| s,
        else => ctx.refuse(c.line, "Clause {s} takes a string", .{c.name}),
    };
}
fn wantNumber(ctx: *Ctx, c: Clause) Error!u64 {
    return switch (c.value) {
        .number => |n| n,
        else => ctx.refuse(c.line, "Clause {s} takes a number", .{c.name}),
    };
}
fn wantNames(ctx: *Ctx, c: Clause) Error![]const []const u8 {
    return switch (c.value) {
        .name_list => |l| l,
        .string_list => |l| if (l.len == 0) l else ctx.refuse(c.line, "Clause {s} takes a list of words", .{c.name}),
        else => ctx.refuse(c.line, "Clause {s} takes a list of words", .{c.name}),
    };
}
fn wantStrings(ctx: *Ctx, c: Clause) Error![]const []const u8 {
    return switch (c.value) {
        .string_list => |l| l,
        .name_list => |l| if (l.len == 0) l else ctx.refuse(c.line, "Clause {s} takes a string list, one word of the argv per string", .{c.name}),
        else => ctx.refuse(c.line, "Clause {s} takes a string list, one word of the argv per string", .{c.name}),
    };
}
fn wantEnum(ctx: *Ctx, comptime E: type, c: Clause, comptime what: []const u8) Error!E {
    const word = try wantIdent(ctx, c);
    return std.meta.stringToEnum(E, word) orelse ctx.refuse(c.line, "{s} is {s}, not '{s}'", .{ c.name, what, word });
}
fn required(ctx: *Ctx, d: Decl, name: []const u8) Error!Clause {
    return find(d, name) orelse ctx.refuse(d.line, "{s} is required on {s} {s}", .{ name, @tagName(d.kind), d.name });
}

// ---- declare: parse, then judge -----------------------------------------

/// Parse and check one `.machine` source. On refusal, `refusal` carries
/// the line and the message and the error is `Refused`. All returned
/// memory lives in `arena`.
pub fn declare(arena: Allocator, src: []const u8, refusal: *Refusal) Error!Machine {
    var ctx = Ctx{ .arena = arena, .src = src, .refusal = refusal };
    try ctx.tokenize();

    var decls: std.ArrayList(Decl) = .{};
    while (ctx.peek().tag != .eof) try decls.append(arena, try parseDecl(&ctx));
    if (decls.items.len == 0) return ctx.refuse(1, "A machine file declares exactly one MACHINE; this file declares nothing", .{});

    // one MACHINE, first
    var machines: usize = 0;
    for (decls.items) |d| if (d.kind == .MACHINE) {
        machines += 1;
    };
    if (machines != 1) return ctx.refuse(decls.items[0].line, "A machine file declares exactly one MACHINE (found {d})", .{machines});
    if (decls.items[0].kind != .MACHINE) return ctx.refuse(decls.items[0].line, "The MACHINE declaration comes first", .{});

    // one namespace
    for (decls.items, 0..) |d, i| {
        for (decls.items[0..i]) |e| if (std.mem.eql(u8, d.name, e.name)) {
            return ctx.refuse(d.line, "'{s}' is already declared (line {d}); one namespace, no duplicates", .{ d.name, e.line });
        };
    }

    // the machine
    const md = decls.items[0];
    const profile = try wantEnum(&ctx, Profile, try required(&ctx, md, "PROFILE"), "hosted, edge or touch");
    const arch = try wantEnum(&ctx, Arch, try required(&ctx, md, "ARCH"), "x86_64, aarch64, riscv32, riscv64 or thumbv7em");
    const kernel = try wantEnum(&ctx, Kernel, try required(&ctx, md, "KERNEL"), "linux, none or android");
    const expected_kernel: Kernel = switch (profile) {
        .hosted => .linux,
        .edge => .none,
        .touch => .android,
    };
    if (kernel != expected_kernel) {
        return ctx.refuse(md.line, "PROFILE {s} contradicts KERNEL {s}: a machine of PROFILE {s} runs on KERNEL {s}", .{ @tagName(profile), @tagName(kernel), @tagName(profile), @tagName(expected_kernel) });
    }
    const default_libc: Libc = switch (profile) {
        .hosted => .musl,
        .edge => .none,
        .touch => .bionic,
    };
    var libc = default_libc;
    if (find(md, "LIBC")) |c| {
        libc = try wantEnum(&ctx, Libc, c, "musl, none or bionic");
        if (libc != default_libc) return ctx.refuse(c.line, "PROFILE {s} contradicts LIBC {s}: a machine of PROFILE {s} links LIBC {s}", .{ @tagName(profile), @tagName(libc), @tagName(profile), @tagName(default_libc) });
    }
    var board: Board = switch (profile) {
        .hosted => if (arch == .x86_64) Board.qemu_pc else Board.qemu_virt,
        .edge => Board.sim, // the emulator board of the edge profile, MicroRing's own
        .touch => Board.qemu_virt, // unused: a touch machine's device is the phone
    };
    if (find(md, "BOARD")) |c| {
        board = try wantEnum(&ctx, Board, c, "qemu_pc, qemu_virt, rpi4 (hosted) or sim, pico2, pico2w, esp32c6 (edge)");
        // the profile check comes first: the court convicted the other
        // order on R35 (an edge machine naming a hosted board was refused
        // for its ARCH, the truer reason being the profile)
        if (profile == .touch) return ctx.refuse(c.line, "BOARD is for a hosted or an edge machine; a touch machine's device is the phone the pack is installed on", .{});
        if (boardProfile(board) != profile) {
            return ctx.refuse(c.line, "PROFILE {s} contradicts BOARD {s}: that is a board of the {s} profile", .{ @tagName(profile), @tagName(board), @tagName(boardProfile(board)) });
        }
        const wanted_arch: ?Arch = switch (board) {
            .qemu_pc => .x86_64,
            .qemu_virt, .rpi4 => .aarch64,
            .pico2, .pico2w => .thumbv8m,
            .esp32c6 => .riscv32,
            .sim => null, // the simulator runs whatever the machine declares
        };
        if (wanted_arch) |wa| if (wa != arch) {
            return ctx.refuse(c.line, "ARCH {s} contradicts BOARD {s}: that board is {s}", .{ @tagName(arch), @tagName(board), @tagName(wa) });
        };
    }
    var console: []const u8 = switch (profile) {
        .hosted => "/dev/console",
        .edge => "uart0",
        .touch => "logcat",
    };
    if (find(md, "CONSOLE")) |c| console = try wantString(&ctx, c);
    var slots: ?[]const u8 = null;
    if (find(md, "SLOTS")) |c| {
        const dev = try wantString(&ctx, c);
        if (dev.len == 0 or dev[0] != '/') return ctx.refuse(c.line, "SLOTS is the boot partition's device, an absolute path, not '{s}'", .{dev});
        if (board != .rpi4) return ctx.refuse(c.line, "SLOTS needs a board that boots from a card under a firmware that can try a slot (rpi4); {s} loads the kernel directly", .{@tagName(board)});
        slots = dev;
    }

    // capabilities first (services and pins refer to them)
    var caps: std.ArrayList(CapDecl) = .{};
    for (decls.items) |d| if (d.kind == .CAPABILITY) {
        const cap = std.meta.stringToEnum(Capability, d.name) orelse return ctx.refuse(d.line, "'{s}' is not a capability: the menu is {s}", .{ d.name, try enumNames(arena, Capability) });
        const g = try required(&ctx, d, "GRANT");
        const word = try wantIdent(&ctx, g);
        const granted = if (std.mem.eql(u8, word, "yes")) true else if (std.mem.eql(u8, word, "no")) false else return ctx.refuse(g.line, "GRANT is yes or no, not '{s}'", .{word});
        try caps.append(arena, .{ .name = cap, .granted = granted, .line = d.line, .rationale = d.rationale });
    };
    const cap_slice = try caps.toOwnedSlice(arena);
    const grantedCap = struct {
        fn f(list: []const CapDecl, c: Capability) ?bool {
            for (list) |d| if (d.name == c) return d.granted;
            return null;
        }
    }.f;

    // users: declared identities, before the services that name them
    var users: std.ArrayList(User) = .{};
    for (decls.items) |d| if (d.kind == .USER) {
        if (profile != .hosted) return ctx.refuse(d.line, "USER is a hosted machine's declaration; a machine of PROFILE {s} runs one program and has no identities to hand out", .{@tagName(profile)});
        const uid = try wantNumber(&ctx, try required(&ctx, d, "UID"));
        if (uid == 0) return ctx.refuse(d.line, "uid 0 is the machine itself; a service that must be root declares no USER rather than a root one", .{});
        if (uid > 65534) return ctx.refuse(d.line, "uid {d} is out of range (1..65534)", .{uid});
        var gid: u64 = uid;
        if (find(d, "GID")) |c| {
            gid = try wantNumber(&ctx, c);
            if (gid == 0) return ctx.refuse(c.line, "gid 0 is the machine's own group; a service that must have it declares no USER", .{});
            if (gid > 65534) return ctx.refuse(c.line, "gid {d} is out of range (1..65534)", .{gid});
        }
        for (users.items) |e| if (e.uid == uid) {
            return ctx.refuse(d.line, "uid {d} is already {s}'s; one number, one identity", .{ uid, e.name });
        };
        try users.append(arena, .{ .name = d.name, .line = d.line, .uid = @intCast(uid), .gid = @intCast(gid), .rationale = d.rationale });
    };
    const user_slice = try users.toOwnedSlice(arena);

    // networks: one per interface, the network capability granted
    var nets: std.ArrayList(Network) = .{};
    for (decls.items) |d| if (d.kind == .NETWORK) {
        switch (grantedCap(cap_slice, .network) orelse return ctx.refuse(d.line, "NETWORK {s} needs network, which no declaration grants", .{d.name})) {
            true => {},
            false => return ctx.refuse(d.line, "NETWORK {s} needs network, which is declared and refused (GRANT no)", .{d.name}),
        }
        const iface = try wantString(&ctx, try required(&ctx, d, "INTERFACE"));
        if (iface.len == 0) return ctx.refuse(d.line, "INTERFACE names the interface (\"eth0\"), not an empty string", .{});
        for (nets.items) |e| if (std.mem.eql(u8, e.interface, iface)) {
            return ctx.refuse(d.line, "{s} already has a network ({s}); one network per interface", .{ iface, e.name });
        };
        const ac = try required(&ctx, d, "ADDRESS");
        const address: Address = switch (ac.value) {
            .ident => |w| if (std.mem.eql(u8, w, "dhcp")) Address.dhcp else return ctx.refuse(ac.line, "ADDRESS is dhcp or an address/prefix string, not '{s}'", .{w}),
            .string => |s| blk: {
                const c = parseCidr(s) orelse return ctx.refuse(ac.line, "'{s}' is not an address/prefix (a.b.c.d/n)", .{s});
                break :blk Address{ .static = .{ .text = s, .ip = c.ip, .prefix = c.prefix } };
            },
            else => return ctx.refuse(ac.line, "ADDRESS is dhcp or an address/prefix string", .{}),
        };
        var gateway: ?Ipv4 = null;
        if (find(d, "GATEWAY")) |c| {
            if (address == .dhcp) return ctx.refuse(c.line, "a dhcp network learns its gateway; GATEWAY is for a static ADDRESS", .{});
            const s = try wantString(&ctx, c);
            gateway = .{ .text = s, .addr = parseIpv4(s) orelse return ctx.refuse(c.line, "'{s}' is not an address (a.b.c.d)", .{s}) };
        }
        var dns: std.ArrayList(Ipv4) = .{};
        if (find(d, "DNS")) |c| {
            if (address == .dhcp) return ctx.refuse(c.line, "a dhcp network learns its dns servers; DNS is for a static ADDRESS", .{});
            for (try wantStrings(&ctx, c)) |s| {
                try dns.append(arena, .{ .text = s, .addr = parseIpv4(s) orelse return ctx.refuse(c.line, "'{s}' is not an address (a.b.c.d)", .{s}) });
            }
        }
        try nets.append(arena, .{ .name = d.name, .line = d.line, .interface = iface, .address = address, .gateway = gateway, .dns = try dns.toOwnedSlice(arena), .rationale = d.rationale });
    };

    // services
    var services: std.ArrayList(Service) = .{};
    for (decls.items) |d| if (d.kind == .SERVICE) {
        const run_c = try required(&ctx, d, "RUN");
        const run = try wantStrings(&ctx, run_c);
        if (run.len == 0) return ctx.refuse(run_c.line, "RUN must name a program: the argv is empty", .{});
        const base = std.fs.path.basenamePosix(run[0]);
        for (shells) |sh| if (std.mem.eql(u8, base, sh)) {
            return ctx.refuse(run_c.line, "A service is an argv, never a shell line: the boot path has no shell ('{s}')", .{run[0]});
        };
        var restart: Restart = .never;
        if (find(d, "RESTART")) |c| restart = try wantEnum(&ctx, Restart, c, "never, always or on_failure");
        var after: []const []const u8 = &.{};
        if (find(d, "AFTER")) |c| after = try wantNames(&ctx, c);
        var needs: std.ArrayList(Capability) = .{};
        if (find(d, "NEEDS")) |c| {
            for (try wantNames(&ctx, c)) |n| {
                const cap = std.meta.stringToEnum(Capability, n) orelse return ctx.refuse(c.line, "'{s}' is not a capability: the menu is {s}", .{ n, try enumNames(arena, Capability) });
                switch (grantedCap(cap_slice, cap) orelse return ctx.refuse(c.line, "{s} needs {s}, which no declaration grants", .{ d.name, n })) {
                    true => {},
                    false => return ctx.refuse(c.line, "{s} needs {s}, which is declared and refused (GRANT no)", .{ d.name, n }),
                }
                try needs.append(arena, cap);
            }
        }
        var ready: ?[]const u8 = null;
        if (find(d, "READY")) |c| {
            if (restart == .never) return ctx.refuse(c.line, "READY is a daemon's signal; {s} is a one-shot (RESTART never) and its readiness is its exit 0", .{d.name});
            const path = try wantString(&ctx, c);
            if (path.len == 0 or path[0] != '/') return ctx.refuse(c.line, "READY is the absolute path the service creates when it is serving, not '{s}'", .{path});
            for (services.items) |e| if (e.ready) |other| if (std.mem.eql(u8, other, path)) {
                return ctx.refuse(c.line, "{s} already signals on {s}; one path signals for one service", .{ e.name, path });
            };
            ready = path;
        }
        // HEALTH reads AFTER ready, because it is measured on that path
        var health: ?u32 = null;
        if (find(d, "HEALTH")) |c| {
            if (ready == null) return ctx.refuse(c.line, "HEALTH is measured on the READY path, and {s} declares none: a world with nothing to refresh cannot be found wedged", .{d.name});
            const secs = try wantNumber(&ctx, c);
            if (secs == 0) return ctx.refuse(c.line, "HEALTH 0 is not a window: a world that never has to refresh is a world that can stop serving unnoticed", .{});
            if (secs > 3600) return ctx.refuse(c.line, "HEALTH {d} is longer than an hour: a window nobody would wait out is a promise the watchdog cannot keep", .{secs});
            health = @intCast(secs);
        }
        // the ceilings the kernel holds (BDG-1). A budget is a fact of
        // the world, not of the machine: the machine's own total is the
        // board's, and a world that names a ceiling names its own.
        var memory_mb: ?u32 = null;
        if (find(d, "MEMORY")) |c| {
            const mb = try wantNumber(&ctx, c);
            if (mb == 0) return ctx.refuse(c.line, "MEMORY 0 is not a ceiling: a world that may hold nothing cannot run at all", .{});
            if (mb > 1024 * 1024) return ctx.refuse(c.line, "MEMORY {d} is more than a tebibyte; the number is mebibytes, not bytes", .{mb});
            memory_mb = @intCast(mb);
        }
        var cpu_percent: ?u32 = null;
        if (find(d, "CPU")) |c| {
            const pct = try wantNumber(&ctx, c);
            if (pct == 0) return ctx.refuse(c.line, "CPU 0 is a service that cannot run: the number is a percentage of ONE core, and 100 is that core", .{});
            if (pct > 1600) return ctx.refuse(c.line, "CPU {d} is more than sixteen cores' worth; 1600 is the ceiling this grammar admits", .{pct});
            cpu_percent = @intCast(pct);
        }
        var user: ?*const User = null;
        if (find(d, "USER")) |c| {
            const uname = try wantIdent(&ctx, c);
            for (user_slice) |*u| if (std.mem.eql(u8, u.name, uname)) {
                user = u;
            };
            if (user == null) return ctx.refuse(c.line, "{s} runs as '{s}', which resolves to nothing: no such USER", .{ d.name, uname });
        }
        try services.append(arena, .{ .name = d.name, .line = d.line, .run = run, .restart = restart, .after = after, .needs = try needs.toOwnedSlice(arena), .ready = ready, .health = health, .memory_mb = memory_mb, .cpu_percent = cpu_percent, .user = user, .rationale = d.rationale });
    };
    const svc_slice = try services.toOwnedSlice(arena);

    // AFTER resolves (G6), never to itself, never in a cycle
    for (svc_slice) |s| {
        for (s.after) |a| {
            if (std.mem.eql(u8, a, s.name)) return ctx.refuse(s.line, "{s} comes after itself", .{s.name});
            var found = false;
            for (svc_slice) |t| if (std.mem.eql(u8, t.name, a)) {
                found = true;
            };
            if (!found) return ctx.refuse(s.line, "{s} comes AFTER '{s}', which resolves to nothing: no such SERVICE", .{ s.name, a });
        }
    }
    {
        // Kahn over declaration order; anything left is a cycle
        const started = try arena.alloc(bool, svc_slice.len);
        @memset(started, false);
        var count: usize = 0;
        while (count < svc_slice.len) {
            var progressed = false;
            for (svc_slice, 0..) |s, i| {
                if (started[i]) continue;
                var ready = true;
                for (s.after) |a| {
                    for (svc_slice, 0..) |t, j| if (std.mem.eql(u8, t.name, a) and !started[j]) {
                        ready = false;
                    };
                }
                if (ready) {
                    started[i] = true;
                    count += 1;
                    progressed = true;
                    break;
                }
            }
            if (!progressed) {
                for (svc_slice, 0..) |s, i| if (!started[i]) {
                    return ctx.refuse(s.line, "AFTER forms a cycle through {s}: no order starts it", .{s.name});
                };
            }
        }
    }

    // mounts
    var mounts: std.ArrayList(Mount) = .{};
    for (decls.items) |d| if (d.kind == .MOUNT) {
        if (profile == .touch) return ctx.refuse(d.line, "The touch profile owns no mounts: Android's init does ({s})", .{d.name});
        const at = try wantString(&ctx, try required(&ctx, d, "AT"));
        if (at.len == 0 or at[0] != '/') return ctx.refuse(d.line, "AT is an absolute path, not '{s}'", .{at});
        const fs_c = try required(&ctx, d, "FS");
        const fs = try wantEnum(&ctx, Fs, fs_c, "proc, sysfs, devtmpfs, tmpfs, ext4, vfat or littlefs");
        const edge_ok = fs == .littlefs or fs == .vfat or fs == .tmpfs;
        const hosted_ok = fs != .littlefs;
        if (profile == .edge and !edge_ok) return ctx.refuse(fs_c.line, "{s} is not a filesystem of the edge profile (littlefs, vfat, tmpfs)", .{@tagName(fs)});
        if (profile == .hosted and !hosted_ok) return ctx.refuse(fs_c.line, "{s} is not a filesystem of the hosted profile", .{@tagName(fs)});
        var device: ?[]const u8 = null;
        if (find(d, "DEVICE")) |c| device = try wantString(&ctx, c);
        const needs_device = fs == .ext4 or fs == .vfat or fs == .littlefs;
        if (needs_device and device == null) return ctx.refuse(d.line, "MOUNT {s} on {s} needs a DEVICE", .{ d.name, @tagName(fs) });
        var opts: std.ArrayList(MountOption) = .{};
        if (find(d, "OPTIONS")) |c| {
            for (try wantNames(&ctx, c)) |o| {
                try opts.append(arena, std.meta.stringToEnum(MountOption, o) orelse return ctx.refuse(c.line, "'{s}' is not a mount option: the menu is {s}", .{ o, try enumNames(arena, MountOption) }));
            }
        }
        try mounts.append(arena, .{ .name = d.name, .line = d.line, .at = at, .fs = fs, .device = device, .options = try opts.toOwnedSlice(arena), .rationale = d.rationale });
    };

    // pins
    var pins: std.ArrayList(Pin) = .{};
    for (decls.items) |d| if (d.kind == .PIN) {
        if (profile == .touch) return ctx.refuse(d.line, "The touch profile owns no pins ({s})", .{d.name});
        switch (grantedCap(cap_slice, .gpio) orelse return ctx.refuse(d.line, "PIN {s} needs gpio, and no declaration grants gpio", .{d.name})) {
            true => {},
            false => return ctx.refuse(d.line, "PIN {s} needs gpio, which is declared and refused (GRANT no)", .{d.name}),
        }
        const n = try wantNumber(&ctx, try required(&ctx, d, "GPIO"));
        const mode = try wantEnum(&ctx, PinMode, try required(&ctx, d, "MODE"), "in or out");
        try pins.append(arena, .{ .name = d.name, .line = d.line, .gpio = @intCast(n), .mode = mode, .rationale = d.rationale });
    };

    return .{
        .name = md.name,
        .line = md.line,
        .profile = profile,
        .arch = arch,
        .kernel = kernel,
        .libc = libc,
        .board = board,
        .console = console,
        .slots = slots,
        .rationale = md.rationale,
        .services = svc_slice,
        .capabilities = cap_slice,
        .mounts = try mounts.toOwnedSlice(arena),
        .pins = try pins.toOwnedSlice(arena),
        .networks = try nets.toOwnedSlice(arena),
        .users = user_slice,
    };
}

// ---- unit tests: the mechanism, with its negative siblings ---------------

test "the minimal machine is accepted with defaults" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    var r = Refusal{};
    const m = try declare(arena_state.allocator(), "DEFINE MACHINE hello AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE \"x\"", &r);
    try std.testing.expectEqualStrings("hello", m.name);
    try std.testing.expectEqual(Libc.musl, m.libc);
    try std.testing.expectEqualStrings("/dev/console", m.console);
}

test "a shell line is refused by name" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    var r = Refusal{};
    const src = "DEFINE MACHINE m AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE \"x\"\nDEFINE SERVICE s AS (RUN [\"/bin/sh\", \"-c\", \"ls\"]) RATIONALE \"y\"";
    try std.testing.expectError(error.Refused, declare(arena_state.allocator(), src, &r));
    try std.testing.expect(std.mem.indexOf(u8, r.message, "never a shell line") != null);
    try std.testing.expectEqual(@as(usize, 2), r.line);
}
