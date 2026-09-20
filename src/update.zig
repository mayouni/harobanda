// update.zig -- `harb update <dir>`: write a new image into the slot that
// is NOT committed, then ask the firmware to try it once. The file half:
// the boot partition (SLOTS of the machine at /etc/machine, or --boot
// <dir> to rehearse on any directory) is read for the committed slot, the
// other slot receives kernel8.img, initramfs.cpio, the dtb and
// cmdline.txt from <dir>, every byte synced. The reboot half: a restart
// with the argument "0 tryboot", which the Raspberry Pi's downstream
// kernel turns into the firmware's tryboot flag -- mainline 6.12's
// watchdog driver ignores the argument (a plain restart), so on this
// kernel the trial must be requested by hand until the driver is patched
// (a named seam, experiment/PROTOCOL.md AB-1). --no-reboot writes and stops.

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");

const files = [_][]const u8{ "kernel8.img", "initramfs.cpio", "bcm2711-rpi-4-b.dtb", "cmdline.txt" };

pub fn run(gpa: std.mem.Allocator, args: []const []const u8, out: *std.Io.Writer) !u8 {
    if (args.len < 1) {
        try out.print("update: usage -- harb update <dir> [--boot <mountpoint>] [--no-reboot]\n", .{});
        return 1;
    }
    const src = args[0];
    var boot: ?[]const u8 = null;
    var do_reboot = true;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--boot") and i + 1 < args.len) {
            i += 1;
            boot = args[i];
        } else if (std.mem.eql(u8, args[i], "--no-reboot")) {
            do_reboot = false;
        } else {
            try out.print("update: unknown option '{s}'\n", .{args[i]});
            return 1;
        }
    }
    var mounted = false;
    if (boot == null) {
        if (builtin.os.tag != .linux) {
            try out.print("update: mounting the boot partition is a Linux act; pass --boot <dir> to rehearse\n", .{});
            return 2;
        }
        return updateOnMachine(gpa, src, do_reboot, out, &mounted);
    }
    return updateIn(gpa, boot.?, src, out);
}

fn updateOnMachine(gpa: std.mem.Allocator, src: []const u8, do_reboot: bool, out: *std.Io.Writer, mounted: *bool) !u8 {
    const linux = std.os.linux;
    const text = std.fs.cwd().readFileAlloc(gpa, "/etc/machine", 1 << 20) catch |e| {
        try out.print("update: /etc/machine unreadable: {s}\n", .{@errorName(e)});
        return 2;
    };
    defer gpa.free(text);
    var refusal = machine.Refusal{};
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const m = machine.declare(arena_state.allocator(), text, &refusal) catch {
        try out.print("update: /etc/machine refused: {s}\n", .{refusal.message});
        return 2;
    };
    const dev = m.slots orelse {
        try out.print("update: this machine declares no SLOTS; a single-slot machine is updated by writing a new card\n", .{});
        return 2;
    };
    std.fs.cwd().makePath("/boot") catch {};
    const devz = try gpa.dupeZ(u8, dev);
    defer gpa.free(devz);
    switch (linux.E.init(linux.mount(devz.ptr, "/boot", "vfat", 0, 0))) {
        .SUCCESS => mounted.* = true,
        .BUSY => {},
        else => |e| {
            try out.print("update: the boot partition {s} refused: {s}\n", .{ dev, @tagName(e) });
            return 2;
        },
    }
    const code = try updateIn(gpa, "/boot", src, out);
    linux.sync();
    if (code != 0 or !do_reboot) return code;
    try out.print("update: restarting with the tryboot flag -- the firmware tries the new slot once; PID 1 commits it when every service has started\n", .{});
    try out.flush();
    const rc = linux.reboot(.MAGIC1, .MAGIC2, .RESTART2, @ptrCast("0 tryboot"));
    try out.print("update: reboot refused: {s}\n", .{@tagName(linux.E.init(rc))});
    return 2;
}

/// the file half, on any directory laid out like the boot partition
fn updateIn(gpa: std.mem.Allocator, boot: []const u8, src: []const u8, out: *std.Io.Writer) !u8 {
    const cfg_path = try std.fs.path.join(gpa, &.{ boot, "config.txt" });
    defer gpa.free(cfg_path);
    const cfg = std.fs.cwd().readFileAlloc(gpa, cfg_path, 1 << 16) catch |e| {
        try out.print("update: {s} unreadable: {s}\n", .{ cfg_path, @errorName(e) });
        return 2;
    };
    defer gpa.free(cfg);
    const head = if (std.mem.indexOf(u8, cfg, "[tryboot]")) |t| cfg[0..t] else cfg;
    const k = std.mem.indexOf(u8, head, "os_prefix=slots/") orelse {
        try out.print("update: config.txt names no committed slot (no os_prefix=slots/)\n", .{});
        return 2;
    };
    const committed = head[k + "os_prefix=slots/".len];
    const target: u8 = if (committed == 'A') 'B' else 'A';
    try out.print("update: committed slot {c}; writing {c} from {s}\n", .{ committed, target, src });
    // every source must exist before a byte is written: a half-written slot
    // would fail its trial and roll back, but it is better refused whole
    // (the rehearsal's negative: a missing cmdline.txt left three files behind)
    for (files) |name| {
        const from = try std.fs.path.join(gpa, &.{ src, name });
        defer gpa.free(from);
        std.fs.cwd().access(from, .{}) catch |e| {
            try out.print("update: refused -- {s} is missing from {s} ({s}); nothing written\n", .{ name, src, @errorName(e) });
            return 2;
        };
    }
    const slot_dir = try std.fmt.allocPrint(gpa, "{s}/slots/{c}", .{ boot, target });
    defer gpa.free(slot_dir);
    std.fs.cwd().makePath(slot_dir) catch {};
    var written: usize = 0;
    for (files) |name| {
        const from = try std.fs.path.join(gpa, &.{ src, name });
        defer gpa.free(from);
        const to = try std.fs.path.join(gpa, &.{ slot_dir, name });
        defer gpa.free(to);
        const data = std.fs.cwd().readFileAlloc(gpa, from, 1 << 28) catch |e| {
            try out.print("update: {s} -- {s}: {s}\n", .{ name, from, @errorName(e) });
            return 2;
        };
        defer gpa.free(data);
        var f = std.fs.cwd().createFile(to, .{ .truncate = true }) catch |e| {
            try out.print("update: {s} -- cannot write {s}: {s}\n", .{ name, to, @errorName(e) });
            return 2;
        };
        defer f.close();
        f.writeAll(data) catch |e| {
            try out.print("update: {s} -- write failed: {s}\n", .{ name, @errorName(e) });
            return 2;
        };
        f.sync() catch {};
        written += data.len;
        try out.print("update: slot {c}/{s} <- {d} bytes\n", .{ target, name, data.len });
    }
    try out.print("update: slot {c} written ({d} bytes); config.txt still commits {c} -- the trial decides\n", .{ target, written, committed });
    return 0;
}
