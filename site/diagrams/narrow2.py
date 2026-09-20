"""Diagram 2, narrow. NOTE: a redraw of the hand-authored wide diagram 2, in
the house style. See narrow1.py for why, and for how to drop it.

The altitudes keep the order the wide one reads in -- applications at the
top, ordinary hardware at the floor -- because that order is the claim.

    python site/diagrams/narrow2.py
"""
from narrowlib import Col, MUTED, NEW_LINE

c = Col(2)
c.title("DECLARE, JUDGE, GOVERN — AT EVERY ALTITUDE.")
c.gap(8)

c.box("your applications & AI", "governed, in any domain", "old", accent=True)
c.box("the intelligence layer", "knowledge, models, agents — on device", "plain")
c.box("Softanza", "the computational foundation — build apps", "plain")
c.box("the Haro family", "engine, server, mobile, IoT — run programs", "plain")
c.box("HAROBANDA", "the declared machine — host and govern", "machine")
c.box("ordinary hardware", "chosen, pinned, replaceable — Linux LTS", "old")
c.render("harobanda-diagram-2-narrow.png")
