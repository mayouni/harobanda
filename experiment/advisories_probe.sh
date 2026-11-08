#!/bin/bash
# advisories_probe.sh -- the advisories' rules, each put back wrong and convicted by the test named for it (ONEHOUR-1).
#
# A judge that was green the first time it ran is a judge to doubt: each mutant below changes ONE rule of
# src/advisories.zig in a scratch copy of src/, and the module's tests must fail, in the test that names the rule.
# The clean copy must pass: a judge that always convicts is as useless as one that never does (VDCT-1).
#
#   bash experiment/advisories_probe.sh [m1 m2 ...]     -> zig-out/advisories_probe.txt
#
# One compile of one module per mutant, one at a time (the machine freezes under memory pressure). The mutants
# are in experiment/advisories_mutants.tsv, one a line, TAB-separated -- a rule's text holds `|`, so no other
# separator survives it: name, the exact line of the rule, what it becomes, a fragment of the test that must fail.
set -u
cd "$(dirname "$0")/.." || exit 1
LOG=zig-out/advisories_probe.txt
S=zig-out/advisories_probe.tmp
TSV=experiment/advisories_mutants.tsv
mkdir -p zig-out
rm -f "$LOG"
WANT="$*"

fails=0
{
  rm -rf "$S"; mkdir -p "$S/clean"; cp -r src "$S/clean/"
  out=$(cd "$S/clean" && zig test -j2 src/advisories.zig 2>&1); rc=$?
  if [ $rc = 0 ]; then echo "clean: passes"; else echo "clean: FAILS -- the probe proves nothing"; echo "$out" | tail -20; fails=$((fails+1)); fi
  while IFS=$'\t' read -r name from to test; do
    case "$name" in ''|'#'*) continue ;; esac
    if [ -n "$WANT" ]; then case " $WANT " in *" $name "*) ;; *) continue ;; esac; fi
    d=$S/$name; rm -rf "$d"; mkdir -p "$d"; cp -r src "$d/"
    n=$(grep -cxF -- "$from" "$d/src/advisories.zig")
    if [ "$n" != 1 ]; then echo "$name: NOT APPLIED -- the rule's text is found $n times: the probe is stale"; fails=$((fails+1)); continue; fi
    FROM="$from" TO="$to" python3 -I experiment/advisories_mutate.py "$d/src/advisories.zig" || { echo "$name: NOT APPLIED"; fails=$((fails+1)); continue; }
    out=$(cd "$d" && zig test -j2 src/advisories.zig 2>&1); rc=$?
    # the tests that failed: a numbered test line that does not end in OK
    failed=$(echo "$out" | grep -E '^[0-9]+/[0-9]+ advisories\.test\.' | grep -v '\.\.\.OK$')
    if [ $rc = 0 ]; then
      echo "$name: SURVIVED -- every test passed with the rule broken"; fails=$((fails+1))
    elif [ -z "$failed" ]; then
      echo "$name: DID NOT COMPILE -- a mutant must compile to test anything"; echo "$out" | grep "error:" | head -3; fails=$((fails+1))
    elif echo "$failed" | grep -qF -- "$test"; then
      echo "$name: convicted by '$test'"
    else
      echo "$name: convicted, but NOT by '$test':"; echo "$failed" | head -5; fails=$((fails+1))
    fi
  done < "$TSV"
  rm -rf "$S"
  echo "probe: $fails finding(s)"
} 2>&1 | tee "$LOG"
[ "${PIPESTATUS[0]}" = 0 ] || exit 1
grep -q "^probe: 0 finding(s)$" "$LOG"
