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

Refit to the calibrated type scale in house.py. Three cards at reading size
hold sixteen characters a line, so every slot label was cut to fit.

    python site/diagrams/diagram5.py
"""
from house import (W, S, canvas, save, band, dashed, rr_path, chip, chevron, fit,
                   sans, mono, text, ls_text, centre_ls,
                   READ, TITLE, KICKER,
                   INK, MUTED, OLD_FILL, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE, BRICK, BG)

img, d = canvas(5)

ML = MR = 68
CGAP = 40.0
CW = (W - ML - MR - 2*CGAP) / 3.0
CY, CH = 106, 200.0
BAR_INSET, BAR_H = 16.0, 58.0

f_read, f_readm = mono(READ), mono(READ, "Medium")
f_title, f_kick = sans(TITLE, "SemiBold"), mono(KICKER, "Medium")
BAR_INNER = CW - 2*BAR_INSET - 32

centre_ls(d, W/2, 48, "TWO SLOTS, A TRIAL, AND A TIMER THAT IS NOT SOFTWARE.",
          f_kick, INK, 3.2)

# ---- the three stages ----
# each shows BOTH slots, because the point is that the old one is never gone
STAGES = [
    ("1 · now", False,
     [("slot A — running", NEW_FILL, NEW_LINE, NEW_TEXT, False),
      ("slot B — empty",   None,     OLD_LINE, OLD_TEXT, True)],
     "two copies, always"),
    ("2 · the update", False,
     [("slot A — running", NEW_FILL, NEW_LINE, NEW_TEXT, False),
      ("slot B — written", OLD_FILL, OLD_LINE, OLD_TEXT, False)],
     "not yet trusted"),
    ("3 · the trial", True,
     [("slot A — kept",    OLD_FILL, OLD_LINE, OLD_TEXT, False),
      ("slot B — booted",  NEW_FILL, NEW_LINE, NEW_TEXT, False)],
     "watchdog armed"),
]

for i, (head, hot, bars, cap) in enumerate(STAGES):
    x = ML + i*(CW + CGAP)
    band(d, x, CY, CW, CH, 13, BG, ORANGE if hot else OLD_LINE,
         lw=3.0 if hot else 1.8, amp=0.8)
    ls_text(d, (x+24)*S, (CY+38)*S, head, f_kick, ORANGE if hot else MUTED, 1.8)
    for j, (label, fill, line, ink, empty) in enumerate(bars):
        by = CY + 62 + j*68
        pts = rr_path((x+BAR_INSET)*S, by*S, (x+CW-BAR_INSET)*S, (by+BAR_H)*S, 9*S)
        if empty:                                   # a slot with nothing in it
            dashed(d, pts, line, int(1.8*S))
        else:
            d.polygon(pts, fill=fill)
            d.line(pts + [pts[0]], fill=line, width=int(1.8*S), joint="curve")
        text(d, x + BAR_INSET + 16, by + BAR_H/2,
             fit(f_read, label, BAR_INNER, "slot bar"), f_read, ink)
    text(d, x, CY + CH + 40, fit(f_read, cap, CW, "stage cap"),
         f_read, ORANGE if hot else MUTED)
    if i < 2:
        chevron(d, x + CW + CGAP/2, CY + CH/2, size=11)

# ---- the question the box asks itself ----
centre_ls(d, W/2, 412, "does the boot match what the file declared?", f_read, INK, 1.2)

# ---- the two outcomes ----
BW, BH, CHIP_W = W - ML - MR, 124.0, 280.0
OUT = [
    (446, "IT DOES", NEW_LINE, NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB,
     "commit — slot B is the one that runs", "the watchdog keeps being fed"),
    (590, "IT DOES NOT", BRICK, OLD_FILL, BRICK, OLD_TEXT, MUTED,
     "reset — the board boots slot A", "the feed stops. no one drives out."),
]
for y, label, chip_fill, fill, line, ink, sub_ink, main, sub in OUT:
    band(d, ML, y, BW, BH, 13, fill, line, lw=2.4, amp=0.9)
    chip(d, ML + 28, y + BH/2 - 24, CHIP_W, 48, label, f_readm, chip_fill)
    tx = ML + 28 + CHIP_W + 30
    avail = W - MR - 34 - tx
    text(d, tx, y + BH/2 - 20, fit(f_title, main, avail, "outcome"), f_title, ink)
    text(d, tx, y + BH/2 + 22, fit(f_read, sub, avail, "outcome sub"), f_read, sub_ink)

print("wrote", save(img, "harobanda-diagram-5.jpg"))
