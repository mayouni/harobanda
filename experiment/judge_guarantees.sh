#!/bin/bash
# judge_guarantees.sh -- the hosted profile's four standing promises,
# judged by name against a machine's own evidence (GRT-1).
#
# Twice, on purpose. A box's promises are kept by two different texts
# today, and neither can keep them all:
#
#   the board's EXPECTATION (zig-out/image/<name>/expected, derived by
#   `harb image` through the board's lens) -- the floor's three: the
#   wire up, the address declared, the partition mounted, all before any
#   world starts. It carries no slot decision, because an expectation
#   stops where the verdict begins.
#
#   the court's TRANSCRIPT (machines/<name>.expected, what the emulator
#   really printed) -- what actually happened, on an emulator with no
#   Ethernet and a watchdog it cannot arm. It keeps the promises that do
#   not need the hardware it lacks, and names the rest.
#
# The pair is the honest state of the box until OS-5 puts a card in a
# board. On that day ONE transcript keeps all four, and this script is
# what will say so.
#
#   bash experiment/judge_guarantees.sh [machine-name]
cd "$(dirname "$0")/.." || exit 1
NAME=${1:-makeen_box}
HARB=${HARB:-}
if [ -z "$HARB" ]; then
  for c in ./zig-out/bin/harb.exe ./zig-out/bin/harb ./zig-out/cross/x86_64-linux-musl/harb; do
    [ -x "$c" ] && { HARB=$c; break; }
  done
fi
[ -n "$HARB" ] || { echo "judge_guarantees: no harb binary (zig build)"; exit 1; }
M=machines/$NAME.machine
[ -f "$M" ] || { echo "judge_guarantees: no such machine: $M"; exit 1; }

OUT=zig-out/guarantees
mkdir -p "$OUT"
REPORT=$OUT/$NAME.txt
: > "$REPORT"

EXPECTED=zig-out/image/$NAME/expected
if [ -f "$EXPECTED" ]; then
  "$HARB" guarantees "$M" "$EXPECTED" >> "$REPORT"
  echo >> "$REPORT"
else
  echo "the board's expectation is not built ($EXPECTED); run experiment/os2_image.sh $NAME first" >> "$REPORT"
  echo >> "$REPORT"
fi

TRANSCRIPT=machines/$NAME.expected
if [ -f "$TRANSCRIPT" ]; then
  "$HARB" guarantees "$M" "$TRANSCRIPT" >> "$REPORT"
else
  echo "no transcript pinned for $NAME yet ($TRANSCRIPT)" >> "$REPORT"
fi

cat "$REPORT"

PIN=machines/$NAME.guarantees.expected
echo "=== judged ==="
if [ ! -f "$PIN" ]; then
  echo "JUDGED: no verdict pinned for $NAME yet -- $PIN is missing; this run's report is at $REPORT"
  exit 0
fi
if diff -u "$PIN" "$REPORT" > "$OUT/$NAME.diff"; then
  echo "JUDGED: the verdicts match $PIN line for line ($(wc -l < "$REPORT") lines)"
else
  echo "JUDGED: FAIL -- the verdicts differ from $PIN:"; cat "$OUT/$NAME.diff"; exit 1
fi
