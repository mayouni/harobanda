//! What a world may SEE and what it may ASK the kernel for (NS-1).
//!
//! ## Nothing new is declared
//!
//! This seat adds no clause. `NEEDS` has said what a world requires since
//! the first day, and until now the runtime refused what was not granted
//! while the kernel allowed it anyway. A world that did not declare
//! `network` could still open a socket; a world that did not declare
//! `process` could still fork. The declaration was a promise kept by
//! good manners.
//!
//! Here the kernel keeps it instead:
//!
//! | the declaration omits | the kernel makes it so |
//! |---|---|
//! | `network` | the world runs in its OWN empty network namespace -- no interface, no route, no loopback. Not "refused permission": there is nothing there |
//! | `process` | `fork`, `vfork` and `clone` WITHOUT `CLONE_THREAD` return EPERM |
//!
//! ## Why the vocabulary already fit
//!
//! stzlib's nine capabilities separate `process` from `threads`, and the
//! kernel separates them at exactly the same seam: one `clone` call makes
//! either a process or a thread depending on one bit of its first
//! argument. The filter tests that bit, which is what makes the refusal
//! of process creation precise rather than a blanket ban on `clone` that
//! would break every runtime that threads. A vocabulary written for a
//! virtual twin turned out to name the real distinction the kernel makes,
//! which is a fact about the vocabulary and not a coincidence arranged
//! here.
//!
//! ## The one that is NOT enforced, and why
//!
//! `threads` is read, judged and left ungranted-but-allowed. A capability
//! says what the WORLD may do, and a thread the RUNTIME creates for its
//! own housekeeping is not the world asking for one: stzr is a process
//! this machine starts, not a program the declaration wrote. Refusing it
//! a thread because a Luau script never asked for threading would punish
//! the runtime for the world's declaration. The machinery to refuse it is
//! here and tested; what is missing is a seat that decides whose thread
//! it is.
//!
//! ## What this is and is not
//!
//! It is the kernel's own refusal, before the world starts: the filter is
//! installed between the fork and the exec, with `NO_NEW_PRIVS` set, so
//! it survives `execve` and the world cannot lift it.
//!
//! It is NOT a sandbox. A world still sees the machine's filesystem and
//! its process table; a MOUNT namespace and a PID namespace are named
//! seams and are not built. Say what is true: a world that did not
//! declare the network HAS no network, and a world that did not declare
//! process creation CANNOT create one. Nothing here says anything about
//! what it can read.
//!
//! The denial is EPERM rather than a kill, deliberately. A world refused
//! by the kernel reports it in its own words and the transcript carries
//! the refusal, which is the same shape as every other refusal in this
//! machine -- a line, not a silence.

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");

const linux = std.os.linux;

/// What the kernel will hold this world to, derived from its NEEDS.
pub const Confinement = struct {
    /// may the world speak on the network at all
    network: bool,
    /// may it have any business with processes at all: create one
    /// (NS-1) and, since PID-1, SEE or signal one. stzlib's capability
    /// is "spawn and manage", and managing is inspecting and signalling
    /// as much as starting -- so a world that never asked for it is
    /// alone in a process table of its own, where the pids of the other
    /// worlds do not exist and cannot be named, let alone signalled.
    process: bool,
    /// may it create a thread
    threads: bool,
    /// the machine's declared MOUNTs this world may not see (MNT-1).
    /// Empty when the world declared `filesystem`, or when the machine
    /// mounts nothing of its own. The world keeps the image it was built
    /// from -- its binary is a file, and a world with no files is not a
    /// world -- and loses the machine's STORAGE, which is where anything
    /// worth keeping from it lives: the device key, the signed record,
    /// the business data.
    hidden: []const []const u8 = &.{},

    /// Read off the machine and the service together. The machine
    /// matters for one reason: a machine that declares NO network has
    /// none to keep a world out of, so there is nothing to refuse and
    /// nothing to say. Claiming a world "has no network of its own" on a
    /// box that has no network at all would be a true sentence about
    /// nothing -- and the kernel agrees, because CONFIG_NET_NS depends
    /// on CONFIG_NET and cannot even be built there (NS-1, found when
    /// unshare answered EINVAL on a machine with no wire).
    pub fn of(m: machine.Machine, svc: machine.Service) Confinement {
        return ofAlloc(m, svc, null) catch unreachable;
    }

    /// The same, with somewhere to build a NARROWED list. `SEE-1` lets a
    /// world keep only the mounts it names, and the paths it may not see
    /// are then "the machine's mounts minus those" -- a set that has to
    /// be built. With no allocator the narrowing is skipped and the
    /// world keeps what `filesystem` alone would give it, which is what
    /// the derivation in expect.zig needs when it is only counting.
    pub fn ofAlloc(m: machine.Machine, svc: machine.Service, gpa: ?std.mem.Allocator) !Confinement {
        var c = ofService(svc);
        if (m.networks.len == 0) c.network = true;
        var granted_fs = false;
        for (svc.needs) |n| {
            if (n == .filesystem) granted_fs = true;
        }
        if (!granted_fs) {
            // no grant at all: the machine's storage is not in its tree
            c.hidden = m.mountPaths();
            return c;
        }
        const kept = svc.sees orelse return c; // the grant, unnarrowed
        const a = gpa orelse return c;
        var hide: std.ArrayList([]const u8) = .{};
        for (m.mounts) |mt| {
            var named = false;
            for (kept) |name| {
                if (std.mem.eql(u8, mt.name, name)) named = true;
            }
            if (!named) try hide.append(a, mt.at);
        }
        c.hidden = try hide.toOwnedSlice(a);
        return c;
    }

    fn ofService(svc: machine.Service) Confinement {
        // THREADS ARE NOT ENFORCED HERE, on purpose, and the reason is a
        // distinction worth keeping: a capability says what the WORLD may
        // do, and a thread the RUNTIME creates for its own housekeeping is
        // not the world asking for one. stzr is a process this machine
        // starts, not a program the declaration wrote; refusing it a
        // thread because a Luau script did not ask for threading would be
        // punishing the runtime for the world's declaration.
        //
        // The filter below can refuse threads and is judged doing it,
        // because that is the same mechanism that makes the refusal of
        // PROCESS creation precise -- one clone call makes either, and
        // one bit says which. What is missing is not the machinery but a
        // seat that decides whose thread it is. Named, not hidden.
        var c = Confinement{ .network = false, .process = false, .threads = true };
        for (svc.needs) |n| switch (n) {
            .network => c.network = true,
            .process => c.process = true,
            else => {},
        };
        return c;
    }

    /// does anything need saying about this world at all
    pub fn confined(self: Confinement) bool {
        return !self.network or !self.process or !self.threads or self.hidden.len > 0;
    }

    /// what to call it in one word, for the line the boot prints
    pub fn words(self: Confinement, buf: []u8) []const u8 {
        var n: usize = 0;
        _ = &n;
        if (!self.network) {
            const s = "no network of its own";
            @memcpy(buf[n..][0..s.len], s);
            n += s.len;
        }
        if (!self.process) {
            if (n > 0) {
                @memcpy(buf[n..][0..5], " and ");
                n += 5;
            }
            const s = "no sight of the other worlds and no way to start one";
            @memcpy(buf[n..][0..s.len], s);
            n += s.len;
        }
        if (!self.threads) {
            if (n > 0) {
                @memcpy(buf[n..][0..5], " and ");
                n += 5;
            }
            const s = "no way to start a thread";
            @memcpy(buf[n..][0..s.len], s);
            n += s.len;
        }
        if (self.hidden.len > 0) {
            if (n > 0) {
                @memcpy(buf[n..][0..5], " and ");
                n += 5;
            }
            const s = "no sight of ";
            @memcpy(buf[n..][0..s.len], s);
            n += s.len;
            for (self.hidden, 0..) |p, i| {
                if (i > 0) {
                    @memcpy(buf[n..][0..2], ", ");
                    n += 2;
                }
                @memcpy(buf[n..][0..p.len], p);
                n += p.len;
            }
        }
        return buf[0..n];
    }
};

// ---- classic BPF, which is what a seccomp filter is ---------------------

pub const sock_filter = extern struct {
    code: u16,
    jt: u8,
    jf: u8,
    k: u32,
};

const sock_fprog = extern struct {
    len: u16,
    filter: [*]const sock_filter,
};

const LD_W_ABS: u16 = 0x20; // BPF_LD | BPF_W | BPF_ABS
const JMP_JEQ_K: u16 = 0x15; // BPF_JMP | BPF_JEQ | BPF_K
const JMP_JSET_K: u16 = 0x45; // BPF_JMP | BPF_JSET | BPF_K
const RET_K: u16 = 0x06; // BPF_RET | BPF_K

// offsets into `struct seccomp_data`: nr, arch, instruction_pointer, args[6]
const OFF_NR: u32 = 0;
const OFF_ARCH: u32 = 4;
const OFF_ARG0: u32 = 16; // low word first: this floor is little-endian on both targets

const CLONE_THREAD: u32 = 0x00010000;

/// The architecture the filter was built for. A filter is compiled for ONE
/// syscall table and MUST refuse to run against another, or the numbers it
/// tests mean something else entirely -- the classic way a seccomp filter
/// becomes a hole rather than a wall.
const audit_arch: u32 = switch (builtin.cpu.arch) {
    .x86_64 => 0xC000003E,
    .aarch64 => 0xC00000B7,
    else => 0,
};

/// The calls that would let a WORLD change the MACHINE it was declared
/// to run on (SYS-1).
///
/// This list is the only thing in the envelope that is NOT derived from
/// `NEEDS`, and that is the point. The other three seats ask what this
/// world declared; this one asks what a world IS on this floor. The
/// machine's own law says there is no shell, no package manager and no
/// service manager, and that the declared machine IS the system. A world
/// computes and talks to what it declared. It does not remount the
/// filesystem, set the clock, load a module, rename the host, build
/// itself a new envelope, read another process's memory, or reboot the
/// box. No clause grants these because no declaration should ask.
///
/// Every one is refused with EPERM for every world, on every machine.
/// A call absent on an architecture is simply skipped -- `nrOf` returns
/// null and no instruction is emitted, so the filter never tests a
/// number that means something else here.
const off_limits = [_][]const u8{
    // the filesystem tree is the declaration's, not a world's
    "mount",       "umount2",        "pivot_root",
    // the kernel is the image's
    "init_module", "finit_module",   "delete_module",
    "kexec_load",  "kexec_file_load",
    // the machine's life is PID 1's
    "reboot",
    // the clock is the machine's, and a world that may READ it still may
    // not move it under every other world
    "settimeofday", "clock_settime", "adjtimex", "clock_adjtime",
    // who the machine says it is
    "sethostname", "setdomainname",
    // the envelope is built BEFORE the world and is not the world's to
    // widen, narrow or leave
    "unshare",     "setns",
    // another process's memory
    "ptrace",
    // the machine's own plumbing
    "swapon",      "swapoff",        "bpf",   "syslog", "acct",
    "mknod",       "mknodat",
};

fn nrOf(comptime name: []const u8) ?u32 {
    if (!@hasField(linux.SYS, name)) return null;
    return @intCast(@intFromEnum(@field(linux.SYS, name)));
}

/// Build the filter for one confinement. Returns the program, or an empty
/// slice when the world may do everything this filter knows how to refuse.
///
/// The shape: guard the architecture, then test the syscall number, then
/// -- for `clone` alone -- test the one bit that decides whether the call
/// makes a process or a thread. Every jump target is one of three returns
/// at the end, so the offsets are computed rather than counted by hand.
pub fn filter(c: Confinement, buf: []sock_filter) []sock_filter {
    if (audit_arch == 0) return buf[0..0];

    var n: usize = 0;
    var arch_jmp: usize = 0;
    var deny_jmps: [off_limits.len + 4]usize = undefined;
    var ndeny: usize = 0;
    var clone_jmp: ?usize = null;
    var thread_jmp: ?usize = null;

    // the architecture this filter was built for, and nothing else
    buf[n] = .{ .code = LD_W_ABS, .jt = 0, .jf = 0, .k = OFF_ARCH };
    n += 1;
    arch_jmp = n;
    buf[n] = .{ .code = JMP_JEQ_K, .jt = 0, .jf = 0, .k = audit_arch };
    n += 1;

    buf[n] = .{ .code = LD_W_ABS, .jt = 0, .jf = 0, .k = OFF_NR };
    n += 1;

    // what no world may do on this floor, whatever it declared (SYS-1)
    inline for (off_limits) |name| {
        if (nrOf(name)) |nr| {
            deny_jmps[ndeny] = n;
            ndeny += 1;
            buf[n] = .{ .code = JMP_JEQ_K, .jt = 0, .jf = 0, .k = nr };
            n += 1;
        }
    }

    // the calls that make a PROCESS and cannot make anything else
    if (!c.process) {
        inline for (.{ "fork", "vfork", "clone3" }) |name| {
            if (nrOf(name)) |nr| {
                deny_jmps[ndeny] = n;
                ndeny += 1;
                buf[n] = .{ .code = JMP_JEQ_K, .jt = 0, .jf = 0, .k = nr };
                n += 1;
            }
        }
    }

    // clone makes either, and one bit of its first argument says which
    if (nrOf("clone")) |nr| {
        if (!c.process and !c.threads) {
            deny_jmps[ndeny] = n;
            ndeny += 1;
            buf[n] = .{ .code = JMP_JEQ_K, .jt = 0, .jf = 0, .k = nr };
            n += 1;
        } else if (!c.process) {
            clone_jmp = n;
            buf[n] = .{ .code = JMP_JEQ_K, .jt = 0, .jf = 0, .k = nr };
            n += 1;
            buf[n] = .{ .code = LD_W_ABS, .jt = 0, .jf = 0, .k = OFF_ARG0 };
            n += 1;
            thread_jmp = n;
            buf[n] = .{ .code = JMP_JSET_K, .jt = 0, .jf = 0, .k = CLONE_THREAD };
            n += 1;
        } else if (!c.threads) {
            clone_jmp = n;
            buf[n] = .{ .code = JMP_JEQ_K, .jt = 0, .jf = 0, .k = nr };
            n += 1;
            buf[n] = .{ .code = LD_W_ABS, .jt = 0, .jf = 0, .k = OFF_ARG0 };
            n += 1;
            // a thread is the denied one here: jump to DENY when the bit is set
            thread_jmp = n;
            buf[n] = .{ .code = JMP_JSET_K, .jt = 0, .jf = 0, .k = CLONE_THREAD };
            n += 1;
        }
    }

    const allow = n;
    const deny = n + 1;
    const kill = n + 2;
    buf[allow] = .{ .code = RET_K, .jt = 0, .jf = 0, .k = linux.SECCOMP.RET.ALLOW };
    buf[deny] = .{ .code = RET_K, .jt = 0, .jf = 0, .k = linux.SECCOMP.RET.ERRNO | @as(u32, @intFromEnum(linux.E.PERM)) };
    buf[kill] = .{ .code = RET_K, .jt = 0, .jf = 0, .k = linux.SECCOMP.RET.KILL_PROCESS };

    // a jump's offset counts from the instruction AFTER it
    buf[arch_jmp].jt = 0;
    buf[arch_jmp].jf = @intCast(kill - arch_jmp - 1);
    for (deny_jmps[0..ndeny]) |i| {
        buf[i].jt = @intCast(deny - i - 1);
        buf[i].jf = 0;
    }
    if (clone_jmp) |i| {
        // not clone: fall through to whatever comes next, which for the
        // last test is ALLOW
        buf[i].jt = 0;
        buf[i].jf = @intCast(allow - i - 1);
    }
    if (thread_jmp) |i| {
        if (!c.process) {
            // the bit is set: a thread, and threads are granted
            buf[i].jt = @intCast(allow - i - 1);
            buf[i].jf = @intCast(deny - i - 1);
        } else {
            buf[i].jt = @intCast(deny - i - 1);
            buf[i].jf = @intCast(allow - i - 1);
        }
    }
    return buf[0 .. kill + 1];
}

pub const Applied = struct {
    network: bool = false, // an empty network namespace was entered
    mounts: bool = false, // the machine's storage was detached
    pids: bool = false, // the world is alone in a table of its own
    seccomp: bool = false, // a filter was installed
    trouble: ?[]const u8 = null,
};

/// Called in the CHILD, after the spawn gate and before the exec. Every
/// act here must happen before `execve`, and `NO_NEW_PRIVS` is what makes
/// the filter survive it.
///
/// Order matters: unshare first (it needs the privilege the child still
/// has), then the filter, then the caller drops to the declared USER and
/// execs. A filter installed before the unshare would have to allow the
/// unshare itself.
pub fn apply(c: Confinement) Applied {
    if (builtin.os.tag != .linux) return .{ .trouble = "not linux" };
    var done = Applied{};

    if (!c.network) {
        switch (linux.E.init(linux.unshare(linux.CLONE.NEWNET))) {
            .SUCCESS => done.network = true,
            // inside a user namespace without the privilege, or a kernel
            // built without namespaces: say so rather than pretending
            else => |e| done.trouble = @tagName(e),
        }
    }

    // A mount namespace is wanted for either of two reasons: to detach
    // the machine's storage (MNT-1), or to give this world a /proc that
    // shows its OWN process table and not the machine's (PID-1). Asking
    // twice would fail the second time, so the reasons are joined here.
    const wants_mountns = c.hidden.len > 0 or !c.process;
    if (wants_mountns) mounts: {
        switch (linux.E.init(linux.unshare(linux.CLONE.NEWNS))) {
            .SUCCESS => {},
            else => |e| {
                if (done.trouble == null) done.trouble = @tagName(e);
                break :mounts;
            },
        }
        // FIRST, and this is the whole safety of the act: make the tree
        // private, or the umounts below PROPAGATE BACK to the machine and
        // this world takes /data away from every other world and from PID
        // 1 itself. A mount namespace that shares propagation is not an
        // isolation, it is a way to break the box from inside a world.
        switch (linux.E.init(linux.mount("none", "/", null, linux.MS.REC | linux.MS.PRIVATE, 0))) {
            .SUCCESS => {},
            else => |e| {
                if (done.trouble == null) done.trouble = @tagName(e);
                break :mounts;
            },
        }
        for (c.hidden) |path| {
            var buf: [256]u8 = undefined;
            if (path.len + 1 > buf.len) continue;
            @memcpy(buf[0..path.len], path);
            buf[path.len] = 0;
            const z: [*:0]const u8 = @ptrCast(&buf);
            // MNT_DETACH (2): take it out of THIS tree now, and let the
            // kernel release it when nothing holds it any more
            switch (linux.E.init(linux.umount2(z, 2))) {
                .SUCCESS, .INVAL, .NOENT => {},
                else => |e| if (done.trouble == null) {
                    done.trouble = @tagName(e);
                },
            }
        }
        done.mounts = done.trouble == null and c.hidden.len > 0;
    }

    if (!c.process) pids: {
        // unshare(CLONE_NEWPID) does NOT move the caller -- it makes the
        // caller's future CHILDREN the inhabitants of a new table. So the
        // world cannot simply exec here: this process forks once more,
        // the grandchild is pid 1 of the new namespace and becomes the
        // world, and THIS process stays behind only to carry the
        // grandchild's fate back to the machine's PID 1 unchanged.
        switch (linux.E.init(linux.unshare(linux.CLONE.NEWPID))) {
            .SUCCESS => {},
            else => |e| {
                if (done.trouble == null) done.trouble = @tagName(e);
                break :pids;
            },
        }
        const pid = std.posix.fork() catch |e| {
            if (done.trouble == null) done.trouble = @errorName(e);
            break :pids;
        };
        if (pid != 0) {
            // the stand-in. It waits, and then it dies the way the world
            // died: an exit code exits, a signal is re-raised on itself,
            // so `boot: kds (pid N) exited 0` and the killed-by-the-kernel
            // line of the BUDGET seat both stay true through the extra
            // process nobody declared.
            var status: u32 = 0;
            while (true) {
                const rc = linux.wait4(pid, &status, 0, null);
                switch (linux.E.init(rc)) {
                    .SUCCESS => break,
                    .INTR => continue,
                    else => linux.exit(127),
                }
            }
            if (status & 0x7f != 0) {
                const sig: u32 = status & 0x7f;
                _ = linux.kill(linux.getpid(), @intCast(sig));
                linux.exit(128 + @as(u8, @intCast(sig)));
            }
            linux.exit(@intCast((status >> 8) & 0xff));
        }
        // the grandchild: pid 1 of its own table, and a /proc that says
        // so. Without the remount it would read the machine's table
        // through the mount it inherited and see every other world.
        switch (linux.E.init(linux.mount("proc", "/proc", "proc", 0, 0))) {
            .SUCCESS => done.pids = true,
            else => |e| if (done.trouble == null) {
                done.trouble = @tagName(e);
            },
        }
    }

    {
        var buf: [64]sock_filter = undefined;
        const prog = filter(c, &buf);
        if (prog.len > 0) {
            // without this, a filter may not be installed by an
            // unprivileged process and may be lifted by a setuid exec
            _ = linux.prctl(@intFromEnum(linux.PR.SET_NO_NEW_PRIVS), 1, 0, 0, 0);
            const fprog = sock_fprog{ .len = @intCast(prog.len), .filter = prog.ptr };
            switch (linux.E.init(linux.seccomp(linux.SECCOMP.SET_MODE_FILTER, 0, &fprog))) {
                .SUCCESS => done.seccomp = true,
                else => |e| if (done.trouble == null) {
                    done.trouble = @tagName(e);
                },
            }
        }
    }
    return done;
}

// ---- judged beside the code -------------------------------------------

const testing = std.testing;

fn svcWith(needs: []const machine.Capability) machine.Service {
    return .{
        .name = "w",
        .line = 0,
        .run = &.{},
        .restart = .never,
        .after = &.{},
        .needs = needs,
        .ready = null,
        .health = null,
        .memory_mb = null,
        .cpu_percent = null,
        .user = null,
        .sees = null,
        .rationale = "",
    };
}

/// a machine that HAS a wire, so a world can be kept off it
fn wired() machine.Machine {
    var m = std.mem.zeroInit(machine.Machine, .{});
    m.networks = &.{.{
        .name = "lan",
        .line = 0,
        .interface = "eth0",
        .address = .dhcp,
        .gateway = null,
        .dns = &.{},
        .egress = .unrestricted,
        .domain = null,
        .rationale = "",
    }};
    return m;
}

fn bare() machine.Machine {
    return std.mem.zeroInit(machine.Machine, .{ .networks = &[_]machine.Network{} });
}

test "the confinement is read off NEEDS, and threads are deliberately not read" {
    const m = wired();
    const all = Confinement.of(m, svcWith(&.{ .network, .process }));
    try testing.expect(all.network and all.process);
    try testing.expect(!all.confined());

    const none = Confinement.of(m, svcWith(&.{.filesystem}));
    try testing.expect(!none.network and !none.process);
    // a world that declared `threads` and one that did not are treated
    // alike: whose thread it is has not been decided (NS-1)
    try testing.expect(none.threads);
    try testing.expect(Confinement.of(m, svcWith(&.{.threads})).threads);
    try testing.expect(none.confined());

    var buf: [128]u8 = undefined;
    try testing.expectEqualStrings("no network of its own and no sight of the other worlds and no way to start one", none.words(&buf));
}

test "a machine with no wire keeps no world off one" {
    // the claim would be true and empty, and the kernel cannot even build
    // NET_NS without NET -- the EINVAL that found this (NS-1)
    const c = Confinement.of(bare(), svcWith(&.{ .process, .filesystem }));
    try testing.expect(c.network);
    try testing.expect(!c.confined());
    // and the same service on a machine that HAS one is kept off it
    try testing.expect(!Confinement.of(wired(), svcWith(&.{ .process, .filesystem })).network);
}

test "a world that declared everything is still held to the floor" {
    if (audit_arch == 0) return error.SkipZigTest;
    var buf: [64]sock_filter = undefined;
    const prog = filter(.{ .network = true, .process = true, .threads = true }, &buf);
    // it declared all three, so nothing is refused ON ITS ACCOUNT -- and
    // it is still refused the calls that would let it change the machine
    // it runs on, because that was never a world's to do (SYS-1)
    try testing.expect(prog.len > off_limits.len);
    var found_reboot = false;
    var found_mount = false;
    const reboot_nr = nrOf("reboot").?;
    const mount_nr = nrOf("mount").?;
    for (prog, 0..) |ins, i| {
        if (ins.code != JMP_JEQ_K) continue;
        if (ins.k == reboot_nr) {
            found_reboot = true;
            try testing.expect(prog[i + 1 + ins.jt].k & linux.SECCOMP.RET.ACTION == linux.SECCOMP.RET.ERRNO);
        }
        if (ins.k == mount_nr) found_mount = true;
    }
    try testing.expect(found_reboot and found_mount);
}

test "the floor's own refusals are on every filter, whatever the world declared" {
    if (audit_arch == 0) return error.SkipZigTest;
    const cases = [_]Confinement{
        .{ .network = true, .process = true, .threads = true },
        .{ .network = false, .process = false, .threads = true },
        .{ .network = true, .process = true, .threads = false },
    };
    for (cases) |c| {
        var buf: [64]sock_filter = undefined;
        const prog = filter(c, &buf);
        inline for (off_limits) |name| {
            if (nrOf(name)) |nr| {
                var seen = false;
                for (prog) |ins| {
                    if (ins.code == JMP_JEQ_K and ins.k == nr) seen = true;
                }
                if (!seen) return error.FloorNotHeld;
            }
        }
    }
}

test "every jump lands inside the program, and on a return" {
    if (audit_arch == 0) return error.SkipZigTest;
    const cases = [_]Confinement{
        .{ .network = true, .process = false, .threads = true },
        .{ .network = true, .process = false, .threads = false },
        .{ .network = true, .process = true, .threads = false },
    };
    for (cases) |c| {
        var buf: [64]sock_filter = undefined;
        const prog = filter(c, &buf);
        try testing.expect(prog.len >= 4);
        // the last three instructions are the three verdicts
        const allow = prog.len - 3;
        try testing.expectEqual(linux.SECCOMP.RET.ALLOW, prog[allow].k);
        try testing.expectEqual(linux.SECCOMP.RET.KILL_PROCESS, prog[prog.len - 1].k);
        try testing.expect(prog[allow + 1].k & linux.SECCOMP.RET.ACTION == linux.SECCOMP.RET.ERRNO);

        for (prog, 0..) |ins, i| {
            if (ins.code == RET_K or ins.code == LD_W_ABS) continue;
            for ([_]u8{ ins.jt, ins.jf }) |off| {
                const target = i + 1 + @as(usize, off);
                try testing.expect(target < prog.len);
                // a jump must land on one of the three verdicts, or on the
                // instruction that follows it (offset 0)
                try testing.expect(off == 0 or prog[target].code == RET_K);
            }
        }
        // the architecture guard is first and refuses anything else
        try testing.expectEqual(OFF_ARCH, prog[0].k);
        try testing.expectEqual(audit_arch, prog[1].k);
        try testing.expectEqual(prog.len - 1, 1 + 1 + @as(usize, prog[1].jf));
    }
}

test "the clone bit decides, and it decides the right way round" {
    if (audit_arch == 0) return error.SkipZigTest;
    var buf: [64]sock_filter = undefined;

    // no process, threads granted: the bit SET means a thread, allowed
    const p = filter(.{ .network = true, .process = false, .threads = true }, &buf);
    var found = false;
    for (p, 0..) |ins, i| if (ins.code == JMP_JSET_K and ins.k == CLONE_THREAD) {
        found = true;
        try testing.expectEqual(linux.SECCOMP.RET.ALLOW, p[i + 1 + ins.jt].k);
        try testing.expect(p[i + 1 + ins.jf].k & linux.SECCOMP.RET.ACTION == linux.SECCOMP.RET.ERRNO);
    };
    try testing.expect(found);

    // process granted, no threads: the bit SET means a thread, refused
    var buf2: [64]sock_filter = undefined;
    const t = filter(.{ .network = true, .process = true, .threads = false }, &buf2);
    found = false;
    for (t, 0..) |ins, i| if (ins.code == JMP_JSET_K and ins.k == CLONE_THREAD) {
        found = true;
        try testing.expect(t[i + 1 + ins.jt].k & linux.SECCOMP.RET.ACTION == linux.SECCOMP.RET.ERRNO);
        try testing.expectEqual(linux.SECCOMP.RET.ALLOW, t[i + 1 + ins.jf].k);
    };
    try testing.expect(found);
}
