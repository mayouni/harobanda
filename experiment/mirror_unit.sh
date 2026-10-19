#!/bin/bash
# mirror_unit.sh -- the mirror seat's own tests, on Linux, in seconds (MIR-1).
#
# The seat's tests that need a kernel -- the walk that follows no link, the files streamed over a socket between a
# source and a puller, the swap that a power cut can interrupt at any step -- cannot run on the Windows host
# (`zig build test` skips them there). `experiment/linux_test.sh` runs the whole suite and takes minutes; this runs
# the three files of the seat and nothing else, which is the inner loop (PX): edit, run, read.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/mirror_unit.sh
#
# Log: zig-out/wsl/mirror_unit.txt, this run's or absent. Exit 0 only if every test of both files ran and none was
# skipped: on Linux a skip is a question that was not asked. It copies src/ under $HOME and never touches this
# repository's tree; it boots nothing. The mutants of the seat are experiment/mirror_probe.sh's.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-mirror-unit
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/mirror_unit.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  cp -r "$R/src" "$S/src" || { echo "copy failed"; exit 1; }
  cd "$S" || exit 1
  verdict=0
  for f in src/mirror.zig src/mirrorserve.zig src/mirroraudit.zig; do
    echo "=== zig test $f, on Linux (uid $(id -u)) ==="
    "$Z" test "$f" > "$S/out.txt" 2>&1
    rc=$?
    grep -E 'passed|failed|FAIL|skipped|panic|error:|MIR-1' "$S/out.txt" | head -40
    if [ "$rc" -ne 0 ]; then echo "FAILS ON LINUX (exit $rc): $f"; verdict=1; fi
    if grep -Eq '[1-9][0-9]* skipped' "$S/out.txt"; then echo "TESTS WERE SKIPPED ON LINUX: $f"; verdict=1; fi
  done
  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then echo "ALL RAN, none skipped, on Linux"; else echo "FAILED"; fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
