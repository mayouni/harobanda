#!/bin/bash
# judge_project.sh -- the edge projection judged like every other artifact
# here: project the declared sensor and diff the generated MicroRing source
# against what is pinned beside the machine. Runs anywhere the binary does
# (git-bash on Windows, or WSL with the Linux build).
#   bash experiment/judge_project.sh [machine-name]
cd "$(dirname "$0")/.." || exit 1
NAME=${1:-cold_room_sensor}
HARB=${HARB:-}
if [ -z "$HARB" ]; then
  for c in ./zig-out/bin/harb.exe ./zig-out/bin/harb ./zig-out/cross/x86_64-linux-musl/harb; do
    [ -x "$c" ] && { HARB=$c; break; }
  done
fi
[ -n "$HARB" ] || { echo "judge_project: no harb binary (zig build)"; exit 1; }
OUT=zig-out/project/$NAME
rm -rf "$OUT"
"$HARB" project "machines/$NAME.machine" --out "$OUT" || exit 1
EXP=machines/$NAME.device.ring.expected
if [ ! -f "$EXP" ]; then
  echo "JUDGED: no expectation pinned for $NAME yet -- $EXP is missing; this projection is at $OUT/device.ring"
  exit 0
fi
if diff -u "$EXP" "$OUT/device.ring" > "$OUT/device.ring.diff"; then
  echo "JUDGED: the projection matches $EXP line for line ($(wc -l < "$OUT/device.ring") lines)"
else
  echo "JUDGED: FAIL -- the projection differs from $EXP:"; cat "$OUT/device.ring.diff"; exit 1
fi

# ... and then the CONSUMER, which is the only judge that can convict what a
# diff against our own output cannot: the first projection was accepted by
# that diff and refused by MicroRing, because its comments were written in
# the machine language's '--' and Ring's is '#' (PRJ-2).
MR=${MICRORING:-}
if [ -z "$MR" ]; then
  for c in ../microring/zig-out/bin/microring.exe ../microring/zig-out/bin/microring; do
    [ -x "$c" ] && { MR=$c; break; }
  done
fi
if [ -z "$MR" ]; then
  echo "CONSUMER: not run -- no microring binary beside this repository (set MICRORING=<path>)"
  exit 0
fi
echo "CONSUMER: $("$MR" version)"
if "$MR" run "$(pwd)/$OUT" --for 2000 > "$OUT/microring.txt" 2>&1; then
  sed 's/^/  /' "$OUT/microring.txt"
  echo "CONSUMER: MicroRing ran the projection"
else
  echo "CONSUMER: FAIL -- MicroRing refused the projection:"; sed 's/^/  /' "$OUT/microring.txt"; exit 1
fi
