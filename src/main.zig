// stzos -- one static binary, every role. On the host it is the CLI
// (check, plan, court); on a hosted machine the same binary is PID 1
// (init). Cross-compiling it for the machine is one flag (`zig build
// cross`), and the image carries nothing else on its boot path: no
// shell, no service manager, no package manager -- the declared machine
// IS the system.
//
//   stzos check  <file.machine>                 judge a declaration
//   stzos plan   <file.machine>                 print the boot plan
//   stzos court  [declarative/machine/fixtures.json]
//   stzos init   <file.machine> [--rehearse] [--turns N]
//   stzos version

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");
const plan = @import("plan.zig");
const court = @import("court.zig");
const init = @import("init.zig");
const image = @import("image.zig");
const net = @import("net.zig");

pub const version = "0.1.0";
const default_fixtures = "declarative/machine/fixtures.json";

fn usage(out: *std.Io.Writer) !void {
    try out.print(
        \\stzos {s} -- the declared machine ({s}-{s})
        \\  stzos check  <file.machine>
        \\  stzos plan   <file.machine>
        \\  stzos court  [fixtures.json]        (default: {s})
        \\  stzos init   <file.machine> [--rehearse] [--turns N]
        \\  stzos image  <file.machine> --root <staging dir> --out <image dir>
        \\  stzos net    <iface> <a.b.c.d>/<prefix> [gateway] | <iface> dhcp   (by hand, what init does for a NETWORK)
        \\  stzos version
        \\
    , .{ version, @tagName(builtin.cpu.arch), @tagName(builtin.os.tag), default_fixtures });
}

fn load(arena: std.mem.Allocator, path: []const u8, out: *std.Io.Writer) !?machine.Machine {
    const src = std.fs.cwd().readFileAlloc(arena, path, 1 << 20) catch |e| {
        try out.print("stzos: cannot read {s}: {s}\n", .{ path, @errorName(e) });
        return null;
    };
    var refusal = machine.Refusal{};
    const m = machine.declare(arena, src, &refusal) catch |e| switch (e) {
        error.Refused => {
            try out.print("machine (line {d}): {s}\n", .{ refusal.line, refusal.message });
            return null;
        },
        else => return e,
    };
    return m;
}

pub fn main() !u8 {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Streaming, not positional: on a seekable stdout (a redirected
    // transcript) the default writer starts at offset 0 and overwrites what
    // the shell wrote before it -- found on the first WSL transcript
    // (experiment/PROTOCOL.md, OS-1 finding 2). A console never shows it;
    // a redirected file always does.
    var buf: [8192]u8 = undefined;
    var w = std.fs.File.stdout().writerStreaming(&buf);
    const out = &w.interface;
    defer out.flush() catch {};

    const args = try std.process.argsAlloc(arena);
    if (args.len < 2) {
        try usage(out);
        return 1;
    }
    const verb = args[1];

    if (std.mem.eql(u8, verb, "version")) {
        try out.print("stzos {s}\n", .{version});
        return 0;
    }
    if (std.mem.eql(u8, verb, "net")) {
        return net.run(arena, args[2..], out);
    }
    if (std.mem.eql(u8, verb, "court")) {
        const path = if (args.len > 2) args[2] else default_fixtures;
        const failures = try court.run(gpa, path, out);
        return if (failures == 0) 0 else 1;
    }
    if (std.mem.eql(u8, verb, "check") or std.mem.eql(u8, verb, "plan") or std.mem.eql(u8, verb, "init") or std.mem.eql(u8, verb, "image")) {
        if (args.len < 3) {
            try usage(out);
            return 1;
        }
        const m = (try load(arena, args[2], out)) orelse return 1;
        if (std.mem.eql(u8, verb, "check")) {
            try out.print("machine {s} -- {s} / {s} / kernel {s} -- {d} service(s), {d} capabilit{s}, {d} mount(s), {d} pin(s), {d} network(s) -- judged, no refusal\n", .{
                m.name, @tagName(m.profile), @tagName(m.arch), @tagName(m.kernel), m.services.len, m.capabilities.len, if (m.capabilities.len == 1) "y" else "ies", m.mounts.len, m.pins.len, m.networks.len,
            });
            return 0;
        }
        const p = try plan.derive(arena, &m);
        if (std.mem.eql(u8, verb, "plan")) {
            try plan.render(p, out);
            return 0;
        }
        if (std.mem.eql(u8, verb, "image")) {
            var root: ?[]const u8 = null;
            var out_dir: ?[]const u8 = null;
            var j: usize = 3;
            while (j + 1 < args.len) : (j += 2) {
                if (std.mem.eql(u8, args[j], "--root")) {
                    root = args[j + 1];
                } else if (std.mem.eql(u8, args[j], "--out")) {
                    out_dir = args[j + 1];
                } else {
                    try out.print("stzos: unknown option '{s}'\n", .{args[j]});
                    return 1;
                }
            }
            if (root == null or out_dir == null) {
                try out.print("stzos: image needs --root <staging dir> and --out <image dir>\n", .{});
                return 1;
            }
            return image.write(arena, p, .{ .out_dir = out_dir.?, .root = root.?, .machine_path = args[2] }, out);
        }
        var opts = init.Options{};
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--rehearse")) {
                opts.rehearse = true;
            } else if (std.mem.eql(u8, args[i], "--turns") and i + 1 < args.len) {
                i += 1;
                opts.turns = std.fmt.parseInt(usize, args[i], 10) catch {
                    try out.print("stzos: --turns takes a number\n", .{});
                    return 1;
                };
            } else {
                try out.print("stzos: unknown option '{s}'\n", .{args[i]});
                return 1;
            }
        }
        return init.run(gpa, p, opts, out);
    }
    try usage(out);
    return 1;
}

test {
    _ = machine;
    _ = plan;
    _ = net;
}
