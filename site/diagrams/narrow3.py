"""Diagram 3, narrow. NOTE: a redraw of the hand-authored wide diagram 3, in
the house style. See narrow1.py for why, and for how to drop it.

The wide one draws the envelope as a box with the assistant inside it and
the internet crossed off to one side. A column has no inside, so containment
becomes order and wording: what sits in the envelope is listed under it, and
the way out is drawn as an absence at the end.

    python site/diagrams/narrow3.py
"""
from narrowlib import Col, MUTED, INK, BRICK, NEW_LINE

c = Col(3)
c.title("HAROBANDA — THE GOVERNED ENVELOPE")
c.gap(8)

c.box("a person asks", "asks, and is answered", "plain")
c.arrow()
c.kicker("INSIDE THE ENVELOPE", NEW_LINE)
c.box("the assistant", "Softanza AI", "machine", accent=True)
c.bar("the knowledge base — on device", "plain")
c.bar("the model — on device", "plain")
c.note("budgeted on memory and CPU, confined, and every exchange recorded")
c.gap(24)

c.absence("the internet — a cloud model, a vendor")
c.note("EGRESS none — no route out", BRICK, medium=True)
c.render("harobanda-diagram-3-narrow.png")
