//! advisories.zig -- which kernel advisories reach THIS machine (ONEHOUR-1, HAROBANDA-ONEHOUR-01).
//!
//! The kernel's own numbering authority publishes a record for every flaw it fixes (CVE JSON 5): the
//! releases that carry the flaw and the ones that carry its fix, and the source files the fix touched
//! (`programFiles`). Most of them do not reach a given machine, and reading them all is how a team learns to
//! read none. A machine here is built from a kernel fragment that asks for what its declaration needs and
//! nothing else, so most of the kernel is not in it -- and which source files ARE in it is a question the
//! build already answered: `experiment/kernel_sources.py` lists every file an object of the kernel was
//! compiled from, into `kernel.sources` beside the image.
//!
//! So an advisory REACHES a machine when the machine's kernel release is one the record says is affected
//! AND one of the files the record names was compiled into that kernel. Each record gets one line, in the
//! key=value shape of a ledger:
//!
//!   reaches      the release is affected, and a named file is in this kernel
//!   fixed        the release is one the record says is not affected (the fix is in it, or the flaw came later)
//!   not-built    the release is affected, and no file the record names is in this kernel
//!   cannot-tell  the record does not say enough to answer: no file named, no release range that a release
//!                number can be compared with (a range in git commits only), or two ranges that disagree
//!   not-kernel   the record is not about the Linux kernel
//!   rejected     the record was withdrawn by its authority
//!
//! "cannot-tell" is never silence: it is printed beside "reaches", and either one makes the verb exit 1. A
//! machine nothing reaches exits 0.
//!
//! The list is refused when it is not THIS machine's kernel: it carries the name of the build it was read
//! from, `<release>-<12 hex>`, which is the release of the kernel pin (`vendor/PIN.md`) and the digest of the
//! options of the fragment the declaration derives TODAY (`image.kernelFragment`, the same text `harb image`
//! writes, and the same digest `os2_image.sh` keys its build directory by). A list from before the pin moved,
//! or from before the declaration changed what its kernel needs, names another build, and the verb says so
//! and answers nothing: an answer about a kernel the machine no longer gets is the wrong answer with full
//! confidence (MNT-1).
//!
//! What it does not do, and says. It does not fetch: the records are BROUGHT, a directory of `.json` files
//! or one file, by whoever reads the advisories -- the floor reaches nothing it was not declared to. "Built"
//! is "compiled": an object compiled into the kernel is taken to be linked into it, which holds for a build
//! with no modules (tinyconfig plus the fragment, `CONFIG_MODULES` off) and is not otherwise checked. The
//! files a record names are the files its FIX touched, which is where the flaw is in every record the kernel's
//! authority writes, and is the record's word: a flaw whose path runs through a file the fix did not change is
//! not seen. And a release range is compared by its numbers: a range given only in git commits is
//! cannot-tell, because a pin is a release and not a commit.

const std = @import("std");
const machine = @import("machine.zig");
const image = @import("image.zig");

pub const Verdict = enum {
    reaches,
    cannot_tell,
    not_built,
    fixed,
    not_kernel,
    rejected,

    pub fn word(v: Verdict) []const u8 {
        return switch (v) {
            .reaches => "reaches",
            .cannot_tell => "cannot-tell",
            .not_built => "not-built",
            .fixed => "fixed",
            .not_kernel => "not-kernel",
            .rejected => "rejected",
        };
    }
};

// ---------------------------------------------------------------------------------------------------------
// Releases

/// A kernel release as a record writes it: up to five numbers, and an `-rcN` that comes before the release
/// it names ("6.13-rc1" < "6.13").
pub const Release = struct {
    nums: [5]u32 = .{ 0, 0, 0, 0, 0 },
    len: usize = 0,
    rc: ?u32 = null,

    pub fn parse(s: []const u8) ?Release {
        var r = Release{};
        var main_part = s;
        if (std.mem.indexOf(u8, s, "-rc")) |i| {
            r.rc = std.fmt.parseInt(u32, s[i + 3 ..], 10) catch return null;
            main_part = s[0..i];
        }
        if (main_part.len == 0) return null;
        var it = std.mem.splitScalar(u8, main_part, '.');
        while (it.next()) |part| {
            if (r.len == r.nums.len) return null;
            if (part.len == 0) return null;
            for (part) |c| if (c < '0' or c > '9') return null;
            r.nums[r.len] = std.fmt.parseInt(u32, part, 10) catch return null;
            r.len += 1;
        }
        return r;
    }

    pub fn order(a: Release, b: Release) std.math.Order {
        for (0..a.nums.len) |i| {
            const o = std.math.order(a.nums[i], b.nums[i]);
            if (o != .eq) return o;
        }
        if (a.rc == null and b.rc == null) return .eq;
        if (a.rc == null) return .gt;
        if (b.rc == null) return .lt;
        return std.math.order(a.rc.?, b.rc.?);
    }
};

/// Whether release `v` falls in one entry of a record's `versions`, or null when the entry cannot be read as
/// a release range (a git commit, a value that is not a release): such an entry is not compared at all.
fn entryHolds(v: Release, e: std.json.ObjectMap) ?bool {
    if (e.get("versionType")) |t| {
        if (t != .string) return null;
        const ty = t.string;
        if (!(std.mem.eql(u8, ty, "semver") or std.mem.eql(u8, ty, "custom") or std.mem.eql(u8, ty, "original_commit_for_fix"))) return null;
    }
    const from_v = e.get("version") orelse return null;
    if (from_v != .string) return null;
    const from = Release.parse(from_v.string) orelse return null;
    if (e.get("lessThan")) |lt_v| {
        if (lt_v != .string) return null;
        const lt = Release.parse(lt_v.string) orelse return null;
        return v.order(from) != .lt and v.order(lt) == .lt;
    }
    if (e.get("lessThanOrEqual")) |le_v| {
        if (le_v != .string) return null;
        const le = le_v.string;
        if (v.order(from) == .lt) return false;
        if (std.mem.eql(u8, le, "*")) return true;
        if (std.mem.endsWith(u8, le, ".*")) {
            // a branch: "6.12.*" is every release whose first numbers are 6 and 12
            const branch = Release.parse(le[0 .. le.len - 2]) orelse return null;
            for (0..branch.len) |i| if (v.nums[i] != branch.nums[i]) return false;
            return true;
        }
        const top = Release.parse(le) orelse return null;
        return v.order(top) != .gt;
    }
    // a single release, exactly
    return v.order(from) == .eq;
}

/// What an element says of a release: its word, or that it cannot say -- no entry a release can be compared
/// with (git commits only, or an entry that cannot be read), or entries that hold the release and disagree.
const Status = enum { affected, unaffected, unknown, incomparable, disagree };

fn statusWord(s: []const u8) ?Status {
    if (std.mem.eql(u8, s, "affected")) return .affected;
    if (std.mem.eql(u8, s, "unaffected")) return .unaffected;
    if (std.mem.eql(u8, s, "unknown")) return .unknown;
    return null;
}

/// What one `affected` element of a record says of release `v`: the status of the entries that hold it, or
/// its `defaultStatus` when none does.
fn elementStatus(v: Release, el: std.json.ObjectMap) Status {
    const versions = el.get("versions") orelse return .incomparable;
    if (versions != .array) return .incomparable;
    var comparable = false;
    var found: ?Status = null;
    for (versions.array.items) |item| {
        if (item != .object) continue;
        const holds = entryHolds(v, item.object) orelse continue;
        comparable = true;
        if (!holds) continue;
        const st_v = item.object.get("status") orelse return .incomparable;
        if (st_v != .string) return .incomparable;
        const st = statusWord(st_v.string) orelse return .incomparable;
        if (found) |f| {
            if (f != st) return .disagree;
        }
        found = st;
    }
    if (!comparable) return .incomparable;
    if (found) |f| return f;
    const d = el.get("defaultStatus") orelse return .unknown;
    if (d != .string) return .incomparable;
    return statusWord(d.string) orelse .incomparable;
}

// ---------------------------------------------------------------------------------------------------------
// The machine's kernel

/// The release the kernel pin names, read from the `tarball` row of `vendor/PIN.md` -- the row the fetch
/// itself reads, so the two cannot name different kernels.
pub fn pinnedRelease(pin_md: []const u8) ?[]const u8 {
    var it = std.mem.splitScalar(u8, pin_md, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        const prefix = "| tarball | `linux-";
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        const rest = line[prefix.len..];
        const end = std.mem.indexOf(u8, rest, ".tar.xz`") orelse return null;
        const rel = rest[0..end];
        _ = Release.parse(rel) orelse return null;
        return rel;
    }
    return null;
}

/// The name of the build a machine's kernel is: the pinned release and the first 12 hex of the sha256 of the
/// fragment's OPTION lines -- `CONFIG_X=...` and `# CONFIG_X is not set`, each with its line end -- which is
/// exactly what `os2_image.sh` hashes to key its build directory (its comment line names the machine file, so
/// two machines asking for the same options share one build).
pub fn buildName(arena: std.mem.Allocator, release: []const u8, fragment: []const u8) ![]const u8 {
    var h = std.crypto.hash.sha2.Sha256.init(.{});
    var it = std.mem.splitScalar(u8, fragment, '\n');
    while (it.next()) |line| {
        if (isOptionLine(line)) {
            h.update(line);
            h.update("\n");
        }
    }
    var d: [32]u8 = undefined;
    h.final(&d);
    const hex = std.fmt.bytesToHex(d, .lower);
    return std.fmt.allocPrint(arena, "{s}-{s}", .{ release, hex[0..12] });
}

fn isConfigName(s: []const u8) bool {
    if (!std.mem.startsWith(u8, s, "CONFIG_") or s.len == "CONFIG_".len) return false;
    for (s["CONFIG_".len..]) |c| {
        if (!((c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_')) return false;
    }
    return true;
}

fn isOptionLine(line: []const u8) bool {
    if (std.mem.indexOfScalar(u8, line, '=')) |i| {
        if (isConfigName(line[0..i])) return true;
    }
    if (std.mem.startsWith(u8, line, "# ") and std.mem.endsWith(u8, line, " is not set")) {
        return isConfigName(line[2 .. line.len - " is not set".len]);
    }
    return false;
}

pub const Sources = struct {
    build: []const u8,
    files: std.StringHashMapUnmanaged(void),
};

pub const SourcesError = struct { line: usize = 0, why: []const u8 = "" };

/// A `kernel.sources` file, read strictly: its header, its build line, then one path a line, sorted and unique.
pub fn parseSources(arena: std.mem.Allocator, text: []const u8, err: *SourcesError) !?Sources {
    var it = std.mem.splitScalar(u8, text, '\n');
    var n: usize = 0;
    var s = Sources{ .build = "", .files = .{} };
    var prev: ?[]const u8 = null;
    while (it.next()) |line| {
        n += 1;
        if (line.len == 0) {
            if (it.peek() == null) break;
            err.* = .{ .line = n, .why = "an empty line" };
            return null;
        }
        if (n == 1) {
            if (!std.mem.eql(u8, line, "harb kernel sources v1")) {
                err.* = .{ .line = n, .why = "not `harb kernel sources v1`" };
                return null;
            }
            continue;
        }
        if (n == 2) {
            if (!std.mem.startsWith(u8, line, "build ") or line.len == "build ".len) {
                err.* = .{ .line = n, .why = "not `build <release>-<12 hex>`" };
                return null;
            }
            s.build = line["build ".len..];
            continue;
        }
        if (std.mem.indexOfAny(u8, line, " \t\r") != null or line[0] == '/') {
            err.* = .{ .line = n, .why = "a path with a space or a leading /" };
            return null;
        }
        if (prev) |p| if (std.mem.order(u8, p, line) != .lt) {
            err.* = .{ .line = n, .why = "a path out of order or twice" };
            return null;
        };
        prev = line;
        try s.files.put(arena, line, {});
    }
    if (n < 3 or s.files.count() == 0) {
        err.* = .{ .line = n, .why = "no file listed" };
        return null;
    }
    return s;
}

// ---------------------------------------------------------------------------------------------------------
// One record

pub const Answer = struct {
    id: []const u8,
    verdict: Verdict,
    /// the files the record names, and those of them compiled into this kernel
    named: []const []const u8 = &.{},
    built: []const []const u8 = &.{},
    why: []const u8 = "",
};

fn isLinux(el: std.json.ObjectMap) bool {
    const vendor = el.get("vendor") orelse return false;
    const product = el.get("product") orelse return false;
    if (vendor != .string or product != .string) return false;
    if (!std.ascii.eqlIgnoreCase(vendor.string, "linux")) return false;
    return std.ascii.eqlIgnoreCase(product.string, "linux") or std.ascii.eqlIgnoreCase(product.string, "kernel");
}

fn field(v: std.json.Value, name: []const u8) ?std.json.Value {
    if (v != .object) return null;
    return v.object.get(name);
}

/// The answer one CVE record gives for a kernel of release `rel` built from the files in `src`. An error
/// return means the text is not a CVE record at all, which refuses the run: a judge that skips what it
/// cannot read is green for the wrong reason.
pub fn judge(arena: std.mem.Allocator, text: []const u8, rel: Release, src: *const Sources) !Answer {
    const root = std.json.parseFromSliceLeaky(std.json.Value, arena, text, .{}) catch return error.NotJson;
    const meta = field(root, "cveMetadata") orelse return error.NotACveRecord;
    const id_v = field(meta, "cveId") orelse return error.NotACveRecord;
    if (id_v != .string) return error.NotACveRecord;
    const id = id_v.string;
    if (field(meta, "state")) |st| {
        if (st == .string and std.mem.eql(u8, st.string, "REJECTED")) return .{ .id = id, .verdict = .rejected };
    }
    const cna = field(field(root, "containers") orelse return error.NotACveRecord, "cna") orelse return error.NotACveRecord;
    const affected = field(cna, "affected") orelse return .{ .id = id, .verdict = .not_kernel };
    if (affected != .array) return error.NotACveRecord;

    var named: std.ArrayList([]const u8) = .{};
    var any_linux = false;
    var any_affected = false;
    var any_unaffected = false;
    var any_incomparable = false;
    var any_unknown = false;
    var any_disagree = false;
    for (affected.array.items) |el| {
        if (el != .object or !isLinux(el.object)) continue;
        any_linux = true;
        if (el.object.get("programFiles")) |pf| if (pf == .array) for (pf.array.items) |f| {
            if (f != .string) continue;
            for (named.items) |have| {
                if (std.mem.eql(u8, have, f.string)) break;
            } else try named.append(arena, f.string);
        };
        switch (elementStatus(rel, el.object)) {
            .affected => any_affected = true,
            .unaffected => any_unaffected = true,
            .unknown => any_unknown = true,
            .incomparable => any_incomparable = true,
            .disagree => any_disagree = true,
        }
    }
    if (!any_linux) return .{ .id = id, .verdict = .not_kernel };
    std.mem.sort([]const u8, named.items, {}, lessThan);
    var built: std.ArrayList([]const u8) = .{};
    for (named.items) |f| if (src.files.contains(f)) try built.append(arena, f);
    var a = Answer{ .id = id, .verdict = .cannot_tell, .named = named.items, .built = built.items };
    // an element that cannot be compared (git commits only) says nothing either way; the ones that can are
    // the record's word, and two of them that disagree are not resolved here
    if (any_disagree or (any_affected and any_unaffected)) {
        a.why = "its release ranges disagree";
        return a;
    }
    if (any_unaffected) {
        a.verdict = .fixed;
        return a;
    }
    if (!any_affected) {
        a.why = if (any_unknown) "it says this release's status is unknown" else if (any_incomparable) "it gives no release range a release number can be compared with" else "it says nothing of this release";
        return a;
    }
    if (named.items.len == 0) {
        a.why = "it names no file";
        return a;
    }
    a.verdict = if (built.items.len > 0) .reaches else .not_built;
    return a;
}

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}

fn writeList(out: *std.Io.Writer, items: []const []const u8) !void {
    if (items.len == 0) return out.writeAll("none");
    for (items, 0..) |f, i| {
        if (i > 0) try out.writeAll(",");
        try out.writeAll(f);
    }
}

/// One ledger-shaped line: every field a key, nothing that needs a parser of prose.
pub fn ledgerLine(out: *std.Io.Writer, a: Answer, release: []const u8, build: []const u8) !void {
    try out.print("advisory id={s} verdict={s} kernel={s} build={s}", .{ a.id, a.verdict.word(), release, build });
    if (a.verdict != .not_kernel and a.verdict != .rejected) {
        try out.writeAll(" named=");
        try writeList(out, a.named);
        try out.writeAll(" built=");
        try writeList(out, a.built);
    }
    if (a.why.len > 0) try out.print(" why=\"{s}\"", .{a.why});
    try out.writeAll("\n");
}

// ---------------------------------------------------------------------------------------------------------
// The verb

pub const Options = struct {
    machine_path: []const u8,
    records: []const u8,
    sources: ?[]const u8 = null,
    pin: []const u8 = "vendor/PIN.md",
    all: bool = false,
};

pub fn run(arena: std.mem.Allocator, m: *const machine.Machine, o: Options, out: *std.Io.Writer) !u8 {
    const frag = (try image.kernelFragment(arena, m, o.machine_path)) orelse {
        try out.print("advisories: {s} has no kernel built here -- only a hosted machine with one disk is imaged by harb image; an edge machine's substrate is MicroRing's\n", .{m.name});
        return 1;
    };
    const pin_md = std.fs.cwd().readFileAlloc(arena, o.pin, 1 << 20) catch |e| {
        try out.print("advisories: cannot read the kernel pin {s}: {s}\n", .{ o.pin, @errorName(e) });
        return 1;
    };
    const release = pinnedRelease(pin_md) orelse {
        try out.print("advisories: {s} has no `| tarball | `linux-<release>.tar.xz` |` row\n", .{o.pin});
        return 1;
    };
    const rel = Release.parse(release).?;
    const want = try buildName(arena, release, frag);

    const stem = std.fs.path.stem(o.machine_path);
    const sources_path = o.sources orelse try std.fmt.allocPrint(arena, "zig-out/image/{s}/kernel.sources", .{stem});
    const sources_text = std.fs.cwd().readFileAlloc(arena, sources_path, 64 << 20) catch |e| {
        try out.print("advisories: cannot read {s}: {s} -- the list of what {s}'s kernel compiled is written when its image is built (experiment/os2_image.sh {s}); without it nothing here can say what reaches it\n", .{ sources_path, @errorName(e), m.name, stem });
        return 1;
    };
    var serr = SourcesError{};
    const src = (try parseSources(arena, sources_text, &serr)) orelse {
        try out.print("advisories: {s} line {d}: {s}\n", .{ sources_path, serr.line, serr.why });
        return 1;
    };
    if (!std.mem.eql(u8, src.build, want)) {
        try out.print("advisories: refused -- {s} lists the kernel build {s}, and {s} with the pin of {s} is the build {s} today: build its image again (experiment/os2_image.sh {s}) before asking what reaches it\n", .{ sources_path, src.build, m.name, o.pin, want, stem });
        return 1;
    }

    // the records, in the order of their names
    var names: std.ArrayList([]const u8) = .{};
    var dir_opt: ?std.fs.Dir = std.fs.cwd().openDir(o.records, .{ .iterate = true }) catch |e| switch (e) {
        error.NotDir => null,
        else => {
            try out.print("advisories: cannot open {s}: {s}\n", .{ o.records, @errorName(e) });
            return 1;
        },
    };
    if (dir_opt) |*dir| {
        defer dir.close();
        var it = dir.iterate();
        while (try it.next()) |ent| {
            if (ent.kind != .file or !std.mem.endsWith(u8, ent.name, ".json")) {
                try out.print("advisories: refused -- {s} holds {s}, which is not a record (a .json file): the directory is read whole or not at all\n", .{ o.records, ent.name });
                return 1;
            }
            try names.append(arena, try std.fs.path.join(arena, &.{ o.records, ent.name }));
        }
    } else try names.append(arena, o.records);
    std.mem.sort([]const u8, names.items, {}, lessThan);
    if (names.items.len == 0) {
        try out.print("advisories: refused -- {s} holds no record: an answer about nothing is not one\n", .{o.records});
        return 1;
    }

    var counts = std.EnumArray(Verdict, usize).initFill(0);
    var answers: std.ArrayList(Answer) = .{};
    for (names.items) |path| {
        const text = std.fs.cwd().readFileAlloc(arena, path, 16 << 20) catch |e| {
            try out.print("advisories: cannot read {s}: {s}\n", .{ path, @errorName(e) });
            return 1;
        };
        const a = judge(arena, text, rel, &src) catch |e| switch (e) {
            error.NotJson, error.NotACveRecord => {
                try out.print("advisories: refused -- {s} is not a CVE record (CVE JSON 5, with cveMetadata.cveId and containers.cna): {s}\n", .{ path, @errorName(e) });
                return 1;
            },
            else => return e,
        };
        counts.getPtr(a.verdict).* += 1;
        try answers.append(arena, a);
    }
    // what reaches the machine first, then what cannot be told; the rest only when asked for
    for ([_]Verdict{ .reaches, .cannot_tell, .not_built, .fixed, .not_kernel, .rejected }) |v| {
        if (!o.all and v != .reaches and v != .cannot_tell) continue;
        for (answers.items) |a| if (a.verdict == v) try ledgerLine(out, a, release, want);
    }
    try out.print("advisories: {s}, kernel {s} (build {s}, {d} source files compiled) -- {d} record{s}: {d} reach{s} it, {d} cannot be told, {d} not built into it, {d} fixed in {s}, {d} not about the kernel, {d} rejected\n", .{
        m.name,                          release,                                  want,
        src.files.count(),               answers.items.len,                        if (answers.items.len == 1) "" else "s",
        counts.get(.reaches),            if (counts.get(.reaches) == 1) "es" else "", counts.get(.cannot_tell),
        counts.get(.not_built),          counts.get(.fixed),                       release,
        counts.get(.not_kernel),         counts.get(.rejected),
    });
    return if (counts.get(.reaches) == 0 and counts.get(.cannot_tell) == 0) 0 else 1;
}

// ---------------------------------------------------------------------------------------------------------
// Tests

const tst = std.testing;

fn testSources(arena: std.mem.Allocator, files: []const []const u8) !Sources {
    var s = Sources{ .build = "6.12.115-000000000000", .files = .{} };
    for (files) |f| try s.files.put(arena, f, {});
    return s;
}

/// A record in the shape the kernel's numbering authority writes (CVE-2024-50264, read 2026-11-08): one
/// element in git commits, one in releases, both naming the files of the fix.
fn kernelRecord(arena: std.mem.Allocator, id: []const u8, files: []const u8, versions: []const u8, default: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena,
        \\{{"dataType":"CVE_RECORD","dataVersion":"5.2","cveMetadata":{{"cveId":"{s}","state":"PUBLISHED","assignerShortName":"Linux"}},
        \\ "containers":{{"cna":{{"affected":[
        \\  {{"product":"Linux","vendor":"Linux","defaultStatus":"unaffected","programFiles":[{s}],
        \\   "versions":[{{"version":"06a8fc78367d070720af960dcecec917d3ae5f3b","lessThan":"5f092a4271f6dccf88fe0d132475a17b69ef71df","status":"affected","versionType":"git"}}]}},
        \\  {{"product":"Linux","vendor":"Linux","defaultStatus":"{s}","programFiles":[{s}],"versions":[{s}]}}]}}}}}}
    , .{ id, files, default, files, versions });
}

test "a release is compared by its numbers, and a release candidate comes before its release" {
    const r = Release.parse;
    try tst.expect(r("6.12.115").?.order(r("6.12.113").?) == .gt);
    try tst.expect(r("6.12.9").?.order(r("6.12.10").?) == .lt);
    try tst.expect(r("6.13-rc1").?.order(r("6.13").?) == .lt);
    try tst.expect(r("6.12").?.order(r("6.12.0").?) == .eq);
    try tst.expect(r("0").?.order(r("4.8").?) == .lt);
    try tst.expect(r("06a8fc78367d") == null);
    try tst.expect(r("6..12") == null);
    try tst.expect(r("") == null);
}

test "an advisory reaches a machine when its release is affected and a file it names is compiled in (ONEHOUR-1)" {
    var arena_state = std.heap.ArenaAllocator.init(tst.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const src = try testSources(arena, &.{ "include/net/tcp.h", "net/ipv4/tcp.c", "net/ipv4/tcp_ipv4.c" });
    const rel = Release.parse("6.12.115").?;
    // affected since 4.8; the 6.12 branch is fixed only from 6.12.200, so 6.12.115 is affected
    const versions =
        \\{"version":"4.8","status":"affected"},{"version":"0","lessThan":"4.8","status":"unaffected","versionType":"semver"},
        \\{"version":"6.6.90","lessThanOrEqual":"6.6.*","status":"unaffected","versionType":"semver"},
        \\{"version":"6.12.200","lessThanOrEqual":"6.12.*","status":"unaffected","versionType":"semver"},
        \\{"version":"6.13","lessThanOrEqual":"*","status":"unaffected","versionType":"original_commit_for_fix"}
    ;
    const reach = try judge(arena, try kernelRecord(arena, "CVE-0000-0001", "\"net/ipv4/tcp_ipv4.c\",\"net/core/sock.c\"", versions, "affected"), rel, &src);
    try tst.expectEqual(Verdict.reaches, reach.verdict);
    try tst.expectEqual(@as(usize, 2), reach.named.len);
    try tst.expectEqual(@as(usize, 1), reach.built.len);
    try tst.expectEqualStrings("net/ipv4/tcp_ipv4.c", reach.built[0]);
    // a header counts when an object of the kernel included it
    const header = try judge(arena, try kernelRecord(arena, "CVE-0000-0002", "\"include/net/tcp.h\"", versions, "affected"), rel, &src);
    try tst.expectEqual(Verdict.reaches, header.verdict);
    // the same flaw in a file this kernel never compiled: not built
    const absent = try judge(arena, try kernelRecord(arena, "CVE-0000-0003", "\"crypto/af_alg.c\",\"crypto/algif_aead.c\"", versions, "affected"), rel, &src);
    try tst.expectEqual(Verdict.not_built, absent.verdict);
    try tst.expectEqual(@as(usize, 0), absent.built.len);
}

test "an advisory whose fix is in the pinned release is fixed, whatever it names (ONEHOUR-1)" {
    var arena_state = std.heap.ArenaAllocator.init(tst.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const src = try testSources(arena, &.{"net/ipv4/tcp.c"});
    const rel = Release.parse("6.12.115").?;
    // the TCP flaw the pin moved past (TCPUAF-1): fixed in the 6.12 branch from 6.12.113
    const versions =
        \\{"version":"3.6","status":"affected"},{"version":"0","lessThan":"3.6","status":"unaffected","versionType":"semver"},
        \\{"version":"6.12.113","lessThanOrEqual":"6.12.*","status":"unaffected","versionType":"semver"},
        \\{"version":"6.18","lessThanOrEqual":"*","status":"unaffected","versionType":"original_commit_for_fix"}
    ;
    const a = try judge(arena, try kernelRecord(arena, "CVE-0000-0004", "\"net/ipv4/tcp.c\"", versions, "affected"), rel, &src);
    try tst.expectEqual(Verdict.fixed, a.verdict);
    // ... and the same record read for the release the pin held before: it reaches
    const before = try judge(arena, try kernelRecord(arena, "CVE-0000-0004", "\"net/ipv4/tcp.c\"", versions, "affected"), Release.parse("6.12.109").?, &src);
    try tst.expectEqual(Verdict.reaches, before.verdict);
    // a range written as a span (the shape of a record from another authority): 3.15 up to 6.8 is past
    const span =
        \\{"cveMetadata":{"cveId":"CVE-0000-0005"},"containers":{"cna":{"affected":[{"vendor":"Linux","product":"Kernel",
        \\ "defaultStatus":"unaffected","versions":[{"status":"affected","version":"3.15","lessThan":"6.8","versionType":"custom"}]}]}}}
    ;
    try tst.expectEqual(Verdict.fixed, (try judge(arena, span, rel, &src)).verdict);
    try tst.expectEqual(Verdict.cannot_tell, (try judge(arena, span, Release.parse("6.7.3").?, &src)).verdict); // affected, no file named
}

test "a record that cannot answer says so, and is never silence (ONEHOUR-1)" {
    var arena_state = std.heap.ArenaAllocator.init(tst.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const src = try testSources(arena, &.{"net/ipv4/tcp.c"});
    const rel = Release.parse("6.12.115").?;
    // git commits only: a pin is a release, not a commit
    const git_only =
        \\{"cveMetadata":{"cveId":"CVE-0000-0006"},"containers":{"cna":{"affected":[{"vendor":"Linux","product":"Linux","defaultStatus":"unaffected",
        \\ "programFiles":["net/ipv4/tcp.c"],"versions":[{"version":"06a8fc78","lessThan":"5f092a42","status":"affected","versionType":"git"}]}]}}}
    ;
    const g = try judge(arena, git_only, rel, &src);
    try tst.expectEqual(Verdict.cannot_tell, g.verdict);
    try tst.expect(std.mem.indexOf(u8, g.why, "compared") != null);
    // affected, and no file named
    const no_files = try kernelRecord(arena, "CVE-0000-0007", "", "{\"version\":\"4.8\",\"status\":\"affected\"}", "affected");
    const n = try judge(arena, no_files, rel, &src);
    try tst.expectEqual(Verdict.cannot_tell, n.verdict);
    try tst.expectEqualStrings("it names no file", n.why);
    // two elements that disagree
    const split =
        \\{"cveMetadata":{"cveId":"CVE-0000-0008"},"containers":{"cna":{"affected":[
        \\ {"vendor":"Linux","product":"Linux","defaultStatus":"affected","programFiles":["net/ipv4/tcp.c"],"versions":[{"version":"4.8","status":"affected"}]},
        \\ {"vendor":"Linux","product":"Linux","defaultStatus":"unaffected","programFiles":["net/ipv4/tcp.c"],"versions":[{"version":"4.8","status":"affected"}]}]}}}
    ;
    const sp = try judge(arena, split, rel, &src);
    try tst.expectEqual(Verdict.cannot_tell, sp.verdict);
    try tst.expectEqualStrings("its release ranges disagree", sp.why);
    // two entries of ONE element that both hold the release and disagree
    const within =
        \\{"cveMetadata":{"cveId":"CVE-0000-0012"},"containers":{"cna":{"affected":[{"vendor":"Linux","product":"Linux","defaultStatus":"affected",
        \\ "programFiles":["net/ipv4/tcp.c"],"versions":[{"version":"6.0","lessThan":"6.13","status":"affected","versionType":"semver"},
        \\ {"version":"6.12.100","lessThanOrEqual":"6.12.*","status":"unaffected","versionType":"semver"}]}]}}}
    ;
    const wi = try judge(arena, within, rel, &src);
    try tst.expectEqual(Verdict.cannot_tell, wi.verdict);
    try tst.expectEqualStrings("its release ranges disagree", wi.why);
    // an authority that says it does not know
    const unknown =
        \\{"cveMetadata":{"cveId":"CVE-0000-0013"},"containers":{"cna":{"affected":[{"vendor":"Linux","product":"Linux","defaultStatus":"unknown",
        \\ "programFiles":["net/ipv4/tcp.c"],"versions":[{"version":"4.8","status":"affected","versionType":"semver"}]}]}}}
    ;
    const un = try judge(arena, unknown, rel, &src);
    try tst.expectEqual(Verdict.cannot_tell, un.verdict);
    try tst.expectEqualStrings("it says this release's status is unknown", un.why);
    // not the kernel, withdrawn, and not a record at all
    const other =
        \\{"cveMetadata":{"cveId":"CVE-0000-0009"},"containers":{"cna":{"affected":[{"vendor":"Example","product":"Thing","versions":[]}]}}}
    ;
    try tst.expectEqual(Verdict.not_kernel, (try judge(arena, other, rel, &src)).verdict);
    const withdrawn =
        \\{"cveMetadata":{"cveId":"CVE-0000-0010","state":"REJECTED"},"containers":{"cna":{}}}
    ;
    try tst.expectEqual(Verdict.rejected, (try judge(arena, withdrawn, rel, &src)).verdict);
    try tst.expectError(error.NotACveRecord, judge(arena, "{\"id\":\"CVE-0000-0011\",\"affected\":[]}", rel, &src));
    try tst.expectError(error.NotJson, judge(arena, "not json", rel, &src));
}

test "the build a list names is the pin's release and the digest of the fragment's options alone (ONEHOUR-1)" {
    var arena_state = std.heap.ArenaAllocator.init(tst.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // the comment line names the machine and is not part of the key; `# CONFIG_X is not set` is a setting
    const a = "# kernel.fragment -- derived by harb image from machines/a.machine\nCONFIG_64BIT=y\n# CONFIG_MODULES is not set\nCONFIG_LSM=\"landlock\"\n";
    const b = "# kernel.fragment -- derived by harb image from machines/b.machine\nCONFIG_64BIT=y\n# CONFIG_MODULES is not set\nCONFIG_LSM=\"landlock\"\n";
    const c = "# kernel.fragment -- derived by harb image from machines/a.machine\nCONFIG_64BIT=y\nCONFIG_LSM=\"landlock\"\n";
    try tst.expectEqualStrings(try buildName(arena, "6.12.115", a), try buildName(arena, "6.12.115", b));
    try tst.expect(!std.mem.eql(u8, try buildName(arena, "6.12.115", a), try buildName(arena, "6.12.115", c)));
    try tst.expect(!std.mem.eql(u8, try buildName(arena, "6.12.115", a), try buildName(arena, "6.12.109", a)));
    // the value os2_image.sh computes for the same text, read on 2026-11-08 from
    //   printf 'CONFIG_64BIT=y\n# CONFIG_MODULES is not set\nCONFIG_LSM="landlock"\n' | sha256sum | cut -c1-12
    try tst.expectEqualStrings("6.12.115-103af3d2857d", try buildName(arena, "6.12.115", a));
    try tst.expectEqualStrings("6.12.115", pinnedRelease("x\n| tarball | `linux-6.12.115.tar.xz` |\r\n").?);
    try tst.expect(pinnedRelease("| tarball | `linux-6.12.tar.gz` |\n") == null);
}

test "a list of compiled files is read strictly (ONEHOUR-1)" {
    var arena_state = std.heap.ArenaAllocator.init(tst.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var e = SourcesError{};
    const good = (try parseSources(arena, "harb kernel sources v1\nbuild 6.12.115-04bf90e9a773\nkernel/seccomp.c\nnet/ipv4/tcp.c\n", &e)).?;
    try tst.expectEqualStrings("6.12.115-04bf90e9a773", good.build);
    try tst.expect(good.files.contains("net/ipv4/tcp.c"));
    try tst.expect(try parseSources(arena, "harb kernel sources v1\nbuild x\nnet/ipv4/tcp.c\nkernel/seccomp.c\n", &e) == null);
    try tst.expectEqualStrings("a path out of order or twice", e.why);
    try tst.expect(try parseSources(arena, "harb kernel sources v1\nbuild x\n", &e) == null);
    try tst.expect(try parseSources(arena, "harb kernel sources v2\nbuild x\na.c\n", &e) == null);
    try tst.expect(try parseSources(arena, "harb kernel sources v1\nbuild x\n/abs.c\n", &e) == null);
}
