"""Diagram 10 -- the two deployments, drawn as topologies.  (field.html)

Brief: site/DIAGRAMS.md section 10. The sentence it must make true:
one a critical application, one a critical agent -- and both the same floor.

The two shapes are deliberately DIFFERENT: a star with a crossed way out, and
a hub with two bases. The brief's must-not is that they should not look like
one product wearing two skins, and the honest reason is that they are not --
one is a counter in Lyon, the other a hub and two bases across Niger.

WHAT THEY ARE ALLOWED TO CLAIM. field.html's own honesty list is stricter
than its case cards: "no customer yet runs a critical production workload on
it", and Cousbox's "box is the first Harobanda target". So the chip says the
APP is delivered and the line underneath says the box is the first target --
not that a restaurant is running on Harobanda today. The Diko side says won
and entering development, which is what the page says.

The orange appears on both machine boxes, as the same left rule. That is one
accent on one idea -- the floor is the same one -- which is the whole title.

    python site/diagrams/diagram10.py
"""
from house import (W, S, canvas, save, band, dashed, rule, rr_path, chip, fit,
                   sans, mono, text, ls_text, centre_ls,
                   READ, TITLE, KICKER,
                   INK, MUTED, OLD_LINE, NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB,
                   ORANGE, BRICK, BG, HAIR)

img, d = canvas(10)

ML = MR = 68
LX, RX, DIV, CW = 68, 716, 688, 592.0
BOX_W, BOX_H, BOX_Y = 300.0, 110.0, 190
PW, PH = 260.0, 50.0
LOW_Y, LOW_H = 390, 66.0

f_read, f_readm = mono(READ), mono(READ, "Medium")
f_title, f_kick = sans(TITLE, "SemiBold"), mono(KICKER, "Medium")

centre_ls(d, W/2, 48, "TWO PLACES, ONE FLOOR.", f_kick, INK, 3.2)
ls_text(d, LX*S, 104*S, "COUSBOX · A RESTAURANT IN LYON", f_kick, MUTED, 2.4)
ls_text(d, RX*S, 104*S, "DIKO · AN NGO IN NIGER", f_kick, MUTED, 2.4)
rule(d, DIV, 96, DIV, 700)


def pill(d, x, y, label):
    pts = rr_path(x*S, y*S, (x+PW)*S, (y+PH)*S, (PH/2)*S)
    d.polygon(pts, fill=BG)
    d.line(pts + [pts[0]], fill=NEW_LINE, width=int(1.8*S), joint="curve")
    text(d, x + 22, y + PH/2, fit(f_read, label, PW - 44, "pill"), f_read, NEW_TEXT)


def machine(d, x, title, sub):
    """Both places run the same floor, so both carry the same mark."""
    band(d, x, BOX_Y, BOX_W, BOX_H, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
    d.polygon(rr_path((x+16)*S, (BOX_Y+22)*S, (x+25)*S, (BOX_Y+BOX_H-22)*S, 4*S), fill=ORANGE)
    text(d, x + 42, BOX_Y + 40, fit(f_title, title, BOX_W - 68, "box"), f_title, NEW_TEXT)
    text(d, x + 42, BOX_Y + 78, fit(f_read, sub, BOX_W - 68, "box sub"), f_read, NEW_SUB)


# ---- LEFT: one box behind the counter, and no way out that it depends on ----
machine(d, LX, "the box", "the counter")
for i, label in enumerate(["a phone", "the kitchen", "the till"]):
    py = 165 + i*65
    pill(d, 400, py, label)
    rule(d, LX + BOX_W, BOX_Y + BOX_H/2, 400, py + PH/2, HAIR, 2.0)

rule(d, LX + BOX_W/2, BOX_Y + BOX_H, LX + BOX_W/2, LOW_Y, HAIR, 2.0)
cx, cy = LX + BOX_W/2, (BOX_Y + BOX_H + LOW_Y) / 2      # the crossed way out
for k in (-1, 1):
    d.line([((cx-13)*S, (cy - k*13)*S), ((cx+13)*S, (cy + k*13)*S)],
           fill=BRICK, width=int(3.0*S))
pts = rr_path(LX*S, LOW_Y*S, (LX+BOX_W)*S, (LOW_Y+LOW_H)*S, 13*S)
dashed(d, pts, OLD_LINE, int(2.0*S))
text(d, LX + 26, LOW_Y + LOW_H/2, "the internet", f_read, MUTED)

text(d, LX, 500, fit(f_read, "the service does not stop", CW, "L cap1"), f_read, MUTED)
text(d, LX, 538, fit(f_read, "when the link does", CW, "L cap2"), f_read, MUTED)

# ---- RIGHT: a hub, two bases, and the agents held inside the box ----
machine(d, RX, "the hub", "Niamey")
for i, label in enumerate(["Gothèye", "Diffa"]):
    py = 190 + i*65
    pill(d, 1048, py, label)
    rule(d, RX + BOX_W, BOX_Y + BOX_H/2, 1048, py + PH/2, HAIR, 2.0)

rule(d, RX + BOX_W/2, BOX_Y + BOX_H, RX + BOX_W/2, LOW_Y, HAIR, 2.0)
band(d, RX, LOW_Y, BOX_W, LOW_H, 13, BG, NEW_LINE, lw=2.4, amp=1.0)
text(d, RX + 26, LOW_Y + LOW_H/2, fit(f_title, "the agents", BOX_W - 52, "agents"),
     f_title, NEW_TEXT)

text(d, RX, 500, fit(f_read, "agents confined to the box", CW, "R cap1"), f_read, MUTED)
text(d, RX, 538, fit(f_read, "every action recorded", CW, "R cap2"), f_read, MUTED)

# ---- what each one honestly is today ----
chip(d, LX, 572, 318, 48, "app delivered", f_readm, NEW_LINE)
text(d, LX, 656, fit(f_read, "its box is the first target", CW, "L status"), f_read, MUTED)
chip(d, RX, 572, 339, 48, "engagement won", f_readm, MUTED)
text(d, RX, 656, fit(f_read, "now entering development", CW, "R status"), f_read, MUTED)

print("wrote", save(img, "harobanda-diagram-10.png"))
