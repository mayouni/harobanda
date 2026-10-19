// mirror.zig -- a copy of a world's directory is the source's word, or it is not kept (MIR-1, STZ-OS-RULING-19).
//
// The floor moves no data between machines today. The mirror is the one addition that changes what the floor
// is: it copies and verifies files between declared places, and what a CONSISTENT copy is stays the
// application's. This file is the part that needs no kernel -- the messages, the manifest and its judgement,
// and the reading of a copy against a manifest -- exactly as timeattest.zig is the statement and its
// judgement. mirrorserve.zig is what touches the machine (the sockets, the walk of a directory, the files
// written), and `harb mirror` is what reads the result.
//
// WHAT IS SIGNED. The source signs a MANIFEST of the directory it gives:
//
//   mirror v1 source=<16 hex> puller=<16 hex> nonce=<64 hex> dir=<path> files=<n> bytes=<total>
//   dir <relative path>                                    (zero or more)
//   file <sha256, 64 hex> <size in bytes> <relative path>  (zero or more, interleaved in path order)
//   end
//   sig=<128 hex>
//
// `source` is the fingerprint of the signing key (the function the journal and the fleet use), `puller` the
// fingerprint of the device it was cut for, `nonce` the puller's own and fresh one, and `sig` is Ed25519 over
// the exact bytes before the `sig=` line -- the bytes on the wire, not the object they were parsed into (the
// rule JRN-1 and TIME-1 kept). A manifest is therefore the source's word about ONE directory, for ONE
// puller, at ONE request: an old one replayed is refused for its nonce, and one cut for another device for
// its puller. The file bytes follow it, in its order, and are not signed one by one: each is held to the
// digest the signature covers, which is what a signature over a list of digests is for.
//
// THE SAME KEY SIGNS A JOURNAL ENTRY, A TIME STATEMENT AND A MANIFEST, so each is judged by its shape: a
// manifest begins `mirror v1`, a request `mirror-request`, and no line a world can influence (a file's name,
// which is the one thing in a manifest chosen by something other than the key's holder) can begin a line --
// a name with a line end in it, or a control byte, or a backslash, makes the directory unmirrorable rather
// than the manifest ambiguous (`safeRelPath`).
//
// ONE SPELLING of every field: lowercase hex of its exact length, a size of decimal digits with no sign and
// no leading zero, one line end per line and nothing after the signature, paths strictly increasing in byte
// order (so no entry twice, and a file that is also a directory above another entry is refused). A manifest
// that is not that is not read leniently; PID 1 reads it off a wire and must never be taken down by it.
//
// WHO MAY ASK. The source gives the copy to one device, the holder of the key it was declared with
// (`MIRROR_FOR`): it sends a challenge, the puller answers with a request signed by its device key over BOTH
// nonces, and only a request that verifies under that key, for that challenge, is given a manifest. A world's
// directory is closed to every other world (OWN-1); the floor reads it as root, and a floor that gave it to
// whoever asked on the link would break the promise it keeps.

const std = @import("std");
const builtin = @import("builtin");
const Ed25519 = std.crypto.sign.Ed25519;
const Sha256 = std.crypto.hash.sha2.Sha256;
const journal = @import("journal.zig");

pub const nonce_len = 32;
/// the most entries a manifest carries, files and directories together: a directory with more is not one the
/// mirror gives (it says so and gives nothing), never a manifest cut short that verifies
pub const max_entries: usize = 4096;
/// the most bytes of manifest a puller reads before it is a manifest at all
pub const max_manifest_bytes: usize = 1 << 20;
/// the most file bytes one copy carries: the sum the signed header states, held by both ends
pub const max_total_bytes: u64 = 1 << 30;
pub const max_path_bytes: usize = 1024;
pub const max_component_bytes: usize = 255;
/// the longest challenge or request line
pub const max_line: usize = 512;

/// A copy is kept beside the directory it is a copy of, outside it: the manifest of the last COMPLETE copy
/// (the commit record) and one line about the last attempt. The one place that says so, because the machine
/// that writes them (PID 1's puller) and the witness that reads them (`harb mirror check`) are two programs
/// that must name the same files.
pub const kept_manifest_suffix = ".manifest";
pub const kept_last_suffix = ".last";

// ---- spelling ----------------------------------------------------------------------------------------

fn isLowerHex(s: []const u8) bool {
    for (s) |c| if (!std.ascii.isHex(c) or std.ascii.isUpper(c)) return false;
    return true;
}

fn hexBytes(comptime n: usize, s: []const u8) ?[n]u8 {
    if (s.len != n * 2 or !isLowerHex(s)) return null;
    var out: [n]u8 = undefined;
    _ = std.fmt.hexToBytes(&out, s) catch return null;
    return out;
}

/// A fingerprint as the journal, the fleet and the roll print it: 16 lowercase hex CHARACTERS (the first 8 bytes of
/// a key's sha256), kept as the characters they are.
fn fp16(s: []const u8) ?[16]u8 {
    if (s.len != 16 or !isLowerHex(s)) return null;
    var out: [16]u8 = undefined;
    @memcpy(&out, s);
    return out;
}

/// A line without its end: ONE `\n`, or one `\r\n`, and no more.
pub fn trimLineEnd(line: []const u8) []const u8 {
    var l = line;
    if (l.len > 0 and l[l.len - 1] == '\n') l = l[0 .. l.len - 1];
    if (l.len > 0 and l[l.len - 1] == '\r') l = l[0 .. l.len - 1];
    return l;
}

/// A decimal number as a manifest spells it: digits and nothing else, no sign, no separator, no leading zero
/// (`parseInt` takes all three, and then two manifests would be one).
fn decimal(s: []const u8) ?u64 {
    if (s.len == 0 or s.len > 12) return null;
    for (s) |c| if (c < '0' or c > '9') return null;
    if (s.len > 1 and s[0] == '0') return null;
    return std.fmt.parseInt(u64, s, 10) catch null;
}

/// A path inside a mirrored directory: relative, made of components that are not empty, not `.` and not `..`,
/// with no control byte (so no line end) and no backslash (so a copy read on a desk that takes it for a
/// separator is the copy that was made). Spaces and bytes above 127 are names like any other. Nothing a
/// verifier could be led out of its directory by, and nothing that could begin a line of its own.
pub fn safeRelPath(p: []const u8) bool {
    if (p.len == 0 or p.len > max_path_bytes) return false;
    if (p[0] == '/' or p[p.len - 1] == '/') return false;
    var it = std.mem.splitScalar(u8, p, '/');
    while (it.next()) |c| {
        if (c.len == 0 or c.len > max_component_bytes) return false;
        if (std.mem.eql(u8, c, ".") or std.mem.eql(u8, c, "..")) return false;
        for (c) |b| if (b < 0x20 or b == 0x7f or b == '\\') return false;
    }
    return true;
}

/// The directory a manifest says it was cut from: absolute, a safe path, and no space, so that the header's
/// `dir=` is one field.
pub fn safeDir(p: []const u8) bool {
    if (p.len < 2 or p[0] != '/') return false;
    if (std.mem.indexOfScalar(u8, p, ' ') != null) return false;
    return safeRelPath(p[1..]);
}

// ---- the challenge and the request -------------------------------------------------------------------

/// `mirror-challenge <64 hex>`: the source's, a fresh nonce for this connection.
pub fn challenge(buf: []u8, nonce: [nonce_len]u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "mirror-challenge {x}", .{&nonce});
}

pub fn parseChallenge(line: []const u8) ?[nonce_len]u8 {
    const l = trimLineEnd(line);
    const prefix = "mirror-challenge ";
    if (!std.mem.startsWith(u8, l, prefix)) return null;
    return hexBytes(nonce_len, l[prefix.len..]);
}

pub const Request = struct {
    key: [32]u8,
    a: [nonce_len]u8,
    b: [nonce_len]u8,
    sig: [Ed25519.Signature.encoded_length]u8,
};

/// `mirror-request key=<64 hex> a=<64 hex> b=<64 hex> sig=<128 hex>`: the puller's device key over both
/// nonces -- the source's (`a`, which makes the answer this connection's and no other) and its own (`b`, which
/// the manifest will carry back).
pub fn request(buf: []u8, pair: Ed25519.KeyPair, a: [nonce_len]u8, b: [nonce_len]u8) ![]const u8 {
    var pb: [max_line]u8 = undefined;
    const body = try std.fmt.bufPrint(&pb, "mirror-request key={x} a={x} b={x}", .{ &pair.public_key.toBytes(), &a, &b });
    const sig = try pair.sign(body, null);
    return std.fmt.bufPrint(buf, "{s} sig={x}", .{ body, &sig.toBytes() });
}

/// Parse a request: the fields in order, lowercase hex of the lengths they must have, nothing after.
pub fn parseRequest(line: []const u8) ?Request {
    const l = trimLineEnd(line);
    if (l.len > max_line) return null;
    var it = std.mem.splitScalar(u8, l, ' ');
    const verb = it.next() orelse return null;
    if (!std.mem.eql(u8, verb, "mirror-request")) return null;
    const k = it.next() orelse return null;
    const a = it.next() orelse return null;
    const b = it.next() orelse return null;
    const s = it.next() orelse return null;
    if (it.next() != null) return null;
    if (!std.mem.startsWith(u8, k, "key=") or !std.mem.startsWith(u8, a, "a=")) return null;
    if (!std.mem.startsWith(u8, b, "b=") or !std.mem.startsWith(u8, s, "sig=")) return null;
    return .{
        .key = hexBytes(32, k["key=".len..]) orelse return null,
        .a = hexBytes(nonce_len, a["a=".len..]) orelse return null,
        .b = hexBytes(nonce_len, b["b=".len..]) orelse return null,
        .sig = hexBytes(Ed25519.Signature.encoded_length, s["sig=".len..]) orelse return null,
    };
}

/// A request is the puller's word only if it is signed by the key the source was declared to give the copy to,
/// answers THIS challenge, and verifies over the bytes on the line. Null for anything else, with no reason: the
/// source tells an asker nothing it could use.
pub fn verifyRequest(line: []const u8, allowed: Ed25519.PublicKey, a: [nonce_len]u8) ?Request {
    const r = parseRequest(line) orelse return null;
    if (!std.mem.eql(u8, &r.key, &allowed.toBytes())) return null;
    if (!std.mem.eql(u8, &r.a, &a)) return null;
    const l = trimLineEnd(line);
    const body = l[0 .. l.len - " sig=".len - Ed25519.Signature.encoded_length * 2];
    Ed25519.Signature.fromBytes(r.sig).verify(body, allowed) catch return null;
    return r;
}

// ---- the manifest ------------------------------------------------------------------------------------

pub const Kind = enum { dir, file };

/// One entry of a directory: where it is, and for a file how big and what digest.
pub const Entry = struct {
    kind: Kind,
    path: []const u8,
    size: u64 = 0,
    digest: [32]u8 = [_]u8{0} ** 32,
};

pub const Manifest = struct {
    source: [16]u8,
    puller: [16]u8,
    nonce: [nonce_len]u8,
    dir: []const u8,
    entries: []const Entry,
    files: u64,
    bytes: u64,
    sig: [Ed25519.Signature.encoded_length]u8,
    /// how many bytes of the text the signature covers: all of it up to the `sig=` line
    signed_len: usize,
};

fn pathLess(_: void, a: Entry, b: Entry) bool {
    return std.mem.lessThan(u8, a.path, b.path);
}

/// Sort entries by path, in place: the order a manifest states them in.
pub fn sortEntries(entries: []Entry) void {
    std.mem.sort(Entry, entries, {}, pathLess);
}

/// What is wrong with a list of entries as a manifest states them, in words, or null. Strictly increasing by
/// path (so none twice), every path safe, no file that is also a directory above another entry, and within the
/// bounds a copy has. One reading, for the source that builds a manifest and the puller that is handed one.
pub fn entriesProblem(alloc: std.mem.Allocator, entries: []const Entry) !?[]const u8 {
    if (entries.len > max_entries) return try std.fmt.allocPrint(alloc, "{d} entries, and a manifest carries at most {d}", .{ entries.len, max_entries });
    var total: u64 = 0;
    var files = std.StringHashMap(void).init(alloc);
    defer files.deinit();
    for (entries, 0..) |e, i| {
        if (!safeRelPath(e.path)) return try std.fmt.allocPrint(alloc, "'{s}' is not a path a manifest can name", .{e.path});
        if (i > 0 and !std.mem.lessThan(u8, entries[i - 1].path, e.path)) {
            return try std.fmt.allocPrint(alloc, "'{s}' does not come after '{s}': a manifest names each path once, in order", .{ e.path, entries[i - 1].path });
        }
        // a file is not a directory: nothing may lie under a path that is a file
        var at: usize = 0;
        while (std.mem.indexOfScalarPos(u8, e.path, at, '/')) |slash| {
            if (files.contains(e.path[0..slash])) return try std.fmt.allocPrint(alloc, "'{s}' lies under '{s}', which is a file", .{ e.path, e.path[0..slash] });
            at = slash + 1;
        }
        if (e.kind == .file) {
            try files.put(e.path, {});
            total += e.size;
            if (total > max_total_bytes) return try std.fmt.allocPrint(alloc, "more than {d} bytes of files, and a copy carries at most that", .{max_total_bytes});
        }
    }
    return null;
}

/// Build and sign a manifest of `entries` (already sorted) for `puller`'s request `nonce`, cut from `dir`.
/// Returns the whole text, the `sig=` line included.
pub fn build(alloc: std.mem.Allocator, pair: Ed25519.KeyPair, puller: [16]u8, nonce: [nonce_len]u8, dir: []const u8, entries: []const Entry) ![]u8 {
    if (!safeDir(dir)) return error.UnsafeDir;
    if (try entriesProblem(alloc, entries)) |why| {
        alloc.free(why);
        return error.BadEntries;
    }
    var files: u64 = 0;
    var bytes: u64 = 0;
    for (entries) |e| if (e.kind == .file) {
        files += 1;
        bytes += e.size;
    };
    var aw = std.Io.Writer.Allocating.init(alloc);
    errdefer aw.deinit();
    const w = &aw.writer;
    const fp = journal.fingerprintOf(pair.public_key.toBytes());
    try w.print("mirror v1 source={s} puller={s} nonce={x} dir={s} files={d} bytes={d}\n", .{ &fp, &puller, &nonce, dir, files, bytes });
    for (entries) |e| switch (e.kind) {
        .dir => try w.print("dir {s}\n", .{e.path}),
        .file => try w.print("file {x} {d} {s}\n", .{ &e.digest, e.size, e.path }),
    };
    try w.writeAll("end\n");
    const sig = try pair.sign(aw.written(), null);
    try w.print("sig={x}\n", .{&sig.toBytes()});
    return aw.toOwnedSlice();
}

pub const ParseError = error{ Malformed, TooLarge, OutOfMemory };

/// Parse a manifest, strictly. No signature is judged here; `verify` does that over the same bytes.
pub fn parse(alloc: std.mem.Allocator, text: []const u8) ParseError!Manifest {
    if (text.len > max_manifest_bytes) return error.TooLarge;
    if (text.len == 0 or text[text.len - 1] != '\n') return error.Malformed;
    // the last line is the signature, and the line before it is `end`
    const body_end = (std.mem.lastIndexOfScalar(u8, text[0 .. text.len - 1], '\n') orelse return error.Malformed) + 1;
    const sig_line = text[body_end .. text.len - 1];
    if (!std.mem.startsWith(u8, sig_line, "sig=")) return error.Malformed;
    const sig = hexBytes(Ed25519.Signature.encoded_length, sig_line["sig=".len..]) orelse return error.Malformed;
    const body = text[0..body_end];
    if (!std.mem.endsWith(u8, body, "\nend\n")) return error.Malformed;

    var lines = std.mem.splitScalar(u8, body[0 .. body.len - "end\n".len], '\n');
    const header = lines.next() orelse return error.Malformed;
    var h = std.mem.splitScalar(u8, header, ' ');
    const magic = h.next() orelse return error.Malformed;
    const ver = h.next() orelse return error.Malformed;
    const src = h.next() orelse return error.Malformed;
    const pul = h.next() orelse return error.Malformed;
    const non = h.next() orelse return error.Malformed;
    const dir = h.next() orelse return error.Malformed;
    const fil = h.next() orelse return error.Malformed;
    const byt = h.next() orelse return error.Malformed;
    if (h.next() != null) return error.Malformed;
    if (!std.mem.eql(u8, magic, "mirror") or !std.mem.eql(u8, ver, "v1")) return error.Malformed;
    if (!std.mem.startsWith(u8, src, "source=") or !std.mem.startsWith(u8, pul, "puller=")) return error.Malformed;
    if (!std.mem.startsWith(u8, non, "nonce=") or !std.mem.startsWith(u8, dir, "dir=")) return error.Malformed;
    if (!std.mem.startsWith(u8, fil, "files=") or !std.mem.startsWith(u8, byt, "bytes=")) return error.Malformed;
    const source = fp16(src["source=".len..]) orelse return error.Malformed;
    const puller = fp16(pul["puller=".len..]) orelse return error.Malformed;
    const nonce = hexBytes(nonce_len, non["nonce=".len..]) orelse return error.Malformed;
    const dir_path = dir["dir=".len..];
    if (!safeDir(dir_path)) return error.Malformed;
    const files_n = decimal(fil["files=".len..]) orelse return error.Malformed;
    const bytes_n = decimal(byt["bytes=".len..]) orelse return error.Malformed;

    var list: std.ArrayList(Entry) = .{};
    errdefer list.deinit(alloc);
    var files_seen: u64 = 0;
    var bytes_seen: u64 = 0;
    while (lines.next()) |line| {
        if (line.len == 0 and lines.peek() == null) break; // the split's empty tail after the last line end
        if (list.items.len >= max_entries) return error.TooLarge;
        if (std.mem.startsWith(u8, line, "dir ")) {
            try list.append(alloc, .{ .kind = .dir, .path = line["dir ".len..] });
        } else if (std.mem.startsWith(u8, line, "file ")) {
            const rest = line["file ".len..];
            const sp1 = std.mem.indexOfScalar(u8, rest, ' ') orelse return error.Malformed;
            const digest = hexBytes(32, rest[0..sp1]) orelse return error.Malformed;
            const rest2 = rest[sp1 + 1 ..];
            const sp2 = std.mem.indexOfScalar(u8, rest2, ' ') orelse return error.Malformed;
            const size = decimal(rest2[0..sp2]) orelse return error.Malformed;
            try list.append(alloc, .{ .kind = .file, .path = rest2[sp2 + 1 ..], .size = size, .digest = digest });
            files_seen += 1;
            bytes_seen += size;
        } else return error.Malformed;
    }
    if (files_seen != files_n or bytes_seen != bytes_n) return error.Malformed;
    if (bytes_n > max_total_bytes) return error.TooLarge;
    // the entries are held to the same reading the source built them by
    if (try entriesProblem(alloc, list.items)) |why| {
        alloc.free(why);
        return error.Malformed;
    }
    return .{
        .source = source,
        .puller = puller,
        .nonce = nonce,
        .dir = dir_path,
        .entries = try list.toOwnedSlice(alloc),
        .files = files_n,
        .bytes = bytes_n,
        .sig = sig,
        .signed_len = body_end,
    };
}

/// What judging a manifest comes to.
pub const Verdict = enum {
    ok,
    /// not a manifest at all: a field missing, out of order, spelled another way, or entries that are not one
    malformed,
    /// more than a copy carries
    too_large,
    /// a manifest signed by somebody else: the fingerprint is not the source's
    wrong_source,
    /// a manifest from this source whose signature does not verify: it was changed after it was signed
    bad_signature,
    /// signed by the source, and cut for another device than this one
    wrong_puller,
    /// signed by the source, and answering another request than this one: an old manifest, replayed
    wrong_nonce,

    pub fn words(self: Verdict) []const u8 {
        return switch (self) {
            .ok => "verifies",
            .malformed => "is not a manifest",
            .too_large => "carries more than a copy can",
            .wrong_source => "was signed by somebody else than the source",
            .bad_signature => "does not verify: it was changed after it was signed, or signed by another key",
            .wrong_puller => "was cut for another device",
            .wrong_nonce => "answers another request than this one",
        };
    }
};

pub const Verified = union(enum) {
    ok: Manifest,
    bad: Verdict,
};

/// Judge a manifest against the source's public key: its own, no secret. The signature is checked over the
/// bytes of the text itself, never over a rendering of what was parsed from it. `puller` and `nonce`, when
/// given, bind it to this device and this request; the witness that reads a KEPT manifest passes the device it
/// is on and no nonce, because the nonce was the request's and is not kept as one.
pub fn verify(alloc: std.mem.Allocator, text: []const u8, source: Ed25519.PublicKey, puller: ?[16]u8, nonce: ?[nonce_len]u8) Verified {
    const m = parse(alloc, text) catch |e| return .{ .bad = switch (e) {
        error.TooLarge => .too_large,
        else => .malformed,
    } };
    const fp = journal.fingerprintOf(source.toBytes());
    if (!std.mem.eql(u8, &fp, &m.source)) return .{ .bad = .wrong_source };
    Ed25519.Signature.fromBytes(m.sig).verify(text[0..m.signed_len], source) catch return .{ .bad = .bad_signature };
    if (puller) |p| if (!std.mem.eql(u8, &p, &m.puller)) return .{ .bad = .wrong_puller };
    if (nonce) |n| if (!std.mem.eql(u8, &n, &m.nonce)) return .{ .bad = .wrong_nonce };
    return .{ .ok = m };
}

// ---- a copy, read against a manifest -----------------------------------------------------------------

pub const FileHash = struct { size: u64, digest: [32]u8 };

/// The size and sha256 of a file, read once, in blocks, and not past `limit` bytes: a file that is longer is refused as
/// soon as it is known to be, and its end is never read. The source reads a world's files as root, and a world can make
/// one of any size or one that grows as fast as it is read.
pub fn hashFileLimit(f: std.fs.File, limit: u64) !FileHash {
    var h = Sha256.init(.{});
    var buf: [65536]u8 = undefined;
    var size: u64 = 0;
    while (true) {
        const n = try f.read(&buf);
        if (n == 0) break;
        size += n;
        if (size > limit) return error.FileTooLarge;
        h.update(buf[0..n]);
    }
    var d: [32]u8 = undefined;
    h.final(&d);
    return .{ .size = size, .digest = d };
}

/// The size and sha256 of a file, read once, in blocks.
pub fn hashFile(f: std.fs.File) !FileHash {
    return hashFileLimit(f, std.math.maxInt(u64));
}

pub const CopyReport = struct {
    files: u64 = 0,
    dirs: u64 = 0,
    bytes: u64 = 0,
    /// the first thing wrong, in words, owned by the allocator the report was made with; null when the copy is
    /// exactly what the manifest says
    problem: ?[]const u8 = null,
};

fn isLink(dir: std.fs.Dir, rel: []const u8) bool {
    // (a desk that is not Linux reads a copy a Linux machine made, and has no links in it to be led by: its
    // `readLink` answers a file that is not one with an error that prints a trace, and says nothing more)
    if (builtin.os.tag == .windows) return false;
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = dir.readLink(rel, &buf) catch return false;
    return true;
}

/// Whether `rel`, or any directory above it, is a symbolic link: a copy holds regular files and directories and
/// nothing a verifier could be led somewhere else by.
fn underLink(dir: std.fs.Dir, rel: []const u8) bool {
    var at: usize = 0;
    while (std.mem.indexOfScalarPos(u8, rel, at, '/')) |slash| {
        if (isLink(dir, rel[0..slash])) return true;
        at = slash + 1;
    }
    return isLink(dir, rel);
}

/// Read the directory `dir` against `m`: every entry is there with the size and digest the manifest says, and
/// nothing else is. The reading `harb mirror check` makes from inside the machine and `harb mirror verify` makes
/// on a host with the fleet's key, and the reading the puller makes of its own staging before it swaps it in.
pub fn verifyCopy(alloc: std.mem.Allocator, dir: std.fs.Dir, m: Manifest) !CopyReport {
    var r = CopyReport{};
    var listed = std.StringHashMap(void).init(alloc);
    defer listed.deinit();
    for (m.entries) |e| {
        try listed.put(e.path, {});
        if (underLink(dir, e.path)) {
            r.problem = try std.fmt.allocPrint(alloc, "{s} is, or lies under, a symbolic link: a copy holds files and directories", .{e.path});
            return r;
        }
        switch (e.kind) {
            .dir => {
                var d = dir.openDir(e.path, .{}) catch {
                    r.problem = try std.fmt.allocPrint(alloc, "{s} is not there as a directory", .{e.path});
                    return r;
                };
                d.close();
                r.dirs += 1;
            },
            .file => {
                const f = dir.openFile(e.path, .{}) catch {
                    r.problem = try std.fmt.allocPrint(alloc, "{s} is not there", .{e.path});
                    return r;
                };
                defer f.close();
                const st = try f.stat();
                if (st.kind != .file) {
                    r.problem = try std.fmt.allocPrint(alloc, "{s} is not a regular file", .{e.path});
                    return r;
                }
                const got = try hashFile(f);
                if (got.size != e.size) {
                    r.problem = try std.fmt.allocPrint(alloc, "{s} is {d} bytes and the manifest says {d}", .{ e.path, got.size, e.size });
                    return r;
                }
                if (!std.mem.eql(u8, &got.digest, &e.digest)) {
                    r.problem = try std.fmt.allocPrint(alloc, "{s} does not match its digest: it was changed after it was copied, or copied badly", .{e.path});
                    return r;
                }
                r.files += 1;
                r.bytes += got.size;
            },
        }
    }
    // and nothing the manifest does not list: a copy that holds a file the source never gave is not that copy
    var w = try dir.walk(alloc);
    defer w.deinit();
    while (try w.next()) |e| {
        // a manifest says `/`; a walk on a desk that is not Linux says what that desk's separator is
        const here = try alloc.dupe(u8, e.path);
        if (builtin.os.tag == .windows) std.mem.replaceScalar(u8, here, '\\', '/');
        if (!listed.contains(here)) {
            r.problem = try std.fmt.allocPrint(alloc, "it holds {s}, which the manifest does not list", .{here});
            return r;
        }
    }
    return r;
}

// ---- tests -----------------------------------------------------------------------------------------

fn testPair(seed_byte: u8) !Ed25519.KeyPair {
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, seed_byte);
    return Ed25519.KeyPair.generateDeterministic(seed);
}

fn digestOf(bytes: []const u8) [32]u8 {
    var d: [32]u8 = undefined;
    Sha256.hash(bytes, &d, .{});
    return d;
}

const test_nonce_a = [_]u8{0xa1} ** nonce_len;
const test_nonce_b = [_]u8{0xb2} ** nonce_len;

/// three entries as the source would list them: a directory, and a file in it, and a file beside it
fn testEntries() [3]Entry {
    return .{
        .{ .kind = .dir, .path = "sub" },
        .{ .kind = .file, .path = "sub/inner.db", .size = 5, .digest = digestOf("inner") },
        .{ .kind = .file, .path = "top.db", .size = 3, .digest = digestOf("top") },
    };
}

test "a manifest is built, parsed and verified with the source's public key and nothing else (MIR-1)" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const src = try testPair(1);
    const pul = try testPair(2);
    const puller = journal.fingerprintOf(pul.public_key.toBytes());
    const es = testEntries();
    const text = try build(arena, src, puller, test_nonce_b, "/data/ringserv", &es);
    try t.expect(std.mem.startsWith(u8, text, "mirror v1 source="));
    try t.expect(std.mem.endsWith(u8, text, "\n"));
    const ok = verify(arena, text, src.public_key, puller, test_nonce_b);
    try t.expect(ok == .ok);
    try t.expectEqual(@as(u64, 2), ok.ok.files);
    try t.expectEqual(@as(u64, 8), ok.ok.bytes);
    try t.expectEqual(@as(usize, 3), ok.ok.entries.len);
    try t.expectEqualStrings("sub/inner.db", ok.ok.entries[1].path);
    // the witness reads a kept manifest without its request's nonce
    try t.expect(verify(arena, text, src.public_key, puller, null) == .ok);
    // and the empty directory is a manifest too: a mirror of nothing is not an error
    const none = try build(arena, src, puller, test_nonce_b, "/data/x", &.{});
    try t.expect(verify(arena, none, src.public_key, puller, test_nonce_b) == .ok);
}

test "a manifest that was changed, or is not this source's, or is not for this puller or this request, is refused for its own reason (MIR-1)" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const src = try testPair(1);
    const other = try testPair(3);
    const pul = try testPair(2);
    const puller = journal.fingerprintOf(pul.public_key.toBytes());
    const es = testEntries();
    const text = try build(arena, src, puller, test_nonce_b, "/data/ringserv", &es);

    // a digest changed after it was signed: the file it names would be a lie the signature no longer covers
    const at = std.mem.indexOf(u8, text, "file ").? + "file ".len;
    const swapped = try arena.dupe(u8, text);
    swapped[at] = if (swapped[at] == '0') '1' else '0';
    try t.expect(verify(arena, swapped, src.public_key, puller, test_nonce_b).bad == .bad_signature);
    // a size changed, a path changed
    const sized = try std.mem.replaceOwned(u8, arena, text, " 5 sub/inner.db", " 6 sub/inner.db");
    try t.expect(verify(arena, sized, src.public_key, puller, test_nonce_b).bad == .malformed); // the header's byte total no longer adds up
    const renamed = try std.mem.replaceOwned(u8, arena, text, "top.db", "top.dc");
    try t.expect(verify(arena, renamed, src.public_key, puller, test_nonce_b).bad == .bad_signature);
    // signed by another key
    try t.expect(verify(arena, text, other.public_key, puller, test_nonce_b).bad == .wrong_source);
    // cut for another device, and answering another request
    const pul2 = journal.fingerprintOf((try testPair(4)).public_key.toBytes());
    try t.expect(verify(arena, text, src.public_key, pul2, test_nonce_b).bad == .wrong_puller);
    try t.expect(verify(arena, text, src.public_key, puller, test_nonce_a).bad == .wrong_nonce);
    // cut short: the signature line gone, or only half of it
    const nosig = text[0 .. std.mem.lastIndexOf(u8, text[0 .. text.len - 1], "\n").? + 1];
    try t.expect(verify(arena, nosig, src.public_key, puller, test_nonce_b).bad == .malformed);
    try t.expect(verify(arena, text[0 .. text.len - 20], src.public_key, puller, test_nonce_b).bad == .malformed);
    // something after the signature
    const tail = try std.mem.concat(arena, u8, &.{ text, "file 00 0 x\n" });
    try t.expect(verify(arena, tail, src.public_key, puller, test_nonce_b).bad == .malformed);
    // not a manifest
    try t.expect(verify(arena, "", src.public_key, puller, test_nonce_b).bad == .malformed);
    try t.expect(verify(arena, "GET / HTTP/1.0\r\n\r\n", src.public_key, puller, test_nonce_b).bad == .malformed);
}

test "a manifest has one spelling, and a path that could lead anywhere is not one (MIR-1)" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const src = try testPair(1);
    const puller = [_]u8{'a'} ** 16;
    // paths: the ones a world's directory may hold, and the ones no manifest names
    try t.expect(safeRelPath("a"));
    try t.expect(safeRelPath("sub/inner.db"));
    try t.expect(safeRelPath("a name with spaces/and bytes \xd8\xb3"));
    try t.expect(!safeRelPath(""));
    try t.expect(!safeRelPath("/etc/passwd"));
    try t.expect(!safeRelPath("../outside"));
    try t.expect(!safeRelPath("a/../b"));
    try t.expect(!safeRelPath("a//b"));
    try t.expect(!safeRelPath("a/"));
    try t.expect(!safeRelPath("./a"));
    try t.expect(!safeRelPath("a\nfile 00 0 b"));
    try t.expect(!safeRelPath("a\\b"));
    try t.expect(!safeRelPath("a\x00b"));
    try t.expect(!safeRelPath(&([_]u8{'x'} ** (max_component_bytes + 1))));
    try t.expect(safeDir("/data/ringserv"));
    try t.expect(!safeDir("/data/ring serv"));
    try t.expect(!safeDir("data/ringserv"));
    try t.expect(!safeDir("/"));
    // a name that could begin a line is refused at the source, so no manifest is built from it
    const evil = [_]Entry{.{ .kind = .file, .path = "x\nfile ab 1 y", .size = 1, .digest = digestOf("a") }};
    try t.expectError(error.BadEntries, build(arena, src, puller, test_nonce_b, "/data/x", &evil));
    // out of order, twice, a file above an entry
    const unsorted = [_]Entry{ .{ .kind = .dir, .path = "b" }, .{ .kind = .dir, .path = "a" } };
    try t.expectError(error.BadEntries, build(arena, src, puller, test_nonce_b, "/data/x", &unsorted));
    const twice = [_]Entry{ .{ .kind = .dir, .path = "a" }, .{ .kind = .dir, .path = "a" } };
    try t.expectError(error.BadEntries, build(arena, src, puller, test_nonce_b, "/data/x", &twice));
    const under = [_]Entry{ .{ .kind = .file, .path = "a", .size = 1, .digest = digestOf("a") }, .{ .kind = .file, .path = "a/b", .size = 1, .digest = digestOf("b") } };
    try t.expectError(error.BadEntries, build(arena, src, puller, test_nonce_b, "/data/x", &under));
    try t.expectError(error.UnsafeDir, build(arena, src, puller, test_nonce_b, "/data/a b", &.{}));
    // the same, in a manifest a hostile source signed itself: the puller refuses it however well it is signed
    const hostile = try signedRaw(arena, src, "mirror v1 source={s} puller=" ++ "61" ** 8 ++ " nonce=" ++ "b2" ** 32 ++ " dir=/data/x files=1 bytes=1\nfile " ++ "00" ** 32 ++ " 1 ../escape\nend\n");
    try t.expect(verify(arena, hostile, src.public_key, null, null).bad == .malformed);
    // one spelling: uppercase hex, a signed or zero-led number, a missing field, a field twice
    const good = try signedRaw(arena, src, "mirror v1 source={s} puller=" ++ "61" ** 8 ++ " nonce=" ++ "b2" ** 32 ++ " dir=/data/x files=1 bytes=1\nfile " ++ "ab" ** 32 ++ " 1 f\nend\n");
    try t.expect(verify(arena, good, src.public_key, null, null) == .ok);
    const upper = try signedRaw(arena, src, "mirror v1 source={s} puller=" ++ "61" ** 8 ++ " nonce=" ++ "b2" ** 32 ++ " dir=/data/x files=1 bytes=1\nfile " ++ "AB" ** 32 ++ " 1 f\nend\n");
    try t.expect(verify(arena, upper, src.public_key, null, null).bad == .malformed);
    const zeroled = try signedRaw(arena, src, "mirror v1 source={s} puller=" ++ "61" ** 8 ++ " nonce=" ++ "b2" ** 32 ++ " dir=/data/x files=1 bytes=01\nfile " ++ "ab" ** 32 ++ " 01 f\nend\n");
    try t.expect(verify(arena, zeroled, src.public_key, null, null).bad == .malformed);
    const plus = try signedRaw(arena, src, "mirror v1 source={s} puller=" ++ "61" ** 8 ++ " nonce=" ++ "b2" ** 32 ++ " dir=/data/x files=1 bytes=+1\nfile " ++ "ab" ** 32 ++ " +1 f\nend\n");
    try t.expect(verify(arena, plus, src.public_key, null, null).bad == .malformed);
    const nofield = try signedRaw(arena, src, "mirror v1 source={s} puller=" ++ "61" ** 8 ++ " dir=/data/x files=0 bytes=0\nend\n");
    try t.expect(verify(arena, nofield, src.public_key, null, null).bad == .malformed);
    const v2 = try signedRaw(arena, src, "mirror v2 source={s} puller=" ++ "61" ** 8 ++ " nonce=" ++ "b2" ** 32 ++ " dir=/data/x files=0 bytes=0\nend\n");
    try t.expect(verify(arena, v2, src.public_key, null, null).bad == .malformed);
}

/// A manifest text whose body is `format` (with `{s}` for the source's fingerprint), signed by `pair` as the
/// source would: for the cases where the SOURCE is the one at fault, which `build` would not let it be.
fn signedRaw(alloc: std.mem.Allocator, pair: Ed25519.KeyPair, comptime format: []const u8) ![]u8 {
    const fp = journal.fingerprintOf(pair.public_key.toBytes());
    const body = try std.fmt.allocPrint(alloc, format, .{&fp});
    const sig = try pair.sign(body, null);
    return std.fmt.allocPrint(alloc, "{s}sig={x}\n", .{ body, &sig.toBytes() });
}

test "a request is the puller's word only for the key it was declared for and the challenge it answers (MIR-1)" {
    const t = std.testing;
    const pul = try testPair(2);
    const other = try testPair(5);
    var cb: [max_line]u8 = undefined;
    const ch = try challenge(&cb, test_nonce_a);
    try t.expectEqualStrings("mirror-challenge " ++ "a1" ** 32, ch);
    try t.expectEqual(test_nonce_a, parseChallenge(ch).?);
    try t.expect(parseChallenge("mirror-challenge " ++ "A1" ** 32) == null);
    try t.expect(parseChallenge("mirror-challenge abc") == null);
    try t.expect(parseChallenge("mirror-challenge " ++ "a1" ** 32 ++ "\n\n") == null);

    var rb: [max_line]u8 = undefined;
    const rq = try request(&rb, pul, test_nonce_a, test_nonce_b);
    const r = verifyRequest(rq, pul.public_key, test_nonce_a).?;
    try t.expectEqual(test_nonce_b, r.b);
    // one line end is not part of it
    var nl: [max_line + 2]u8 = undefined;
    try t.expect(verifyRequest(try std.fmt.bufPrint(&nl, "{s}\n", .{rq}), pul.public_key, test_nonce_a) != null);
    // signed by a device the source was not declared to give the copy to: another key, even one that signs well
    // (its own buffer: a request built into `rb` again would overwrite `rq`, and every case below would be judged
    // against the other device's request and refused for its key, whatever it was meant to show)
    var rb2: [max_line]u8 = undefined;
    const mine = try request(&rb2, other, test_nonce_a, test_nonce_b);
    try t.expect(verifyRequest(mine, pul.public_key, test_nonce_a) == null);
    // a request that CLAIMS another key than the one that signed it: the declared device's own signature, over a
    // request that names somebody else, would cut the listing for that somebody
    var lb: [max_line]u8 = undefined;
    const lying_body = try std.fmt.bufPrint(&lb, "mirror-request key={x} a={x} b={x}", .{ &other.public_key.toBytes(), &test_nonce_a, &test_nonce_b });
    const lying_sig = try pul.sign(lying_body, null);
    var lq: [max_line]u8 = undefined;
    const lying = try std.fmt.bufPrint(&lq, "{s} sig={x}", .{ lying_body, &lying_sig.toBytes() });
    try t.expect(verifyRequest(lying, pul.public_key, test_nonce_a) == null);
    // answering another challenge: an old request replayed on a new connection
    try t.expect(verifyRequest(rq, pul.public_key, test_nonce_b) == null);
    // changed after it was signed: the nonce the manifest will carry back
    const edited = try t.allocator.dupe(u8, rq);
    defer t.allocator.free(edited);
    const bat = std.mem.indexOf(u8, edited, " b=").? + 3;
    edited[bat] = if (edited[bat] == '0') '1' else '0';
    try t.expect(verifyRequest(edited, pul.public_key, test_nonce_a) == null);
    // cut short, and not a request
    try t.expect(verifyRequest(rq[0 .. rq.len - 10], pul.public_key, test_nonce_a) == null);
    try t.expect(verifyRequest("GET / HTTP/1.0", pul.public_key, test_nonce_a) == null);
}

fn writeTestFile(dir: std.fs.Dir, path: []const u8, bytes: []const u8) !void {
    if (std.fs.path.dirname(path)) |d| try dir.makePath(d);
    try dir.writeFile(.{ .sub_path = path, .data = bytes });
}

test "a copy is read against its manifest: exactly what it says, and nothing it does not (MIR-1)" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const src = try testPair(1);
    const puller = [_]u8{'c'} ** 16;
    const es = testEntries();
    const text = try build(arena, src, puller, test_nonce_b, "/data/ringserv", &es);
    const m = verify(arena, text, src.public_key, null, null).ok;

    var tmp = t.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try writeTestFile(tmp.dir, "sub/inner.db", "inner");
    try writeTestFile(tmp.dir, "top.db", "top");
    const ok = try verifyCopy(arena, tmp.dir, m);
    // (a copy that is not exactly its manifest says why, in the failure, and not only that it is not)
    if (ok.problem) |why| {
        std.debug.print("the copy is not its manifest: {s}\n", .{why});
        return error.TestUnexpectedResult;
    }
    try t.expectEqual(@as(u64, 2), ok.files);
    try t.expectEqual(@as(u64, 1), ok.dirs);
    try t.expectEqual(@as(u64, 8), ok.bytes);

    // a byte changed: the same size, another digest
    try writeTestFile(tmp.dir, "top.db", "tOp");
    const changed = try verifyCopy(arena, tmp.dir, m);
    try t.expect(std.mem.indexOf(u8, changed.problem.?, "top.db does not match its digest") != null);
    // a file longer than the manifest says
    try writeTestFile(tmp.dir, "top.db", "top!");
    const longer = try verifyCopy(arena, tmp.dir, m);
    try t.expect(std.mem.indexOf(u8, longer.problem.?, "top.db is 4 bytes and the manifest says 3") != null);
    try writeTestFile(tmp.dir, "top.db", "top");
    // a file gone
    try tmp.dir.deleteFile("sub/inner.db");
    const gone = try verifyCopy(arena, tmp.dir, m);
    try t.expect(std.mem.indexOf(u8, gone.problem.?, "sub/inner.db is not there") != null);
    try writeTestFile(tmp.dir, "sub/inner.db", "inner");
    // something the manifest does not list: a file, and a directory
    try writeTestFile(tmp.dir, "extra.txt", "x");
    const extra = try verifyCopy(arena, tmp.dir, m);
    try t.expect(std.mem.indexOf(u8, extra.problem.?, "it holds extra.txt, which the manifest does not list") != null);
    try tmp.dir.deleteFile("extra.txt");
    try tmp.dir.makePath("sub/deeper");
    const deeper = try verifyCopy(arena, tmp.dir, m);
    try t.expect(std.mem.indexOf(u8, deeper.problem.?, "sub/deeper") != null);
    try tmp.dir.deleteDir("sub/deeper");
    // a directory where the manifest has a file
    try tmp.dir.deleteFile("top.db");
    try tmp.dir.makeDir("top.db");
    const wrong_kind = try verifyCopy(arena, tmp.dir, m);
    try t.expect(wrong_kind.problem != null);
}

test "a symbolic link is not a copy of a file, whatever it points at (MIR-1)" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const src = try testPair(1);
    const es = [_]Entry{.{ .kind = .file, .path = "top.db", .size = 3, .digest = digestOf("top") }};
    const text = try build(arena, src, [_]u8{'c'} ** 16, test_nonce_b, "/data/ringserv", &es);
    const m = verify(arena, text, src.public_key, null, null).ok;
    var tmp = t.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    // the bytes are right, and the file is a link to them: the digest matches and the copy is still refused
    try writeTestFile(tmp.dir, "real.bin", "top");
    try tmp.dir.symLink("real.bin", "top.db", .{});
    const r = try verifyCopy(arena, tmp.dir, m);
    try t.expect(std.mem.indexOf(u8, r.problem.?, "symbolic link") != null);
}
