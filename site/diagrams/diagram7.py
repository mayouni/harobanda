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
comes first, so the left shows the job as a small part of a system that was
built for everyone, and shows how little subtracting it changes.

    python site/diagrams/diagram7.py
"""
from house import (W, S, canvas, save, band, rule, rr_path,
                   mono, text, ls_text, centre_ls,
                   INK, MUTED, OLD_FILL, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE, BRICK, BG, HAIR)

img, d = canvas(7)

ML = MR = 68
CW  = 592
LX, RX = ML, 716
DIV = 688

B1Y, B1H = 158, 214
B2Y, B2H = 452, 238

centre_ls(d, W/2, 58, "ONE STARTS FROM THE SYSTEM.  THE OTHER STARTS FROM THE JOB.",
          mono(19, "Medium"), INK, 3.2)
ls_text(d, LX*S, 126*S, "A GENERAL-PURPOSE OS", mono(16, "Medium"), MUTED, 2.4)
ls_text(d, RX*S, 126*S, "A DECLARED MACHINE",   mono(16, "Medium"), NEW_LINE, 2.4)
rule(d, DIV, 110, DIV, 690)

f_h, f_m, f_s = mono(16, "Medium"), mono(16), mono(15)

PROMISES = ["a fixed address", "a name that never moves",
            "a record that survives", "a clean restart"]


def arrow_down(d, x, y0, y1, fill, lw=2.4, head=9):
    rule(d, x, y0, x, y1, fill, lw)
    w = int(lw*S)
    d.line([((x-head)*S, (y1-head-1)*S), (x*S, y1*S)], fill=fill, width=w)
    d.line([(x*S, y1*S), ((x+head)*S, (y1-head-1)*S)], fill=fill, width=w)


def pill(d, x, y, w, h, label, fill, line, ink, font):
    pts = rr_path(x*S, y*S, (x+w)*S, (y+h)*S, (h/2)*S)
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=line, width=int(1.8*S), joint="curve")
    text(d, x + 18, y + h/2, label, font, ink)


def token_line(d, x, y, tokens, font, ink, struck_ink):
    """A list where some entries are crossed out -- subtraction, drawn."""
    for i, (t, struck) in enumerate(tokens):
        if i:
            text(d, x, y, " · ", font, MUTED)
            x += font.getlength(" · ") / S
        text(d, x, y, t, font, struck_ink if struck else ink)
        wpx = font.getlength(t) / S
        if struck:
            rule(d, x - 1, y, x + wpx + 1, y, BRICK, 1.8)
        x += wpx


# ---- LEFT: the system is given, the job is fitted into it ----
band(d, LX, B1Y, CW, B1H, 13, OLD_FILL, OLD_LINE, lw=1.8, amp=0.9)
text(d, LX + 26, B1Y + 34, "built for everyone", f_h, MUTED)
pill(d, LX + 26, B1Y + 70, 160, 44, "your job", NEW_FILL, NEW_LINE, NEW_TEXT, f_m)
text(d, LX + 204, B1Y + 92, "plus everything else it ships with", f_s, OLD_TEXT)
text(d, LX + 26, B1Y + 150, "drivers · desktop · services · packages · logins · a store",
     f_s, OLD_TEXT)
text(d, LX + 26, B1Y + 180, "updates you did not choose · a calendar someone else picks",
     f_s, OLD_TEXT)

arrow_down(d, LX + 90, B1Y + B1H + 22, B2Y - 22, HAIR, 2.4)
text(d, LX + 120, (B1Y + B1H + B2Y) / 2, "you adapt, and subtract", f_m, MUTED)

band(d, LX, B2Y, CW, B2H, 13, OLD_FILL, OLD_LINE, lw=1.8, amp=0.9)
text(d, LX + 26, B2Y + 36, "what you are left with", f_h, MUTED)
pill(d, LX + 26, B2Y + 70, 160, 44, "your job", NEW_FILL, NEW_LINE, NEW_TEXT, f_m)
token_line(d, LX + 26, B2Y + 146,
           [("drivers", False), ("desktop", True), ("services", False),
            ("packages", False), ("logins", False), ("a store", True)],
           f_s, OLD_TEXT, MUTED)
text(d, LX + 26, B2Y + 190, "two gone. the rest is still there,", f_s, OLD_TEXT)
text(d, LX + 26, B2Y + 214, "and still yours to secure.", f_s, OLD_TEXT)

# ---- RIGHT: the job is written first, and the machine follows from it ----
band(d, RX, B1Y, CW, B1H, 13, BG, OLD_LINE, lw=1.8, amp=0.9)   # a written sheet
text(d, RX + 26, B1Y + 34, "what the job must guarantee", f_h, NEW_LINE)
for i, p in enumerate(PROMISES):
    text(d, RX + 26, B1Y + 80 + i*32, p, mono(17), INK)

arrow_down(d, RX + 90, B1Y + B1H + 22, B2Y - 22, ORANGE, 3.0)  # the one accent
ls_text(d, (RX + 120)*S, ((B1Y + B1H + B2Y) / 2 + 6)*S, "DERIVE",
        mono(19, "Medium"), ORANGE, 3.0)

band(d, RX, B2Y, CW, B2H, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
text(d, RX + 26, B2Y + 36, "the machine", f_h, NEW_TEXT)
PW, PH = 262.0, 42.0
for i, p in enumerate(PROMISES):
    px = RX + 26 + (i % 2) * (PW + 14)
    py = B2Y + 70 + (i // 2) * (PH + 12)
    pill(d, px, py, PW, PH, p, BG, NEW_LINE, NEW_TEXT, f_s)
text(d, RX + 26, B2Y + 190, "contains only what was declared,", f_s, NEW_SUB)
text(d, RX + 26, B2Y + 214, "nothing more.", f_s, NEW_SUB)

print("wrote", save(img, "harobanda-diagram-7.jpg"))
