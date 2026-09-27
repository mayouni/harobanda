"""Diagram 9, narrow. The wide version draws the return as an arc sweeping
back under the four beats, and the arc is the whole point. A column cannot
sweep, so the closure is the last item and carries the orange rule -- it is
still the heaviest thing in the picture.

    python site/diagrams/narrow9.py
"""
from narrowlib import Col

c = Col(9)
c.title("THE LAST STEP RETURNS TO THE FIRST.")
c.gap(8)

c.box("declare", "one file", "plain")
c.box("judge", "harb check", "plain")
c.box("plan", "harb plan", "plain")
c.box("boot", "in QEMU", "plain")
c.gap(10)
c.box("and back to declare",
      "the boot is judged against the file, and a change is a new file, judged again",
      "plain", accent=True)
c.render("harobanda-diagram-9-narrow.png")
