"""Diagram 4 -- what was kept, what was replaced above the kernel.  (machine.html)

Brief: site/DIAGRAMS.md section 4. The sentence it must make true:
the kernel is the same one you already run; everything the industry treats
as inevitable above it is gone, replaced by one idea.

Refit to the calibrated type scale in house.py. The first cut of this
diagram set its labels at roughly half the size of the hand-authored
diagrams 1-3, and shrank its sub-labels below its titles -- the one thing
the site's own rule forbids. Bigger type means fewer words, so every label
here was cut to fit rather than set smaller to make room.

    python site/diagrams/diagram4.py
"""
from house import (W, S, canvas, save, band, dashed, rule, rr_path, fit,
                   sans, mono, text, ls_text, centre_ls,
                   READ, TITLE, KICKER,
                   INK, MUTED, OLD_FILL, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE,
                   KERN_FILL, KERN_LINE, HAIR)

img, d = canvas(4)

ML = MR = 68
CW = 592.0
LX, RX, DIV = ML, 716, 688
TOP, BOT = 146, 538                  # both stacks share this top and this baseline
INNER = CW - 56

f_read, f_readm = mono(READ), mono(READ, "Medium")
f_lab, f_title = sans(READ), sans(TITLE, "SemiBold")
f_kick = mono(KICKER, "Medium")

centre_ls(d, W/2, 52, "THE KERNEL IS THE SAME.  EVERYTHING ABOVE IT IS NOT.",
          f_kick, INK, 3.2)
ls_text(d, LX*S, 110*S, "AN ORDINARY DISTRIBUTION", f_kick, MUTED, 2.4)
ls_text(d, RX*S, 110*S, "HAROBANDA", f_kick, NEW_LINE, 2.4)

# ---- left: six bands, tight. The crowding is the point. ----
OLD = ["a shell", "a package manager", "a service manager",
       "mutable configuration", "a login, an account", "a store"]
gap = 4.0
bh = ((BOT - TOP) - 5*gap) / 6.0
for i, label in enumerate(OLD):
    y = TOP + i*(bh + gap)
    band(d, LX, y, CW, bh, 9, OLD_FILL, OLD_LINE, lw=1.8, amp=0.9)
    text(d, LX + 28, y + bh/2, fit(f_lab, label, INNER, "old band"), f_lab, OLD_TEXT)

# ---- right: two bands and an absence, ending on the left's baseline ----
NEW = [("the declaration", "every line says why", True),
       ("the court",       "judged before it runs", False)]
bh2, gap2 = 130.0, 24.0
for i, (title, sub, accent) in enumerate(NEW):
    y = TOP + i*(bh2 + gap2)
    band(d, RX, y, CW, bh2, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
    if accent:                       # the one orange accent, the site's own left rule
        d.polygon(rr_path((RX+18)*S, (y+24)*S, (RX+27)*S, (y+bh2-24)*S, 4*S), fill=ORANGE)
    text(d, RX + 44, y + 48, fit(f_title, title, INNER, "new title"), f_title, NEW_TEXT)
    text(d, RX + 44, y + 94, fit(f_read, sub, INNER, "new sub"), f_read, NEW_SUB)

# What replaced the other six: nothing. The void has to carry that, or it
# reads as a hole -- so it is drawn as an absence, the way diagram 3 draws
# the internet the box cannot reach.
GY = TOP + 2*(bh2 + gap2)
GH = BOT - GY
dashed(d, rr_path(RX*S, GY*S, (RX+CW)*S, (GY+GH)*S, 13*S), OLD_LINE, int(2.0*S))
centre_ls(d, RX + CW/2, GY + GH/2 + 11, "and nothing else", f_read, MUTED, 1.4)

rule(d, DIV, 100, DIV, 566)          # stops where the shared band begins

text(d, LX, 574, fit(f_read, "not the kernel's doing", CW, "left cap"), f_read, MUTED)
text(d, RX, 574, fit(f_readm, "declare · judge · govern", CW, "right cap"), f_readm, NEW_LINE)

for cx in (LX + CW/2, RX + CW/2):    # both stacks stand on the same band
    rule(d, cx, 596, cx, 628)

KY, KH = 630, 100
band(d, ML, KY, W - ML - MR, KH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
text(d, ML + 36, KY + KH/2, "Linux LTS", f_title, INK)
text(d, W - MR - 36, KY + KH/2,
     fit(f_read, "the same kernel, the same drivers", 700, "kernel sub"),
     f_read, MUTED, anchor="rm")

print("wrote", save(img, "harobanda-diagram-4.png"))
