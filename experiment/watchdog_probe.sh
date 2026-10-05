#!/bin/bash
# watchdog_probe.sh -- a world that execs holds no watchdog (WDG-1).
#
# PID 1 opens /dev/watchdog BEFORE it spawns its first world, and a world is a fork and an exec, so a
# descriptor opened without close-on-exec sits in every world's table: a world holding it can keep the
# hardware fed while PID 1 has stopped feeding it, or disarm the rollback. src/init.zig opens it
# close-on-exec (`watchdog_flags`, `openWatchdog`), and two unit tests beside the code hold that:
#
#   the watchdog's open flags are close-on-exec     the declaration, true on every host
#   a world that execs holds no watchdog descriptor the question that decides: what does a child that
#                                                   exec's from here hold? (`ls -l /proc/self/fd`)
#
# The second can only be asked on Linux; `zig build test` on the Windows host skips it. This probe runs both
# on Linux, then runs them again against scratch copies of the source with ONE mutation each, and requires
# each mutant to be convicted by the test that is named for it: a judge that never convicts is as useless
# as one that always does (VDCT-1).
#
#   mutant 1  the flag constant loses CLOEXEC      -> the declaration test must fail
#   mutant 2  the open ignores the constant        -> the exec test must fail, the declaration test must NOT
#             (the original defect: the call site never passed the flag, and nothing about it looked wrong)
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/watchdog_probe.sh
#
# Log: zig-out/wsl/watchdog_probe.txt, this run's or absent. Exit 0 only if the production source passes and
# both mutants are convicted for the right reason. It builds a copy of the sources under $HOME and never
# touches this repository's tree; it does not boot anything and never opens a real watchdog.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-wd-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/watchdog_probe.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
DECL="the watchdog's open flags are close-on-exec (WDG-1)"
EXEC="a world that execs holds no watchdog descriptor (WDG-1)"
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  cd "$S" || exit 1
  grep -q 'const watchdog_flags' src/init.zig || { echo "src/init.zig has no watchdog_flags: nothing to probe"; exit 1; }

  run() { # $1 = label ; leaves the output in $S/$1.txt and the status in RC
    "$Z" test src/main.zig --test-filter "WDG-1" > "$S/$1.txt" 2>&1
    RC=$?
    echo "--- $1: exit $RC"
    grep -E 'passed|failed|FAIL|skipped|WDG-1' "$S/$1.txt" | head -12
  }
  verdict=0

  echo "=== the production source, on Linux ==="
  run production
  if [ "$RC" -ne 0 ]; then echo "THE PRODUCTION SOURCE FAILS ITS OWN TESTS"; verdict=1; fi
  # the exec test must have RUN, not been skipped: a skip is no witness
  if grep -Eq '[1-9][0-9]* skipped' "$S/production.txt"; then echo "a test was skipped, so the exec question was not asked"; verdict=1; fi

  echo "=== mutant 1: the flag constant loses CLOEXEC ==="
  cp src/init.zig init.zig.orig
  sed -i 's/, \.CLOEXEC = true };/ };/' src/init.zig
  if cmp -s src/init.zig init.zig.orig; then echo "the mutation did not apply"; verdict=1; fi
  run mutant1
  if [ "$RC" -eq 0 ]; then echo "MUTANT 1 SURVIVED: nothing convicts a watchdog opened without the flag"; verdict=1; fi
  grep -q "$DECL" mutant1.txt || { echo "MUTANT 1 was not convicted by the declaration test"; verdict=1; }
  cp init.zig.orig src/init.zig

  echo "=== mutant 2: the open ignores the constant (the original defect) ==="
  sed -i 's/std\.os\.linux\.open(path, watchdog_flags, 0)/std.os.linux.open(path, .{ .ACCMODE = .WRONLY }, 0)/' src/init.zig
  if cmp -s src/init.zig init.zig.orig; then echo "the mutation did not apply"; verdict=1; fi
  run mutant2
  if [ "$RC" -eq 0 ]; then echo "MUTANT 2 SURVIVED: nothing convicts an open that ignores the flags"; verdict=1; fi
  # the declaration is still true here, so it must be the EXEC test that convicts
  grep -E 'FAIL|failed' mutant2.txt | grep -q "$EXEC" || { echo "MUTANT 2 was not convicted by the exec test"; verdict=1; }
  grep -E 'FAIL|failed' mutant2.txt | grep -q "$DECL" && { echo "MUTANT 2 failed the declaration test too, so the exec test proved nothing the declaration did not"; verdict=1; }
  cp init.zig.orig src/init.zig

  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then
    echo "PROBED: the production open is close-on-exec, an exec'd child holds none of it, and each mutant is convicted by the test named for it"
  else
    echo "PROBE FAILED"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
