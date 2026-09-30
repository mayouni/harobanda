"""Diagram 11 -- the kernel answers from the file.  (security.html)

The page's thesis, "assume the agent is fooled, then decide in the kernel what
it can reach", drawn as the mechanism: a file declares what each program may
use, the kernel applies that to every request, and when a request asks for
more than the file granted the kernel answers in its own words.

Those words are quoted, not paraphrased: every one is a substring of the
pinned boot machines/qemu_confine.expected (the four answers), and the check
at the foot of this file refuses to draw one that is not. Brick is the house's
colour for a refusal and is used only there; the orange accent is used once,
on the kernel.

What is NOT there yet is on the picture, in the same words as the page's own
list (DOC-2): a picture that showed only what works would claim more than the
machine keeps.

The phone gets a different drawing of the same argument: narrow11.py.

    python site/diagrams/diagram11.py
"""
import pathlib
import sys

from house import (W, S, canvas, save, band, rule, rr_path, fit,
                   sans, mono, text, ls_text,
                   READ, TITLE, KICKER,
                   INK, MUTED, NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE, BRICK,
                   KERN_FILL, KERN_LINE, BG, HAIR)

PINNED = pathlib.Path(__file__).resolve().parent.parent.parent / "machines" / "qemu_confine.expected"

KICKER_TOP = "HAROBANDA — THE KERNEL ANSWERS FROM THE FILE"
FILE = ("The file", "declares what each program may use")
KERNEL = ("The kernel", "applies it to every request. It does not read prompts.")
HEADING = "IF NOT GRANTED, THE KERNEL SAYS"
# (label, the kernel's words), in reading order: row by row
ANSWERS = [("network", "no such interface from here"),
           ("disks", "nothing mounted on it"),
           ("programs", "cannot start another process"),
           ("25 calls", "cannot change the machine")]
NOT_YET = ("NOT THERE YET", ["No packet filter behind the routes.",
                             "No signed record of each agent action.",
                             "No board yet: the boot is emulated."])

# every quotation is the kernel's, verbatim, or nothing is drawn
pinned = PINNED.read_text(encoding="utf-8")
for _, words in ANSWERS:
    if words not in pinned:
        sys.exit("REFUSED: %r is not in %s" % (words, PINNED.name))

img, d = canvas(11)

ML = MR = 68
f_read, f_readm = mono(READ), mono(READ, "Medium")
f_title, f_lab = sans(TITLE, "SemiBold"), sans(READ, "Medium")
f_kick = mono(KICKER, "Medium")
INNER = W - ML - MR

ls_text(d, ML*S, 56*S, fit(f_kick, KICKER_TOP, INNER, "kicker", 2.4), f_kick, INK, 2.4)

# ---- the file, and the kernel that applies it -----------------------------------
BY, BH = 84, 170.0
FX, FW = ML, 500.0
KX, KW = 688, W - MR - 688.0            # the kernel is the wider, emphasised box


def box(x, y, w, h, title, sub, fill, line, ink, subink, lw, accent=False):
    band(d, x, y, w, h, 13, fill, line, lw=lw, amp=1.0)
    pad = 44 if accent else 26
    if accent:
        d.polygon(rr_path((x + 16)*S, (y + 22)*S, (x + 25)*S, (y + h - 22)*S, 4*S), fill=ORANGE)
    inner = w - pad - 26
    text(d, x + pad, y + 24 + TITLE/2, fit(f_title, title, inner, "box title"), f_title, ink)
    words, lines, cur = sub.split(" "), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if f_read.getlength(t)/S <= inner or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    lines.append(cur)
    if len(lines) != 2:
        sys.exit("REFUSED: %r wraps to %d lines in its box, the drawing budgets 2" % (sub, len(lines)))
    for i, ln in enumerate(lines):
        text(d, x + pad, y + 24 + TITLE + 12 + 20 + i*40, fit(f_read, ln, inner, "box sub"), f_read, subink)


box(FX, BY, FW, BH, FILE[0], FILE[1], BG, NEW_LINE, NEW_TEXT, NEW_SUB, 2.2)
box(KX, BY, KW, BH, KERNEL[0], KERNEL[1], NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, 2.6, accent=True)

# the order: file, then kernel (a small arrowhead, never a heavy one)
ay = BY + BH/2
x0, x1 = FX + FW + 14, KX - 14
rule(d, x0, ay, x1, ay, HAIR, 2.4)
w = int(2.4*S)
d.line([((x1 - 11)*S, (ay - 10)*S), (x1*S, ay*S)], fill=HAIR, width=w)
d.line([(x1*S, ay*S), ((x1 - 11)*S, (ay + 10)*S)], fill=HAIR, width=w)

# ---- what the kernel says when the file did not grant it --------------------------
kcx = KX + KW/2
rule(d, kcx, BY + BH + 4, kcx, 326, HAIR, 2.4)
d.line([((kcx - 10)*S, 316*S), (kcx*S, 326*S)], fill=HAIR, width=w)
d.line([(kcx*S, 326*S), ((kcx + 10)*S, 316*S)], fill=HAIR, width=w)
ls_text(d, ML*S, 318*S, fit(f_kick, HEADING, INNER, "heading", 2.4), f_kick, NEW_LINE, 2.4)

CY, CH = 336, 208.0
band(d, ML, CY, INNER, CH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
C1 = 660.0                                # first column; the second takes the rest
rule(d, ML + C1, CY + 16, ML + C1, CY + CH - 16, HAIR, 1.6)
rule(d, ML + 22, CY + CH/2, W - MR - 22, CY + CH/2, HAIR, 1.6)
RH = (CH - 16)/2
for i, (label, words) in enumerate(ANSWERS):
    col, row = i % 2, i // 2
    cx = ML + (C1 if col else 0)
    cw = (INNER - C1) if col else C1
    top = CY + 8 + row*RH
    quote = "“" + words + "”"
    text(d, cx + 26, top + 26, fit(f_lab, label, cw - 46, "label"), f_lab, INK)
    text(d, cx + 26, top + 66, fit(f_read, quote, cw - 46, "answer"), f_read, BRICK)

# ---- what is not there yet ------------------------------------------------------
SY, SH = 568, 160.0
band(d, ML, SY, INNER, SH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
lab, items = NOT_YET
text(d, ML + 26, SY + 42, fit(f_readm, lab, 270, "strip label"), f_readm, INK)
for i, ln in enumerate(items):
    text(d, ML + 26 + 296, SY + 42 + i*40, fit(f_read, ln, INNER - 26 - 296 - 26, "strip line"),
         f_read, MUTED)

print("wrote", save(img, "harobanda-diagram-11.png"))
