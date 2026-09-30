//! The documents' own claims, judged (DOC-1).
//!
//! Two rules, both about what a reader SEES on a page.
//!
//! 1. No code line in a Markdown file is wider than GitHub shows before it
//!    puts a horizontal scrollbar under the block. The author's rule for
//!    every page (2026-09-27), made after a screenshot of the README's own
//!    "Try it" block scrolling sideways -- and when this was written, 152
//!    code lines in 10 of the repository's 17 Markdown files were wider.
//!
//!    A code block is what GitHub RENDERS as one (DOC-3): three or more
//!    backticks or tildes, inside any number of quotes, closed by a line
//!    of the same character at least as long -- or by the end of the
//!    quote, or of the page, that holds it. A quote takes room from its
//!    code (`quote_cost`). Until 2026-09-29 a fence was a line that BEGAN
//!    with three backticks, so a block inside a quote was never read:
//!    WHATS-NEXT.md carried a 106-character command in one, and the court
//!    was green.
//!
//! 2. Every machine a page shows IN FULL is one the court accepts. When this
//!    was written, the README's headline example ("a whole machine, in nine
//!    lines") and the site home page's were both REFUSED -- PROFILE is
//!    required -- and the site's assistant excerpt showed a daemon that
//!    signals READY but never said it restarts. The first thing a visitor
//!    reads was a claim no judge had ever read.
//!
//! 3. The project's words are worded ONCE (DOC-2). The tour's glossary
//!    (`learn.words`) is the source; the README's "The words, in plain
//!    terms" and the site's words.html carry every word of it, in its
//!    order and in its words. A page's own formatting -- backticks, bold,
//!    <code> -- is not a difference; a changed word is. The pages had eight
//!    terms, each explained by another metaphor ("the court: the judge of
//!    the grammar"), and the tour had its own wording of the same eight.
//!
//! What this does NOT judge, stated rather than implied: an excerpt elided
//! with `...` (what is elided cannot be judged, which is why the pages say
//! "in full"); code INDENTED four spaces rather than fenced; the width of
//! the site's own pages, which wrap code in their own CSS; and the room a
//! LIST leaves its code -- a block in a list is measured as written, its
//! indent counted as characters, and GitHub's padding for a list was
//! never measured, because no page here has one.
//!
//! Nor does it judge Central's own files, `.central/` and the root
//! `WHATS-NEXT.md`. The coordinating session writes them into this working
//! copy, but they are not the repository's: they carry paths on one machine
//! and the estate's internal coordination, and the repository is public, so
//! they are untracked (STZ-OS-RULING-13). This judge walks the folder and
//! not git, so it is told to leave them: a wide line in a page the
//! repository does not hold would turn its court red on one machine and
//! never in a clean clone.

const std = @import("std");
const machine = @import("machine.zig");
const learn = @import("learn.zig");

/// What GitHub shows of a code line in a README column before the block
/// scrolls: 68 characters on the author's screen, less a margin.
pub const max_code_width: usize = 64;

/// What one quote takes from the room of the code inside it, in
/// characters. GitHub draws a quote with 16 pixels of padding on each side
/// and a 4-pixel border: 36 pixels, which is 4.81 characters of the code
/// font as this machine draws it (7.48 pixels each). Measured on the
/// rendered WHATS-NEXT.md, 2026-09-29, at 820 and at 1280 pixels wide --
/// 36 at both, so a quote costs characters, not a share of the column
/// (DOC-3). Rounded up, so the margin under the 68 survives in a quote.
pub const quote_cost: usize = 5;

/// how wide a code line may be inside `depth` quotes
pub fn allowedWidth(depth: usize) usize {
    return max_code_width -| depth * quote_cost;
}

/// never descended into: build output, caches, the VCS, the harness, and
/// Central's mirror (`.central`), which is not the repository's
const skip_dirs = [_][]const u8{ "zig-out", ".zig-cache", "zig-cache", ".git", "__pycache__", ".claude", ".central", "node_modules" };

fn skipped(name: []const u8) bool {
    for (skip_dirs) |s| {
        if (std.mem.eql(u8, s, name)) return true;
    }
    return false;
}

/// Central's page for this desk, written into the ROOT of the working copy.
/// Only the root's: a WHATS-NEXT.md anywhere else is somebody's own page.
fn centralsFile(prefix: []const u8, name: []const u8) bool {
    return prefix.len == 0 and std.mem.eql(u8, name, "WHATS-NEXT.md");
}

const Found = struct {
    md: std.ArrayList([]const u8) = .{},
    html: std.ArrayList([]const u8) = .{},
};

/// every Markdown and HTML file under `dir`, by path relative to the root
fn collect(alloc: std.mem.Allocator, dir: std.fs.Dir, prefix: []const u8, out: *Found) !void {
    var it = dir.iterate();
    while (try it.next()) |e| {
        const rel = if (prefix.len == 0)
            try alloc.dupe(u8, e.name)
        else
            try std.fmt.allocPrint(alloc, "{s}/{s}", .{ prefix, e.name });
        switch (e.kind) {
            .directory => {
                if (skipped(e.name)) continue;
                var sub = dir.openDir(e.name, .{ .iterate = true }) catch continue;
                defer sub.close();
                try collect(alloc, sub, rel, out);
            },
            .file => {
                if (centralsFile(prefix, e.name)) continue;
                if (std.mem.endsWith(u8, e.name, ".md")) try out.md.append(alloc, rel);
                if (std.mem.endsWith(u8, e.name, ".html")) try out.html.append(alloc, rel);
            },
            else => {},
        }
    }
}

const Tally = struct {
    bad: usize = 0,
    /// machines shown in full, and so judged
    judged: usize = 0,
    /// code blocks inside a quote, and so measured with less room
    quoted: usize = 0,
};

/// A block that declares a MACHINE and elides nothing is a claim that this
/// is a machine; the court is asked whether it is one. `first_line` is the
/// file's line on which `body` begins, so a refusal names the line of the
/// PAGE, where the reader can go and look.
fn judgeMachine(alloc: std.mem.Allocator, w: *std.Io.Writer, path: []const u8, first_line: usize, body: []const u8, t: *Tally) !void {
    if (std.mem.indexOf(u8, body, "DEFINE MACHINE") == null) return;
    if (std.mem.indexOf(u8, body, "...") != null) return;
    if (std.mem.indexOf(u8, body, "\u{2026}") != null) return;
    t.judged += 1;
    const from = std.mem.indexOf(u8, body, "DEFINE").?;
    var refusal = machine.Refusal{};
    _ = machine.declare(alloc, body[from..], &refusal) catch |e| switch (e) {
        error.Refused => {
            t.bad += 1;
            const at = first_line + std.mem.count(u8, body[0..from], "\n") + refusal.line - 1;
            try w.print("  {s}:{d} shows a machine the court refuses: {s}\n", .{ path, at, refusal.message });
            return;
        },
        else => return e,
    };
}

/// how many times `c` begins `s`
fn runOf(s: []const u8, c: u8) usize {
    var n: usize = 0;
    while (n < s.len and s[n] == c) n += 1;
    return n;
}

/// A fence: three or more backticks or tildes (CommonMark, which GitHub
/// renders). The words after a backtick fence may hold no backtick, or the
/// line is inline code and opens nothing.
const Fence = struct { char: u8, len: usize };

fn opens(line: []const u8) ?Fence {
    const s = std.mem.trimLeft(u8, line, " \t");
    if (s.len == 0 or (s[0] != '`' and s[0] != '~')) return null;
    const n = runOf(s, s[0]);
    if (n < 3) return null;
    if (s[0] == '`' and std.mem.indexOfScalar(u8, s[n..], '`') != null) return null;
    return .{ .char = s[0], .len = n };
}

/// A block closes on a line of its OWN character, at least as long as the
/// fence that opened it, with nothing after: a shorter fence, the other
/// character, or a fence with words after it is a line of code.
fn closes(line: []const u8, f: Fence) bool {
    const s = std.mem.trimLeft(u8, line, " \t");
    const n = runOf(s, f.char);
    return n >= f.len and std.mem.trim(u8, s[n..], " \t").len == 0;
}

const Unquoted = struct { depth: usize, rest: []const u8 };

/// Up to `most` quote markers taken off the front of a line: a `>` after
/// at most three spaces, with the one space after it. `> > x` and `>> x`
/// are both two quotes deep.
fn unquote(line: []const u8, most: usize) Unquoted {
    var rest = line;
    var depth: usize = 0;
    while (depth < most) : (depth += 1) {
        const i = @min(runOf(rest, ' '), 3);
        if (i == rest.len or rest[i] != '>') break;
        const after = i + 1;
        rest = rest[if (after < rest.len and rest[after] == ' ') after + 1 else after..];
    }
    return .{ .depth = depth, .rest = rest };
}

/// One code line against the room it has, `depth` quotes deep.
fn measure(w: *std.Io.Writer, path: []const u8, n: usize, code: []const u8, depth: usize, t: *Tally) !void {
    const width = std.unicode.utf8CountCodepoints(code) catch code.len;
    const room = allowedWidth(depth);
    if (width <= room) return;
    t.bad += 1;
    switch (depth) {
        0 => try w.print("  {s}:{d} -- a code line {d} wide; GitHub shows {d} before the block scrolls\n", .{ path, n, width, room }),
        1 => try w.print("  {s}:{d} -- a code line {d} wide inside a quote; GitHub shows {d} there before the block scrolls\n", .{ path, n, width, room }),
        else => try w.print("  {s}:{d} -- a code line {d} wide inside {d} quotes; GitHub shows {d} there before the block scrolls\n", .{ path, n, width, depth, room }),
    }
}

fn checkMarkdown(alloc: std.mem.Allocator, w: *std.Io.Writer, path: []const u8, text: []const u8, t: *Tally) !void {
    // the block that is open, if one is, and how many quotes deep it opened
    var fence: ?Fence = null;
    var depth: usize = 0;
    var block: std.ArrayList(u8) = .{};
    var start: usize = 0;
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw| {
        n += 1;
        const line = std.mem.trimRight(u8, raw, "\r");
        if (fence) |f| {
            const inner = unquote(line, depth);
            if (inner.depth == depth and !closes(inner.rest, f)) {
                try block.appendSlice(alloc, inner.rest);
                try block.append(alloc, '\n');
                try measure(w, path, n, inner.rest, depth, t);
                continue;
            }
            // the block's text begins on the line after its fence
            try judgeMachine(alloc, w, path, start + 1, block.items, t);
            block.clearRetainingCapacity();
            fence = null;
            // a closing fence is spent. A line that ended the QUOTE ended
            // the block inside it too, as GitHub renders it, and is read
            // again below as the line it is.
            if (inner.depth == depth) continue;
        }
        const q = unquote(line, std.math.maxInt(usize));
        if (opens(q.rest)) |g| {
            fence = g;
            depth = q.depth;
            start = n;
            if (depth > 0) t.quoted += 1;
        }
    }
    // a block the page never closes runs to the page's end (CommonMark)
    if (fence != null) try judgeMachine(alloc, w, path, start + 1, block.items, t);
}

/// the text a reader sees inside a <pre>: tags dropped, the entities a
/// page uses in code decoded
fn plainText(alloc: std.mem.Allocator, s: []const u8) ![]const u8 {
    const entities = [_][2][]const u8{
        .{ "&lt;", "<" },    .{ "&gt;", ">" },  .{ "&amp;", "&" },
        .{ "&quot;", "\"" }, .{ "&#39;", "'" }, .{ "&nbsp;", " " },
    };
    var out: std.ArrayList(u8) = .{};
    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '<') {
            // a tag is dropped, but not the lines it spans: a refusal
            // must still name the line of the page it is on
            const end = @min(s.len, (std.mem.indexOfScalarPos(u8, s, i, '>') orelse s.len) + 1);
            for (s[i..end]) |c| if (c == '\n') try out.append(alloc, '\n');
            i = end;
            continue;
        }
        if (s[i] == '&') {
            var matched = false;
            for (entities) |e| {
                if (std.mem.startsWith(u8, s[i..], e[0])) {
                    try out.appendSlice(alloc, e[1]);
                    i += e[0].len;
                    matched = true;
                    break;
                }
            }
            if (matched) continue;
        }
        try out.append(alloc, s[i]);
        i += 1;
    }
    return out.items;
}

fn checkHtml(alloc: std.mem.Allocator, w: *std.Io.Writer, path: []const u8, text: []const u8, t: *Tally) !void {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, text, pos, "<pre")) |open| {
        const body = (std.mem.indexOfScalarPos(u8, text, open, '>') orelse break) + 1;
        const close = std.mem.indexOfPos(u8, text, body, "</pre>") orelse break;
        // the <pre>'s text begins on the line its opening tag ends on
        const line = std.mem.count(u8, text[0..body], "\n") + 1;
        try judgeMachine(alloc, w, path, line, try plainText(alloc, text[body..close]), t);
        pos = close + "</pre>".len;
    }
}

fn byPath(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

// ---- the words, carried word for word (DOC-2) ----

/// where each page keeps the words
pub const readme_words_heading = "## The words, in plain terms";

const Word = struct { term: []const u8, def: []const u8, line: usize };

/// The words as a reader sees them: code and bold marks dropped, every run
/// of whitespace one space. A backtick in the source, the same span in
/// <code> on the site: the same words.
fn plainWords(alloc: std.mem.Allocator, s: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .{};
    var space = false;
    for (s) |c| {
        if (c == '`' or c == '*') continue;
        if (c == ' ' or c == '\n' or c == '\r' or c == '\t') {
            space = out.items.len > 0;
            continue;
        }
        if (space) try out.append(alloc, ' ');
        space = false;
        try out.append(alloc, c);
    }
    return out.items;
}

/// the rows `| **term** | definition |` of the README's words table
fn readmeWords(alloc: std.mem.Allocator, text: []const u8) ![]Word {
    var out: std.ArrayList(Word) = .{};
    var inside = false;
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw| {
        n += 1;
        const line = std.mem.trimRight(u8, raw, "\r");
        if (std.mem.startsWith(u8, line, "## ")) {
            inside = std.mem.eql(u8, line, readme_words_heading);
            continue;
        }
        if (!inside or !std.mem.startsWith(u8, line, "| **")) continue;
        const cells = std.mem.trim(u8, line, " |");
        const bar = std.mem.indexOf(u8, cells, " | ") orelse continue;
        try out.append(alloc, .{
            .term = try plainWords(alloc, cells[0..bar]),
            .def = try plainWords(alloc, cells[bar + 3 ..]),
            .line = n,
        });
    }
    return out.items;
}

/// the entries `<div><b>term</b><span>definition</span></div>` of the
/// site's words page, inside its `class="words"` block
fn siteWords(alloc: std.mem.Allocator, text: []const u8) ![]Word {
    var out: std.ArrayList(Word) = .{};
    const from = std.mem.indexOf(u8, text, "class=\"words\"") orelse return out.items;
    const to = std.mem.indexOfPos(u8, text, from, "</section>") orelse text.len;
    var pos = from;
    while (std.mem.indexOfPos(u8, text[0..to], pos, "<b>")) |b| {
        const b_end = std.mem.indexOfPos(u8, text, b, "</b>") orelse break;
        const s = std.mem.indexOfPos(u8, text, b_end, "<span>") orelse break;
        const s_end = std.mem.indexOfPos(u8, text, s, "</span>") orelse break;
        try out.append(alloc, .{
            .term = try plainWords(alloc, try plainText(alloc, text[b + 3 .. b_end])),
            .def = try plainWords(alloc, try plainText(alloc, text[s + 6 .. s_end])),
            .line = std.mem.count(u8, text[0..b], "\n") + 1,
        });
        pos = s_end;
    }
    return out.items;
}

/// Every word the source defines, in its order and in its words; nothing
/// the source does not define.
fn compareWords(alloc: std.mem.Allocator, w: *std.Io.Writer, path: []const u8, found: []const Word, source: []const [2][]const u8, t: *Tally) !void {
    const n = @max(found.len, source.len);
    for (0..n) |i| {
        if (i >= found.len) {
            t.bad += 1;
            try w.print("  {s} -- '{s}' is missing: the tour defines it (src/learn.zig), and every page that lists the words carries all of them\n", .{ path, source[i][0] });
            continue;
        }
        const f = found[i];
        if (i >= source.len) {
            t.bad += 1;
            try w.print("  {s}:{d} -- '{s}' is not a word the tour defines (src/learn.zig)\n", .{ path, f.line, f.term });
            continue;
        }
        if (!std.mem.eql(u8, f.term, try plainWords(alloc, source[i][0]))) {
            t.bad += 1;
            try w.print("  {s}:{d} -- '{s}' is here, where the tour's order has '{s}'\n", .{ path, f.line, f.term, source[i][0] });
            continue;
        }
        if (!std.mem.eql(u8, f.def, try plainWords(alloc, source[i][1]))) {
            t.bad += 1;
            try w.print("  {s}:{d} -- '{s}' is not defined in the tour's words (src/learn.zig): a word is worded once\n", .{ path, f.line, f.term });
        }
    }
}

/// Run from the repository root, as `zig build court` runs it.
pub fn check(w: *std.Io.Writer) !usize {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const alloc = arena_state.allocator();

    var root = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer root.close();
    var found = Found{};
    try collect(alloc, root, "", &found);
    std.mem.sort([]const u8, found.md.items, {}, byPath);
    std.mem.sort([]const u8, found.html.items, {}, byPath);

    var t = Tally{};
    for (found.md.items) |p| {
        try checkMarkdown(alloc, w, p, try root.readFileAlloc(alloc, p, 1 << 24), &t);
    }
    for (found.html.items) |p| {
        try checkHtml(alloc, w, p, try root.readFileAlloc(alloc, p, 1 << 24), &t);
    }
    const pages = [_]struct { path: []const u8, html: bool }{
        .{ .path = "README.md", .html = false },
        .{ .path = "site/words.html", .html = true },
    };
    for (pages) |pg| {
        const text = root.readFileAlloc(alloc, pg.path, 1 << 24) catch {
            t.bad += 1;
            try w.print("  {s} -- cannot be read, and it is where the words are carried\n", .{pg.path});
            continue;
        };
        const got = if (pg.html) try siteWords(alloc, text) else try readmeWords(alloc, text);
        try compareWords(alloc, w, pg.path, got, &learn.words, &t);
    }
    if (t.bad == 0) {
        try w.print("docs -- {d} Markdown files: no code line wider than {d}, nor than {d} inside a quote, where {d} code block(s) sit; {d} machine(s) shown in full, and the court accepts every one; the {d} words the tour defines, carried word for word to the README and the site\n", .{ found.md.items.len, max_code_width, allowedWidth(1), t.quoted, t.judged, learn.words.len });
    } else {
        try w.print("docs -- {d} claim(s) the documents make do not hold\n", .{t.bad});
    }
    return t.bad;
}

// ---- judged beside the code: each rule convicts, and each has its edge ----

const Probe = struct { tally: Tally, said: []const u8 };

/// Judge one page's text. Everything lives in `arena`, so a test can read
/// what was said as well as count it.
fn probe(arena: std.mem.Allocator, text: []const u8, html: bool) !Probe {
    var aw = std.Io.Writer.Allocating.init(arena);
    var t = Tally{};
    if (html) try checkHtml(arena, &aw.writer, "t.html", text, &t) else try checkMarkdown(arena, &aw.writer, "t.md", text, &t);
    return .{ .tally = t, .said = aw.written() };
}

fn run(text: []const u8, html: bool) !Tally {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    return (try probe(arena_state.allocator(), text, html)).tally;
}

const good_machine =
    \\DEFINE MACHINE hello AS (
    \\  PROFILE hosted,
    \\  ARCH x86_64,
    \\  KERNEL linux
    \\) RATIONALE "the smallest machine that boots"
    \\
;

test "a code line wider than GitHub shows is convicted, and one exactly as wide is not" {
    const t = std.testing;
    const at = "x" ** max_code_width;
    const over = "x" ** (max_code_width + 1);
    try t.expectEqual(@as(usize, 0), (try run("```\n" ++ at ++ "\n```\n", false)).bad);
    try t.expectEqual(@as(usize, 1), (try run("```\n" ++ over ++ "\n```\n", false)).bad);
    // prose is not code: a long sentence outside a fence is not measured
    try t.expectEqual(@as(usize, 0), (try run(over ++ "\n", false)).bad);
    // width is counted in characters, not bytes: 64 arrows fit
    try t.expectEqual(@as(usize, 0), (try run("```\n" ++ ("\u{2192}" ** max_code_width) ++ "\n```\n", false)).bad);
}

test "a machine shown in full is judged, and a refused one is convicted" {
    const t = std.testing;
    const ok = try run("```\n" ++ good_machine ++ "```\n", false);
    try t.expectEqual(@as(usize, 0), ok.bad);
    try t.expectEqual(@as(usize, 1), ok.judged);
    // the README's headline example as it stood: no PROFILE
    const refused = "DEFINE MACHINE hello AS (\n  ARCH x86_64,\n  KERNEL linux\n) RATIONALE \"x\"\n";
    try t.expectEqual(@as(usize, 1), (try run("```\n" ++ refused ++ "```\n", false)).bad);
    // an excerpt is not judged, and says so by eliding visibly
    const excerpt = try run("```\nDEFINE MACHINE hub AS ( ... )\n```\n", false);
    try t.expectEqual(@as(usize, 0), excerpt.bad);
    try t.expectEqual(@as(usize, 0), excerpt.judged);
}

test "a refusal names the line of the PAGE, not the line of the block" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // prose on lines 1-2, the fence on 3, a blank line opening the block,
    // and the machine with no PROFILE declared on line 5 of the page
    const page = "# a page\n\n```\n\nDEFINE MACHINE hello AS (\n  ARCH x86_64,\n  KERNEL linux\n) RATIONALE \"x\"\n```\n";
    const p = try probe(arena, page, false);
    try t.expectEqual(@as(usize, 1), p.tally.bad);
    try t.expect(std.mem.indexOf(u8, p.said, "t.md:5 shows a machine the court refuses: PROFILE is required") != null);
    // a refusal deep in the block: a clause no MACHINE has, on line 6
    const deep = "text\n```\nDEFINE MACHINE hello AS (\n  PROFILE hosted,\n  ARCH x86_64,\n  COLOR blue,\n  KERNEL linux\n) RATIONALE \"x\"\n```\n";
    const d = try probe(arena, deep, false);
    try t.expectEqual(@as(usize, 1), d.tally.bad);
    try t.expect(std.mem.indexOf(u8, d.said, "t.md:6 shows a machine the court refuses:") != null);
    // and in a site page, a tag that spans two lines still counts both
    const html = "<p>x</p>\n<pre><span\n  class=\"kw\">DEFINE MACHINE</span> hello AS (\n  ARCH x86_64,\n  KERNEL linux\n) RATIONALE &quot;x&quot;\n</pre>";
    const h = try probe(arena, html, true);
    try t.expectEqual(@as(usize, 1), h.tally.bad);
    try t.expect(std.mem.indexOf(u8, h.said, "t.html:3 shows a machine the court refuses: PROFILE is required") != null);
}

test "the words are carried word for word, and a changed word is convicted" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const source = [_][2][]const u8{
        .{ "a pin", "A saved copy of a transcript, kept as `machines/<name>.expected`." },
        .{ "PID 1", "The first program the kernel starts." },
    };
    const readme = readme_words_heading ++ "\n\n| word | in practice |\n|---|---|\n" ++
        "| **a pin** | A saved copy of a  transcript, kept as `machines/<name>.expected`. |\n" ++
        "| **PID 1** | The first program the kernel starts. |\n\n## Next\n";
    const html = "<div class=\"words\">\n  <div><b>a pin</b><span>A saved copy of a transcript, kept as <code>machines/&lt;name&gt;.expected</code>.</span></div>\n" ++
        "  <div><b>PID 1</b><span>The first program the kernel starts.</span></div>\n</div>\n</section>";

    // carried: formatting and spacing are not differences
    var aw = std.Io.Writer.Allocating.init(arena);
    var ok = Tally{};
    try compareWords(arena, &aw.writer, "README.md", try readmeWords(arena, readme), &source, &ok);
    try compareWords(arena, &aw.writer, "site/words.html", try siteWords(arena, html), &source, &ok);
    try t.expectEqual(@as(usize, 0), ok.bad);

    // one word changed: convicted, by name and by line
    const changed = try std.mem.replaceOwned(u8, arena, readme, "kernel starts", "kernel runs");
    var aw2 = std.Io.Writer.Allocating.init(arena);
    var bad = Tally{};
    try compareWords(arena, &aw2.writer, "README.md", try readmeWords(arena, changed), &source, &bad);
    try t.expectEqual(@as(usize, 1), bad.bad);
    try t.expect(std.mem.indexOf(u8, aw2.written(), "README.md:6 -- 'PID 1' is not defined in the tour's words") != null);

    // a word left out of the site: convicted as missing
    const short = "<div class=\"words\">\n  <div><b>a pin</b><span>A saved copy of a transcript, kept as <code>machines/&lt;name&gt;.expected</code>.</span></div>\n</div>\n</section>";
    var aw3 = std.Io.Writer.Allocating.init(arena);
    var missing = Tally{};
    try compareWords(arena, &aw3.writer, "site/words.html", try siteWords(arena, short), &source, &missing);
    try t.expectEqual(@as(usize, 1), missing.bad);
    try t.expect(std.mem.indexOf(u8, aw3.written(), "'PID 1' is missing") != null);

    // the right words in the wrong order: convicted where the order breaks
    const swapped = readme_words_heading ++ "\n\n| **PID 1** | The first program the kernel starts. |\n" ++
        "| **a pin** | A saved copy of a transcript, kept as `machines/<name>.expected`. |\n";
    var aw4 = std.Io.Writer.Allocating.init(arena);
    var order = Tally{};
    try compareWords(arena, &aw4.writer, "README.md", try readmeWords(arena, swapped), &source, &order);
    try t.expectEqual(@as(usize, 2), order.bad);
    try t.expect(std.mem.indexOf(u8, aw4.written(), "'PID 1' is here, where the tour's order has 'a pin'") != null);
}

test "a site page's machine is judged through its markup" {
    const t = std.testing;
    const page = "<pre><span class=\"kw\">DEFINE MACHINE</span> hello <span class=\"kw\">AS</span> (\n" ++
        "  PROFILE hosted,\n  ARCH x86_64,\n  KERNEL linux\n) <span class=\"kw\">RATIONALE</span> &quot;x&quot;\n</pre>";
    const ok = try run(page, true);
    try t.expectEqual(@as(usize, 0), ok.bad);
    try t.expectEqual(@as(usize, 1), ok.judged);
    // the same page without PROFILE, which is how the home page stood
    const without = "<pre><span class=\"kw\">DEFINE MACHINE</span> hello AS (\n  ARCH x86_64,\n  KERNEL linux\n) RATIONALE &quot;x&quot;\n</pre>";
    try t.expectEqual(@as(usize, 1), (try run(without, true)).bad);
}

// ---- DOC-3: a code block is what GitHub renders as one ----

/// WHATS-NEXT.md's refresh command as it stood until 6ade3a0, inside a
/// quote: 106 characters, green, because the fence was never read
const old_command = "powershell -ExecutionPolicy Bypass -File D:\\GitHub\\softanza\\dashboard\\central.ps1 -Install -Only harobanda";

test "a code block inside a quote is measured, in the room the quote leaves" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // the line that walked past, convicted at the line of the page
    const p = try probe(arena, "> ## Answer\n>\n> ```\n> " ++ old_command ++ "\n> ```\n", false);
    try t.expectEqual(@as(usize, 1), p.tally.bad);
    try t.expectEqual(@as(usize, 1), p.tally.quoted);
    const said = std.fmt.comptimePrint("t.md:4 -- a code line {d} wide inside a quote; GitHub shows {d} there before the block scrolls", .{ old_command.len, comptime allowedWidth(1) });
    try t.expect(std.mem.indexOf(u8, p.said, said) != null);

    // exactly the room a quote leaves: acquitted; one more: convicted
    const room = comptime allowedWidth(1);
    try t.expectEqual(@as(usize, 0), (try run("> ```\n> " ++ ("x" ** room) ++ "\n> ```\n", false)).bad);
    try t.expectEqual(@as(usize, 1), (try run("> ```\n> " ++ ("x" ** (room + 1)) ++ "\n> ```\n", false)).bad);
    // a quote COSTS room: a line that fits the page does not fit a quote
    try t.expectEqual(@as(usize, 1), (try run("> ```\n> " ++ ("x" ** max_code_width) ++ "\n> ```\n", false)).bad);

    // two quotes deep, spelled either way, cost it twice
    const room2 = comptime allowedWidth(2);
    try t.expectEqual(@as(usize, 0), (try run(">> ```\n>> " ++ ("x" ** room2) ++ "\n>> ```\n", false)).bad);
    try t.expectEqual(@as(usize, 1), (try run("> > ```\n> > " ++ ("x" ** (room2 + 1)) ++ "\n> > ```\n", false)).bad);

    // prose in a quote is not code, however long
    try t.expectEqual(@as(usize, 0), (try run("> " ++ ("x" ** 200) ++ "\n", false)).bad);
    // and in a block that is NOT quoted, a `>` is code, and counts
    try t.expectEqual(@as(usize, 1), (try run("```\n> " ++ ("x" ** (max_code_width - 1)) ++ "\n```\n", false)).bad);
}

test "a block inside a quote ends where the quote ends" {
    const t = std.testing;
    const over = "x" ** (max_code_width + 1);
    // GitHub closes a code block when the quote around it closes: the line
    // after is prose, and a long one is not measured
    try t.expectEqual(@as(usize, 0), (try run("> ```\n> x\n\n" ++ over ++ "\n", false)).bad);
    // and a fence right after the quote opens a block of its own
    try t.expectEqual(@as(usize, 1), (try run("> ```\n> x\n```\n" ++ over ++ "\n```\n", false)).bad);
}

test "a machine inside a quote is judged, and refused at its page line" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const ok = try probe(arena, "> ```\n> DEFINE MACHINE hello AS (\n>   PROFILE hosted,\n>   ARCH x86_64,\n>   KERNEL linux\n> ) RATIONALE \"x\"\n> ```\n", false);
    try t.expectEqual(@as(usize, 0), ok.tally.bad);
    try t.expectEqual(@as(usize, 1), ok.tally.judged);
    // no PROFILE, on the machine that begins on line 2 of the page
    const p = try probe(arena, "> ```\n> DEFINE MACHINE hello AS (\n>   ARCH x86_64,\n>   KERNEL linux\n> ) RATIONALE \"x\"\n> ```\n", false);
    try t.expectEqual(@as(usize, 1), p.tally.bad);
    try t.expect(std.mem.indexOf(u8, p.said, "t.md:2 shows a machine the court refuses: PROFILE is required") != null);
}

test "a fence is closed by its own kind, and a page that ends closes it" {
    const t = std.testing;
    const over = "x" ** (max_code_width + 1);
    // tildes open a block as backticks do
    try t.expectEqual(@as(usize, 1), (try run("~~~\n" ++ over ++ "\n~~~\n", false)).bad);
    // backticks inside a tilde block are code, not its end
    try t.expectEqual(@as(usize, 0), (try run("~~~\n```\n~~~\n" ++ over ++ "\n", false)).bad);
    // a shorter fence inside a longer one is code, not its end
    try t.expectEqual(@as(usize, 1), (try run("````\n```\n" ++ over ++ "\n````\n", false)).bad);
    // a fence with words after it never closes a block
    try t.expectEqual(@as(usize, 1), (try run("```\n```bash\n" ++ over ++ "\n```\n", false)).bad);
    // three backticks around words on one line are inline code, not a fence
    try t.expectEqual(@as(usize, 0), (try run("```x```\n" ++ over ++ "\n", false)).bad);
    // a block the page never closes runs to the end, and its machine is judged
    const refused = "DEFINE MACHINE hello AS (\n  ARCH x86_64,\n  KERNEL linux\n) RATIONALE \"x\"\n";
    try t.expectEqual(@as(usize, 1), (try run("```\n" ++ refused, false)).bad);
}

// ---- STZ-OS-RULING-13: Central's files are not the repository's ----

fn listed(paths: []const []const u8, want: []const u8) bool {
    for (paths) |p| {
        if (std.mem.eql(u8, p, want)) return true;
    }
    return false;
}

test "Central's files are not judged, and a page of the same name elsewhere is" {
    const t = std.testing;
    var tmp = t.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.makeDir(".central");
    try tmp.dir.makeDir("doc");
    const page = "# a page\n";
    const made = [_][]const u8{
        ".central/inbox.md", ".central/status.html", "WHATS-NEXT.md",
        "doc/WHATS-NEXT.md", "doc/a.md",             "README.md",
    };
    for (made) |p| try tmp.dir.writeFile(.{ .sub_path = p, .data = page });

    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    var found = Found{};
    try collect(arena_state.allocator(), tmp.dir, "", &found);

    // the walk did walk: an assertion of absence over an empty walk proves nothing
    try t.expect(listed(found.md.items, "README.md"));
    try t.expect(listed(found.md.items, "doc/a.md"));
    // only the ROOT's WHATS-NEXT.md is Central's; a page of that name in a folder is not
    try t.expect(listed(found.md.items, "doc/WHATS-NEXT.md"));
    try t.expect(!listed(found.md.items, "WHATS-NEXT.md"));
    // and nothing under .central, of either kind
    try t.expect(!listed(found.md.items, ".central/inbox.md"));
    try t.expectEqual(@as(usize, 0), found.html.items.len);
    try t.expectEqual(@as(usize, 3), found.md.items.len);
}
