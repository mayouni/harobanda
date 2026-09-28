"""Diagram 8 -- a fleet is a set of declarations, and the cloud is a peer.
   (enterprise.html)

Brief: site/DIAGRAMS.md section 8. The sentence it must make true:
sovereign nodes that integrate with the cloud you already run -- not a cloud
replacement, and not a cloud dependency.

The cloud is drawn at the SAME altitude as the boxes and joined by a link
with equal weight at both ends. Drawing it above them, or as a hub they hang
from, is the exact misreading this diagram exists to prevent.

The brief asked for a figure holding the public half. No person is drawn --
diagram 5 established that, and a silhouette would be the only human shape
in the family. The claim is a sentence in the evidence strip instead.

The keys are distinct -- KEY1, KEY2, KEY3, never one repeated value -- for
the same reason the boot judge maps each fingerprint separately (IDN-1): a
constant would hide the claim that every box keeps its own.

    python site/diagrams/diagram8.py
"""
from house import (W, S, canvas, save, band, rule, chip, fit, arrow_down, link_peer,
                   sans, mono, text, ls_text, centre_ls,
                   READ, TITLE, KICKER,
                   INK, MUTED, OLD_FILL, OLD_LINE, OLD_TEXT,
                   NEW_FILL, NEW_LINE, NEW_TEXT, NEW_SUB, ORANGE,
                   KERN_FILL, KERN_LINE, HAIR, BG)

img, d = canvas(8)

ML = MR = 68
CARD_X, CARD_Y, CARD_W, CARD_H = ML, 136, 402.0, 126.0
BOX_Y, BOX_H, BOX_W, BOX_GAP = 330, 140.0, 224.0, 30.0
CLOUD_X, CLOUD_Y, CLOUD_W, CLOUD_H = 920, 344, 388.0, 112.0
SPINE = 296

f_read, f_readm = mono(READ), mono(READ, "Medium")
f_title = sans(TITLE, "SemiBold")
f_box   = sans(38, "SemiBold")
f_sub   = mono(READ)        # sub-labels sit at READ like everything else

centre_ls(d, W/2, 52, "A FLEET IS A SET OF DECLARATIONS.", mono(KICKER, "Medium"), INK, 3.2)
ls_text(d, ML*S, 108*S, "ONE DECLARATION", mono(KICKER, "Medium"), NEW_LINE, 2.4)
ls_text(d, CLOUD_X*S, 108*S, "AND THE CLOUD YOU RUN", mono(KICKER, "Medium"), MUTED, 2.4)

# ---- the declaration every box is derived from ----
band(d, CARD_X, CARD_Y, CARD_W, CARD_H, 13, NEW_FILL, NEW_LINE, lw=2.6, amp=1.0)
text(d, CARD_X + 30, CARD_Y + 48,
     fit(f_title, "one declaration", CARD_W - 60, "card title"), f_title, NEW_TEXT)
text(d, CARD_X + 30, CARD_Y + 94,
     fit(f_sub, "+ a pinned digest", CARD_W - 60, "card sub"), f_sub, NEW_SUB)

# ---- the fleet: identical boxes, each with its own key ----
cx = [ML + i*(BOX_W + BOX_GAP) + BOX_W/2 for i in range(3)]
arrow_down(d, CARD_X + CARD_W/2, CARD_Y + CARD_H + 10, SPINE - 2, HAIR, 2.4, head=0)
rule(d, cx[0], SPINE, cx[-1], SPINE, HAIR, 2.4)
for c in cx:
    arrow_down(d, c, SPINE, BOX_Y - 12, HAIR, 2.4)

for i, c in enumerate(cx):
    x = c - BOX_W/2
    band(d, x, BOX_Y, BOX_W, BOX_H, 13, BG, NEW_LINE, lw=2.4, amp=1.0)
    text(d, x + 26, BOX_Y + 48,
         fit(f_box, "box %d" % (i+1), BOX_W - 52, "box title"), f_box, NEW_TEXT)
    chip(d, x + 26, BOX_Y + 78, 120, 44, "KEY%d" % (i+1), mono(28, "Medium"), NEW_LINE)

# ---- the cloud: same altitude, joined by a link of equal weight ----
link_peer(d, ML + 3*BOX_W + 2*BOX_GAP + 12, CLOUD_X - 12, BOX_Y + BOX_H/2, HAIR, 2.4)
band(d, CLOUD_X, CLOUD_Y, CLOUD_W, CLOUD_H, 13, OLD_FILL, OLD_LINE, lw=2.0, amp=0.9)
text(d, CLOUD_X + CLOUD_W/2, CLOUD_Y + 42,
     fit(f_box, "your cloud", CLOUD_W - 40, "cloud"), f_box, OLD_TEXT, anchor="mm")
text(d, CLOUD_X + CLOUD_W/2, CLOUD_Y + 82,
     fit(f_sub, "a peer, not a hub", CLOUD_W - 40, "cloud sub"), f_sub, MUTED, anchor="mm")

# ---- the two claims, stated once each ----
SW = W - ML - MR
# "bit-for-bit" ended the first strip until 2026-09-28. No build fixes the
# kernel's build timestamp, so two builds of one file differ (DOC-2).
for y, left, right in [
    (506, "no snowflakes", "every box derived from one file"),
    (598, "evidence",      "checked by anyone who never held the secret"),
]:
    band(d, ML, y, SW, 78, 13, KERN_FILL, KERN_LINE, lw=2.0, amp=0.8)
    text(d, ML + 34, y + 39, fit(f_readm, left, 420, "strip left"), f_readm, INK)
    text(d, W - MR - 34, y + 39, fit(f_read, right, 950, "strip right"),
         f_read, MUTED, anchor="rm")

print("wrote", save(img, "harobanda-diagram-8.png"))
