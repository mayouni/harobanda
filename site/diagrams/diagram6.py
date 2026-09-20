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

    python site/diagrams/diagram6.py
"""
from house import (W, H, S, canvas, save, band, dashed, rule, rr_path,
                   sans, mono, text, ls_text, centre_ls,
                   INK, MUTED, OLD_FILL, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE,
                   KERN_FILL, KERN_LINE, HAIR)

img, d = canvas(6)

ML = MR = 68
CARD_X, CARD_W = ML, 402
CARD_Y, CARD_H = 150, 320
DEV_X,  DEV_W  = 640, W - MR - 640
TRUNK          = 560
TOP, BOT       = 140, 610

centre_ls(d, W/2, 58, "ONE FILE.  ONE COMMAND.  FOUR KINDS OF DEVICE.",
          mono(19, "Medium"), INK, 3.2)

ls_text(d, CARD_X*S, 120*S, "ONE DECLARATION", mono(16, "Medium"), NEW_LINE, 2.4)
ls_text(d, DEV_X*S,  120*S, "FOUR TARGETS",    mono(16, "Medium"), MUTED,    2.4)

# ---- the file: real grammar, taken from machines/makeen_box.machine ----
band(d, CARD_X, CARD_Y, CARD_W, CARD_H, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
LINES = ["DEFINE MACHINE counter AS (",
         "  PROFILE hosted,",
         "  ARCH    aarch64,",
         "  BOARD   rpi4,",
         "  KERNEL  linux,",
         "  LIBC    musl,",
         ")"]
f_code = mono(17)
cy = CARD_Y + CARD_H/2
for i, ln in enumerate(LINES):
    text(d, CARD_X + 30, cy - 102 + i*34, ln, f_code, NEW_TEXT)

# the one orange accent, on the three lines that name the target
d.polygon(rr_path((CARD_X+14)*S, (cy-85)*S, (CARD_X+22)*S, (cy+17)*S, 4*S), fill=ORANGE)
text(d, CARD_X + 30, CARD_Y + CARD_H + 28,
     "PROFILE · ARCH · BOARD name the target", mono(16), MUTED)

# ---- the fan ----
DEV = [("a normal PC",       "x86_64  ·  hosted shape",            False),
       ("a Raspberry Pi",    "aarch64  ·  two slots, a watchdog",  False),
       ("a tablet or phone", "touch shape  ·  design",             True),
       ("a sensor or MCU",   "edge shape  ·  no kernel at all",    False)]
bh = 100.0
gap = ((BOT - TOP) - 4*bh) / 3.0
centres = [TOP + i*(bh + gap) + bh/2 for i in range(4)]

# the fan carries the whole claim, so it is drawn to be seen, not guessed at
FAN = (176, 169, 153)
rule(d, CARD_X + CARD_W, cy, TRUNK, cy, FAN, 2.0)
rule(d, TRUNK, centres[0], TRUNK, centres[-1], FAN, 2.0)
for c in centres:
    rule(d, TRUNK, c, DEV_X, c, FAN, 2.0)

f_dev, f_sub = sans(26, "SemiBold"), mono(16)
for (title, sub, design), c in zip(DEV, centres):
    y = c - bh/2
    if design:                    # not a fact today, so it is drawn as one that is not
        pts = rr_path(DEV_X*S, y*S, (DEV_X+DEV_W)*S, (y+bh)*S, 13*S)
        d.polygon(pts, fill=OLD_FILL)
        dashed(d, pts, OLD_LINE, int(2.0*S))
        tc, sc = OLD_TEXT, MUTED
    else:
        band(d, DEV_X, y, DEV_W, bh, 13, NEW_FILL, NEW_LINE, lw=2.4, amp=1.0)
        tc, sc = NEW_TEXT, NEW_SUB
    text(d, DEV_X + 34, c - 13, title, f_dev, tc)
    text(d, DEV_X + 34, c + 20, sub,   f_sub, sc)

# ---- what does not change, for every one of them ----
KY, KH = 638, 74
band(d, ML, KY, W - ML - MR, KH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
text(d, ML + 34, KY + KH/2, "harb check  ·  harb plan  ·  harb boot",
     mono(20, "Medium"), INK)
text(d, W - MR - 34, KY + KH/2, "the same command, every target",
     mono(17), MUTED, anchor="rm")

print("wrote", save(img, "harobanda-diagram-6.jpg"))
