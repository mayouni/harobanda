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

/// Write one entry, chained to whatever is already there. The caller has
/// verified first: a chain that does not verify is never extended, because
/// an entry appended after a broken one would launder the break.
pub fn append(
    path: []const u8,
    pair: Ed25519.KeyPair,
    check: Check,
    machine_name: []const u8,
    declaration: [16]u8,
    verdict: Verdict,
) !usize {
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

    var line_buf: [1024]u8 = undefined;
    const line = try std.fmt.bufPrint(&line_buf, "{s} hash={s} sig={x}\n", .{ payload, hash[0..], &sig_bytes });

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

    // ALTER the second entry's payload: one word, the verdict, which is
    // exactly the field someone would want to change
    const tampered = try std.mem.replaceOwned(u8, alloc, text, "seq=2 prev=", "seq=2 prev=");
    alloc.free(text);
    defer alloc.free(tampered);
    const with_lie = try std.mem.replaceOwned(u8, alloc, tampered, "verdict=matched hash", "verdict=perfect hash");
    defer alloc.free(with_lie);
    const broken = verify(with_lie, pair.public_key);
    try std.testing.expect(broken.broken_at != null);
    try std.testing.expect(broken.verified < 3);

    // ... and a signature from another device is refused as well
    const other = Ed25519.KeyPair.generate();
    const foreign = verify(with_lie, other.public_key);
    try std.testing.expect(foreign.broken_at != null);
}
