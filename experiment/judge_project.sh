#!/bin/bash
# judge_project.sh -- the edge projection judged like every other artifact
# here: project the declared sensor and diff the generated MicroRing source
# against what is pinned beside the machine. Runs anywhere the binary does
# (git-bash on Windows, or WSL with the Linux build).
#   bash experiment/judge_project.sh [machine-name]
cd "$(dirname "$0")/.." || exit 1
NAME=${1:-cold_room_sensor}
STZOS=${STZOS:-}
if [ -z "$STZOS" ]; then
  for c in ./zig-out/bin/stzos.exe ./zig-out/bin/stzos ./zig-out/cross/x86_64-linux-musl/stzos; do
    [ -x "$c" ] && { STZOS=$c; break; }
  done
fi
[ -n "$STZOS" ] || { echo "judge_project: no stzos binary (zig build)"; exit 1; }
OUT=zig-out/project/$NAME
rm -rf "$OUT"
"$STZOS" project "machines/$NAME.machine" --out "$OUT" || exit 1
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
