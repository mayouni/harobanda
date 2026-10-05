//! `harb own <dir> [--not <other>]...` -- a world asks, from inside, what it may write (OWN-1).
//!
//! The witness of the STATE seat, as `harb id` is USER's and `harb reach` is EGRESS's. It is run AS
//! the identity the machine gave a world, so it asks the KERNEL, one question at a time, what that
//! identity can do, and says each answer on its own line. It does not trust what the declaration says
//! the machine did: the boot line `boot: state -- ...` is PID 1's word that it handed a directory over,
//! and this is the world's own experience of having been handed it.
//!
//!   - in `<dir>`, which it was given: it makes a file, and reads it back
//!   - in `<dir>`'s parent, and in `/`, which are the machine's: it asks to make a file, and must be
//!     refused. If it is not, it says so in capitals and takes the file away: a world that can write
//!     the machine's directories was never confined to its own
//!   - in each `--not <other>`, a directory another world owns: it asks to list it and to make a file
//!     there, and must be refused both times
//!
//! The last line is the verdict: every answer was the one a world with only its own directory gets.
//! Unlike `get` and `reach`, whose answers are facts about where a machine stands, this asserts an
//! invariant, so it exits 1 when an answer was wrong: PID 1's own ledger then says `exited 1` where the
//! machine's expectation says `exited 0`, the machine's own judge convicts the boot (JDG-1), and the
//! world that comes AFTER never starts. The pinned transcript, and the file this leaves on the disk
//! (the disk is read back after the boot, and the file is that identity's), convict it a second way.

const std = @import("std");
const builtin = @import("builtin");

/// What it asked of the kernel: allowed, or the kernel's own word for why not.
pub const Answer = union(enum) {
    allowed,
    refused: []const u8,
};

/// Ask to make an (empty) file at `path`. An answer, never an error: a refusal is what is being asked
/// for, and every other failure is reported by its name.
pub fn tryMake(path: []const u8) Answer {
    const f = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch |e| return .{ .refused = @errorName(e) };
    f.close();
    return .allowed;
}

/// Ask to list the directory at `path`.
pub fn tryList(path: []const u8) Answer {
    var d = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |e| return .{ .refused = @errorName(e) };
    defer d.close();
    var it = d.iterate();
    _ = it.next() catch |e| return .{ .refused = @errorName(e) };
    return .allowed;
}

/// The directory a path lies in, or `/` for a path with none.
pub fn parentOf(path: []const u8) []const u8 {
    return std.fs.path.dirnamePosix(path) orelse "/";
}

/// The verb. Returns what `harb` exits with.
pub fn run(args: []const []const u8, out: *std.Io.Writer) !u8 {
    if (builtin.os.tag != .linux) {
        try out.print("own: a Linux act; this binary was built for {s}\n", .{@tagName(builtin.os.tag)});
        return 2;
    }
    if (args.len < 1) {
        try out.print("harb: own takes a directory (harb own /data/app [--not /data/other]...)\n", .{});
        return 1;
    }
    const dir = args[0];
    var others: [8][]const u8 = undefined;
    var n_others: usize = 0;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (!std.mem.eql(u8, args[i], "--not") or i + 1 >= args.len or n_others == others.len) {
            try out.print("harb: own takes a directory and up to {d} of --not <directory>\n", .{others.len});
            return 1;
        }
        i += 1;
        others[n_others] = args[i];
        n_others += 1;
    }

    const linux = std.os.linux;
    try out.print("own: uid={d} gid={d}\n", .{ linux.getuid(), linux.getgid() });
    var wrong: usize = 0;

    // the directory it was given: a file made and read back
    var note_buf: [std.fs.max_path_bytes]u8 = undefined;
    const note = std.fmt.bufPrint(&note_buf, "{s}/note", .{dir}) catch {
        try out.print("own: {s} -- the path is too long\n", .{dir});
        return 1;
    };
    const kept: ?usize = blk: {
        const f = std.fs.cwd().createFile(note, .{ .truncate = true }) catch |e| {
            try out.print("own: {s} -- could not write here: {s}\n", .{ dir, @errorName(e) });
            break :blk null;
        };
        defer f.close();
        f.writeAll("Ahlan\n") catch |e| {
            try out.print("own: {s} -- could not write here: {s}\n", .{ dir, @errorName(e) });
            break :blk null;
        };
        var back: [16]u8 = undefined;
        const got = std.fs.cwd().readFile(note, &back) catch |e| {
            try out.print("own: {s} -- wrote, and could not read it back: {s}\n", .{ dir, @errorName(e) });
            break :blk null;
        };
        break :blk got.len;
    };
    if (kept) |bytes| {
        try out.print("own: {s} -- wrote note and read it back ({d} bytes)\n", .{ dir, bytes });
    } else {
        wrong += 1;
    }

    // the machine's directories: the parent of the one it was given, and the root
    const machines = [_][]const u8{ parentOf(dir), "/" };
    for (machines, 0..) |m, k| {
        if (k == 1 and std.mem.eql(u8, m, machines[0])) continue; // the parent IS the root
        var probe_buf: [std.fs.max_path_bytes]u8 = undefined;
        const probe = std.fmt.bufPrint(&probe_buf, "{s}{s}own-probe", .{ m, if (std.mem.endsWith(u8, m, "/")) "" else "/" }) catch continue;
        switch (tryMake(probe)) {
            .refused => |why| try out.print("own: {s} -- refused: {s}\n", .{ m, why }),
            .allowed => {
                wrong += 1;
                try out.print("own: {s} -- WROTE A FILE THERE: this world can change the machine's own directory\n", .{m});
                std.fs.cwd().deleteFile(probe) catch {};
            },
        }
    }

    // a directory another world owns: it may neither list it nor make a file in it
    for (others[0..n_others]) |other| {
        switch (tryList(other)) {
            .refused => |why| try out.print("own: {s} -- refused to list: {s}\n", .{ other, why }),
            .allowed => {
                wrong += 1;
                try out.print("own: {s} -- LISTED: this world can read another's directory\n", .{other});
            },
        }
        var probe_buf: [std.fs.max_path_bytes]u8 = undefined;
        const probe = std.fmt.bufPrint(&probe_buf, "{s}/own-probe", .{other}) catch continue;
        switch (tryMake(probe)) {
            .refused => |why| try out.print("own: {s} -- refused to write: {s}\n", .{ other, why }),
            .allowed => {
                wrong += 1;
                try out.print("own: {s} -- WROTE A FILE THERE: this world can change another's directory\n", .{other});
                std.fs.cwd().deleteFile(probe) catch {};
            },
        }
    }

    if (wrong == 0) {
        try out.print("own: this world wrote in its own directory and nowhere else\n", .{});
        return 0;
    }
    try out.print("own: NOT AS DECLARED -- {d} answer(s) were not the ones a world with only its own directory gets\n", .{wrong});
    return 1;
}

test "a path's parent is its directory, and / has none above it" {
    try std.testing.expectEqualStrings("/data", parentOf("/data/alpha"));
    try std.testing.expectEqualStrings("/", parentOf("/data"));
    try std.testing.expectEqualStrings("/", parentOf("/"));
}

test "asking to make a file says made once and refused after, with the kernel's word (OWN-1)" {
    // Linux only: the kernel is the one being asked. As root every directory is writable, so the
    // refusal half is asked of a directory that does not exist, which every identity is refused.
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const gpa = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realpathAlloc(gpa, ".");
    defer gpa.free(base);
    const p = try std.fmt.allocPrint(gpa, "{s}/f", .{base});
    defer gpa.free(p);
    try std.testing.expect(tryMake(p) == .allowed);
    switch (tryMake(p)) { // exclusive: the second is refused, and says why
        .allowed => return error.TestUnexpectedResult,
        .refused => |why| try std.testing.expectEqualStrings("PathAlreadyExists", why),
    }
    const missing = try std.fmt.allocPrint(gpa, "{s}/nowhere/f", .{base});
    defer gpa.free(missing);
    switch (tryMake(missing)) {
        .allowed => return error.TestUnexpectedResult,
        .refused => |why| try std.testing.expectEqualStrings("FileNotFound", why),
    }
    try std.testing.expect(tryList(base) == .allowed);
    try std.testing.expect(tryList(missing) != .allowed);
}
