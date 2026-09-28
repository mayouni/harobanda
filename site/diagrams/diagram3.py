"""Diagram 3 -- the governed envelope.  (assistant.html)

A REDRAW, in the house style, of the hand-drawn diagram 3, which could be
replaced but not edited. It labelled the envelope "every exchange recorded",
and nothing records an exchange: the machine's journal signs what the
machine WAS at each boot (JRN-1), and what a world does is that world's own
record to keep. The page's prose said so from 2026-09-27 (DOC-2); the
picture went on saying the opposite until the author asked for this one.

The words are the hand drawing's, less that phrase. The arrangement is not.
Its type was smaller than the scale diagrams 4-10 were calibrated to, and at
READ and TITLE three boxes across fill the width, leaving no room beside the
envelope for the internet. So the internet moved ABOVE it, and the way out
leaves through the envelope's top edge, crossed. The envelope's properties
moved to its top line, because in the hand drawing the person's arrow ran
straight through them.

    python site/diagrams/diagram3.py
"""
from house import (W, S, canvas, save, band, dashed, rule, rr_path, fit,
                   link_peer, sans, mono, text, ls_text, centre_ls,
                   READ, TITLE, KICKER,
                   INK, MUTED, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE, BRICK,
                   BG, HAIR)

img, d = canvas(3)

ML = MR = 68
f_read, f_readm = mono(READ), mono(READ, "Medium")
f_title, f_head = sans(TITLE, "SemiBold"), sans(READ, "SemiBold")
f_kick = mono(KICKER, "Medium")

# ---- the way out: an absence above the envelope, reached by a crossed line ----
IX, IY, IW, IH = 810, 40, 498.0, 108.0
dashed(d, rr_path(IX*S, IY*S, (IX+IW)*S, (IY+IH)*S, 13*S), OLD_LINE, int(2.0*S))
text(d, IX + 28, IY + 36, fit(f_head, "the internet", IW - 56, "internet"),
     f_head, OLD_TEXT)
text(d, IX + 28, IY + 76, fit(f_read, "a cloud model, a vendor", IW - 56, "internet sub"),
     f_read, MUTED)

ls_text(d, ML*S, (IY + 46)*S, "HAROBANDA — THE GOVERNED ENVELOPE", f_kick, INK, 2.4)

EX, EY, EW, EH = ML, 252, W - ML - MR, 288.0
CX = IX + IW/2                        # the way out, straight down from the absence
rule(d, CX, IY + IH, CX, EY, HAIR, 2.0)
cy = (IY + IH + EY) / 2
for k in (-1, 1):
    d.line([((CX-13)*S, (cy - k*13)*S), ((CX+13)*S, (cy + k*13)*S)],
           fill=BRICK, width=int(3.0*S))
text(d, CX - 30, cy, fit(f_readm, "EGRESS none — no route out", CX - 30 - ML, "egress"),
     f_readm, BRICK, anchor="rm")

# ---- the envelope, and what it holds ----
band(d, EX, EY, EW, EH, 16, BG, NEW_LINE, lw=2.8, amp=1.2)
PAD = 34
text(d, EX + PAD, EY + 46,
     fit(f_readm, "budgeted (memory · CPU) · confined", EW - 2*PAD, "properties"),
     f_readm, NEW_LINE)

KB_W, AS_W, MD_W = 297.0, 281.0, 229.0
LINK = (EW - 2*PAD - KB_W - AS_W - MD_W) / 2
KB_X = EX + PAD
AS_X = KB_X + KB_W + LINK
MD_X = AS_X + AS_W + LINK
RY = EY + 166                         # the row's centre line
SH, AH = 110.0, 130.0                 # the assistant stands taller than its two


def side(x, w, title, sub):
    """A thing the assistant uses: on the device, inside the same envelope."""
    y = RY - SH/2
    band(d, x, y, w, SH, 13, BG, NEW_LINE, lw=2.2, amp=1.0)
    text(d, x + 28, y + 40, fit(f_head, title, w - 56, "side"), f_head, NEW_TEXT)
    text(d, x + 28, y + 78, fit(f_read, sub, w - 56, "side sub"), f_read, NEW_SUB)


side(KB_X, KB_W, "knowledge base", "on device")
side(MD_X, MD_W, "model", "on device")

ay = RY - AH/2
band(d, AS_X, ay, AS_W, AH, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
d.polygon(rr_path((AS_X+16)*S, (ay+24)*S, (AS_X+25)*S, (ay+AH-24)*S, 4*S), fill=ORANGE)
text(d, AS_X + 42, ay + 48, fit(f_title, "assistant", AS_W - 66, "assistant"),
     f_title, NEW_TEXT)
text(d, AS_X + 42, ay + 94, fit(f_read, "Softanza AI", AS_W - 66, "assistant sub"),
     f_read, NEW_SUB)

for x0, label in ((KB_X + KB_W, "retrieve"), (AS_X + AS_W, "reason")):
    link_peer(d, x0 + 4, x0 + LINK - 4, RY)
    centre_ls(d, x0 + LINK/2, RY - 20, fit(f_read, label, LINK - 20, "link"),
              f_read, MUTED, 0)

# ---- the person, outside, and the one way in ----
AX = AS_X + AS_W/2
PW, PH, PY = 298.0, 56.0, 652
pts = rr_path((AX - PW/2)*S, PY*S, (AX + PW/2)*S, (PY+PH)*S, (PH/2)*S)
d.polygon(pts, fill=BG)
d.line(pts + [pts[0]], fill=NEW_LINE, width=int(1.8*S), joint="curve")
text(d, AX, PY + PH/2, fit(f_read, "a person asks", PW - 40, "pill"), f_read, NEW_TEXT,
     anchor="mm")

top = ay + AH                          # an arrow UP: the person asks, into the box
rule(d, AX, PY, AX, top + 2, HAIR, 2.4)
w = int(2.4*S)
d.line([((AX-9)*S, (top+11)*S), (AX*S, (top+2)*S)], fill=HAIR, width=w)
d.line([(AX*S, (top+2)*S), ((AX+9)*S, (top+11)*S)], fill=HAIR, width=w)
text(d, AX + 22, (EY + EH + PY) / 2, "asks · answers", f_read, MUTED)

print("wrote", save(img, "harobanda-diagram-3.png"))
