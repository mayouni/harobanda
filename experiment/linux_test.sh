#!/bin/bash
# linux_test.sh -- every unit test, on Linux, with none skipped.
#
# `zig build test` on the Windows host skips the tests that need a kernel: what an exec'd child holds, what a
# directory's owner is once PID 1 has handed it over, what a signal is when a link stands in its place, what a
# datagram to an authority comes back as. A test that can only be run where it is not written is not run until
# somebody runs it there, and "somebody" is not a plan. This runs the WHOLE suite where the kernel is, from a
# copy of the tree, and fails if anything fails or anything is skipped: on Linux a skip is a question that was
# not asked.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/linux_test.sh
#
# Log: zig-out/wsl/linux_test.txt, this run's or absent. It builds a copy under $HOME and never touches this
# repository's tree; it boots nothing. (experiment/state_probe.sh and watchdog_probe.sh run the tests of one
# seat each against mutants; this is the breadth, and they are the depth.)
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-linux-test
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/linux_test.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  cd "$S" || exit 1
  echo "=== zig test src/main.zig, on Linux (uid $(id -u)) ==="
  "$Z" test src/main.zig > "$S/all.txt" 2>&1
  RC=$?
  grep -E 'passed|failed|FAIL|skipped|panic|error:' "$S/all.txt" | head -20
  verdict=0
  if [ "$RC" -ne 0 ]; then echo "THE SUITE FAILS ON LINUX (exit $RC)"; verdict=1; fi
  if grep -Eq '[1-9][0-9]* skipped' "$S/all.txt"; then
    echo "TESTS WERE SKIPPED ON LINUX, so a question was not asked:"
    grep -E 'SKIP|skip' "$S/all.txt" | head -10
    verdict=1
  fi
  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then echo "ALL RAN: $(grep -Eo 'All [0-9]+ tests passed' "$S/all.txt" | head -1), none skipped, on Linux"; else echo "SUITE FAILED"; fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
