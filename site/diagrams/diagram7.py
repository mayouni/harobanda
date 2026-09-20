"""Diagram 7 -- derived from the job, not adapted down from a general system.
   (why.html, difference one)

Brief: site/DIAGRAMS.md section 7. The sentence it must make true:
you do not bend your solution to fit the OS; the machine is derived from
what the solution must guarantee.

The brief asked for arrows pointing in opposite directions and a title
reading "one is adapted downwards, the other is derived upwards" -- while
its own composition has DERIVE pointing down. Both cannot be drawn. The
opposition is not the direction of the arrow, it is WHAT SITS AT THE TOP:
on the left the system is given and the job is fitted into it; on the right
the job is written first and the machine follows from it. So both columns
read downwards and the title names the real difference.

The left column deliberately does NOT reuse diagram 4's crowded stack. That
diagram is about what an OS carries; this one is about which of the two
comes first.

Refit to the calibrated type scale in house.py. The four promises are still
drawn twice, because that correspondence IS the derivation -- at reading
size they are a list on both sides rather than a grid of pills.

    python site/diagrams/diagram7.py
"""
from house import (W, S, canvas, save, band, rule, rr_path, arrow_down, fit,
                   sans, mono, text, ls_text, centre_ls,
                   READ, TITLE, KICKER,
                   INK, MUTED, OLD_FILL, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE, BRICK, BG, HAIR)

img, d = canvas(7)

ML = MR = 68
CW = 592.0
LX, RX, DIV = ML, 716, 688
INNER = CW - 56
B1Y, B1H = 132, 220.0
B2Y, B2H = 430, 262.0

f_read, f_readm = mono(READ), mono(READ, "Medium")
# headers are told apart by FONT and WEIGHT at the same size, never by shrinking
# the text under them -- that is the whole of the site's type rule
f_head = sans(READ, "SemiBold")
f_kick = mono(KICKER, "Medium")

PROMISES = ["a fixed address", "a name that never moves",
            "a record that survives", "a clean restart"]

centre_ls(d, W/2, 48, "ONE STARTS FROM THE SYSTEM.  THE OTHER STARTS FROM THE JOB.",
          f_kick, INK, 3.2)
ls_text(d, LX*S, 104*S, "A GENERAL-PURPOSE OS", f_kick, MUTED, 2.4)
ls_text(d, RX*S, 104*S, "A DECLARED MACHINE",   f_kick, NEW_LINE, 2.4)
rule(d, DIV, 96, DIV, 692)


def pill(d, x, y, w, h, label, fill, line, ink, font):
    pts = rr_path(x*S, y*S, (x+w)*S, (y+h)*S, (h/2)*S)
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=line, width=int(1.8*S), joint="curve")
    text(d, x + 24, y + h/2, label, font, ink)


def token_line(d, x, y, tokens, font, ink):
    """A list where some entries are crossed out -- subtraction, drawn."""
    for i, (t, struck) in enumerate(tokens):
        if i:
            text(d, x, y, " · ", font, MUTED)
            x += font.getlength(" · ") / S
        text(d, x, y, t, font, MUTED if struck else ink)
        wpx = font.getlength(t) / S
        if struck:
            rule(d, x - 2, y, x + wpx + 2, y, BRICK, 2.0)
        x += wpx


# ---- LEFT: the system is given, the job is fitted into it ----
band(d, LX, B1Y, CW, B1H, 13, OLD_FILL, OLD_LINE, lw=1.8, amp=0.9)
text(d, LX + 28, B1Y + 38, fit(f_read, "built for everyone", INNER, "L1 head"), f_head, MUTED)
pill(d, LX + 28, B1Y + 66, 220, 56, "your job", NEW_FILL, NEW_LINE, NEW_TEXT, f_read)
text(d, LX + 28, B1Y + 158, fit(f_read, "plus everything else", INNER, "L1 a"), f_read, OLD_TEXT)
text(d, LX + 28, B1Y + 196, fit(f_read, "you did not choose", INNER, "L1 b"), f_read, OLD_TEXT)

arrow_down(d, LX + 90, B1Y + B1H + 16, B2Y - 18, HAIR, 2.4)
text(d, LX + 130, (B1Y + B1H + B2Y) / 2,
     fit(f_read, "you adapt, and subtract", CW - 130, "L arrow"), f_read, MUTED)

band(d, LX, B2Y, CW, B2H, 13, OLD_FILL, OLD_LINE, lw=1.8, amp=0.9)
text(d, LX + 28, B2Y + 38, fit(f_read, "what you are left with", INNER, "L2 head"), f_head, MUTED)
pill(d, LX + 28, B2Y + 66, 220, 56, "your job", NEW_FILL, NEW_LINE, NEW_TEXT, f_read)
token_line(d, LX + 28, B2Y + 166,
           [("drivers", False), ("desktop", True), ("logins", False)], f_read, OLD_TEXT)
token_line(d, LX + 28, B2Y + 204,
           [("packages", False), ("a store", True)], f_read, OLD_TEXT)
text(d, LX + 28, B2Y + 242, fit(f_read, "two gone. the rest stays.", INNER, "L2 note"),
     f_read, OLD_TEXT)

# ---- RIGHT: the job is written first, and the machine follows from it ----
band(d, RX, B1Y, CW, B1H, 13, BG, OLD_LINE, lw=1.8, amp=0.9)   # a written sheet
text(d, RX + 28, B1Y + 38, fit(f_read, "what the job must guarantee", INNER, "R1 head"),
     f_head, NEW_LINE)
for i, p in enumerate(PROMISES):
    text(d, RX + 28, B1Y + 86 + i*36, fit(f_read, p, INNER, "promise"), f_read, INK)

arrow_down(d, RX + 90, B1Y + B1H + 16, B2Y - 18, ORANGE, 3.0)  # the one accent
ls_text(d, (RX + 130)*S, ((B1Y + B1H + B2Y) / 2 + 11)*S, "DERIVE", f_readm, ORANGE, 3.0)

band(d, RX, B2Y, CW, B2H, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
text(d, RX + 28, B2Y + 38, fit(f_read, "the machine", INNER, "R2 head"), f_head, NEW_TEXT)
for i, p in enumerate(PROMISES):
    text(d, RX + 28, B2Y + 86 + i*36, p, f_read, NEW_TEXT)
text(d, RX + 28, B2Y + 242, fit(f_read, "nothing more.", INNER, "R2 note"), f_read, NEW_SUB)

print("wrote", save(img, "harobanda-diagram-7.jpg"))
