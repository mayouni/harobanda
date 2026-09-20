"""Diagram 9 -- the loop: the last step returns to the first.  (index.html)

Brief: site/DIAGRAMS.md section 9. The sentence it must make true:
the last step returns to the first; that closure is the whole method.

THE SHAPE. The brief asked for a ring of five beats and for the diagram to
stay small, because it sits above the front page's card row and must not
tower over it. Those two pull against each other: a ring wastes the width of
a 16:9 canvas, and 16:9 renders 531px tall on a page only 3.5 screens long.
So the loop is drawn as a row that returns -- four beats read left to right,
and one heavy arc carrying the closure back under them -- on a canvas 500px
tall rather than 768. The closure becomes the largest thing in the picture,
which is what the diagram is for.

WHAT WAS DROPPED. The brief also wanted the court's refusal quoted beside the
judge beat. At reading size that sentence is 845px and the beat is 292px
wide, and the front page already carries it in the card below ("would have
refused it by name"). Repeating it here would make the diagram a restatement
rather than an addition, which is the thing the brief's own must-not warns
against. No 01-04 badges either, for the same reason.

    python site/diagrams/diagram9.py
"""
import math
from house import (W, S, canvas, save, band, rule, fit,
                   sans, mono, text, ls_text, centre_ls,
                   READ, TITLE, KICKER,
                   INK, MUTED, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE, BG, HAIR)

H9 = 500
img, d = canvas(9, H9)

ML = MR = 68
CW, CGAP, CY, CH = 292.0, 24.0, 100, 130.0
ARC_Y, R = 330, 26.0

f_read = mono(READ)
f_title = sans(TITLE, "SemiBold")
f_kick = mono(KICKER, "Medium")

centre_ls(d, W/2, 46, "THE LAST STEP RETURNS TO THE FIRST.", f_kick, INK, 3.2)

BEATS = [("declare", "one file"),
         ("judge",   "harb check"),
         ("plan",    "harb plan"),
         ("boot",    "harb boot")]

xs = [ML + i*(CW + CGAP) for i in range(4)]
for (title, sub), x in zip(BEATS, xs):
    band(d, x, CY, CW, CH, 13, BG, NEW_LINE, lw=2.4, amp=1.0)
    text(d, x + 26, CY + 48, fit(f_title, title, CW - 52, "beat"), f_title, NEW_TEXT)
    text(d, x + 26, CY + 92, fit(f_read, sub, CW - 52, "beat sub"), f_read, NEW_SUB)

for x in xs[:-1]:                     # time, left to right
    cxx = x + CW + CGAP/2
    for k in (-1, 1):
        d.line([((cxx - 5)*S, (CY + CH/2 + k*9)*S), ((cxx + 5)*S, (CY + CH/2)*S)],
               fill=HAIR, width=int(2.0*S))

# ---- the closure: drawn as the heaviest thing here, because it IS the method ----
x0, x1 = xs[-1] + CW/2, xs[0] + CW/2
pts = [(x0, CY + CH)]
for cx, cy, a0, a1 in ((x0 - R, ARC_Y - R, 0, 90), (x1 + R, ARC_Y - R, 90, 180)):
    for i in range(13):
        a = math.radians(a0 + (a1 - a0) * i / 12)
        pts.append((cx + R*math.cos(a), cy + R*math.sin(a)))
pts.append((x1, CY + CH + 16))
d.line([(px*S, py*S) for px, py in pts], fill=ORANGE, width=int(4.0*S), joint="curve")
for k in (-1, 1):                     # the head, landing back on the first beat
    d.line([((x1 + k*11)*S, (CY + CH + 27)*S), (x1*S, (CY + CH + 14)*S)],
           fill=ORANGE, width=int(4.0*S))

centre_ls(d, W/2, ARC_Y + 52, "the boot is judged against the file", f_read, MUTED, 1.2)
centre_ls(d, W/2, ARC_Y + 92, "a change is a new file, judged again",
           mono(READ, "Medium"), INK, 1.2)

print("wrote", save(img, "harobanda-diagram-9.png"))
