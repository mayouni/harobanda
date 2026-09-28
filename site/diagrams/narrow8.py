"""Diagram 8, narrow. The wide version puts the cloud BESIDE the fleet, at
the same altitude, because that is the misreading it exists to prevent. A
column has no beside, so the words have to carry it: the cloud is not drawn
under the boxes as something they hang from, it is drawn after them as
another thing at the same level, and it says so.

    python site/diagrams/narrow8.py
"""
from narrowlib import Col, MUTED, NEW_LINE

c = Col(8)
c.title("A FLEET IS A SET OF DECLARATIONS.")
c.gap(8)

c.kicker("ONE DECLARATION", NEW_LINE)
c.box("one declaration", "+ a pinned digest", "machine")
c.arrow()
c.bar("box 1 · KEY1", "plain")
c.bar("box 2 · KEY2", "plain")
c.bar("box 3 · KEY3", "plain")
c.gap(26)

c.kicker("AND THE CLOUD YOU RUN")
c.box("your cloud", "a peer, not a parent. not above them, not under them.", "old")
c.gap(18)

c.strip("no snowflakes", "every box derived from one file")
c.strip("evidence", "checked by anyone who never held the secret")
c.render("harobanda-diagram-8-narrow.png")
