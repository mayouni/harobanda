"""Diagram 13, narrow.

The wide one (diagram13.py) sets the two cores side by side under the
declaration, with one period of the reserved core drawn as a bar inside it. A
column has no beside, so the order becomes sequence: the declaration, core 0,
core 1 with its period beneath it, then what the machine said, then what is
not there yet. Every fact is the wide drawing's, in the same words, and every
quotation is checked against the pinned boots.

Three item types are local to this script, as in narrow12.py: `period` (one
period of the reserved core as a bar, with its numbers inside the two slices
wide enough to carry one and the kernel's in the legend), `said` (a label over
the machine's words, wrapped and never shrunk) and `strip_items` (a strip whose
items each start on their own line). None touches narrowlib.

    python site/diagrams/narrow13.py
"""
import pathlib
import sys

from narrowlib import Col, NW, M, INNER, wrap, INK, MUTED, NEW_LINE, NEW_SUB
from house import (S, band, rule, fit, sans, mono, text, ls_w, chevron, READ,
                   KERN_FILL, KERN_LINE, HAIR, BG)

MACHINES = pathlib.Path(__file__).resolve().parent.parent.parent / "machines"
PINS = [MACHINES / "qemu_deadline.expected", MACHINES / "qemu_tick.expected"]

PERIOD = [("200", 200, NEW_LINE, BG), ("700", 700, KERN_LINE, INK), ("", 100, HAIR, INK)]
LEGEND = ["control 200 · second 700", "the kernel: 100 of 1000"]
SAID = [("the kernel", "PREEMPT_RT and its timers resolve 1 ns"),
        ("control", "on core 1 and no other"),
        ("the witness", "N us at the median, N us at the 99th")]

pinned = "\n".join(p.read_text(encoding="utf-8") for p in PINS)
for _, words in SAID:
    if words not in pinned:
        sys.exit("REFUSED: %r is not in any of %s" % (words, [p.name for p in PINS]))


class Narrow(Col):
    def period(self, slices, legend):
        """One period of the reserved core: a bar read left to right, the numbers inside the
        slices wide enough to carry one, the rest in the legend beneath."""
        f = mono(READ)
        for ln in legend:
            fit(f, ln, INNER - 52, "legend")
        h = 20 + 28 + 22 + len(legend) * 36 + 10

        def fn(d, y):
            bx0, bx1 = M + 26, NW - M - 26 - 22
            by0, by1 = y + 20, y + 48
            cx = bx0
            total = sum(us for _, us, _, _ in slices)
            for label, us, fill, ink in slices:
                sw = (bx1 - bx0) * us / total
                d.rectangle([cx*S, by0*S, (cx + sw)*S, by1*S], fill=fill)
                if label:
                    text(d, cx + sw/2, (by0 + by1)/2, fit(f, label, sw - 6, "slice"), f, ink, anchor="mm")
                cx += sw
            d.rectangle([bx0*S, by0*S, bx1*S, by1*S], outline=NEW_LINE, width=int(1.6*S))
            chevron(d, bx1 + 14, (by0 + by1)/2, 8, NEW_LINE, 2.0)
            for i, ln in enumerate(legend):
                text(d, M + 26, by1 + 22 + 14 + i*36, ln, f, NEW_SUB)
        self._push(h + 8, fn)

    def said(self, rows):
        """Each label over the machine's words; a quotation wraps, never shrinks."""
        fl, fa = sans(READ, "Medium"), mono(READ)
        blocks = []
        for label, words in rows:
            fit(fl, label, INNER - 52, "label")
            blocks.append((label, wrap(fa, "“" + words + "”", INNER - 52)))
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


c = Narrow(13)
c.title("HAROBANDA — A PROGRAM GIVEN ITS TIME")
c.gap(8)

c.box("The declaration", "CORES 2 · PERIOD 1000, DEADLINE 500, RUNTIME 200, CORE 1", "plain")
c.arrow()
c.box("core 0: the machine's", "PID 1, and every program with no reservation: it gets what is left", "plain")
c.gap(8)
c.box("core 1: set apart", "reserved programs only, one period of it below", "machine", accent=True)
c.period(PERIOD, LEGEND)
c.gap(20)

c.kicker("WHAT THE MACHINE SAID", NEW_LINE)
c.said(SAID)
c.gap(22)

c.strip_items("NOT THERE YET", ["No board: every number is an emulator's.",
                                "No body: nothing has moved a motor."])
c.render("harobanda-diagram-13-narrow.png")
