"""Diagram 3, narrow.

The wide one (diagram3.py) draws the envelope as a box with the assistant
inside it and the internet crossed off above it. A column has no inside, so
containment becomes order and wording: what sits in the envelope is listed
under it, and the way out is drawn as an absence at the end.

Neither says "every exchange recorded" any more, and the narrow one said it
too: nothing records an exchange. The journal signs what the machine was at
each boot; what a world does is that world's own record (DOC-2).

Two of its labels were wider than their boxes, and published so: the phone
read "internet — a cloud model, a ver", cut at both edges. narrowlib now
refuses that, and the words are the wide drawing's, which fit.

    python site/diagrams/narrow3.py
"""
from narrowlib import Col, MUTED, INK, BRICK, NEW_LINE

c = Col(3)
c.title("HAROBANDA — THE GOVERNED ENVELOPE")
c.gap(8)

c.box("a person asks", "asks, and is answered", "plain")
c.arrow()
c.kicker("INSIDE THE ENVELOPE", NEW_LINE)
c.box("assistant", "Softanza AI", "machine", accent=True)
c.bar("knowledge base — on device", "plain")
c.bar("model — on device", "plain")
c.note("budgeted on memory and CPU, and confined")
c.gap(24)

c.absence("the internet", "a cloud model, a vendor")
c.note("EGRESS none — no route out", BRICK, medium=True)
c.render("harobanda-diagram-3-narrow.png")
