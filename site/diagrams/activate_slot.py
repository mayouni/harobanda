"""Uncomment a DIAGRAM SLOT once its image has landed.

    python site/diagrams/activate_slot.py 5

Refuses if the image the slot names is not on disk, because a slot that
points at nothing is a broken image on a live page.
"""
import sys, re, pathlib

site = pathlib.Path(__file__).resolve().parent.parent
n = int(sys.argv[1])

pat = re.compile(
    r'[ \t]*<!-- DIAGRAM SLOT %d —[^\n]*\n([ \t]*<img class="diagram-img"[^\n]*>)\n[ \t]*-->\n' % n)

for fp in sorted(site.glob("*.html")):
    s = fp.read_text(encoding="utf-8")
    m = pat.search(s)
    if not m:
        continue
    img = m.group(1)
    src = re.search(r'src="([^"]+)"', img).group(1)
    if not (site / src).exists():
        sys.exit("REFUSED: %s does not exist yet" % src)
    fp.write_text(s[:m.start()] + img + "\n" + s[m.end():], encoding="utf-8", newline="\n")
    print("slot %d activated in %s  (%s)" % (n, fp.name, src))
    print("now set its row in site/DIAGRAMS.md to live")
    break
else:
    sys.exit("no commented slot %d found" % n)
