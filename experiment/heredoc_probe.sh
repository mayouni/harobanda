#!/bin/bash
# heredoc_probe.sh -- what an `&&` chain does and does not cover when one
# of its commands owns a heredoc.
#
# Paid for on 2026-09-14 by two sessions in one night. stzlib-graphics
# wrote a staging script that ASSERTED its way out before writing, and
# then committed the full working file anyway: the `git add` sat on the
# line after the heredoc's terminator, so it was never part of the chain
# the assertion was supposed to guard. The commit carried another desk's
# memo under its own subject.
#
# The rule, and the probe that establishes it:
#
#   A && cmd <<'X' && B      B is INSIDE the chain (same line as the
#   ...                      redirect) and is skipped when A fails
#   X
#   C                        C is a NEW command and runs regardless --
#                            while `$?` still shows A's failure, which is
#                            what makes it read like a chain that held
#
#   bash experiment/heredoc_probe.sh
#
# Expected: SAME LINE never prints, NEXT LINE always does, exit 1.
set -u
echo "-- the guard fails, and the command that owns the heredoc must not run"

false && python3 -c "print('OWNER: ran -- the probe itself is broken')" <<'PY' && echo "SAME LINE: ran (it should NOT)"
PY
echo "NEXT LINE: ran, and \$? is $? -- the chain's failure, on a line the chain never covered"

echo "-- and the fix: the program in a FILE, the chain over the file"
cat > "${TMPDIR:-/tmp}/heredoc_probe_inner.py" <<'PY'
print("INNER: ran")
PY
false && python3 "${TMPDIR:-/tmp}/heredoc_probe_inner.py" && echo "GUARDED: ran (it should NOT)"
echo "-- nothing above this line should say it ran except NEXT LINE"
rm -f "${TMPDIR:-/tmp}/heredoc_probe_inner.py"
