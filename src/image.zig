// image.zig -- the hosted image, DERIVED from a judged plan. This module
// writes declarative artifacts into an output directory and touches no
// toolchain:
//
//   initramfs.list   the kernel's own gen_init_cpio description of the
//                    root filesystem: the mount points, the device nodes
//                    PID 1 needs, /etc/machine (the declaration itself),
//                    /stzos, and every program and file the services name
//                    -- each taken from a STAGING ROOT and refused if absent
//   kernel.fragment  the kconfig options the profile, the architecture and
//                    the declared mounts require, merged over tinyconfig
//   image.env        what the build must be told: the kernel ARCH, the
//                    cross prefix, the kernel artifact's path
//   disk.list        the block devices the declared mounts need (one per
//                    line: id, device, fs, size) -- the build creates them
//   boot.cmd         the QEMU line that boots the image with this binary
//                    as PID 1 and the serial console as the transcript
//
// The imperative act -- building the vendored kernel, packing the cpio,
// making the disks, running QEMU -- is experiment/os2_image.sh on a
// Linux host. The derivation is here so it is portable, judged, and
// printed before it is run: the image is text before it is an act.

const std = @import("std");
const machine = @import("machine.zig");
const plan = @import("plan.zig");

pub const Options = struct {
    out_dir: []const u8,
    root: []const u8,
    machine_path: []const u8,
    disk_mb: u32 = 64,
};

const Entry = struct { path: []const u8, source: []const u8 };

/// What each supported architecture needs, in one place.
const Target = struct {
    kernel_arch: []const u8, // make ARCH=
    cross: []const u8, // make CROSS_COMPILE=
    artifact: []const u8, // path of the kernel image inside the tree
    image_name: []const u8, // its name in the output dir
    qemu: []const u8,
    machine_args: []const u8,
    console: []const u8,
    memory_mb: u32,
    serial_cfg: []const []const u8,
    block_cfg: []const []const u8,
    blk_device: []const u8, // the QEMU virtio-blk device for this machine type
};

fn target(arch: machine.Arch) ?Target {
    return switch (arch) {
        .x86_64 => .{
            .kernel_arch = "x86_64",
            .cross = "",
            .artifact = "arch/x86/boot/bzImage",
            .image_name = "bzImage",
            .qemu = "qemu-system-x86_64",
            .machine_args = "-M pc -cpu max",
            .console = "ttyS0",
            .memory_mb = 256,
            .serial_cfg = &.{ "CONFIG_SERIAL_8250=y", "CONFIG_SERIAL_8250_CONSOLE=y", "CONFIG_KERNEL_GZIP=y" },
            .block_cfg = &.{ "CONFIG_PCI=y", "CONFIG_VIRTIO_PCI=y" },
            .blk_device = "virtio-blk-pci",
        },
        .aarch64 => .{
            .kernel_arch = "arm64",
            .cross = "aarch64-linux-gnu-",
            .artifact = "arch/arm64/boot/Image",
            .image_name = "Image",
            .qemu = "qemu-system-aarch64",
            .machine_args = "-M virt -cpu cortex-a53",
            .console = "ttyAMA0",
            .memory_mb = 512,
            .serial_cfg = &.{ "CONFIG_SERIAL_AMBA_PL011=y", "CONFIG_SERIAL_AMBA_PL011_CONSOLE=y" },
            .block_cfg = &.{"CONFIG_VIRTIO_MMIO=y"},
            .blk_device = "virtio-blk-device",
        },
        else => null,
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
        try out.print("image: refused -- only the hosted profile has an image here; a {s} machine is projected by its own substrate\n", .{@tagName(m.profile)});
        return 2;
    }
    const t = target(m.arch) orelse {
        try out.print("image: refused -- the {s} image is queued; x86_64 and aarch64 boot in QEMU today\n", .{@tagName(m.arch)});
        return 2;
    };

    // image.env first: it derives from the declaration alone, so the build
    // can learn the target before anything is staged
    try std.fs.cwd().makePath(opts.out_dir);
    {
        const env = try std.fmt.allocPrint(arena,
            "# image.env -- derived by stzos image; sourced by experiment/os2_image.sh\nARCH={s}\nCROSS_COMPILE={s}\nKERNEL_ARTIFACT={s}\nKERNEL_IMAGE={s}\nTRIPLE={s}-linux-musl\n", .{ t.kernel_arch, t.cross, t.artifact, t.image_name, @tagName(m.arch) });
        try writeOut(opts.out_dir, "image.env", env);
    }

    var dirs: std.ArrayList([]const u8) = .{};
    var files: std.ArrayList(Entry) = .{};
    for ([_][]const u8{ "/dev", "/proc", "/sys", "/etc", "/tmp" }) |d| try addDir(arena, &dirs, d);
    for (m.mounts) |mt| try addDir(arena, &dirs, mt.at);

    // /stzos: this binary, cross-built, staged at the root
    const stzos_src = (try staged(arena, opts.root, "/stzos")) orelse {
        try out.print("image: refused -- /stzos is not staged under {s} (zig build cross, then copy the Linux binary there)\n", .{opts.root});
        return 2;
    };
    try files.append(arena, .{ .path = "/stzos", .source = stzos_src });

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

    // the block devices the declared mounts need -- one in this version
    var block: ?*const machine.Mount = null;
    for (m.mounts) |*mt| {
        if (mt.fs == .ext4 or mt.fs == .vfat) {
            if (block != null) {
                try out.print("image: refused -- two block mounts ({s} and {s}); one virtio disk per image today\n", .{ block.?.name, mt.name });
                return 2;
            }
            block = mt;
        }
    }

    // initramfs.list -- gen_init_cpio format
    {
        var list: std.ArrayList(u8) = .{};
        const w = list.writer(arena);
        try w.print("# initramfs.list -- derived by stzos image from {s}; gen_init_cpio format\n", .{opts.machine_path});
        try w.print("dir /dev 0755 0 0\n", .{});
        try w.print("nod /dev/console 0600 0 0 c 5 1\n", .{});
        try w.print("nod /dev/null 0666 0 0 c 1 3\n", .{});
        for (dirs.items) |d| {
            if (std.mem.eql(u8, d, "/dev")) continue;
            try w.print("dir {s} 0755 0 0\n", .{d});
        }
        for (files.items) |f| {
            const mode: []const u8 = if (std.mem.eql(u8, f.path, "/etc/machine")) "0644" else "0755";
            try w.print("file {s} {s} {s} 0 0\n", .{ f.path, f.source, mode });
        }
        try writeOut(opts.out_dir, "initramfs.list", list.items);
    }

    // kernel.fragment
    {
        var frag: std.ArrayList(u8) = .{};
        const w = frag.writer(arena);
        try w.print("# kernel.fragment -- derived by stzos image from {s} for {s}; merged over tinyconfig\n", .{ opts.machine_path, t.kernel_arch });
        const base = [_][]const u8{
            "CONFIG_64BIT=y",       "CONFIG_PRINTK=y",    "CONFIG_TTY=y",        "CONFIG_BLK_DEV_INITRD=y",
            "CONFIG_BINFMT_ELF=y",  "CONFIG_PROC_FS=y",   "CONFIG_SYSFS=y",      "CONFIG_DEVTMPFS=y",
            "CONFIG_TMPFS=y",       "CONFIG_SHMEM=y",     "CONFIG_FUTEX=y",      "CONFIG_EPOLL=y",
            "CONFIG_EVENTFD=y",     "CONFIG_SIGNALFD=y",  "CONFIG_TIMERFD=y",    "CONFIG_MULTIUSER=y",
            "# CONFIG_MODULES is not set",
        };
        for (base) |l| try w.print("{s}\n", .{l});
        for (t.serial_cfg) |l| try w.print("{s}\n", .{l});
        if (block) |b| {
            // BLOCK and BLK_DEV are menus tinyconfig closes; VIRTIO_MENU
            // gates every virtio driver. Without the three, olddefconfig
            // drops VIRTIO_BLK silently and the mount fails NOENT -- the
            // Makeen box's first boot (PROTOCOL.md, OS-3 finding 2).
            try w.print("CONFIG_BLOCK=y\nCONFIG_BLK_DEV=y\nCONFIG_VIRTIO_MENU=y\nCONFIG_VIRTIO=y\nCONFIG_VIRTIO_BLK=y\n", .{});
            for (t.block_cfg) |l| try w.print("{s}\n", .{l});
            switch (b.fs) {
                .ext4 => try w.print("CONFIG_EXT4_FS=y\n", .{}),
                .vfat => try w.print("CONFIG_VFAT_FS=y\nCONFIG_NLS_CODEPAGE_437=y\nCONFIG_NLS_ISO8859_1=y\n", .{}),
                else => {},
            }
        }
        try writeOut(opts.out_dir, "kernel.fragment", frag.items);
    }

    // disk.list -- the block devices to create
    {
        var disks: std.ArrayList(u8) = .{};
        const w = disks.writer(arena);
        try w.print("# disk.list -- derived by stzos image: id device fs size_mb image\n", .{});
        if (block) |b| try w.print("d0 {s} {s} {d} disk0.img\n", .{ b.device.?, @tagName(b.fs), opts.disk_mb });
        try writeOut(opts.out_dir, "disk.list", disks.items);
    }

    // boot.cmd
    {
        var cmd: std.ArrayList(u8) = .{};
        const w = cmd.writer(arena);
        try w.print("{s} {s} -m {d}M -nographic -no-reboot -kernel {s} -initrd initramfs.cpio", .{ t.qemu, t.machine_args, t.memory_mb, t.image_name });
        if (block != null) try w.print(" -drive if=none,file=disk0.img,format=raw,id=d0 -device {s},drive=d0", .{t.blk_device});
        // rdinit=, not init=: the root IS the initramfs. With init= the
        // kernel first looks for /init, finds none, and goes to mount a
        // root DEVICE -- which panics as soon as CONFIG_BLOCK exists. The
        // x86 boot of OS-2 worked only because its kernel had no block
        // layer to try (PROTOCOL.md, OS-3 finding 1).
        try w.print(" -append \"console={s} quiet loglevel=3 rdinit=/stzos -- init /etc/machine\"\n", .{t.console});
        try writeOut(opts.out_dir, "boot.cmd", cmd.items);
    }

    try out.print("image {s} -- {s} / {s} -- {d} dir(s), {d} file(s), {d} disk(s) -> {s}/{{initramfs.list,kernel.fragment,image.env,disk.list,boot.cmd}}\n", .{ m.name, @tagName(m.profile), @tagName(m.arch), dirs.items.len, files.items.len, @as(u8, if (block != null) 1 else 0), opts.out_dir });
    for (files.items) |f| try out.print("  {s} <- {s}\n", .{ f.path, f.source });
    if (block) |b| try out.print("  disk d0 -> {s} ({s}, {d} MB) at {s}\n", .{ b.device.?, @tagName(b.fs), opts.disk_mb, b.at });
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
