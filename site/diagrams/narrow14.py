"""Diagram 14, narrow.

The wide one (diagram14.py) sets a hall as one strip, the fleet file under it,
and three rooms side by side on the links the file names, with a dashed mirror
between two of them. A column has no beside, so the order becomes sequence: the
hall, the file, room A, room B, room C struck, the wire and the mirror as a
note, then what the file will say next. Every fact is the wide drawing's, in
the same words.

One item type is local to this script: `strip_items`, a strip whose items each
start on their own line (as in narrow13.py). It touches nothing in narrowlib.

    python site/diagrams/narrow14.py
"""
from narrowlib import Col, NW, M, INNER, wrap, INK, MUTED
from house import band, fit, mono, text, READ, KERN_FILL, KERN_LINE, NEW_LINE, ORANGE


class Narrow(Col):
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


c = Narrow(14)
c.title("HAROBANDA — A CLOUD THAT FITS IN A ROOM")
c.gap(8)

c.box("a hall", "data, compute and reach in one place: one strike, and all three are lost", "old")
c.gap(20)

c.kicker("MANY ROOMS", NEW_LINE)
c.box("The fleet file", "which boxes, on which links, who is the way between, who dates the records, which key is out", "plain", accent=True)
c.arrow()
c.box("room A", "one file, its own key; it judges its boot and keeps its record", "machine")
c.gap(8)
c.box("room B", "the same, and the way between the two links", "machine")
c.gap(8)
c.box("room C, struck", "lost: what the file says was here, and nothing more", "kern")
c.gap(8)
c.note("The links the file names join the rooms. A mirror from A to B is ordered, not built.", MUTED)
c.gap(16)

c.strip_items("NEXT, ORDERED", ["territory: which country each box is in",
                                "a mirror: A's files kept on B, and verified",
                                "the roll call: who has written a record since"])
c.render("harobanda-diagram-14-narrow.png")
