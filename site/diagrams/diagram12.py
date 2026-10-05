"""Diagram 12 -- the smallest cloud: a till, the box between two links, a server.
   (cloud.html)

Brief: site/DIAGRAMS.md section 11. The sentence it must make true: a till on
one network asks for a server on another by name, and reaches it through the
one machine the fleet file says is the way between them -- and what is not
there yet.

It is a topology, which is what a diagram is for here: three machines, two
networks, and which of them joins the two. The orange accent is used once, on
the box, because the box is what a second network adds. The two links are
drawn with the same weight at both ends (house.link_peer): the fleet's route
is a way BOTH ways, since no packet filter exists to make it one-way, and a
drawing that gave the link a direction would claim one.

What the machines said is quoted, not paraphrased: every quotation is a
substring of the pinned boot machines/cloud_links.expected, and the check
below refuses to draw one that is not. What is NOT there yet is on the
picture, in the same words as the page's own list (DOC-2): a picture that
showed only what works would claim more than the machines keep.

The phone gets a different drawing of the same argument: narrow12.py.

    python site/diagrams/diagram12.py
"""
import pathlib
import sys

from house import (W, S, canvas, save, band, rule, fit, arrow_down, link_peer,
                   sans, mono, text, ls_text, rr_path,
                   READ, TITLE, KICKER,
                   INK, MUTED, NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE,
                   KERN_FILL, KERN_LINE, BG, HAIR)

PINNED = pathlib.Path(__file__).resolve().parent.parent.parent / "machines" / "cloud_links.expected"

KICKER_TOP = "HAROBANDA — THE SMALLEST CLOUD"
FILE = ("The fleet file", "names the machines, the two links, and the way between")
# (title, what it does, which network it is on)
MACHINES = [("till", "asks by name"),
            ("box", "the way between"),
            ("server", "RingServ 0.9")]
LINKS = ["front", "core"]
# (who, the machine's own words), in reading order
SAID = [("the box says", "commons.core.cloud is 10.20.0.2"),
        ("the till gets", "commons.core.cloud:8210/health -- 200"),
        ("the server runs", "as appserver (2000:2000)")]
NOT_YET = ("NOT THERE YET", ["No front: plain HTTP, inside the cloud only.",
                             "No packet filter: a route is a way both ways.",
                             "No board: every boot shown is emulated."])

# every quotation is the machines', verbatim, or nothing is drawn
pinned = PINNED.read_text(encoding="utf-8")
for _, words in SAID:
    if words not in pinned:
        sys.exit("REFUSED: %r is not in %s" % (words, PINNED.name))

img, d = canvas(12)

ML = MR = 68
f_read, f_readm = mono(READ), mono(READ, "Medium")
f_title, f_lab = sans(TITLE, "SemiBold"), sans(READ, "Medium")
f_kick = mono(KICKER, "Medium")
INNER = W - ML - MR

ls_text(d, ML*S, 56*S, fit(f_kick, KICKER_TOP, INNER, "kicker", 2.4), f_kick, INK, 2.4)

# ---- the fleet file, and the three machines it names ------------------------------
FY, FH = 84, 112.0
band(d, ML, FY, INNER, FH, 13, BG, NEW_LINE, lw=2.2, amp=1.0)
text(d, ML + 26, FY + 44, fit(f_title, FILE[0], INNER - 52, "file title"), f_title, NEW_TEXT)
text(d, ML + 26, FY + 88, fit(f_read, FILE[1], INNER - 52, "file sub"), f_read, NEW_SUB)

BY, BH = 236, 124.0
# the box is the wider, emphasised machine; the two ends are plain
widths = [310.0, 380.0, 310.0]
gap = (INNER - sum(widths)) / 2
xs = [ML, ML + widths[0] + gap, ML + widths[0] + gap + widths[1] + gap]


def box(x, y, w, h, title, sub, fill, line, ink, subink, lw, accent=False):
    band(d, x, y, w, h, 13, fill, line, lw=lw, amp=1.0)
    pad = 44 if accent else 26
    if accent:
        d.polygon(rr_path((x + 16)*S, (y + 22)*S, (x + 25)*S, (y + h - 22)*S, 4*S), fill=ORANGE)
    inner = w - pad - 26
    text(d, x + pad, y + 44, fit(f_title, title, inner, "box title"), f_title, ink)
    text(d, x + pad, y + 92, fit(f_read, sub, inner, "box sub"), f_read, subink)


for i, ((title, sub), x, w) in enumerate(zip(MACHINES, xs, widths)):
    middle = i == 1
    box(x, BY, w, BH, title, sub,
        NEW_FILL if middle else BG, NEW_LINE, NEW_TEXT, NEW_SUB,
        2.6 if middle else 2.2, accent=middle)
    arrow_down(d, x + w/2, FY + FH + 4, BY - 6, HAIR, 2.4)

# ---- the two links: the same weight at both ends -----------------------------------
ly = BY + BH/2
for (label, x_from, x_to) in [(LINKS[0], xs[0] + widths[0], xs[1]),
                              (LINKS[1], xs[1] + widths[1], xs[2])]:
    link_peer(d, x_from + 10, x_to - 10, ly, HAIR, 2.4)
    text(d, (x_from + x_to)/2, ly - 24, fit(f_read, label, x_to - x_from - 8, "link label"),
         f_read, MUTED, anchor="mm")

# ---- what the machines said ---------------------------------------------------------
SY = BY + BH + 24
SH = 24 + 44.0 * len(SAID)
band(d, ML, SY, INNER, SH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
LABEL_W = 250
for i, (who, words) in enumerate(SAID):
    cy = SY + 12 + 22 + i*44
    text(d, ML + 26, cy, fit(f_lab, who, LABEL_W - 26, "label"), f_lab, INK)
    quote = "“" + words + "”"
    text(d, ML + 26 + LABEL_W, cy, fit(f_read, quote, INNER - 26 - LABEL_W - 26, "quotation"),
         f_read, NEW_SUB)

# ---- what is not there yet ---------------------------------------------------------
NY, NH = SY + SH + 22, 150.0
band(d, ML, NY, INNER, NH, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
lab, items = NOT_YET
text(d, ML + 26, NY + 42, fit(f_readm, lab, 270, "strip label"), f_readm, INK)
for i, ln in enumerate(items):
    text(d, ML + 26 + 296, NY + 42 + i*40, fit(f_read, ln, INNER - 26 - 296 - 26, "strip line"),
         f_read, MUTED)

print("wrote", save(img, "harobanda-diagram-12.png"))
