//! work.zig -- a worker: a world started for one job and ended after it (WORKER-1, HAROBANDA-WORKER-01).
//!
//! Code a model or a stranger wrote is run by the estate in a process of its own, because a language's own
//! sandbox is not a boundary (stzlib-security's reading of 2026-11-05: a template escaped Jinja's sandbox
//! through a bug in the interpreter beneath it, and the interpreter's authors ruled that sandboxing untrusted
//! code is not a security boundary). On this floor the boundary is the kernel's, and a WORKER is the shape:
//!
//!   - it is not started at boot. A world that declares `JOBS "<dir>"` is started by PID 1 once for each job
//!     another world places in that directory, and ended after it: when it exits, or when it runs past its
//!     `LIMIT`, at which PID 1 ends every process of its group
//!   - it is given nothing: no network, no process, no storage (the court refuses a worker that needs one), a
//!     ceiling of MEMORY and CPU the kernel holds, and NO SOCKET OF ANY KIND (`confine.Confinement.sockets`:
//!     `socket` and `socketpair` refused outright, which an empty network namespace alone does not do -- a
//!     world in one still has unix sockets and netlink)
//!   - it may write ONE folder: a scratch folder PID 1 makes for the job under `machine.work_dir`, owned by the
//!     worker's identity, holding a copy of the job's files; and it may read ONE file: its own program. A
//!     Landlock rule set says so before the exec (`holdToScratch`), so `/etc/machine`, the other worlds' files
//!     and `/` itself are refused it by the kernel
//!   - what it prints goes to a file in that folder (`stdout_name`) and never to the machine's console, where
//!     code nobody vouched for could otherwise write lines that look like the floor's
//!
//! A job is files. The world that places it -- the world whose STATE holds the JOBS directory, which the court
//! requires -- makes `<id>/` with its files and then `<id>.go` as its last act. PID 1 copies the files in,
//! starts the worker, and when it has ended copies back what the worker left in its folder into `<id>.out/`,
//! owned by the placer, and last writes `<id>.done`: one line, what became of the job. Then it removes the
//! scratch folder, so the next job starts in an empty one.
//!
//! THE PLACER OWNS EVERYTHING IN THE JOBS DIRECTORY, and PID 1 reads and writes there as root. So every name is
//! opened from a descriptor with `O_NOFOLLOW`, from the root down (a link anywhere is a refusal, never a
//! destination); a file is copied in only if it is a regular file the PLACER owns with one link (a hard link to
//! the machine's key is a regular file too -- MIR-1's lesson); what PID 1 creates there it creates with
//! `O_EXCL` and hands to the placer; and the results are moved into place by a rename of a name PID 1 made.
//!
//! Named seams: one job at a time per worker; a job is flat (files, no folders), at most `max_files` files and
//! `max_bytes` bytes each way; the scratch folder lives in RAM (`/run`) and what the floor copies into it is not
//! charged to the worker's MEMORY ceiling, what the worker writes there is; the worker's program is the one the
//! declaration names, never one the job brings, and the job's files are data to it -- what an interpreter does
//! with them is that interpreter's, inside this envelope.

const std = @import("std");
const builtin = @import("builtin");
const machine = @import("machine.zig");
const linux = std.os.linux;
const is_linux = builtin.os.tag == .linux;

/// the file in the scratch folder a worker's stdout and stderr go to
pub const stdout_name = "stdout";
/// the scratch folder of one job: `<work_dir>/<worker>/job`
pub const scratch_leaf = "job";
pub const max_files: usize = 64;
pub const max_bytes: usize = 16 << 20;

// ---------------------------------------------------------------------------------------------------------
// Landlock's file rules (the uapi's numbers)

const FS_EXECUTE: u64 = 1 << 0;
const FS_WRITE_FILE: u64 = 1 << 1;
const FS_READ_FILE: u64 = 1 << 2;
const FS_READ_DIR: u64 = 1 << 3;
const FS_REMOVE_DIR: u64 = 1 << 4;
const FS_REMOVE_FILE: u64 = 1 << 5;
const FS_MAKE_CHAR: u64 = 1 << 6;
const FS_MAKE_DIR: u64 = 1 << 7;
const FS_MAKE_REG: u64 = 1 << 8;
const FS_MAKE_SOCK: u64 = 1 << 9;
const FS_MAKE_FIFO: u64 = 1 << 10;
const FS_MAKE_BLOCK: u64 = 1 << 11;
const FS_MAKE_SYM: u64 = 1 << 12;
const FS_REFER: u64 = 1 << 13; // ABI 2
const FS_TRUNCATE: u64 = 1 << 14; // ABI 3
const FS_IOCTL_DEV: u64 = 1 << 15; // ABI 5
const NET_BIND_TCP: u64 = 1 << 0; // ABI 4
const NET_CONNECT_TCP: u64 = 1 << 1;
const SCOPE_ABSTRACT_UNIX: u64 = 1 << 0; // ABI 6
const SCOPE_SIGNAL: u64 = 1 << 1;
const RULE_PATH_BENEATH: usize = 1;

/// Every file access this ABI knows: what the rule set HANDLES is what it refuses unless a rule allows it.
fn fsHandled(abi: u32) u64 {
    var a: u64 = FS_EXECUTE | FS_WRITE_FILE | FS_READ_FILE | FS_READ_DIR | FS_REMOVE_DIR | FS_REMOVE_FILE |
        FS_MAKE_CHAR | FS_MAKE_DIR | FS_MAKE_REG | FS_MAKE_SOCK | FS_MAKE_FIFO | FS_MAKE_BLOCK | FS_MAKE_SYM;
    if (abi >= 2) a |= FS_REFER;
    if (abi >= 3) a |= FS_TRUNCATE;
    if (abi >= 5) a |= FS_IOCTL_DEV;
    return a;
}

/// What a worker may do in its scratch folder: read it, and read, write, make and remove the FILES in it. Not
/// execute what it finds there -- the code that runs is the program the declaration names -- not make a folder
/// (a job is flat files, and a tree the worker made is a tree PID 1 would have to walk to remove), and not make
/// a device, a socket, a pipe or a link.
fn scratchAllowed(abi: u32) u64 {
    var a: u64 = FS_WRITE_FILE | FS_READ_FILE | FS_READ_DIR | FS_REMOVE_FILE | FS_MAKE_REG;
    if (abi >= 3) a |= FS_TRUNCATE;
    return a;
}

fn landlockAbi() u32 {
    if (!is_linux) return 0;
    const rc = linux.syscall3(.landlock_create_ruleset, 0, 0, 1);
    return switch (linux.E.init(rc)) {
        .SUCCESS => @intCast(rc),
        else => 0,
    };
}

/// Whether this kernel can hold a worker to its folder: it speaks Landlock at all.
pub fn canHold() bool {
    return landlockAbi() >= 1;
}

fn addBeneath(ruleset: usize, path: [*:0]const u8, allowed: u64, dir: bool) ?[]const u8 {
    var o: linux.O = .{ .PATH = true, .CLOEXEC = true, .NOFOLLOW = true };
    if (dir) o.DIRECTORY = true;
    const fd = linux.openat(linux.AT.FDCWD, path, o, 0);
    if (linux.E.init(fd) != .SUCCESS) return @tagName(linux.E.init(fd));
    defer _ = linux.close(@intCast(fd));
    // struct landlock_path_beneath_attr { __u64 allowed_access; __s32 parent_fd; } __attribute__((packed))
    var attr: [12]u8 = undefined;
    std.mem.writeInt(u64, attr[0..8], allowed, .little);
    std.mem.writeInt(i32, attr[8..12], @intCast(fd), .little);
    const rc = linux.syscall4(.landlock_add_rule, ruleset, RULE_PATH_BENEATH, @intFromPtr(&attr), 0);
    if (linux.E.init(rc) != .SUCCESS) return @tagName(linux.E.init(rc));
    return null;
}

/// Hold the CALLING task to `scratch` (read and write inside it) and `program` (read and execute that one
/// file), and to nothing else of the filesystem; no TCP bind or connect where the kernel can say so, no
/// abstract unix socket and no signal outside its own domain where it can say that. Called in the child after
/// the filter, whose no_new_privs Landlock needs. Null when the kernel holds it; its word otherwise.
pub fn holdToScratch(scratch: [*:0]const u8, program: [*:0]const u8) ?[]const u8 {
    if (!is_linux) return "not linux";
    const abi = landlockAbi();
    if (abi == 0) return "no landlock";
    // struct landlock_ruleset_attr grew with the ABI: fs (1), net (4), scoped (6); the size says which
    var attr = [3]u64{ fsHandled(abi), 0, 0 };
    var size: usize = 8;
    if (abi >= 4) {
        attr[1] = NET_BIND_TCP | NET_CONNECT_TCP;
        size = 16;
    }
    if (abi >= 6) {
        attr[2] = SCOPE_ABSTRACT_UNIX | SCOPE_SIGNAL;
        size = 24;
    }
    const made = linux.syscall3(.landlock_create_ruleset, @intFromPtr(&attr), size, 0);
    if (linux.E.init(made) != .SUCCESS) return @tagName(linux.E.init(made));
    defer _ = linux.close(@intCast(made));
    if (addBeneath(made, scratch, scratchAllowed(abi), true)) |why| return why;
    if (addBeneath(made, program, FS_EXECUTE | FS_READ_FILE, false)) |why| return why;
    const held = linux.syscall2(.landlock_restrict_self, made, 0);
    if (linux.E.init(held) != .SUCCESS) return @tagName(linux.E.init(held));
    return null;
}

// ---------------------------------------------------------------------------------------------------------
// The raw calls, as errors this file names (the standard library calls EINVAL and EBADF `unreachable`, which in
// the ReleaseSafe build PID 1 ships in is a panic where a refusal in a line was owed -- OWN-1)

fn check(rc: usize) !usize {
    return switch (linux.E.init(rc)) {
        .SUCCESS => rc,
        .NOENT => error.FileNotFound,
        .EXIST => error.PathAlreadyExists,
        .LOOP, .MLINK => error.IsALink,
        .NOTDIR => error.NotADirectory,
        .ACCES, .PERM => error.PermissionDenied,
        .NOSPC => error.NoSpaceLeft,
        .NOTEMPTY => error.DirNotEmpty,
        .ISDIR => error.IsADirectory,
        else => error.Unexpected,
    };
}

fn openAt(dir: i32, name: [*:0]const u8, o: linux.O, mode: linux.mode_t) !i32 {
    var flags = o;
    flags.NOFOLLOW = true;
    flags.CLOEXEC = true;
    return @intCast(try check(linux.openat(dir, name, flags, mode)));
}

fn statFd(fd: i32) !linux.Stat {
    var st: linux.Stat = undefined;
    _ = try check(linux.fstat(fd, &st));
    return st;
}

fn z(buf: []u8, a: []const u8, b: []const u8) ![:0]const u8 {
    return std.fmt.bufPrintZ(buf, "{s}{s}", .{ a, b });
}

/// Open the directory at `path` from the root, following no link on the way, and require the last to be
/// `owner`'s. The jobs directory lies in the placer's STATE, so everything at and below that STATE is the
/// placer's to rename, and a link where a directory was would send root's reads and writes elsewhere.
pub fn openOwnedDir(path: []const u8, owner: u32) !i32 {
    var cur: i32 = try openAt(linux.AT.FDCWD, "/", .{ .DIRECTORY = true }, 0);
    errdefer _ = linux.close(cur);
    var parts = std.mem.tokenizeScalar(u8, path, '/');
    var nb: [machine.max_name + 1]u8 = undefined;
    while (parts.next()) |name| {
        const nz = try std.fmt.bufPrintZ(&nb, "{s}", .{name});
        const next = try openAt(cur, nz, .{ .DIRECTORY = true }, 0);
        _ = linux.close(cur);
        cur = next;
    }
    const st = try statFd(cur);
    if (st.uid != owner) return error.NotThePlacers;
    return cur;
}

fn exists(dir: i32, name: [:0]const u8) bool {
    var st: linux.Stat = undefined;
    return linux.E.init(linux.fstatat(dir, name, &st, linux.AT.SYMLINK_NOFOLLOW)) == .SUCCESS;
}

/// The next job placed in the directory `jobs` holds: the smallest id with a `<id>.go` and no `<id>.done`.
/// An id is `machine.jobId`'s; a `.go` whose name is not one is not a job and is left alone.
pub fn nextJob(jobs: i32, buf: []u8) ?[]const u8 {
    var d = std.fs.Dir{ .fd = jobs };
    var it = d.iterate();
    var best: ?[]const u8 = null;
    var hold: [33]u8 = undefined;
    while (it.next() catch null) |e| {
        if (!std.mem.endsWith(u8, e.name, machine.job_go)) continue;
        const id = e.name[0 .. e.name.len - machine.job_go.len];
        if (!machine.jobId(id)) continue;
        var db: [48]u8 = undefined;
        const done = z(&db, id, machine.job_done) catch continue;
        if (exists(jobs, done)) continue;
        if (best == null or std.mem.order(u8, id, best.?) == .lt) {
            @memcpy(hold[0..id.len], id);
            best = hold[0..id.len];
        }
    }
    const b = best orelse return null;
    if (b.len > buf.len) return null;
    @memcpy(buf[0..b.len], b);
    return buf[0..b.len];
}

/// A plain file name a job may carry: the court's plain characters, no dot first, not the floor's own.
pub fn plainName(n: []const u8) bool {
    if (n.len == 0 or n.len > 64 or n[0] == '.') return false;
    if (std.mem.eql(u8, n, stdout_name)) return false;
    for (n) |c| if (!((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '.' or c == '_' or c == '-')) return false;
    return true;
}

pub const Moved = struct { files: usize = 0, bytes: usize = 0, left: usize = 0 };

/// Copy one regular file `owner` owns, with one link, from `from_dir` to a new file in `to_dir` given to
/// `to_uid:to_gid` with mode 0600. Returns its size.
fn copyFile(from_dir: i32, name: [:0]const u8, owner: u32, to_dir: i32, to_name: [:0]const u8, to_uid: u32, to_gid: u32, budget: usize) !usize {
    const src = try openAt(from_dir, name, .{ .NONBLOCK = true }, 0);
    defer _ = linux.close(src);
    const st = try statFd(src);
    if (!linux.S.ISREG(st.mode)) return error.NotARegularFile;
    if (st.uid != owner) return error.NotTheOwners;
    if (st.nlink != 1) return error.IsALink;
    const size: usize = @intCast(st.size);
    if (size > budget) return error.TooLarge;
    const dst = try openAt(to_dir, to_name, .{ .ACCMODE = .WRONLY, .CREAT = true, .EXCL = true }, 0o600);
    defer _ = linux.close(dst);
    _ = try check(linux.fchown(dst, to_uid, to_gid));
    var buf: [16 << 10]u8 = undefined;
    var total: usize = 0;
    while (true) {
        const n = try check(linux.read(src, &buf, buf.len));
        if (n == 0) break;
        total += n;
        if (total > budget) return error.TooLarge;
        var off: usize = 0;
        while (off < n) off += try check(linux.write(dst, buf[off..].ptr, n - off));
    }
    return total;
}

/// Remove everything in the directory `dir` holds, following no link (a link is removed, never entered).
///
/// ONE pass, no recursion and no retry: a worker may make no folder (`scratchAllowed`), so its scratch folder
/// holds files; a folder found inside is removed only if it is empty, and otherwise stays, so that the removal of
/// the folder holding it fails and is said. (The first version recursed and retried until the folder was empty,
/// and a review found that a worker which made a thousand nested folders and changed into each would hold PID 1
/// in that loop for ever, its descriptors spent: a clean-up the cleaned can make endless is a hang of PID 1.)
fn emptyDir(dir: i32) !void {
    var d = std.fs.Dir{ .fd = dir };
    var it = d.iterate();
    var seen: usize = 0;
    while (try it.next()) |e| {
        seen += 1;
        if (seen > 4 * max_files) return error.TooManyFiles;
        var nb: [300]u8 = undefined;
        const nz = std.fmt.bufPrintZ(&nb, "{s}", .{e.name}) catch continue;
        _ = check(linux.unlinkat(dir, nz, if (e.kind == .directory) linux.AT.REMOVEDIR else 0)) catch {};
    }
}

/// Remove what a crash, or the placer, left under one of the names PID 1 makes for a job's answer, so that the
/// O_EXCL that follows is about THIS answer. A name it cannot clear makes the answer fail, and is said.
fn clearLeftover(jobs: i32, name: [:0]const u8) void {
    if (openAt(jobs, name, .{ .DIRECTORY = true }, 0)) |old| {
        emptyDir(old) catch {};
        _ = linux.close(old);
        _ = linux.unlinkat(jobs, name, linux.AT.REMOVEDIR);
    } else |_| {
        _ = linux.unlinkat(jobs, name, 0);
    }
}

/// Make the scratch folder `<parent>/job` for one job afresh -- an earlier one's is emptied and removed first
/// -- give it to the worker, and copy the job's files into it from `<jobs>/<id>/`, which must be the placer's.
/// Makes the worker's `stdout` file too. The scratch descriptor is returned open.
pub fn takeJob(parent: i32, jobs: i32, id: []const u8, placer: u32, worker: *const machine.User) !struct { scratch: i32, moved: Moved } {
    if (openAt(parent, scratch_leaf, .{ .DIRECTORY = true }, 0)) |old| {
        emptyDir(old) catch {};
        _ = linux.close(old);
        _ = try check(linux.unlinkat(parent, scratch_leaf, linux.AT.REMOVEDIR));
    } else |_| {}
    _ = try check(linux.mkdirat(parent, scratch_leaf, 0o700));
    const scratch = try openAt(parent, scratch_leaf, .{ .DIRECTORY = true }, 0);
    errdefer _ = linux.close(scratch);
    _ = try check(linux.fchown(scratch, worker.uid, worker.gid));
    _ = try check(linux.fchmod(scratch, 0o700));
    var ib: [40]u8 = undefined;
    const idz = try std.fmt.bufPrintZ(&ib, "{s}", .{id});
    const src = try openAt(jobs, idz, .{ .DIRECTORY = true }, 0);
    defer _ = linux.close(src);
    if ((try statFd(src)).uid != placer) return error.NotThePlacers;
    var moved = Moved{};
    var d = std.fs.Dir{ .fd = src };
    var it = d.iterate();
    while (try it.next()) |e| {
        if (!plainName(e.name)) return error.NotAPlainName;
        if (moved.files == max_files) return error.TooManyFiles;
        var nb: [80]u8 = undefined;
        const nz = try std.fmt.bufPrintZ(&nb, "{s}", .{e.name});
        moved.bytes += try copyFile(src, nz, placer, scratch, nz, worker.uid, worker.gid, max_bytes - moved.bytes);
        moved.files += 1;
    }
    const out = try openAt(scratch, stdout_name, .{ .ACCMODE = .WRONLY, .CREAT = true, .EXCL = true }, 0o600);
    defer _ = linux.close(out);
    _ = try check(linux.fchown(out, worker.uid, worker.gid));
    return .{ .scratch = scratch, .moved = moved };
}

/// Copy what the worker left in its scratch folder -- the regular files it owns with one link, by plain names,
/// and its `stdout` -- into `<jobs>/<id>.out/`, given to the placer. Made under a name PID 1 creates with
/// O_EXCL and renamed into place; anything else the worker left is counted and not handed back.
pub fn handBack(scratch: i32, jobs: i32, id: []const u8, worker_uid: u32, placer: *const machine.User) !Moved {
    var nb: [64]u8 = undefined;
    var fb: [64]u8 = undefined;
    const tmp = try std.fmt.bufPrintZ(&nb, ".{s}{s}.new", .{ id, machine.job_out });
    const final = try std.fmt.bufPrintZ(&fb, "{s}{s}", .{ id, machine.job_out });
    clearLeftover(jobs, tmp);
    _ = try check(linux.mkdirat(jobs, tmp, 0o700));
    const dst = try openAt(jobs, tmp, .{ .DIRECTORY = true }, 0);
    defer _ = linux.close(dst);
    _ = try check(linux.fchown(dst, placer.uid, placer.gid));
    var moved = Moved{};
    var d = std.fs.Dir{ .fd = scratch };
    var it = d.iterate();
    while (try it.next()) |e| {
        const stdout = std.mem.eql(u8, e.name, stdout_name);
        if (e.kind != .file or (!stdout and !plainName(e.name)) or moved.files == max_files) {
            moved.left += 1;
            continue;
        }
        var eb: [80]u8 = undefined;
        const ez = try std.fmt.bufPrintZ(&eb, "{s}", .{e.name});
        const n = copyFile(scratch, ez, worker_uid, dst, ez, placer.uid, placer.gid, max_bytes - moved.bytes) catch {
            moved.left += 1;
            continue;
        };
        moved.bytes += n;
        moved.files += 1;
    }
    _ = try check(linux.renameat(jobs, tmp, jobs, final));
    return moved;
}

/// What became of a job, in one line, written last: `<id>.done`, made under a name PID 1 creates with O_EXCL,
/// given to the placer, synced and renamed into place, so a placer that sees it sees all of it.
pub fn writeDone(jobs: i32, id: []const u8, line: []const u8, placer: *const machine.User) !void {
    var nb: [64]u8 = undefined;
    var fb: [64]u8 = undefined;
    const tmp = try std.fmt.bufPrintZ(&nb, ".{s}{s}.new", .{ id, machine.job_done });
    const final = try std.fmt.bufPrintZ(&fb, "{s}{s}", .{ id, machine.job_done });
    clearLeftover(jobs, tmp);
    const fd = try openAt(jobs, tmp, .{ .ACCMODE = .WRONLY, .CREAT = true, .EXCL = true }, 0o600);
    defer _ = linux.close(fd);
    _ = try check(linux.fchown(fd, placer.uid, placer.gid));
    var off: usize = 0;
    while (off < line.len) off += try check(linux.write(fd, line[off..].ptr, line.len - off));
    _ = try check(linux.write(fd, "\n", 1));
    _ = linux.fsync(fd);
    _ = try check(linux.renameat(jobs, tmp, jobs, final));
}

/// Empty and remove the scratch folder of the job just ended.
pub fn removeScratch(parent: i32, scratch: i32) void {
    emptyDir(scratch) catch {};
    _ = linux.close(scratch);
    _ = linux.unlinkat(parent, scratch_leaf, linux.AT.REMOVEDIR);
}

/// Remove the scratch folder a job left half made, if there is one.
pub fn clearScratch(parent: i32) void {
    const old = openAt(parent, scratch_leaf, .{ .DIRECTORY = true }, 0) catch return;
    removeScratch(parent, old);
}

/// Make the directory `path` as the machine's -- its parent must exist -- closed to others' writing (0755),
/// and read it back as the caller's, opened from the root with no link followed.
pub fn makeMachineDir(path: []const u8) !void {
    var pb: [machine.max_path + 1]u8 = undefined;
    const pz = try std.fmt.bufPrintZ(&pb, "{s}", .{path});
    _ = check(linux.mkdir(pz, 0o755)) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
    const fd = try openOwnedDir(path, linux.getuid());
    defer _ = linux.close(fd);
    _ = try check(linux.fchmod(fd, 0o755));
}

/// What a person reads when a job could not be taken or handed back.
pub fn reason(e: anyerror) []const u8 {
    return switch (e) {
        error.FileNotFound => "its folder is not there",
        error.IsALink => "a link was found where a file or a folder was (a link is never followed)",
        error.NotADirectory => "a link, or something else that is not a folder, was found where a folder was (a link is never followed)",
        error.NotARegularFile => "it holds something that is not a plain file",
        error.NotTheOwners, error.NotThePlacers => "it holds something the world that placed it does not own",
        error.NotAPlainName => "it holds a name that is not plain (letters, digits, '.', '_', '-', no dot first, not stdout)",
        error.TooManyFiles => "it holds more files than a job may carry (64)",
        error.TooLarge => "it carries more than a job may (16 MiB)",
        error.PathAlreadyExists => "a name the floor makes for it already exists",
        error.NoSpaceLeft => "there is no room left in RAM for it",
        error.PermissionDenied => "the kernel refused (permission denied)",
        else => @errorName(e),
    };
}

// ---------------------------------------------------------------------------------------------------------
// The witnesses

/// `harb job <jobs dir> <id>=<task>...`: the PLACER. For each job in order: make `<id>/` holding one file,
/// `task`, with the words after the `=`; place it (`<id>.go`, last); wait for `<id>.done` (at most 60 s); print
/// what became of it and every line of every file handed back. Exit 0 when every job was answered.
pub fn place(args: []const []const u8, out: *std.Io.Writer) !u8 {
    if (args.len < 2) {
        try out.print("job: takes <jobs dir> <id>=<task>...\n", .{});
        return 2;
    }
    var dir = std.fs.cwd().makeOpenPath(args[0], .{ .iterate = true }) catch |e| {
        try out.print("job: cannot make {s}: {s}\n", .{ args[0], @errorName(e) });
        return 1;
    };
    defer dir.close();
    var answered = true;
    for (args[1..]) |a| {
        const eq = std.mem.indexOfScalar(u8, a, '=') orelse {
            try out.print("job: '{s}' is not <id>=<task>\n", .{a});
            return 2;
        };
        const id = a[0..eq];
        if (!machine.jobId(id)) {
            try out.print("job: '{s}' is not a job id (1 to 32 of a-z, 0-9, '_' and '-')\n", .{id});
            return 2;
        }
        dir.makeDir(id) catch |e| {
            try out.print("job: cannot make {s}/{s}: {s}\n", .{ args[0], id, @errorName(e) });
            return 1;
        };
        var sub = try dir.openDir(id, .{});
        try sub.writeFile(.{ .sub_path = "task", .data = a[eq + 1 ..] });
        sub.close();
        var gb: [48]u8 = undefined;
        try dir.writeFile(.{ .sub_path = try std.fmt.bufPrint(&gb, "{s}{s}", .{ id, machine.job_go }), .data = "" });
        try out.print("job: {s} -- placed: {s}\n", .{ id, a[eq + 1 ..] });
        try out.flush();
        var db: [48]u8 = undefined;
        const done_name = try std.fmt.bufPrint(&db, "{s}{s}", .{ id, machine.job_done });
        var waited: u32 = 0;
        const done = while (waited < 600) : (waited += 1) {
            if (dir.readFileAlloc(std.heap.page_allocator, done_name, 4096)) |t| break t else |_| {}
            std.Thread.sleep(100 * std.time.ns_per_ms);
        } else null;
        const text = done orelse {
            try out.print("job: {s} -- NO ANSWER after 60 s\n", .{id});
            answered = false;
            continue;
        };
        try out.print("job: {s} -- {s}\n", .{ id, std.mem.trimRight(u8, text, "\n") });
        var ob: [48]u8 = undefined;
        var back = dir.openDir(try std.fmt.bufPrint(&ob, "{s}{s}", .{ id, machine.job_out }), .{ .iterate = true }) catch continue;
        defer back.close();
        var names: std.ArrayList([]const u8) = .{};
        var it = back.iterate();
        while (try it.next()) |e| try names.append(std.heap.page_allocator, try std.heap.page_allocator.dupe(u8, e.name));
        std.mem.sort([]const u8, names.items, {}, struct {
            fn lt(_: void, x: []const u8, y: []const u8) bool {
                return std.mem.order(u8, x, y) == .lt;
            }
        }.lt);
        for (names.items) |n| {
            if (std.mem.eql(u8, n, "task")) continue; // what it was given, not what it did
            const body = back.readFileAlloc(std.heap.page_allocator, n, 1 << 16) catch continue;
            if (body.len == 0) {
                try out.print("job: {s} -- {s}: (empty)\n", .{ id, n });
                continue;
            }
            var lines = std.mem.splitScalar(u8, std.mem.trimRight(u8, body, "\n"), '\n');
            while (lines.next()) |l| try out.print("job: {s} -- {s}: {s}\n", .{ id, n, l });
        }
    }
    return if (answered) 0 else 1;
}

fn sayOpen(w: *std.Io.Writer, what: []const u8, rc: usize, want_refused: bool, wrong: *bool) !void {
    const e = linux.E.init(rc);
    if (e == .SUCCESS) {
        _ = linux.close(@intCast(rc));
        if (want_refused) wrong.* = true;
        try w.print("{s} -- {s}\n", .{ what, if (want_refused) "ALLOWED" else "allowed" });
    } else {
        if (!want_refused) wrong.* = true;
        try w.print("{s} -- refused ({s})\n", .{ what, @tagName(e) });
    }
}

/// `harb untrusted`: the WORKER the witness machine runs, standing in for code nobody vouched for. It reads
/// `task` in its folder: `probe` asks the kernel, from inside, for everything a worker must be refused and the
/// two things it must be let do, and writes the answers to `report` (exit 1 on a wrong one); `spin` runs until
/// it is ended; `eat` asks for memory until the kernel ends it. It prints one line, which must land in its
/// `stdout` file and never on the console.
pub fn untrusted(out: *std.Io.Writer) !u8 {
    if (!is_linux) {
        try out.print("untrusted: a Linux act\n", .{});
        return 2;
    }
    try out.print("untrusted: this line is the worker's own, and it is written to a file in its folder, not to the console\n", .{});
    try out.flush();
    var tb: [64]u8 = undefined;
    const task = std.mem.trim(u8, std.fs.cwd().readFile("task", &tb) catch "probe", " \n");
    if (std.mem.eql(u8, task, "spin")) {
        var x: u64 = 0;
        while (true) x +%= 1;
    }
    if (std.mem.eql(u8, task, "eat")) {
        var held: usize = 0;
        while (true) {
            const p = std.heap.page_allocator.alloc(u8, 4 << 20) catch break;
            @memset(p, 0xa5);
            held += p.len;
        }
        return 3; // the kernel refused memory instead of ending it: said by the exit
    }
    var rb: [2048]u8 = undefined;
    var w = std.Io.Writer.fixed(&rb);
    var wrong = false;
    // what is in its folder BEFORE it has made anything: a job starts in a new one, so it holds the job's
    // files and the worker's stdout and nothing an earlier job left -- asked first, or the listing would
    // show what this job made and prove nothing
    var names: [16][]const u8 = undefined;
    var nn: usize = 0;
    var store: [512]u8 = undefined;
    var used: usize = 0;
    var d = std.fs.cwd().openDir(".", .{ .iterate = true }) catch null;
    if (d) |*dd| {
        defer dd.close();
        var it = dd.iterate();
        while (it.next() catch null) |e| {
            if (nn == names.len or used + e.name.len > store.len) break;
            @memcpy(store[used..][0..e.name.len], e.name);
            names[nn] = store[used..][0..e.name.len];
            used += e.name.len;
            nn += 1;
        }
    }
    std.mem.sort([]const u8, names[0..nn], {}, struct {
        fn lt(_: void, x: []const u8, y: []const u8) bool {
            return std.mem.order(u8, x, y) == .lt;
        }
    }.lt);
    try w.print("its folder holds, when it starts:", .{});
    for (names[0..nn]) |n| try w.print(" {s}", .{n});
    try w.print("\n", .{});
    if (nn != 2 or !std.mem.eql(u8, names[0], stdout_name) or !std.mem.eql(u8, names[1], "task")) wrong = true;
    const fams = [_]struct { name: []const u8, af: u32 }{
        .{ .name = "a unix socket", .af = linux.AF.UNIX },
        .{ .name = "an inet socket", .af = linux.AF.INET },
        .{ .name = "a netlink socket", .af = linux.AF.NETLINK },
    };
    for (fams) |f| try sayOpen(&w, f.name, linux.socket(f.af, linux.SOCK.DGRAM | linux.SOCK.CLOEXEC, 0), true, &wrong);
    var pair: [2]i32 = undefined;
    try sayOpen(&w, "a socket pair", linux.socketpair(linux.AF.UNIX, linux.SOCK.STREAM, 0, &pair), true, &wrong);
    try sayOpen(&w, "read /etc/machine", linux.openat(linux.AT.FDCWD, "/etc/machine", .{}, 0), true, &wrong);
    try sayOpen(&w, "list /", linux.openat(linux.AT.FDCWD, "/", .{ .DIRECTORY = true }, 0), true, &wrong);
    try sayOpen(&w, "make /run/escape", linux.openat(linux.AT.FDCWD, "/run/escape", .{ .ACCMODE = .WRONLY, .CREAT = true }, 0o600), true, &wrong);
    const forked = linux.fork();
    if (forked == 0) linux.exit(0);
    if (linux.E.init(forked) == .SUCCESS) {
        wrong = true;
        try w.print("start a process -- ALLOWED\n", .{});
    } else try w.print("start a process -- refused ({s})\n", .{@tagName(linux.E.init(forked))});
    try sayOpen(&w, "read its task", linux.openat(linux.AT.FDCWD, "task", .{}, 0), false, &wrong);
    try sayOpen(&w, "make a file in its folder", linux.openat(linux.AT.FDCWD, "left", .{ .ACCMODE = .WRONLY, .CREAT = true }, 0o600), false, &wrong);
    // a folder in its folder: a job is flat files, and a tree is something PID 1 would have to walk to remove
    const md = linux.mkdir("sub", 0o700);
    if (linux.E.init(md) == .SUCCESS) {
        wrong = true;
        try w.print("make a folder in its folder -- ALLOWED\n", .{});
    } else try w.print("make a folder in its folder -- refused ({s})\n", .{@tagName(linux.E.init(md))});
    try w.print("{s}\n", .{if (wrong) "AN ANSWER WAS NOT THE ONE A WORKER MUST GET" else "every answer was the one a worker must get"});
    std.fs.cwd().writeFile(.{ .sub_path = "report", .data = w.buffered() }) catch return 1;
    return if (wrong) 1 else 0;
}

// ---------------------------------------------------------------------------------------------------------
// Tests

const testing = std.testing;

test "a job's names are plain, and the floor's own name is not a job's (WORKER-1)" {
    try testing.expect(plainName("task"));
    try testing.expect(plainName("input.json"));
    try testing.expect(!plainName("stdout"));
    try testing.expect(!plainName(".hidden"));
    try testing.expect(!plainName("a/b"));
    try testing.expect(!plainName(""));
    try testing.expect(machine.jobId("a1"));
    try testing.expect(!machine.jobId("A1"));
    try testing.expect(!machine.jobId("a.1"));
    try testing.expect(!machine.jobId(""));
}

test "the scratch folder allows no execution, no folder, and no device, socket, pipe or link (WORKER-1)" {
    for ([_]u32{ 1, 2, 3, 5, 6 }) |abi| {
        const a = scratchAllowed(abi);
        try testing.expect(a & FS_EXECUTE == 0);
        try testing.expect(a & (FS_MAKE_CHAR | FS_MAKE_BLOCK | FS_MAKE_SOCK | FS_MAKE_FIFO | FS_MAKE_SYM | FS_MAKE_DIR | FS_REMOVE_DIR | FS_REFER) == 0);
        try testing.expect(a & FS_WRITE_FILE != 0 and a & FS_READ_FILE != 0);
        // nothing allowed that the rule set does not handle: an allowed right it does not handle is refused by the kernel
        try testing.expectEqual(a, a & fsHandled(abi));
    }
}

/// A test directory under the system's temporary one, opened from the root with no link followed.
fn tmpRoot(buf: []u8) ![]const u8 {
    const p = try std.fmt.bufPrint(buf, "/tmp/harb-work-test-{d}", .{linux.getpid()});
    std.fs.deleteTreeAbsolute(p) catch {};
    try std.fs.makeDirAbsolute(p);
    return p;
}

test "a job is copied in from the placer's folder, and what the worker left is handed back (WORKER-1)" {
    if (!is_linux) return error.SkipZigTest;
    var pb: [64]u8 = undefined;
    const root = try tmpRoot(&pb);
    defer std.fs.deleteTreeAbsolute(root) catch {};
    const me = linux.getuid();
    const u = machine.User{ .name = "me", .uid = me, .gid = linux.getgid(), .line = 0, .rationale = "" };
    var r = try std.fs.openDirAbsolute(root, .{});
    defer r.close();
    try r.makePath("jobs/a1");
    try r.writeFile(.{ .sub_path = "jobs/a1/task", .data = "probe" });
    try r.writeFile(.{ .sub_path = "jobs/a1.go", .data = "" });
    try r.makePath("work");
    var jb: [96]u8 = undefined;
    const jobs = try openOwnedDir(try std.fmt.bufPrint(&jb, "{s}/jobs", .{root}), me);
    defer _ = linux.close(jobs);
    var idb: [33]u8 = undefined;
    const id = nextJob(jobs, &idb).?;
    try testing.expectEqualStrings("a1", id);
    var wb: [96]u8 = undefined;
    const parent = try openOwnedDir(try std.fmt.bufPrint(&wb, "{s}/work", .{root}), me);
    defer _ = linux.close(parent);
    const taken = try takeJob(parent, jobs, id, me, &u);
    try testing.expectEqual(@as(usize, 1), taken.moved.files);
    // the worker writes a result, and leaves a link, which is not handed back
    var s = std.fs.Dir{ .fd = taken.scratch };
    try s.writeFile(.{ .sub_path = "result", .data = "42" });
    try s.symLink("/etc/passwd", "sneak", .{});
    const back = try handBack(taken.scratch, jobs, id, me, &u);
    try testing.expectEqual(@as(usize, 3), back.files); // task, result, stdout
    try testing.expectEqual(@as(usize, 1), back.left);
    try writeDone(jobs, id, "exited 0", &u);
    removeScratch(parent, taken.scratch);
    try testing.expectEqualStrings("42", try r.readFile("jobs/a1.out/result", &idb));
    try testing.expectEqualStrings("exited 0\n", try r.readFile("jobs/a1.done", &idb));
    try testing.expectError(error.FileNotFound, r.access("work/job", .{}));
    // answered: the job is not taken again
    try testing.expect(nextJob(jobs, &idb) == null);
}

test "what a crash or the placer left under an answer's names does not stop the answer (WORKER-1)" {
    if (!is_linux) return error.SkipZigTest;
    var pb: [64]u8 = undefined;
    const root = try tmpRoot(&pb);
    defer std.fs.deleteTreeAbsolute(root) catch {};
    const me = linux.getuid();
    const u = machine.User{ .name = "me", .uid = me, .gid = linux.getgid(), .line = 0, .rationale = "" };
    var r = try std.fs.openDirAbsolute(root, .{});
    defer r.close();
    try r.makePath("jobs/a1");
    try r.writeFile(.{ .sub_path = "jobs/a1/task", .data = "probe" });
    try r.makePath("work");
    // the names PID 1 makes for the answer, left behind: a file where the folder goes, a link where the line goes
    try r.writeFile(.{ .sub_path = "jobs/.a1.out.new", .data = "left by a crash" });
    try r.symLink("/etc/passwd", "jobs/.a1.done.new", .{});
    var jb: [96]u8 = undefined;
    const jobs = try openOwnedDir(try std.fmt.bufPrint(&jb, "{s}/jobs", .{root}), me);
    defer _ = linux.close(jobs);
    var wb: [96]u8 = undefined;
    const parent = try openOwnedDir(try std.fmt.bufPrint(&wb, "{s}/work", .{root}), me);
    defer _ = linux.close(parent);
    const taken = try takeJob(parent, jobs, "a1", me, &u);
    _ = try handBack(taken.scratch, jobs, "a1", me, &u);
    try writeDone(jobs, "a1", "exited 0", &u);
    removeScratch(parent, taken.scratch);
    var buf: [64]u8 = undefined;
    try testing.expectEqualStrings("exited 0\n", try r.readFile("jobs/a1.done", &buf));
    // ... and the link was removed, never written through
    try testing.expect(!std.mem.eql(u8, (try std.fs.cwd().readFile("/etc/passwd", &buf))[0..8], "exited 0"));
}

test "a job that holds a link, a hard link or a folder is refused, and a link above the jobs is never followed (WORKER-1)" {
    if (!is_linux) return error.SkipZigTest;
    var pb: [64]u8 = undefined;
    const root = try tmpRoot(&pb);
    defer std.fs.deleteTreeAbsolute(root) catch {};
    const me = linux.getuid();
    const u = machine.User{ .name = "me", .uid = me, .gid = linux.getgid(), .line = 0, .rationale = "" };
    var r = try std.fs.openDirAbsolute(root, .{});
    defer r.close();
    try r.makePath("jobs/l1");
    try r.symLink("/etc/hostname", "jobs/l1/task", .{});
    try r.makePath("jobs/h1");
    try r.writeFile(.{ .sub_path = "secret", .data = "the machine's key" });
    try std.posix.linkat(r.fd, "secret", r.fd, "jobs/h1/task", 0);
    try r.makePath("jobs/d1/sub");
    try r.makePath("work");
    var jb: [96]u8 = undefined;
    const jobs = try openOwnedDir(try std.fmt.bufPrint(&jb, "{s}/jobs", .{root}), me);
    defer _ = linux.close(jobs);
    var wb: [96]u8 = undefined;
    const parent = try openOwnedDir(try std.fmt.bufPrint(&wb, "{s}/work", .{root}), me);
    defer _ = linux.close(parent);
    try testing.expectError(error.IsALink, takeJob(parent, jobs, "l1", me, &u));
    try testing.expectError(error.IsALink, takeJob(parent, jobs, "h1", me, &u));
    try testing.expectError(error.NotARegularFile, takeJob(parent, jobs, "d1", me, &u));
    // a jobs directory reached through a link is refused before anything is read
    try r.symLink("jobs", "via", .{});
    var vb: [96]u8 = undefined;
    // (a link opened as a directory with no link followed is answered ENOTDIR by the kernel, not ELOOP)
    try testing.expectError(error.NotADirectory, openOwnedDir(try std.fmt.bufPrint(&vb, "{s}/via", .{root}), me));
    // and one somebody else owns is not the placer's
    try testing.expectError(error.NotThePlacers, openOwnedDir("/", me +% 1));
}

/// What a child answers when held to a scratch folder and its own program: 0 when it may write in the folder
/// and read the program, and is refused another file, the folder above and a file it would make outside;
/// 4 when the kernel speaks no Landlock here; 1 when the rule set did not hold.
fn childHeldToScratch(scratch: [*:0]const u8) u8 {
    if (!canHold()) return 4;
    _ = linux.prctl(@intFromEnum(linux.PR.SET_NO_NEW_PRIVS), 1, 0, 0, 0);
    var exe: [256]u8 = undefined;
    const self = std.fs.selfExePath(&exe) catch return 4;
    exe[self.len] = 0;
    if (holdToScratch(scratch, @ptrCast(exe[0..self.len :0])) != null) return 1;
    var pb: [160]u8 = undefined;
    const inside = std.fmt.bufPrintZ(&pb, "{s}/made", .{std.mem.span(scratch)}) catch return 1;
    const made = linux.openat(linux.AT.FDCWD, inside, .{ .ACCMODE = .WRONLY, .CREAT = true }, 0o600);
    if (linux.E.init(made) != .SUCCESS) return 1;
    if (linux.E.init(linux.openat(linux.AT.FDCWD, @ptrCast(exe[0..self.len :0]), .{}, 0)) != .SUCCESS) return 1;
    if (linux.E.init(linux.openat(linux.AT.FDCWD, "/etc/passwd", .{}, 0)) == .SUCCESS) return 1;
    if (linux.E.init(linux.openat(linux.AT.FDCWD, "/tmp", .{ .DIRECTORY = true }, 0)) == .SUCCESS) return 1;
    if (linux.E.init(linux.openat(linux.AT.FDCWD, "/tmp/harb-escape", .{ .ACCMODE = .WRONLY, .CREAT = true }, 0o600)) == .SUCCESS) return 1;
    return 0;
}

test "a worker held to its folder writes there and is refused every other file, by the kernel (WORKER-1)" {
    if (!is_linux) return error.SkipZigTest;
    var pb: [64]u8 = undefined;
    const root = try tmpRoot(&pb);
    defer std.fs.deleteTreeAbsolute(root) catch {};
    var sb: [96]u8 = undefined;
    const scratch = try std.fmt.bufPrintZ(&sb, "{s}", .{root});
    const pid = try std.posix.fork();
    if (pid == 0) linux.exit(childHeldToScratch(scratch));
    var status: u32 = 0;
    _ = linux.wait4(pid, &status, 0, null);
    if (status & 0x7f != 0) return error.ChildKilled;
    const answer: u8 = @intCast((status >> 8) & 0xff);
    if (answer == 4) return error.SkipZigTest;
    try testing.expectEqual(@as(u8, 0), answer);
    std.fs.deleteFileAbsolute("/tmp/harb-escape") catch {};
}
