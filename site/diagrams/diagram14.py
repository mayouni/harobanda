"""Diagram 14 -- a cloud that fits in a room: one hall, or many rooms the file names.
   (datacenters.html, resilience.html)

Brief: site/DIAGRAMS.md section 13. The sentence it must make true: a resilient
cloud is many small declared machines in many rooms, each judging its own boot
and keeping its own record, joined by links the fleet file names, so that
losing a room is losing what the file says was in it -- and what the file will
say next (the roll call, the loss drill) is ordered and not built; where the data
stays (TERR-1) and the copy of a room's files (MIR-1) are written already and are on the file's own list.

It is containment and topology, which is what a diagram is for here: a hall as
ONE strip, where data, compute and reach sit in one place and one strike takes
all three; beneath it the fleet file, and under the file three rooms as three
machines on the links the file names, one of them the way between, one of them
struck. The orange accent is used once, on the fleet file, because that is
what makes many rooms one cloud. Brick is used once, on the strike. The copy
from room A to room B is a solid arrow since 2026-10-19 (MIR-1): it was dashed,
this family's mark for absence, while it was ordered and not built. The last band
says what is still ahead in the page's own words (DOC-2).

The phone gets a different drawing of the same argument: narrow14.py.

    python site/diagrams/diagram14.py
"""
from house import (W, S, canvas, save, band, rule, fit, arrow_down, dashed, chip,
                   sans, mono, text, ls_text, rr_path,
                   READ, TITLE, KICKER,
                   INK, MUTED, NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE, BRICK,
                   OLD_FILL, OLD_LINE, OLD_TEXT,
                   KERN_FILL, KERN_LINE, BG, HAIR)

KICKER_TOP = "HAROBANDA — A CLOUD THAT FITS IN A ROOM"
HALL = ("a hall", "data, compute, reach: one place", "ONE STRIKE, ALL LOST")
FILE = ("The fleet file", ["which boxes, on which links, who is the way between,",
                           "who dates the records, where data stays, which key is out"])
ROOMS = [("room A", ["one file, own key", "judges its boot", "keeps its record"], "machine"),
         ("room B", ["one file, own key", "the way between", "the two links"], "machine"),
         ("room C", ["lost: what the", "file says, and", "nothing more"], "struck")]
MIRROR = "A's files, kept on B"
NEXT = ("NEXT, ORDERED", ["the roll call: who has written a record since",
                          "the loss drill: one box lost, the rest serve"])

img, d = canvas(14)

ML = MR = 68
f_read, f_readm = mono(READ), mono(READ, "Medium")
f_title, f_lab = sans(TITLE, "SemiBold"), sans(READ, "Medium")
f_kick = mono(KICKER, "Medium")
INNER = W - ML - MR

ls_text(d, ML*S, 56*S, fit(f_kick, KICKER_TOP, INNER, "kicker", 2.4), f_kick, INK, 2.4)

# ---- one hall: everything in one place, and one strike ----------------------------------
HY, HH = 84, 72.0
band(d, ML, HY, INNER, HH, 13, OLD_FILL, OLD_LINE, lw=1.8, amp=1.0)
text(d, ML + 26, HY + HH/2, fit(f_title, HALL[0], 160, "hall title"), f_title, OLD_TEXT)
text(d, ML + 26 + 150, HY + HH/2, fit(f_read, HALL[1], 640, "hall sub"), f_read, OLD_TEXT)
CW, CH = 372, 40
cx = ML + INNER - 26 - CW
chip(d, cx, HY + (HH - CH)/2, CW, CH, fit(f_kick, HALL[2], CW - 24, "strike chip", 1.6), f_kick, BRICK, BG, 1.6)

# ---- the fleet file: what makes many rooms one cloud (the one orange mark) ---------------
FY, FH = 172, 128.0
band(d, ML, FY, INNER, FH, 13, BG, NEW_LINE, lw=2.2, amp=1.0)
d.polygon(rr_path((ML + 16)*S, (FY + 22)*S, (ML + 25)*S, (FY + FH - 22)*S, 4*S), fill=ORANGE)
text(d, ML + 44, FY + 40, fit(f_title, FILE[0], INNER - 70, "file title"), f_title, NEW_TEXT)
for i, ln in enumerate(FILE[1]):
    text(d, ML + 44, FY + 76 + i*34, fit(f_read, ln, INNER - 70, "file sub"), f_read, NEW_SUB)

# ---- three rooms on the links the file names -------------------------------------------
BY, BH = 336, 184.0
n = len(ROOMS)
gapw = 41.0
bw = (INNER - gapw*(n - 1)) / n
xs = [ML + i*(bw + gapw) for i in range(n)]
for (title, subs, style), x in zip(ROOMS, xs):
    if style == "machine":
        band(d, x, BY, bw, BH, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
        t_ink, s_ink = NEW_TEXT, NEW_SUB
    else:
        band(d, x, BY, bw, BH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=1.0)
        t_ink, s_ink = INK, MUTED
    text(d, x + 26, BY + 40, fit(f_title, title, bw - 52 - 150, "room title"), f_title, t_ink)
    if style == "struck":
        cw, ch = 140, 36
        chip(d, x + bw - 26 - cw, BY + 22, cw, ch, fit(f_kick, "STRUCK", cw - 20, "struck chip", 1.6), f_kick, BRICK, BG, 1.6)
    for i, ln in enumerate(subs):
        text(d, x + 26, BY + 78 + i*34, fit(f_read, ln, bw - 52, "room sub"), f_read, s_ink)
    arrow_down(d, x + bw/2, FY + FH + 4, BY - 6, HAIR, 2.4)

# ---- the copy, built: a solid line (it was dashed, this family's mark for absence, until MIR-1) ----------
MY = BY + BH + 14
ax0, ax1 = xs[0] + bw/2, xs[1] + bw/2
d.line([(ax0*S, MY*S), (ax1*S, MY*S)], fill=NEW_LINE, width=int(2.2*S))
hw = int(2.2*S)
d.line([((ax1 - 9)*S, (MY - 9)*S), (ax1*S, MY*S)], fill=NEW_LINE, width=hw)
d.line([(ax1*S, MY*S), ((ax1 - 9)*S, (MY + 9)*S)], fill=NEW_LINE, width=hw)
text(d, (ax0 + ax1)/2, MY + 22, fit(f_read, MIRROR, ax1 - ax0 - 20, "mirror label"), f_read, NEW_SUB, anchor="mm")

# ---- what the file will say next ----------------------------------------------------------
# (the links the rooms stand on are the file band's own words: "on which links, who is the way
# between"; a wire drawn under the rooms was the first render's, and it pushed this band off the
# canvas -- seen on the image, not by any check)
NY, NH = MY + 50, 24 + 40.0*len(NEXT[1]) + 16
band(d, ML, NY, INNER, NH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
lab, items = NEXT
text(d, ML + 26, NY + 42, fit(f_readm, lab, 270, "strip label"), f_readm, INK)
for i, ln in enumerate(items):
    text(d, ML + 26 + 296, NY + 42 + i*40, fit(f_read, ln, INNER - 26 - 296 - 26, "strip line"),
         f_read, MUTED)

print("wrote", save(img, "harobanda-diagram-14.png"))
