"""Diagram 1, narrow. NOTE: the wide diagram 1 was drawn by hand, outside
this repository. This is not that drawing made narrow -- it cannot be. It is
the same argument redrawn in the house style, which was itself read off that
drawing, so the two are cousins rather than strangers. If the author would
rather the phone kept the hand-drawn one, delete this and the <source> that
points at it; the wide version is the fallback and needs no change.

    python site/diagrams/narrow1.py
"""
from narrowlib import Col, MUTED, NEW_LINE

c = Col(1)
c.title("ONE FILE SPANS BOTH BANKS.")
c.gap(8)

c.kicker("WHAT YOUR SOLUTION RUNS")
c.bar("the app logic", "plain")
c.bar("local data", "plain")
c.bar("the interface", "plain")
c.bar("on-device AI", "plain")
c.arrow()
c.box("HAROBANDA", "the declared machine", "machine")
c.arrow()
c.kicker("WHAT IT JOINS", NEW_LINE)
c.box("the promises it must keep", "what the job needs", "old", accent=True)
c.box("ordinary hardware", "chosen by you, never welded shut", "old")
c.render("harobanda-diagram-1-narrow.png")
