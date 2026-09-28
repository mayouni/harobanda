"""Diagram 10, narrow. Two topologies cannot sit side by side in a column,
so they follow one another -- and they must still not read as one product in
two skins. What keeps them apart is that each keeps its own shape: one box
with things around it and a way out that is crossed; a hub with two bases and
the agents held inside. Both machine boxes carry the same orange rule, which
is the title: two places, one floor.

The statuses stay as honest as the page's own list: the APP is delivered, and
the box is the first Harobanda target.

    python site/diagrams/narrow10.py
"""
from narrowlib import Col, MUTED, NEW_LINE

c = Col(10)
c.title("TWO PLACES, ONE FLOOR.")
c.gap(8)

c.kicker("COUSBOX · A RESTAURANT IN LYON")
c.box("the box", "the counter", "machine", accent=True)
c.bar("a phone", "plain")
c.bar("the kitchen", "plain")
c.bar("the till", "plain")
c.absence("the internet — crossed")
c.note("the service does not stop when the link does")
c.chipline("app delivered", NEW_LINE)
c.note("its box is the first Harobanda target")
c.gap(28)

c.kicker("DIKO · AN NGO IN NIGER")
c.box("the hub", "Niamey", "machine", accent=True)
c.bar("Gothèye", "plain")
c.bar("Diffa", "plain")
c.box("the agents", "confined by the kernel to what their files grant", "plain")
c.chipline("engagement won", MUTED)
c.note("now entering development")
c.render("harobanda-diagram-10-narrow.png")
