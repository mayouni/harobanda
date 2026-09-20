"""Diagram 5 -- the trial: two slots, a timer, and the return to what worked.
   (machine.html)

Brief: site/DIAGRAMS.md section 5. The sentence it must make true:
a new version is tried once, and if it does not recognise its own boot the
board returns to the one that worked -- with nobody on site.

The brief's closing strip was the VDCT-1 doctrine line about verdicts and
exit codes. That is a line about shell scripts, written for people who
maintain this repository; a reader of the site has no way to hear it. The
closing sentence is the page's own instead: no one drives out to fix it.

No person, no console, no dashboard is drawn anywhere here -- the mechanism's
entire claim is that nobody is present. And the watchdog is never called
automatic recovery: it is a timer that stops being fed.

    python site/diagrams/diagram5.py
"""
from house import (W, H, S, canvas, save, band, dashed, rule, rr_path, chip, chevron,
                   sans, mono, text, ls_text, centre_ls,
                   INK, MUTED, OLD_FILL, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE, BRICK, BG, HAIR)

img, d = canvas(5)

ML = MR = 68
CW, CGAP = 380.0, 50.0               # three stages across the top
CY, CH = 140, 196

centre_ls(d, W/2, 58, "TWO SLOTS, A TRIAL, AND A TIMER THAT IS NOT SOFTWARE.",
          mono(19, "Medium"), INK, 3.2)

# ---- the three stages ----
# each shows BOTH slots, because the point is that the old one is never gone
STAGES = [
    ("1 · now", False,
     [("slot A  —  running",        NEW_FILL, NEW_LINE, NEW_TEXT, False),
      ("slot B  —  empty",          None,     OLD_LINE, OLD_TEXT, True)],
     "two copies of the machine"),
    ("2 · the update", False,
     [("slot A  —  still running",  NEW_FILL, NEW_LINE, NEW_TEXT, False),
      ("slot B  —  written",        OLD_FILL, OLD_LINE, OLD_TEXT, False)],
     "written, not yet trusted"),
    ("3 · the trial", True,
     [("slot A  —  kept, untouched", OLD_FILL, OLD_LINE, OLD_TEXT, False),
      ("slot B  —  booted once",     NEW_FILL, NEW_LINE, NEW_TEXT, False)],
     "the watchdog is armed"),
]

f_stage, f_bar, f_cap = mono(16, "Medium"), mono(15), mono(16)
for i, (head, hot, bars, cap) in enumerate(STAGES):
    x = ML + i*(CW + CGAP)
    band(d, x, CY, CW, CH, 13, BG, OLD_LINE if not hot else ORANGE,
         lw=1.8 if not hot else 3.0, amp=0.8)
    ls_text(d, (x+24)*S, (CY+36)*S, head, f_stage, ORANGE if hot else MUTED, 1.8)
    for j, (label, fill, line, ink, empty) in enumerate(bars):
        by = CY + 58 + j*62
        pts = rr_path((x+22)*S, by*S, (x+CW-22)*S, (by+52)*S, 9*S)
        if empty:                                   # a slot with nothing in it
            dashed(d, pts, line, int(1.8*S))
        else:
            d.polygon(pts, fill=fill)
            o = rr_path((x+22)*S, by*S, (x+CW-22)*S, (by+52)*S, 9*S)
            d.line(o + [o[0]], fill=line, width=int(1.8*S), joint="curve")
        text(d, x + 40, by + 26, label, f_bar, ink)
    text(d, x + 24, CY + CH + 26, cap, f_cap, ORANGE if hot else MUTED)
    if i < 2:
        chevron(d, x + CW + CGAP/2, CY + CH/2)

# ---- the question the box asks itself ----
centre_ls(d, W/2, 416, "does the boot match what the file declared?",
          mono(19), INK, 1.2)

# ---- the two outcomes ----
BX, BW, BH = ML, W - ML - MR, 108.0
CHIP_W = 168.0
OUT = [
    (452, "IT DOES", NEW_LINE, NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB,
     "commit  —  slot B is the one that runs",
     "the watchdog keeps being fed, and the trial is committed"),
    (590, "IT DOES NOT", BRICK, OLD_FILL, BRICK, OLD_TEXT, MUTED,
     "reset  —  the board boots slot A, unchanged",
     "the feed stops, the timer expires, and no one drives out to fix it"),
]
f_out, f_osub = sans(26, "SemiBold"), mono(16)
for y, label, chip_fill, fill, line, ink, sub_ink, main, sub in OUT:
    band(d, BX, y, BW, BH, 13, fill, line, lw=2.4, amp=0.9)
    chip(d, BX + 28, y + BH/2 - 18, CHIP_W, 36, label, mono(16, "Medium"), chip_fill)
    tx = BX + 28 + CHIP_W + 30
    text(d, tx, y + BH/2 - 14, main, f_out,  ink)
    text(d, tx, y + BH/2 + 20, sub,  f_osub, sub_ink)

print("wrote", save(img, "harobanda-diagram-5.jpg"))
