// image.zig -- the hosted image, DERIVED from a judged plan. This module
// writes declarative artifacts into an output directory and touches no
// toolchain:
//
//   image.env        what the build must be told: the kernel ARCH, the
//                    cross prefix, the artifacts, the board (written from
//                    the declaration alone, before any staging check)
//   initramfs.list   the kernel's own gen_init_cpio description of the
//                    root filesystem: the mount points, the device nodes
//                    PID 1 needs, /etc/machine (the declaration itself),
//                    /harb, and every program and file the services name
//                    -- each taken from a STAGING ROOT and refused if absent
//   kernel.fragment  the kconfig options the profile, the board and the
//                    declared mounts require, merged over tinyconfig
//   disk.list        the virtio disks the declared mounts need (emulator
//                    boards; one per image today)
//   sd.list          for a board that boots from an SD card: the card's
//                    partitions and the boot partition's files, with the
//                    firmware's config.txt and cmdline.txt written beside
//   boot.cmd         the QEMU line that boots the image (the same board,
//                    emulated) with this binary as PID 1 and the serial
//                    console as the transcript
//
// The imperative act -- building the vendored kernel, packing the cpio,
// making the disks and the card, running QEMU -- is experiment/os2_image.sh
// on a Linux host. The derivation is here so it is portable, judged, and
// printed before it is run: the image is text before it is an act.

const std = @import("std");
const machine = @import("machine.zig");
const confine = @import("confine.zig");
const plan = @import("plan.zig");
const expect = @import("expect.zig");

pub const Options = struct {
    out_dir: []const u8,
    root: []const u8,
    machine_path: []const u8,
    disk_mb: u32 = 64,
};

const Entry = struct { path: []const u8, source: []const u8 };

/// What each board needs, in one place.
const Target = struct {
    kernel_arch: []const u8, // make ARCH=
    cross: []const u8, // make CROSS_COMPILE=
    artifact: []const u8, // path of the kernel image inside the tree
    image_name: []const u8, // its name in the output dir
    dtb: ?[]const u8 = null, // device tree inside the tree, for a real board
    qemu: []const u8,
    machine_args: []const u8,
    memory_mb: u32, // 0: the board's own, fixed
    console_qemu: []const u8,
    console_board: []const u8,
    serial_cfg: []const []const u8,
    platform_cfg: []const []const u8 = &.{},
    block_cfg: []const []const u8, // for a declared block mount
    blk_device: ?[]const u8, // the QEMU virtio-blk device, or null when the board boots from a card
    net_cfg: []const []const u8 = &.{}, // for a declared NETWORK (the emulator's NIC; a board has its own in platform_cfg)
    net_device: ?[]const u8 = null, // the QEMU virtio-net device, or null when the board has its own NIC
    sd: bool = false,
    /// what the BOARD's tree needs that mainline's does not say (applied
    /// to the card's DTB; experiment/dtb_ops.py). Ops:
    /// disable:<node>  okay:<node>  drop:<node>:<property>  alias:<name>:<path>
    dtb_ops: []const []const u8 = &.{},
    /// what the EMULATOR's tree needs on top: the blocks it does not
    /// model (disabled), the host it plugs the card into (opened, and
    /// aliased so the declared device name holds in both worlds)
    qemu_dtb_ops: []const []const u8 = &.{},
    /// the boot EXPECTED through the emulator's eyes, when the emulator
    /// lacks what the board has: each lack a field, each field a line of
    /// /etc/expected.emulator that differs from /etc/expected (JDG-1).
    /// Null for a board that IS an emulator: one expectation, one lens.
    qemu_lens: ?expect.Lens = null,
};

fn target(board: machine.Board) ?Target {
    return switch (board) {
        // the edge boards have no image here: their substrate is
        // MicroRing's and `harb project` hands them over (PRJ-1)
        .sim, .pico2, .pico2w, .esp32c6 => null,
        .qemu_pc => .{
            .kernel_arch = "x86_64",
            .cross = "",
            .artifact = "arch/x86/boot/bzImage",
            .image_name = "bzImage",
            .qemu = "qemu-system-x86_64",
            .machine_args = "-M pc -cpu max",
            .memory_mb = 256,
            .console_qemu = "ttyS0",
            .console_board = "ttyS0",
            .serial_cfg = &.{ "CONFIG_SERIAL_8250=y", "CONFIG_SERIAL_8250_CONSOLE=y", "CONFIG_KERNEL_GZIP=y" },
            .block_cfg = &.{ "CONFIG_PCI=y", "CONFIG_VIRTIO_PCI=y" },
            .blk_device = "virtio-blk-pci",
            .net_cfg = &.{ "CONFIG_PCI=y", "CONFIG_VIRTIO_PCI=y" },
            .net_device = "virtio-net-pci",
        },
        .qemu_virt => .{
            .kernel_arch = "arm64",
            .cross = "aarch64-linux-gnu-",
            .artifact = "arch/arm64/boot/Image",
            .image_name = "Image",
            .qemu = "qemu-system-aarch64",
            .machine_args = "-M virt -cpu cortex-a53",
            .memory_mb = 512,
            .console_qemu = "ttyAMA0",
            .console_board = "ttyAMA0",
            .serial_cfg = &.{ "CONFIG_SERIAL_AMBA_PL011=y", "CONFIG_SERIAL_AMBA_PL011_CONSOLE=y" },
            .block_cfg = &.{"CONFIG_VIRTIO_MMIO=y"},
            .blk_device = "virtio-blk-device",
            .net_cfg = &.{"CONFIG_VIRTIO_MMIO=y"},
            .net_device = "virtio-net-device",
        },
        .rpi4 => .{
            .kernel_arch = "arm64",
            .cross = "aarch64-linux-gnu-",
            .artifact = "arch/arm64/boot/Image",
            .image_name = "Image",
            .dtb = "arch/arm64/boot/dts/broadcom/bcm2711-rpi-4-b.dtb",
            .qemu = "qemu-system-aarch64",
            .machine_args = "-M raspi4b -dtb bcm2711-rpi-4-b.qemu.dtb",
            // QEMU 10.2's raspi4b does not model the AON L2 interrupt
            // controller at 0x7ef00100; brcmstb_l2_intc_of_init takes a
            // synchronous external abort there (OS-4 finding). It disables
            // pcie, rng, thermal and genet itself; this one it misses.
            // The whole AON block at 0x7ef00000 is absent from the emulator:
            // after the L2 intc, clk_disable_unused took the same abort in
            // clk_gate_readl on the DVP clock (clock@7ef00000). Two nodes,
            // each found by its own fault, each named here. And the card:
            // QEMU plugs it into the legacy SDHCI at 0x7e300000 (mainline
            // gives that host to the Wi-Fi SDIO, with a power sequence and
            // non-removable), not into emmc2 where the board's card sits --
            // so the emulator's DTB opens that host as a plain removable one
            // and aliases mmc0 to it, so /dev/mmcblk0p2 names the same
            // partition in both worlds.
            // Mainline's rpi-4-b tree carries NO mmc aliases, so the card's
            // index is probe order: with two hosts (emmc2 for the card, the
            // legacy SDHCI for the Wi-Fi SDIO) /dev/mmcblk0 is a race. The
            // board's tree pins mmc0 to emmc2 -- the declared device name
            // is a fact, not a hope.
            .dtb_ops = &.{ "alias:mmc0:/emmc2bus/mmc@7e340000", "alias:mmc1:/soc/mmc@7e300000" },
            .qemu_dtb_ops = &.{
                "disable:interrupt-controller@7ef00100", "disable:clock@7ef00000",
                "okay:mmc@7e300000",                     "drop:mmc@7e300000:mmc-pwrseq",
                "drop:mmc@7e300000:non-removable",       "drop:mmc@7e300000:vmmc-supply",
                "alias:mmc0:/soc/mmc@7e300000",          "alias:mmc1:/emmc2bus/mmc@7e340000",
            },
            .memory_mb = 0,
            // raspi4b models no GENET, so a declared NETWORK is NODEV there;
            // and it resets the board the moment the watchdog is armed, so
            // the emulator's boot line turns it off. Two lacks, two lines.
            .qemu_lens = .{ .watchdog = .off, .network_absent = true },
            // the emulator's PL011 sits on the header pins; the board's
            // PL011 goes to Bluetooth and its mini-UART (ttyS1) to the pins
            .console_qemu = "ttyAMA0",
            .console_board = "ttyS1,115200",
            // the mini-UART driver sits behind SERIAL_8250_EXTENDED and
            // SHARE_IRQ; without them olddefconfig drops it (first rpi4 build)
            .serial_cfg = &.{ "CONFIG_SERIAL_8250=y", "CONFIG_SERIAL_8250_CONSOLE=y", "CONFIG_SERIAL_8250_EXTENDED=y", "CONFIG_SERIAL_8250_SHARE_IRQ=y", "CONFIG_SERIAL_8250_BCM2835AUX=y", "CONFIG_SERIAL_AMBA_PL011=y", "CONFIG_SERIAL_AMBA_PL011_CONSOLE=y" },
            .platform_cfg = &.{
                "CONFIG_ARCH_BCM=y",            "CONFIG_ARCH_BCM2835=y",        "CONFIG_RASPBERRYPI_FIRMWARE=y",
                "CONFIG_MAILBOX=y",             "CONFIG_BCM2835_MBOX=y",        "CONFIG_WATCHDOG=y",
                "CONFIG_BCM2835_WDT=y",         "CONFIG_BLOCK=y",               "CONFIG_BLK_DEV=y",
                "CONFIG_MMC=y",                 "CONFIG_MMC_BLOCK=y",           "CONFIG_MMC_SDHCI=y",
                "CONFIG_MMC_SDHCI_PLTFM=y",     "CONFIG_MMC_SDHCI_IPROC=y",     "CONFIG_MMC_BCM2835=y",
                "CONFIG_NET=y",                 "CONFIG_INET=y",                "CONFIG_NETDEVICES=y",
                "CONFIG_ETHERNET=y",            "CONFIG_NET_VENDOR_BROADCOM=y", "CONFIG_BCMGENET=y",
                "CONFIG_PHYLIB=y",              "CONFIG_BROADCOM_PHY=y",
            },
            .block_cfg = &.{},
            .blk_device = null,
            .sd = true,
        },
    };
}

fn addDir(arena: std.mem.Allocator, dirs: *std.ArrayList([]const u8), path: []const u8) !void {
    // every ancestor, once
    var i: usize = 1;
    while (i <= path.len) : (i += 1) {
        if (i == path.len or path[i] == '/') {
            const p = path[0..i];
            if (p.len == 0) continue;
            var seen = false;
            for (dirs.items) |d| if (std.mem.eql(u8, d, p)) {
                seen = true;
            };
            if (!seen) try dirs.append(arena, try arena.dupe(u8, p));
        }
    }
}

fn staged(arena: std.mem.Allocator, root: []const u8, path: []const u8) !?[]const u8 {
    const full = try std.fs.path.join(arena, &.{ root, path });
    std.fs.cwd().access(full, .{}) catch return null;
    return full;
}

pub fn write(arena: std.mem.Allocator, p: plan.Plan, opts: Options, out: *std.Io.Writer) !u8 {
    const m = p.machine;
    if (m.profile != .hosted) {
        try out.print("image: refused -- only the hosted profile has an image here; a machine of PROFILE {s} is projected by its own substrate (harb project)\n", .{@tagName(m.profile)});
        return 2;
    }
    if (m.arch != .x86_64 and m.arch != .aarch64) {
        try out.print("image: refused -- the {s} image is queued; x86_64 and aarch64 boot today\n", .{@tagName(m.arch)});
        return 2;
    }
    const t = target(m.board) orelse {
        try out.print("image: refused -- {s} is an edge board; an edge machine is projected onto MicroRing's substrate, not imaged here (harb project)\n", .{@tagName(m.board)});
        return 2;
    };

    // image.env first: it derives from the declaration alone, so the build
    // can learn the target before anything is staged
    try std.fs.cwd().makePath(opts.out_dir);
    {
        var env: std.ArrayList(u8) = .{};
        const w = env.writer(arena);
        try w.print("# image.env -- derived by harb image; sourced by experiment/os2_image.sh\n", .{});
        try w.print("ARCH={s}\nCROSS_COMPILE={s}\nKERNEL_ARTIFACT={s}\nKERNEL_IMAGE={s}\nTRIPLE={s}-linux-musl\nBOARD={s}\n", .{ t.kernel_arch, t.cross, t.artifact, t.image_name, @tagName(m.arch), @tagName(m.board) });
        if (t.dtb) |d| try w.print("DTB={s}\n", .{d});
        try w.print("SD={s}\n", .{if (t.sd) "yes" else "no"});
        if (t.dtb_ops.len > 0) {
            try w.print("DTB_OPS=\"", .{});
            for (t.dtb_ops, 0..) |n, i| try w.print("{s}{s}", .{ if (i > 0) " " else "", n });
            try w.print("\"\n", .{});
        }
        if (t.qemu_dtb_ops.len > 0) {
            try w.print("QEMU_DTB_OPS=\"", .{});
            for (t.qemu_dtb_ops, 0..) |n, i| try w.print("{s}{s}", .{ if (i > 0) " " else "", n });
            try w.print("\"\n", .{});
        }
        try writeOut(opts.out_dir, "image.env", env.items);
    }

    var dirs: std.ArrayList([]const u8) = .{};
    var files: std.ArrayList(Entry) = .{};
    for ([_][]const u8{ "/dev", "/proc", "/sys", "/etc", "/tmp" }) |d| try addDir(arena, &dirs, d);
    for (m.mounts) |mt| try addDir(arena, &dirs, mt.at);
    if (m.slots != null) try addDir(arena, &dirs, "/boot"); // where PID 1 mounts the boot partition to read and commit the slot
    // where a daemon creates its READY signal: the initramfs root is RAM
    // and writable, so the directory is all the image owes it
    for (m.services) |svc| if (svc.ready) |r| {
        if (std.fs.path.dirnamePosix(r)) |d| if (d.len > 1) try addDir(arena, &dirs, d);
    };

    // /harb: this binary, cross-built, staged at the root
    const harb_src = (try staged(arena, opts.root, "/harb")) orelse {
        try out.print("image: refused -- /harb is not staged under {s} (zig build cross, then copy the Linux binary there)\n", .{opts.root});
        return 2;
    };
    try files.append(arena, .{ .path = "/harb", .source = harb_src });

    // the services: the program must be staged; other absolute words are packed if staged
    for (m.services) |svc| {
        const prog = svc.run[0];
        if (prog.len == 0 or prog[0] != '/') {
            try out.print("image: refused -- service {s}: a program in an image is an absolute path, not '{s}'\n", .{ svc.name, prog });
            return 2;
        }
        const src = (try staged(arena, opts.root, prog)) orelse {
            try out.print("image: refused -- service {s}: program {s} is not staged under {s}\n", .{ svc.name, prog, opts.root });
            return 2;
        };
        try appendFile(arena, &files, &dirs, prog, src);
        for (svc.run[1..]) |w| {
            if (w.len > 1 and w[0] == '/') {
                if (try staged(arena, opts.root, w)) |s| try appendFile(arena, &files, &dirs, w, s);
            }
        }
    }

    // the declaration itself rides in the image
    try files.append(arena, .{ .path = "/etc/machine", .source = opts.machine_path });

    // a machine has no /etc/passwd until it declares identities; then it
    // has exactly the ones it declared, and root. Derived, never edited.
    if (m.users.len > 0) {
        var passwd: std.ArrayList(u8) = .{};
        var group: std.ArrayList(u8) = .{};
        const pw = passwd.writer(arena);
        const gw = group.writer(arena);
        try pw.print("root:x:0:0:root:/:/nonexistent\n", .{});
        try gw.print("root:x:0:\n", .{});
        for (m.users) |u| {
            try pw.print("{s}:x:{d}:{d}:{s}:/:/nonexistent\n", .{ u.name, u.uid, u.gid, u.name });
            try gw.print("{s}:x:{d}:\n", .{ u.name, u.gid });
        }
        // /nonexistent as the shell: there is none, and the file says so
        try writeOut(opts.out_dir, "passwd", passwd.items);
        try writeOut(opts.out_dir, "group", group.items);
        try files.append(arena, .{ .path = "/etc/passwd", .source = try std.fs.path.join(arena, &.{ opts.out_dir, "passwd" }) });
        try files.append(arena, .{ .path = "/etc/group", .source = try std.fs.path.join(arena, &.{ opts.out_dir, "group" }) });
    }

    // /etc/expected -- the boot, EXPECTED: the init lines a faithful boot
    // of this machine prints, derived from the plan, carried in the image
    // and judged by PID 1 itself once every service is ready; a trial is
    // committed only on a match (JDG-1). A board the court emulates gets a
    // second text through the emulator's lens -- what it lacks, named per
    // line -- selected by harb.expect=emulator on the emulator's boot line
    // and never on the card's. The diff of the two texts IS the list of
    // the emulator's lacks, and os2_image.sh prints it at build time.
    {
        const board = try expect.derive(arena, p, .{});
        try writeOut(opts.out_dir, "expected", board);
        try files.append(arena, .{ .path = "/etc/expected", .source = try std.fs.path.join(arena, &.{ opts.out_dir, "expected" }) });
        if (t.qemu_lens) |lens| {
            const emu = try expect.derive(arena, p, lens);
            try writeOut(opts.out_dir, "expected.emulator", emu);
            try files.append(arena, .{ .path = "/etc/expected.emulator", .source = try std.fs.path.join(arena, &.{ opts.out_dir, "expected.emulator" }) });
        }
    }

    // the block devices the declared mounts need -- one in this version
    var block: ?*const machine.Mount = null;
    for (m.mounts) |*mt| {
        if (mt.fs == .ext4 or mt.fs == .vfat) {
            if (block != null) {
                try out.print("image: refused -- two block mounts ({s} and {s}); one disk per image today\n", .{ block.?.name, mt.name });
                return 2;
            }
            block = mt;
        }
    }

    // initramfs.list -- gen_init_cpio format
    {
        var list: std.ArrayList(u8) = .{};
        const w = list.writer(arena);
        try w.print("# initramfs.list -- derived by harb image from {s}; gen_init_cpio format\n", .{opts.machine_path});
        try w.print("dir /dev 0755 0 0\n", .{});
        try w.print("nod /dev/console 0600 0 0 c 5 1\n", .{});
        try w.print("nod /dev/null 0666 0 0 c 1 3\n", .{});
        for (dirs.items) |d| {
            if (std.mem.eql(u8, d, "/dev")) continue;
            try w.print("dir {s} 0755 0 0\n", .{d});
        }
        for (files.items) |f| {
            const mode: []const u8 = if (std.mem.startsWith(u8, f.path, "/etc/")) "0644" else "0755";
            try w.print("file {s} {s} {s} 0 0\n", .{ f.path, f.source, mode });
        }
        try writeOut(opts.out_dir, "initramfs.list", list.items);
    }

    // kernel.fragment
    {
        var frag: std.ArrayList(u8) = .{};
        const w = frag.writer(arena);
        try w.print("# kernel.fragment -- derived by harb image from {s} for {s} ({s}); merged over tinyconfig\n", .{ opts.machine_path, t.kernel_arch, @tagName(m.board) });
        const base = [_][]const u8{
            "CONFIG_64BIT=y",       "CONFIG_PRINTK=y",    "CONFIG_TTY=y",        "CONFIG_BLK_DEV_INITRD=y",
            "CONFIG_BINFMT_ELF=y",  "CONFIG_PROC_FS=y",   "CONFIG_SYSFS=y",      "CONFIG_DEVTMPFS=y",
            "CONFIG_TMPFS=y",       "CONFIG_SHMEM=y",     "CONFIG_FUTEX=y",      "CONFIG_EPOLL=y",
            "CONFIG_EVENTFD=y",     "CONFIG_SIGNALFD=y",  "CONFIG_TIMERFD=y",    "CONFIG_MULTIUSER=y",
            "# CONFIG_MODULES is not set",
        };
        for (base) |l| try w.print("{s}\n", .{l});
        for (t.serial_cfg) |l| try w.print("{s}\n", .{l});
        for (t.platform_cfg) |l| try w.print("{s}\n", .{l});
        if (m.networks.len > 0) {
            // the wire: the IP stack, and the emulator's NIC when the board
            // has none of its own (a real board's NIC is in platform_cfg)
            try w.print("CONFIG_NET=y\nCONFIG_INET=y\nCONFIG_NETDEVICES=y\n", .{});
            if (t.net_device != null) {
                try w.print("CONFIG_VIRTIO_MENU=y\nCONFIG_VIRTIO=y\nCONFIG_VIRTIO_NET=y\n", .{});
                for (t.net_cfg) |l| try w.print("{s}\n", .{l});
            }
        }
        if (m.slots != null) {
            // the boot partition is FAT (the firmware's), mounted by PID 1 to
            // read the committed slot and to commit a trial
            try w.print("CONFIG_VFAT_FS=y\nCONFIG_NLS_CODEPAGE_437=y\nCONFIG_NLS_ISO8859_1=y\n", .{});
        }
        {
            // the groups a declared budget is held in (BDG-1): the memory
            // controller for the ceiling that kills, the cpu controller
            // and its bandwidth for the share that throttles. Asked for
            // only when a world declares one -- a machine carries the
            // kernel its own declaration needs.
            var budgeted = false;
            var counted = false;
            for (m.services) |s| {
                if (s.memory_mb != null or s.cpu_percent != null) budgeted = true;
                if (s.tasks != null) counted = true;
            }
            if (budgeted or counted) {
                try w.print("CONFIG_CGROUPS=y\n", .{});
            }
            if (budgeted) {
                try w.print("CONFIG_MEMCG=y\nCONFIG_CGROUP_SCHED=y\nCONFIG_FAIR_GROUP_SCHED=y\nCONFIG_CFS_BANDWIDTH=y\n", .{});
            }
            // the pids controller is what holds a TASKS ceiling (THR-1)
            if (counted) try w.print("CONFIG_CGROUP_PIDS=y\n", .{});
            // ... and the kernel that can hold a world to what it did NOT
            // declare (NS-1). NAMESPACES is the menu NET_NS lives under
            // and tinyconfig closes it, which is the trap OS-3 paid for;
            // SECCOMP_FILTER is what makes a filter more than a mode.
            // Only when a world is actually confined: a machine carries
            // the kernel its own declaration needs and nothing else.
            var needs_namespaces = false;
            var needs_netns = false;
            var needs_pidns = false;
            var needs_seccomp = false;
            for (m.services) |s| {
                const c = try confine.Confinement.ofAlloc(m.*, s, arena);
                if (!c.network) {
                    needs_netns = true;
                    needs_namespaces = true;
                }
                // a MOUNT namespace needs no option of its own: it exists
                // wherever NAMESPACES does (MNT-1)
                if (c.hidden.len > 0) needs_namespaces = true;
                if (!c.process) {
                    // a world alone in its own process table (PID-1), which
                    // also needs the mount namespace its /proc is remounted in
                    needs_pidns = true;
                    needs_namespaces = true;
                }
                if (!c.process or !c.threads) needs_seccomp = true;
            }
            // NAMESPACES is a menu tinyconfig closes; NET_NS lives under
            // it AND under NET, which only a machine with a declared
            // network opens -- so each is asked for exactly where it can
            // be built and where it means something.
            if (needs_namespaces) try w.print("CONFIG_NAMESPACES=y\n", .{});
            if (needs_netns) try w.print("CONFIG_NET_NS=y\n", .{});
            if (needs_pidns) try w.print("CONFIG_PID_NS=y\n", .{});
            // EVERY world carries the floor's own refusals since SYS-1, so
            // a machine with any world at all needs the filter built in
            if (m.services.len > 0) needs_seccomp = true;
            if (needs_seccomp) {
                // CONFIG_SECCOMP_FILTER depends on HAVE_ARCH_SECCOMP_FILTER
                // && SECCOMP && NET: the kernel builds its filter engine on
                // the BPF core, which lives under NET. So a machine with no
                // declared network still needs CONFIG_NET to hold its worlds
                // to the floor, and it gets it -- a machine carries the
                // kernel ITS OWN DECLARATION needs, and since SYS-1 every
                // declaration needs the floor's refusals. Found because
                // qemu_hello refused to start a world it could not confine,
                // which is the NS-1 law doing exactly its job.
                if (m.networks.len == 0) try w.print("CONFIG_NET=y\n", .{});
                try w.print("CONFIG_SECCOMP=y\nCONFIG_SECCOMP_FILTER=y\n", .{});
            }
        }
        if (block) |b| {
            // BLOCK and BLK_DEV are menus tinyconfig closes; VIRTIO_MENU
            // gates every virtio driver. Without them, olddefconfig drops
            // the drivers silently and the mount fails NOENT -- the Makeen
            // box's first emulated boot (PROTOCOL.md, OS-3 finding 2).
            try w.print("CONFIG_BLOCK=y\nCONFIG_BLK_DEV=y\n", .{});
            if (t.blk_device != null) try w.print("CONFIG_VIRTIO_MENU=y\nCONFIG_VIRTIO=y\nCONFIG_VIRTIO_BLK=y\n", .{});
            for (t.block_cfg) |l| try w.print("{s}\n", .{l});
            switch (b.fs) {
                .ext4 => try w.print("CONFIG_EXT4_FS=y\n", .{}),
                .vfat => try w.print("CONFIG_VFAT_FS=y\nCONFIG_NLS_CODEPAGE_437=y\nCONFIG_NLS_ISO8859_1=y\n", .{}),
                else => {},
            }
        }
        try writeOut(opts.out_dir, "kernel.fragment", frag.items);
    }

    // disk.list -- the virtio disks to create (emulator boards)
    {
        var disks: std.ArrayList(u8) = .{};
        const w = disks.writer(arena);
        try w.print("# disk.list -- derived by harb image: id device fs size_mb image\n", .{});
        if (block) |b| if (t.blk_device != null) try w.print("d0 {s} {s} {d} disk0.img\n", .{ b.device.?, @tagName(b.fs), opts.disk_mb });
        try writeOut(opts.out_dir, "disk.list", disks.items);
    }

    // sd.list + config.txt + cmdline.txt -- a board that boots from a card
    if (t.sd) {
        var sd: std.ArrayList(u8) = .{};
        const w = sd.writer(arena);
        try w.print("# sd.list -- derived by harb image: the card's partitions (part id fs size_mb label) and the boot partition's files (boot name source)\n", .{});
        try w.print("part p1 fat32 64 boot\n", .{});
        if (block) |b| {
            try w.print("part p2 {s} {d} {s}\n", .{ @tagName(b.fs), opts.disk_mb, b.name });
        }
        try w.print("boot config.txt config.txt\n", .{});
        try w.print("boot start4.elf firmware/start4.elf\n", .{});
        try w.print("boot fixup4.dat firmware/fixup4.dat\n", .{});
        if (m.slots != null) {
            // A/B: the same image in both slots at first; an update writes the
            // other slot and asks the firmware to try it once. config.txt's
            // [tryboot] section is the firmware's own mechanism: it passes only
            // on a boot requested with the tryboot flag, so the trial slot's
            // prefix applies once, and a reset falls back to the committed one.
            const config = try std.fmt.allocPrint(arena,
                \\# config.txt -- derived by harb image for {s} ({s}); read by the board's firmware
                \\arm_64bit=1
                \\kernel=kernel8.img
                \\initramfs initramfs.cpio followkernel
                \\enable_uart=1
                \\os_prefix=slots/A/
                \\[tryboot]
                \\os_prefix=slots/B/
                \\
            , .{ m.name, @tagName(m.board) });
            try writeOut(opts.out_dir, "config.txt", config);
            for ([_][]const u8{ "A", "B" }) |slot| {
                const cmdline = try std.fmt.allocPrint(arena, "console={s} quiet loglevel=3 harb.slot={s} rdinit=/harb -- init /etc/machine\n", .{ t.console_board, slot });
                try writeOut(opts.out_dir, try std.fmt.allocPrint(arena, "cmdline.{s}.txt", .{slot}), cmdline);
                try w.print("boot slots/{s}/cmdline.txt cmdline.{s}.txt\n", .{ slot, slot });
                try w.print("boot slots/{s}/kernel8.img {s}\n", .{ slot, t.image_name });
                try w.print("boot slots/{s}/bcm2711-rpi-4-b.dtb bcm2711-rpi-4-b.dtb\n", .{slot});
                try w.print("boot slots/{s}/initramfs.cpio initramfs.cpio\n", .{slot});
            }
        } else {
            const cmdline = try std.fmt.allocPrint(arena, "console={s} quiet loglevel=3 rdinit=/harb -- init /etc/machine\n", .{t.console_board});
            try writeOut(opts.out_dir, "cmdline.txt", cmdline);
            const config = try std.fmt.allocPrint(arena,
                \\# config.txt -- derived by harb image for {s} ({s}); read by the board's firmware
                \\arm_64bit=1
                \\kernel=kernel8.img
                \\initramfs initramfs.cpio followkernel
                \\enable_uart=1
                \\
            , .{ m.name, @tagName(m.board) });
            try writeOut(opts.out_dir, "config.txt", config);
            try w.print("boot cmdline.txt cmdline.txt\n", .{});
            try w.print("boot kernel8.img {s}\n", .{t.image_name});
            try w.print("boot bcm2711-rpi-4-b.dtb bcm2711-rpi-4-b.dtb\n", .{});
            try w.print("boot initramfs.cpio initramfs.cpio\n", .{});
        }
        try writeOut(opts.out_dir, "sd.list", sd.items);
    }

    // boot.cmd -- the same board, emulated
    {
        var cmd: std.ArrayList(u8) = .{};
        const w = cmd.writer(arena);
        try w.print("{s} {s}", .{ t.qemu, t.machine_args });
        if (t.memory_mb > 0) try w.print(" -m {d}M", .{t.memory_mb});
        try w.print(" -nographic -no-reboot -kernel {s} -initrd initramfs.cpio", .{t.image_name});
        if (t.sd) {
            try w.print(" -drive file=sd.img,if=sd,format=raw", .{});
        } else if (block != null) {
            try w.print(" -drive if=none,file=disk0.img,format=raw,id=d0 -device {s},drive=d0", .{t.blk_device.?});
        }
        // QEMU's user-mode network: a built-in DHCP server (router 10.0.2.2,
        // lease 10.0.2.15, dns 10.0.2.3) -- the oracle for a dhcp NETWORK
        if (m.networks.len > 0) if (t.net_device) |nd| try w.print(" -netdev user,id=n0 -device {s},netdev=n0", .{nd});
        // rdinit=, not init=: the root IS the initramfs. With init= the
        // kernel first looks for /init, finds none, and goes to mount a
        // root DEVICE -- which panics as soon as CONFIG_BLOCK exists. The
        // x86 boot of OS-2 worked only because its kernel had no block
        // layer to try (PROTOCOL.md, OS-3 finding 1).
        // an A/B machine is booted by the court as a TRIAL of slot B while
        // the card commits A: the transcript shows the trial and the commit,
        // and the card's config.txt after the boot is the second witness
        // ... and with the watchdog off: QEMU's raspi4b resets the board the
        // moment it is armed (no countdown in its model), so the emulator's
        // line says so and PID 1 states the consequence. The card's own
        // cmdline.txt never carries it.
        const slot_arg: []const u8 = if (m.slots != null) " harb.slot=B harb.watchdog=off" else "";
        // ... and judged through the emulator's lens, when it has one
        const lens_arg: []const u8 = if (t.qemu_lens != null) " harb.expect=emulator" else "";
        // ... and ENDED, when the machine's worlds serve: a daemon never
        // exits, so a real init never halts and the transcript never
        // closes. Derived from the declaration -- any service that is not
        // a one-shot -- and carried on the EMULATOR's line only. The
        // card's cmdline.txt never says it: a board keeps the box alive
        // (SRV-1).
        var serves = false;
        for (m.services) |svc| {
            if (svc.restart != .never) serves = true;
        }
        const init_args = try std.fmt.allocPrint(arena, "-- init /etc/machine{s}", .{if (serves) " --halt-on-verdict" else ""});
        try w.print(" -append \"console={s} quiet loglevel=3{s}{s} rdinit=/harb {s}\"\n", .{ t.console_qemu, slot_arg, lens_arg, init_args });
        try writeOut(opts.out_dir, "boot.cmd", cmd.items);
        if (m.slots != null) {
            // the rollback instrument: the same trial, held -- never committed,
            // the watchdog not fed. What follows is the hardware's answer.
            const hold_needle = try std.fmt.allocPrint(arena, "{s}\"", .{init_args});
            const hold_with = try std.fmt.allocPrint(arena, "{s} --hold\"", .{init_args});
            const hold = try std.mem.replaceOwned(u8, arena, cmd.items, hold_needle, hold_with);
            try writeOut(opts.out_dir, "boot_hold.cmd", hold);
            // the judge's negative: the same trial judged by the BOARD's
            // expectation, which the emulator cannot meet. PID 1 must name
            // the lines and hold the trial; the card must still boot A.
            if (t.qemu_lens != null) {
                const unmet = try std.mem.replaceOwned(u8, arena, cmd.items, " harb.expect=emulator", "");
                try writeOut(opts.out_dir, "boot_unmet.cmd", unmet);
            }
        }
    }

    try out.print("image {s} -- {s} / {s} / {s} -- {d} dir(s), {d} file(s), {s}, {d} network(s) -> {s}/\n", .{ m.name, @tagName(m.profile), @tagName(m.arch), @tagName(m.board), dirs.items.len, files.items.len, if (t.sd) "an SD card" else if (block != null) "1 disk" else "no disk", m.networks.len, opts.out_dir });
    for (files.items) |f| try out.print("  {s} <- {s}\n", .{ f.path, f.source });
    if (block) |b| try out.print("  {s} -> {s} ({s}, {d} MB) at {s}\n", .{ if (t.sd) "card p2" else "disk d0", b.device.?, @tagName(b.fs), opts.disk_mb, b.at });
    return 0;
}

fn appendFile(arena: std.mem.Allocator, files: *std.ArrayList(Entry), dirs: *std.ArrayList([]const u8), path: []const u8, source: []const u8) !void {
    for (files.items) |f| if (std.mem.eql(u8, f.path, path)) return;
    if (std.fs.path.dirnamePosix(path)) |d| if (d.len > 1) try addDir(arena, dirs, d);
    try files.append(arena, .{ .path = path, .source = source });
}

fn writeOut(dir: []const u8, name: []const u8, bytes: []const u8) !void {
    var d = try std.fs.cwd().openDir(dir, .{});
    defer d.close();
    var f = try d.createFile(name, .{});
    defer f.close();
    try f.writeAll(bytes);
}
