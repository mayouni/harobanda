"""Diagram 13 -- a program given its time: two cores, one set apart, and one period of it.
   (realtime.html)

Brief: site/DIAGRAMS.md section 12. The sentence it must make true: a program
that declares its time runs on a core set apart for reserved programs, where
the kernel gives it its slice of every period and keeps the rest; everything
without a reservation runs on the other core and gets what is left.

It is containment and flow over time, which is what a diagram is for here:
two cores side by side, and inside the reserved one, one period drawn as a
bar -- the witness's 200, the neighbour's 700, the kernel's 100 of every
1000 microseconds, read left to right. The orange accent is used once, on
the core that is set apart, because that is what a reservation adds to a
machine. Nothing in the picture is a latency: the one number the witness
says is drawn as the letter N, as the pin holds it.

What the machine said is quoted, not paraphrased: every quotation is a
substring of a pinned boot (machines/qemu_deadline.expected or
machines/qemu_tick.expected), and the check below refuses to draw one that
is not. What is NOT there yet is on the picture, in the same words as the
page's own list (DOC-2).

The phone gets a different drawing of the same argument: narrow13.py.

    python site/diagrams/diagram13.py
"""
import pathlib
import sys

from house import (W, S, canvas, save, band, rule, fit, arrow_down, chevron,
                   sans, mono, text, ls_text, rr_path,
                   READ, TITLE, KICKER,
                   INK, MUTED, NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE,
                   KERN_FILL, KERN_LINE, BG, HAIR)

MACHINES = pathlib.Path(__file__).resolve().parent.parent.parent / "machines"
PINS = [MACHINES / "qemu_deadline.expected", MACHINES / "qemu_tick.expected"]

KICKER_TOP = "HAROBANDA — A PROGRAM GIVEN ITS TIME"
FILE = ("The declaration", "CORES 2 · PERIOD 1000, DEADLINE 500, RUNTIME 200, CORE 1")
CORE0 = ("core 0: the machine's", ["PID 1, and every program", "with no reservation:", "it gets what is left"])
CORE1 = ("core 1: set apart", "reserved programs only")
# one period of the reserved core, in microseconds: the witness, its neighbour, the kernel's own
# the kernel's slice is too narrow to carry its number at the one readable size: the legend says it
PERIOD = [("200", 200, NEW_LINE, BG), ("700", 700, KERN_LINE, INK), ("", 100, HAIR, INK)]
LEGEND = ["control 200 · second 700", "the kernel: 100 of 1000"]
# (who, the machine's own words), in reading order
SAID = [("the kernel", "PREEMPT_RT and its timers resolve 1 ns"),
        ("control", "on core 1 and no other"),
        ("the witness", "N us at the median, N us at the 99th")]
NOT_YET = ("NOT THERE YET", ["No board: every number is an emulator's.",
                             "No body: nothing has moved a motor."])

# every quotation is the machines', verbatim, or nothing is drawn
pinned = "\n".join(p.read_text(encoding="utf-8") for p in PINS)
for _, words in SAID:
    if words not in pinned:
        sys.exit("REFUSED: %r is not in any of %s" % (words, [p.name for p in PINS]))

img, d = canvas(13)

ML = MR = 68
f_read, f_readm = mono(READ), mono(READ, "Medium")
f_title, f_lab = sans(TITLE, "SemiBold"), sans(READ, "Medium")
f_kick = mono(KICKER, "Medium")
INNER = W - ML - MR

ls_text(d, ML*S, 56*S, fit(f_kick, KICKER_TOP, INNER, "kicker", 2.4), f_kick, INK, 2.4)

# ---- the declaration -------------------------------------------------------------------
FY, FH = 84, 100.0
band(d, ML, FY, INNER, FH, 13, BG, NEW_LINE, lw=2.2, amp=1.0)
text(d, ML + 26, FY + 40, fit(f_title, FILE[0], INNER - 52, "file title"), f_title, NEW_TEXT)
text(d, ML + 26, FY + 78, fit(f_read, FILE[1], INNER - 52, "file sub"), f_read, NEW_SUB)

# ---- the two cores: the machine's, and the one set apart --------------------------------
# tall enough for the period bar and its two legend lines: the first render's second legend line
# crossed the box's lower edge, seen on the image and not by any check
BY, BH = 224, 230.0
widths = [520.0, 680.0]
gap = INNER - sum(widths)
xs = [ML, ML + widths[0] + gap]

# core 0, plain: what is not reserved lives here
x, w = xs[0], widths[0]
band(d, x, BY, w, BH, 13, BG, NEW_LINE, lw=2.2, amp=1.0)
text(d, x + 26, BY + 44, fit(f_title, CORE0[0], w - 52, "core 0 title"), f_title, NEW_TEXT)
for i, ln in enumerate(CORE0[1]):
    text(d, x + 26, BY + 88 + i*40, fit(f_read, ln, w - 52, "core 0 sub"), f_read, NEW_SUB)
arrow_down(d, x + w/2, FY + FH + 4, BY - 6, HAIR, 2.4)

# core 1, the machine's blue-grey with the one orange mark: set apart for reserved programs
x, w = xs[1], widths[1]
band(d, x, BY, w, BH, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
d.polygon(rr_path((x + 16)*S, (BY + 22)*S, (x + 25)*S, (BY + BH - 22)*S, 4*S), fill=ORANGE)
text(d, x + 44, BY + 44, fit(f_title, CORE1[0], w - 70, "core 1 title"), f_title, NEW_TEXT)
text(d, x + 44, BY + 86, fit(f_read, CORE1[1], w - 70, "core 1 sub"), f_read, NEW_SUB)
arrow_down(d, x + w/2, FY + FH + 4, BY - 6, HAIR, 2.4)

# one period of the reserved core, left to right: the witness's slice, the neighbour's, the kernel's
bx0, bx1 = x + 44, x + w - 44
by0, by1 = BY + 108, BY + 136
cx = bx0
total = sum(us for _, us, _, _ in PERIOD)
for label, us, fill, ink in PERIOD:
    sw = (bx1 - bx0) * us / total
    d.rectangle([cx*S, by0*S, (cx + sw)*S, by1*S], fill=fill)
    if label:
        text(d, cx + sw/2, (by0 + by1)/2, fit(f_read, label, sw - 6, "period slice"), f_read, ink, anchor="mm")
    cx += sw
d.rectangle([bx0*S, by0*S, bx1*S, by1*S], outline=NEW_LINE, width=int(1.6*S))
chevron(d, bx1 + 16, (by0 + by1)/2, 8, NEW_LINE, 2.0)
for i, ln in enumerate(LEGEND):
    text(d, x + 44, BY + 166 + i*36, fit(f_read, ln, w - 70, "legend"), f_read, NEW_SUB)

# ---- what the machines said -------------------------------------------------------------
SY = BY + BH + 22
SH = 24 + 44.0 * len(SAID)
band(d, ML, SY, INNER, SH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
LABEL_W = 240
for i, (who, words) in enumerate(SAID):
    cy = SY + 12 + 22 + i*44
    text(d, ML + 26, cy, fit(f_lab, who, LABEL_W - 26, "label"), f_lab, INK)
    quote = "“" + words + "”"
    text(d, ML + 26 + LABEL_W, cy, fit(f_read, quote, INNER - 26 - LABEL_W - 26, "quotation"),
         f_read, NEW_SUB)

# ---- what is not there yet -------------------------------------------------------------
NY, NH = SY + SH + 20, 104.0
band(d, ML, NY, INNER, NH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
lab, items = NOT_YET
text(d, ML + 26, NY + 42, fit(f_readm, lab, 270, "strip label"), f_readm, INK)
for i, ln in enumerate(items):
    text(d, ML + 26 + 296, NY + 42 + i*40, fit(f_read, ln, INNER - 26 - 296 - 26, "strip line"),
         f_read, MUTED)

print("wrote", save(img, "harobanda-diagram-13.png"))
