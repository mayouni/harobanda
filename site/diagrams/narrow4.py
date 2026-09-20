"""Diagram 4, narrow. The wide version sets the two systems side by side so
the crowding of one answers the spareness of the other. A phone has no room
for side by side, so the same contrast is made by SEQUENCE: six bands, then
two and an absence, then the band they both stand on.

    python site/diagrams/narrow4.py
"""
from narrowlib import Col, MUTED, NEW_LINE

c = Col(4)
c.title("THE KERNEL IS THE SAME. EVERYTHING ABOVE IT IS NOT.")
c.gap(10)

c.kicker("AN ORDINARY DISTRIBUTION", MUTED)
for s in ["a shell", "a package manager", "a service manager",
          "mutable configuration", "a login, an account", "a store"]:
    c.bar(s, "old")
c.note("not the kernel's doing")
c.gap(26)

c.kicker("HAROBANDA", NEW_LINE)
c.box("the declaration", "every line says why", "machine", accent=True)
c.box("the court", "judged before it runs", "machine")
c.absence("and nothing else")
c.note("declare, judge, govern", NEW_LINE, medium=True)
c.gap(26)

c.strip("Linux LTS", "the same kernel, the same drivers, the same hardening")
c.render("harobanda-diagram-4-narrow.png")
