//! `harb time verify <fleet-file> <statements> [<record>]` -- time, checked by something that never held the
//! secret (TIME-1, STZ-OS-RULING-07).
//!
//! A machine's record is ORDERED and UNDATED: the sequence is the order, and nothing on the floor can say
//! what day it is. What dates it is an authority's statement -- "the entry whose digest is D existed no
//! later than T" -- and this is the whole of how a statement is trusted: a public key (the FLEET holds it,
//! because the authority is enrolled like any member; the machine that asked holds it as TIME_KEY), a
//! signature, and a digest. No secret takes part, so anyone with the key can run it: another machine, the
//! court, an auditor years from now -- with the fleet file as it was when the authority's key was the one
//! enrolled: an authority's key that was replaced takes its statements with it, there being no retirement for
//! an authority as there is for a device (RET-1).
//!
//! Given a record it does the second half. A statement names an entry by the digest of its whole written line
//! (`timeattest.entryDigest`: signature and all, so nobody can ask for the time of a line before the device has
//! written it, and two devices with one machine file have two), so it dates that line and, by the chain, what
//! every entry before it SAYS (each entry's hash covers the one before it, so the entry cannot have existed
//! before the entries under it did). An entry's best bound is the EARLIEST statement at or after it; an entry
//! after the last statement is ORDERED and UNDATED, in those words, because that is what is true of it -- a
//! time it cannot stand behind is not printed.
//!
//! A statement about an entry the record does not REACH is refused, and that is a finding and not a nicety: a
//! record can be cut at its end and still hash and chain perfectly, and the only thing that says it used to be
//! longer is somebody else's word about a line it no longer has.
//!
//! Two callers, ONE reading (`read`): the verb below, with the key from the fleet, and `harb journal`, from
//! inside the machine that asked, with the key it was declared to take the answer from. A second reading would
//! have to agree with the first, and would not.
//!
//! What is checked of the record is that its entries are shaped like entries, hash to what they say and are
//! chained to each other. That each entry was signed by the DEVICE is `harb fleet <file> verify <member>
//! <record>`, which needs the device's enrolled key; this needs only the authority's. Two questions, two keys,
//! two verbs.

const std = @import("std");
const fleet = @import("fleet.zig");
const journal = @import("journal.zig");
const timeattest = @import("timeattest.zig");
const Ed25519 = std.crypto.sign.Ed25519;
const Sha256 = std.crypto.hash.sha2.Sha256;

/// One entry of a record, as far as it can be judged without the device's key: its place, and the digest a
/// statement names it by.
const Entry = struct { seq: usize, digest: [64]u8 };

/// A line of an export without the word an export puts before it (`record `, `statement `).
fn bare(line: []const u8, prefix: []const u8) []const u8 {
    const l = std.mem.trimRight(u8, line, "\r\n");
    return if (std.mem.startsWith(u8, l, prefix)) l[prefix.len..] else l;
}

fn lowerHexOf(out: *[64]u8, digest: [32]u8) void {
    _ = std.fmt.bufPrint(out, "{x}", .{&digest}) catch unreachable;
}

/// Read a record into its entries, judging only what needs no key: each entry is shaped like one, hashes to what
/// it says, and is chained to the one before it -- the questions `journal.verify` asks before it asks about the
/// signature, answered the same way. Returns the entries, or null after saying why not.
fn readRecord(arena: std.mem.Allocator, text: []const u8, out: *std.Io.Writer) !?[]const Entry {
    var entries: std.ArrayList(Entry) = .{};
    var it = std.mem.splitScalar(u8, text, '\n');
    var prev: [64]u8 = [_]u8{'-'} ** 64;
    while (it.next()) |raw| {
        const line = bare(raw, "record ");
        if (line.len == 0) continue;
        const n = entries.items.len + 1;
        const cut = std.mem.indexOf(u8, line, " hash=") orelse {
            try out.print("time: record entry {d} carries no hash: it is not a record entry\n", .{n});
            return null;
        };
        if (!journal.entryShaped(line[0..cut], n)) {
            try out.print("time: record entry {d} is not the entry this place holds (seq=<its place> prev=...): an entry was removed, reordered or replaced, or this line is not an entry at all\n", .{n});
            return null;
        }
        const after = line[cut + " hash=".len ..];
        const hash_text = after[0 .. std.mem.indexOfScalar(u8, after, ' ') orelse after.len];
        var digest: [32]u8 = undefined;
        Sha256.hash(line[0..cut], &digest, .{});
        var want: [64]u8 = undefined;
        lowerHexOf(&want, digest);
        if (!std.mem.eql(u8, hash_text, &want)) {
            try out.print("time: record entry {d} does not hash to what it says: it was changed after it was written\n", .{n});
            return null;
        }
        // chained: `prev=-` for the first entry, and the hash of the one before for every other
        const pfield = blk: {
            var f = std.mem.splitScalar(u8, line, ' ');
            while (f.next()) |part| if (std.mem.startsWith(u8, part, "prev=")) break :blk part["prev=".len..];
            break :blk "";
        };
        const expect_prev: []const u8 = if (n == 1) "-" else &prev;
        if (!std.mem.eql(u8, pfield, expect_prev)) {
            try out.print("time: record entry {d} is not chained to the one before it: an entry was removed, reordered or replaced\n", .{n});
            return null;
        }
        try entries.append(arena, .{ .seq = n, .digest = timeattest.entryDigest(line) });
        prev = want;
    }
    return try entries.toOwnedSlice(arena);
}

/// What reading a set of statements came to.
pub const Reading = struct {
    /// the statements the file held: every line that is not blank
    statements: usize = 0,
    /// the ones that were not taken: they did not verify, or they are about an entry the record does not hold
    refused: usize = 0,
    /// false when the record itself did not hash and chain, or held nothing: no statement was bound to it
    record_ok: bool = true,
    /// pairs of statements that cannot both be right about a clock that runs forward: a later entry dated earlier
    /// than an earlier one. Said, never refused: each statement is still an upper bound, and the earlier of two is
    /// the tighter, so what is printed of the entries stays true -- but an auditor is owed the sentence
    backwards: usize = 0,

    /// every statement was taken, and the record, if one was given, is one
    pub fn clean(self: Reading) bool {
        return self.record_ok and self.refused == 0;
    }
};

/// Judge `statements` against the authority's public key and, if a record is given, bind each to the entry its
/// digest names. Prints what it found, one line each, and returns the count; the caller decides what that means
/// for its own exit code (a verification of nothing is the verb's to refuse, and a witness's to report).
pub fn read(
    arena: std.mem.Allocator,
    out: *std.Io.Writer,
    key: Ed25519.PublicKey,
    statements: []const u8,
    record: ?[]const u8,
) !Reading {
    var r = Reading{};
    var entries: ?[]const Entry = null;
    if (record) |text| {
        const es = (try readRecord(arena, text, out)) orelse {
            r.record_ok = false;
            return r;
        };
        if (es.len == 0) {
            try out.print("time: the record holds no entry: there is nothing here for a statement to be about\n", .{});
            r.record_ok = false;
            return r;
        }
        entries = es;
        try out.print("time: the record has {d} entr{s}, each shaped like one, hashing to what it says and chained to the one before it\n", .{ es.len, if (es.len == 1) "y" else "ies" });
    }

    // every statement, judged; the best bound each entry gets is the earliest statement at or after it
    const have = if (entries) |es| es.len else 0;
    const bound = try arena.alloc(?i64, have);
    @memset(bound, null);
    const bound_by = try arena.alloc(usize, have);
    const Seen = struct { idx: usize, t: i64, n: usize };
    var seen: std.ArrayList(Seen) = .{};
    var lines = std.mem.splitScalar(u8, statements, '\n');
    while (lines.next()) |raw| {
        const line = bare(raw, "statement ");
        if (line.len == 0) continue;
        r.statements += 1;
        const n = r.statements;
        const verdict = timeattest.verify(line, key);
        if (verdict != .ok) {
            try out.print("time: statement {d} {s}\n", .{ n, verdict.words() });
            r.refused += 1;
            continue;
        }
        const st = timeattest.parse(line).?;
        var tb: [32]u8 = undefined;
        try out.print("time: statement {d} verifies -- the entry {s} existed no later than {s}\n", .{ n, st.entry[0..8], try timeattest.minuteUp(&tb, st.t) });
        const es = entries orelse continue;
        var at: ?usize = null;
        for (es, 0..) |e, i| if (std.mem.eql(u8, &e.digest, &st.entry)) {
            at = i;
        };
        const idx = at orelse {
            try out.print("time: statement {d} is about an entry this record does not hold: it is another record's, or entries were cut from the end of this one\n", .{n});
            r.refused += 1;
            continue;
        };
        try out.print("time:   that is entry {d} of {d}: it, and every entry before it, existed no later than then\n", .{ es[idx].seq, es.len });
        // a clock runs forward: an entry written LATER and dated EARLIER than one before it is a clock that went
        // backwards between the two, or a statement that is wrong -- in whatever order the file keeps them
        for (seen.items) |p| {
            const later_earlier = p.idx < idx and p.t > st.t; // this one is about the later entry, and dated before
            const earlier_later = p.idx > idx and p.t < st.t; // this one is about the earlier entry, and dated after
            if (!later_earlier and !earlier_later) continue;
            var pb: [32]u8 = undefined;
            try out.print("time:   it and statement {d} ({s}) cannot both be right of a clock that runs forward: the entry written later is dated earlier -- the authority's clock went backwards between them, or one of them is wrong\n", .{ p.n, try timeattest.minuteUp(&pb, p.t) });
            r.backwards += 1;
            break;
        }
        try seen.append(arena, .{ .idx = idx, .t = st.t, .n = n });
        // a later statement can only be looser than an earlier one about the same entry
        for (0..idx + 1) |i| {
            if (bound[i] == null or st.t < bound[i].?) {
                bound[i] = st.t;
                bound_by[i] = n;
            }
        }
    }
    if (r.statements == 0) {
        if (entries != null) {
            try out.print("time: no statement is kept: every entry of this record is ORDERED and UNDATED\n", .{});
        } else {
            try out.print("time: no statement is kept: nothing here says when anything happened\n", .{});
        }
        return r;
    }
    if (entries) |es| for (es, 0..) |e, i| {
        if (bound[i]) |t| {
            var tb: [32]u8 = undefined;
            try out.print("time: entry {d} existed no later than {s} (statement {d})\n", .{ e.seq, try timeattest.minuteUp(&tb, t), bound_by[i] });
        } else {
            try out.print("time: entry {d} is ORDERED and UNDATED: no statement is about it, or about any entry after it\n", .{e.seq});
        }
    };
    return r;
}

/// The verb. Returns what `harb` exits with: 0 only if at least one statement was read, every statement
/// verifies against the fleet's authority and, when a record is given, belongs to it.
pub fn run(arena: std.mem.Allocator, args: []const []const u8, out: *std.Io.Writer) !u8 {
    if (args.len < 2 or args.len > 3) {
        try out.print("harb: time verify takes a fleet file, a file of statements and, optionally, the record they date\n", .{});
        return 1;
    }
    const fleet_path = args[0];
    const src = std.fs.cwd().readFileAlloc(arena, fleet_path, 1 << 20) catch |e| {
        try out.print("harb: cannot read {s}: {s}\n", .{ fleet_path, @errorName(e) });
        return 1;
    };
    const disk = fleet.Disk{ .arena = arena, .base = std.fs.path.dirname(fleet_path) orelse "" };
    var refusal = fleet.Refusal{};
    const f = fleet.declare(arena, src, disk.resolver(), &refusal) catch |e| switch (e) {
        error.Refused => {
            try out.print("fleet (line {d}): {s}\n", .{ refusal.line, refusal.message });
            return 1;
        },
        else => return e,
    };
    const who = f.time_authority orelse {
        try out.print("time: fleet {s} declares no time authority: there is no key a statement could be checked against, so none is taken\n", .{f.name});
        return 1;
    };
    // the fleet court judged that the authority is a member and that it is enrolled
    const am = f.member(who).?;
    try out.print("time: fleet {s} takes the time from {s}, enrolled as fingerprint {s}\n", .{ f.name, who, am.fingerprint.?[0..] });

    const stext = std.fs.cwd().readFileAlloc(arena, args[1], 1 << 20) catch |e| {
        try out.print("harb: cannot read {s}: {s}\n", .{ args[1], @errorName(e) });
        return 1;
    };
    var rtext: ?[]const u8 = null;
    if (args.len == 3) rtext = std.fs.cwd().readFileAlloc(arena, args[2], 1 << 20) catch |e| {
        try out.print("harb: cannot read {s}: {s}\n", .{ args[2], @errorName(e) });
        return 1;
    };

    const r = try read(arena, out, am.key.?, stext, rtext);
    if (!r.record_ok) return 1;
    if (r.statements == 0) {
        try out.print("time: a verification of nothing is not one: the file holds no statement\n", .{});
        return 1;
    }
    if (r.refused > 0) {
        try out.print("time: {d} of {d} statement{s} refused: what a refused statement says is not taken\n", .{ r.refused, r.statements, if (r.statements == 1) "" else "s" });
        return 1;
    }
    try out.print("time: {d} statement{s} verified against the key {s} holds in this fleet, and no secret took part\n", .{ r.statements, if (r.statements == 1) "" else "s", who });
    return 0;
}

// ---- tests ---------------------------------------------------------------------------------------

fn pairOf(seed_byte: u8) !Ed25519.KeyPair {
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, seed_byte);
    return Ed25519.KeyPair.generateDeterministic(seed);
}

/// A record of `n` entries signed by `pair`, as a journal writes it.
fn recordOf(arena: std.mem.Allocator, pair: Ed25519.KeyPair, n: usize) ![]const u8 {
    var text: std.ArrayList(u8) = .{};
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const check = journal.verify(text.items, pair.public_key);
        const line = try journal.entry(arena, pair, check, "m", journal.declarationDigest("decl"), .matched);
        try text.appendSlice(arena, line);
    }
    return text.items;
}

/// The line of entry `seq` (1-based) of a record, as written.
fn lineOf(record: []const u8, seq: usize) []const u8 {
    var it = std.mem.splitScalar(u8, record, '\n');
    var n: usize = 0;
    while (it.next()) |line| {
        if (line.len == 0) continue;
        n += 1;
        if (n == seq) return line;
    }
    unreachable;
}

/// What a statement names entry `seq` of a record by: the digest of its whole line.
fn entryOf(record: []const u8, seq: usize) [64]u8 {
    return timeattest.entryDigest(lineOf(record, seq));
}

/// The `hash=` an entry carries: a hash of public bytes, which is NOT what a statement names an entry by.
fn hashOf(record: []const u8, seq: usize) []const u8 {
    const line = lineOf(record, seq);
    const at = std.mem.indexOf(u8, line, " hash=").? + " hash=".len;
    return line[at .. at + 64];
}

fn statement(arena: std.mem.Allocator, pair: Ed25519.KeyPair, entry: []const u8, t: i64) ![]const u8 {
    var buf: [timeattest.max_line]u8 = undefined;
    return arena.dupe(u8, try timeattest.sign(&buf, pair, entry, t));
}

/// A statement the authority's own `sign` would not make (a time it refuses), signed all the same: what a
/// holder of the key, or a clock that lied, could produce, and what an auditor must refuse.
fn rawStatement(arena: std.mem.Allocator, pair: Ed25519.KeyPair, entry: []const u8, t: i64) ![]const u8 {
    var pbuf: [timeattest.max_line]u8 = undefined;
    const body = try timeattest.payload(&pbuf, journal.fingerprintOf(pair.public_key.toBytes()), entry, t);
    return std.fmt.allocPrint(arena, "{s} sig={x}", .{ body, &(try pair.sign(body, null)).toBytes() });
}

const t0: i64 = 1_790_000_000; // 2026-09-21 13:33:20 UTC: the tests' clock, and nobody's

test "a record is read for what needs no key, and agrees with the journal's own check on every cut (TIME-1)" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const pair = try pairOf(9);
    const text = try recordOf(arena, pair, 3);
    var aw = std.Io.Writer.Allocating.init(arena);
    const es = (try readRecord(arena, text, &aw.writer)).?;
    try std.testing.expectEqual(@as(usize, 3), es.len);
    try std.testing.expectEqual(@as(usize, 1), es[0].seq);
    try std.testing.expectEqualStrings(&entryOf(text, 3), &es[2].digest);

    // the same record as an export prints it: `record ` before every line
    var prefixed: std.ArrayList(u8) = .{};
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |l| if (l.len > 0) try prefixed.writer(arena).print("record {s}\n", .{l});
    try std.testing.expectEqual(@as(usize, 3), (try readRecord(arena, prefixed.items, &aw.writer)).?.len);

    // every way a record is damaged WITHOUT the signature being the thing damaged: this reading and the
    // journal's refuse the same ones. (A bit flipped in a signature alone is the journal's to refuse and
    // not this one's, by design: it asks what the record says, never whose it is.)
    const first_end = std.mem.indexOfScalar(u8, text, '\n').? + 1;
    const second_end = first_end + std.mem.indexOfScalar(u8, text[first_end..], '\n').? + 1;
    const l1 = text[0..first_end];
    const l2 = text[first_end..second_end];
    const l3 = text[second_end..];
    var altered = try arena.dupe(u8, text);
    altered[std.mem.indexOf(u8, altered, "verdict=matched").? + "verdict=".len] = 'M';
    // the LAST entry altered is its own case: nothing after it names its hash, so only the entry's own hash
    // can say it was changed, and a reading that left the check to the chain would let it through
    var altered_last = try arena.dupe(u8, text);
    altered_last[std.mem.lastIndexOf(u8, altered_last, "verdict=matched").? + "verdict=".len] = 'M';
    // a `prev` that is no entry's hash, in an entry whose place, hash and every other number are right: the entry's
    // place and its hash cannot say it (every cut above is caught first by the place an entry no longer has), and
    // only the chain does
    const two = try recordOf(arena, pair, 2);
    const first_len = std.mem.indexOfScalar(u8, two, '\n').? + 1;
    const e2 = std.mem.trimRight(u8, two[first_len..], "\n");
    const payload_len = std.mem.indexOf(u8, e2, " hash=").?;
    const payload2 = try arena.dupe(u8, e2[0..payload_len]);
    const prev_at = std.mem.indexOf(u8, payload2, "prev=").? + "prev=".len;
    @memset(payload2[prev_at .. prev_at + 64], 'a');
    var digest2: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(payload2, &digest2, .{});
    const relinked = try std.fmt.allocPrint(arena, "{s}{s} hash={x} sig={s}\n", .{ two[0..first_len], payload2, &digest2, e2[std.mem.indexOf(u8, e2, " sig=").? + " sig=".len ..] });
    const cases = [_]struct { name: []const u8, text: []const u8 }{
        .{ .name = "an entry altered", .text = altered },
        .{ .name = "the last entry altered", .text = altered_last },
        .{ .name = "a link to another hash, every number right", .text = relinked },
        .{ .name = "the first entry removed", .text = try std.mem.concat(arena, u8, &.{ l2, l3 }) },
        .{ .name = "the middle entry removed", .text = try std.mem.concat(arena, u8, &.{ l1, l3 }) },
        .{ .name = "two entries swapped", .text = try std.mem.concat(arena, u8, &.{ l1, l3, l2 }) },
        .{ .name = "an entry repeated", .text = try std.mem.concat(arena, u8, &.{ l1, l2, l2, l3 }) },
    };
    for (cases) |c| {
        var sink = std.Io.Writer.Allocating.init(arena);
        const here = (try readRecord(arena, c.text, &sink.writer)) != null;
        const there = journal.verify(c.text, pair.public_key).broken_at == null;
        std.testing.expect(!here and !there) catch |e| {
            std.debug.print("{s}: this reading says {}, the journal's says {}\n", .{ c.name, here, there });
            return e;
        };
        try std.testing.expect(sink.written().len > 0); // and it said why
    }
}

test "an entry is bounded by the earliest statement at or after it, and no entry is dated by a time it cannot stand behind (TIME-1)" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const device = try pairOf(9);
    const authority = try pairOf(7);
    const record = try recordOf(arena, device, 4);
    var tb: [32]u8 = undefined;

    // the authority answered for entry 2 (at t0) and for entry 3 (at t0 + 600); it was down for entry 1 and entry 4
    const both = try std.mem.concat(arena, u8, &.{
        try statement(arena, authority, &entryOf(record, 2), t0), "\n",
        try statement(arena, authority, &entryOf(record, 3), t0 + 600), "\n",
    });
    var aw = std.Io.Writer.Allocating.init(arena);
    const r = try read(arena, &aw.writer, authority.public_key, both, record);
    try std.testing.expect(r.clean());
    try std.testing.expectEqual(@as(usize, 2), r.statements);
    const said = aw.written();
    // (copied out of the buffer: the next call into it would change what this names)
    const first = try arena.dupe(u8, try timeattest.minuteUp(&tb, t0));
    // entry 1 is not dated by what was asked of it (nothing was): it is dated by the first statement AFTER it
    try std.testing.expect(std.mem.indexOf(u8, said, try std.fmt.allocPrint(arena, "time: entry 1 existed no later than {s} (statement 1)\n", .{first})) != null);
    try std.testing.expect(std.mem.indexOf(u8, said, try std.fmt.allocPrint(arena, "time: entry 2 existed no later than {s} (statement 1)\n", .{first})) != null);
    // entry 3 has statement 2 only, and statement 1 says nothing of entries after its own
    try std.testing.expect(std.mem.indexOf(u8, said, try std.fmt.allocPrint(arena, "time: entry 3 existed no later than {s} (statement 2)\n", .{try timeattest.minuteUp(&tb, t0 + 600)})) != null);
    // entry 4 is after the last statement: ordered, and no more
    try std.testing.expect(std.mem.indexOf(u8, said, "time: entry 4 is ORDERED and UNDATED") != null);
    try std.testing.expect(std.mem.indexOf(u8, said, "entry 4 existed no later") == null);

    // the same statements in the order they would have been KEPT in a file that was written backwards: still the
    // earliest at or after, never the first one read
    const reversed = try std.mem.concat(arena, u8, &.{
        try statement(arena, authority, &entryOf(record, 3), t0 + 600), "\n",
        try statement(arena, authority, &entryOf(record, 2), t0), "\n",
    });
    var aw2 = std.Io.Writer.Allocating.init(arena);
    const r2 = try read(arena, &aw2.writer, authority.public_key, reversed, record);
    try std.testing.expect(std.mem.indexOf(u8, aw2.written(), try std.fmt.allocPrint(arena, "time: entry 1 existed no later than {s} (statement 2)\n", .{first})) != null);
    // a file in the order the entries were written says nothing about a clock that ran forward
    try std.testing.expectEqual(@as(usize, 0), r.backwards);
    try std.testing.expectEqual(@as(usize, 0), r2.backwards);

    // ... and a LATER entry dated EARLIER than one before it says so: the authority's clock went backwards
    // between the two, or one of them is wrong. It is said and not refused: both are still upper bounds, and the
    // earlier is the tighter, so what is printed of every entry stays true
    const backwards = try std.mem.concat(arena, u8, &.{
        try statement(arena, authority, &entryOf(record, 2), t0 + 600), "\n",
        try statement(arena, authority, &entryOf(record, 3), t0), "\n",
    });
    var aw3 = std.Io.Writer.Allocating.init(arena);
    const r3 = try read(arena, &aw3.writer, authority.public_key, backwards, record);
    try std.testing.expect(r3.clean());
    try std.testing.expectEqual(@as(usize, 1), r3.backwards);
    try std.testing.expect(std.mem.indexOf(u8, aw3.written(), "the authority's clock went backwards between them") != null);
    // ... in whatever order the file keeps the two (the statement about the later entry first, here)
    const backwards_reordered = try std.mem.concat(arena, u8, &.{
        try statement(arena, authority, &entryOf(record, 3), t0), "\n",
        try statement(arena, authority, &entryOf(record, 2), t0 + 600), "\n",
    });
    var aw4 = std.Io.Writer.Allocating.init(arena);
    const r4 = try read(arena, &aw4.writer, authority.public_key, backwards_reordered, record);
    try std.testing.expect(r4.clean());
    try std.testing.expectEqual(@as(usize, 1), r4.backwards);
}

test "a statement that cannot be taken is refused, and what it says dates nothing (TIME-1)" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const device = try pairOf(9);
    const authority = try pairOf(7);
    const impostor = try pairOf(8);
    const record = try recordOf(arena, device, 3);
    const good = try statement(arena, authority, &entryOf(record, 3), t0);

    // the export's own word before it is not part of a statement
    var aw = std.Io.Writer.Allocating.init(arena);
    const prefixed = try std.fmt.allocPrint(arena, "statement {s}\n", .{good});
    try std.testing.expect((try read(arena, &aw.writer, authority.public_key, prefixed, record)).clean());

    // changed after it was signed: the time moved by one second
    var changed = try arena.dupe(u8, good);
    const at = std.mem.indexOf(u8, changed, " t=").? + 3;
    changed[at + 9] = if (changed[at + 9] == '9') '8' else changed[at + 9] + 1;
    // signed by somebody else, with a perfectly good signature of its own
    const other = try statement(arena, impostor, &entryOf(record, 3), t0);
    // about an entry nobody has: one this record does not hold
    const elsewhere = try statement(arena, authority, "ff" ** 32, t0);
    // and a line that is no statement at all
    const nonsense = "the time is half past three";
    // signed by the authority and dated before the clock was ever set: an upper bound earlier than the truth
    const early = try rawStatement(arena, authority, &entryOf(record, 3), 946_684_800);
    const bad = [_]struct { name: []const u8, line: []const u8, words: []const u8 }{
        .{ .name = "changed", .line = changed, .words = "does not verify" },
        .{ .name = "an impostor's", .line = other, .words = "signed by somebody else" },
        .{ .name = "another entry's", .line = elsewhere, .words = "an entry this record does not hold" },
        .{ .name = "no statement", .line = nonsense, .words = "is not a time statement" },
        .{ .name = "dated before the clock was set", .line = early, .words = "states a time before 2026" },
    };
    for (bad) |b| {
        var sink = std.Io.Writer.Allocating.init(arena);
        const r = try read(arena, &sink.writer, authority.public_key, b.line, record);
        std.testing.expect(!r.clean() and r.refused == 1 and r.statements == 1) catch |e| {
            std.debug.print("{s}: refused {d} of {d}\n", .{ b.name, r.refused, r.statements });
            return e;
        };
        std.testing.expect(std.mem.indexOf(u8, sink.written(), b.words) != null) catch |e| {
            std.debug.print("{s}: said {s}\n", .{ b.name, sink.written() });
            return e;
        };
        // and nothing was dated by it: no entry names a statement, and the first is still ORDERED and UNDATED
        try std.testing.expect(std.mem.indexOf(u8, sink.written(), "(statement ") == null);
        try std.testing.expect(std.mem.indexOf(u8, sink.written(), "time: entry 1 is ORDERED and UNDATED") != null);
    }

    // a record cut at its end still hashes and chains, and the statement about the entry that was cut says so
    const cut = record[0 .. std.mem.lastIndexOf(u8, record[0 .. record.len - 1], "\n").? + 1];
    var sink = std.Io.Writer.Allocating.init(arena);
    const r = try read(arena, &sink.writer, authority.public_key, good, cut);
    try std.testing.expect(r.record_ok and r.refused == 1);
    try std.testing.expect(std.mem.indexOf(u8, sink.written(), "entries were cut from the end") != null);

    // no statement at all is a state, and it is said as one
    var none = std.Io.Writer.Allocating.init(arena);
    const nr = try read(arena, &none.writer, authority.public_key, "\n\n", record);
    try std.testing.expect(nr.clean() and nr.statements == 0);
    try std.testing.expect(std.mem.indexOf(u8, none.written(), "every entry of this record is ORDERED and UNDATED") != null);

    // a record that is no record dates nothing, and neither does an empty one
    var empty = std.Io.Writer.Allocating.init(arena);
    try std.testing.expect(!(try read(arena, &empty.writer, authority.public_key, good, "")).record_ok);
    try std.testing.expect(!(try read(arena, &empty.writer, authority.public_key, good, "not a record\n")).record_ok);
}

test "a time cannot be bought for an entry before the device has written it, nor for another device's (TIME-1)" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const device = try pairOf(9);
    const twin = try pairOf(10); // another device, running the same machine file
    const authority = try pairOf(7);
    const record = try recordOf(arena, device, 4);
    const twin_record = try recordOf(arena, twin, 4);

    // what anybody can know of entry 4 before it is written: its `hash=` is a hash of public bytes (its place,
    // the hash before it, the machine's name, the declaration's digest, a verdict), so it can be computed from
    // entry 3's. An authority asked for ITS time signs it, as it signs any digest it is shown
    const early = try statement(arena, authority, hashOf(record, 4), t0);
    var aw = std.Io.Writer.Allocating.init(arena);
    const r = try read(arena, &aw.writer, authority.public_key, early, record);
    // ... and it dates nothing: it is about no entry the record holds, and entry 4 is as undated as it was
    try std.testing.expect(!r.clean() and r.refused == 1);
    try std.testing.expect(std.mem.indexOf(u8, aw.written(), "an entry this record does not hold") != null);
    try std.testing.expect(std.mem.indexOf(u8, aw.written(), "time: entry 4 is ORDERED and UNDATED") != null);

    // two devices with one machine file and the same verdicts write the SAME `hash=` chain ...
    try std.testing.expectEqualStrings(hashOf(record, 3), hashOf(twin_record, 3));
    // ... and a statement the authority made about the first one's entry is not about the other's
    const mine = try statement(arena, authority, &entryOf(record, 3), t0);
    var aw2 = std.Io.Writer.Allocating.init(arena);
    const r2 = try read(arena, &aw2.writer, authority.public_key, mine, twin_record);
    try std.testing.expect(!r2.clean() and r2.refused == 1);
    try std.testing.expect(std.mem.indexOf(u8, aw2.written(), "(statement ") == null);
    // while it is about the first one's, as it was
    var aw3 = std.Io.Writer.Allocating.init(arena);
    try std.testing.expect((try read(arena, &aw3.writer, authority.public_key, mine, record)).clean());
}

test "a line somebody signed that is not an entry is not an entry of the record (TIME-1)" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const device = try pairOf(9);
    // a statement is signed with the device's key, over text a caller chooses in part; dressed with a hash and a
    // `prev`, its signature is a real one over bytes that are not an entry
    const st = try statement(arena, device, "ab" ** 32, t0);
    const parsed = timeattest.parse(st).?;
    var pbuf: [timeattest.max_line]u8 = undefined;
    const body = try timeattest.payload(&pbuf, parsed.authority, &parsed.entry, parsed.t);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(body, &digest, .{});
    const forged = try std.fmt.allocPrint(arena, "{s} hash={x} prev=- sig={x}\n", .{ body, &digest, &parsed.sig });
    var aw = std.Io.Writer.Allocating.init(arena);
    try std.testing.expect((try readRecord(arena, forged, &aw.writer)) == null);
    try std.testing.expect(std.mem.indexOf(u8, aw.written(), "is not the entry this place holds") != null);
}
