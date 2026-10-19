#!/bin/bash
# nav_probe.sh -- the site's navigation check, convicted by what it exists for (NAV-1).
#
# `harb docs --check` judges that a page's Next link goes where its section strip says
# (src/docs.zig, rule 4). A judge that was green the first time it ran is a judge to doubt, so
# this puts each defect it exists to catch back into a scratch copy of the pages, one at a time,
# and requires the check to convict it, by name. It also requires the CLEAN copy to pass: a
# judge that always convicts is as useless as one that never does (VDCT-1).
#
# The first mutant is the defect that was real: the Cloud page's Next going to the page after
# the one inserted after it (2026-10-19), found by the author's eye with every gate green.
#
# Run from anywhere with a built binary (zig build -j2); the working tree is never touched, the
# mutations happen in a copy of every Markdown and HTML file made under a temporary folder.
#
#   bash experiment/nav_probe.sh            # the host's zig-out/bin/harb.exe, or HARB=<binary>
#
# Log: zig-out/nav_probe.txt
set -u
cd "$(dirname "$0")/.." || exit 1
ROOT=$(pwd)
LOG=zig-out/nav_probe.txt
mkdir -p zig-out

H=${HARB:-}
if [ -z "$H" ]; then
  for c in zig-out/bin/harb.exe zig-out/bin/harb zig-out/cross/x86_64-linux-musl/harb; do
    if [ -x "$c" ]; then H=$c; break; fi
  done
fi
[ -n "$H" ] || { echo "no harb binary (zig build -j2)"; exit 1; }
# absolute, because every run happens in the scratch copy
H=$(cd "$(dirname "$H")" && pwd)/$(basename "$H")

S=$(mktemp -d) || exit 1
trap 'rm -rf "$S"' EXIT

fails=0

{
  echo "=== a scratch copy of every Markdown and HTML file the check reads (the working tree, as it is) ==="
  n=0
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    cp --parents "$f" "$S" && n=$((n+1))
  done < <(git ls-files -z --cached --others --exclude-standard -- '*.md' '*.html')
  echo "$n files, binary $H"

  echo "=== the control: the clean copy passes, and says what it judged ==="
  out=$(cd "$S" && "$H" docs --check 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF "7 section strips"; then
    echo "ok    clean copy: exit 0, $(printf '%s' "$out" | grep -o -E "of the site's [0-9]+ pages.*")"
  else
    echo "FAIL  clean copy: exit $rc"; printf '%s\n' "$out" | sed 's/^/        /'; fails=$((fails+1))
  fi

  # one mutant: put a defect into one file of the copy, require the check to exit 1 and say the
  # words that name it, and put the file back
  mutant() { # $1 = what the defect is, $2 = file, $3 = sed script, $4 = words the check must say
    local label=$1 f=$2 script=$3 want=$4 o c
    cp "$ROOT/$f" "$S/$f"
    sed -i -e "$script" "$S/$f"
    if cmp -s "$ROOT/$f" "$S/$f"; then
      echo "FAIL  $label: the mutation changed nothing in $f, so it proved nothing"; fails=$((fails+1)); return
    fi
    o=$(cd "$S" && "$H" docs --check 2>&1); c=$?
    cp "$ROOT/$f" "$S/$f"
    if [ "$c" -eq 1 ] && printf '%s' "$o" | grep -qF -- "$want"; then
      echo "ok    $label -- convicted: $want"
    else
      echo "FAIL  $label -- exit $c; wanted exit 1 and '$want':"; printf '%s\n' "$o" | sed 's/^/        /'; fails=$((fails+1))
    fi
  }

  echo "=== the defects the check exists to catch, one at a time ==="
  mutant "the Cloud page's Next goes to the page after the skipped one (the real defect)" \
    site/cloud.html 's|Next: <a href="realtime.html">Real time|Next: <a href="cloud-files.html">How it is written|' \
    "Next goes to cloud-files.html, and the page after this one in its strip is realtime.html (Real time)"
  mutant "a Next that does not call its page what the strip calls it" \
    site/cloud.html 's|Next: <a href="realtime.html">Real time|Next: <a href="realtime.html">Realtime|' \
    "Next says 'Realtime'"
  mutant "a Next line in a form the check does not read" \
    site/cloud.html 's|Next: <a href="realtime.html">|Next: <a class="x" href="realtime.html">|' \
    "in a form this check cannot read"
  mutant "a strip that lacks a page the rest of its section lists" \
    site/threats.html '/^ *<a href="resilience.html">Resilience<\/a>$/d' \
    "differ at entry 5: resilience.html (Resilience) here, (nothing) there"
  mutant "a strip that words one entry another way" \
    site/cloud.html 's|<a href="cloud-files.html">How it is written</a>|<a href="cloud-files.html">How it was written</a>|' \
    "differ at entry 4"
  mutant "a strip that marks no page as the current one" \
    site/realtime.html 's|<a href="realtime.html" class="here" aria-current="page">Real time</a>|<a href="realtime.html">Real time</a>|' \
    "marks 0 entries as the current page"
  mutant "a page with no strip" \
    site/build.html 's|<nav class="path"|<nav class="paths"|' \
    "site/build.html -- carries no section strip"
  mutant "a link that leaves its section from the last page of it, unnamed" \
    site/datacenters.html 's|Next: <a href="resilience.html">Resilience|Next: <a href="threats.html">Resilience|' \
    "this is the last page of its strip, so no page follows it"
  mutant "a name in the onward list that its page no longer bears out" \
    site/datacenters.html '/Next: <a href="resilience.html">Resilience/d' \
    "the page carries no Next link: the name is stale"

  # the seam the check names, run rather than only stated: a page with no Next is not judged, so a
  # Next that is deleted goes unnoticed. It is reported, and it is not part of the verdict.
  cp "$ROOT/site/secure-design.html" "$S/site/secure-design.html"
  sed -i -e '/Next: <a href="resilience.html">Resilience/d' "$S/site/secure-design.html"
  o=$(cd "$S" && "$H" docs --check 2>&1); c=$?
  cp "$ROOT/site/secure-design.html" "$S/site/secure-design.html"
  if [ "$c" -eq 0 ]; then
    echo "seam  a deleted Next (secure-design.html) is not judged: exit 0, as src/docs.zig says"
  else
    echo "seam  a deleted Next (secure-design.html) IS judged now: exit $c -- src/docs.zig's header and this probe are out of date"
  fi

  echo "=== verdict: $fails survivor(s) ==="
  if [ "$fails" -eq 0 ]; then echo "PROBED: every defect convicted, and the clean copy passes"; else echo "PROBE RED"; fi
  echo "exit $((fails > 0))"
  exit $((fails > 0))
} 2>&1 | tee "$LOG"
#
# THE VERDICT IS THE BLOCK'S, NOT tee's (VDCT-1)
exit "${PIPESTATUS[0]}"
