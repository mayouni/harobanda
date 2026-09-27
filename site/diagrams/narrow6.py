"""Diagram 6, narrow. The wide version fans one file out to four targets.
A column cannot fan, so the file is stated once and the four targets follow
it as a list -- and the invariant that holds for all four closes it.

    python site/diagrams/narrow6.py
"""
from narrowlib import Col, MUTED, NEW_LINE

c = Col(6)
c.title("ONE FILE. ONE COMMAND. FOUR KINDS OF DEVICE.")
c.gap(8)

c.kicker("ONE DECLARATION", NEW_LINE)
c.code(["DEFINE MACHINE counter AS (",
        "  PROFILE hosted,",
        "  ARCH    aarch64,",
        "  BOARD   rpi4,",
        "  KERNEL  linux,",
        ")"], accent=(1, 3))
c.note("these name the target")
c.gap(26)

c.kicker("FOUR TARGETS")
c.box("a normal PC", "x86_64 · hosted shape", "plain")
c.box("a Raspberry Pi", "aarch64 · two slots", "plain")
c.box("a tablet or phone", "touch shape · design", "old")
c.box("a sensor or MCU", "edge shape · no kernel", "plain")
c.gap(18)

c.strip("harb check · harb plan", "the same command, every target")
c.render("harobanda-diagram-6-narrow.png")
