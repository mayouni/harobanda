//! roll.zig -- the roll call: who has written a record since, and the latest it can have been (ROLL-1,
//! STZ-OS-RULING-19).
//!
//! A cloud is a fleet of machines that each keep a signed record of their own boots (JRN-1) and, when the
//! fleet names a time authority, a file of statements beside it that dates the entries (TIME-1).
//! `harb fleet <file> verify` says whether ONE record is its member's; `harb time verify` says what the
//! authority said of ONE record. The roll reads the whole set at once, with only what anybody holding the
//! fleet file has -- the members' public keys and the authority's -- and says, for every member that keeps a
//! record: whether one was brought, whether it is the member's own and in order from its first entry, how far
//! it goes, and the newest entry anybody put a time on.
//!
//! Read against the roll before it, it says what no single record can: WHO HAS WRITTEN SINCE, how many
//! entries, and by when they existed -- or that nothing new was brought, which is a fact of the set with a
//! time on it.
//!
//! "Since" is a comparison and not a clock. A record is a hash chain: each entry's hash covers the one
//! before it, so a roll that remembers the last entry of a member's record can tell, from the next record
//! alone, whether that record is the first one EXTENDED -- the old last entry is still in it, at the place the
//! old roll counted it -- or something else: shorter, which is a record cut back, or another chain, which is
//! another device's or one written again from the start. That is all that is proved, and it needs no date:
//! entries after the old last entry were written after THAT ENTRY, by the hash. That they were written after the
//! roll looked is the copy's to say -- a roll shown a stale copy held an older end than the record had -- and only
//! a date can contradict it. What a date adds is the authority's, and it is an upper bound and never a lower one
//! (TIME-1): an entry "existed no later than" a time. So the window of an entry written since is from the roll that
//! did not have it (the CALLER's clock, said to be the caller's, because the floor has none) to the authority's
//! bound; and an entry the authority dates BEFORE the roll that did not have it says the copy that roll was shown
//! was stale, or that the two clocks disagree, and that is a finding.
//!
//! THE ANCHOR IS THE DIGEST OF THE WHOLE LAST LINE, never its `hash=`. An entry's hash is a hash of public
//! bytes (its place, the hash before it, the machine's name, the declaration's digest, a verdict): two devices
//! of one design that have booted alike have the SAME chain of hashes, so a head made of one would call a
//! rebuilt card's record the old card's, extended, for as long as the new card had at least as many entries.
//! The signature is in the line, so the digest of the line is the chain of ONE device (TIME-1 named an entry by
//! it for the same reason, and `timeattest.entryDigest` is the one place that makes it).
//!
//! THE ANCHOR IS THE LAST OBSERVATION THAT WAS HELD, and a roll that could not hold a member does not lose it:
//! a member nobody brought, whose record does not verify, or that nobody can vouch for keeps the anchor the roll
//! before it had, with the time of the roll that last held it, so that one missed collection does not turn the
//! next record -- cut back, forked, another device's -- into a first look. A record that goes BACKWARDS keeps the
//! old anchor too, and stays DIVERGED until a roll is called again without `--since`: accepting a rebuilt card or
//! a restored record is an act of the person who calls the roll, and never a side effect of calling it. A machine
//! whose declaration stops naming a JOURNAL is said once (NO LONGER KEEPS A RECORD) and its anchor is kept, silent,
//! for the day it names one again; a member the fleet file stops naming is said once too (LEFT), as a finding when the
//! roll held something of it, because deleting a member must not be a way to make a divergence go away unseen.
//!
//! The roll is itself a file (`render`, `parse`): the set's memory of who was heard from and how far. It
//! carries no signature, because nothing in it is a secret. What it holds is the records' word, the caller's clock
//! (`at`, `last`) and the history of the calls that made it (anchors carried, divergences kept), so the same records
//! and the same roll before it, called at the same moment, make the same one; and it is the anchor of the next one,
//! so a roll that was changed by hand changes only what its owner is told. It is written only if it reads back (a
//! roll its own parser would refuse, such as one whose clock runs behind the roll it was compared with, is not
//! written), to a file beside the one it replaces, synced, and renamed over it: a killed run or a power cut leaves
//! the roll before or this one, never half of one.
//!
//! What it does not do, and says. It does not fetch: the records are BROUGHT, one file named for the member
//! and the statements beside it, by whoever collects them -- the floor moves no records between machines, and
//! the mirror carries a world's directory and not the floor's own record (JRN-1). It does not know that what
//! it was brought is the latest: a copy that is stale reads as "nothing new", and only a date that disagrees
//! says otherwise. It does not tell a silent member from a healthy one: a record is written once per boot, so
//! a machine that stays up for a year has nothing new for a year, and "nothing new" names a state and never a
//! verdict. And it does not read a clock: the roll's own time is the caller's, printed as the caller's, and it is
//! the moment the records were COLLECTED (`--at`; it defaults to now, which is right only when they were collected a
//! moment ago). A roll that says it is as of 12:30 over records collected at 12:00 would call an entry the authority
//! dated at 12:10 a finding in the next one, and be right to: the copy it was shown was older than it said.

const std = @import("std");
const fleet = @import("fleet.zig");
const journal = @import("journal.zig");
const timeattest = @import("timeattest.zig");
const Ed25519 = std.crypto.sign.Ed25519;

/// What was found of one member's record.
pub const State = enum {
    /// its machine declares no JOURNAL: there is no record to bring
    none,
    /// its machine keeps a record, and nobody brought it
    absent,
    /// the record is the member's own and in order from its first entry, and goes on from the roll before it
    /// (or there is no roll before, or that roll never held this member)
    held,
    /// the record is the member's own and in order, and is NOT the roll before's record extended: it is
    /// shorter, or it is another chain. Only `call` says it: `read` has no roll to compare with
    diverged,
    /// an entry does not verify, or the record is not the chain the fleet trusts a retired key through
    broken,
    /// the fleet holds no key for the member: nobody can speak for its records
    unenrolled,
    /// a record was brought and it holds no entry
    empty,
    /// no key the member has held signed the record
    unsigned,
};

fn stateOf(word: []const u8) ?State {
    inline for (@typeInfo(State).@"enum".fields) |f| {
        if (std.mem.eql(u8, word, f.name)) return @field(State, f.name);
    }
    return null;
}

/// What a roll holds of one member. `state` is what THIS roll found; the rest is the ANCHOR, the last observation
/// that was held, which the next roll looks for in the record it is brought. For a held member it is this roll's
/// own observation; for any other it is the roll before's, carried.
pub const Seen = struct {
    name: []const u8,
    state: State,
    /// the entries that verified, from the first
    entries: usize = 0,
    /// the digest of the whole line of the last of them: the anchor the next roll looks for
    head: ?[64]u8 = null,
    /// how many entries have a time on them (the place of the newest dated entry), 0 for none
    dated: usize = 0,
    /// the tightest bound of that entry: the authority's "no later than"
    t: ?i64 = null,
    /// the roll (the caller's clock) that last held this observation
    last: ?i64 = null,
};

pub const Roll = struct {
    fleet: []const u8,
    /// when the roll was called, by the caller's clock
    at: i64,
    /// the fingerprint of the time authority the dates came from, if the fleet has one
    authority: ?[16]u8 = null,
    members: []const Seen,

    pub fn find(self: Roll, name: []const u8) ?Seen {
        for (self.members) |m| if (std.mem.eql(u8, m.name, name)) return m;
        return null;
    }
};

// ---- the roll as a file ---------------------------------------------------------------------------

/// The roll, as the exact bytes `parse` reads back:
///
///   roll v1 fleet=<name> at=<seconds> authority=<16 hex or ->
///   member <name> state=<word> entries=<n> head=<64 hex or -> dated=<n> t=<seconds or -> last=<seconds or ->
///   end
pub fn render(arena: std.mem.Allocator, r: Roll) ![]u8 {
    var aw = std.Io.Writer.Allocating.init(arena);
    errdefer aw.deinit();
    const w = &aw.writer;
    try w.print("roll v1 fleet={s} at={d} authority=", .{ r.fleet, r.at });
    if (r.authority) |a| try w.print("{s}\n", .{&a}) else try w.writeAll("-\n");
    for (r.members) |m| {
        try w.print("member {s} state={s} entries={d} head=", .{ m.name, @tagName(m.state), m.entries });
        if (m.head) |h| try w.print("{s}", .{&h}) else try w.writeAll("-");
        try w.print(" dated={d} t=", .{m.dated});
        if (m.t) |t| try w.print("{d}", .{t}) else try w.writeAll("-");
        try w.writeAll(" last=");
        if (m.last) |l| try w.print("{d}\n", .{l}) else try w.writeAll("-\n");
    }
    try w.writeAll("end\n");
    return aw.toOwnedSlice();
}

pub const ParseError = error{ Malformed, OutOfMemory };

fn isLowerHex(s: []const u8) bool {
    for (s) |c| if (!((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f'))) return false;
    return true;
}

/// A number as this file spells it: digits and nothing else, no sign, no separator, no leading zero.
fn decimal(s: []const u8) ?u64 {
    if (s.len == 0 or s.len > 18) return null;
    for (s) |c| if (c < '0' or c > '9') return null;
    if (s.len > 1 and s[0] == '0') return null;
    return std.fmt.parseInt(u64, s, 10) catch null;
}

/// A name the fleet grammar can write: lower_snake, of any length -- the grammar sets none, and a roll must read
/// back every roll the program can write.
fn plainName(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| if (!((c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_')) return false;
    return true;
}

/// The value of `key=value`, if `token` is that key.
fn valueOf(token: []const u8, key: []const u8) ?[]const u8 {
    if (token.len <= key.len or !std.mem.startsWith(u8, token, key) or token[key.len] != '=') return null;
    return token[key.len + 1 ..];
}

/// A time of this file: seconds, one spelling, no later than a statement may state.
fn seconds(s: []const u8) ?i64 {
    const t = decimal(s) orelse return null;
    if (t > timeattest.max_t) return null;
    return @intCast(t);
}

/// Read a roll back, strictly: the fields in order, one spelling of each, a line end after every line and
/// nothing after `end`. A roll is read to be compared with, and a roll read leniently is a comparison made
/// against something nobody wrote.
pub fn parse(arena: std.mem.Allocator, text: []const u8) ParseError!Roll {
    if (text.len == 0 or text[text.len - 1] != '\n') return error.Malformed;
    var it = std.mem.splitScalar(u8, text[0 .. text.len - 1], '\n');
    const head_line = it.next() orelse return error.Malformed;
    var ht = std.mem.splitScalar(u8, head_line, ' ');
    if (!std.mem.eql(u8, ht.next() orelse return error.Malformed, "roll")) return error.Malformed;
    if (!std.mem.eql(u8, ht.next() orelse return error.Malformed, "v1")) return error.Malformed;
    const fleet_name = valueOf(ht.next() orelse return error.Malformed, "fleet") orelse return error.Malformed;
    const at_text = valueOf(ht.next() orelse return error.Malformed, "at") orelse return error.Malformed;
    const auth_text = valueOf(ht.next() orelse return error.Malformed, "authority") orelse return error.Malformed;
    if (ht.next() != null) return error.Malformed;
    if (!plainName(fleet_name)) return error.Malformed;
    const at = seconds(at_text) orelse return error.Malformed;
    var authority: ?[16]u8 = null;
    if (!std.mem.eql(u8, auth_text, "-")) {
        if (auth_text.len != 16 or !isLowerHex(auth_text)) return error.Malformed;
        var a: [16]u8 = undefined;
        @memcpy(&a, auth_text);
        authority = a;
    }

    var members: std.ArrayList(Seen) = .{};
    var ended = false;
    while (it.next()) |line| {
        if (ended) return error.Malformed; // nothing after `end`
        if (std.mem.eql(u8, line, "end")) {
            ended = true;
            continue;
        }
        var mt = std.mem.splitScalar(u8, line, ' ');
        if (!std.mem.eql(u8, mt.next() orelse return error.Malformed, "member")) return error.Malformed;
        const name = mt.next() orelse return error.Malformed;
        const state_text = valueOf(mt.next() orelse return error.Malformed, "state") orelse return error.Malformed;
        const entries_text = valueOf(mt.next() orelse return error.Malformed, "entries") orelse return error.Malformed;
        const head_text = valueOf(mt.next() orelse return error.Malformed, "head") orelse return error.Malformed;
        const dated_text = valueOf(mt.next() orelse return error.Malformed, "dated") orelse return error.Malformed;
        const t_text = valueOf(mt.next() orelse return error.Malformed, "t") orelse return error.Malformed;
        const last_text = valueOf(mt.next() orelse return error.Malformed, "last") orelse return error.Malformed;
        if (mt.next() != null) return error.Malformed;
        if (!plainName(name)) return error.Malformed;
        for (members.items) |m| if (std.mem.eql(u8, m.name, name)) return error.Malformed; // one line a member
        var seen = Seen{ .name = try arena.dupe(u8, name), .state = stateOf(state_text) orelse return error.Malformed };
        seen.entries = std.math.cast(usize, decimal(entries_text) orelse return error.Malformed) orelse return error.Malformed;
        if (!std.mem.eql(u8, head_text, "-")) {
            if (head_text.len != 64 or !isLowerHex(head_text)) return error.Malformed;
            var h: [64]u8 = undefined;
            @memcpy(&h, head_text);
            seen.head = h;
        }
        seen.dated = std.math.cast(usize, decimal(dated_text) orelse return error.Malformed) orelse return error.Malformed;
        if (!std.mem.eql(u8, t_text, "-")) seen.t = seconds(t_text) orelse return error.Malformed;
        if (!std.mem.eql(u8, last_text, "-")) seen.last = seconds(last_text) orelse return error.Malformed;
        // a roll says nothing it could not have read: an anchor is a head AND a count AND the roll that held it, a
        // date needs a time to say it by, a held member was held by THIS roll, and nothing was held in the future
        if ((seen.entries == 0) != (seen.head == null)) return error.Malformed;
        if ((seen.last == null) != (seen.head == null)) return error.Malformed;
        if (seen.dated > seen.entries) return error.Malformed;
        if ((seen.dated == 0) != (seen.t == null)) return error.Malformed;
        if (seen.last) |l| if (l > at) return error.Malformed;
        if (seen.state == .held and seen.last != at) return error.Malformed;
        if (seen.state == .diverged and seen.head == null) return error.Malformed;
        try members.append(arena, seen);
    }
    if (!ended) return error.Malformed;
    return .{ .fleet = try arena.dupe(u8, fleet_name), .at = at, .authority = authority, .members = try members.toOwnedSlice(arena) };
}

// ---- one member's record, read ----------------------------------------------------------------------

/// What was brought for a member: the exact bytes of its record, and of the statements beside it. A file
/// nobody brought is null, and that is a different fact from a file that holds nothing.
pub const Brought = struct {
    member: []const u8,
    record: ?[]const u8 = null,
    statements: ?[]const u8 = null,
};

/// The fleet's time authority, as far as a statement can be checked.
pub const Authority = struct {
    name: []const u8,
    key: Ed25519.PublicKey,
    fingerprint: [16]u8,
};

pub const Reading = struct {
    /// what this record is: its state, and for a held one the observation (entries, head, dated, t); `last` is the
    /// roll's to say, not the reading's
    seen: Seen,
    /// how the record fell short of held, in words
    why: []const u8 = "",
    /// the entry that did not verify, when one did not
    broken_at: ?usize = null,
    /// the digest of the whole line of every entry that verified, in order
    digests: []const [64]u8 = &.{},
    /// the tightest bound of every verified entry: null for an entry nobody dated
    bounds: []const ?i64 = &.{},
    /// lines of the statements file that were not blank, were not taken (did not verify), and verified and are
    /// about no entry this record holds
    statements: usize = 0,
    refused: usize = 0,
    foreign: usize = 0,
    /// statements that cannot both be right of a clock that runs forward with an earlier one: an entry written later
    /// and dated earlier (the time audit counts the same)
    backwards: usize = 0,
    had_statements: bool = false,
    /// the retirement the record was heard under, when it is a chain the member signed with a key it has retired
    retired_as: ?[]const u8 = null,
    /// where the machine keeps its record, for the sentences
    kept_at: []const u8 = "",
};

fn bare(line: []const u8, prefix: []const u8) []const u8 {
    const l = std.mem.trimRight(u8, line, "\r");
    return if (std.mem.startsWith(u8, l, prefix)) l[prefix.len..] else l;
}

/// The first `n` entries of a record, as written, one line each.
fn entryLines(arena: std.mem.Allocator, record: []const u8, n: usize) ![]const []const u8 {
    var list: std.ArrayList([]const u8) = .{};
    var it = std.mem.splitScalar(u8, record, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len == 0) continue;
        if (list.items.len == n) break;
        try list.append(arena, line);
    }
    return list.toOwnedSlice(arena);
}

/// Read one member's record as far as a fleet file can: whether it is there, whose it is, how far it goes, and
/// what the authority said of it. Prints nothing; `call` says what was found.
pub fn read(arena: std.mem.Allocator, f: fleet.Fleet, m: fleet.Member, brought: Brought, authority: ?Authority) !Reading {
    var r = Reading{ .seen = .{ .name = m.name, .state = .none } };
    const path = m.machine.journal orelse return r;
    r.kept_at = path;
    const record = brought.record orelse {
        r.seen.state = .absent;
        return r;
    };

    var verified: usize = 0;
    switch (fleet.attribute(f, m.name, record)) {
        .verified => |c| {
            r.seen.state = .held;
            verified = c.verified;
        },
        .broken => |c| {
            r.seen.state = .broken;
            verified = c.verified;
            r.broken_at = c.broken_at;
            r.why = c.reason;
        },
        .retired_verified => |x| {
            r.seen.state = .held;
            verified = x.through.check.verified;
            r.retired_as = x.retirement.name;
        },
        .retired_broken => |x| {
            r.seen.state = .broken;
            verified = x.through.check.verified;
            r.broken_at = x.through.check.broken_at;
            r.retired_as = x.retirement.name;
            r.why = if (x.through.check.broken_at != null) x.through.check.reason else "every entry verifies under the key it has retired, and none is the entry the fleet trusts that key through: a retired key vouches for one chain, and a shorter record cannot be told from one its holder wrote since";
        },
        .unsigned => {
            r.seen.state = .unsigned;
            return r;
        },
        .empty => {
            r.seen.state = .empty;
            return r;
        },
        .not_enrolled => {
            r.seen.state = .unenrolled;
            return r;
        },
        .no_such_member => unreachable, // the member is the fleet's own
    }

    // the digest of every entry that verified: what a statement names an entry by, and what the next roll looks for
    const lines = try entryLines(arena, record, verified);
    const digests = try arena.alloc([timeattest.entry_len]u8, lines.len);
    for (lines, 0..) |line, i| digests[i] = timeattest.entryDigest(line);
    r.digests = digests;
    r.seen.entries = lines.len;
    if (r.seen.state == .held and lines.len > 0) r.seen.head = digests[lines.len - 1];

    // what the authority said: the best bound an entry gets is the EARLIEST statement at or after it, since a
    // statement dates the entry it names and, by the chain, every entry before it (timeaudit.zig reads the same
    // way and a test holds the two to each other)
    const bounds = try arena.alloc(?i64, lines.len);
    @memset(bounds, null);
    r.bounds = bounds;
    if (r.seen.state != .held) return r;
    const auth = authority orelse return r;
    const text = brought.statements orelse return r;
    r.had_statements = true;
    const Stated = struct { idx: usize, t: i64 };
    var stated: std.ArrayList(Stated) = .{};
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw| {
        const line = bare(raw, "statement ");
        if (line.len == 0) continue;
        r.statements += 1;
        if (timeattest.verify(line, auth.key) != .ok) {
            r.refused += 1;
            continue;
        }
        const st = timeattest.parse(line).?;
        var at: ?usize = null;
        for (digests, 0..) |d, i| if (std.mem.eql(u8, &d, &st.entry)) {
            at = i;
        };
        const idx = at orelse {
            r.foreign += 1;
            continue;
        };
        // a clock runs forward: an entry written LATER and dated EARLIER than one before it is a clock that went
        // backwards between the two, or a statement that is wrong -- in whatever order the file keeps them
        for (stated.items) |p| {
            if ((p.idx < idx and p.t > st.t) or (p.idx > idx and p.t < st.t)) {
                r.backwards += 1;
                break;
            }
        }
        try stated.append(arena, .{ .idx = idx, .t = st.t });
        for (0..idx + 1) |i| {
            if (bounds[i] == null or st.t < bounds[i].?) bounds[i] = st.t;
        }
    }
    var dated: usize = 0;
    for (bounds, 0..) |b, i| if (b != null) {
        dated = i + 1;
    };
    r.seen.dated = dated;
    if (dated > 0) r.seen.t = bounds[dated - 1];
    return r;
}

// ---- a record against the roll before ------------------------------------------------------------------

pub const Wrote = struct {
    /// the anchor the record goes on from
    old: Seen,
    /// how many entries the record holds now
    to: usize,
    /// the bound of the first entry written since, if the authority dated it
    first_bound: ?i64,
    /// how many of the entries written since nobody dated
    undated: usize,
    /// the authority dates the first of them BEFORE the roll that did not have it: that roll was shown a stale
    /// copy, or the caller's clock and the authority's disagree
    stale: bool,
};

pub const Change = union(enum) {
    /// not a thing to compare: the member keeps no record and did not
    nothing,
    /// there is no roll before this one
    first,
    /// the roll before did not have the member
    new,
    /// the roll before never held the member, so there is no anchor to look for
    no_anchor: Seen,
    /// the machine keeps no record now, and the roll before held one
    no_longer: Seen,
    /// the record is the anchor's record extended
    wrote: Wrote,
    /// the record is the anchor's record, no longer
    silent: Seen,
    /// the anchor is not in this record, which is shorter than the roll before held
    shorter: Seen,
    /// the anchor is not in this record, which is as long or longer
    forked: Seen,
    /// the record was held and nobody brought it
    absent_since: Seen,
    /// the record does not verify, and the break is inside what the roll before vouched for
    broken_within: Seen,
    /// the record does not verify, and what the roll before vouched for is intact
    broken_after: Seen,
    /// the roll before held it, and this record cannot be vouched for
    unvouched: Seen,
};

pub fn compare(since: ?Roll, r: Reading) Change {
    const keeps = r.seen.state != .none;
    const prev = since orelse return if (keeps) .first else .nothing;
    const old = prev.find(r.seen.name) orelse return if (keeps) .new else .nothing;
    // said once: the roll that first finds the declaration without a JOURNAL says so and keeps the anchor, silent,
    // so that a machine that names one again goes on from where it was, and the roll after it is clean
    if (!keeps) return if (old.head != null and old.state != .none) .{ .no_longer = old } else .nothing;
    if (old.head == null) return .{ .no_anchor = old };
    switch (r.seen.state) {
        .none => unreachable,
        .diverged => unreachable, // `read` never says it
        .absent => return .{ .absent_since = old },
        .held => {
            const n = r.seen.entries;
            if (n < old.entries) return .{ .shorter = old };
            if (!std.mem.eql(u8, &r.digests[old.entries - 1], &old.head.?)) return .{ .forked = old };
            if (n == old.entries) return .{ .silent = old };
            var undated: usize = 0;
            for (r.bounds[old.entries..]) |b| {
                if (b == null) undated += 1;
            }
            const first_bound = r.bounds[old.entries];
            const stale = if (first_bound) |t| (if (old.last) |l| t < l else false) else false;
            return .{ .wrote = .{ .old = old, .to = n, .first_bound = first_bound, .undated = undated, .stale = stale } };
        },
        .broken => {
            // a chain that is not the one a retired key is trusted through has no break to place against the roll
            if (r.broken_at == null) return .{ .unvouched = old };
            const n = r.seen.entries;
            if (n >= old.entries and std.mem.eql(u8, &r.digests[old.entries - 1], &old.head.?)) return .{ .broken_after = old };
            return .{ .broken_within = old };
        },
        .unenrolled, .empty, .unsigned => return .{ .unvouched = old },
    }
}

/// What this roll writes down of a member: this observation if it was held and goes on from the anchor, the
/// anchor itself otherwise -- the roll before's, carried, so that a missed collection, a record that does not
/// verify or one that went backwards does not turn the next record into a first look.
fn stored(since: ?Roll, r: Reading, change: Change, at: i64) Seen {
    var s = Seen{ .name = r.seen.name, .state = r.seen.state };
    const adopts = r.seen.state == .held and switch (change) {
        .shorter, .forked => false,
        else => true,
    };
    if (adopts) {
        s.entries = r.seen.entries;
        s.head = r.seen.head;
        s.dated = r.seen.dated;
        s.t = r.seen.t;
        s.last = at;
        return s;
    }
    if (since) |p| if (p.find(r.seen.name)) |o| {
        s.entries = o.entries;
        s.head = o.head;
        s.dated = o.dated;
        s.t = o.t;
        s.last = o.last;
    };
    if (r.seen.state == .held) s.state = .diverged;
    return s;
}

// ---- words ----------------------------------------------------------------------------------------------

/// `YYYY-MM-DD HH:MM UTC`, the minute the time falls in: the caller's own clock, which is read and never
/// rounded up (a bound the authority stated is rounded UP, `timeattest.minuteUp`).
fn clockOf(buf: []u8, t: i64) []const u8 {
    const c = timeattest.civilFromUnix(t);
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2} UTC", .{ @as(u64, @intCast(@max(c.year, 0))), c.month, c.day, c.hour, c.minute }) catch "?";
}

/// `YYYY-MM-DD HH:MM:SS UTC`, to the second: for the one sentence that sets two times against each other, which
/// would otherwise print a bound rounded up beside a roll rounded down and contradict itself.
fn clockSec(buf: []u8, t: i64) []const u8 {
    const c = timeattest.civilFromUnix(t);
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2} UTC", .{ @as(u64, @intCast(@max(c.year, 0))), c.month, c.day, c.hour, c.minute, c.second }) catch "?";
}

/// How long, in the words a person says it: "less than a minute", "14 min", "3 h 5 min", "2 d 1 h".
fn span(buf: []u8, secs: i64) []const u8 {
    const s: u64 = @intCast(@max(secs, 0));
    if (s < 60) return "less than a minute";
    const d = s / 86400;
    const h = (s % 86400) / 3600;
    const m = (s % 3600) / 60;
    const printed = if (d > 0)
        (if (h > 0) std.fmt.bufPrint(buf, "{d} d {d} h", .{ d, h }) else std.fmt.bufPrint(buf, "{d} d", .{d}))
    else if (h > 0)
        (if (m > 0) std.fmt.bufPrint(buf, "{d} h {d} min", .{ h, m }) else std.fmt.bufPrint(buf, "{d} h", .{h}))
    else
        std.fmt.bufPrint(buf, "{d} min", .{m});
    return printed catch "?";
}

fn plural(n: usize, one: []const u8, many: []const u8) []const u8 {
    return if (n == 1) one else many;
}

/// A number of exactly `n` digits and nothing else: no sign, no separator (a date is one spelling).
fn digits(s: []const u8, n: usize) ?u32 {
    if (s.len != n) return null;
    for (s) |c| if (c < '0' or c > '9') return null;
    return std.fmt.parseInt(u32, s, 10) catch null;
}

/// The time argument of the verb: seconds since the epoch, or `YYYY-MM-DDTHH:MMZ` / `YYYY-MM-DDTHH:MM:SSZ`.
pub fn parseTime(s: []const u8) ?i64 {
    if (decimal(s)) |t| return if (t <= timeattest.max_t) @as(i64, @intCast(t)) else null;
    if (s.len != 17 and s.len != 20) return null;
    if (s[4] != '-' or s[7] != '-' or s[10] != 'T' or s[13] != ':' or s[s.len - 1] != 'Z') return null;
    if (s.len == 20 and s[16] != ':') return null;
    const year = digits(s[0..4], 4) orelse return null;
    const month = digits(s[5..7], 2) orelse return null;
    const day = digits(s[8..10], 2) orelse return null;
    const hour = digits(s[11..13], 2) orelse return null;
    const minute = digits(s[14..16], 2) orelse return null;
    const second: u32 = if (s.len == 20) (digits(s[17..19], 2) orelse return null) else 0;
    if (year < 1970) return null;
    const t = timeattest.unixFromCivil(year, @intCast(month), @intCast(day), @intCast(hour), @intCast(minute), @intCast(second));
    // the calendar is the one judge of a date: 31 February, month 13, 20:60 and 24:00 would each be read as some other
    // moment, so the moment is turned back into a date and has to be the one that was written, every part of it
    const c = timeattest.civilFromUnix(t);
    if (c.year != year or c.month != month or c.day != day or c.hour != hour or c.minute != minute or c.second != second) return null;
    return if (t >= 0 and t <= timeattest.max_t) t else null;
}

// ---- the roll, called ---------------------------------------------------------------------------------------

pub const Called = struct {
    roll: Roll,
    /// every member that keeps a record brought one that is its own and in order, none went backwards or was
    /// lost, no statement was refused or about an entry the record does not hold, and nothing the authority
    /// dated disagrees with the roll before it
    clean: bool,
};

fn h8(h: *const [64]u8) []const u8 {
    return h[0..8];
}

fn when(buf: []u8, old: Seen) []const u8 {
    return clockOf(buf, old.last orelse 0);
}

/// Read the whole set, say what was found, and return the roll it makes (the anchor of the next).
pub fn call(
    arena: std.mem.Allocator,
    out: *std.Io.Writer,
    f: fleet.Fleet,
    brought: []const Brought,
    since: ?Roll,
    at: i64,
) !Called {
    var authority: ?Authority = null;
    if (f.time_authority) |who| {
        if (f.member(who)) |am| if (am.key) |k| {
            authority = .{ .name = who, .key = k, .fingerprint = am.fingerprint.? };
        };
    }
    var keepers: usize = 0;
    for (f.members) |m| {
        if (m.machine.journal != null) keepers += 1;
    }
    var cb: [48]u8 = undefined;
    try out.print("roll: fleet {s} -- {d} member{s}, {d} keep{s} a record; as of {s}, by the caller's clock\n", .{
        f.name, f.members.len, plural(f.members.len, "", "s"), keepers, plural(keepers, "s", ""), clockOf(&cb, at),
    });
    if (authority) |a| {
        try out.print("roll: dates come from {s} (fingerprint {s}): an entry \"existed no later than\" a time, which is that member's word and never a lower bound\n", .{ a.name, &a.fingerprint });
    } else {
        try out.print("roll: this fleet takes its time from nobody, so no entry is dated: every record below is ORDERED and UNDATED\n", .{});
    }
    var pb: [48]u8 = undefined;
    var sb: [48]u8 = undefined;
    if (since) |p| {
        if (at >= p.at) {
            try out.print("roll: compared with the roll of {s}, {s} before this one by the caller's clock\n", .{ clockOf(&pb, p.at), span(&sb, at - p.at) });
        } else {
            try out.print("roll: compared with the roll of {s}, which the caller's clock reads as LATER than this one: the two are not one clock's\n", .{clockOf(&pb, p.at)});
        }
        if (authority != null and p.authority != null and !std.mem.eql(u8, &authority.?.fingerprint, &p.authority.?)) {
            try out.print("roll: that roll took its time from another authority (fingerprint {s}): the dates in the two are not one clock's\n", .{&p.authority.?});
        }
    } else {
        try out.print("roll: this is the first roll: there is nothing to compare it with\n", .{});
    }

    var seen: std.ArrayList(Seen) = .{};
    var findings: usize = 0;
    var n_held: usize = 0;
    var n_wrote: usize = 0;
    var n_nothing_new: usize = 0;
    var n_absent: usize = 0;
    var n_diverged: usize = 0;
    var n_new: usize = 0;
    var n_gone: usize = 0;

    for (f.members) |m| {
        var mine = Brought{ .member = m.name };
        for (brought) |b| if (std.mem.eql(u8, b.member, m.name)) {
            mine = b;
        };
        const r = try read(arena, f, m, mine, authority);
        const change = compare(since, r);
        const kept_now = stored(since, r, change, at);
        // held means the observation the roll adopts: a record that went backwards is brought and verifies, and is not held
        if (kept_now.state == .held) n_held += 1;
        try seen.append(arena, kept_now);
        const name = m.name;
        switch (r.seen.state) {
            .none => {
                try out.print("roll: {s} -- keeps no record: its machine declares no JOURNAL, so there is none to bring", .{name});
                if (mine.record != null) try out.print("; one was brought for it and is not read", .{});
                try out.print("\n", .{});
            },
            .diverged => unreachable, // `read` never says it
            .absent => {
                findings += 1;
                n_absent += 1;
                try out.print("roll: {s} -- ABSENT: its machine keeps a record at {s}, and none was brought\n", .{ name, r.kept_at });
            },
            .unenrolled => {
                findings += 1;
                try out.print("roll: {s} -- NOT ENROLLED: the fleet holds no key for it, so nobody can speak for its records until its own fingerprint is enrolled\n", .{name});
            },
            .empty => {
                findings += 1;
                try out.print("roll: {s} -- EMPTY: the record that was brought holds no entry, so there is nothing to attribute\n", .{name});
            },
            .unsigned => {
                findings += 1;
                try out.print("roll: {s} -- NOT ITS OWN: no key it has held signed the record that was brought\n", .{name});
            },
            .broken => {
                findings += 1;
                if (r.broken_at) |b| {
                    try out.print("roll: {s} -- BROKEN at entry {d}: {s}; {d} entr{s} verified before it\n", .{
                        name, b, r.why, r.seen.entries, plural(r.seen.entries, "y", "ies"),
                    });
                } else {
                    try out.print("roll: {s} -- BROKEN: {s}; {d} entr{s} verify\n", .{ name, r.why, r.seen.entries, plural(r.seen.entries, "y", "ies") });
                }
            },
            .held => {
                if (r.retired_as) |old_key| {
                    try out.print("roll: {s} -- {d} entr{s}, from its first, in order, each signed by a key it no longer holds (retired as {s}), through the entry the fleet trusts that key through; head {s}, and no secret took part\n", .{
                        name, r.seen.entries, plural(r.seen.entries, "y", "ies"), old_key, h8(&r.seen.head.?),
                    });
                } else {
                    const fp_text: []const u8 = if (m.fingerprint) |*fp| fp[0..] else "none";
                    try out.print("roll: {s} -- {d} entr{s}, from its first, in order, each signed by the key enrolled for it (fingerprint {s}); head {s}, and no secret took part\n", .{
                        name, r.seen.entries, plural(r.seen.entries, "y", "ies"), fp_text, h8(&r.seen.head.?),
                    });
                }
                // the time on it
                var tb: [48]u8 = undefined;
                if (authority == null) {
                    try out.print("roll: {s} -- every entry is ORDERED and UNDATED: the fleet takes its time from nobody\n", .{name});
                } else if (!r.had_statements) {
                    try out.print("roll: {s} -- every entry is ORDERED and UNDATED here: no statements were brought beside the record\n", .{name});
                } else if (r.seen.dated == 0) {
                    try out.print("roll: {s} -- every entry is ORDERED and UNDATED: no statement is about this record, or about any entry of it\n", .{name});
                } else {
                    const after = r.seen.entries - r.seen.dated;
                    try out.print("roll: {s} -- entry {d} of {d} existed no later than {s} ({s}'s word)", .{
                        name, r.seen.dated, r.seen.entries, timeattest.minuteUp(&tb, r.seen.t.?) catch "?", authority.?.name,
                    });
                    if (after == 1) {
                        try out.print("; the entry after it is ORDERED and UNDATED", .{});
                    } else if (after > 1) {
                        try out.print("; the {d} after it are ORDERED and UNDATED", .{after});
                    }
                    try out.print("\n", .{});
                }
                if (r.refused > 0) {
                    findings += 1;
                    try out.print("roll: {s} -- FINDING: {d} of {d} statement{s} did not verify against {s}'s key and {s} not taken: changed after {s} signed, signed by another, cut short, or not a statement\n", .{
                        name, r.refused, r.statements, plural(r.statements, "", "s"), authority.?.name, plural(r.refused, "it is", "they are"), plural(r.refused, "it was", "they were"),
                    });
                }
                if (r.foreign > 0) {
                    findings += 1;
                    try out.print("roll: {s} -- FINDING: {d} statement{s} verif{s} and {s} about entries this record does not hold: {s} another record's, or entries were cut from the end of this one\n", .{
                        name, r.foreign, plural(r.foreign, "", "s"), plural(r.foreign, "ies", "y"), plural(r.foreign, "is", "are"), plural(r.foreign, "it is", "they are"),
                    });
                }
                if (r.backwards > 0) {
                    findings += 1;
                    try out.print("roll: {s} -- FINDING: {d} statement{s} cannot be right of a clock that runs forward with an earlier one: an entry written later is dated earlier -- {s}'s clock went backwards between them, or one of them is wrong\n", .{
                        name, r.backwards, plural(r.backwards, "", "s"), authority.?.name,
                    });
                }
            },
        }

        // against the roll before
        var wb: [48]u8 = undefined;
        var tbuf: [48]u8 = undefined;
        switch (change) {
            .nothing, .first => {},
            .new => {
                n_new += 1;
                try out.print("roll: {s} -- NEW: the roll of {s} did not have it\n", .{ name, clockOf(&wb, since.?.at) });
            },
            .no_anchor => |old| try out.print("roll: {s} -- the roll of {s} never held it ({s}), so there is no anchor to look for in this record\n", .{ name, clockOf(&wb, since.?.at), @tagName(old.state) }),
            .no_longer => |old| {
                findings += 1;
                try out.print("roll: {s} -- NO LONGER KEEPS A RECORD: its machine declares no JOURNAL now, and the roll of {s} held it at {d} entr{s}, head {s}\n", .{
                    name, when(&wb, old), old.entries, plural(old.entries, "y", "ies"), h8(&old.head.?),
                });
            },
            .wrote => |w| {
                n_wrote += 1;
                const since_text = when(&wb, w.old);
                if (w.to - w.old.entries == 1) {
                    try out.print("roll: {s} -- WROTE 1 entry since the roll of {s} (entry {d})", .{ name, since_text, w.to });
                } else {
                    try out.print("roll: {s} -- WROTE {d} entries since the roll of {s} (entries {d}-{d})", .{ name, w.to - w.old.entries, since_text, w.old.entries + 1, w.to });
                }
                if (w.first_bound) |t| {
                    try out.print("; the first existed no later than {s}", .{timeattest.minuteUp(&tbuf, t) catch "?"});
                    if (w.undated == 1) {
                        try out.print(", and the last one is ORDERED and UNDATED", .{});
                    } else if (w.undated > 1) {
                        try out.print(", and the last {d} are ORDERED and UNDATED", .{w.undated});
                    }
                } else {
                    try out.print("; ORDERED and UNDATED: nothing dates {s}", .{plural(w.to - w.old.entries, "it", "them")});
                }
                try out.print("\n", .{});
                if (w.stale) {
                    findings += 1;
                    var sbuf: [48]u8 = undefined;
                    try out.print("roll: {s} -- FINDING: the authority dates the first of them no later than {s}, which is before the roll of {s}, the roll that did not have it: the copy that roll was shown was stale, or the caller's clock and the authority's disagree\n", .{
                        name, clockSec(&tbuf, w.first_bound.?), clockSec(&sbuf, w.old.last.?),
                    });
                }
            },
            .silent => |old| {
                n_nothing_new += 1;
                try out.print("roll: {s} -- NOTHING NEW since the roll of {s}: the record brought still ends at entry {d}, head {s}\n", .{ name, when(&wb, old), old.entries, h8(&old.head.?) });
            },
            .shorter => |old| {
                n_diverged += 1;
                findings += 1;
                try out.print("roll: {s} -- DIVERGED: the roll of {s} held {d} entr{s} and this record holds {d}: a record is only ever extended, so this one was cut back, is another device's, or is not the one that roll saw. It stays DIVERGED until a roll is called again without --since\n", .{
                    name, when(&wb, old), old.entries, plural(old.entries, "y", "ies"), r.seen.entries,
                });
            },
            .forked => |old| {
                n_diverged += 1;
                findings += 1;
                try out.print("roll: {s} -- DIVERGED: the roll of {s} held {d} entr{s} ending in {s}, and this record's entry {d} is {s}: not the same chain -- another device's, or written again from the start. It stays DIVERGED until a roll is called again without --since\n", .{
                    name, when(&wb, old), old.entries, plural(old.entries, "y", "ies"), h8(&old.head.?), old.entries, h8(&r.digests[old.entries - 1]),
                });
            },
            .absent_since => |old| {
                try out.print("roll: {s} -- the roll of {s} held it: {d} entr{s}, head {s}, ", .{ name, when(&wb, old), old.entries, plural(old.entries, "y", "ies"), h8(&old.head.?) });
                if (old.dated > 0) {
                    try out.print("newest dated entry {d} no later than {s}\n", .{ old.dated, timeattest.minuteUp(&tbuf, old.t.?) catch "?" });
                } else {
                    try out.print("none of them dated\n", .{});
                }
            },
            .broken_within => |old| {
                try out.print("roll: {s} -- the break is inside what the roll of {s} vouched for ({d} entr{s}): entries that roll saw have been changed or removed\n", .{ name, when(&wb, old), old.entries, plural(old.entries, "y", "ies") });
            },
            .broken_after => |old| {
                try out.print("roll: {s} -- the {d} entr{s} the roll of {s} vouched for {s} intact; the break is in what was written after {s}\n", .{ name, old.entries, plural(old.entries, "y", "ies"), when(&wb, old), plural(old.entries, "is", "are"), plural(old.entries, "it", "them") });
            },
            .unvouched => |old| {
                try out.print("roll: {s} -- the roll of {s} held it at {d} entr{s}; this record cannot be vouched for\n", .{ name, when(&wb, old), old.entries, plural(old.entries, "y", "ies") });
            },
        }
    }

    // a member the roll before had and the fleet no longer names. A member that was held and is decommissioned is said
    // and costs nothing; one the roll still owed an answer for (nobody could bring it, it had gone backwards, it was
    // broken) is a finding, once -- the roll written now forgets it, and deleting a member must not be a way to make
    // that go away unseen
    if (since) |p| for (p.members) |old| {
        if (f.member(old.name) != null or (old.state == .none and old.head == null)) continue;
        n_gone += 1;
        var pbuf2: [48]u8 = undefined;
        try out.print("roll: {s} -- LEFT the fleet since the roll of {s}: that roll had it as {s}", .{ old.name, clockOf(&pbuf2, p.at), @tagName(old.state) });
        if (old.head != null) try out.print(", with an anchor at {d} entr{s}, head {s}", .{ old.entries, plural(old.entries, "y", "ies"), h8(&old.head.?) });
        if (old.head != null and old.state != .held and old.state != .none) {
            findings += 1;
            try out.print(" -- FINDING: the fleet file no longer names it, and the roll written now has nothing of it, so what that roll still owed an answer for is answered by no roll after this one", .{});
        }
        try out.print("\n", .{});
    };

    if (keepers == 0) {
        findings += 1;
        try out.print("roll: no member of this fleet keeps a record, so there is nothing to call: a roll of nothing is not one\n", .{});
    } else if (since != null) {
        try out.print("roll: {d} of {d} record{s} held; since the last roll {d} wrote, {d} had nothing new, {d} absent, {d} diverged, {d} new, {d} left the fleet\n", .{
            n_held, keepers, plural(keepers, "", "s"), n_wrote, n_nothing_new, n_absent, n_diverged, n_new, n_gone,
        });
    } else {
        try out.print("roll: {d} of {d} record{s} held\n", .{ n_held, keepers, plural(keepers, "", "s") });
    }
    if (findings == 0) {
        if (since != null) {
            try out.print("roll: clean: every record that should be there is, is its member's, and goes on from the roll before it wherever that roll held it\n", .{});
        } else {
            try out.print("roll: clean: every record that should be there is, and is its member's, in order from its first entry\n", .{});
        }
    } else {
        try out.print("roll: NOT clean: {d} thing{s} the set owes an answer for\n", .{ findings, plural(findings, "", "s") });
    }
    return .{
        .roll = .{ .fleet = f.name, .at = at, .authority = if (authority) |a| a.fingerprint else null, .members = try seen.toOwnedSlice(arena) },
        .clean = findings == 0,
    };
}

// ---- the verb ----------------------------------------------------------------------------------------------

/// How much of a file the roll reads of what it is brought. A record grows by an entry a boot, about three hundred bytes:
/// a machine rebooted daily for ten years is over a megabyte, which is what the other verbs read a record with.
const max_brought: usize = 64 << 20;

fn readIf(arena: std.mem.Allocator, path: []const u8, out: *std.Io.Writer) !?[]const u8 {
    return std.fs.cwd().readFileAlloc(arena, path, max_brought) catch |e| switch (e) {
        error.FileNotFound => null,
        else => {
            try out.print("harb: cannot read {s}: {s}\n", .{ path, @errorName(e) });
            return error.Reported;
        },
    };
}

/// Whether the text is a roll the next call can read: the one question that decides whether it may replace the roll
/// before it.
fn readsBack(arena: std.mem.Allocator, text: []const u8) bool {
    _ = parse(arena, text) catch return false;
    return true;
}

/// `harb roll <fleet-file> <records-dir> [--since <roll>] [--at <time>] [--out <roll>]`. Returns what `harb`
/// exits with: 0 only if the roll is clean.
pub fn run(arena: std.mem.Allocator, args: []const []const u8, out: *std.Io.Writer) !u8 {
    var fleet_path: ?[]const u8 = null;
    var dir_path: ?[]const u8 = null;
    var since_path: ?[]const u8 = null;
    var out_path: ?[]const u8 = null;
    var at: ?i64 = null;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--since") or std.mem.eql(u8, a, "--out") or std.mem.eql(u8, a, "--at")) {
            if (i + 1 >= args.len) {
                try out.print("harb: roll: {s} takes a value\n", .{a});
                return 1;
            }
            i += 1;
            if (std.mem.eql(u8, a, "--since")) since_path = args[i];
            if (std.mem.eql(u8, a, "--out")) out_path = args[i];
            if (std.mem.eql(u8, a, "--at")) at = parseTime(args[i]) orelse {
                try out.print("harb: roll: --at is seconds since the epoch or YYYY-MM-DDTHH:MMZ, not '{s}'\n", .{args[i]});
                return 1;
            };
        } else if (std.mem.startsWith(u8, a, "--")) {
            try out.print("harb: roll: there is no flag {s}\n", .{a});
            return 1;
        } else if (fleet_path == null) {
            fleet_path = a;
        } else if (dir_path == null) {
            dir_path = a;
        } else {
            try out.print("harb: roll takes a fleet file and the directory the records were brought to\n", .{});
            return 1;
        }
    }
    if (fleet_path == null or dir_path == null) {
        try out.print("harb: roll takes a fleet file and the directory the records were brought to: harb roll <file.fleet> <dir> [--since <roll>] [--at <time>] [--out <roll>]\n", .{});
        return 1;
    }

    const src = std.fs.cwd().readFileAlloc(arena, fleet_path.?, 1 << 20) catch |e| {
        try out.print("harb: cannot read {s}: {s}\n", .{ fleet_path.?, @errorName(e) });
        return 1;
    };
    const disk = fleet.Disk{ .arena = arena, .base = std.fs.path.dirname(fleet_path.?) orelse "" };
    var refusal = fleet.Refusal{};
    const f = fleet.declare(arena, src, disk.resolver(), &refusal) catch |e| switch (e) {
        error.Refused => {
            try out.print("fleet (line {d}): {s}\n", .{ refusal.line, refusal.message });
            return 1;
        },
        else => return e,
    };

    var since: ?Roll = null;
    if (since_path) |p| {
        const text = (readIf(arena, p, out) catch return 1) orelse {
            try out.print("harb: cannot read {s}: there is no such roll\n", .{p});
            return 1;
        };
        since = parse(arena, text) catch {
            try out.print("harb: {s} is not a roll: it is a file `harb roll --out` writes, in the one spelling it reads back\n", .{p});
            return 1;
        };
        if (!std.mem.eql(u8, since.?.fleet, f.name)) {
            try out.print("harb: {s} is a roll of fleet {s}, and this is fleet {s}: the anchors in it are another fleet's\n", .{ p, since.?.fleet, f.name });
            return 1;
        }
    }

    // the directory the records were brought to has to be there: a typo in it would make every keeper ABSENT and,
    // with --out, rewrite the roll as if that were news
    var brought_dir = std.fs.cwd().openDir(dir_path.?, .{}) catch |e| {
        try out.print("harb: cannot open {s}, the directory the records were brought to: {s}\n", .{ dir_path.?, @errorName(e) });
        return 1;
    };
    brought_dir.close();

    var list: std.ArrayList(Brought) = .{};
    for (f.members) |m| {
        const rp = try std.fmt.allocPrint(arena, "{s}/{s}.record", .{ dir_path.?, m.name });
        if (m.machine.journal == null) {
            // a record brought for a member that keeps none is said and not read: that it is there is all the roll
            // needs, and a file it will not use is not one it can fail on
            std.fs.cwd().access(rp, .{}) catch continue;
            try list.append(arena, .{ .member = m.name, .record = "" });
            continue;
        }
        const sp = try std.fmt.allocPrint(arena, "{s}{s}", .{ rp, timeattest.kept_suffix });
        const record = readIf(arena, rp, out) catch return 1;
        const statements = readIf(arena, sp, out) catch return 1;
        try list.append(arena, .{ .member = m.name, .record = record, .statements = statements });
    }

    const as_of = at orelse std.time.timestamp();
    const called = try call(arena, out, f, list.items, since, as_of);
    if (out_path) |p| {
        const text = try render(arena, called.roll);
        // a roll is written only if it reads back. The next call is compared with it, and a file its own parser
        // refuses would replace a good roll with one nobody can use; the cause that can happen is a clock that runs
        // behind the roll this one was compared with, and a roll file is kept only in the order of that clock
        if (!readsBack(arena, text)) {
            if (since) |back| if (as_of < back.at) {
                try out.print("harb: roll: nothing was written: this roll is as of a time earlier than the roll it was compared with, and a roll file is kept only in the order of the caller's clock -- call it with a later --at, or with no --since to start again\n", .{});
                return 1;
            };
            try out.print("harb: roll: nothing was written: the roll this call makes does not read back as a roll, and the one before it is left as it is\n", .{});
            return 1;
        }
        // written whole or not at all: to a file beside the one it replaces, synced, and renamed over it, so that a
        // killed run or a power cut leaves the roll before or this one and never half of one (`--since X --out X` is
        // the ordinary way to go on)
        const tmp = try std.fmt.allocPrint(arena, "{s}.new", .{p});
        var file = std.fs.cwd().createFile(tmp, .{}) catch |e| {
            try out.print("harb: cannot write {s}: {s}\n", .{ tmp, @errorName(e) });
            return 1;
        };
        const failed: ?anyerror = blk: {
            file.writeAll(text) catch |e| break :blk e;
            file.sync() catch |e| break :blk e;
            break :blk null;
        };
        file.close();
        if (failed) |e| {
            std.fs.cwd().deleteFile(tmp) catch {};
            try out.print("harb: cannot write {s}: {s}\n", .{ tmp, @errorName(e) });
            return 1;
        }
        std.fs.cwd().rename(tmp, p) catch |e| {
            std.fs.cwd().deleteFile(tmp) catch {};
            try out.print("harb: cannot put {s} in place: {s}\n", .{ p, @errorName(e) });
            return 1;
        };
        try out.print("roll: written to {s}: the next roll is compared with it (--since)\n", .{p});
    } else if (since == null) {
        try out.print("roll: not written (no --out): nothing was kept, so the next roll will be a first roll too\n", .{});
    }
    return if (called.clean) 0 else 1;
}

// ---- tests ---------------------------------------------------------------------------------------

const testing = std.testing;
const timeaudit = @import("timeaudit.zig");

fn pairOf(byte: u8) !Ed25519.KeyPair {
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    @memset(&seed, byte);
    return Ed25519.KeyPair.generateDeterministic(seed);
}

fn hexOf(arena: std.mem.Allocator, pair: Ed25519.KeyPair) ![]const u8 {
    return std.fmt.allocPrint(arena, "{x}", .{&pair.public_key.toBytes()});
}

const Files = struct {
    files: []const [2][]const u8,

    fn fetch(context: *const anyopaque, path: []const u8) ?[]const u8 {
        const self: *const Files = @alignCast(@ptrCast(context));
        for (self.files) |f| if (std.mem.eql(u8, f[0], path)) return f[1];
        return null;
    }
    fn resolver(self: *const Files) fleet.Resolver {
        return .{ .context = self, .readFn = fetch };
    }
};

/// A fleet that takes its time from one member and has two devices that keep a record: the files of the time
/// seat, as they stand in `machines/`, with the keys of this test written in (enrolment is somebody reading a
/// line and writing it down, and so it is here).
const Time = struct {
    f: fleet.Fleet,
    src: []const u8,
    sources: []const [2][]const u8,
    auth: Ed25519.KeyPair,
    till: Ed25519.KeyPair,
    till2: Ed25519.KeyPair,
};

const placeholder_key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

/// `till_key` is the key the fleet holds for the member `till` (null: none enrolled); `with_till2` adds a second
/// device, which the fleet court wants as a second machine file with a machine name of its own.
fn timeFleetOf(arena: std.mem.Allocator, till_key: ?Ed25519.KeyPair, with_till2: bool) !Time {
    const auth = try pairOf(0xa1);
    const till = try pairOf(0xb1);
    const till2 = try pairOf(0xb2);
    const auth_hex = try hexOf(arena, auth);
    const clockbox = try std.fs.cwd().readFileAlloc(arena, "machines/time_clockbox.machine", 1 << 16);
    const till_raw = try std.fs.cwd().readFileAlloc(arena, "machines/time_till.machine", 1 << 16);
    const till_text = try std.mem.replaceOwned(u8, arena, till_raw, placeholder_key, auth_hex);
    // a signed record names its machine, so two devices are two machine files (the court refuses one name twice)
    const till2_addr = try std.mem.replaceOwned(u8, arena, till_text, "10.30.0.2/24", "10.30.0.3/24");
    const till2_text = try std.mem.replaceOwned(u8, arena, till2_addr, "DEFINE MACHINE time_till AS", "DEFINE MACHINE time_till2 AS");
    const till_clause = if (till_key) |k| try std.fmt.allocPrint(arena, "KEY \"{s}\", ", .{try hexOf(arena, k)}) else "";
    const second = if (with_till2)
        try std.fmt.allocPrint(arena, "DEFINE MEMBER till2 AS (DECLARATION \"time_till2.machine\", KEY \"{s}\", HARDWARE \"52:54:00:12:36:03\") RATIONALE \"x\"\n", .{try hexOf(arena, till2)})
    else
        "";
    const src = try std.fmt.allocPrint(arena,
        \\DEFINE FLEET nuage AS (LINK lan, TIME_AUTHORITY clockbox) RATIONALE "x"
        \\DEFINE MEMBER clockbox AS (DECLARATION "time_clockbox.machine", KEY "{s}", HARDWARE "52:54:00:12:36:01") RATIONALE "x"
        \\DEFINE MEMBER till AS (DECLARATION "time_till.machine", {s}HARDWARE "52:54:00:12:36:02") RATIONALE "x"
        \\{s}
    , .{ auth_hex, till_clause, second });
    const sources = try arena.dupe([2][]const u8, &.{
        .{ "time_clockbox.machine", clockbox },
        .{ "time_till.machine", till_text },
        .{ "time_till2.machine", till2_text },
    });
    const files = try arena.create(Files);
    files.* = .{ .files = sources };
    var refusal = fleet.Refusal{};
    const f = fleet.declare(arena, src, files.resolver(), &refusal) catch |e| {
        std.debug.print("the test fleet is refused (line {d}): {s}\n", .{ refusal.line, refusal.message });
        return e;
    };
    return .{ .f = f, .src = src, .sources = sources, .auth = auth, .till = till, .till2 = till2 };
}

fn timeFleet(arena: std.mem.Allocator, enrol_till: bool) !Time {
    return timeFleetOf(arena, if (enrol_till) try pairOf(0xb1) else null, true);
}

fn keeperMachine(comptime name: []const u8, comptime keeps: bool) []const u8 {
    return "DEFINE MACHINE " ++ name ++ " AS (PROFILE hosted, ARCH x86_64, KERNEL linux, IDENTITY \"/data/key\"" ++
        (if (keeps) ", JOURNAL \"/data/record\"" else "") ++ ") RATIONALE \"x\"\n" ++
        "DEFINE CAPABILITY filesystem AS (GRANT yes) RATIONALE \"x\"\n" ++
        "DEFINE MOUNT data AS (AT \"/data\", FS ext4, DEVICE \"/dev/vda\", OPTIONS [rw]) RATIONALE \"x\"\n";
}

/// A fleet that takes its time from nobody: two devices that keep a record (the second of them only if `annex_keeps`),
/// and one that keeps none.
fn estate(arena: std.mem.Allocator, annex_keeps: bool) !struct { f: fleet.Fleet, a: Ed25519.KeyPair, b: Ed25519.KeyPair } {
    const a = try pairOf(0xc1);
    const b = try pairOf(0xc2);
    const plain = "DEFINE MACHINE plain AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE \"x\"\n";
    const src = try std.fmt.allocPrint(arena,
        \\DEFINE FLEET estate AS () RATIONALE "x"
        \\DEFINE MEMBER depot AS (DECLARATION "depot.machine", KEY "{s}") RATIONALE "x"
        \\DEFINE MEMBER annex AS (DECLARATION "annex.machine", KEY "{s}") RATIONALE "x"
        \\DEFINE MEMBER box AS (DECLARATION "plain.machine") RATIONALE "x"
        \\
    , .{ try hexOf(arena, a), try hexOf(arena, b) });
    const files = try arena.create(Files);
    files.* = .{ .files = &.{
        .{ "depot.machine", keeperMachine("depot", true) },
        .{ "annex.machine", if (annex_keeps) keeperMachine("annex", true) else keeperMachine("annex", false) },
        .{ "plain.machine", plain },
    } };
    var refusal = fleet.Refusal{};
    const f = fleet.declare(arena, src, files.resolver(), &refusal) catch |e| {
        std.debug.print("the test estate is refused (line {d}): {s}\n", .{ refusal.line, refusal.message });
        return e;
    };
    return .{ .f = f, .a = a, .b = b };
}

/// A fleet whose member `depot` had a first card, retired through `head`, and holds a second one (or none).
fn cardFleet(arena: std.mem.Allocator, old: Ed25519.KeyPair, new: ?Ed25519.KeyPair, head: []const u8) !fleet.Fleet {
    const old_hex = try hexOf(arena, old);
    const src = if (new) |n| try std.fmt.allocPrint(arena,
        \\DEFINE FLEET f AS () RATIONALE "x"
        \\DEFINE MEMBER depot AS (DECLARATION "depot.machine", KEY "{s}") RATIONALE "x"
        \\DEFINE RETIREMENT card_1 AS (MEMBER depot, KEY "{s}", THROUGH "{s}") RATIONALE "the first card failed"
        \\
    , .{ try hexOf(arena, n), old_hex, head }) else try std.fmt.allocPrint(arena,
        \\DEFINE FLEET f AS () RATIONALE "x"
        \\DEFINE MEMBER depot AS (DECLARATION "depot.machine") RATIONALE "x"
        \\DEFINE RETIREMENT card_1 AS (MEMBER depot, KEY "{s}", THROUGH "{s}") RATIONALE "the first card failed"
        \\
    , .{ old_hex, head });
    const files = try arena.create(Files);
    files.* = .{ .files = &.{.{ "depot.machine", keeperMachine("depot", true) }} };
    var refusal = fleet.Refusal{};
    return fleet.declare(arena, src, files.resolver(), &refusal) catch |e| {
        std.debug.print("the test card fleet is refused (line {d}): {s}\n", .{ refusal.line, refusal.message });
        return e;
    };
}

/// A record of `n` entries signed by `pair`, as a journal writes it; `who` is the machine name each carries, so
/// that two records of one device can be told apart (the same key, another chain).
fn recordOf(arena: std.mem.Allocator, pair: Ed25519.KeyPair, who: []const u8, n: usize) ![]const u8 {
    var text: std.ArrayList(u8) = .{};
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const check = journal.verify(text.items, pair.public_key);
        const line = try journal.entry(arena, pair, check, who, journal.declarationDigest("decl"), .matched);
        try text.appendSlice(arena, line);
    }
    return text.items;
}

/// The first `n` entries of a record, as written.
fn firstOf(record: []const u8, n: usize) []const u8 {
    var at: usize = 0;
    var seen: usize = 0;
    while (seen < n) : (seen += 1) at = std.mem.indexOfScalarPos(u8, record, at, '\n').? + 1;
    return record[0..at];
}

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

/// The record with the machine name of entry `seq` changed in place: that entry no longer hashes to what it says.
fn altered(arena: std.mem.Allocator, record: []const u8, seq: usize) ![]u8 {
    const line = lineOf(record, seq);
    const start = @intFromPtr(line.ptr) - @intFromPtr(record.ptr);
    const at = std.mem.indexOf(u8, line, "machine=").? + "machine=".len;
    const copy = try arena.dupe(u8, record);
    copy[start + at] = if (copy[start + at] == 'X') 'Y' else 'X';
    return copy;
}

/// The authority's statement that entry `seq` of `record` existed no later than `t`, one line.
fn said(arena: std.mem.Allocator, auth: Ed25519.KeyPair, record: []const u8, seq: usize, t: i64) ![]const u8 {
    const digest = timeattest.entryDigest(lineOf(record, seq));
    var buf: [timeattest.max_line]u8 = undefined;
    return std.fmt.allocPrint(arena, "{s}\n", .{try timeattest.sign(&buf, auth, &digest, t)});
}

fn joined(arena: std.mem.Allocator, parts: []const []const u8) ![]const u8 {
    return std.mem.concat(arena, u8, parts);
}

const t0: i64 = 1_790_000_000; // 2026-09-21 14:13:20 UTC: the tests' clock, and nobody's
const at1: i64 = t0 + 120; // the first roll, called just after the first entries were written
const at2: i64 = at1 + 2 * 3600 + 5 * 60;

/// What `call` printed and decided, for a set of records.
fn callIt(arena: std.mem.Allocator, f: fleet.Fleet, brought: []const Brought, since: ?Roll, at: i64) !struct { text: []const u8, c: Called } {
    var aw = std.Io.Writer.Allocating.init(arena);
    const c = try call(arena, &aw.writer, f, brought, since, at);
    return .{ .text = aw.written(), .c = c };
}

fn has(hay: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, hay, needle) != null;
}

/// `needle` is in `hay`, and when it is not the test says both: a failed `expect` says only `false`.
fn must(hay: []const u8, needle: []const u8) !void {
    if (has(hay, needle)) return;
    std.debug.print("\nnot found: {s}\n--- in ---\n{s}--- end ---\n", .{ needle, hay });
    return error.TestUnexpectedResult;
}

fn mustNot(hay: []const u8, needle: []const u8) !void {
    if (!has(hay, needle)) return;
    std.debug.print("\nfound, and should not be: {s}\n--- in ---\n{s}--- end ---\n", .{ needle, hay });
    return error.TestUnexpectedResult;
}

/// The roll a call makes, written and read back, as the next call reads it.
fn kept(arena: std.mem.Allocator, c: Called) !Roll {
    return parse(arena, try render(arena, c.roll));
}

test "a roll is written as a file and read back in one spelling (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var head: [64]u8 = undefined;
    @memcpy(&head, "0123456789abcdef" ** 4);
    var auth: [16]u8 = undefined;
    @memcpy(&auth, "00112233445566ff");
    const members = [_]Seen{
        .{ .name = "box", .state = .none },
        .{ .name = "depot", .state = .held, .entries = 5, .head = head, .dated = 3, .t = t0, .last = at1 },
        .{ .name = "annex", .state = .absent, .entries = 4, .head = head, .last = at1 - 3600 },
        .{ .name = "till_2", .state = .diverged, .entries = 2, .head = head, .last = at1 - 60 },
        .{ .name = "gone", .state = .broken },
    };
    const r = Roll{ .fleet = "estate", .at = at1, .authority = auth, .members = &members };
    const text = try render(arena, r);
    try testing.expectEqualStrings(try render(arena, r), text); // one spelling: the same roll is the same bytes
    const back = try parse(arena, text);
    try testing.expectEqualStrings("estate", back.fleet);
    try testing.expectEqual(at1, back.at);
    try testing.expectEqualSlices(u8, &auth, &back.authority.?);
    try testing.expectEqual(members.len, back.members.len);
    for (members, back.members) |want, got| {
        try testing.expectEqualStrings(want.name, got.name);
        try testing.expectEqual(want.state, got.state);
        try testing.expectEqual(want.entries, got.entries);
        try testing.expectEqual(want.dated, got.dated);
        try testing.expectEqual(want.t, got.t);
        try testing.expectEqual(want.last, got.last);
        try testing.expectEqual(want.head == null, got.head == null);
        if (want.head) |h| try testing.expectEqualSlices(u8, &h, &got.head.?);
    }
    // no authority is a dash, and reads back as none
    const bare_roll = try parse(arena, try render(arena, .{ .fleet = "estate", .at = at1, .members = &.{} }));
    try testing.expect(bare_roll.authority == null);
    // the fleet grammar sets no limit on a name, so a roll of any name the program can write is a roll that reads back
    const long_name = "a" ** 300;
    const long_roll = try parse(arena, try render(arena, .{ .fleet = long_name, .at = at1, .members = &[_]Seen{.{ .name = long_name, .state = .none }} }));
    try testing.expectEqualStrings(long_name, long_roll.fleet);

    // a roll is read strictly: each of these is not one
    const mut = struct {
        fn bad(a: std.mem.Allocator, from: []const u8, needle: []const u8, with: []const u8) !void {
            const changed = try std.mem.replaceOwned(u8, a, from, needle, with);
            try testing.expect(!std.mem.eql(u8, changed, from));
            try testing.expectError(error.Malformed, parse(a, changed));
        }
    };
    try mut.bad(arena, text, "entries=5", "entries=05"); // a number with a leading zero
    try mut.bad(arena, text, "entries=5", "entries=+5");
    try mut.bad(arena, text, "state=held", "state=asleep"); // a state nobody names
    try mut.bad(arena, text, "dated=3", "dated=6"); // a date past the end
    try mut.bad(arena, text, "dated=3 t=1790000000", "dated=3 t=-"); // entries dated and no time to say it by
    try mut.bad(arena, text, "roll v1", "roll v2");
    try mut.bad(arena, text, "authority=00112233445566ff", "authority=00112233445566f"); // a fingerprint is sixteen digits
    try mut.bad(arena, text, "authority=00112233445566ff", "authority=00112233445566FF");
    try mut.bad(arena, text, "at=1790000120", "at=253402300800"); // a time later than a statement may state
    // ... and by no other rule: the case above is also a held member held by another roll, so these are the ones only the
    // limit can see -- a roll with nothing held, and an entry dated later than any statement may be
    const far = timeattest.max_t + 1;
    try testing.expectError(error.Malformed, parse(arena, try render(arena, .{ .fleet = "estate", .at = far, .members = &.{} })));
    const too_late = [_]Seen{.{ .name = "box", .state = .absent, .entries = 1, .head = head, .dated = 1, .t = far, .last = at1 }};
    try testing.expectError(error.Malformed, parse(arena, try render(arena, .{ .fleet = "estate", .at = at1, .members = &too_late })));
    const last_second = [_]Seen{.{ .name = "box", .state = .absent, .entries = 1, .head = head, .dated = 1, .t = timeattest.max_t, .last = at1 }};
    _ = try parse(arena, try render(arena, .{ .fleet = "estate", .at = timeattest.max_t, .members = &last_second }));
    // a word too many on the header or on a member's line, a fleet named in capitals or not at all, a head a character short
    try mut.bad(arena, text, "authority=00112233445566ff", "authority=00112233445566ff extra=1");
    try mut.bad(arena, text, "member box state=none entries=0 head=- dated=0 t=- last=-", "member box state=none entries=0 head=- dated=0 t=- last=- extra=1");
    try mut.bad(arena, text, "fleet=estate", "fleet=Estate");
    try mut.bad(arena, text, "fleet=estate", "fleet=");
    try mut.bad(arena, text, "cdef dated=3", "cde dated=3");
    try mut.bad(arena, text, "\n", "\r\n"); // one line end
    try mut.bad(arena, text, "member box state=none entries=0 head=-", "member box state=none entries=1 head=-"); // entries with no head behind them
    try mut.bad(arena, text, "member annex", "member depot"); // a member twice
    try mut.bad(arena, text, "member box", "member Box");
    try mut.bad(arena, text, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", "0123456789ABCDEF0123456789abcdef0123456789abcdef0123456789abcdef");
    try mut.bad(arena, text, "end\n", "end\nmember x state=none entries=0 head=- dated=0 t=- last=-\n"); // nothing after `end`
    try mut.bad(arena, text, "end\n", ""); // no `end`
    try mut.bad(arena, text, "t=1790000000 last=1790000120", "t=1790000000 last=1790000119"); // a held member was held by THIS roll
    try mut.bad(arena, text, "member box state=none entries=0 head=- dated=0 t=- last=-", "member box state=none entries=0 head=- dated=0 t=- last=5"); // a roll that held nothing
    try mut.bad(arena, text, "last=1789996520", "last=-"); // an anchor with no roll that held it
    try mut.bad(arena, text, "last=1790000060", "last=1790000121"); // held in the future
    try mut.bad(arena, text, "member gone state=broken", "member gone state=diverged"); // diverged from nothing
    try testing.expectError(error.Malformed, parse(arena, text[0 .. text.len - 1])); // no line end after it
    try testing.expectError(error.Malformed, parse(arena, ""));
}

test "a time is read in the two spellings the verb takes, and a date the calendar lacks is not one (ROLL-1)" {
    try testing.expectEqual(@as(?i64, 1_790_000_000), parseTime("1790000000"));
    try testing.expectEqual(@as(?i64, timeattest.unixFromCivil(2026, 10, 19, 20, 5, 0)), parseTime("2026-10-19T20:05Z"));
    try testing.expectEqual(@as(?i64, timeattest.unixFromCivil(2026, 10, 19, 20, 5, 9)), parseTime("2026-10-19T20:05:09Z"));
    try testing.expectEqual(@as(?i64, null), parseTime("2026-02-31T00:00Z")); // the calendar has no 31 February
    try testing.expectEqual(@as(?i64, null), parseTime("2026-13-01T00:00Z"));
    try testing.expectEqual(@as(?i64, null), parseTime("2026-10-19T24:00Z"));
    try testing.expectEqual(@as(?i64, null), parseTime("2026-10-19T20:60Z")); // the calendar reads 20:60 as 21:00, and a date is not that
    try testing.expectEqual(@as(?i64, null), parseTime("2026-10-19T20:05:60Z"));
    try testing.expectEqual(@as(?i64, null), parseTime("2026-00-10T00:00Z"));
    try testing.expectEqual(@as(?i64, null), parseTime("2026-10-00T00:00Z"));
    try testing.expectEqual(@as(?i64, null), parseTime("1969-12-31T23:59Z")); // before the epoch
    try testing.expectEqual(@as(?i64, timeattest.unixFromCivil(2026, 10, 19, 23, 59, 59)), parseTime("2026-10-19T23:59:59Z"));
    try testing.expectEqual(@as(?i64, null), parseTime("2026-10-19 20:05Z"));
    try testing.expectEqual(@as(?i64, null), parseTime("2026-10-19T20:05"));
    try testing.expectEqual(@as(?i64, null), parseTime("26-10-19T20:05Z"));
    try testing.expectEqual(@as(?i64, null), parseTime("2026-10-19T+9:05Z")); // one spelling: no sign in a time
    try testing.expectEqual(@as(?i64, null), parseTime("2026-10-19T2_:05Z"));
    try testing.expectEqual(@as(?i64, null), parseTime("01790000000")); // one spelling of a number
    try testing.expectEqual(@as(?i64, null), parseTime("-5"));
    try testing.expectEqual(@as(?i64, null), parseTime(""));
}

test "a record is read for whose it is, how far it goes and what the authority said of it (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const till = fx.f.member("till").?;
    const auth = Authority{ .name = "clockbox", .key = fx.auth.public_key, .fingerprint = fx.f.member("clockbox").?.fingerprint.? };

    const record = try recordOf(arena, fx.till, "till", 5);
    // entry 3 and entry 2 were dated; the earlier statement about the later entry does not date the earlier ones
    // any tighter than the later statement about them does
    const statements = try joined(arena, &.{ try said(arena, fx.auth, record, 3, t0 + 300), try said(arena, fx.auth, record, 2, t0 + 100) });
    const r = try read(arena, fx.f, till, .{ .member = "till", .record = record, .statements = statements }, auth);
    try testing.expectEqual(State.held, r.seen.state);
    try testing.expectEqual(@as(usize, 5), r.seen.entries);
    // the anchor is the digest of the whole last line -- the chain of ONE device -- and not the entry's `hash=`, which
    // is a hash of public bytes
    const want = timeattest.entryDigest(lineOf(record, 5));
    try testing.expectEqualSlices(u8, &want, &r.seen.head.?);
    try testing.expectEqualSlices(u8, &r.digests[4], &r.seen.head.?);
    const hash_field = journal.verify(record, fx.till.public_key).last_hash;
    try testing.expect(!std.mem.eql(u8, &hash_field, &r.seen.head.?));
    try testing.expectEqual(@as(usize, 3), r.seen.dated); // entry 3 is the newest anybody dated; 4 and 5 are not
    try testing.expectEqual(@as(?i64, t0 + 300), r.seen.t);
    try testing.expectEqual(@as(?i64, t0 + 100), r.bounds[0]); // the earlier statement is the tighter bound for the entries it names
    try testing.expectEqual(@as(?i64, t0 + 100), r.bounds[1]);
    try testing.expectEqual(@as(?i64, t0 + 300), r.bounds[2]);
    try testing.expectEqual(@as(?i64, null), r.bounds[3]);
    try testing.expectEqual(@as(?i64, null), r.bounds[4]);
    try testing.expectEqual(@as(usize, 2), r.statements);
    try testing.expectEqual(@as(usize, 0), r.refused + r.foreign);

    // nothing brought beside the record: held, and every entry undated -- a date it cannot stand behind is not printed
    const bare_r = try read(arena, fx.f, till, .{ .member = "till", .record = record }, auth);
    try testing.expectEqual(State.held, bare_r.seen.state);
    try testing.expectEqual(@as(usize, 0), bare_r.seen.dated);
    try testing.expect(!bare_r.had_statements);
    // and with an authority that is not this fleet's, nothing is taken
    const other = try pairOf(0xee);
    const stray = try said(arena, other, record, 5, t0 + 900);
    const refused = try read(arena, fx.f, till, .{ .member = "till", .record = record, .statements = stray }, auth);
    try testing.expectEqual(State.held, refused.seen.state);
    try testing.expectEqual(@as(usize, 1), refused.refused);
    try testing.expectEqual(@as(usize, 0), refused.seen.dated);
    // a statement changed by a second is not the authority's
    var changed: [timeattest.max_line]u8 = undefined;
    const good = try said(arena, fx.auth, record, 4, t0 + 400);
    const one = try std.fmt.bufPrint(&changed, "{s}", .{std.mem.trimRight(u8, good, "\n")});
    const at_t = std.mem.indexOf(u8, one, " t=").? + 3;
    one[at_t + 9] = if (one[at_t + 9] == '0') '1' else '0'; // the last digit of the time
    const tampered = try read(arena, fx.f, till, .{ .member = "till", .record = record, .statements = one }, auth);
    try testing.expectEqual(@as(usize, 1), tampered.refused);
    try testing.expectEqual(@as(usize, 0), tampered.seen.dated);
    // a statement the authority signed about an entry this record does not hold: another record's, or a cut one
    const long = try recordOf(arena, fx.till, "till", 6);
    const cut = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 4), .statements = try said(arena, fx.auth, long, 6, t0 + 600) }, auth);
    try testing.expectEqual(State.held, cut.seen.state);
    try testing.expectEqual(@as(usize, 1), cut.foreign);
    try testing.expectEqual(@as(usize, 0), cut.seen.dated);
}

test "a record that is not the member's, not in order, not there or not enrolled is named for what it is (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const till = fx.f.member("till").?;
    const record = try recordOf(arena, fx.till, "till", 5);

    // a machine that keeps no record is not asked for one
    const clockbox = try read(arena, fx.f, fx.f.member("clockbox").?, .{ .member = "clockbox" }, null);
    try testing.expectEqual(State.none, clockbox.seen.state);
    // one that does, and nobody brought it
    const absent = try read(arena, fx.f, till, .{ .member = "till" }, null);
    try testing.expectEqual(State.absent, absent.seen.state);
    try testing.expectEqualStrings("/data/journal", absent.kept_at);
    // a file with nothing in it is a different fact
    const empty = try read(arena, fx.f, till, .{ .member = "till", .record = "" }, null);
    try testing.expectEqual(State.empty, empty.seen.state);
    // another device's record
    const theirs = try read(arena, fx.f, till, .{ .member = "till", .record = try recordOf(arena, fx.till2, "till", 3) }, null);
    try testing.expectEqual(State.broken, theirs.seen.state);
    try testing.expectEqual(@as(?usize, 1), theirs.broken_at);
    try testing.expectEqual(@as(usize, 0), theirs.seen.entries);
    // an entry changed after it was written: the entries before it still stand, and none of them is an anchor of THIS
    // observation (a broken record has no head: the roll before's is carried)
    const broken = try read(arena, fx.f, till, .{ .member = "till", .record = try altered(arena, record, 3) }, null);
    try testing.expectEqual(State.broken, broken.seen.state);
    try testing.expectEqual(@as(?usize, 3), broken.broken_at);
    try testing.expectEqual(@as(usize, 2), broken.seen.entries);
    try testing.expectEqual(@as(usize, 2), broken.digests.len);
    try testing.expect(broken.seen.head == null);
    // an entry taken out of the middle
    var taken: std.ArrayList(u8) = .{};
    var it = std.mem.splitScalar(u8, record, '\n');
    var n: usize = 0;
    while (it.next()) |l| {
        if (l.len == 0) continue;
        n += 1;
        if (n == 3) continue;
        try taken.appendSlice(arena, l);
        try taken.append(arena, '\n');
    }
    const removed = try read(arena, fx.f, till, .{ .member = "till", .record = taken.items }, null);
    try testing.expectEqual(State.broken, removed.seen.state);
    try testing.expectEqual(@as(usize, 2), removed.seen.entries);

    // a member the fleet holds no key for: nobody can speak for its records
    const unkeyed = try timeFleet(arena, false);
    const unenrolled = try read(arena, unkeyed.f, unkeyed.f.member("till").?, .{ .member = "till", .record = record }, null);
    try testing.expectEqual(State.unenrolled, unenrolled.seen.state);
}

test "a record heard under a retired key, one that went on past it, and one nobody ever signed are named for what they are (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const old = try pairOf(0x42);
    const new = try pairOf(0x43);
    const stranger = try pairOf(0x44);
    const old_chain = try recordOf(arena, old, "depot", 3);
    const head = journal.verify(old_chain, old.public_key).last_hash;
    const f = try cardFleet(arena, old, new, &head);
    const depot = f.member("depot").?;

    // the first card's chain, through the entry the fleet trusts that key through: held, and said to be heard under
    // the key it no longer holds
    const through = try read(arena, f, depot, .{ .member = "depot", .record = old_chain }, null);
    try testing.expectEqual(State.held, through.seen.state);
    try testing.expectEqual(@as(usize, 3), through.seen.entries);
    try testing.expectEqualStrings("card_1", through.retired_as.?);
    // the second card's chain, in full
    const fresh = try read(arena, f, depot, .{ .member = "depot", .record = try recordOf(arena, new, "depot", 2) }, null);
    try testing.expectEqual(State.held, fresh.seen.state);
    try testing.expect(fresh.retired_as == null);
    // the first card went on signing after it was retired: broken at the first entry past the head
    const stolen = try read(arena, f, depot, .{ .member = "depot", .record = try recordOf(arena, old, "depot", 4) }, null);
    try testing.expectEqual(State.broken, stolen.seen.state);
    try testing.expectEqual(@as(?usize, 4), stolen.broken_at);
    // a shorter chain from the first card never reaches the head, and there is no entry to point at
    const short = try read(arena, f, depot, .{ .member = "depot", .record = firstOf(old_chain, 2) }, null);
    try testing.expectEqual(State.broken, short.seen.state);
    try testing.expectEqual(@as(?usize, null), short.broken_at);
    try testing.expectEqual(@as(usize, 2), short.seen.entries);
    // against a roll that held it, that is a record nobody can vouch for -- not a break inside it or after it
    const seen = [_]Seen{.{ .name = "depot", .state = .held, .entries = 3, .head = through.seen.head, .last = at1 }};
    try testing.expectEqual(std.meta.Tag(Change).unvouched, std.meta.activeTag(compare(Roll{ .fleet = "f", .at = at1, .members = &seen }, short)));
    // a chain neither card signed is a break at its first entry
    const alien = try read(arena, f, depot, .{ .member = "depot", .record = try recordOf(arena, stranger, "depot", 2) }, null);
    try testing.expectEqual(State.broken, alien.seen.state);
    try testing.expectEqual(@as(?usize, 1), alien.broken_at);

    // a member that holds no key today: a chain none of the keys it has held signed is not its own
    const keyless = try cardFleet(arena, old, null, &head);
    const nobody = try read(arena, keyless, keyless.member("depot").?, .{ .member = "depot", .record = try recordOf(arena, stranger, "depot", 2) }, null);
    try testing.expectEqual(State.unsigned, nobody.seen.state);
}

test "a chain is named by the device that signed it, so a rebuilt card is not the old card's chain extended (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const auth = Authority{ .name = "clockbox", .key = fx.auth.public_key, .fingerprint = fx.f.member("clockbox").?.fingerprint.? };
    // the till's card is replaced: the fleet now holds the second device's key for the member `till`
    const swapped = try timeFleetOf(arena, fx.till2, false);

    // the same design, the same machine name and declaration, every verdict `matched`: the entries' own hashes -- a
    // hash of public bytes -- are the same chain through the third entry on both cards
    const old_record = try recordOf(arena, fx.till, "till", 3);
    const new_record = try recordOf(arena, fx.till2, "till", 5);
    const old_hash = journal.verify(old_record, fx.till.public_key).last_hash;
    const new_hash = journal.verify(firstOf(new_record, 3), fx.till2.public_key).last_hash;
    try testing.expectEqualSlices(u8, &old_hash, &new_hash);

    const before = try read(arena, fx.f, fx.f.member("till").?, .{ .member = "till", .record = old_record }, auth);
    const members = [_]Seen{stored(null, before, .first, at1)};
    const anchored = Roll{ .fleet = "nuage", .at = at1, .members = &members };
    // a head made of the entry's hash would call the new card's record the old one extended, because it has more
    // entries; the line's digest names the signer, and it is another chain
    const after = try read(arena, swapped.f, swapped.f.member("till").?, .{ .member = "till", .record = new_record }, auth);
    try testing.expectEqual(State.held, after.seen.state);
    try testing.expectEqual(std.meta.Tag(Change).forked, std.meta.activeTag(compare(anchored, after)));
    // and with as many entries, or fewer, it is not the old card's either
    const same = try read(arena, swapped.f, swapped.f.member("till").?, .{ .member = "till", .record = firstOf(new_record, 3) }, auth);
    try testing.expectEqual(std.meta.Tag(Change).forked, std.meta.activeTag(compare(anchored, same)));
    const fewer = try read(arena, swapped.f, swapped.f.member("till").?, .{ .member = "till", .record = firstOf(new_record, 2) }, auth);
    try testing.expectEqual(std.meta.Tag(Change).shorter, std.meta.activeTag(compare(anchored, fewer)));

    // and said in words, for a set: the roll that held the old card's record, then the same member with the new card
    const old_call = try callIt(arena, fx.f, &.{.{ .member = "till", .record = old_record }}, null, at1);
    const new_call = try callIt(arena, swapped.f, &.{.{ .member = "till", .record = new_record }}, try kept(arena, old_call.c), at2);
    try testing.expect(!new_call.c.clean);
    try must(new_call.text, "roll: till -- DIVERGED: the roll of 2026-09-21 14:15 UTC held 3 entries ending in ");
    try must(new_call.text, ": not the same chain -- another device's, or written again from the start. It stays DIVERGED until a roll is called again without --since");
    // the two digests it names are the two chains' own, and in the order the sentence says them
    const old_head = timeattest.entryDigest(lineOf(old_record, 3));
    const new_entry = timeattest.entryDigest(lineOf(new_record, 3));
    try must(new_call.text, try std.fmt.allocPrint(arena, "held 3 entries ending in {s}, and this record's entry 3 is {s}: not the same chain", .{ old_head[0..8], new_entry[0..8] }));
    try must(new_call.text, "roll: till2 -- LEFT the fleet since the roll of 2026-09-21 14:15 UTC: that roll had it as absent");
    try must(new_call.text, "roll: 0 of 1 record held; since the last roll 0 wrote, 0 had nothing new, 0 absent, 1 diverged, 0 new, 1 left the fleet");
}

test "against the roll before it, a record has written, had nothing new, gone backwards or gone (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const till = fx.f.member("till").?;
    const auth = Authority{ .name = "clockbox", .key = fx.auth.public_key, .fingerprint = fx.f.member("clockbox").?.fingerprint.? };
    const long = try recordOf(arena, fx.till, "till", 6);
    const three = firstOf(long, 3);

    // the roll that saw three entries
    const first = try read(arena, fx.f, till, .{ .member = "till", .record = three }, auth);
    const seen = [_]Seen{stored(null, first, .first, at1)};
    const before = Roll{ .fleet = "nuage", .at = at1, .members = &seen };
    try testing.expectEqual(at1, seen[0].last.?);

    // no roll before: nothing to compare with
    try testing.expectEqual(std.meta.Tag(Change).first, std.meta.activeTag(compare(null, first)));
    // the same record: nothing new
    try testing.expectEqual(std.meta.Tag(Change).silent, std.meta.activeTag(compare(before, first)));
    // the record, gone on: two entries written, the first of them dated, the second not
    const st = try said(arena, fx.auth, long, 4, t0 + 777);
    const later = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 5), .statements = st }, auth);
    switch (compare(before, later)) {
        .wrote => |w| {
            try testing.expectEqual(@as(usize, 3), w.old.entries);
            try testing.expectEqual(@as(usize, 5), w.to);
            try testing.expectEqual(@as(?i64, t0 + 777), w.first_bound);
            try testing.expectEqual(@as(usize, 1), w.undated);
            try testing.expect(!w.stale);
        },
        else => return error.NotWritten,
    }
    // the authority dates the first of them BEFORE the roll that did not have it: that roll saw a stale copy, or the
    // clocks disagree
    const early = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 5), .statements = try said(arena, fx.auth, long, 4, at1 - 10) }, auth);
    switch (compare(before, early)) {
        .wrote => |w| try testing.expect(w.stale),
        else => return error.NotWritten,
    }
    // undated, none of it has a time on it, and so nothing can be stale
    const undated = try read(arena, fx.f, till, .{ .member = "till", .record = long }, auth);
    switch (compare(before, undated)) {
        .wrote => |w| {
            try testing.expectEqual(@as(?i64, null), w.first_bound);
            try testing.expectEqual(@as(usize, 3), w.undated);
            try testing.expect(!w.stale);
        },
        else => return error.NotWritten,
    }
    // shorter than the roll saw: a record is only ever extended
    const two = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 2) }, auth);
    try testing.expectEqual(std.meta.Tag(Change).shorter, std.meta.activeTag(compare(before, two)));
    // as long, and not the same chain: the same device's, written again from the start
    const forked_record = try recordOf(arena, fx.till, "rebuilt", 3);
    const forked = try read(arena, fx.f, till, .{ .member = "till", .record = forked_record }, auth);
    try testing.expectEqual(std.meta.Tag(Change).forked, std.meta.activeTag(compare(before, forked)));
    // longer, and not the same chain
    const forked_long = try read(arena, fx.f, till, .{ .member = "till", .record = try recordOf(arena, fx.till, "rebuilt", 6) }, auth);
    try testing.expectEqual(std.meta.Tag(Change).forked, std.meta.activeTag(compare(before, forked_long)));
    // held then and nobody brought it now
    const absent = try read(arena, fx.f, till, .{ .member = "till" }, auth);
    try testing.expectEqual(std.meta.Tag(Change).absent_since, std.meta.activeTag(compare(before, absent)));
    // a break inside what the roll vouched for, and one after it
    const inside = try read(arena, fx.f, till, .{ .member = "till", .record = try altered(arena, long, 2) }, auth);
    try testing.expectEqual(std.meta.Tag(Change).broken_within, std.meta.activeTag(compare(before, inside)));
    const past = try read(arena, fx.f, till, .{ .member = "till", .record = try altered(arena, long, 5) }, auth);
    try testing.expectEqual(State.broken, past.seen.state);
    try testing.expectEqual(std.meta.Tag(Change).broken_after, std.meta.activeTag(compare(before, past)));
    // held then, and nothing can be said of it now
    const nothing = try read(arena, fx.f, till, .{ .member = "till", .record = "" }, auth);
    try testing.expectEqual(std.meta.Tag(Change).unvouched, std.meta.activeTag(compare(before, nothing)));
    // a member the roll before did not have
    const other = [_]Seen{.{ .name = "till2", .state = .absent }};
    try testing.expectEqual(std.meta.Tag(Change).new, std.meta.activeTag(compare(Roll{ .fleet = "nuage", .at = at1, .members = &other }, first)));
    // a roll that never held it gives no anchor to look for
    try testing.expectEqual(std.meta.Tag(Change).no_anchor, std.meta.activeTag(compare(Roll{ .fleet = "nuage", .at = at1, .members = &[_]Seen{.{ .name = "till", .state = .absent }} }, first)));
    // a machine that keeps no record has nothing to compare, unless the roll before held one of it
    const none = try read(arena, fx.f, fx.f.member("clockbox").?, .{ .member = "clockbox" }, auth);
    try testing.expectEqual(std.meta.Tag(Change).nothing, std.meta.activeTag(compare(before, none)));
    const held_clockbox = [_]Seen{.{ .name = "clockbox", .state = .held, .entries = 2, .head = first.seen.head, .last = at1 }};
    try testing.expectEqual(std.meta.Tag(Change).no_longer, std.meta.activeTag(compare(Roll{ .fleet = "nuage", .at = at1, .members = &held_clockbox }, none)));
}

test "what a roll writes down is the last observation that was held, and a missed collection does not lose it (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const till = fx.f.member("till").?;
    const auth = Authority{ .name = "clockbox", .key = fx.auth.public_key, .fingerprint = fx.f.member("clockbox").?.fingerprint.? };
    const long = try recordOf(arena, fx.till, "till", 6);

    const held3 = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 3) }, auth);
    const first_seen = stored(null, held3, .first, at1);
    try testing.expectEqual(State.held, first_seen.state);
    try testing.expectEqual(@as(usize, 3), first_seen.entries);
    try testing.expectEqual(@as(?i64, at1), first_seen.last);
    const r1 = Roll{ .fleet = "nuage", .at = at1, .members = &[_]Seen{first_seen} };

    // nobody brought it: the member is ABSENT, and the anchor is the roll before's, with the time that roll held it
    const absent = try read(arena, fx.f, till, .{ .member = "till" }, auth);
    const lost = stored(r1, absent, compare(r1, absent), at2);
    try testing.expectEqual(State.absent, lost.state);
    try testing.expectEqual(@as(usize, 3), lost.entries);
    try testing.expectEqual(first_seen.head.?, lost.head.?);
    try testing.expectEqual(@as(?i64, at1), lost.last);
    // and so for a record that does not verify, one nobody can vouch for, and one the machine no longer keeps
    const broken = try read(arena, fx.f, till, .{ .member = "till", .record = try altered(arena, long, 2) }, auth);
    try testing.expectEqual(@as(?i64, at1), stored(r1, broken, compare(r1, broken), at2).last);
    try testing.expectEqual(@as(usize, 3), stored(r1, broken, compare(r1, broken), at2).entries);
    // a record that goes BACKWARDS is held, and does not replace the anchor: it is DIVERGED until somebody says otherwise
    const cut = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 2) }, auth);
    const diverged = stored(r1, cut, compare(r1, cut), at2);
    try testing.expectEqual(State.diverged, diverged.state);
    try testing.expectEqual(@as(usize, 3), diverged.entries);
    try testing.expectEqual(@as(?i64, at1), diverged.last);
    // a record that goes on is this roll's own observation
    const more = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 5) }, auth);
    const gone_on = stored(r1, more, compare(r1, more), at2);
    try testing.expectEqual(State.held, gone_on.state);
    try testing.expectEqual(@as(usize, 5), gone_on.entries);
    try testing.expectEqual(@as(?i64, at2), gone_on.last);
    // a member that was never held has no anchor to carry
    const never = stored(null, absent, .first, at1);
    try testing.expect(never.head == null and never.last == null);
}

test "the whole set is called, and said in words a person can act on (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const till_long = try recordOf(arena, fx.till, "till", 5);
    const till2_long = try recordOf(arena, fx.till2, "till2", 4);

    // the first roll: till at three entries (all dated), till2 at four (none dated); the clock box keeps none
    const first = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(till_long, 3), .statements = try said(arena, fx.auth, till_long, 3, t0 + 60) },
        .{ .member = "till2", .record = till2_long },
    }, null, at1);
    try testing.expect(first.c.clean);
    try must(first.text, "roll: fleet nuage -- 3 members, 2 keep a record; as of ");
    try must(first.text, "roll: dates come from clockbox (fingerprint ");
    try must(first.text, "roll: this is the first roll");
    try must(first.text, "roll: clockbox -- keeps no record: its machine declares no JOURNAL");
    try must(first.text, "roll: till -- 3 entries, from its first, in order, each signed by the key enrolled for it");
    // the head the line prints is the head the roll will hold (a prefix of a digest that is gone reads as noise)
    const head_of_till = first.c.roll.members[1].head.?;
    try must(first.text, try std.fmt.allocPrint(arena, "; head {s}, and no secret took part", .{head_of_till[0..8]}));
    try must(first.text, "roll: till -- entry 3 of 3 existed no later than ");
    try must(first.text, "roll: till2 -- every entry is ORDERED and UNDATED here: no statements were brought beside the record");
    try must(first.text, "roll: 2 of 2 records held");
    try must(first.text, "roll: clean: every record that should be there is, and is its member's, in order from its first entry");

    // the roll is a file, and the next call is compared with it
    const r1 = try kept(arena, first.c);
    // two hours later: till wrote two entries (dated), till2 has nothing new, and the clock box still keeps none
    const second = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = till_long, .statements = try joined(arena, &.{ try said(arena, fx.auth, till_long, 3, t0 + 60), try said(arena, fx.auth, till_long, 5, t0 + 7000) }) },
        .{ .member = "till2", .record = till2_long },
    }, r1, at2);
    try testing.expect(second.c.clean);
    try must(second.text, "roll: compared with the roll of ");
    try must(second.text, "2 h 5 min before this one by the caller's clock");
    try must(second.text, "roll: till -- WROTE 2 entries since the roll of ");
    try must(second.text, "(entries 4-5); the first existed no later than ");
    // dated up to entry 4 only: the last entry written since is the one nothing dates
    const partly = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = till_long, .statements = try said(arena, fx.auth, till_long, 4, t0 + 5000) },
        .{ .member = "till2", .record = till2_long },
    }, r1, at2);
    try must(partly.text, "; the first existed no later than ");
    try must(partly.text, ", and the last one is ORDERED and UNDATED");
    try must(partly.text, "; the entry after it is ORDERED and UNDATED");
    try must(second.text, "roll: till2 -- NOTHING NEW since the roll of ");
    try must(second.text, try std.fmt.allocPrint(arena, "the record brought still ends at entry 4, head {s}", .{second.c.roll.members[2].head.?[0..8]}));
    try must(second.text, "roll: 2 of 2 records held; since the last roll 1 wrote, 1 had nothing new, 0 absent, 0 diverged, 0 new, 0 left the fleet");
    try must(second.text, "roll: clean: every record that should be there is, is its member's, and goes on from the roll before it wherever that roll held it");
    const r2 = try kept(arena, second.c);

    // a caller's clock that reads before the roll it is compared with is said, and no span is made up
    const backwards = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = till_long },
        .{ .member = "till2", .record = till2_long },
    }, r1, at1 - 60);
    try must(backwards.text, "which the caller's clock reads as LATER than this one");
    try mustNot(backwards.text, "before this one by the caller's clock");
    // and so is a roll that took its time from another authority: the two are not one clock's
    var alien = r1;
    alien.authority = [_]u8{'0'} ** 16;
    const strange = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = till_long },
        .{ .member = "till2", .record = till2_long },
    }, alien, at2);
    try must(strange.text, "that roll took its time from another authority (fingerprint 0000000000000000)");

    // a third roll finds till2 not brought, and till cut back to two entries
    const third = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(till_long, 2) },
    }, r2, at2 + 3600);
    try testing.expect(!third.c.clean);
    try must(third.text, "roll: till2 -- ABSENT: its machine keeps a record at /data/journal, and none was brought");
    try must(third.text, "roll: till2 -- the roll of ");
    try must(third.text, " held it: 4 entries, head ");
    try must(third.text, "none of them dated");
    try must(third.text, "roll: till -- DIVERGED: the roll of ");
    try must(third.text, " held 5 entries and this record holds 2");
    try must(third.text, "It stays DIVERGED until a roll is called again without --since");
    try must(third.text, "roll: NOT clean: 2 things the set owes an answer for");
    try must(third.text, "1 absent, 1 diverged");
    const r3 = try kept(arena, third.c);
    // ... and the roll it writes does not forget what it lost: till2's record, cut back or forked after one missed
    // collection, is DIVERGED and not a first look; the diverged record is DIVERGED again, not accepted
    try testing.expectEqual(State.absent, r3.find("till2").?.state);
    try testing.expectEqual(@as(usize, 4), r3.find("till2").?.entries);
    try testing.expectEqual(State.diverged, r3.find("till").?.state);
    try testing.expectEqual(@as(usize, 5), r3.find("till").?.entries);
    const fourth = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(till_long, 2) },
        .{ .member = "till2", .record = firstOf(till2_long, 2) },
    }, r3, at2 + 7200);
    try testing.expect(!fourth.c.clean);
    try must(fourth.text, "roll: till2 -- DIVERGED: the roll of ");
    try must(fourth.text, " held 4 entries and this record holds 2");
    try must(fourth.text, "roll: till -- DIVERGED: the roll of ");
    try mustNot(fourth.text, "never held it");
    // till2 comes back whole, and the roll says it wrote since the roll that last HELD it, not since the one that missed it
    const fifth = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = till_long },
        .{ .member = "till2", .record = try recordOf(arena, fx.till2, "till2", 6) },
    }, try kept(arena, fourth.c), at2 + 10800);
    try testing.expect(fifth.c.clean);
    try must(fifth.text, "roll: till2 -- WROTE 2 entries since the roll of ");
    // a roll called again without --since is the new anchor: what was diverged is a first look, and clean
    const reanchored = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(till_long, 2) },
        .{ .member = "till2", .record = firstOf(till2_long, 2) },
    }, null, at2 + 14400);
    try testing.expect(reanchored.c.clean);
    const sixth = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(till_long, 2) },
        .{ .member = "till2", .record = firstOf(till2_long, 2) },
    }, try kept(arena, reanchored.c), at2 + 18000);
    try testing.expect(sixth.c.clean);
    try must(sixth.text, "roll: till -- NOTHING NEW since the roll of ");

    // a member the roll before had and the fleet no longer names LEFT; one it did not have is NEW
    var older: std.ArrayList(Seen) = .{};
    try older.append(arena, r2.members[0]); // clockbox
    try older.append(arena, r2.members[1]); // till
    try older.append(arena, .{ .name = "gone_one", .state = .held, .entries = 2, .head = r2.members[1].head, .last = at1 });
    const departed = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = till_long },
        .{ .member = "till2", .record = till2_long },
    }, Roll{ .fleet = "nuage", .at = at1, .members = older.items }, at2);
    try testing.expect(departed.c.clean);
    try must(departed.text, "roll: gone_one -- LEFT the fleet since the roll of ");
    try must(departed.text, "with an anchor at 2 entries");
    try must(departed.text, "roll: till2 -- NEW: the roll of ");
    try must(departed.text, "1 new, 1 left the fleet");

    // the same call, said twice, is said the same: nothing in a roll is a clock that moved
    const again = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(till_long, 3), .statements = try said(arena, fx.auth, till_long, 3, t0 + 60) },
        .{ .member = "till2", .record = till2_long },
    }, null, at1);
    try testing.expectEqualStrings(first.text, again.text);
    try testing.expectEqualStrings(try render(arena, first.c.roll), try render(arena, again.c.roll));
}

test "a record that does not verify, is nobody's, or is empty makes a roll that is not clean, in words (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const record = try recordOf(arena, fx.till, "till", 3);
    const second = try recordOf(arena, fx.till2, "till2", 2);

    // another device's chain under this member's name, and an entry changed in the middle of its own
    const theirs = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = try recordOf(arena, fx.till2, "till", 3) },
        .{ .member = "till2", .record = second },
    }, null, at1);
    try testing.expect(!theirs.c.clean);
    try must(theirs.text, "roll: till -- BROKEN at entry 1: ");
    try must(theirs.text, "; 0 entries verified before it");
    try must(theirs.text, "roll: 1 of 2 records held");
    try must(theirs.text, "roll: NOT clean: 1 thing the set owes an answer for");
    const changed = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = try altered(arena, record, 3) },
        .{ .member = "till2", .record = second },
    }, null, at1);
    try testing.expect(!changed.c.clean);
    try must(changed.text, "roll: till -- BROKEN at entry 3: ");
    try must(changed.text, "; 2 entries verified before it");
    // a record with nothing in it
    const empty = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = "" },
        .{ .member = "till2", .record = second },
    }, null, at1);
    try testing.expect(!empty.c.clean);
    try must(empty.text, "roll: till -- EMPTY: the record that was brought holds no entry");
    // a member the fleet holds no key for
    const unkeyed = try timeFleet(arena, false);
    const nobody = try callIt(arena, unkeyed.f, &.{
        .{ .member = "till", .record = record },
        .{ .member = "till2", .record = second },
    }, null, at1);
    try testing.expect(!nobody.c.clean);
    try must(nobody.text, "roll: till -- NOT ENROLLED: the fleet holds no key for it");

    // a member that was retired once: the first card's chain is heard through its head, and a record that stops short
    // of the head is not a record anybody can vouch for
    const old = try pairOf(0x42);
    const new = try pairOf(0x43);
    const stranger = try pairOf(0x44);
    const old_chain = try recordOf(arena, old, "depot", 3);
    const head = journal.verify(old_chain, old.public_key).last_hash;
    const card = try cardFleet(arena, old, new, &head);
    const through = try callIt(arena, card, &.{.{ .member = "depot", .record = old_chain }}, null, at1);
    try testing.expect(through.c.clean);
    try must(through.text, "roll: fleet f -- 1 member, 1 keeps a record; as of ");
    try must(through.text, "roll: depot -- 3 entries, from its first, in order, each signed by a key it no longer holds (retired as card_1)");
    const short = try callIt(arena, card, &.{.{ .member = "depot", .record = firstOf(old_chain, 2) }}, null, at1);
    try testing.expect(!short.c.clean);
    try must(short.text, "roll: depot -- BROKEN: every entry verifies under the key it has retired, and none is the entry the fleet trusts that key through");
    try must(short.text, "; 2 entries verify");
    // a member none of whose keys signed what was brought
    const keyless = try cardFleet(arena, old, null, &head);
    const unsigned = try callIt(arena, keyless, &.{.{ .member = "depot", .record = try recordOf(arena, stranger, "depot", 2) }}, null, at1);
    try testing.expect(!unsigned.c.clean);
    try must(unsigned.text, "roll: depot -- NOT ITS OWN: no key it has held signed the record that was brought");
}

test "a roll is always one the program can read back, or it is not written (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const long = try recordOf(arena, fx.till, "till", 6);
    const second = try recordOf(arena, fx.till2, "till2", 3);

    // every way a member's record can differ from the roll before it, brought later: the roll it makes reads back, and
    // so does the roll after that one, whatever it is shown -- an anchor carried across all of them is a roll that
    // nothing can make unreadable
    const brought = [_]?[]const u8{
        firstOf(long, 3), // the same
        firstOf(long, 5), // grown
        firstOf(long, 2), // cut back
        try recordOf(arena, fx.till2, "till", 4), // another device's chain under this member's name
        try altered(arena, long, 2), // changed inside what the roll saw
        try altered(arena, long, 5), // changed after it
        "", // nothing in it
        null, // not brought
    };
    const first = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(long, 3) },
        .{ .member = "till2", .record = second },
    }, null, at1);
    const r1 = try kept(arena, first.c);
    for (brought) |one| {
        const c2 = try callIt(arena, fx.f, &.{ .{ .member = "till", .record = one }, .{ .member = "till2", .record = second } }, r1, at2);
        const r2 = try kept(arena, c2.c);
        for (brought) |two| {
            const c3 = try callIt(arena, fx.f, &.{ .{ .member = "till", .record = two }, .{ .member = "till2", .record = second } }, r2, at2 + 3600);
            _ = try kept(arena, c3.c);
        }
    }
    // a fleet that does not enrol the member any more is one more way a record can be unreadable
    const unkeyed = try timeFleet(arena, false);
    const c4 = try callIt(arena, unkeyed.f, &.{ .{ .member = "till", .record = firstOf(long, 3) }, .{ .member = "till2", .record = second } }, r1, at2);
    _ = try kept(arena, c4.c);

    // a roll as of a time earlier than the roll it is compared with carries that roll's anchors and does not read back:
    // the call says so, and the verb refuses to write it (the verb's own test)
    const behind = try callIt(arena, fx.f, &.{ .{ .member = "till" }, .{ .member = "till2", .record = second } }, r1, at1 - 1000);
    try must(behind.text, "which the caller's clock reads as LATER than this one");
    try testing.expectError(error.Malformed, parse(arena, try render(arena, behind.c.roll)));
}

test "a machine that stops declaring a journal is said once, and a member that leaves is said when it still owed an answer (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const keeps = try estate(arena, true);
    const stops = try estate(arena, false);
    const a_rec = try recordOf(arena, keeps.a, "depot", 3);
    const b_rec = try recordOf(arena, keeps.b, "annex", 2);

    const first = try callIt(arena, keeps.f, &.{
        .{ .member = "depot", .record = a_rec },
        .{ .member = "annex", .record = b_rec },
    }, null, at1);
    const r1 = try kept(arena, first.c);
    // the first roll that finds annex's machine without a JOURNAL says so, and is not clean
    const second = try callIt(arena, stops.f, &.{.{ .member = "depot", .record = a_rec }}, r1, at2);
    try testing.expect(!second.c.clean);
    try must(second.text, "roll: annex -- NO LONGER KEEPS A RECORD");
    const r2 = try kept(arena, second.c);
    // the roll after it has nothing more to say: it was said once, and the anchor is kept, silent, for the day the
    // machine names a journal again
    const third = try callIt(arena, stops.f, &.{.{ .member = "depot", .record = a_rec }}, r2, at2 + 3600);
    try testing.expect(third.c.clean);
    try mustNot(third.text, "NO LONGER");
    try must(third.text, "roll: annex -- keeps no record: its machine declares no JOURNAL, so there is none to bring");
    const r3 = try kept(arena, third.c);
    try testing.expectEqual(@as(usize, 2), r3.find("annex").?.entries);
    // named again, with its record gone on, it goes on from where the roll that held it left it
    const fourth = try callIt(arena, keeps.f, &.{
        .{ .member = "depot", .record = a_rec },
        .{ .member = "annex", .record = try recordOf(arena, keeps.b, "annex", 4) },
    }, r3, at2 + 7200);
    try testing.expect(fourth.c.clean);
    try must(fourth.text, "roll: annex -- WROTE 2 entries since the roll of 2026-09-21 14:15 UTC (entries 3-4)");

    // a member the fleet file stops naming: one the roll held and has nothing outstanding about is said and costs
    // nothing; one it still owed an answer for (nobody could bring it, it had gone backwards) is a finding, because the
    // roll written now has nothing of it and a divergence must not be a thing deleting a member makes go away unseen
    const fx = try timeFleet(arena, true);
    const head = timeattest.entryDigest("an entry");
    const earlier = [_]Seen{
        .{ .name = "clockbox", .state = .none },
        .{ .name = "gone_held", .state = .held, .entries = 2, .head = head, .last = at1 },
        .{ .name = "gone_absent", .state = .absent, .entries = 2, .head = head, .last = at1 },
        .{ .name = "gone_diverged", .state = .diverged, .entries = 2, .head = head, .last = at1 },
        .{ .name = "gone_unkept", .state = .none, .entries = 2, .head = head, .last = at1 },
        .{ .name = "gone_nothing", .state = .none },
        .{ .name = "gone_never_held", .state = .absent },
    };
    const before = Roll{ .fleet = "nuage", .at = at1, .members = &earlier };
    const left = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = try recordOf(arena, fx.till, "till", 2) },
        .{ .member = "till2", .record = try recordOf(arena, fx.till2, "till2", 2) },
    }, before, at2);
    try testing.expect(!left.c.clean);
    try must(left.text, "roll: gone_held -- LEFT the fleet since the roll of 2026-09-21 14:15 UTC: that roll had it as held, with an anchor at 2 entries, head ");
    try must(left.text, "roll: gone_absent -- LEFT the fleet since the roll of 2026-09-21 14:15 UTC: that roll had it as absent, with an anchor at 2 entries, head ");
    try must(left.text, "roll: gone_diverged -- LEFT the fleet since the roll of 2026-09-21 14:15 UTC: that roll had it as diverged, with an anchor at 2 entries, head ");
    try must(left.text, "roll: gone_unkept -- LEFT the fleet since the roll of 2026-09-21 14:15 UTC: that roll had it as none, with an anchor at 2 entries, head ");
    try must(left.text, "roll: gone_never_held -- LEFT the fleet since the roll of 2026-09-21 14:15 UTC: that roll had it as absent\n");
    try mustNot(left.text, "gone_nothing");
    // two findings, and not five: the two the roll still owed an answer for
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, left.text, " -- FINDING: the fleet file no longer names it, and the roll written now has nothing of it"));
    try must(left.text, "roll: NOT clean: 2 things the set owes an answer for");
    try must(left.text, "roll: 2 of 2 records held; since the last roll 0 wrote, 0 had nothing new, 0 absent, 0 diverged, 2 new, 5 left the fleet");
    // ... and said once: the roll it wrote has none of them, and the one after it is clean
    const after = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = try recordOf(arena, fx.till, "till", 2) },
        .{ .member = "till2", .record = try recordOf(arena, fx.till2, "till2", 2) },
    }, try kept(arena, left.c), at2 + 3600);
    try testing.expect(after.c.clean);
    try mustNot(after.text, "LEFT");
}

test "a clock that went backwards between statements is a finding, and a date equal to the roll's is not a stale copy (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const till = fx.f.member("till").?;
    const auth = Authority{ .name = "clockbox", .key = fx.auth.public_key, .fingerprint = fx.f.member("clockbox").?.fingerprint.? };
    const long = try recordOf(arena, fx.till, "till", 6);

    // entry 2 dated after entry 4: the authority's clock went backwards between them, or one of them is wrong
    const wrong_way = try joined(arena, &.{ try said(arena, fx.auth, long, 2, t0 + 500), try said(arena, fx.auth, long, 4, t0 + 100) });
    const r = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 4), .statements = wrong_way }, auth);
    try testing.expectEqual(@as(usize, 1), r.backwards);
    const c = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(long, 4), .statements = wrong_way },
        .{ .member = "till2", .record = try recordOf(arena, fx.till2, "till2", 1) },
    }, null, at1);
    try testing.expect(!c.c.clean);
    try must(c.text, "roll: till -- FINDING: 1 statement cannot be right of a clock that runs forward with an earlier one: an entry written later is dated earlier -- clockbox's clock went backwards between them, or one of them is wrong");
    // the same two statements the right way round are not
    const right_way = try joined(arena, &.{ try said(arena, fx.auth, long, 2, t0 + 100), try said(arena, fx.auth, long, 4, t0 + 500) });
    const fine = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 4), .statements = right_way }, auth);
    try testing.expectEqual(@as(usize, 0), fine.backwards);

    // a bound equal to the roll's own time is not a copy older than the roll said: the authority read its clock at the
    // very second the roll was as of, and the entry may have been written a moment after the copy was taken
    const held = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 3) }, auth);
    const seen = [_]Seen{stored(null, held, .first, at1)};
    const before = Roll{ .fleet = "nuage", .at = at1, .members = &seen };
    const on_the_second = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 5), .statements = try said(arena, fx.auth, long, 4, at1) }, auth);
    switch (compare(before, on_the_second)) {
        .wrote => |w| try testing.expect(!w.stale),
        else => return error.NotWritten,
    }
    const a_second_earlier = try read(arena, fx.f, till, .{ .member = "till", .record = firstOf(long, 5), .statements = try said(arena, fx.auth, long, 4, at1 - 1) }, auth);
    switch (compare(before, a_second_earlier)) {
        .wrote => |w| try testing.expect(w.stale),
        else => return error.NotWritten,
    }
}

test "a record with blank lines or carriage returns is counted as the journal counts it (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const till = fx.f.member("till").?;
    const plain = try recordOf(arena, fx.till, "till", 4);
    const blank = try std.mem.replaceOwned(u8, arena, plain, "\n", "\n\n");
    const crlf = try std.mem.replaceOwned(u8, arena, plain, "\n", "\r\n");
    const want = try read(arena, fx.f, till, .{ .member = "till", .record = plain }, null);
    try testing.expectEqual(@as(usize, 4), want.digests.len);
    // the journal's verifier skips a blank line and trims a carriage return, so these are the same four entries, and the
    // digest of an entry is the digest of its line and not of the bytes that ended it
    for ([_][]const u8{ blank, crlf }) |variant| {
        const got = try read(arena, fx.f, till, .{ .member = "till", .record = variant }, null);
        try testing.expectEqual(State.held, got.seen.state);
        try testing.expectEqual(@as(usize, 4), got.seen.entries);
        try testing.expectEqual(journal.verify(variant, fx.till.public_key).verified, got.seen.entries);
        try testing.expectEqual(want.digests.len, got.digests.len);
        for (want.digests, got.digests) |a, b| try testing.expectEqualSlices(u8, &a, &b);
    }
    // a statement about an entry binds to it however the record was copied
    const statement = try said(arena, fx.auth, plain, 3, t0 + 300);
    const auth = Authority{ .name = "clockbox", .key = fx.auth.public_key, .fingerprint = fx.f.member("clockbox").?.fingerprint.? };
    const dated = try read(arena, fx.f, till, .{ .member = "till", .record = crlf, .statements = statement }, auth);
    try testing.expectEqual(@as(usize, 3), dated.seen.dated);
}

test "how long ago is said in the words a person says it (ROLL-1)" {
    var buf: [48]u8 = undefined;
    const cases = [_]struct { secs: i64, want: []const u8 }{
        .{ .secs = -5, .want = "less than a minute" },
        .{ .secs = 0, .want = "less than a minute" },
        .{ .secs = 59, .want = "less than a minute" },
        .{ .secs = 60, .want = "1 min" },
        .{ .secs = 3599, .want = "59 min" },
        .{ .secs = 3600, .want = "1 h" },
        .{ .secs = 3660, .want = "1 h 1 min" },
        .{ .secs = 7500, .want = "2 h 5 min" },
        .{ .secs = 86399, .want = "23 h 59 min" },
        .{ .secs = 86400, .want = "1 d" },
        .{ .secs = 86400 + 3600, .want = "1 d 1 h" },
        .{ .secs = 2 * 86400 + 5 * 3600 + 59 * 60, .want = "2 d 5 h" },
        .{ .secs = 400 * 86400, .want = "400 d" },
    };
    for (cases) |c| try testing.expectEqualStrings(c.want, span(&buf, c.secs));
}

test "what the roll says of a record it cannot go on from is said in words (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const long = try recordOf(arena, fx.till, "till", 6);
    const second = try recordOf(arena, fx.till2, "till2", 2);

    // a roll that never held the member (it was not brought): there is no anchor to look for in what comes after
    const nothing = try callIt(arena, fx.f, &.{.{ .member = "till2", .record = second }}, null, at1);
    const r0 = try kept(arena, nothing.c);
    const then_there = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(long, 3) },
        .{ .member = "till2", .record = second },
    }, r0, at2);
    try testing.expect(then_there.c.clean);
    try must(then_there.text, "roll: till -- the roll of 2026-09-21 14:15 UTC never held it (absent), so there is no anchor to look for in this record");

    // a roll that held it, shown a record changed inside what it saw, changed after it, and nothing at all
    const held = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(long, 3) },
        .{ .member = "till2", .record = second },
    }, null, at1);
    const r1 = try kept(arena, held.c);
    const inside = try callIt(arena, fx.f, &.{ .{ .member = "till", .record = try altered(arena, long, 2) }, .{ .member = "till2", .record = second } }, r1, at2);
    try must(inside.text, "roll: till -- the break is inside what the roll of 2026-09-21 14:15 UTC vouched for (3 entries): entries that roll saw have been changed or removed");
    const after = try callIt(arena, fx.f, &.{ .{ .member = "till", .record = try altered(arena, long, 5) }, .{ .member = "till2", .record = second } }, r1, at2);
    try must(after.text, "roll: till -- the 3 entries the roll of 2026-09-21 14:15 UTC vouched for are intact; the break is in what was written after them");
    const empty = try callIt(arena, fx.f, &.{ .{ .member = "till", .record = "" }, .{ .member = "till2", .record = second } }, r1, at2);
    try must(empty.text, "roll: till -- the roll of 2026-09-21 14:15 UTC held it at 3 entries; this record cannot be vouched for");
}

test "a member whose machine stops declaring a journal is said, and the roll keeps what it held (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const keeps = try estate(arena, true);
    const stops = try estate(arena, false);
    const a_rec = try recordOf(arena, keeps.a, "depot", 3);
    const b_rec = try recordOf(arena, keeps.b, "annex", 2);

    const first = try callIt(arena, keeps.f, &.{
        .{ .member = "depot", .record = a_rec },
        .{ .member = "annex", .record = b_rec },
    }, null, at1);
    try testing.expect(first.c.clean);
    const r1 = try kept(arena, first.c);
    // the design changed: annex's machine does not declare a JOURNAL any more. Nothing is brought for it, and the
    // roll says what it held and is not clean -- a record that stopped existing in the declaration is not a silence
    const second = try callIt(arena, stops.f, &.{.{ .member = "depot", .record = a_rec }}, r1, at2);
    try testing.expect(!second.c.clean);
    try must(second.text, "roll: annex -- keeps no record: its machine declares no JOURNAL");
    try must(second.text, "roll: annex -- NO LONGER KEEPS A RECORD: its machine declares no JOURNAL now, and the roll of ");
    try must(second.text, " held it at 2 entries, head ");
    const r2 = try kept(arena, second.c);
    try testing.expectEqual(@as(usize, 2), r2.find("annex").?.entries); // carried
    // the machine declares it again, and the record has gone on: it wrote since the roll that held it
    const third = try callIt(arena, keeps.f, &.{
        .{ .member = "depot", .record = a_rec },
        .{ .member = "annex", .record = try recordOf(arena, keeps.b, "annex", 4) },
    }, r2, at2 + 3600);
    try testing.expect(third.c.clean);
    try must(third.text, "roll: annex -- WROTE 2 entries since the roll of ");
}

test "a fleet that keeps no record has nothing to call, and one that takes its time from nobody dates nothing (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const es = try estate(arena, true);
    const a_rec = try recordOf(arena, es.a, "depot", 3);
    const b_rec = try recordOf(arena, es.b, "annex", 2);
    const r = try callIt(arena, es.f, &.{
        .{ .member = "depot", .record = a_rec, .statements = "time authority=0000000000000000 entry=00 t=1 sig=00\n" },
        .{ .member = "annex", .record = b_rec },
        .{ .member = "box", .record = a_rec },
    }, null, at1);
    try testing.expect(r.c.clean);
    try must(r.text, "roll: this fleet takes its time from nobody, so no entry is dated");
    try must(r.text, "roll: depot -- every entry is ORDERED and UNDATED: the fleet takes its time from nobody");
    try must(r.text, "roll: box -- keeps no record: its machine declares no JOURNAL, so there is none to bring; one was brought for it and is not read");
    try testing.expect(r.c.roll.authority == null);
    // a fleet of machines that keep nothing: a roll of nothing is not one
    const none_src =
        \\DEFINE FLEET quiet AS () RATIONALE "x"
        \\DEFINE MEMBER box AS (DECLARATION "plain.machine") RATIONALE "x"
        \\
    ;
    const files = try arena.create(Files);
    files.* = .{ .files = &.{.{ "plain.machine", "DEFINE MACHINE plain AS (PROFILE hosted, ARCH x86_64, KERNEL linux) RATIONALE \"x\"\n" }} };
    var refusal = fleet.Refusal{};
    const quiet = try fleet.declare(arena, none_src, files.resolver(), &refusal);
    const q = try callIt(arena, quiet, &.{}, null, at1);
    try testing.expect(!q.c.clean);
    try must(q.text, "no member of this fleet keeps a record");
}

test "statements that do not verify, are about no entry here, or disagree with the roll before make a roll that is not clean (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const record = try recordOf(arena, fx.till, "till", 4);
    const long = try recordOf(arena, fx.till, "till", 6);
    const other = try pairOf(0xee);
    const bad = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = record, .statements = try joined(arena, &.{ try said(arena, fx.auth, record, 2, t0 + 5), try said(arena, other, record, 4, t0 + 9) }) },
        .{ .member = "till2", .record = try recordOf(arena, fx.till2, "till2", 1) },
    }, null, at1);
    try testing.expect(!bad.c.clean);
    try must(bad.text, "roll: till -- FINDING: 1 of 2 statements did not verify against clockbox's key and it is not taken: changed after it was signed, signed by another, cut short, or not a statement");
    const cut = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(long, 4), .statements = try said(arena, fx.auth, long, 6, t0 + 70) },
        .{ .member = "till2", .record = try recordOf(arena, fx.till2, "till2", 1) },
    }, null, at1);
    try testing.expect(!cut.c.clean);
    try must(cut.text, "roll: till -- FINDING: 1 statement verifies and is about entries this record does not hold: it is another record's, or entries were cut from the end of this one");

    // the authority dates what the roll before did not have BEFORE that roll: the copy it was shown was stale, or the
    // clocks disagree -- and the roll says so instead of printing a window that cannot be
    const first = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = firstOf(long, 3) },
        .{ .member = "till2", .record = try recordOf(arena, fx.till2, "till2", 1) },
    }, null, at1);
    const r1 = try kept(arena, first.c);
    const stale = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = long, .statements = try said(arena, fx.auth, long, 4, at1 - 600) },
        .{ .member = "till2", .record = try recordOf(arena, fx.till2, "till2", 1) },
    }, r1, at2);
    try testing.expect(!stale.c.clean);
    try must(stale.text, "roll: till -- WROTE 3 entries since the roll of ");
    try must(stale.text, "roll: till -- FINDING: the authority dates the first of them no later than ");
    try must(stale.text, "no later than 2026-09-21 14:05:20 UTC, which is before the roll of 2026-09-21 14:15:20 UTC, the roll that did not have it");
    try must(stale.text, ", the roll that did not have it: the copy that roll was shown was stale, or the caller's clock and the authority's disagree");
    // dated after that roll, it is a window like any other
    const fine = try callIt(arena, fx.f, &.{
        .{ .member = "till", .record = long, .statements = try said(arena, fx.auth, long, 4, at1 + 600) },
        .{ .member = "till2", .record = try recordOf(arena, fx.till2, "till2", 1) },
    }, r1, at2);
    try testing.expect(fine.c.clean);
}

test "the roll reads the same of a record and its statements as the time audit does (ROLL-1, TIME-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    const till = fx.f.member("till").?;
    const auth = Authority{ .name = "clockbox", .key = fx.auth.public_key, .fingerprint = fx.f.member("clockbox").?.fingerprint.? };
    const long = try recordOf(arena, fx.till, "till", 7);
    const other = try pairOf(0xee);
    // statements of every kind: dated, out of order, redundant, the authority's about an entry this record lacks,
    // another authority's, and a line that is not a statement
    const cases = [_][]const []const u8{
        &.{},
        &.{try said(arena, fx.auth, long, 4, t0 + 400)},
        &.{ try said(arena, fx.auth, long, 6, t0 + 600), try said(arena, fx.auth, long, 2, t0 + 200), try said(arena, fx.auth, long, 4, t0 + 450) },
        &.{ try said(arena, fx.auth, long, 7, t0 + 700), try said(arena, other, long, 5, t0 + 500), "not a statement\n" },
        &.{ try said(arena, fx.auth, long, 3, t0 + 300), try said(arena, fx.auth, long, 3, t0 + 250), try said(arena, fx.auth, long, 5, t0 + 260) },
        &.{ try said(arena, fx.auth, long, 2, t0 + 500), try said(arena, fx.auth, long, 4, t0 + 100) },
    };
    for (cases) |parts| {
        const statements = try std.mem.concat(arena, u8, parts);
        for ([_]usize{ 7, 5 }) |n| {
            const record = firstOf(long, n);
            var aw = std.Io.Writer.Allocating.init(arena);
            const audit = try timeaudit.read(arena, &aw.writer, fx.auth.public_key, statements, record);
            const mine = try read(arena, fx.f, till, .{ .member = "till", .record = record, .statements = statements }, auth);
            // the same count of statements, the same count not taken (the audit refuses both kinds together)
            try testing.expectEqual(audit.statements, mine.statements);
            try testing.expectEqual(audit.refused, mine.refused + mine.foreign);
            // and the same count of statements that cannot both be right of a clock that runs forward
            try testing.expectEqual(audit.backwards, mine.backwards);
            // the same bound for every entry, as the audit prints them, and no line for an entry nobody dated
            var printed: [8]?[]const u8 = [_]?[]const u8{null} ** 8;
            var lines = std.mem.splitScalar(u8, aw.written(), '\n');
            while (lines.next()) |l| {
                const mark = "time: entry ";
                const rest = if (std.mem.startsWith(u8, l, mark)) l[mark.len..] else continue;
                const sp = std.mem.indexOfScalar(u8, rest, ' ') orelse continue;
                const after = rest[sp..];
                const said_at = " existed no later than ";
                if (!std.mem.startsWith(u8, after, said_at)) continue;
                const seq = try std.fmt.parseInt(usize, rest[0..sp], 10);
                printed[seq] = after[said_at.len .. std.mem.indexOf(u8, after, " (statement ").?];
            }
            for (mine.bounds, 1..) |b, seq| {
                if (b) |t| {
                    var tb: [48]u8 = undefined;
                    try testing.expectEqualStrings(printed[seq].?, try timeattest.minuteUp(&tb, t));
                } else {
                    try testing.expect(printed[seq] == null);
                }
            }
        }
    }
}

test "the verb reads a directory of brought records and writes the roll the next call is compared with (ROLL-1)" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fx = try timeFleet(arena, true);
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    for (fx.sources) |s| try tmp.dir.writeFile(.{ .sub_path = s[0], .data = s[1] });
    try tmp.dir.writeFile(.{ .sub_path = "nuage.fleet", .data = fx.src });
    try tmp.dir.makePath("one");
    try tmp.dir.makePath("two");
    const base = try tmp.dir.realpathAlloc(arena, ".");
    const fleet_path = try std.fmt.allocPrint(arena, "{s}/nuage.fleet", .{base});
    const one = try std.fmt.allocPrint(arena, "{s}/one", .{base});
    const two = try std.fmt.allocPrint(arena, "{s}/two", .{base});
    const roll_path = try std.fmt.allocPrint(arena, "{s}/first.roll", .{base});

    const till_long = try recordOf(arena, fx.till, "till", 5);
    try tmp.dir.writeFile(.{ .sub_path = "one/till.record", .data = firstOf(till_long, 3) });
    try tmp.dir.writeFile(.{ .sub_path = "one/till.record.time", .data = try said(arena, fx.auth, till_long, 3, t0 + 60) });
    try tmp.dir.writeFile(.{ .sub_path = "one/till2.record", .data = try recordOf(arena, fx.till2, "till2", 2) });
    try tmp.dir.writeFile(.{ .sub_path = "two/till.record", .data = till_long });
    try tmp.dir.writeFile(.{ .sub_path = "two/till2.record", .data = try recordOf(arena, fx.till2, "till2", 2) });

    // the roll is called at the moment the first records were brought
    const t_first = timeattest.civilFromUnix(t0 + 120);
    var at_buf: [20]u8 = undefined;
    const at_text = try std.fmt.bufPrint(&at_buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}Z", .{ @as(u64, @intCast(t_first.year)), t_first.month, t_first.day, t_first.hour, t_first.minute });
    var aw = std.Io.Writer.Allocating.init(arena);
    try testing.expectEqual(@as(u8, 0), try run(arena, &.{ fleet_path, one, "--at", at_text, "--out", roll_path }, &aw.writer));
    try must(aw.written(), "roll: till -- 3 entries, from its first, in order");
    try must(aw.written(), "roll: written to ");
    const kept_text = try tmp.dir.readFileAlloc(arena, "first.roll", 1 << 16);
    try testing.expect(std.mem.startsWith(u8, kept_text, "roll v1 fleet=nuage at="));
    // written whole: no half of a roll is left beside it
    try testing.expectError(error.FileNotFound, tmp.dir.access("first.roll.new", .{}));

    // the next call, two hours later, against the file the first one wrote, and written over it
    var bw = std.Io.Writer.Allocating.init(arena);
    try testing.expectEqual(@as(u8, 0), try run(arena, &.{ fleet_path, two, "--since", roll_path, "--at", "2026-09-21T16:00Z", "--out", roll_path }, &bw.writer));
    try must(bw.written(), "roll: till -- WROTE 2 entries since the roll of 2026-09-21 14:15 UTC (entries 4-5)");
    try must(bw.written(), "roll: till2 -- NOTHING NEW since the roll of 2026-09-21 14:15 UTC");
    try must(bw.written(), "1 h 45 min before this one by the caller's clock");
    const rewritten = try tmp.dir.readFileAlloc(arena, "first.roll", 1 << 16);
    try testing.expect(!std.mem.eql(u8, kept_text, rewritten));
    // and that file is the anchor of the one after it
    var cw = std.Io.Writer.Allocating.init(arena);
    try testing.expectEqual(@as(u8, 0), try run(arena, &.{ fleet_path, two, "--since", roll_path, "--at", "2026-09-21T17:00Z" }, &cw.writer));
    try must(cw.written(), "roll: till -- NOTHING NEW since the roll of 2026-09-21 16:00 UTC");

    // an empty directory brings nothing: both are absent, and the roll is not clean
    try tmp.dir.makePath("empty");
    const empty = try std.fmt.allocPrint(arena, "{s}/empty", .{base});
    var dw = std.Io.Writer.Allocating.init(arena);
    try testing.expectEqual(@as(u8, 1), try run(arena, &.{ fleet_path, empty, "--since", roll_path, "--at", "2026-09-21T19:00Z" }, &dw.writer));
    try must(dw.written(), "roll: till -- ABSENT");
    try must(dw.written(), "roll: till2 -- ABSENT");

    // a roll as of a time earlier than the roll it is compared with does not read back: it is printed, nothing is
    // written, and the roll before is left as it is
    const before_bytes = try tmp.dir.readFileAlloc(arena, "first.roll", 1 << 16);
    var xw = std.Io.Writer.Allocating.init(arena);
    try testing.expectEqual(@as(u8, 1), try run(arena, &.{ fleet_path, empty, "--since", roll_path, "--at", "2026-09-21T10:00Z", "--out", roll_path }, &xw.writer));
    try must(xw.written(), "which the caller's clock reads as LATER than this one");
    try must(xw.written(), "harb: roll: nothing was written: this roll is as of a time earlier than the roll it was compared with");
    try testing.expectEqualStrings(before_bytes, try tmp.dir.readFileAlloc(arena, "first.roll", 1 << 16));
    try testing.expectError(error.FileNotFound, tmp.dir.access("first.roll.new", .{}));

    // a directory that is not there is an error, not a roll of members nobody brought
    var mw = std.Io.Writer.Allocating.init(arena);
    try testing.expectEqual(@as(u8, 1), try run(arena, &.{ fleet_path, try std.fmt.allocPrint(arena, "{s}/nowhere", .{base}), "--since", roll_path, "--out", roll_path }, &mw.writer));
    try must(mw.written(), "the directory the records were brought to");
    try testing.expectEqualStrings(before_bytes, try tmp.dir.readFileAlloc(arena, "first.roll", 1 << 16));

    // a record that cannot be read is said and stops the verb, and is not taken for one that was not brought; a file
    // brought for a machine that keeps no record is not read at all, so it cannot stop anything
    try tmp.dir.makePath("odd/till.record");
    try tmp.dir.makePath("odd/clockbox.record");
    const odd = try std.fmt.allocPrint(arena, "{s}/odd", .{base});
    var ow = std.Io.Writer.Allocating.init(arena);
    try testing.expectEqual(@as(u8, 1), try run(arena, &.{ fleet_path, odd }, &ow.writer));
    try must(ow.written(), "harb: cannot read ");
    try must(ow.written(), "till.record: ");
    try mustNot(ow.written(), "roll: fleet nuage"); // the verb stopped: it did not go on to call a roll over what it could read
    try tmp.dir.deleteTree("odd/till.record");
    try tmp.dir.writeFile(.{ .sub_path = "odd/till.record", .data = firstOf(till_long, 3) });
    var pw = std.Io.Writer.Allocating.init(arena);
    _ = try run(arena, &.{ fleet_path, odd }, &pw.writer);
    try must(pw.written(), "roll: clockbox -- keeps no record: its machine declares no JOURNAL, so there is none to bring; one was brought for it and is not read");
    // a first roll that is not kept says so, where it would otherwise let a person think the next one had something to
    // be compared with
    try must(pw.written(), "roll: not written (no --out): nothing was kept, so the next roll will be a first roll too");

    // what is refused, in words, and with a failing exit
    for ([_][]const []const u8{
        &.{},
        &.{fleet_path},
        &.{ fleet_path, one, "--at", "yesterday" },
        &.{ fleet_path, one, "--since" },
        &.{ fleet_path, one, "--ago", "5" },
        &.{ fleet_path, one, "extra" },
        &.{ fleet_path, one, "--since", try std.fmt.allocPrint(arena, "{s}/none.roll", .{base}) },
        &.{ "no/such.fleet", one },
    }) |args| {
        var w = std.Io.Writer.Allocating.init(arena);
        try testing.expectEqual(@as(u8, 1), try run(arena, args, &w.writer));
        try testing.expect(w.written().len > 0);
    }
    // a roll of another fleet, and a file that is no roll
    try tmp.dir.writeFile(.{ .sub_path = "other.roll", .data = "roll v1 fleet=elsewhere at=5 authority=-\nend\n" });
    try tmp.dir.writeFile(.{ .sub_path = "junk.roll", .data = "not a roll\n" });
    var ew = std.Io.Writer.Allocating.init(arena);
    try testing.expectEqual(@as(u8, 1), try run(arena, &.{ fleet_path, one, "--since", try std.fmt.allocPrint(arena, "{s}/other.roll", .{base}) }, &ew.writer));
    try must(ew.written(), "is a roll of fleet elsewhere, and this is fleet nuage");
    var gw = std.Io.Writer.Allocating.init(arena);
    try testing.expectEqual(@as(u8, 1), try run(arena, &.{ fleet_path, one, "--since", try std.fmt.allocPrint(arena, "{s}/junk.roll", .{base}) }, &gw.writer));
    try must(gw.written(), "is not a roll");
}
