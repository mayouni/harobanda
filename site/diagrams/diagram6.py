"""Diagram 6 -- one file, four kinds of device.  (build.html)

Brief: site/DIAGRAMS.md section 6. The sentence it must make true:
you change what names the target and re-derive; you do not learn a new
toolchain per device.

The brief asked for a callout reading "one word changes: the board", which
is build.html's own sentence. It is true within a profile -- a PC and a Pi
differ by ARCH and BOARD -- but crossing to the touch or edge shape changes
PROFILE as well, and this diagram prints all four targets at once. A
sentence worded for one case and printed for four is a lie in three of them,
so the card marks the three lines that NAME the target and the invariant
moves to the bottom band, where it holds for every one of them.

Refit to the calibrated type scale in house.py. The declaration keeps a
smaller size than the labels around it: a code block is the one thing the
site's type rule exempts, and 27 characters of real grammar will not fit a
card at reading size without becoming fake grammar.

    python site/diagrams/diagram6.py
"""
from house import (W, S, canvas, save, band, dashed, rule, rr_path, fit,
                   sans, mono, text, ls_text, centre_ls,
                   READ, TITLE, KICKER,
                   INK, MUTED, OLD_FILL, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE,
                   KERN_FILL, KERN_LINE, HAIR)

img, d = canvas(6)

ML = MR = 68
CARD_X, CARD_W, CARD_Y, CARD_H = ML, 560.0, 132, 336.0
DEV_X, DEV_W = 760, W - MR - 760
TRUNK = 700
TOP, DBH, DGAP = 132, 100.0, 16.0

f_read, f_readm = mono(READ), mono(READ, "Medium")
f_title, f_kick, f_code = sans(TITLE, "SemiBold"), mono(KICKER, "Medium"), mono(28)

centre_ls(d, W/2, 48, "ONE FILE.  ONE COMMAND.  FOUR KINDS OF DEVICE.", f_kick, INK, 3.2)
ls_text(d, CARD_X*S, 104*S, "ONE DECLARATION", f_kick, NEW_LINE, 2.4)
ls_text(d, DEV_X*S,  104*S, "FOUR TARGETS",    f_kick, MUTED,    2.4)

# ---- the file: real grammar, taken from machines/makeen_box.machine ----
band(d, CARD_X, CARD_Y, CARD_W, CARD_H, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
LINES = ["DEFINE MACHINE counter AS (",
         "  PROFILE hosted,",
         "  ARCH    aarch64,",
         "  BOARD   rpi4,",
         "  KERNEL  linux,",
         "  LIBC    musl,",
         ")"]
for i, ln in enumerate(LINES):
    text(d, CARD_X + 36, CARD_Y + 52 + i*40,
         fit(f_code, ln, CARD_W - 72, "code"), f_code, NEW_TEXT)

# the one orange accent, on the three lines that name the target
d.polygon(rr_path((CARD_X+18)*S, (CARD_Y+72)*S, (CARD_X+27)*S, (CARD_Y+192)*S, 4*S),
          fill=ORANGE)
text(d, CARD_X, CARD_Y + CARD_H + 40,
     fit(f_read, "these name the target", CARD_W, "card label"), f_read, MUTED)

# ---- the fan ----
DEV = [("a normal PC",       "x86_64 · hosted shape", False),
       ("a Raspberry Pi",    "aarch64 · two slots",   False),
       ("a tablet or phone", "touch shape · design",  True),
       ("a sensor or MCU",   "edge shape · no kernel", False)]
centres = [TOP + i*(DBH + DGAP) + DBH/2 for i in range(4)]

FAN = (176, 169, 153)                # the fan carries the claim; it is drawn to be seen
rule(d, CARD_X + CARD_W, CARD_Y + CARD_H/2, TRUNK, CARD_Y + CARD_H/2, FAN, 2.0)
rule(d, TRUNK, centres[0], TRUNK, centres[-1], FAN, 2.0)
for c in centres:
    rule(d, TRUNK, c, DEV_X, c, FAN, 2.0)

for (title, sub, design), c in zip(DEV, centres):
    y = c - DBH/2
    if design:                       # not a fact today, so it is drawn as one that is not
        pts = rr_path(DEV_X*S, y*S, (DEV_X+DEV_W)*S, (y+DBH)*S, 13*S)
        d.polygon(pts, fill=OLD_FILL)
        dashed(d, pts, OLD_LINE, int(2.0*S))
        tc, sc = OLD_TEXT, MUTED
    else:
        band(d, DEV_X, y, DEV_W, DBH, 13, NEW_FILL, NEW_LINE, lw=2.4, amp=1.0)
        tc, sc = NEW_TEXT, NEW_SUB
    text(d, DEV_X + 34, y + 38, fit(f_title, title, DEV_W - 68, "dev"), f_title, tc)
    text(d, DEV_X + 34, y + 74, fit(f_read, sub, DEV_W - 68, "dev sub"), f_read, sc)

# ---- what does not change, for every one of them ----
KY, KH = 610, 96
band(d, ML, KY, W - ML - MR, KH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
text(d, ML + 36, KY + KH/2, "harb check · harb plan", f_readm, INK)
text(d, W - MR - 36, KY + KH/2, "every target", f_read, MUTED, anchor="rm")

print("wrote", save(img, "harobanda-diagram-6.png"))
