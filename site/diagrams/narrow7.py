"""Diagram 7, narrow. The wide version sets the two orders side by side so
the eye can see which thing sits at the top of each. Stacked, the order is
the reading order itself: the system first on one side, the job first on the
other. The four promises are still drawn twice, because that repetition IS
the derivation.

    python site/diagrams/narrow7.py
"""
from narrowlib import Col, MUTED, NEW_LINE, INK, ORANGE

PROMISES = ["a fixed address", "a name that never moves",
            "a record that survives", "a clean restart"]

c = Col(7)
c.title("ONE STARTS FROM THE SYSTEM. THE OTHER STARTS FROM THE JOB.")
c.gap(8)

c.kicker("A GENERAL-PURPOSE OS")
c.box("built for everyone", "your job, plus everything else you did not choose", "old")
c.arrow()
c.note("you adapt, and subtract")
c.box("what you are left with", "two gone. the rest is still there, and still yours to secure.", "old")
c.gap(26)

c.kicker("A DECLARED MACHINE", NEW_LINE)
c.note("what the job must guarantee", INK, medium=True)
for p in PROMISES:
    c.bar(p, "plain")
c.arrow(ORANGE, 3.0)
c.note("DERIVE", INK, medium=True)
c.box("the machine", None, "machine", accent=True)
for p in PROMISES:
    c.bar(p, "plain")
c.note("contains only what was declared. nothing more.")
c.render("harobanda-diagram-7-narrow.png")
