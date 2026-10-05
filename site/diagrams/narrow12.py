"""Diagram 12, narrow.

The wide one (diagram12.py) sets the three machines in a row with the fleet
file above them and the two links between. A column has no beside, so the
order becomes sequence: the file, then the till, the front link, the box, the
core link, the server, then what the machines said, then what is not there
yet. Every fact is the wide drawing's, in the same words, and every quotation
is checked against the pinned boot.

Three item types are local to this script, as in narrow11.py: `said` (a label
over the machine's words, which may break a long address after a colon, a slash
or a dot rather than run off the edge), `link` (a line with a head at both ends,
because the route is a way both ways and a down arrow would give it a
direction) and `strip_items` (a strip whose items each start on their own
line). None touches narrowlib, so no other narrow drawing can change.

    python site/diagrams/narrow12.py
"""
import pathlib
import sys

from narrowlib import Col, NW, M, INNER, wrap, INK, MUTED, NEW_LINE, NEW_SUB
from house import (S, band, rule, fit, sans, mono, text, ls_w, READ,
                   KERN_FILL, KERN_LINE, HAIR)

PINNED = pathlib.Path(__file__).resolve().parent.parent.parent / "machines" / "cloud_links.expected"

SAID = [("the box says", "commons.core.cloud is 10.20.0.2"),
        ("the till gets", "commons.core.cloud:8210/health -- 200"),
        ("the server runs", "as appserver (2000:2000)")]

pinned = PINNED.read_text(encoding="utf-8")
for _, words in SAID:
    if words not in pinned:
        sys.exit("REFUSED: %r is not in %s" % (words, PINNED.name))


def wrap_quote(font, s, width):
    """Lines that fit `width`: at spaces first, and a word wider than the line is broken
    after its last colon, slash or dot that fits, so a verbatim address stays whole in
    the reading and never runs off the canvas."""
    out, cur = [], ""
    for word in s.split(" "):
        t = (cur + " " + word).strip()
        if ls_w(font, t, 0.0) / S <= width or not cur:
            cur = t
        else:
            out.append(cur)
            cur = word
        while ls_w(font, cur, 0.0) / S > width:
            cut = max((i for i, ch in enumerate(cur) if ch in ":/." and
                       ls_w(font, cur[:i + 1], 0.0) / S <= width), default=-1)
            if cut < 0:
                sys.exit("REFUSED: %r cannot be broken to fit %dpx" % (cur, width))
            out.append(cur[:cut + 1])
            cur = cur[cut + 1:]
    if cur:
        out.append(cur)
    return out


class Narrow(Col):
    def said(self, rows):
        """Each label over the machine's words; a quotation wraps, never shrinks."""
        fl, fa = sans(READ, "Medium"), mono(READ)
        blocks = []
        for label, words in rows:
            fit(fl, label, INNER - 52, "label")
            blocks.append((label, wrap_quote(fa, "“" + words + "”", INNER - 52)))
        heights = [16 + 40 + len(q) * 40 + 12 for _, q in blocks]
        h = sum(heights) + 20

        def fn(d, y):
            band(d, M, y, INNER, h - 10, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
            yy = y + 10
            for i, ((label, quote), bh) in enumerate(zip(blocks, heights)):
                if i:
                    rule(d, M + 22, yy, NW - M - 22, yy, HAIR, 1.6)
                text(d, M + 26, yy + 16 + 20, label, fl, INK)
                for j, ln in enumerate(quote):
                    text(d, M + 26, yy + 16 + 40 + 20 + j * 40, ln, fa, NEW_SUB)
                yy += bh
        self._push(h + 2, fn)

    def link(self, label):
        """A link between two machines: a line with a head at both ends, its name beside it."""
        f = mono(READ)
        fit(f, label, INNER - 90, "link label")

        def fn(d, y):
            x = M + 30
            rule(d, x, y + 4, x, y + 64, HAIR, 2.4)
            w = int(2.4 * S)
            for yy, s in ((y + 4, 1), (y + 64, -1)):
                d.line([((x - 9) * S, (yy + s * 10) * S), (x * S, yy * S)], fill=HAIR, width=w)
                d.line([(x * S, yy * S), ((x + 9) * S, (yy + s * 10) * S)], fill=HAIR, width=w)
            text(d, x + 36, y + 34, label, f, MUTED)
        self._push(70, fn)

    def strip_items(self, label, items):
        """A strip whose items are lines of their own, not one run-on note."""
        f1, f2 = mono(READ, "Medium"), mono(READ)
        fit(f1, label, INNER - 52, "strip")
        lines = []
        for it in items:
            lines += wrap(f2, it, INNER - 52)
        h = 24 + 42 + len(lines) * 40 + 20

        def fn(d, y):
            band(d, M, y, INNER, h - 10, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
            text(d, M + 26, y + 42, label, f1, INK)
            for i, ln in enumerate(lines):
                text(d, M + 26, y + 84 + i * 40, ln, f2, MUTED)
        self._push(h + 12, fn)


c = Narrow(12)
c.title("HAROBANDA — THE SMALLEST CLOUD")
c.gap(8)

c.box("The fleet file", "names the machines, the two links, and the way between", "plain")
c.gap(8)
c.box("till", "asks by name", "plain")
c.link("the front link")
c.box("box", "the way between", "machine", accent=True)
c.link("the core link")
c.box("server", "RingServ 0.9", "plain")
c.gap(20)

c.kicker("WHAT THE MACHINES SAID", NEW_LINE)
c.said(SAID)
c.gap(22)

c.strip_items("NOT THERE YET", ["No front: plain HTTP, inside the cloud only.",
                                "No packet filter: a route is a way both ways.",
                                "No board: every boot shown is emulated."])
c.render("harobanda-diagram-12-narrow.png")
