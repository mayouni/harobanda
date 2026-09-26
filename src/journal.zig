// journal.zig -- the machine's own boot record: hash-chained, signed by
// this device's key, and never rewritten (JRN-1).
//
// WHOSE RECORD THIS IS, said first, because the scope is the design.
// This is the FLOOR's journal, not a world's. It records what the
// machine was and what it judged of itself: one line per boot, carrying
// the declaration that ran and the verdict PID 1 reached. It does NOT
// record orders, payments or any business fact -- what a record IS
// belongs to the world that keeps it, and a machine that invented that
// would be inventing its customer's domain.
//
// The two compose exactly as MicroRing's identity design says they do:
// a device signature attributes a record BEFORE it enters any ledger,
// and a chain orders records WITHIN one. A world's journal of signed
// records sits above this one; neither replaces the other.
//
// The ground is a real constraint: French anti-fraud law requires
// cash-register software to guarantee inalterability, security,
// retention and archiving. Inalterability does not mean a record cannot
// be changed -- any file can be changed -- it means a change cannot go
// UNNOTICED. That is what a chain buys, and it is the whole claim here:
// every entry carries the hash of the one before it, so altering entry
// two breaks entry three's chain, and the signature makes the entry
// itself the device's word rather than anyone's.
//
// The format is plain text, one entry per line, because the estate's
// law is that a record a person cannot read is a record nobody audits:
//
//   seq=1 prev=- machine=makeen_box declaration=<16 hex> verdict=matched hash=<64 hex> sig=<128 hex>
//
// `hash` is sha256 of everything before " hash=" on that line, and
// `sig` is Ed25519 over those same bytes -- the exact bytes on the line,
// not the object they came from, which is MicroRing's rule and removes
// the class of bug where two spellings of one record verify differently.
//
// No timestamp, deliberately. The board has no clock of its own and
// nothing on the boot path sets one, so a time in this file would be
// the epoch wearing the authority of a date. The SEQUENCE is the order.
// A trusted clock is a named seam, and the day one exists the field can
// be added to the end of the payload without moving anything.

const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const Verdict = enum {
    matched,
    differed,
    unjudged,

    pub fn text(self: Verdict) []const u8 {
        return @tagName(self);
    }
};

pub const Check = struct {
    /// how many entries verified, in order, from the first
    verified: usize = 0,
    /// the entry that failed, by its position in the file (1-based)
    broken_at: ?usize = null,
    /// why it failed, in words
    reason: []const u8 = "",
    /// the hash of the last verified entry, for the next one to chain to
    last_hash: [64]u8 = [_]u8{'-'} ** 64,
    has_last: bool = false,
};

fn hex64(bytes: [32]u8) [64]u8 {
    var out: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&out, "{x}", .{&bytes}) catch unreachable;
    return out;
}

fn field(line: []const u8, name: []const u8) ?[]const u8 {
    var it = std.mem.splitScalar(u8, line, ' ');
    while (it.next()) |part| {
        if (std.mem.startsWith(u8, part, name) and part.len > name.len and part[name.len] == '=') {
            return part[name.len + 1 ..];
        }
    }
    return null;
}

/// Walk the chain and say where it breaks, if it does. Every entry owes
/// three things: its own hash over its own bytes, a `prev` that is the
/// entry before it, and a signature this device's public key accepts.
pub fn verify(text: []const u8, public: Ed25519.PublicKey) Check {
    var c = Check{};
    var it = std.mem.splitScalar(u8, text, '\n');
    var n: usize = 0;
    while (it.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len == 0) continue;
        n += 1;

        const cut = std.mem.indexOf(u8, line, " hash=") orelse {
            c.broken_at = n;
            c.reason = "the entry carries no hash";
            return c;
        };
        const payload = line[0..cut];

        const hash_field = field(line, "hash") orelse {
            c.broken_at = n;
            c.reason = "the entry carries no hash";
            return c;
        };
        var digest: [32]u8 = undefined;
        Sha256.hash(payload, &digest, .{});
        const want = hex64(digest);
        if (hash_field.len != 64 or !std.mem.eql(u8, hash_field[0..64], &want)) {
            c.broken_at = n;
            c.reason = "the entry's own bytes do not hash to the hash it carries: it was altered after it was written";
            return c;
        }

        const prev = field(line, "prev") orelse {
            c.broken_at = n;
            c.reason = "the entry carries no prev";
            return c;
        };
        if (n == 1) {
            if (!std.mem.eql(u8, prev, "-")) {
                c.broken_at = n;
                c.reason = "the first entry claims a predecessor";
                return c;
            }
        } else if (!c.has_last or prev.len != 64 or !std.mem.eql(u8, prev, &c.last_hash)) {
            c.broken_at = n;
            c.reason = "the entry does not chain to the one before it: an entry was removed, reordered or replaced";
            return c;
        }

        const sig_field = field(line, "sig") orelse {
            c.broken_at = n;
            c.reason = "the entry carries no signature";
            return c;
        };
        if (sig_field.len != 128) {
            c.broken_at = n;
            c.reason = "the signature is not the length a signature has";
            return c;
        }
        var sig_bytes: [64]u8 = undefined;
        _ = std.fmt.hexToBytes(&sig_bytes, sig_field[0..128]) catch {
            c.broken_at = n;
            c.reason = "the signature is not hexadecimal";
            return c;
        };
        const sig = Ed25519.Signature.fromBytes(sig_bytes);
        sig.verify(payload, public) catch {
            c.broken_at = n;
            c.reason = "this device's key did not sign this entry";
            return c;
        };

        c.verified = n;
        c.last_hash = want;
        c.has_last = true;
    }
    return c;
}

/// How many entries a record carries. A record of none is not a record
/// of anything, and an attribution of it is not an attribution: the
/// verifier refuses it rather than saying "0 entries verified" and
/// exiting 0, which is what it did until the real-device arc lost its
/// record and all three of its negatives passed as verified (RET-1).
pub fn entryCount(text: []const u8) usize {
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw| {
        if (std.mem.trimRight(u8, raw, "\r").len > 0) n += 1;
    }
    return n;
}

/// Whether this key signed the FIRST entry. A chain has one signer, so
/// its first entry says whose chain it is -- which is how a fleet picks,
/// among the keys a member has held, the one to hear a record under
/// (RET-1). Only the signature is asked about: whether the entry was
/// altered, or chains, is `verify`'s to say once the key is known.
pub fn firstSignedBy(text: []const u8, public: Ed25519.PublicKey) bool {
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len == 0) continue;
        const cut = std.mem.indexOf(u8, line, " hash=") orelse return false;
        const sig_field = field(line, "sig") orelse return false;
        if (sig_field.len != 128) return false;
        var sig_bytes: [64]u8 = undefined;
        _ = std.fmt.hexToBytes(&sig_bytes, sig_field[0..128]) catch return false;
        Ed25519.Signature.fromBytes(sig_bytes).verify(line[0..cut], public) catch return false;
        return true;
    }
    return false;
}

/// A chain heard under a key the device no longer holds, trusted exactly
/// as far as the fleet trusts that key: THROUGH the entry whose hash is
/// the retirement's head, and not one entry further (RET-1).
pub const Through = struct {
    /// the chain as `verify` sees it, CUT at the head: anything after the
    /// head is broken at head + 1, however well it chains
    check: Check,
    /// where the head sits in the record, if the record reaches it
    head_at: ?usize,
    /// entries past the head that the retired key really did sign --
    /// evidence that whoever still holds it went on signing
    signed_after: usize,

    /// the record IS the chain the fleet vouched for: entire, and ending
    /// exactly at its head
    pub fn kept(self: Through) bool {
        return self.check.broken_at == null and self.head_at != null;
    }
};

/// Clock-free by construction. An entry's hash covers its `prev`, so one
/// hash fixes every entry before it: whoever still holds a retired key can
/// go on signing, but only by EXTENDING the chain, and an extension is
/// exactly what this refuses. No date is needed to say "after" -- the
/// sequence is the order, the same answer this file already gives to
/// having no clock.
///
/// A record that never REACHES the head is not trusted either, even when
/// every entry in it verifies. A shorter chain the device really wrote,
/// and a different chain the key's holder wrote since, both verify under
/// the key; only reaching the head tells them apart.
pub fn verifyThrough(text: []const u8, public: Ed25519.PublicKey, head: []const u8) Through {
    var c = verify(text, public);
    var head_at: ?usize = null;
    var entries: usize = 0;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len == 0) continue;
        entries += 1;
        // only a VERIFIED entry's hash can be the head: an unverified one
        // carries whatever hash its author liked
        if (head_at == null and entries <= c.verified) {
            if (field(line, "hash")) |h| {
                if (std.mem.eql(u8, h, head)) head_at = entries;
            }
        }
    }
    var after: usize = 0;
    if (head_at) |p| {
        if (entries > p) {
            after = c.verified - p;
            c.verified = p;
            c.broken_at = p + 1;
            c.reason = "it comes after the entry the fleet trusts this retired key through, and nothing after that entry is the key's to vouch for";
        }
    }
    return .{ .check = c, .head_at = head_at, .signed_after = after };
}

/// Write one entry, chained to whatever is already there. The caller has
/// verified first: a chain that does not verify is never extended, because
/// an entry appended after a broken one would launder the break.
/// One entry, formatted and signed, as the exact bytes that go on the
/// line. Worded ONCE here: `verify` reads back what this writes, and two
/// spellings of one record would verify differently (MicroRing's rule --
/// a signature is over the bytes, not over the object they came from).
pub fn entry(
    arena: std.mem.Allocator,
    pair: Ed25519.KeyPair,
    check: Check,
    machine_name: []const u8,
    declaration: [16]u8,
    verdict: Verdict,
) ![]const u8 {
    const seq = check.verified + 1;
    var payload_buf: [512]u8 = undefined;
    const payload = try std.fmt.bufPrint(&payload_buf, "seq={d} prev={s} machine={s} declaration={s} verdict={s}", .{
        seq,
        if (check.has_last) check.last_hash[0..] else "-",
        machine_name,
        declaration[0..],
        verdict.text(),
    });

    var digest: [32]u8 = undefined;
    Sha256.hash(payload, &digest, .{});
    const hash = hex64(digest);
    const sig = try pair.sign(payload, null);
    const sig_bytes = sig.toBytes();

    return std.fmt.allocPrint(arena, "{s} hash={s} sig={x}\n", .{ payload, hash[0..], &sig_bytes });
}

/// The fingerprint a public key implies: the same 16 hex a device prints
/// on its own console at every boot, so an enrolled key and a booting
/// device can be compared by eye (IDN-1, shared with the fleet at FLT-1).
pub fn fingerprintOf(public: [32]u8) [16]u8 {
    var digest: [32]u8 = undefined;
    Sha256.hash(&public, &digest, .{});
    var hex: [16]u8 = undefined;
    _ = std.fmt.bufPrint(&hex, "{x}", .{digest[0..8]}) catch unreachable;
    return hex;
}

pub fn append(
    path: []const u8,
    pair: Ed25519.KeyPair,
    check: Check,
    machine_name: []const u8,
    declaration: [16]u8,
    verdict: Verdict,
) !usize {
    const seq = check.verified + 1;
    var buf: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const line = try entry(fba.allocator(), pair, check, machine_name, declaration, verdict);

    const f = std.fs.cwd().openFile(path, .{ .mode = .write_only }) catch |e| switch (e) {
        error.FileNotFound => try std.fs.cwd().createFile(path, .{ .mode = 0o600 }),
        else => return e,
    };
    defer f.close();
    try f.seekFromEnd(0);
    try f.writeAll(line);
    f.sync() catch {};
    return seq;
}

/// The digest of the declaration that ran, which is what makes an entry
/// say WHICH machine booted rather than only which name it went by.
pub fn declarationDigest(text: []const u8) [16]u8 {
    var digest: [32]u8 = undefined;
    Sha256.hash(text, &digest, .{});
    var hex: [16]u8 = undefined;
    _ = std.fmt.bufPrint(&hex, "{x}", .{digest[0..8]}) catch unreachable;
    return hex;
}

// ---- the chain, judged: a break must be found, and named -------------

test "a chain verifies, and an altered entry is named by its position" {
    const alloc = std.testing.allocator;
    const pair = Ed25519.KeyPair.generate();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(path);
    const file = try std.fs.path.join(alloc, &.{ path, "boot.journal" });
    defer alloc.free(file);

    const decl = declarationDigest("DEFINE MACHINE m AS (...)");
    var check = Check{};
    var seq = try append(file, pair, check, "m", decl, .matched);
    try std.testing.expectEqual(@as(usize, 1), seq);

    var text = try std.fs.cwd().readFileAlloc(alloc, file, 1 << 16);
    check = verify(text, pair.public_key);
    alloc.free(text);
    try std.testing.expectEqual(@as(usize, 1), check.verified);
    try std.testing.expectEqual(@as(?usize, null), check.broken_at);

    seq = try append(file, pair, check, "m", decl, .matched);
    try std.testing.expectEqual(@as(usize, 2), seq);
    text = try std.fs.cwd().readFileAlloc(alloc, file, 1 << 16);
    check = verify(text, pair.public_key);
    alloc.free(text);
    try std.testing.expectEqual(@as(usize, 2), check.verified);

    seq = try append(file, pair, check, "m", decl, .differed);
    try std.testing.expectEqual(@as(usize, 3), seq);
    text = try std.fs.cwd().readFileAlloc(alloc, file, 1 << 16);
    check = verify(text, pair.public_key);
    try std.testing.expectEqual(@as(usize, 3), check.verified);
    try std.testing.expectEqual(@as(?usize, null), check.broken_at);

    // ALTER ONLY THE SECOND ENTRY: one word, the verdict, which is
    // exactly the field someone would want to change.
    //
    // Line by line, and not with a replace over the whole text: entries
    // ONE and TWO both say verdict=matched, so a whole-text replace
    // altered both and the chain broke at 1 while this test's name --
    // "named by its position" -- claimed it was about 2. It also
    // asserted only that SOMETHING was wrong. A test that does not check
    // the position cannot be the test that the position is right
    // (read for LRN-1's lesson 13).
    var tampered: std.ArrayList(u8) = .{};
    defer tampered.deinit(alloc);
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "seq=2 ")) {
            const lie = try std.mem.replaceOwned(u8, alloc, line, "verdict=matched", "verdict=perfect");
            defer alloc.free(lie);
            try tampered.appendSlice(alloc, lie);
        } else {
            try tampered.appendSlice(alloc, line);
        }
        try tampered.append(alloc, '\n');
    }
    alloc.free(text);

    const broken = verify(tampered.items, pair.public_key);
    // the POSITION, because that is what this test is named for
    try std.testing.expectEqual(@as(?usize, 2), broken.broken_at);
    // entry one still verifies: the break is where the lie is, not before it
    try std.testing.expectEqual(@as(usize, 1), broken.verified);
    // and the REASON, in the machine's own words
    try std.testing.expect(std.mem.indexOf(u8, broken.reason, "do not hash to the hash it carries") != null);

    // ... and a signature from another device is refused as well, at the
    // FIRST entry, because no entry of this chain is that device's
    const other = Ed25519.KeyPair.generate();
    const foreign = verify(tampered.items, other.public_key);
    try std.testing.expectEqual(@as(?usize, 1), foreign.broken_at);
    try std.testing.expectEqual(@as(usize, 0), foreign.verified);
}
