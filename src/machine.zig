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

/// A serial port a hosted board carries, as a console (CON-1).
pub const Console = struct {
    /// the device PID 1 speaks on, as CONSOLE declares it
    device: []const u8,
    /// how the kernel's boot line names it, options included
    kernel: []const u8,
    /// which of QEMU's serial ports the emulator hears it on, or null when
    /// the emulator cannot carry it -- a lack its lens then names
    qemu_serial: ?u8,
};

pub const Consoles = struct {
    /// the board's ports, its default first: on this board, a machine that
    /// declares no CONSOLE speaks on the first
    ports: []const Console,
    /// what they are, for the refusal of a port the board does not have
    about: []const u8,
};

/// The consoles each hosted board HAS. CONSOLE names one of them or says
/// nothing (the kernel's own, /dev/console, which is the first). The
/// kernel's boot line follows the declaration -- the card's and the
/// emulator's -- so a port that is not here would be a machine announcing a
/// console nothing can hear. Until CON-1 the boot line came from a board
/// table and CONSOLE was only ever said, never done: a machine declaring
/// ttyS3 announced it while it spoke on ttyS0. Edge and touch boards have
/// none here: their consoles are their substrates' (MicroRing's, the
/// phone's), and this repository neither boots them nor narrates them.
pub fn boardConsoles(b: Board) Consoles {
    return switch (b) {
        .qemu_pc => .{
            .ports = &.{
                .{ .device = "/dev/ttyS0", .kernel = "ttyS0", .qemu_serial = 0 },
                .{ .device = "/dev/ttyS1", .kernel = "ttyS1", .qemu_serial = 1 },
                .{ .device = "/dev/ttyS2", .kernel = "ttyS2", .qemu_serial = 2 },
                .{ .device = "/dev/ttyS3", .kernel = "ttyS3", .qemu_serial = 3 },
            },
            .about = "the four serial ports of a PC",
        },
        .qemu_virt => .{
            .ports = &.{.{ .device = "/dev/ttyAMA0", .kernel = "ttyAMA0", .qemu_serial = 0 }},
            .about = "the emulator's one PL011",
        },
        // The header pins carry the mini-UART; the PL011 is wired to the
        // board's Bluetooth. QEMU's raspi4b models a mini-UART, and Linux's
        // driver stalls on it after two bytes (CON-1's probe): the emulator
        // cannot carry this port, and says so through its lens.
        .rpi4 => .{
            .ports = &.{.{ .device = "/dev/ttyS1", .kernel = "ttyS1,115200", .qemu_serial = null }},
            .about = "the mini-UART on the header pins; the PL011 is wired to the board's Bluetooth",
        },
        .sim, .pico2, .pico2w, .esp32c6 => .{ .ports = &.{}, .about = "" },
    };
}

/// The port a hosted machine speaks on: the one its CONSOLE names, or its
/// board's first when it declares none. Null only for a console the court
/// has already refused, or a board that has none (edge).
pub fn consolePort(m: *const Machine) ?Console {
    const cs = boardConsoles(m.board);
    if (cs.ports.len == 0) return null;
    if (std.mem.eql(u8, m.console, "/dev/console")) return cs.ports[0];
    for (cs.ports) |p| {
        if (std.mem.eql(u8, p.device, m.console)) return p;
    }
    return null;
}

/// The device a console NUMBER names, as the kernel numbers them
/// (Documentation/admin-guide/devices.txt): major 4 from minor 64 is the
/// 8250 family, ttyS; major 204 from minor 64 is the AMBA PL011, ttyAMA.
/// PID 1 asks the kernel which device /dev/console really is (TIOCGDEV)
/// and says this name, so the console line is a witness and not a
/// restatement (CON-1). `dev` is the kernel's new_encode_dev form.
pub fn consoleDevice(buf: []u8, dev: u32) []const u8 {
    const major = (dev >> 8) & 0xfff;
    const minor = (dev & 0xff) | ((dev >> 12) & 0xfff00);
    const named: ?[]const u8 = if (major == 4 and minor >= 64 and minor < 256)
        std.fmt.bufPrint(buf, "/dev/ttyS{d}", .{minor - 64}) catch null
    else if (major == 204 and minor >= 64 and minor < 96)
        std.fmt.bufPrint(buf, "/dev/ttyAMA{d}", .{minor - 64}) catch null
    else
        std.fmt.bufPrint(buf, "the device {d}:{d}", .{ major, minor }) catch null;
    return named orelse "a device";
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
    /// how many TASKS the machine will hold for this world -- the kernel's
    /// `pids.max`, which counts processes and threads together (THR-1).
    ///
    /// Together, deliberately. A thread and a process are one clone call
    /// apart and the kernel counts them in one number, so a floor that
    /// billed them separately would be inventing a distinction the kernel
    /// does not make. The runtime's own housekeeping threads count
    /// against this, which is right: the machine is sizing the WORLD, and
    /// stzr's threads are this world's threads.
    ///
    /// This is why the `threads` CAPABILITY is not enforced at the kernel
    /// and never will be here. The capability asks WHO ASKED for a
    /// thread, which only the runtime knows; this asks HOW MANY the
    /// machine will allow, which only the kernel can answer. They are
    /// different questions and each belongs to whoever can answer it.
    tasks: ?u32,
    /// the declared identity this service runs as; null is the machine
    /// itself (root), which is what a service gets only by saying nothing
    user: ?*const User,
    /// WHICH of the machine's declared mounts this world keeps sight of
    /// (SEE-1). Null is a world that did not narrow the grant, and it
    /// keeps them all -- the behaviour of every machine written before
    /// this clause. An empty list is refused rather than meaning
    /// nothing: a world that wants no storage declares no `filesystem`.
    ///
    /// This does not widen anything. `NEEDS [filesystem]` is the grant;
    /// `SEES` narrows it, which is why naming a mount without the
    /// capability is refused -- a world cannot choose sight of something
    /// it never asked to touch.
    sees: ?[]const []const u8,
    /// the directories this world OWNS (OWN-1): PID 1 makes each before the
    /// world starts, owned by the world's USER and closed to every other
    /// identity (mode 0700, at the moment it hands it over; its owner can
    /// change that), and says so only after reading it back. A world that
    /// runs as an identity can write only in a directory it owns or one the
    /// machine made open to everyone (a tmpfs mount's root is 1777), and this
    /// is how it comes to own one: the first server runs as itself and keeps
    /// its database and its signal in a place of its own, and the machine's
    /// own directories stay the machine's. Empty is a world that owns nothing.
    /// Only an identity can own a directory, so a service with a STATE has a
    /// USER, and the court judges where each one may be (`declare`).
    state: []const []const u8 = &.{},
    /// the lines of the STATE and READY clauses, where the court's second pass
    /// reports a refusal: at the line that wrote it, not at the declaration's
    state_line: usize = 0,
    ready_line: usize = 0,
    rationale: []const u8,

    /// Whether this world has the machine's declared storage in its tree at
    /// all: it declared `filesystem` (MNT-1). A world that did not has every
    /// MOUNT detached from it.
    pub fn grantsFilesystem(self: Service) bool {
        for (self.needs) |n| if (n == .filesystem) return true;
        return false;
    }

    /// Whether this world keeps sight of the MOUNT named `name`: it has the
    /// filesystem, and either narrowed nothing or named that mount (SEE-1).
    /// The ONE reading of the question -- the confinement hides what this
    /// says the world does not keep, and the court judges a STATE against the
    /// same answer, so a world is never given a directory on storage it was
    /// built not to see (EGR-3: never a second reading that has to agree).
    pub fn keeps(self: Service, name: []const u8) bool {
        if (!self.grantsFilesystem()) return false;
        const kept = self.sees orelse return true;
        for (kept) |k| if (std.mem.eql(u8, k, name)) return true;
        return false;
    }
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
pub const Destination = struct { text: []const u8, ip: u32, prefix: u6 };

/// Whether a list of destinations reaches EVERY IPv4 address, however it
/// is spelled (STZ-OS-RULING-06). `0.0.0.0/0` is the one-piece spelling;
/// `10.0.0.0/0` writes the same network over another address; `0.0.0.0/1`
/// with `128.0.0.0/1` is the same claim in two pieces. EGR-2's first fix
/// looked only for a prefix of 0, and the boot went on printing "and
/// nowhere else: no default route" over the two-piece spelling while the
/// machine reached 8.8.8.8. So the question is what the list COVERS, not
/// how it is written -- and the grammar and the boot line ask it of this
/// one function, never of two readings that have to agree.
pub fn coversEverything(dests: []const Destination) bool {
    const space: u64 = @as(u64, 1) << 32;
    // [0, reach) is covered; extend it by any destination that starts
    // inside it, until nothing extends it further
    var reach: u64 = 0;
    while (reach < space) {
        var next = reach;
        for (dests) |d| {
            const size: u64 = @as(u64, 1) << @as(u6, @intCast(32 - @as(u8, d.prefix)));
            // the NETWORK the prefix names, not the address as written
            const lo = @as(u64, d.ip) & ~(size - 1);
            if (lo <= reach and lo + size > next) next = lo + size;
        }
        if (next == reach) return false;
        reach = next;
    }
    return true;
}

/// How far a granted network reaches (EGR-1).
///
/// CAPABILITY network says the machine may speak; EGRESS says whom to.
/// `unrestricted` is what saying nothing means, and it is today's
/// behaviour: a declared GATEWAY becomes a default route and the box can
/// reach anything beyond its link. `to` is a closed list of
/// destinations, and then there is NO default route -- the box knows a
/// way to those and to nowhere else. `none` is a box that knows no way
/// off its own link at all.
///
/// What this is, precisely: the ROUTING TABLE, written from the
/// declaration. It is not a packet filter. A world with the privilege to
/// add a route could still add one -- there is no shell on the boot path
/// to do it with, and a world that runs as a declared USER has no such
/// privilege, but the guarantee is "the machine knows no way there", not
/// "the machine is prevented from finding one". A netfilter seat, which
/// would make it the second, is named in GRAMMAR.md and not built.
pub const Egress = union(enum) {
    unrestricted,
    none,
    to: []const Destination,
};
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
    egress: Egress,
    /// the name this link answers to, when the machine is the network's
    /// own server of names (NAM-1). Saying it makes this machine the one
    /// that hands out the addresses on this link and answers for the
    /// names of everything on it: the box IS `makeen`, and a declared
    /// peer is `imprimante.makeen`. Null is a machine that is merely ON a
    /// network somebody else serves.
    domain: ?[]const u8,
    rationale: []const u8,
};

/// Somebody else on this link, declared here by the machine that serves
/// it: a hardware address (who asks), an address (what it is given), and
/// a name (what everyone else calls it).
///
/// The whole design is in what is ABSENT. There is no pool and no range:
/// a peer this machine was not told about gets no address at all, so the
/// register of who has what cannot be lost at a reboot -- there is no
/// register, there is the declaration. The failure the merchant lives
/// with, a box that forgets its leases overnight and renumbers the
/// kitchen printer, is not handled here; it is made impossible to have.
pub const Peer = struct {
    name: []const u8,
    line: usize,
    network: []const u8,
    hardware: [6]u8,
    hardware_text: []const u8,
    ip: u32,
    address: []const u8,
    rationale: []const u8,
};

/// six pairs of hex, colon-separated: the only thing a DHCP server can
/// recognise a returning device by.
pub fn parseMac(s: []const u8) ?[6]u8 {
    var mac: [6]u8 = undefined;
    var it = std.mem.splitScalar(u8, s, ':');
    var n: usize = 0;
    while (it.next()) |part| : (n += 1) {
        if (n == 6 or part.len != 2) return null;
        mac[n] = std.fmt.parseInt(u8, part, 16) catch return null;
    }
    if (n != 6) return null;
    return mac;
}

/// what a name on the wire may be made of. Lowercase letters, digits and
/// the hyphen, not at either end. The estate writes `makeen_box` with an
/// underscore and DNS cannot carry one, so this refuses rather than
/// rewriting: a silently corrected name is a name the author no longer
/// knows.
pub fn isLabel(s: []const u8) bool {
    if (s.len == 0 or s.len > 63) return false;
    if (s[0] == '-' or s[s.len - 1] == '-') return false;
    for (s) |ch| {
        const ok = (ch >= 'a' and ch <= 'z') or (ch >= '0' and ch <= '9') or ch == '-';
        if (!ok) return false;
    }
    return true;
}

/// a domain is one or more labels: `makeen`, or `makeen.local`.
pub fn isDomain(s: []const u8) bool {
    if (s.len == 0 or s.len > 253) return false;
    var it = std.mem.splitScalar(u8, s, '.');
    while (it.next()) |part| if (!isLabel(part)) return false;
    return true;
}

/// A network only the machine itself can reach: its loopback, the interface `lo`
/// or an address in 127/8. It is a network the machine DECLARES, because the
/// floor builds only what a declaration asks for (BDG-1) and a readiness probe
/// that asks 127.0.0.1 needs it up -- but it is not a way to anywhere: it is no
/// NIC, no link another machine can be on, and no side of a forwarder. ONE
/// reading, asked by the judges that count networks (the guarantee sheet, the
/// image's NICs, FORWARD), so no two of them disagree about what a wire is.
pub fn isLoopback(n: Network) bool {
    if (std.mem.eql(u8, n.interface, "lo")) return true;
    return switch (n.address) {
        .static => |s| (s.ip >> 24) == 127,
        .dhcp => false,
    };
}

/// How many of these networks are links somebody else can be on
pub fn countLinks(nets: []const Network) usize {
    var n: usize = 0;
    for (nets) |x| if (!isLoopback(x)) {
        n += 1;
    };
    return n;
}

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
    /// where this device's own key lives: the seed of an Ed25519 pair
    /// PID 1 creates on first boot and never sends anywhere. The public
    /// half is who the machine IS; the private half is why anyone should
    /// believe a record it signed. It must live on a declared persistent
    /// mount, or the device is a new one every morning. Ed25519 on
    /// MicroRing's finding: signing is deterministic and needs no nonce
    /// from a board with no entropy worth the name -- and the algorithm
    /// is recorded per device, because custody and algorithm are coupled
    /// (a key held in silicon may be a P-256 key). Here custody is a
    /// file on a declared partition, and the transcript says so rather
    /// than implying it (IDN-1).
    identity: ?[]const u8,
    /// where this machine keeps its OWN record: one line per boot,
    /// hash-chained and signed by the device's key. It records what the
    /// machine was and what it judged of itself -- never what a world
    /// did, which is the world's to keep. Needs an IDENTITY to sign
    /// with and a persistent mount to survive on (JRN-1).
    journal: ?[]const u8,
    /// whether this machine is the way from one of its networks to
    /// another (FWD-1): the kernel's own forwarding, switched on once
    /// every network is up. It forwards among ALL its networks and
    /// filters nothing -- a per-network list would name a perimeter the
    /// kernel does not keep, because forwarding is decided by the
    /// interface a packet ARRIVES on and not by the one it leaves
    /// from. Needs at least two networks. Which links such a machine may
    /// join is a fact about a set, and a fleet declares it (ROUTE).
    forward: bool = false,
    /// the boot partition that holds config.txt and the two slots, when
    /// the machine updates A/B (SLOTS "/dev/mmcblk0p1"); null: single boot
    slots: ?[]const u8,
    rationale: []const u8,
    services: []const Service,
    capabilities: []const CapDecl,
    mounts: []const Mount,
    pins: []const Pin,
    networks: []const Network,
    /// everyone else this machine serves on a link it declares a DOMAIN
    /// for: an address that never changes and a name that goes with it
    peers: []const Peer,
    /// the `at` of every declared mount, kept beside them so a world's
    /// confinement can name what it may not see without walking the
    /// mounts again in three places
    mount_paths: []const []const u8,
    users: []const User,

    /// the paths this machine mounts of its own, in declaration order.
    /// The profile's implicit proc/sys/dev are not here: they are the
    /// machine's plumbing, not its storage, and a world that cannot see
    /// /proc is a world that cannot run (NS-1, MNT-1).
    pub fn mountPaths(self: Machine) []const []const u8 {
        return self.mount_paths;
    }

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

pub const Tag = enum { ident, keyword, string, number, lparen, rparen, lbracket, rbracket, comma, eof };

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

pub const Ctx = struct {
    arena: Allocator,
    src: []const u8,
    refusal: *Refusal,
    toks: []Token = &.{},
    pos: usize = 0,

    pub fn refuse(self: *Ctx, line: usize, comptime fmt: []const u8, args: anytype) Error {
        self.refusal.line = line;
        self.refusal.message = std.fmt.allocPrint(self.arena, fmt, args) catch return error.OutOfMemory;
        return error.Refused;
    }

    pub fn tokenize(self: *Ctx) Error!void {
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

    pub fn peek(self: *Ctx) Token {
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

pub const Clause = struct {
    name: []const u8,
    line: usize,
    value: Value,
};

pub const Kind = enum { MACHINE, SERVICE, CAPABILITY, MOUNT, PIN, NETWORK, USER, PEER, FLEET, MEMBER, RETIREMENT, ROUTE };

/// Which file a kind belongs in -- one language, two files (FLT-1).
///
/// Exhaustive ON PURPOSE. This was a condition that named the fleet's
/// kinds (`.FLEET or .MEMBER`), and a condition that enumerates the old
/// members of a set is how a new member walks past it: the first TASKS
/// world sat outside the cgroup its own ceiling was written on for exactly
/// that reason (THR-1). RETIREMENT added to the enum without this would
/// have been accepted in a machine file. A kind added after it does not
/// compile until somebody says which file carries it.
pub fn belongsToFleet(kind: Kind) bool {
    return switch (kind) {
        .MACHINE, .SERVICE, .CAPABILITY, .MOUNT, .PIN, .NETWORK, .USER, .PEER => false,
        .FLEET, .MEMBER, .RETIREMENT, .ROUTE => true,
    };
}

pub const Decl = struct {
    kind: Kind,
    name: []const u8,
    line: usize,
    clauses: []const Clause,
    rationale: []const u8,
};

fn allowedClauses(kind: Kind) []const []const u8 {
    return switch (kind) {
        .MACHINE => &.{ "PROFILE", "ARCH", "KERNEL", "LIBC", "BOARD", "CONSOLE", "SLOTS", "IDENTITY", "JOURNAL", "FORWARD" },
        .SERVICE => &.{ "RUN", "RESTART", "AFTER", "NEEDS", "READY", "HEALTH", "MEMORY", "CPU", "TASKS", "USER", "SEES", "STATE" },
        .CAPABILITY => &.{"GRANT"},
        .MOUNT => &.{ "AT", "FS", "DEVICE", "OPTIONS" },
        .PIN => &.{ "GPIO", "MODE" },
        .NETWORK => &.{ "INTERFACE", "ADDRESS", "GATEWAY", "DNS", "EGRESS", "DOMAIN" },
        .USER => &.{ "UID", "GID" },
        .PEER => &.{ "NETWORK", "HARDWARE", "ADDRESS" },
        .FLEET => &.{ "LINK", "LINKS" },
        .MEMBER => &.{ "DECLARATION", "KEY", "HARDWARE" },
        .RETIREMENT => &.{ "MEMBER", "KEY", "THROUGH" },
        .ROUTE => &.{ "BETWEEN", "THROUGH" },
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

pub fn parseDecl(ctx: *Ctx) Error!Decl {
    const verb = ctx.next();
    if (!(verb.tag == .keyword and std.mem.eql(u8, verb.text, "DEFINE"))) {
        return ctx.refuse(verb.line, "Unknown verb '{s}': the machine verb set is closed (DEFINE)", .{verb.text});
    }
    const kind_tok = ctx.next();
    const kind = if (kind_tok.tag == .keyword) std.meta.stringToEnum(Kind, kind_tok.text) else null;
    if (kind == null) {
        return ctx.refuse(kind_tok.line, "Unknown kind '{s}': the kinds are closed ({s})", .{ kind_tok.text, try enumNames(ctx.arena, Kind) });
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

pub fn find(d: Decl, name: []const u8) ?Clause {
    for (d.clauses) |c| if (std.mem.eql(u8, c.name, name)) return c;
    return null;
}

pub fn wantIdent(ctx: *Ctx, c: Clause) Error![]const u8 {
    return switch (c.value) {
        .ident => |s| s,
        else => ctx.refuse(c.line, "Clause {s} takes a word", .{c.name}),
    };
}
pub fn wantString(ctx: *Ctx, c: Clause) Error![]const u8 {
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
pub fn wantNames(ctx: *Ctx, c: Clause) Error![]const []const u8 {
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
pub fn required(ctx: *Ctx, d: Decl, name: []const u8) Error!Clause {
    return find(d, name) orelse ctx.refuse(d.line, "{s} is required on {s} {s}", .{ name, @tagName(d.kind), d.name });
}

// ---- paths a declaration names (OWN-1) ------------------------------------

/// The machine's own scratch directory, in RAM: where a world's signal lives
/// (READY) and one of the two places a world may own a directory (STATE).
pub const run_dir = "/run";

/// The mounts the machine makes for itself, which no MOUNT declares and no world owns a
/// directory in (the profile makes them: `plan.derive`).
pub const implicit_mounts = [_][]const u8{ "/proc", "/sys", "/dev" };

/// The longest name and the longest whole path a declaration may carry: far inside
/// what a filesystem accepts (255 and 4096), so that a path the court passed is never
/// one the kernel refuses for its length at boot.
pub const max_name = 64;
pub const max_path = 200;

/// A path of plain names: absolute, not the root, no trailing slash, no empty
/// name, no `.` or `..`, and in every name only letters, digits, `.`, `_` and
/// `-`, none longer than `max_name` and the whole no longer than `max_path`.
/// Plain on purpose: this path is walked by PID 1 as root, printed into the
/// boot transcript that is judged, and read back by a person -- a name that needs
/// quoting, or that a transcript cannot carry on one line, is not one.
pub fn plainPath(p: []const u8) bool {
    if (p.len < 2 or p.len > max_path or p[0] != '/' or p[p.len - 1] == '/') return false;
    var it = std.mem.splitScalar(u8, p[1..], '/');
    while (it.next()) |name| {
        if (name.len == 0 or name.len > max_name or std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..")) return false;
        for (name) |c| {
            const plain = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '.' or c == '_' or c == '-';
            if (!plain) return false;
        }
    }
    return true;
}

/// Whether `path` is `dir` or lies inside it, at a name boundary:
/// /data/app is inside /data, and /database is not.
pub fn within(path: []const u8, dir: []const u8) bool {
    if (!std.mem.startsWith(u8, path, dir)) return false;
    if (path.len == dir.len) return true;
    return dir[dir.len - 1] == '/' or path[dir.len] == '/';
}

/// The declared mount that HOLDS `path`: the innermost one it lies inside, or null.
/// A mount inside a mount holds what is under it, whatever is around it -- so a
/// vfat mount inside an ext4 one keeps no owners, and a tmpfs inside a disk is RAM.
/// The court judges a STATE against this answer and the image reads the disk's
/// directories off it: one reading, never two that have to agree. It is the mount
/// the path really lies on only because `declare` refuses two mounts at one mount
/// point and a mount declared before the one it lies inside (a mount made over
/// another hides it). (PID 1's own check that a refused mount is not built on asks a
/// wider question -- any refused mount the directory lies inside -- and so can refuse
/// more than this answers, never less.)
pub fn holderOf(mounts: []const Mount, path: []const u8) ?Mount {
    var holder: ?Mount = null;
    for (mounts) |mt| if (within(path, mt.at)) {
        if (holder == null or mt.at.len > holder.?.at.len) holder = mt;
    };
    return holder;
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

    // one language, two files. A machine file says what ONE machine is;
    // FLEET, MEMBER and RETIREMENT say which machines are one estate and
    // which keys it has held -- facts about no single machine, which
    // belong in a fleet file (FLT-1, RET-1). Asked of `belongsToFleet`,
    // never of a list written here, so a new kind cannot walk past it.
    for (decls.items) |d| if (belongsToFleet(d.kind)) {
        return ctx.refuse(d.line, "{s} belongs to a fleet file, not a machine file: a machine declares what one machine IS, and no machine can say who else is in its estate", .{@tagName(d.kind)});
    };

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
    if (find(md, "CONSOLE")) |c| {
        console = try wantString(&ctx, c);
        // a hosted machine speaks on a port its board HAS, because the
        // boot line follows what is declared here (CON-1). The kernel's own
        // /dev/console is every board's, and is the default.
        if (profile == .hosted and !std.mem.eql(u8, console, "/dev/console")) {
            const cs = boardConsoles(board);
            var known = false;
            for (cs.ports) |p| {
                if (std.mem.eql(u8, p.device, console)) known = true;
            }
            if (!known) {
                var list: std.ArrayList(u8) = .{};
                for (cs.ports, 0..) |p, i| {
                    const sep = if (i == 0) "" else if (i + 1 == cs.ports.len) " and " else ", ";
                    try list.appendSlice(arena, sep);
                    try list.appendSlice(arena, p.device);
                }
                return ctx.refuse(c.line, "CONSOLE {s} is not a console of BOARD {s}: its {s} {s}, {s}", .{ console, @tagName(board), if (cs.ports.len == 1) "console is" else "consoles are", list.items, cs.about });
            }
        }
    }
    // IDENTITY -- where this device's key lives. WHERE it may live is
    // checked once the mounts are known, at the end of this function.
    var identity: ?[]const u8 = null;
    if (find(md, "IDENTITY")) |c| {
        if (profile != .hosted) return ctx.refuse(c.line, "IDENTITY is a hosted machine's declaration; a machine of PROFILE {s} keeps its key in its own substrate, whose custody is the hardware's (MicroRing's identity design)", .{@tagName(profile)});
        const path = try wantString(&ctx, c);
        if (path.len == 0 or path[0] != '/') return ctx.refuse(c.line, "IDENTITY is the absolute path of this device's key, not '{s}'", .{path});
        if (!plainPath(path)) return ctx.refuse(c.line, "IDENTITY is an absolute path of plain names (\"/data/device.key\"), not '{s}': the court asks whether a world's directory holds it, and a spelling that reaches one file by two names (a '..', a trailing slash) would answer for the wrong one", .{path});
        identity = path;
    }
    var journal: ?[]const u8 = null;
    if (find(md, "JOURNAL")) |c| {
        if (profile != .hosted) return ctx.refuse(c.line, "JOURNAL is a hosted machine's declaration; a machine of PROFILE {s} keeps its record in its own substrate", .{@tagName(profile)});
        if (identity == null) return ctx.refuse(c.line, "a journal is signed by the device, and this machine declares no IDENTITY: an unsigned record is anybody's", .{});
        const path = try wantString(&ctx, c);
        if (path.len == 0 or path[0] != '/') return ctx.refuse(c.line, "JOURNAL is the absolute path of this machine's record, not '{s}'", .{path});
        if (!plainPath(path)) return ctx.refuse(c.line, "JOURNAL is an absolute path of plain names (\"/data/journal\"), not '{s}': the court asks whether a world's directory holds it, and a spelling that reaches one file by two names (a '..', a trailing slash) would answer for the wrong one", .{path});
        journal = path;
    }
    // FORWARD -- this machine is the way from one network to another
    // (FWD-1). The count of networks is checked once they are known.
    var forward = false;
    var forward_line: usize = md.line;
    if (find(md, "FORWARD")) |c| {
        if (profile != .hosted) return ctx.refuse(c.line, "FORWARD is a hosted machine's declaration; a machine of PROFILE {s} is the way between networks, if it is one, in its own substrate", .{@tagName(profile)});
        const word = try wantIdent(&ctx, c);
        if (!std.mem.eql(u8, word, "yes")) return ctx.refuse(c.line, "FORWARD is the word yes -- a machine that is not the way between networks declares nothing -- and '{s}' is not it", .{word});
        forward = true;
        forward_line = c.line;
    }
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
        // EGRESS -- how far this network reaches. Read after GATEWAY,
        // because the two can contradict each other (EGR-1).
        var egress: Egress = .unrestricted;
        if (find(d, "EGRESS")) |c| {
            switch (c.value) {
                .ident => |w| {
                    if (!std.mem.eql(u8, w, "none")) return ctx.refuse(c.line, "EGRESS is a list of destinations or the word none, not '{s}'", .{w});
                    if (gateway != null) return ctx.refuse(c.line, "a gateway is a way out, and EGRESS none says there is none: declare one or the other", .{});
                    egress = .none;
                },
                else => {
                    const strs = try wantStrings(&ctx, c);
                    if (strs.len == 0) return ctx.refuse(c.line, "an empty EGRESS is not a declaration: a list names where the machine may go, and the word none says nowhere", .{});
                    var dests: std.ArrayList(Destination) = .{};
                    for (strs) |s2| {
                        const cidr = parseCidr(s2) orelse return ctx.refuse(c.line, "EGRESS takes destinations as address/prefix (10.9.0.0/16), and '{s}' is not one", .{s2});
                        try dests.append(arena, .{ .text = s2, .ip = cidr.ip, .prefix = cidr.prefix });
                    }
                    // a list is a perimeter; one that covers every address
                    // is not one, and everywhere already has a spelling
                    if (coversEverything(dests.items)) return ctx.refuse(c.line, "EGRESS names a perimeter, and these destinations together cover every address there is: a machine that may go anywhere says so by declaring no EGRESS at all, so that a list never reads as a perimeter it is not", .{});
                    egress = .{ .to = try dests.toOwnedSlice(arena) };
                },
            }
        }
        // DOMAIN -- the machine is this link's own server of names
        // (NAM-1). It is the one clause that turns a machine from an
        // inhabitant of a network into the network's address.
        var domain: ?[]const u8 = null;
        if (find(d, "DOMAIN")) |c| {
            if (address == .dhcp) return ctx.refuse(c.line, "{s} asks for its own address by dhcp, and a machine that asks for its own address is not the one that hands them out: a serving link declares a static ADDRESS", .{d.name});
            const s = try wantString(&ctx, c);
            if (!isDomain(s)) return ctx.refuse(c.line, "'{s}' cannot be a domain: a name on the wire is lowercase letters, digits and the hyphen, in labels separated by dots", .{s});
            // A domain names ONE link. Two links of one machine that answer to the same
            // one would make a name on either a name on both, and a machine that is the
            // way between them (FWD-1) could never be asked for the far one by its full name.
            for (nets.items) |e| if (e.domain) |ed| if (std.mem.eql(u8, ed, s)) {
                return ctx.refuse(c.line, "{s} serves {s}, which {s} already serves: one machine answers for a domain once, or a name on one link would be a name on both", .{ d.name, s, e.name });
            };
            domain = s;
        }
        try nets.append(arena, .{ .name = d.name, .line = d.line, .interface = iface, .address = address, .gateway = gateway, .egress = egress, .dns = try dns.toOwnedSlice(arena), .domain = domain, .rationale = d.rationale });
    };

    // a loopback is a network the machine declares and not a way to anywhere:
    // it is not counted, and not one side of a forwarder
    if (forward and countLinks(nets.items) < 2) return ctx.refuse(forward_line, "FORWARD says this machine is the way from one network to another, and it declares {d}: a machine with fewer than two networks has nothing to forward between (a loopback is not a way to anywhere)", .{countLinks(nets.items)});
    if (forward) for (nets.items) |n| if (n.egress == .none and !isLoopback(n)) {
        return ctx.refuse(n.line, "EGRESS none says {s} knows no way off its own link, and FORWARD makes this machine the way between its networks: a machine that forwards is a way off every link it joins, so it cannot say there is none", .{n.name});
    };

    // peers: who else is on a link this machine serves. Read after the
    // networks, because every check a peer needs is a fact about its link.
    var peers: std.ArrayList(Peer) = .{};
    for (decls.items) |d| if (d.kind == .PEER) {
        const nc = try required(&ctx, d, "NETWORK");
        const nname = try wantIdent(&ctx, nc);
        var link: ?Network = null;
        for (nets.items) |n| if (std.mem.eql(u8, n.name, nname)) {
            link = n;
        };
        const net = link orelse return ctx.refuse(nc.line, "PEER {s} is on {s}, and there is no such NETWORK in this declaration", .{ d.name, nname });
        const dom = net.domain orelse return ctx.refuse(d.line, "PEER {s} is on {s}, and {s} declares no DOMAIN: a machine that does not serve a link has no addresses to give out on it and no names to answer for", .{ d.name, nname, nname });
        if (!isLabel(d.name)) return ctx.refuse(d.line, "'{s}' cannot be a name on {s}: a name on the wire is lowercase letters, digits and the hyphen, not at either end", .{ d.name, dom });
        const hw_c = try required(&ctx, d, "HARDWARE");
        const hw_text = try wantString(&ctx, hw_c);
        const mac = parseMac(hw_text) orelse return ctx.refuse(hw_c.line, "HARDWARE is six pairs of hex separated by colons (b8:27:eb:11:22:33), and '{s}' is not: it is what this machine recognises a returning device by, so it is the device's, not a word for it", .{hw_text});
        const ac2 = try required(&ctx, d, "ADDRESS");
        const atext = try wantString(&ctx, ac2);
        const ip = parseIpv4(atext) orelse return ctx.refuse(ac2.line, "'{s}' is not an address (a.b.c.d): a peer is given one address, not a range", .{atext});
        // a DOMAIN refuses a dhcp ADDRESS above, so a link with a domain
        // is static -- said here rather than assumed.
        const self = switch (net.address) {
            .static => |s| s,
            .dhcp => return ctx.refuse(d.line, "PEER {s} is on {s}, which asks for its own address", .{ d.name, nname }),
        };
        const mask: u32 = if (self.prefix == 0) 0 else ~@as(u32, 0) << @intCast(32 - @as(u6, self.prefix));
        if ((ip & mask) != (self.ip & mask)) return ctx.refuse(ac2.line, "{s} is not on {s} ({s}): a machine hands out addresses on its own link and nowhere else", .{ atext, nname, self.text });
        if (ip == self.ip) return ctx.refuse(ac2.line, "{s} is the machine's own address on {s}: the one address on this link it cannot give away", .{ atext, nname });
        for (peers.items) |e| {
            if (!std.mem.eql(u8, e.network, nname)) continue;
            if (e.ip == ip) return ctx.refuse(ac2.line, "{s} is already {s}'s: one address, one peer, or the name does not mean anything", .{ atext, e.name });
            if (std.mem.eql(u8, e.hardware_text, hw_text)) return ctx.refuse(hw_c.line, "{s} is already {s}'s hardware: one device, one name", .{ hw_text, e.name });
            if (std.mem.eql(u8, e.name, d.name)) return ctx.refuse(d.line, "{s}.{s} is already declared: one name, one peer", .{ d.name, dom });
        }
        try peers.append(arena, .{ .name = d.name, .line = d.line, .network = nname, .hardware = mac, .hardware_text = hw_text, .ip = ip, .address = atext, .rationale = d.rationale });
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
        var ready_line: usize = 0;
        if (find(d, "READY")) |c| {
            ready_line = c.line;
            if (restart == .never) return ctx.refuse(c.line, "READY is a daemon's signal; {s} is a one-shot (RESTART never) and its readiness is its exit 0", .{d.name});
            const path = try wantString(&ctx, c);
            if (path.len == 0 or path[0] != '/') return ctx.refuse(c.line, "READY is the absolute path the service creates when it is serving, not '{s}'", .{path});
            // PID 1 reads this path as root, and the court asks whether it sits inside a directory a world
            // owns: a spelling that reaches one file by two names (a trailing slash that names the directory
            // itself, a '..' that leaves it) would be judged as the wrong place and read as the right one (OWN-1)
            if (!plainPath(path)) return ctx.refuse(c.line, "READY is an absolute path of plain names (\"/run/app/ready\"), not '{s}': PID 1 reads it as root, and a spelling that reaches one file by two names (a trailing slash, a '..') is how a signal sits where no rule judged it", .{path});
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
        var tasks: ?u32 = null;
        if (find(d, "TASKS")) |c| {
            const n = try wantNumber(&ctx, c);
            if (n == 0) return ctx.refuse(c.line, "TASKS 0 is a world that may hold no task at all, and a world with no task cannot run", .{});
            if (n > 4096) return ctx.refuse(c.line, "TASKS {d}: the number counts tasks -- processes and threads together -- and four thousand is more than this grammar admits for one world", .{n});
            tasks = @intCast(n);
        }
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

        // SEES -- which of the machine's mounts this world keeps. Read
        // after NEEDS, because it narrows a grant and there must be one.
        var sees: ?[]const []const u8 = null;
        if (find(d, "SEES")) |c| {
            var granted_fs = false;
            for (needs.items) |n| {
                if (n == .filesystem) granted_fs = true;
            }
            if (!granted_fs) return ctx.refuse(c.line, "{s} SEES a mount and needs filesystem for it: a world cannot choose sight of storage it never asked to touch, and SEES narrows that grant rather than making one", .{d.name});
            const names = try wantNames(&ctx, c);
            if (names.len == 0) return ctx.refuse(c.line, "an empty SEES is not a declaration: a world that wants no storage declares no filesystem, and one that wants all of it says nothing here", .{});
            for (names, 0..) |name, i| {
                for (names[0..i]) |e| if (std.mem.eql(u8, e, name)) {
                    return ctx.refuse(c.line, "{s} is already named in {s}'s SEES: saying it twice says nothing the once did not", .{ name, d.name });
                };
            }
            // that every name IS a declared mount is judged in a second
            // pass below: MOUNTs are parsed after SERVICEs, and a check
            // cannot ask about something the parser has not read yet
            sees = names;
        }

        // STATE -- the directories this world owns (OWN-1). Read after USER, because a
        // directory is owned by an identity or by nobody, and a world with no identity is
        // the machine itself. Only the SHAPE of each path is judged here; where it IS
        // (under /run, or on a mount the world keeps) is judged below, once the MOUNTs are read.
        var state: []const []const u8 = &.{};
        var state_line: usize = 0;
        if (find(d, "STATE")) |c| {
            state_line = c.line;
            if (user == null) return ctx.refuse(c.line, "{s} declares STATE and no USER: a world with no declared identity is the machine itself and owns every place, so a directory made for it would be made for nobody; declare the USER that is to own it", .{d.name});
            const paths = switch (c.value) {
                .string_list => |l| l,
                .name_list => |l| if (l.len == 0) l else return ctx.refuse(c.line, "STATE takes a list of paths in strings (\"/data/app\"), not words", .{}),
                else => return ctx.refuse(c.line, "STATE takes a list of paths in strings (\"/data/app\")", .{}),
            };
            if (paths.len == 0) return ctx.refuse(c.line, "an empty STATE is not a declaration: a world that owns nothing of its own declares none", .{});
            for (paths) |p| if (!plainPath(p)) return ctx.refuse(c.line, "STATE is an absolute path of plain names (\"/data/app\": letters, digits, '.', '_' and '-' between slashes), not '{s}': no relative path, no '.' or '..', no empty name and no trailing slash", .{p});
            state = paths;
        }
        try services.append(arena, .{ .name = d.name, .line = d.line, .run = run, .restart = restart, .after = after, .needs = try needs.toOwnedSlice(arena), .ready = ready, .health = health, .memory_mb = memory_mb, .cpu_percent = cpu_percent, .tasks = tasks, .user = user, .sees = sees, .state = state, .state_line = state_line, .ready_line = ready_line, .rationale = d.rationale });
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

    // a key on a filesystem that dies with the power is a new device
    // every morning, which is the one thing an identity must never be
    if (identity) |key| {
        var kept = false;
        for (mounts.items) |mt| {
            if (mt.fs != .ext4 and mt.fs != .vfat) continue;
            if (!std.mem.startsWith(u8, key, mt.at)) continue;
            if (mt.at.len == 1 or key.len == mt.at.len or key[mt.at.len] == '/') kept = true;
        }
        if (!kept) return ctx.refuse(md.line, "IDENTITY {s} is where the key lives, and no declared MOUNT keeps it: a key on a filesystem that dies with the power is a new device every morning", .{key});
    }
    if (journal) |rec| {
        var kept = false;
        for (mounts.items) |mt| {
            if (mt.fs != .ext4 and mt.fs != .vfat) continue;
            if (!std.mem.startsWith(u8, rec, mt.at)) continue;
            if (mt.at.len == 1 or rec.len == mt.at.len or rec[mt.at.len] == '/') kept = true;
        }
        if (!kept) return ctx.refuse(md.line, "JOURNAL {s} is where the record lives, and no declared MOUNT keeps it: a record that dies with the power is not a record", .{rec});
    }

    // the declared mounts, and their paths beside them: a world's
    // confinement names what it may not see, and walking the mounts again
    // in three places is three chances to disagree (MNT-1)
    const mount_slice = try mounts.toOwnedSlice(arena);

    // The machine mounts in the order it is written, and a mount made over another hides it: so two
    // mounts do not share a mount point, and a mount that lies inside another is declared after it.
    // Only on those terms is the INNERMOST mount holding a path the one it really lies on (`holderOf`,
    // which STATE and the image's `state.list` both ask).
    for (mount_slice, 0..) |a, i| for (mount_slice[i + 1 ..]) |b| {
        if (std.mem.eql(u8, a.at, b.at)) return ctx.refuse(b.line, "MOUNT {s} is at {s}, where MOUNT {s} already is: one mount point, one mount, or the second hides the first", .{ b.name, b.at, a.name });
        if (within(a.at, b.at)) return ctx.refuse(a.line, "MOUNT {s} lies inside MOUNT {s}, which is declared after it: the machine mounts in the order written, and a mount made over another hides it, so declare {s} first", .{ a.name, b.name, b.name });
    };

    // SEE-1's other half: a world sees a mount this machine DECLARES, or
    // none. Here rather than in the service loop because the MOUNTs are
    // parsed after the SERVICEs, and a refusal must be able to name what
    // the declaration actually contains.
    for (svc_slice) |sv| {
        const wants = sv.sees orelse continue;
        if (mount_slice.len == 0) return ctx.refuse(sv.line, "{s} SEES a mount and this machine declares no MOUNT: there is no sight to apportion", .{sv.name});
        for (wants) |name| {
            var found = false;
            for (mount_slice) |mt| {
                if (std.mem.eql(u8, mt.name, name)) found = true;
            }
            if (!found) return ctx.refuse(sv.line, "{s} SEES {s}, and there is no such MOUNT in this declaration", .{ sv.name, name });
        }
    }

    // OWN-1's other half: where each STATE directory IS, and who else is near it. Here
    // and not in the service loop for the same reason as SEES above: the MOUNTs are read
    // after the SERVICEs, and the pass needs every world's directories at once.
    for (svc_slice, 0..) |sv, si| {
        for (sv.state, 0..) |dir, di| {
            // the machine's own mounts are not in `mount_slice` (the profile makes them), and a MOUNT
            // declared at `/` would otherwise be taken for what holds them
            for (implicit_mounts) |imp| if (within(dir, imp)) return ctx.refuse(sv.state_line, "STATE {s} is inside {s}, which the machine mounts itself: not a place a world may own", .{ dir, imp });
            // The place a directory lies in is the INNERMOST mount that holds it
            if (holderOf(mount_slice, dir)) |mt| {
                if (dir.len == mt.at.len) return ctx.refuse(sv.state_line, "STATE {s} is the place itself, not a directory in it: /run and the root of a MOUNT are the machine's, and a world owns a directory inside one", .{dir});
                if (mt.fs != .ext4 and mt.fs != .tmpfs) return ctx.refuse(sv.state_line, "STATE {s} is inside MOUNT {s}, a {s} filesystem, which keeps no owners: only ext4 and tmpfs can hand a directory to an identity", .{ dir, mt.name, @tagName(mt.fs) });
                for (mt.options) |o| if (o == .ro) return ctx.refuse(sv.state_line, "STATE {s} is inside MOUNT {s}, which is read-only: nothing can be made on it", .{ dir, mt.name });
                if (!sv.grantsFilesystem()) return ctx.refuse(sv.state_line, "STATE {s} is inside MOUNT {s}, and {s} does not declare the filesystem, so the machine's storage is not in its tree", .{ dir, mt.name, sv.name });
                if (!sv.keeps(mt.name)) return ctx.refuse(sv.state_line, "STATE {s} is inside MOUNT {s}, which {s} does not keep (SEES): a directory on storage the world cannot see is no place for it", .{ dir, mt.name, sv.name });
                // what a world does not keep is detached from its tree, and detaching a mount takes the
                // mounts inside it along (MNT-1): a mount the world names inside one it does not is empty to it
                for (mount_slice) |outer| {
                    if (outer.at.len >= mt.at.len or !within(mt.at, outer.at)) continue;
                    if (!sv.keeps(outer.name)) return ctx.refuse(sv.state_line, "STATE {s} is inside MOUNT {s}, which lies inside MOUNT {s}, and {s} does not keep {s}: detaching a mount takes the mounts inside it along, so the directory is not in the world's tree", .{ dir, mt.name, outer.name, sv.name, outer.name });
                }
            } else if (within(dir, run_dir)) {
                if (dir.len == run_dir.len) return ctx.refuse(sv.state_line, "STATE {s} is the place itself, not a directory in it: /run and the root of a MOUNT are the machine's, and a world owns a directory inside one", .{dir});
            } else {
                return ctx.refuse(sv.state_line, "STATE {s} is in no place a world may own: a world owns a directory under /run (RAM) or inside a MOUNT it keeps, and this is neither", .{dir});
            }
            // a directory has one owner: no two of a machine's STATE paths overlap, in one
            // world or in two (each pair is asked once)
            // (reported at the LATER claim's line: it is the one that made the conflict, and when a pack
            // was placed on a machine that passed alone it is the pack's, so the refusal lands where the
            // pack's author can read it)
            for (svc_slice, 0..) |ov, oi| for (ov.state, 0..) |other, oj| {
                if (oi < si or (oi == si and oj <= di)) continue;
                if (within(dir, other) or within(other, dir)) return ctx.refuse(ov.state_line, "STATE {s} overlaps {s}, which {s} owns: a directory has one owner, and one inside another is two owners of the same files", .{ other, dir, sv.name });
            };
            // the floor's own key and record are in no directory a world owns (JRN-1): the
            // owner of a directory can replace what is in it
            if (identity) |key| if (within(key, dir)) return ctx.refuse(sv.state_line, "STATE {s} holds IDENTITY {s}: the floor's own key and record are not a world's to replace (JRN-1), so they sit where no world owns the directory", .{ dir, key });
            if (journal) |rec| if (within(rec, dir)) return ctx.refuse(sv.state_line, "STATE {s} holds JOURNAL {s}: the floor's own key and record are not a world's to replace (JRN-1), so they sit where no world owns the directory", .{ dir, rec });
        }
    }
    // A world's word that it serves is a file, and who can write that file decides whether
    // the word means anything. A world that runs as an identity can create a file only in a
    // directory it owns; and nobody's signal sits in a place ANOTHER world owns.
    for (svc_slice, 0..) |sv, si| {
        const ready = sv.ready orelse continue;
        if (sv.user) |u| {
            // DIRECTLY in a directory it owns: the image makes every directory above a signal as
            // root's (`image.zig`), and a world cannot create a file in one it does not own
            var inside = false;
            const parent = std.fs.path.dirnamePosix(ready) orelse "/";
            for (sv.state) |dir| if (std.mem.eql(u8, parent, dir)) {
                inside = true;
            };
            if (!inside) return ctx.refuse(sv.ready_line, "{s} runs as {s} and signals ready on {s}, which is not directly in a directory it owns: a world that is not root cannot create a file in a directory the machine owns, so its signal sits in one the world owns, not in a directory below it -- declare it in STATE", .{ sv.name, u.name, ready });
        }
        for (svc_slice, 0..) |ow, oi| {
            if (oi == si) continue;
            for (ow.state) |dir| if (within(ready, dir)) {
                // reported at whichever came LATER in the text, the signal or the directory that holds
                // it: the claim that arrived second made the conflict, and is the pack's when a pack was
                // placed on a machine that passed alone
                const at = if (oi > si) ow.state_line else sv.ready_line;
                return ctx.refuse(at, "{s} signals ready on {s}, inside {s}'s STATE {s}: the world that owns the directory can write or delete the signal, so no world's word that it serves may sit in another's place", .{ sv.name, ready, ow.name, dir });
            };
        }
    }
    var mount_paths: std.ArrayList([]const u8) = .{};
    for (mount_slice) |mt| try mount_paths.append(arena, mt.at);
    const mount_path_slice = try mount_paths.toOwnedSlice(arena);

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
        .identity = identity,
        .journal = journal,
        .forward = forward,
        .rationale = md.rationale,
        .services = svc_slice,
        .capabilities = cap_slice,
        .mounts = mount_slice,
        .mount_paths = mount_path_slice,
        .pins = try pins.toOwnedSlice(arena),
        .networks = try nets.toOwnedSlice(arena),
        .peers = try peers.toOwnedSlice(arena),
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

test "a console number names the device PID 1 says, and every port is one the board has" {
    const t = std.testing;
    var buf: [48]u8 = undefined;
    // the numbers TIOCGDEV returns: major << 8 | minor, for minors < 256
    try t.expectEqualStrings("/dev/ttyS0", consoleDevice(&buf, (4 << 8) | 64));
    try t.expectEqualStrings("/dev/ttyS3", consoleDevice(&buf, (4 << 8) | 67));
    try t.expectEqualStrings("/dev/ttyAMA0", consoleDevice(&buf, (204 << 8) | 64));
    // a number that is no serial port is named as a number, never guessed
    try t.expectEqualStrings("the device 5:1", consoleDevice(&buf, (5 << 8) | 1));

    // every hosted board has a first port, and the first is where a machine
    // that declares nothing speaks; the edge boards have none of harb's
    for ([_]Board{ .qemu_pc, .qemu_virt, .rpi4 }) |b| {
        const cs = boardConsoles(b);
        try t.expect(cs.ports.len > 0);
        for (cs.ports) |p| {
            try t.expect(std.mem.startsWith(u8, p.device, "/dev/"));
            // the kernel's spelling of a port begins with its device's name
            try t.expect(std.mem.startsWith(u8, p.kernel, p.device["/dev/".len..]));
        }
    }
    try t.expectEqual(@as(usize, 0), boardConsoles(.pico2).ports.len);
}

test "a list covers everything however it is spelled, and half the space is still a perimeter" {
    const t = std.testing;
    const D = Destination;
    const all = [_]D{.{ .text = "0.0.0.0/0", .ip = 0, .prefix = 0 }};
    const elsewhere = [_]D{.{ .text = "10.0.0.0/0", .ip = 0x0A000000, .prefix = 0 }};
    const halves = [_]D{ .{ .text = "128.0.0.0/1", .ip = 0x80000000, .prefix = 1 }, .{ .text = "0.0.0.0/1", .ip = 0, .prefix = 1 } };
    const quarters = [_]D{ .{ .text = "a", .ip = 0x00000000, .prefix = 2 }, .{ .text = "b", .ip = 0x40000000, .prefix = 2 }, .{ .text = "c", .ip = 0x80000000, .prefix = 2 }, .{ .text = "d", .ip = 0xC0000000, .prefix = 2 } };
    const half = [_]D{.{ .text = "0.0.0.0/1", .ip = 0, .prefix = 1 }};
    const gap = [_]D{ .{ .text = "0.0.0.0/2", .ip = 0, .prefix = 2 }, .{ .text = "128.0.0.0/1", .ip = 0x80000000, .prefix = 1 } };
    const one = [_]D{.{ .text = "10.9.0.0/16", .ip = 0x0A090000, .prefix = 16 }};
    try t.expect(coversEverything(&all));
    try t.expect(coversEverything(&elsewhere)); // the network, not the address as written
    try t.expect(coversEverything(&halves)); // two pieces, in either order
    try t.expect(coversEverything(&quarters));
    try t.expect(!coversEverything(&half)); // half the internet IS a perimeter
    try t.expect(!coversEverything(&gap)); // 64.0.0.0/2 is missing
    try t.expect(!coversEverything(&one));
}

test "a STATE path is plain names under a root, and containment is at a name boundary (OWN-1)" {
    const t = std.testing;
    try t.expect(plainPath("/run/app"));
    try t.expect(plainPath("/data/app.d/state_1-x"));
    try t.expect(!plainPath("/"));
    try t.expect(!plainPath("run/app"));
    try t.expect(!plainPath("/run/app/"));
    try t.expect(!plainPath("/run//app"));
    try t.expect(!plainPath("/run/./app"));
    try t.expect(!plainPath("/run/../etc"));
    try t.expect(!plainPath("/run/my app")); // a name a transcript must quote is not plain
    try t.expect(!plainPath("/run/a\tb"));

    try t.expect(within("/data/app", "/data"));
    try t.expect(within("/data", "/data"));
    try t.expect(!within("/database", "/data")); // a prefix of a NAME is not inside
    try t.expect(!within("/dat", "/data"));
    try t.expect(within("/anything", "/")); // a mount at the root holds everything
}

test "a world keeps a mount only if it has the filesystem and has not narrowed it away" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    var r = Refusal{};
    const src =
        \\DEFINE MACHINE m AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE "x"
        \\DEFINE CAPABILITY filesystem AS (GRANT yes) RATIONALE "x"
        \\DEFINE MOUNT data AS (AT "/data", FS tmpfs, OPTIONS [rw]) RATIONALE "x"
        \\DEFINE MOUNT logs AS (AT "/logs", FS tmpfs, OPTIONS [rw]) RATIONALE "x"
        \\DEFINE SERVICE none AS (RUN ["/a"]) RATIONALE "x"
        \\DEFINE SERVICE all AS (RUN ["/b"], NEEDS [filesystem]) RATIONALE "x"
        \\DEFINE SERVICE one AS (RUN ["/c"], NEEDS [filesystem], SEES [data]) RATIONALE "x"
    ;
    const m = try declare(arena_state.allocator(), src, &r);
    try t.expect(!m.services[0].keeps("data")); // no filesystem: no storage in its tree
    try t.expect(!m.services[0].grantsFilesystem());
    try t.expect(m.services[1].keeps("data") and m.services[1].keeps("logs")); // saying nothing keeps them all
    try t.expect(m.services[2].keeps("data") and !m.services[2].keeps("logs")); // SEES narrows
}
