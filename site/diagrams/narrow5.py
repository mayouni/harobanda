"""Diagram 5, narrow. The wide version reads left to right through three
stages and forks at the end. A column cannot fork, so the fork becomes two
labelled outcomes stated one after the other -- the chips carry which is
which. No person, no console, no dashboard here either.

    python site/diagrams/narrow5.py
"""
from narrowlib import Col, MUTED, INK, NEW_LINE, BRICK

c = Col(5)
c.title("TWO SLOTS, A TRIAL, AND A TIMER THAT IS NOT SOFTWARE.")
c.gap(8)

c.kicker("1 · NOW")
c.bar("slot A — running", "machine")
c.bar("slot B — empty", "old", empty=True)
c.note("two copies, always")
c.gap(20)

c.kicker("2 · THE UPDATE")
c.bar("slot A — running", "machine")
c.bar("slot B — written", "old")
c.note("not yet trusted")
c.gap(20)

c.kicker("3 · THE TRIAL", INK)
c.bar("slot A — kept", "old")
c.bar("slot B — booted", "machine", accent=True)
c.note("the watchdog is armed", INK, medium=True)
c.gap(28)

c.note("does the boot match what the file declared?", INK, medium=True)
c.gap(12)
c.chipline("IT DOES", NEW_LINE)
c.box("commit", "slot B is the one that runs, and the watchdog keeps being fed", "machine")
c.chipline("IT DOES NOT", BRICK)
c.box("reset", "the board boots slot A. the feed stops, and no one drives out.", "old")
c.render("harobanda-diagram-5-narrow.png")
