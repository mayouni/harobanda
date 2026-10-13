#!/bin/bash
# priority_probe.sh -- a world is refused a priority it was never given (PRI-1).
#
# Time on the processor is the floor's to give and never a world's to take: a world that made itself real-time
# would starve every other, PID 1 among them, and the scheduling calls all name a PID, so a world that shares
# the machine's table could set the machine's own first program back. Until PRI-1 the floor's own refusals
# (SYS-1) named the clock setters and not these, so a world that ran as the machine kept the privilege and the
# call. src/confine.zig now refuses `sched_setscheduler`, `sched_setparam`, `sched_setattr`, `setpriority` and
# `ioprio_set` to every world, and two unit tests beside the code hold that:
#
#   the scheduling calls are the floor's refusals, by name     the declaration: the five are in the list and on every filter
#   a world is refused a priority it was never given           the question that decides: what does the kernel answer a world
#                                                              that tries, from behind the floor's filter? (two calls, in a child)
#
# The second can only be asked on Linux, and only where the calls would otherwise SUCCEED (as root: an
# unprivileged host is refused by the kernel's own rule, and the floor cannot be told from the privilege). This
# probe runs both on Linux, then runs them again against scratch copies of the source with ONE mutation each, and
# requires each mutant to be convicted by the test named for it: a judge that never convicts is as useless as one
# that always does (VDCT-1).
#
#   mutant 1  the five names leave the list                 -> the declaration test must fail
#   mutant 2  the filter is built as before and never      -> the act test must fail, the declaration test must NOT
#             INSTALLED                                        (the shape of SYS-1's own defect: a floor line printed
#                                                              with nothing behind it; only the kernel's answer sees it)
#   mutant 3  the names stay, the filter emits nothing for  -> the declaration test must fail too: it reads the program
#             them (nrOf answers null for every one)           and not only the list
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/priority_probe.sh
#
# Log: zig-out/wsl/priority_probe.txt, this run's or absent. Exit 0 only if the production source passes (and
# the act test RAN, not skipped) and both mutants are convicted for the right reason. It builds a copy of the
# sources under $HOME and never touches this repository's tree; it boots nothing.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-pri-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/priority_probe.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
DECL="the scheduling calls are the floor's refusals, by name (PRI-1)"
ACT="a world is refused a priority it was never given (PRI-1)"
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  cd "$S" || exit 1
  grep -q 'pub const priority_calls' src/confine.zig || { echo "src/confine.zig has no priority_calls: nothing to probe"; exit 1; }

  run() { # $1 = label ; leaves the output in $S/$1.txt and the status in RC
    "$Z" test src/main.zig --test-filter "PRI-1" > "$S/$1.txt" 2>&1
    RC=$?
    echo "--- $1: exit $RC"
    grep -E 'passed|failed|FAIL|skipped|PRI-1' "$S/$1.txt" | head -12
  }
  # the status line of one test: OK, FAIL or SKIP, as the runner prints it
  line_of() { grep -F "$1" "$2" | head -1; }
  verdict=0

  echo "=== the production source, on Linux (uid $(id -u)) ==="
  run production
  if [ "$RC" -ne 0 ]; then echo "THE PRODUCTION SOURCE FAILS ITS OWN TESTS"; verdict=1; fi
  if grep -Eq '[1-9][0-9]* skipped' "$S/production.txt"; then echo "a test was skipped, so the act question was not asked (run as root, on Linux)"; verdict=1; fi
  line_of "$ACT" "$S/production.txt" | grep -q 'OK$' || { echo "the act test did not run and pass"; verdict=1; }

  echo "=== mutant 1: the five names leave the list ==="
  cp src/confine.zig confine.zig.orig
  sed -i -e '/^    "sched_setscheduler", "sched_setparam", "sched_setattr",$/d' -e '/^    "setpriority",        "ioprio_set",$/d' src/confine.zig
  cmp -s src/confine.zig confine.zig.orig && { echo "the mutation did not apply"; verdict=1; }
  run mutant1
  if [ "$RC" -eq 0 ]; then echo "MUTANT 1 SURVIVED"; verdict=1; fi
  line_of "$DECL" "$S/mutant1.txt" | grep -q 'OK$' && { echo "MUTANT 1 NOT CONVICTED BY THE DECLARATION TEST"; verdict=1; }
  cp confine.zig.orig src/confine.zig

  echo "=== mutant 2: the filter is built as before, and never installed ==="
  # the program is complete and inspectable; the one line that hands it to the kernel is never reached
  sed -i 's/        if (prog.len > 0) {$/        if (prog.len > 1_000_000) {/' src/confine.zig
  cmp -s src/confine.zig confine.zig.orig && { echo "the mutation did not apply"; verdict=1; }
  run mutant2
  if [ "$RC" -eq 0 ]; then echo "MUTANT 2 SURVIVED"; verdict=1; fi
  if grep -q 'error:' "$S/mutant2.txt" && ! grep -qF "$ACT" "$S/mutant2.txt"; then echo "MUTANT 2 DID NOT COMPILE: that convicts nothing"; grep -m3 'error:' "$S/mutant2.txt"; verdict=1; fi
  # convicted by the ACT test, and by that one only: the declaration test must still pass, which is the point
  line_of "$ACT" "$S/mutant2.txt" | grep -q 'OK$' && { echo "MUTANT 2 NOT CONVICTED BY THE ACT TEST"; verdict=1; }
  line_of "$DECL" "$S/mutant2.txt" | grep -q 'OK$' || { echo "MUTANT 2 was convicted by the DECLARATION test, which reads the program and not the kernel: it should not see this"; verdict=1; }
  cp confine.zig.orig src/confine.zig

  echo "=== mutant 3: the names stay, and no instruction is emitted for them ==="
  # nrOf answers null for the five, so the list reads as before and the filter never tests their numbers
  sed -i '/if (!@hasField(linux.SYS, name)) return null;/a\    inline for (priority_calls) |p| if (comptime std.mem.eql(u8, p, name)) return null;' src/confine.zig
  cmp -s src/confine.zig confine.zig.orig && { echo "the mutation did not apply"; verdict=1; }
  run mutant3
  if [ "$RC" -eq 0 ]; then echo "MUTANT 3 SURVIVED"; verdict=1; fi
  if grep -q 'panic:' "$S/mutant3.txt"; then echo "MUTANT 3 made a test PANIC rather than fail: a crash is not a verdict"; verdict=1; fi
  line_of "$DECL" "$S/mutant3.txt" | grep -q 'OK$' && { echo "MUTANT 3 NOT CONVICTED BY THE DECLARATION TEST"; verdict=1; }
  line_of "$ACT" "$S/mutant3.txt" | grep -q 'OK$' && { echo "MUTANT 3 NOT CONVICTED BY THE ACT TEST"; verdict=1; }
  cp confine.zig.orig src/confine.zig

  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then
    echo "PROBED: the production source passes both tests on Linux; mutant 1 is convicted by the declaration, mutant 2 by the act alone, mutant 3 by both"
  else
    echo "PROBE FAILED"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
