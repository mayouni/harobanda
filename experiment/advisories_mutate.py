"""Replace one exact line of a file, read and written as bytes (no newline translation): FROM and TO are in
the environment, the file is the argument. Used by advisories_probe.sh; exits 1 unless the line is there once."""
import os
import sys

p = sys.argv[1]
with open(p, "rb") as f:
    t = f.read().decode("utf-8")
frm = os.environ["FROM"] + "\n"
to = os.environ["TO"] + "\n"
if t.count(frm) != 1:
    sys.exit(1)
with open(p, "wb") as f:
    f.write(t.replace(frm, to, 1).encode("utf-8"))
