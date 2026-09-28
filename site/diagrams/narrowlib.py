"""Narrow variants: the same argument as a column, for a phone.

A diagram drawn to be read at 952px cannot be read at 335 -- its 32px type
lands at 7.8px. And a picture must never ask the reader to drag it sideways.
So the phone gets a DIFFERENT drawing of the same argument: one column, top
to bottom, 640px wide, which puts the same 32px type at about 16px on a
375px screen and 14px on a 320px one.

What does not survive the width is the spatial cleverness -- a fan, a fork,
two columns set against each other. On a phone a diagram becomes a labelled
SEQUENCE instead. What does survive is every fact: if something earned its
place in the wide drawing, it earns its place here, or it should not have
been in the wide one either.

A label that is not wrapped is FITTED: `house.fit` refuses one wider than
the item that holds it, as it does for the wide drawings. Until 2026-09-28
it was not asked here, and diagram 3's phone variant was published with
"the internet" cut to "internet" at the canvas edge.
"""
from PIL import Image
from house import (S, OUT, canvas, band, dashed, rr_path, chip, arrow_down, fit,
                   sans, mono, text, ls_text, centre_ls, ls_w,
                   READ, TITLE, KICKER,
                   INK, MUTED, OLD_FILL, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE, BRICK,
                   KERN_FILL, KERN_LINE, BG, HAIR)

NW = 640
M = 36
INNER = NW - 2 * M

#               fill       line      ink       sub      lw
STYLES = {
    "machine": (NEW_FILL,  NEW_LINE, NEW_TEXT, NEW_SUB, 2.6),
    "plain":   (BG,        NEW_LINE, NEW_TEXT, NEW_SUB, 2.2),
    "old":     (OLD_FILL,  OLD_LINE, OLD_TEXT, MUTED,   1.8),
    "kern":    (KERN_FILL, KERN_LINE, INK,     MUTED,   2.0),
    "hot":     (BG,        ORANGE,   INK,      MUTED,   3.0),
}


def wrap(font, s, width, ls=0.0):
    """Break a label into lines that fit. A label is never set smaller to fit."""
    out, cur = [], ""
    for word in s.split(" "):
        t = (cur + " " + word).strip()
        if ls_w(font, t, ls) / S <= width or not cur:
            cur = t
        else:
            out.append(cur)
            cur = word
    if cur:
        out.append(cur)
    return out


class Col:
    """Stacks items, measuring as it goes, then draws them onto one canvas."""

    def __init__(self, seed):
        self.seed = seed
        self.ops = []
        self.y = M

    def _push(self, h, fn):
        self.ops.append((self.y, fn))
        self.y += h

    def gap(self, h):
        self.y += h

    def title(self, s):
        f = mono(KICKER, "Medium")
        lines = wrap(f, s, INNER, 3.0)

        def fn(d, y):
            for i, ln in enumerate(lines):
                centre_ls(d, NW / 2, y + 34 + i * 42, ln, f, INK, 3.0)
        self._push(len(lines) * 42 + 18, fn)

    def kicker(self, s, colour=MUTED):
        f = mono(KICKER, "Medium")
        fit(f, s, INNER, "kicker", 2.4)

        def fn(d, y):
            ls_text(d, M * S, (y + 30) * S, s, f, colour, 2.4)
        self._push(48, fn)

    def note(self, s, colour=MUTED, medium=False):
        f = mono(READ, "Medium" if medium else "Regular")
        lines = wrap(f, s, INNER)

        def fn(d, y):
            for i, ln in enumerate(lines):
                text(d, M, y + 22 + i * 40, ln, f, colour)
        self._push(len(lines) * 40 + 10, fn)

    def bar(self, label, style="plain", empty=False, accent=False):
        fill, line, ink, _, lw = STYLES[style]
        f = mono(READ)
        fit(f, label, INNER - (40 if accent else 22) - 22, "bar")

        def fn(d, y):
            pts = rr_path(M * S, y * S, (NW - M) * S, (y + 62) * S, 10 * S)
            if empty:
                dashed(d, pts, line, int(1.8 * S))
            else:
                d.polygon(pts, fill=fill)
                d.line(pts + [pts[0]], fill=line, width=int(lw * S), joint="curve")
            if accent:
                d.polygon(rr_path((M + 14) * S, (y + 14) * S,
                                  (M + 22) * S, (y + 48) * S, 4 * S), fill=ORANGE)
            text(d, M + (40 if accent else 22), y + 31, label, f, ink)
        self._push(70, fn)

    def box(self, title, sub=None, style="machine", accent=False):
        fill, line, ink, subink, lw = STYLES[style]
        ft, fs = sans(TITLE, "SemiBold"), mono(READ)
        fit(ft, title, INNER - (44 if accent else 26) - 26, "box title")
        subs = wrap(fs, sub, INNER - 52) if sub else []
        h = 34 + 44 + len(subs) * 40 + 24

        def fn(d, y):
            band(d, M, y, INNER, h - 12, 13, fill, line, lw=lw, amp=1.0)
            if accent:
                d.polygon(rr_path((M + 16) * S, (y + 20) * S,
                                  (M + 25) * S, (y + h - 32) * S, 4 * S), fill=ORANGE)
            tx = M + (44 if accent else 26)
            text(d, tx, y + 46, title, ft, ink)
            for i, ln in enumerate(subs):
                text(d, tx, y + 92 + i * 40, ln, fs, subink)
        self._push(h + 14, fn)

    def absence(self, label, sub=None):
        f = mono(READ)
        for s in filter(None, (label, sub)):
            fit(f, s, INNER - 52, "absence", 1.4)
        h = 78 + (40 if sub else 0)

        def fn(d, y):
            dashed(d, rr_path(M * S, y * S, (NW - M) * S, (y + h) * S, 13 * S),
                   OLD_LINE, int(2.0 * S))
            centre_ls(d, NW / 2, y + 50, label, f, MUTED, 1.4)
            if sub:
                centre_ls(d, NW / 2, y + 90, sub, f, MUTED, 1.4)
        self._push(h + 12, fn)

    def chipline(self, label, fill=NEW_LINE):
        f = mono(READ, "Medium")
        fit(f, label, INNER - 52, "chip", 1.6)
        w = ls_w(f, label, 1.6) / S + 52

        def fn(d, y):
            chip(d, M, y, w, 54, label, f, fill)
        self._push(66, fn)

    def arrow(self, colour=HAIR, lw=2.4):
        def fn(d, y):
            arrow_down(d, M + 30, y + 4, y + 46, colour, lw)
        self._push(58, fn)

    def strip(self, label, note):
        f1, f2 = mono(READ, "Medium"), mono(READ)
        fit(f1, label, INNER - 52, "strip")
        lines = wrap(f2, note, INNER - 52)
        h = 24 + 42 + len(lines) * 40 + 20

        def fn(d, y):
            band(d, M, y, INNER, h - 10, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
            text(d, M + 26, y + 42, label, f1, INK)
            for i, ln in enumerate(lines):
                text(d, M + 26, y + 84 + i * 40, ln, f2, MUTED)
        self._push(h + 12, fn)

    def code(self, lines, style="machine", accent=None):
        """A declaration. Code is the one thing the type rule lets sit below READ."""
        fill, line, ink, _, lw = STYLES[style]
        f = mono(28)
        for ln in lines:
            fit(f, ln, INNER - 60, "code")
        h = 26 + len(lines) * 40 + 24

        def fn(d, y):
            band(d, M, y, INNER, h - 12, 13, fill, line, lw=lw, amp=1.0)
            if accent:
                a, b = accent
                d.polygon(rr_path((M + 14) * S, (y + 24 + a * 40) * S,
                                  (M + 22) * S, (y + 24 + (b + 1) * 40) * S, 4 * S),
                          fill=ORANGE)
            for i, ln in enumerate(lines):
                text(d, M + 34, y + 44 + i * 40, ln, f, ink)
        self._push(h + 14, fn)

    def render(self, name):
        img, d = canvas(self.seed, h=self.y + M, w=NW)
        for y, fn in self.ops:
            fn(d, y)
        small = img.resize((img.width // S, img.height // S), Image.LANCZOS)
        # PNG, not JPEG. These are flat colour and mostly text, so a 64-colour
        # palette is both smaller (145KB against 241) and cleaner: JPEG rings
        # around glyph edges, and this is the variant whose whole job is to be
        # readable at 16px on a phone, often on a connection that is paying for
        # every kilobyte.
        p = OUT / name
        small.convert("P", palette=Image.ADAPTIVE, colors=64).save(p, optimize=True)
        print("wrote", p, small.width, "x", small.height,
              "(%.0f KB)" % (p.stat().st_size / 1024))
        return p
