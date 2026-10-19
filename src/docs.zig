//! The documents' own claims, judged (DOC-1).
//!
//! Four rules, all about what a reader SEES on a page.
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
//! 4. A page's Next link goes where its section strip says (NAV-1). Every
//!    page of the site but the home page and the Blog's carries a strip,
//!    `<nav class="path">`: the pages of its section in the order the
//!    reader is meant to take them. Some end with `Next: <a href="X">Label
//!    →</a>`, and that link must be the page after its own in the strip, in
//!    the strip's own words for it. The strip must be the same on every
//!    page of its section, or there is no one order to follow. The last
//!    page of a strip has no page after it, so a Next link from there
//!    leaves the section, and says so by name in `onward`: loosened for
//!    every last page, any of them could go anywhere. The pages named in
//!    `no_strip` have no order to follow -- the Blog's posts are a list and
//!    not a sequence, the author's ruling of 2026-10-19 -- but a Next link
//!    on one of them still goes to a page that exists. When this was
//!    written the Cloud page's Next skipped the page inserted after it
//!    (Real time), and the Security chain stopped one page short of its
//!    fifth. The author found the first by eye; the court, the tour and the
//!    rules above were green over both.
//!
//! What this does NOT judge, stated rather than implied: an excerpt elided
//! with `...` (what is elided cannot be judged, which is why the pages say
//! "in full"); code INDENTED four spaces rather than fenced; the width of
//! the site's own pages, which wrap code in their own CSS; and the room a
//! LIST leaves its code -- a block in a list is measured as written, its
//! indent counted as characters, and GitHub's padding for a list was
//! never measured, because no page here has one. Nor does rule 4 judge a
//! page with NO Next link: the Why, AI, The machine and Build sections and
//! the For IT page carry none, and in a section that does use them a
//! missing one goes unnoticed (the Security chain's gap was found by
//! comparing neighbours, not by this). Nor the sentence after a Next link,
//! which describes the page it goes to and only a reader can judge.
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
    /// the site's pages the navigation check was handed, and how many sit in
    /// a section strip, in how many distinct strips, with how many Next
    /// links (each judged) of which how many go onward, by name; the rest
    /// are named as having no strip, and how many Next links they carry,
    /// each judged to go to a page that exists (NAV-1)
    nav_total: usize = 0,
    nav_pages: usize = 0,
    nav_sections: usize = 0,
    nav_next: usize = 0,
    nav_onward: usize = 0,
    nav_bare: usize = 0,
    nav_bare_next: usize = 0,
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

// ---- the site's navigation: a Next link goes where its strip says (NAV-1) ----

/// One page of the site, as the navigation check reads it.
const Page = struct { path: []const u8, text: []const u8 };

/// One entry of a section strip: where it goes, what it says (entities
/// decoded, so `&amp;` and `&` are one word), and whether the page marks it
/// as itself.
const Entry = struct { href: []const u8, label: []const u8, current: bool };

/// A page's section strip, `<nav class="path">`: the pages of its section in
/// the order the reader is meant to take them, and the line it begins on.
const Strip = struct { entries: []const Entry, line: usize };

/// A page's bottom link, `Next: <a href="X">Label →</a>`.
const Next = struct { href: []const u8, label: []const u8, line: usize };

/// What a page says about where to go next: the first Next link, how many
/// there are, and whether it has a Next line this check cannot read -- a
/// form it does not know is a link it cannot judge, and a judge that skips
/// what it cannot read is green for the wrong reason.
const NextRead = struct { first: ?Next = null, count: usize = 0, unread: bool = false };

/// A link that leaves its section on purpose. The last page of a strip has
/// no page after it, so a Next link from there is an onward one, and each is
/// named here, by page and by target, rather than the rule being loosened
/// for every last page: loosened, any of them could go anywhere. A name that
/// the page no longer bears out is convicted as stale.
const Onward = struct { from: []const u8, to: []const u8 };

/// None today. The one there was -- the data centers post sending its reader
/// on to the page that holds its proof -- was the last page of the Blog's
/// strip, and the Blog has no strip since 2026-10-19. The list stays, empty,
/// for the day a last page leaves its section on purpose (a section's end
/// sending its reader to the start of the next, say): that is one line here,
/// and a conviction until it is written.
const onward = [_]Onward{};

/// The pages that carry no strip by design: the home page, which is no
/// section's, and the Blog's two, whose posts are a list and not a sequence
/// (the author, 2026-10-19: the Blog keeps no second menu bar). Any other
/// page without one is convicted -- otherwise a change of markup would take
/// every page out of the check and leave it green -- and so is a name that
/// no page bears, or one whose page has grown a strip.
const no_strip = [_][]const u8{ "index.html", "blog.html", "datacenters.html" };

fn isNamed(list: []const []const u8, name: []const u8) bool {
    for (list) |s| {
        if (std.mem.eql(u8, s, name)) return true;
    }
    return false;
}

/// A page of the site: an HTML file directly in `site/`. What lies below it
/// -- fonts, images, the diagrams' sources -- is not a page.
fn isSitePage(path: []const u8) bool {
    const dir = "site/";
    return std.mem.startsWith(u8, path, dir) and std.mem.indexOfScalar(u8, path[dir.len..], '/') == null;
}

/// The value of attribute `name` in an opening tag, if it has one. The name
/// must follow a space, so that `data-href` is not `href`.
fn attrOf(tag: []const u8, name: []const u8) ?[]const u8 {
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, tag, from, name)) |at| {
        from = at + name.len;
        if (at == 0 or tag[at - 1] != ' ') continue;
        if (from + 1 >= tag.len or tag[from] != '=' or tag[from + 1] != '"') continue;
        const end = std.mem.indexOfScalarPos(u8, tag, from + 2, '"') orelse return null;
        return tag[from + 2 .. end];
    }
    return null;
}

/// the words of some markup, as a reader sees them
fn decoded(alloc: std.mem.Allocator, raw: []const u8) ![]const u8 {
    return std.mem.trim(u8, try plainText(alloc, raw), " \t\r\n");
}

/// the words of a Next link, without the arrow that ends them
fn nextLabel(alloc: std.mem.Allocator, raw: []const u8) ![]const u8 {
    const plain = try decoded(alloc, raw);
    const arrow = " →";
    return if (std.mem.endsWith(u8, plain, arrow)) plain[0 .. plain.len - arrow.len] else plain;
}

/// the page's section strip, if it has one
fn parseStrip(alloc: std.mem.Allocator, text: []const u8) !?Strip {
    const nav = std.mem.indexOf(u8, text, "<nav class=\"path\"") orelse return null;
    const body = text[0 .. std.mem.indexOfPos(u8, text, nav, "</nav>") orelse text.len];
    var entries: std.ArrayList(Entry) = .{};
    var pos = nav;
    while (std.mem.indexOfPos(u8, body, pos, "<a ")) |a| {
        const tag_end = std.mem.indexOfScalarPos(u8, body, a, '>') orelse break;
        const label_end = std.mem.indexOfPos(u8, body, tag_end, "</a>") orelse break;
        const tag = body[a..tag_end];
        try entries.append(alloc, .{
            .href = attrOf(tag, "href") orelse "",
            .label = try decoded(alloc, body[tag_end + 1 .. label_end]),
            .current = std.mem.indexOf(u8, tag, "aria-current=\"page\"") != null,
        });
        pos = label_end + "</a>".len;
    }
    return .{ .entries = entries.items, .line = std.mem.count(u8, text[0..nav], "\n") + 1 };
}

/// the page's Next link, as `Next: <a href="X">Label →</a>` -- the form every
/// page writes it in
fn parseNext(alloc: std.mem.Allocator, text: []const u8) !NextRead {
    const marker = "Next: <a href=\"";
    var r = NextRead{};
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, text, pos, marker)) |at| {
        const href0 = at + marker.len;
        const href1 = std.mem.indexOfScalarPos(u8, text, href0, '"') orelse break;
        const gt = std.mem.indexOfScalarPos(u8, text, href1, '>') orelse break;
        const close = std.mem.indexOfPos(u8, text, gt, "</a>") orelse break;
        if (r.first == null) r.first = .{
            .href = text[href0..href1],
            .label = try nextLabel(alloc, text[gt + 1 .. close]),
            .line = std.mem.count(u8, text[0..at], "\n") + 1,
        };
        r.count += 1;
        pos = close;
    }
    // a Next line in any other form is counted by its start, and not read
    r.unread = std.mem.count(u8, text, "Next: <a") != r.count;
    return r;
}

const Read = struct { page: Page, name: []const u8, strip: ?Strip, next: NextRead };

fn readByName(reads: []const Read, name: []const u8) ?Read {
    for (reads) |r| {
        if (std.mem.eql(u8, r.name, name)) return r;
    }
    return null;
}

fn readByPath(reads: []const Read, path: []const u8) ?Read {
    for (reads) |r| {
        if (std.mem.eql(u8, r.page.path, path)) return r;
    }
    return null;
}

fn listsPage(s: Strip, name: []const u8) bool {
    for (s.entries) |e| {
        if (std.mem.eql(u8, e.href, name)) return true;
    }
    return false;
}

/// the first entry at which two strips differ, in where it goes or in what it
/// says -- or where the shorter one ends
fn firstDifference(a: []const Entry, b: []const Entry) ?usize {
    const n = @min(a.len, b.len);
    for (0..n) |i| {
        if (!std.mem.eql(u8, a[i].href, b[i].href) or !std.mem.eql(u8, a[i].label, b[i].label)) return i;
    }
    return if (a.len != b.len) n else null;
}

fn entryText(alloc: std.mem.Allocator, es: []const Entry, i: usize) ![]const u8 {
    if (i >= es.len) return "(nothing)";
    return std.fmt.allocPrint(alloc, "{s} ({s})", .{ es[i].href, es[i].label });
}

/// one strip, as the pages it names in order: two strips are one when this is
fn signature(alloc: std.mem.Allocator, es: []const Entry) ![]const u8 {
    var s: std.ArrayList(u8) = .{};
    for (es) |e| {
        try s.appendSlice(alloc, e.href);
        try s.append(alloc, '\n');
    }
    return s.items;
}

/// A page's Next line is one link, in the form this check reads. When it is
/// not, says so and returns false: there is nothing to judge.
fn nextReadable(w: *std.Io.Writer, r: Read, t: *Tally) !bool {
    const nx = r.next;
    if (nx.count > 1) {
        t.bad += 1;
        try w.print("  {s}:{d} -- carries {d} Next links: a page says where to go next once\n", .{ r.page.path, nx.first.?.line, nx.count });
        return false;
    }
    if (nx.unread) {
        t.bad += 1;
        try w.print("  {s} -- has a Next line in a form this check cannot read (`Next: <a href=\"...\">Label →</a>`): a link it cannot read is a link it cannot judge\n", .{r.page.path});
        return false;
    }
    return true;
}

/// The site's navigation, judged: every page but the `bare` ones carries a
/// strip that marks it and no other as current; a section's strip is the same
/// on every page of it, and names pages that exist; and a page's Next link is
/// the page after its own in the strip, in the strip's words, unless it is the
/// last of its strip and the link is named in `links`. A `bare` page -- one
/// named as having no strip -- has no order to follow, and its Next link goes
/// to a page that exists (NAV-1).
fn checkNavigation(alloc: std.mem.Allocator, w: *std.Io.Writer, pages: []const Page, links: []const Onward, bare: []const []const u8, t: *Tally) !void {
    const reads = try alloc.alloc(Read, pages.len);
    for (pages, reads) |p, *r| {
        r.* = .{ .page = p, .name = std.fs.path.basename(p.path), .strip = try parseStrip(alloc, p.text), .next = try parseNext(alloc, p.text) };
    }
    t.nav_total = pages.len;
    var sections: std.ArrayList([]const u8) = .{};

    for (reads) |r| {
        const strip = r.strip orelse {
            if (isNamed(bare, r.name)) {
                // no strip, so no order to follow; a Next link still goes somewhere that exists
                t.nav_bare += 1;
                if (!try nextReadable(w, r, t)) continue;
                const link = r.next.first orelse continue;
                t.nav_bare_next += 1;
                if (readByName(reads, link.href) == null) {
                    t.bad += 1;
                    try w.print("  {s}:{d} -- Next goes to {s}, which is not a page of the site: a page with no strip has no order to follow, and its link still goes to a page that exists\n", .{ r.page.path, link.line, link.href });
                }
                continue;
            }
            t.bad += 1;
            try w.print("  {s} -- carries no section strip (<nav class=\"path\">): every page but the home page and the Blog's says where it sits in its section, and a Next link is judged against it\n", .{r.page.path});
            continue;
        };
        if (isNamed(bare, r.name)) {
            t.bad += 1;
            try w.print("  {s}:{d} -- is named in `no_strip` (src/docs.zig) as a page with no section strip, and it has one: the name is stale\n", .{ r.page.path, strip.line });
            continue;
        }

        // the page's own entry: exactly one, and it is this page
        var here: usize = 0;
        var marked: usize = 0;
        for (strip.entries, 0..) |e, i| {
            if (e.current) {
                marked += 1;
                here = i;
            }
        }
        if (marked != 1) {
            t.bad += 1;
            try w.print("  {s}:{d} -- its strip marks {d} entries as the current page: it marks this one and no other\n", .{ r.page.path, strip.line, marked });
            continue;
        }
        if (!std.mem.eql(u8, strip.entries[here].href, r.name)) {
            t.bad += 1;
            try w.print("  {s}:{d} -- its strip marks {s} as the current page, and this page is {s}\n", .{ r.page.path, strip.line, strip.entries[here].href, r.name });
            continue;
        }
        t.nav_pages += 1;
        const sig = try signature(alloc, strip.entries);
        if (!isNamed(sections.items, sig)) try sections.append(alloc, sig);

        // one section, one strip: every page it names exists, has a strip, and has THIS one
        for (strip.entries) |e| {
            if (std.mem.eql(u8, e.href, r.name)) continue;
            const other = readByName(reads, e.href) orelse {
                t.bad += 1;
                try w.print("  {s}:{d} -- its strip names {s}, which is not a page of the site\n", .{ r.page.path, strip.line, e.href });
                continue;
            };
            const theirs = other.strip orelse {
                t.bad += 1;
                try w.print("  {s}:{d} -- its strip names {s}, and that page carries no strip: the pages of a section share one\n", .{ r.page.path, strip.line, e.href });
                continue;
            };
            // each pair once: from the page whose path comes first, or from
            // this one when the other does not list it back and would never say
            if (!(std.mem.lessThan(u8, r.page.path, other.page.path) or !listsPage(theirs, r.name))) continue;
            const k = firstDifference(strip.entries, theirs.entries) orelse continue;
            t.bad += 1;
            try w.print("  {s}:{d} -- its strip and {s}'s differ at entry {d}: {s} here, {s} there; a section is one strip, the same on every page of it\n", .{
                r.page.path, strip.line, other.page.path, k + 1, try entryText(alloc, strip.entries, k), try entryText(alloc, theirs.entries, k),
            });
        }

        // the Next link: the page after this one, in the strip's words
        if (!try nextReadable(w, r, t)) continue;
        const link = r.next.first orelse continue;
        t.nav_next += 1;
        if (here + 1 < strip.entries.len) {
            const want = strip.entries[here + 1];
            if (!std.mem.eql(u8, link.href, want.href)) {
                t.bad += 1;
                try w.print("  {s}:{d} -- Next goes to {s}, and the page after this one in its strip is {s} ({s}): a Next link follows the strip\n", .{ r.page.path, link.line, link.href, want.href, want.label });
            } else if (!std.mem.eql(u8, link.label, want.label)) {
                t.bad += 1;
                try w.print("  {s}:{d} -- Next says '{s}', and its strip calls the page it goes to '{s}'\n", .{ r.page.path, link.line, link.label, want.label });
            }
            continue;
        }
        // the last page of its strip: nothing follows it, so a link from here
        // leaves the section, and is named
        var allowed = false;
        for (links) |o| {
            if (std.mem.eql(u8, o.from, r.page.path) and std.mem.eql(u8, o.to, link.href)) allowed = true;
        }
        if (!allowed) {
            t.bad += 1;
            try w.print("  {s}:{d} -- Next goes to {s}, and this is the last page of its strip, so no page follows it: a link that leaves the section on purpose is named in `onward` (src/docs.zig)\n", .{ r.page.path, link.line, link.href });
            continue;
        }
        t.nav_onward += 1;
        // and it calls the page it goes on to what that page calls itself
        const target = readByName(reads, link.href) orelse continue;
        const theirs = target.strip orelse continue;
        for (theirs.entries) |e| {
            if (e.current and !std.mem.eql(u8, e.label, link.label)) {
                t.bad += 1;
                try w.print("  {s}:{d} -- Next says '{s}', and the page it goes on to calls itself '{s}' in its strip\n", .{ r.page.path, link.line, link.label, e.label });
            }
        }
    }
    t.nav_sections = sections.items.len;

    // a name in `onward` that its page no longer bears out hides whatever the
    // page does now
    for (links) |o| {
        const why: ?[]const u8 = blk: {
            const r = readByPath(reads, o.from) orelse break :blk "no such page is on the site";
            const s = r.strip orelse break :blk "the page carries no strip";
            if (s.entries.len == 0 or !s.entries[s.entries.len - 1].current) break :blk "the page is not the last of its strip, where a Next link is judged as any other";
            const link = r.next.first orelse break :blk "the page carries no Next link";
            if (!std.mem.eql(u8, link.href, o.to)) break :blk "the page's Next goes elsewhere";
            if (readByName(reads, o.to) == null) break :blk "the page it goes on to is not a page of the site";
            break :blk null;
        };
        if (why) |m| {
            t.bad += 1;
            try w.print("  {s} -- named in `onward` (src/docs.zig) as going on to {s}, and {s}: the name is stale\n", .{ o.from, o.to, m });
        }
    }

    // a name in `no_strip` that no page bears would keep excusing a page that is gone, and
    // the next page of that name, whatever it is, would be excused unread
    for (bare) |name| {
        if (readByName(reads, name) == null) {
            t.bad += 1;
            try w.print("  {s} -- named in `no_strip` (src/docs.zig) as a page with no section strip, and no such page is on the site: the name is stale\n", .{name});
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
    var site: std.ArrayList(Page) = .{};
    for (found.html.items) |p| {
        const text = try root.readFileAlloc(alloc, p, 1 << 24);
        try checkHtml(alloc, w, p, text, &t);
        if (isSitePage(p)) try site.append(alloc, .{ .path = p, .text = text });
    }
    try checkNavigation(alloc, w, site.items, &onward, &no_strip, &t);
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
        try w.print("docs -- {d} Markdown files: no code line wider than {d}, nor than {d} inside a quote, where {d} code block(s) sit; {d} machine(s) shown in full, and the court accepts every one; the {d} words the tour defines, carried word for word to the README and the site; of the site's {d} pages, {d} sit in {d} section strips, each the same on every page of its section, and their {d} Next links each go to the next page of the strip ({d} onward, named); the {d} pages named as having no strip carry {d} Next link(s), each to a page that exists\n", .{ found.md.items.len, max_code_width, allowedWidth(1), t.quoted, t.judged, learn.words.len, t.nav_total, t.nav_pages, t.nav_sections, t.nav_next, t.nav_onward, t.nav_bare, t.nav_bare_next });
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

// ---- NAV-1: a Next link goes where its strip says ----

/// the head of a page of a section of three -- a, b and c, "One", "Two" and
/// "Three" -- that is page number `here` of it
fn trio(comptime here: u8) []const u8 {
    return "<nav class=\"path\" aria-label=\"Section\">\n<div class=\"path-in\">\n" ++
        "<a href=\"a.html\"" ++ (if (here == 0) " class=\"here\" aria-current=\"page\"" else "") ++ ">One</a>\n" ++
        "<a href=\"b.html\"" ++ (if (here == 1) " class=\"here\" aria-current=\"page\"" else "") ++ ">Two</a>\n" ++
        "<a href=\"c.html\"" ++ (if (here == 2) " class=\"here\" aria-current=\"page\"" else "") ++ ">Three</a>\n" ++
        "</div>\n</nav>\n<main>\n";
}

const nav_a = trio(0);
const nav_b = trio(1);
const nav_c = trio(2);
const nav_end = "</main>\n";

/// the same section as seen by a page that names only some of it
const nav_c_short = "<nav class=\"path\">\n<div class=\"path-in\">\n<a href=\"a.html\">One</a>\n" ++
    "<a href=\"c.html\" class=\"here\" aria-current=\"page\">Three</a>\n</div>\n</nav>\n<main>\n";
const nav_a_alone = "<nav class=\"path\">\n<div class=\"path-in\">\n" ++
    "<a href=\"a.html\" class=\"here\" aria-current=\"page\">One</a>\n</div>\n</nav>\n<main>\n";
const nav_b_pair = "<nav class=\"path\">\n<div class=\"path-in\">\n<a href=\"a.html\">One</a>\n" ++
    "<a href=\"b.html\" class=\"here\" aria-current=\"page\">Two</a>\n</div>\n</nav>\n<main>\n";
const nav_unmarked = "<nav class=\"path\">\n<div class=\"path-in\">\n<a href=\"a.html\">One</a>\n" ++
    "<a href=\"b.html\">Two</a>\n</div>\n</nav>\n<main>\n";

const to_a = "<p class=\"prose\">Next: <a href=\"a.html\">One →</a> A sentence about it.</p>\n";
const to_b = "<p class=\"prose\">Next: <a href=\"b.html\">Two →</a> A sentence about it.</p>\n";
const to_c = "<p class=\"prose\">Next: <a href=\"c.html\">Three →</a> A sentence about it.</p>\n";

const NavProbe = struct { tally: Tally, said: []const u8 };

/// Judge a set of pages' navigation. Everything lives in `arena`, so a test can read what was
/// said as well as count it.
fn navProbe(arena: std.mem.Allocator, pages: []const Page, links: []const Onward) !NavProbe {
    return navProbeBare(arena, pages, links, &.{});
}

/// the same, with some pages named as having no strip
fn navProbeBare(arena: std.mem.Allocator, pages: []const Page, links: []const Onward, bare: []const []const u8) !NavProbe {
    var aw = std.Io.Writer.Allocating.init(arena);
    var t = Tally{};
    try checkNavigation(arena, &aw.writer, pages, links, bare, &t);
    return .{ .tally = t, .said = aw.written() };
}

fn heard(p: NavProbe, fragment: []const u8) bool {
    return std.mem.indexOf(u8, p.said, fragment) != null;
}

test "a Next link that follows its strip is judged and passes, and a page with none is not judged" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const chain = [_]Page{
        .{ .path = "site/a.html", .text = nav_a ++ to_b ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ to_c ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c ++ nav_end },
    };
    const p = try navProbe(arena, &chain, &.{});
    try t.expectEqual(@as(usize, 0), p.tally.bad);
    // it judged: three pages in one strip, two links followed
    try t.expectEqual(@as(usize, 3), p.tally.nav_pages);
    try t.expectEqual(@as(usize, 1), p.tally.nav_sections);
    try t.expectEqual(@as(usize, 2), p.tally.nav_next);
    // a page with no Next is not judged, whatever its neighbours say: the seam the header names
    const gap = [_]Page{
        .{ .path = "site/a.html", .text = nav_a ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ to_c ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c ++ nav_end },
    };
    const g = try navProbe(arena, &gap, &.{});
    try t.expectEqual(@as(usize, 0), g.tally.bad);
    try t.expectEqual(@as(usize, 1), g.tally.nav_next);
}

test "a Next link that skips a page is convicted, naming the page that was meant" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const skip = [_]Page{
        // the Cloud page's defect: the page after it in the strip is b, and it goes to c
        .{ .path = "site/a.html", .text = nav_a ++ to_c ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ to_c ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c ++ nav_end },
    };
    const p = try navProbe(arena_state.allocator(), &skip, &.{});
    try t.expectEqual(@as(usize, 1), p.tally.bad);
    try t.expect(heard(p, "site/a.html:"));
    try t.expect(heard(p, "Next goes to c.html"));
    try t.expect(heard(p, "is b.html (Two)"));
}

test "a Next link that does not call its page what the strip calls it is convicted" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const words = [_]Page{
        .{ .path = "site/a.html", .text = nav_a ++ "<p>Next: <a href=\"b.html\">Deux →</a> A sentence.</p>\n" ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c ++ nav_end },
    };
    const p = try navProbe(arena_state.allocator(), &words, &.{});
    try t.expectEqual(@as(usize, 1), p.tally.bad);
    try t.expect(heard(p, "Next says 'Deux'"));
    try t.expect(heard(p, "calls the page it goes to 'Two'"));
}

test "the last page of a strip has no page after it: an onward link is named, or convicted, or stale" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const away = [_]Page{
        .{ .path = "site/a.html", .text = nav_a ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c ++ to_a ++ nav_end },
    };
    // unnamed: the rule is not loosened for the last page
    const u = try navProbe(arena, &away, &.{});
    try t.expectEqual(@as(usize, 1), u.tally.bad);
    try t.expect(heard(u, "the last page of its strip"));
    // named: it passes, and is counted
    const named = [_]Onward{.{ .from = "site/c.html", .to = "a.html" }};
    const n = try navProbe(arena, &away, &named);
    try t.expectEqual(@as(usize, 0), n.tally.bad);
    try t.expectEqual(@as(usize, 1), n.tally.nav_onward);
    // named, and it calls the page it goes on to something else than that page calls itself
    const renamed = [_]Page{
        .{ .path = "site/a.html", .text = nav_a ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c ++ "<p>Next: <a href=\"a.html\">Uno →</a> A sentence.</p>\n" ++ nav_end },
    };
    const r = try navProbe(arena, &renamed, &named);
    try t.expectEqual(@as(usize, 1), r.tally.bad);
    try t.expect(heard(r, "calls itself 'One'"));
    // stale: named, and the page carries no Next link now
    const quiet = [_]Page{
        .{ .path = "site/a.html", .text = nav_a ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c ++ nav_end },
    };
    const q = try navProbe(arena, &quiet, &named);
    try t.expectEqual(@as(usize, 1), q.tally.bad);
    try t.expect(heard(q, "the page carries no Next link"));
    // stale: named, and the page is not the last of its strip, where its Next is judged as any other
    const first = [_]Onward{.{ .from = "site/a.html", .to = "b.html" }};
    const f = try navProbe(arena, &quiet, &first);
    try t.expectEqual(@as(usize, 1), f.tally.bad);
    try t.expect(heard(f, "not the last of its strip"));
    // stale: named, and what it goes on to is not a page of the site
    const gone = [_]Page{
        .{ .path = "site/a.html", .text = nav_a ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c ++ "<p>Next: <a href=\"z.html\">Zed →</a> A sentence.</p>\n" ++ nav_end },
    };
    const away_z = [_]Onward{.{ .from = "site/c.html", .to = "z.html" }};
    const z = try navProbe(arena, &gone, &away_z);
    try t.expectEqual(@as(usize, 1), z.tally.bad);
    try t.expect(heard(z, "is not a page of the site"));
}

test "a strip that differs on one page is convicted from each page that lists it, and once for each" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const odd = [_]Page{
        .{ .path = "site/a.html", .text = nav_a ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c_short ++ nav_end },
    };
    const p = try navProbe(arena_state.allocator(), &odd, &.{});
    // a and b each list c, and each says so; c lists a, which lists it back, and says nothing
    try t.expectEqual(@as(usize, 2), p.tally.bad);
    try t.expect(heard(p, "site/a.html:"));
    try t.expect(heard(p, "site/b.html:"));
    try t.expect(heard(p, "site/c.html's differ at entry 2: b.html (Two) here, c.html (Three) there"));
}

test "a strip that lists a page which does not list it back is judged from the side that lists" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    // b names a; a names only itself. b's path is the greater, so a pair judged from the lesser side
    // alone would never be judged at all
    const one_way = [_]Page{
        .{ .path = "site/a.html", .text = nav_a_alone ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b_pair ++ nav_end },
    };
    const p = try navProbe(arena_state.allocator(), &one_way, &.{});
    try t.expectEqual(@as(usize, 1), p.tally.bad);
    try t.expect(heard(p, "site/b.html:"));
    try t.expect(heard(p, "differ at entry 2"));
}

test "a strip that names a page the site does not have is convicted" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const short = [_]Page{
        .{ .path = "site/a.html", .text = nav_a ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ nav_end },
    };
    const p = try navProbe(arena_state.allocator(), &short, &.{});
    // both list c
    try t.expectEqual(@as(usize, 2), p.tally.bad);
    try t.expect(heard(p, "names c.html, which is not a page of the site"));
}

test "a page with no strip is convicted unless it is named, as the home page and the Blog's are" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const bare = "<main>no strip here</main>\n";
    const named = [_][]const u8{"index.html"};
    const x = try navProbeBare(arena, &.{.{ .path = "site/x.html", .text = bare }}, &.{}, &named);
    // x is not the named page, and the named page is not on the site
    try t.expect(heard(x, "site/x.html -- carries no section strip"));
    try t.expect(heard(x, "no such page is on the site"));
    try t.expectEqual(@as(usize, 2), x.tally.bad);
    // the named page, present, is counted as having none and judged by nothing more
    const h = try navProbeBare(arena, &.{.{ .path = "site/index.html", .text = bare }}, &.{}, &named);
    try t.expectEqual(@as(usize, 0), h.tally.bad);
    try t.expectEqual(@as(usize, 1), h.tally.nav_bare);
    // a named page that has grown a strip is a stale name
    const s = try navProbeBare(arena, &.{.{ .path = "site/index.html", .text = nav_a ++ nav_end }}, &.{}, &named);
    try t.expect(s.tally.bad >= 1);
    try t.expect(heard(s, "the name is stale"));
}

test "a page with no strip has no order to follow, and its Next link still goes to a page that exists" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const named = [_][]const u8{ "blog.html", "post.html" };
    const post = "<main>a post</main>\n";
    // the index sends its reader to the first post: a page that is there
    const there = [_]Page{
        .{ .path = "site/blog.html", .text = "<main>the list <p>Next: <a href=\"post.html\">A post →</a> About it.</p></main>\n" },
        .{ .path = "site/post.html", .text = post },
    };
    const ok = try navProbeBare(arena, &there, &.{}, &named);
    try t.expectEqual(@as(usize, 0), ok.tally.bad);
    try t.expectEqual(@as(usize, 2), ok.tally.nav_bare);
    // judged, and counted
    try t.expectEqual(@as(usize, 1), ok.tally.nav_bare_next);
    // the same link to a page the site does not have is convicted, at its own line
    const gone = [_]Page{
        .{ .path = "site/blog.html", .text = "<main>the list\n<p>Next: <a href=\"nowhere.html\">A post →</a> About it.</p></main>\n" },
        .{ .path = "site/post.html", .text = post },
    };
    const bad = try navProbeBare(arena, &gone, &.{}, &named);
    try t.expectEqual(@as(usize, 1), bad.tally.bad);
    try t.expect(heard(bad, "site/blog.html:2 -- Next goes to nowhere.html, which is not a page of the site"));
    // and a Next line it cannot read is no more passed over here than on a page with a strip
    const two = [_]Page{
        .{ .path = "site/blog.html", .text = "<p>Next: <a href=\"post.html\">A post →</a></p><p>Next: <a href=\"post.html\">A post →</a></p>\n" },
        .{ .path = "site/post.html", .text = post },
    };
    const twice = try navProbeBare(arena, &two, &.{}, &named);
    try t.expectEqual(@as(usize, 1), twice.tally.bad);
    try t.expect(heard(twice, "carries 2 Next links"));
}

test "a name in no_strip that no page bears is stale" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const chain = [_]Page{
        .{ .path = "site/a.html", .text = nav_a ++ to_b ++ nav_end },
        .{ .path = "site/b.html", .text = nav_b ++ to_c ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c ++ nav_end },
    };
    const ghost = [_][]const u8{"ghost.html"};
    const p = try navProbeBare(arena, &chain, &.{}, &ghost);
    try t.expectEqual(@as(usize, 1), p.tally.bad);
    try t.expect(heard(p, "ghost.html -- named in `no_strip`"));
    try t.expect(heard(p, "no such page is on the site: the name is stale"));
}

test "a strip must mark this page and no other" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // the strip of b on the page a: copied from a neighbour and never re-marked
    const wrong = try navProbe(arena, &.{.{ .path = "site/a.html", .text = nav_b ++ nav_end }}, &.{});
    try t.expect(heard(wrong, "marks b.html as the current page, and this page is a.html"));
    try t.expectEqual(@as(usize, 1), wrong.tally.bad);
    const none = try navProbe(arena, &.{.{ .path = "site/a.html", .text = nav_unmarked ++ nav_end }}, &.{});
    try t.expect(heard(none, "marks 0 entries as the current page"));
    try t.expectEqual(@as(usize, 1), none.tally.bad);
}

test "a Next line this check cannot read, and two of them, are convicted" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const rest = [_]Page{
        .{ .path = "site/b.html", .text = nav_b ++ nav_end },
        .{ .path = "site/c.html", .text = nav_c ++ nav_end },
    };
    // a link with another attribute before its href is a form the check does not know
    const odd = [_]Page{.{ .path = "site/a.html", .text = nav_a ++ "<p>Next: <a class=\"x\" href=\"b.html\">Two →</a></p>\n" ++ nav_end }} ++ rest;
    const o = try navProbe(arena, &odd, &.{});
    try t.expectEqual(@as(usize, 1), o.tally.bad);
    try t.expect(heard(o, "in a form this check cannot read"));
    // a page says where to go next once
    const twice = [_]Page{.{ .path = "site/a.html", .text = nav_a ++ to_b ++ to_b ++ nav_end }} ++ rest;
    const w2 = try navProbe(arena, &twice, &.{});
    try t.expectEqual(@as(usize, 1), w2.tally.bad);
    try t.expect(heard(w2, "carries 2 Next links"));
}

test "the words of a strip and of a link are compared as a reader sees them" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const head = "<nav class=\"path\">\n<div class=\"path-in\">\n";
    const tail = "</div>\n</nav>\n<main>\n";
    const amp = [_]Page{
        .{ .path = "site/a.html", .text = head ++ "<a href=\"a.html\" class=\"here\" aria-current=\"page\">One</a>\n<a href=\"b.html\">Fish &amp; chips</a>\n" ++ tail ++
            "<p>Next: <a href=\"b.html\">Fish & chips →</a> A sentence.</p>\n" ++ nav_end },
        .{ .path = "site/b.html", .text = head ++ "<a href=\"a.html\">One</a>\n<a href=\"b.html\" class=\"here\" aria-current=\"page\">Fish &amp; chips</a>\n" ++ tail ++ nav_end },
    };
    const p = try navProbe(arena_state.allocator(), &amp, &.{});
    try t.expectEqual(@as(usize, 0), p.tally.bad);
    try t.expectEqual(@as(usize, 1), p.tally.nav_next);
}

test "an attribute is read by its own name, and a page is a file directly in site/" {
    const t = std.testing;
    try t.expectEqualStrings("y.html", attrOf("<a data-href=\"x.html\" href=\"y.html\" class=\"k\"", "href").?);
    try t.expect(attrOf("<a data-href=\"x.html\" class=\"k\"", "href") == null);
    try t.expect(isSitePage("site/a.html"));
    try t.expect(!isSitePage("site/diagrams/a.html"));
    try t.expect(!isSitePage("doc/a.html"));
    try t.expect(!isSitePage("a.html"));
}
