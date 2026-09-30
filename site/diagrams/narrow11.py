"""Diagram 11, narrow.

The wide one (diagram11.py) sets the file and the kernel side by side and the
kernel's four answers in a two-by-two table beneath. A column has no beside,
so the order becomes sequence: the file, the kernel, then each answer under
its label, then what is not there yet. Every fact is the wide drawing's, in
the same words, and every quotation is checked against the pinned boot.

Two item types are local to this script: `answers` (a label over the kernel's
words, one to two lines each) and `strip_items` (a strip whose items each
start on their own line). Neither touches narrowlib, so no other narrow
drawing can change.

    python site/diagrams/narrow11.py
"""
import pathlib
import sys

from narrowlib import Col, NW, M, INNER, wrap, INK, MUTED, BRICK, NEW_LINE
from house import (S, band, rule, fit, sans, mono, text, READ,
                   KERN_FILL, KERN_LINE, HAIR)

PINNED = pathlib.Path(__file__).resolve().parent.parent.parent / "machines" / "qemu_confine.expected"

ANSWERS = [("network", "no such interface from here"),
           ("disks", "nothing mounted on it"),
           ("programs", "cannot start another process"),
           ("25 calls", "cannot change the machine")]

pinned = PINNED.read_text(encoding="utf-8")
for _, words in ANSWERS:
    if words not in pinned:
        sys.exit("REFUSED: %r is not in %s" % (words, PINNED.name))


class Narrow(Col):
    def answers(self, rows):
        """Each label over the kernel's words; a quotation wraps, never shrinks."""
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
                    text(d, M + 26, yy + 16 + 40 + 20 + j * 40, ln, fa, BRICK)
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


c = Narrow(11)
c.title("HAROBANDA — THE KERNEL ANSWERS FROM THE FILE")
c.gap(8)

c.box("The file", "declares what each program may use", "plain")
c.arrow()
c.box("The kernel", "applies it to every request. It does not read prompts.", "machine", accent=True)
c.gap(20)

c.kicker("IF NOT GRANTED, THE KERNEL SAYS", NEW_LINE)
c.answers(ANSWERS)
c.gap(22)

c.strip_items("NOT THERE YET", ["No packet filter behind the routes.",
                                "No signed record of each agent action.",
                                "No board yet: the boot is emulated."])
c.render("harobanda-diagram-11-narrow.png")
