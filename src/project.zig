// project.zig -- `stzos project <file.machine> --out <dir>`: the EDGE
// profile's projection. A hosted machine is imaged and booted here; an
// edge machine is not, and never will be. Its substrate is MicroRing's
// (MicroZig, littlefs, the cooperative loop as the scheduler, the tiers),
// and that repository's own refusal stands: not an RTOS, not a new
// language. So this verb writes what MicroRing CONSUMES, and nothing it
// owns: a MicroRing project is a folder with a `device.ring` in it, whose
// `Device([...])` declaration carries the board and the pins. That is
// exactly the half a `.machine` file declares.
//
// What is projected, and what is not, is printed rather than assumed:
// the pins and the board cross over; a flash MOUNT, the capabilities and
// a service's BEHAVIOUR do not. Behaviour belongs to the Device language
// (an L2 member, `04-ESTATE.md`), and until it is declared, the every/on
// handlers are the author's own Ring code beside the generated file --
// which is why the generated file names them in its comments instead of
// inventing them.

const std = @import("std");
const machine = @import("machine.zig");
const plan = @import("plan.zig");

pub const Options = struct {
    out_dir: []const u8,
};

pub fn write(arena: std.mem.Allocator, p: plan.Plan, opts: Options, out: *std.Io.Writer) !u8 {
    const m = p.machine;
    if (m.profile != .edge) {
        try out.print("project: refused -- this verb projects the EDGE profile onto MicroRing's substrate; a {s} machine is imaged here (stzos image)\n", .{@tagName(m.profile)});
        return 2;
    }
    if (m.pins.len == 0) {
        try out.print("project: refused -- {s} declares no PIN: a device.ring with no pins is a project MicroRing cannot do anything with\n", .{m.name});
        return 2;
    }
    try std.fs.cwd().makePath(opts.out_dir);

    var dev: std.ArrayList(u8) = .{};
    const w = dev.writer(arena);
    try w.print("-- device.ring -- DERIVED by stzos project from the declared machine\n", .{});
    try w.print("-- {s}. Do not edit: edit the machine and project it again.\n--\n", .{m.name});
    try w.print("-- {s}\n--\n", .{m.rationale});
    try w.print("-- What crossed over from the declaration: the board and every PIN.\n", .{});
    try w.print("-- What did NOT, and why:\n", .{});
    for (m.mounts) |mt| {
        try w.print("--   MOUNT {s} ({s} at {s}) -- the substrate's: MicroRing mounts the flash\n", .{ mt.name, @tagName(mt.fs), mt.at });
    }
    for (m.capabilities) |c| {
        try w.print("--   CAPABILITY {s} {s} -- the machine's envelope; MicroRing has no such gate\n", .{ @tagName(c.name), if (c.granted) "granted" else "refused" });
    }
    for (m.services) |s| {
        try w.print("--   SERVICE {s} (", .{s.name});
        for (s.run, 0..) |word, i| try w.print("{s}{s}", .{ if (i > 0) " " else "", word });
        try w.print(") -- its BEHAVIOUR is the Device language's, not the machine's:\n", .{});
        try w.print("--     write its every/on handler beside this file until that language exists\n", .{});
    }
    try w.print("\nDevice([\n", .{});
    try w.print("    :board = \"{s}\",\n", .{@tagName(m.board)});
    try w.print("    :pins = [\n", .{});
    for (m.pins, 0..) |pin, i| {
        try w.print("        :{s} = [ :gpio = {d}, :mode = :{s} ]{s}\n", .{ pin.name, pin.gpio, @tagName(pin.mode), if (i + 1 < m.pins.len) "," else "" });
    }
    try w.print("    ]\n])\n", .{});

    var d = try std.fs.cwd().openDir(opts.out_dir, .{});
    defer d.close();
    var f = try d.createFile("device.ring", .{});
    defer f.close();
    try f.writeAll(dev.items);

    try out.print("project {s} -- {s} / {s} / {s} -> {s}/device.ring\n", .{ m.name, @tagName(m.profile), @tagName(m.arch), @tagName(m.board), opts.out_dir });
    try out.print("  board {s}, {d} pin(s) projected\n", .{ @tagName(m.board), m.pins.len });
    for (m.pins) |pin| try out.print("    {s} -> gpio {d} {s}\n", .{ pin.name, pin.gpio, @tagName(pin.mode) });
    try out.print("  NOT projected: {d} mount(s) (the substrate's), {d} capabilit{s} (the machine's envelope), {d} service behaviour(s) (the Device language's)\n", .{ m.mounts.len, m.capabilities.len, if (m.capabilities.len == 1) "y" else "ies", m.services.len });
    try out.print("  the folder IS the project: run it with MicroRing (`microring run {s}`), which owns the substrate and the firmware\n", .{opts.out_dir});
    return 0;
}
