"""Diagram 4 -- what was kept, what was replaced above the kernel.  (machine.html)

Brief: site/DIAGRAMS.md section 4. The sentence it must make true:
the kernel is the same one you already run; everything the industry treats
as inevitable above it is gone, replaced by one idea.

    python site/diagrams/diagram4.py
"""
from house import (W, H, S, canvas, save, band, dashed, rule, rr_path,
                   sans, mono, text, ls_text, centre_ls,
                   INK, MUTED, OLD_FILL, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE,
                   KERN_FILL, KERN_LINE, HAIR)

img, d = canvas(4)

# ---- layout ----
ML = MR = 68
COL_W    = 588
LX, RX   = ML, 720
DIV      = 688
TOP, BOT = 140, 494                  # both stacks share this top and this baseline

centre_ls(d, W/2, 58, "THE KERNEL IS THE SAME.  EVERYTHING ABOVE IT IS NOT.",
          mono(19, "Medium"), INK, 3.2)

ls_text(d, LX*S, 120*S, "AN ORDINARY DISTRIBUTION", mono(16, "Medium"), MUTED, 2.4)
ls_text(d, RX*S, 120*S, "HAROBANDA",                mono(16, "Medium"), NEW_LINE, 2.4)

# ---- left: six bands, tight. The crowding is the point. ----
OLD = ["a shell", "a package manager", "a service manager",
       "mutable configuration", "a login  ·  an account", "a store"]
gap = 3.6
bh = ((BOT - TOP) - 5*gap) / 6.0
f_old = sans(21)
for i, label in enumerate(OLD):
    y = TOP + i * (bh + gap)
    band(d, LX, y, COL_W, bh, 9, OLD_FILL, OLD_LINE, lw=1.6, amp=0.9)
    text(d, LX + 26, y + bh/2, label, f_old, OLD_TEXT)

# ---- right: two bands and an absence, ending on the left's baseline ----
NEW = [("the declaration", "one file  ·  every line says why", True),
       ("the court",       "it judges before anything runs",   False)]
bh2, gap2 = 118.0, 24.0
f_new, f_nsub = sans(31, "SemiBold"), mono(16)
for i, (title, sub, accent) in enumerate(NEW):
    y = TOP + i * (bh2 + gap2)
    band(d, RX, y, COL_W, bh2, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
    if accent:                       # the one orange accent, as the site's own left rule
        d.polygon(rr_path((RX+16)*S, (y+22)*S, (RX+24)*S, (y+bh2-22)*S, 4*S), fill=ORANGE)
    text(d, RX + 38, y + bh2/2 - 14, title, f_new,  NEW_TEXT)
    text(d, RX + 38, y + bh2/2 + 21, sub,   f_nsub, NEW_SUB)

# What replaced the other six: nothing. The void has to carry that, or it
# reads as a hole -- so it is drawn as an absence, the way diagram 3 draws
# the internet the box cannot reach.
GY = TOP + 2*(bh2 + gap2)
GH = BOT - GY
dashed(d, rr_path(RX*S, GY*S, (RX+COL_W)*S, (GY+GH)*S, 13*S), OLD_LINE, int(2.0*S))
centre_ls(d, RX + COL_W/2, GY + GH/2 + 6, "and nothing else", mono(19), MUTED, 1.4)

# ---- the divider stops where the shared band begins ----
rule(d, DIV, 100, DIV, 560)

text(d, LX, 528, "convention, not the kernel's doing", mono(16), MUTED)
ls_text(d, RX*S, 533*S, "declare it  ·  judge it  ·  govern it", mono(16, "Medium"), NEW_LINE, 0.6)

# ---- both stacks stand on the same band ----
for cx in (LX + COL_W/2, RX + COL_W/2):
    rule(d, cx, 552, cx, 594)

KY, KH = 596, 98
band(d, ML, KY, W - ML - MR, KH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
text(d, ML + 34,  KY + KH/2, "Linux LTS", sans(29, "SemiBold"), INK)
text(d, W - MR - 34, KY + KH/2,
     "the same kernel, the same drivers, the same decades of hardening",
     mono(17), MUTED, anchor="rm")

print("wrote", save(img, "harobanda-diagram-4.jpg"))
