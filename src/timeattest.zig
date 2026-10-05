// timeattest.zig -- time enters a record only as a signed statement (STZ-OS-RULING-07, rung 3).
//
// The floor has no date. The board has no clock of its own and nothing on the boot path sets one, so a
// time written by the machine would be the epoch wearing the authority of a date, and the journal says so
// (journal.zig: no timestamp, deliberately). What the machine can have is somebody else's word: a TIME
// AUTHORITY the fleet declares and enrols like any member, which reads a clock it was declared to have
// and signs, with its device key, one sentence:
//
//   the entry whose digest is D existed no later than T
//
// That is the whole of what a time can mean here. It is an UPPER bound: the authority was shown D, so D
// existed by T; it says nothing about how long before. D is the digest of a record's last entry as it is
// WRITTEN, signature and all (`entryDigest`), and the chain says the rest: every entry's hash covers the one
// before it, so an entry cannot have existed before the entries under it did. What D names is what no
// statement can be earned in advance for: the line carries the device's signature, which nobody without its
// key can produce, so nobody can ask for the time of a line before the line is written. (The entry's own
// `hash=` would not do: it is a hash of public bytes -- the sequence number, the hash before it, the
// machine's name, the digest of its declaration, a verdict -- so anyone could compute the NEXT one today,
// ask for its time, and hold a genuine signature that dates an entry the device has not yet written; and
// two devices that run one machine file with the same verdicts have ONE `hash=` chain and two different
// lines.) A holder of the device's key can still compute its own future lines, and that is the party a
// record is attributed to; a statement about a record proves what it proves about the bytes it names.
//
// It is checked the way every record is, with a public key, by anyone who holds the fleet file (FLT-1): the
// device that asked holds no secret that makes the answer true.
//
// One line, plain text, like a journal entry, because a record a person cannot read is a record nobody
// audits:
//
//   time authority=<16 hex> entry=<64 hex> t=<unix seconds> sig=<128 hex>
//
// `authority` is the fingerprint of the signing key (the same function the journal and the fleet use), `t`
// is the authority's reading in decimal seconds since 1970 UTC, and `sig` is Ed25519 over the exact bytes
// before ` sig=` -- the bytes on the line, not the object they came from (MicroRing's rule, JRN-1's). There
// is ONE spelling of every field (lowercase hex, a time of digits with no sign and no leading zero, one line
// end at most), so two spellings of one statement cannot both verify.
//
// Asked by a datagram, answered by a datagram:
//
//   time? entry=<64 hex>
//
// This file is the statement and its judgement, with no clock and no socket: the same code signs on the
// authority, verifies on the machine that asked and again on an auditor's desk, and its tests are the
// negatives (a changed time, a changed entry, another key, a line cut short, a number spelled another way).

const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;
const Sha256 = std.crypto.hash.sha2.Sha256;
const journal = @import("journal.zig");

pub const entry_len = 64;
pub const max_line = 256;

/// A reading before this is a clock that was never set, or whose battery died, and not a time: the first of
/// the year this seat was built. The authority refuses to sign one (`sign`), and an auditor refuses to take
/// one (`verify`): a statement is an upper bound, and an earlier bound than the truth is a false one.
pub const earliest: i64 = 1_767_225_600; // 2026-01-01 00:00:00 UTC

/// The last second a statement may state: 9999-12-31 23:59:59 UTC, so that every calendar conversion below is
/// in range for anything that verifies, and a number a key holder chose cannot be made to overflow one.
pub const max_t: i64 = 253_402_300_799;

/// The statements a machine keeps are one file beside the record they date: the journal's path and this. The
/// one place that says so, because the machine that writes them (PID 1) and the witness that reads them
/// (`harb journal`) are two programs that must name the same file.
pub const kept_suffix = ".time";

/// One statement, parsed. The fields are views into nothing: fixed arrays, so a statement can be kept.
pub const Statement = struct {
    authority: [16]u8,
    entry: [entry_len]u8,
    t: i64,
    sig: [Ed25519.Signature.encoded_length]u8,
};

/// What judging a line comes to.
pub const Verdict = enum {
    ok,
    /// not a statement at all: a field missing, out of order, spelled another way, or not the length it must be
    malformed,
    /// a statement, signed by somebody else: the fingerprint is not the authority's
    wrong_authority,
    /// a statement from this authority whose signature does not verify: the line was changed after it was signed
    bad_signature,
    /// signed, and states a time before this decade: a clock that was never set
    implausible,

    pub fn words(self: Verdict) []const u8 {
        return switch (self) {
            .ok => "verifies",
            .malformed => "is not a time statement",
            .wrong_authority => "was signed by somebody else than the time authority",
            .bad_signature => "does not verify: it was changed after it was signed, or signed by another key",
            .implausible => "states a time before 2026: its clock was never set, and an upper bound earlier than the truth is not one",
        };
    }
};

fn isHex(s: []const u8) bool {
    for (s) |c| if (!std.ascii.isHex(c) or std.ascii.isUpper(c)) return false;
    return true;
}

/// A line without its end: ONE `\n`, or one `\r\n`, and no more. A statement is a line, and a datagram or a
/// file that carries more than a line end after it is not that statement.
pub fn trimTerminator(line: []const u8) []const u8 {
    var l = line;
    if (l.len > 0 and l[l.len - 1] == '\n') l = l[0 .. l.len - 1];
    if (l.len > 0 and l[l.len - 1] == '\r') l = l[0 .. l.len - 1];
    return l;
}

/// What a statement names about a record: the sha256, in lowercase hex, of the last entry's WHOLE line as it is
/// written -- payload, hash and signature -- without its line end. See the top of this file for why it is not
/// the entry's own `hash=`.
pub fn entryDigest(line: []const u8) [entry_len]u8 {
    var d: [32]u8 = undefined;
    Sha256.hash(trimTerminator(line), &d, .{});
    var out: [entry_len]u8 = undefined;
    _ = std.fmt.bufPrint(&out, "{x}", .{&d}) catch unreachable;
    return out;
}

/// The bytes that are signed: everything on the line before ` sig=`.
pub fn payload(buf: []u8, authority: [16]u8, entry: []const u8, t: i64) ![]const u8 {
    return std.fmt.bufPrint(buf, "time authority={s} entry={s} t={d}", .{ &authority, entry, t });
}

/// Sign `entry` at `t` as `pair`'s fingerprint. Returns the whole line, written into `buf`. A time the verifier
/// would refuse is not signed: the authority and the auditor ask one question.
pub fn sign(buf: []u8, pair: Ed25519.KeyPair, entry: []const u8, t: i64) ![]const u8 {
    if (entry.len != entry_len or !isHex(entry)) return error.NotAnEntry;
    if (t < earliest or t > max_t) return error.NotATime;
    const fp = journal.fingerprintOf(pair.public_key.toBytes());
    var pbuf: [max_line]u8 = undefined;
    const body = try payload(&pbuf, fp, entry, t);
    const sig = try pair.sign(body, null);
    return std.fmt.bufPrint(buf, "{s} sig={x}", .{ body, &sig.toBytes() });
}

/// A time as a statement spells it: decimal digits and nothing else -- no sign, no separator, no leading zero
/// (`parseInt` takes all three, and then two lines would be one statement) -- and a number a calendar can hold.
fn decimal(s: []const u8) ?i64 {
    if (s.len == 0 or s.len > 12) return null;
    for (s) |c| if (c < '0' or c > '9') return null;
    if (s.len > 1 and s[0] == '0') return null;
    const t = std.fmt.parseInt(i64, s, 10) catch return null;
    if (t > max_t) return null;
    return t;
}

/// Parse a line into a statement, or null. Exact and strict: the fields in order, lowercase hex, the lengths
/// they must have, a time spelled one way, one line end at most, nothing after the signature.
pub fn parse(line: []const u8) ?Statement {
    const l = trimTerminator(line);
    if (l.len > max_line) return null;
    var it = std.mem.splitScalar(u8, l, ' ');
    const verb = it.next() orelse return null;
    if (!std.mem.eql(u8, verb, "time")) return null;
    const a = it.next() orelse return null;
    const e = it.next() orelse return null;
    const t_field = it.next() orelse return null;
    const s = it.next() orelse return null;
    if (it.next() != null) return null;
    if (!std.mem.startsWith(u8, a, "authority=") or !std.mem.startsWith(u8, e, "entry=")) return null;
    if (!std.mem.startsWith(u8, t_field, "t=") or !std.mem.startsWith(u8, s, "sig=")) return null;
    const authority = a["authority=".len..];
    const entry = e["entry=".len..];
    const sig_hex = s["sig=".len..];
    if (authority.len != 16 or !isHex(authority)) return null;
    if (entry.len != entry_len or !isHex(entry)) return null;
    if (sig_hex.len != Ed25519.Signature.encoded_length * 2 or !isHex(sig_hex)) return null;
    const t = decimal(t_field["t=".len..]) orelse return null;
    var st: Statement = undefined;
    @memcpy(&st.authority, authority);
    @memcpy(&st.entry, entry);
    st.t = t;
    _ = std.fmt.hexToBytes(&st.sig, sig_hex) catch return null;
    return st;
}

/// Judge a line against the authority's public key: its own, no secret. The signature is checked over the
/// bytes of the line itself, never over a rendering of what was parsed from it.
pub fn verify(line: []const u8, public: Ed25519.PublicKey) Verdict {
    const st = parse(line) orelse return .malformed;
    // (the same trim `parse` made, once: trimming the result again would let a second line end through)
    const l = trimTerminator(line);
    const fp = journal.fingerprintOf(public.toBytes());
    if (!std.mem.eql(u8, &fp, &st.authority)) return .wrong_authority;
    const body = l[0 .. l.len - " sig=".len - Ed25519.Signature.encoded_length * 2];
    Ed25519.Signature.fromBytes(st.sig).verify(body, public) catch return .bad_signature;
    if (st.t < earliest) return .implausible;
    return .ok;
}

/// The datagram that asks: `time? entry=<64 hex>`.
pub fn request(buf: []u8, entry: []const u8) ![]const u8 {
    if (entry.len != entry_len or !isHex(entry)) return error.NotAnEntry;
    return std.fmt.bufPrint(buf, "time? entry={s}", .{entry});
}

/// The entry a datagram asks about, or null if it asks nothing this authority answers.
pub fn parseRequest(datagram: []const u8) ?[entry_len]u8 {
    const d = std.mem.trimRight(u8, datagram, "\r\n\x00");
    const prefix = "time? entry=";
    if (!std.mem.startsWith(u8, d, prefix)) return null;
    const entry = d[prefix.len..];
    if (entry.len != entry_len or !isHex(entry)) return null;
    var out: [entry_len]u8 = undefined;
    @memcpy(&out, entry);
    return out;
}

// ---- the calendar -------------------------------------------------------------------------------
//
// A statement carries seconds, and a person reads a date. The conversion is Howard Hinnant's civil-days
// algorithm, which is exact for every proleptic Gregorian date and needs no table.

pub const Civil = struct { year: i64, month: u8, day: u8, hour: u8, minute: u8, second: u8 };

pub fn civilFromUnix(t: i64) Civil {
    const days = @divFloor(t, 86400);
    const secs: u32 = @intCast(@mod(t, 86400));
    const z = days + 719468;
    const era = @divFloor(z, 146097);
    const doe = z - era * 146097;
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36524) - @divFloor(doe, 146096), 365);
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    const day: u8 = @intCast(doy - @divFloor(153 * mp + 2, 5) + 1);
    const month: u8 = @intCast(if (mp < 10) mp + 3 else mp - 9);
    const y = yoe + era * 400;
    return .{
        .year = if (month <= 2) y + 1 else y,
        .month = month,
        .day = day,
        .hour = @intCast(secs / 3600),
        .minute = @intCast((secs % 3600) / 60),
        .second = @intCast(secs % 60),
    };
}

pub fn unixFromCivil(year: i64, month: u8, day: u8, hour: u8, minute: u8, second: u8) i64 {
    const y = if (month <= 2) year - 1 else year;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const mp: i64 = if (month > 2) month - 3 else month + 9;
    const doy = @divFloor(153 * mp + 2, 5) + day - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    const days = era * 146097 + doe - 719468;
    return days * 86400 + @as(i64, hour) * 3600 + @as(i64, minute) * 60 + second;
}

/// A bound is stated no finer than a person can stand behind it, and no tighter than it is: `t` rounded UP
/// to the minute, as `YYYY-MM-DD HH:MM UTC`. A time the authority read at 12:00:07 is "no later than
/// 12:01", which is true, and a later reading of the same boot is never presented as earlier. A time outside
/// what a statement may state (`max_t`) is refused rather than converted.
pub fn minuteUp(buf: []u8, t: i64) ![]const u8 {
    if (t < 0 or t > max_t) return error.NotATime;
    const up = @divFloor(t + 59, 60) * 60;
    const c = civilFromUnix(up);
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2} UTC", .{ @as(u64, @intCast(c.year)), c.month, c.day, c.hour, c.minute });
}

// ---- tests ---------------------------------------------------------------------------------------

const test_entry = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

fn testPair(seed_byte: u8) !Ed25519.KeyPair {
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, seed_byte);
    return Ed25519.KeyPair.generateDeterministic(seed);
}

test "a statement is signed, parsed and verified with the authority's public key and nothing else (TIME-1)" {
    const pair = try testPair(7);
    var buf: [max_line]u8 = undefined;
    const line = try sign(&buf, pair, test_entry, 1_790_000_000);
    try std.testing.expect(std.mem.startsWith(u8, line, "time authority="));
    const st = parse(line).?;
    try std.testing.expectEqual(@as(i64, 1_790_000_000), st.t);
    try std.testing.expectEqualStrings(test_entry, &st.entry);
    try std.testing.expectEqual(Verdict.ok, verify(line, pair.public_key));
    // one line end is not part of the statement: `\n`, or `\r\n` as a file that crossed a Windows desk has it
    var nl: [max_line + 2]u8 = undefined;
    try std.testing.expectEqual(Verdict.ok, verify(try std.fmt.bufPrint(&nl, "{s}\n", .{line}), pair.public_key));
    try std.testing.expectEqual(Verdict.ok, verify(try std.fmt.bufPrint(&nl, "{s}\r\n", .{line}), pair.public_key));
    // the longest statement there can be fits the line it is kept in
    const longest = try sign(&buf, pair, test_entry, max_t);
    try std.testing.expect(longest.len <= max_line);
    try std.testing.expectEqual(Verdict.ok, verify(longest, pair.public_key));
}

test "a statement that was changed, or is not this authority's, or is cut short, is refused for its own reason (TIME-1)" {
    const pair = try testPair(7);
    const other = try testPair(8);
    var buf: [max_line]u8 = undefined;
    const line = try sign(&buf, pair, test_entry, 1_790_000_000);

    // a time changed after it was signed: the later time would be a lie the signature no longer covers
    var changed: [max_line]u8 = undefined;
    @memcpy(changed[0..line.len], line);
    const at = std.mem.indexOf(u8, line, " t=").? + 3;
    changed[at] = if (changed[at] == '1') '2' else '1';
    try std.testing.expectEqual(Verdict.bad_signature, verify(changed[0..line.len], pair.public_key));

    // an entry changed: a statement about another record, wearing this one's signature
    var reentry: [max_line]u8 = undefined;
    @memcpy(reentry[0..line.len], line);
    const hat = std.mem.indexOf(u8, line, " entry=").? + 7;
    reentry[hat] = if (reentry[hat] == '0') '1' else '0';
    try std.testing.expectEqual(Verdict.bad_signature, verify(reentry[0..line.len], pair.public_key));

    // the same statement judged against another key says whose it is not, before it says anything else
    try std.testing.expectEqual(Verdict.wrong_authority, verify(line, other.public_key));

    // a statement is exactly its five fields: nothing after the signature, and no space where a field ends
    var junk: [max_line + 16]u8 = undefined;
    try std.testing.expectEqual(Verdict.malformed, verify(try std.fmt.bufPrint(&junk, "{s} extra", .{line}), pair.public_key));
    try std.testing.expectEqual(Verdict.malformed, verify(try std.fmt.bufPrint(&junk, "{s}  ", .{line}), pair.public_key));
    // ... and no more than ONE line end: a datagram of a statement and ten newlines is not that statement, and
    // is longer than the buffer a kept statement lives in
    try std.testing.expectEqual(Verdict.malformed, verify(try std.fmt.bufPrint(&junk, "{s}\n\n", .{line}), pair.public_key));
    try std.testing.expectEqual(Verdict.malformed, verify(try std.fmt.bufPrint(&junk, "{s}\r\r\n", .{line}), pair.public_key));
    try std.testing.expectEqual(Verdict.malformed, verify(try std.fmt.bufPrint(&junk, "{s}\n\n\n\n\n\n\n\n\n\n\n\n", .{line}), pair.public_key));

    // a line cut short, and things that are not statements at all
    try std.testing.expectEqual(Verdict.malformed, verify(line[0 .. line.len - 2], pair.public_key));
    try std.testing.expectEqual(Verdict.malformed, verify("", pair.public_key));
    try std.testing.expectEqual(Verdict.malformed, verify("seq=1 prev=- machine=m", pair.public_key));
    // uppercase hex is another spelling of the same bytes, and the signed bytes are the spelling
    var upper: [max_line]u8 = undefined;
    @memcpy(upper[0..line.len], line);
    const sat = std.mem.indexOf(u8, line, " sig=").? + 5;
    for (upper[sat..line.len]) |*c| c.* = std.ascii.toUpper(c.*);
    try std.testing.expectEqual(Verdict.malformed, verify(upper[0..line.len], pair.public_key));
    // a time is spelled one way: `parseInt` takes a sign, leading zeros and underscores, and each would make
    // a second line that verifies as the same statement
    const spellings = [_][]const u8{ "+1790000000", "01790000000", "1_790_000_000", "-0", "1790000000.0", "", "1790000000 ", "0x6aff4a00" };
    for (spellings) |sp| {
        const respelled = try std.fmt.allocPrint(std.testing.allocator, "time authority={s} entry={s} t={s} sig={x}", .{
            journal.fingerprintOf(pair.public_key.toBytes()),
            test_entry,
            sp,
            &(try pair.sign("any bytes at all", null)).toBytes(),
        });
        defer std.testing.allocator.free(respelled);
        std.testing.expectEqual(Verdict.malformed, verify(respelled, pair.public_key)) catch |e| {
            std.debug.print("t={s} is a spelling of a time, and it verified as one\n", .{sp});
            return e;
        };
    }
    // a time no calendar can hold is not a time: the statement would convert through a number that overflows
    const huge = try std.fmt.allocPrint(std.testing.allocator, "time authority={s} entry={s} t=9223372036854775807 sig={x}", .{
        journal.fingerprintOf(pair.public_key.toBytes()),
        test_entry,
        &(try pair.sign("any bytes at all", null)).toBytes(),
    });
    defer std.testing.allocator.free(huge);
    try std.testing.expectEqual(Verdict.malformed, verify(huge, pair.public_key));
    // an entry that is not 64 hex is not asked and not signed, and neither is a time before the clock was set
    try std.testing.expectError(error.NotAnEntry, sign(&buf, pair, "abc", 1_790_000_000));
    try std.testing.expectError(error.NotATime, sign(&buf, pair, test_entry, earliest - 1));
    try std.testing.expectError(error.NotATime, sign(&buf, pair, test_entry, max_t + 1));

    // ... and one that was signed all the same is refused by the one who reads it: an upper bound earlier than the
    // truth is not one, whoever says it
    var pbuf: [max_line]u8 = undefined;
    const early_body = try payload(&pbuf, journal.fingerprintOf(pair.public_key.toBytes()), test_entry, 946_684_800);
    const early = try std.fmt.allocPrint(std.testing.allocator, "{s} sig={x}", .{ early_body, &(try pair.sign(early_body, null)).toBytes() });
    defer std.testing.allocator.free(early);
    try std.testing.expectEqual(Verdict.implausible, verify(early, pair.public_key));
}

test "the question and its answer are one datagram each (TIME-1)" {
    var buf: [128]u8 = undefined;
    const q = try request(&buf, test_entry);
    try std.testing.expectEqualStrings("time? entry=" ++ test_entry, q);
    try std.testing.expectEqualStrings(test_entry, &parseRequest(q).?);
    try std.testing.expect(parseRequest("time? entry=zz") == null);
    // the right length is not enough: an entry is named by a digest, 64 lowercase hex and nothing else
    try std.testing.expect(parseRequest("time? entry=" ++ "zz" ** 32) == null);
    try std.testing.expect(parseRequest("time? entry=" ++ "AB" ** 32) == null);
    try std.testing.expect(parseRequest("GET / HTTP/1.0") == null);
    try std.testing.expect(parseRequest("") == null);
}

test "an entry is named by its whole signed line, which nobody can compute before the device has written it (TIME-1)" {
    const device = try testPair(21);
    const twin = try testPair(22);
    const decl = journal.declarationDigest("one machine file");
    // two devices that run ONE machine file, in the same state, write entries whose `hash=` is the same: the
    // hash covers the sequence number, the hash before, the machine's name, the declaration and the verdict
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const a = try journal.entry(arena, device, .{}, "till", decl, .matched);
    const b = try journal.entry(arena, twin, .{}, "till", decl, .matched);
    const hash_of = struct {
        fn of(line: []const u8) []const u8 {
            const at = std.mem.indexOf(u8, line, " hash=").? + " hash=".len;
            return line[at .. at + 64];
        }
    }.of;
    try std.testing.expectEqualStrings(hash_of(a), hash_of(b));
    // ... and the digest a statement names is not: it covers the signature, which only the device can make
    try std.testing.expect(!std.mem.eql(u8, &entryDigest(a), &entryDigest(b)));
    // the digest is of the line and not of its end: the file's `\n` is not part of it
    try std.testing.expectEqualStrings(&entryDigest(a), &entryDigest(std.mem.trimRight(u8, a, "\n")));
    // and it is not the entry's own hash
    try std.testing.expect(!std.mem.eql(u8, &entryDigest(a), hash_of(a)));
}

test "a statement is not a journal entry, though the same key signs both (TIME-1)" {
    const device = try testPair(31);
    var buf: [max_line]u8 = undefined;
    // anybody may ask the authority for a statement about a digest of their own choosing
    const line = try sign(&buf, device, test_entry, 1_790_000_000);
    // ... and dress it as an entry of the authority's own record: the payload is the statement's bytes, whose
    // signature the key really made, with a hash, a `prev` and the signature after them
    const st = parse(line).?;
    var body: [max_line]u8 = undefined;
    const payload_bytes = try payload(&body, st.authority, &st.entry, st.t);
    var digest: [32]u8 = undefined;
    Sha256.hash(payload_bytes, &digest, .{});
    var forged: [4 * max_line]u8 = undefined;
    const forged_line = try std.fmt.bufPrint(&forged, "{s} hash={x} prev=- sig={x}", .{ payload_bytes, &digest, &st.sig });
    try std.testing.expect(journal.verify(forged_line, device.public_key).broken_at != null);
    try std.testing.expect(!journal.firstSignedBy(forged_line, device.public_key));
}

test "the calendar is exact: known instants, a leap day, the epoch, and the round trip (TIME-1)" {
    const t = std.testing;
    const c0 = civilFromUnix(0);
    try t.expectEqual(@as(i64, 1970), c0.year);
    try t.expectEqual(@as(u8, 1), c0.month);
    try t.expectEqual(@as(u8, 1), c0.day);
    // three instants everyone knows
    const c1 = civilFromUnix(1_000_000_000);
    try t.expectEqual(@as(i64, 2001), c1.year);
    try t.expectEqual(@as(u8, 9), c1.month);
    try t.expectEqual(@as(u8, 9), c1.day);
    try t.expectEqual(@as(u8, 1), c1.hour);
    try t.expectEqual(@as(u8, 46), c1.minute);
    try t.expectEqual(@as(u8, 40), c1.second);
    const c2 = civilFromUnix(1_700_000_000);
    try t.expectEqual(@as(i64, 2023), c2.year);
    try t.expectEqual(@as(u8, 11), c2.month);
    try t.expectEqual(@as(u8, 14), c2.day);
    try t.expectEqual(@as(u8, 22), c2.hour);
    const c3 = civilFromUnix(2_000_000_000);
    try t.expectEqual(@as(i64, 2033), c3.year);
    try t.expectEqual(@as(u8, 5), c3.month);
    try t.expectEqual(@as(u8, 18), c3.day);
    // a leap day, and the day after a century that is not one
    const leap = civilFromUnix(unixFromCivil(2000, 2, 29, 12, 0, 0));
    try t.expectEqual(@as(u8, 2), leap.month);
    try t.expectEqual(@as(u8, 29), leap.day);
    try t.expectEqual(@as(i64, 951_825_600), unixFromCivil(2000, 2, 29, 12, 0, 0));
    const after1900 = civilFromUnix(unixFromCivil(1900, 2, 28, 0, 0, 0) + 86400);
    try t.expectEqual(@as(u8, 3), after1900.month); // 1900 was not a leap year
    try t.expectEqual(@as(u8, 1), after1900.day);
    // and every second of an arbitrary stretch round-trips
    var x: i64 = 1_700_000_000;
    while (x < 1_700_000_000 + 400 * 86400) : (x += 3607) {
        const c = civilFromUnix(x);
        try t.expectEqual(x, unixFromCivil(c.year, c.month, c.day, c.hour, c.minute, c.second));
    }
    // the last second a statement may state is the last of the last year the calendar prints in four digits
    try t.expectEqual(unixFromCivil(9999, 12, 31, 23, 59, 59), max_t);
    // the constant that says where a clock that was never set stops is the first second of the year it says
    try t.expectEqual(unixFromCivil(2026, 1, 1, 0, 0, 0), earliest);
}

test "a bound is stated rounded UP to the minute (TIME-1)" {
    var buf: [32]u8 = undefined;
    const base = unixFromCivil(2026, 10, 5, 12, 0, 0);
    try std.testing.expectEqualStrings("2026-10-05 12:00 UTC", try minuteUp(&buf, base));
    try std.testing.expectEqualStrings("2026-10-05 12:01 UTC", try minuteUp(&buf, base + 1));
    try std.testing.expectEqualStrings("2026-10-05 12:01 UTC", try minuteUp(&buf, base + 60));
    try std.testing.expectEqualStrings("2026-10-05 12:02 UTC", try minuteUp(&buf, base + 61));
    try std.testing.expectEqualStrings("2026-10-06 00:00 UTC", try minuteUp(&buf, unixFromCivil(2026, 10, 5, 23, 59, 30)));
    // the last second there is, and no further: a number past it is refused, never converted
    try std.testing.expectEqualStrings("9999-12-31 23:59 UTC", try minuteUp(&buf, max_t - 59));
    try std.testing.expectError(error.NotATime, minuteUp(&buf, max_t + 1));
    try std.testing.expectError(error.NotATime, minuteUp(&buf, std.math.maxInt(i64)));
    try std.testing.expectError(error.NotATime, minuteUp(&buf, -1));
}
