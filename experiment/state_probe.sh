#!/bin/bash
# state_probe.sh -- a world's own directory is made, handed over, read back, and no link is followed (OWN-1).
#
# `STATE` on a SERVICE names directories PID 1 makes for the world's declared identity before the world
# exists, and a world's signal (READY) is read as root in a directory the world may own. The acts are in
# src/init.zig, and two unit tests beside the code ask the questions that decide, of a kernel:
#
#   a world's own directory is made, handed over and read back, and no link is followed (OWN-1)
#       `ownDir`: walk from the root with no link followed, every directory above the last the machine's,
#       make, give to the identity, close, read back as the kernel says it
#   a signal an earlier boot left is cleared, a link is not followed, and only a regular file is a signal (OWN-1)
#       `signalStat`, `removeStaleSignal`: what PID 1 reads at a READY path, and what is left after it clears one
#
# They can only be asked on Linux; `zig build test` on the Windows host skips them. This probe runs them on
# Linux, then again against scratch copies of the source with ONE mutation each, and requires every mutant to
# be convicted by the test named for it: a judge that never convicts is as useless as one that always does
# (VDCT-1).
#
#   mutant 1  a link on the way is followed                      -> the directory test
#   mutant 2  the directory is not closed (no chmod)             -> the directory test, by the readback
#   mutant 3  not closed, and the mode is not read back          -> the directory test, by its own assertion
#   mutant 4  a refused mount is not remembered                  -> the directory test
#   mutant 5  a directory above the last is not asked about      -> the directory test
#   mutant 6  the directory is not given away (no chown)         -> the directory test, by the readback (root only)
#   mutant 7  not given away, and the owner is not read back     -> the directory test, by its own assertion (root only)
#   mutant 8  a stale signal is not cleared                      -> the signal test
#   mutant 9  a link is followed when a signal is read           -> the signal test
#   mutant 10 a directory counts as a signal                     -> the signal test
#
# Mutants 6 and 7 need ROOT: giving a directory to the identity that already owns it asks for no privilege, so
# only a root run hands over to a DIFFERENT owner (2000), which is what a chown that did nothing cannot fake.
# The probe says so when it is not root and does not count those two as survivors. What it cannot show on any
# host is a boot's own handover on a disk: experiment/os9_cloud.sh reads that off the disk the boot leaves.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/state_probe.sh
#
# Log: zig-out/wsl/state_probe.txt, this run's or absent. Exit 0 only if the production source passes (and the
# tests RAN, not skipped) and every mutant that can be run is convicted by the test named for it. It builds a
# copy of the sources under $HOME and never touches this repository's tree; it boots nothing.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-own-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/state_probe.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
OWN="a world's own directory is made, handed over and read back, and no link is followed (OWN-1)"
SIG="a signal an earlier boot left is cleared, a link is not followed, and only a regular file is a signal (OWN-1)"
if [ "$(id -u)" -eq 0 ]; then ROOT=yes; else ROOT=no; fi
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  cd "$S" || exit 1
  grep -q 'fn ownDir' src/init.zig || { echo "src/init.zig has no ownDir: nothing to probe"; exit 1; }

  run() { # $1 = label ; leaves the output in $S/$1.txt and the status in RC
    "$Z" test src/main.zig --test-filter "OWN-1" > "$S/$1.txt" 2>&1
    RC=$?
    echo "--- $1: exit $RC"
    grep -E 'passed|failed|FAIL|skipped|OWN-1' "$S/$1.txt" | head -12
  }
  verdict=0
  cp src/init.zig init.zig.orig

  # one mutation: $1 = label, $2 = the sed program, $3 = file label, $4 = the test that must convict it.
  # The mutant must differ from the source, fail, compile, and be convicted by THAT test (its status line
  # is not OK) -- not merely by something that stopped compiling.
  mutant() {
    echo "=== $1 ==="
    sed -i "$2" src/init.zig
    if cmp -s src/init.zig init.zig.orig; then echo "the mutation did not apply"; verdict=1; fi
    run "$3"
    if [ "$RC" -eq 0 ]; then echo "MUTANT SURVIVED ($1)"; verdict=1; fi
    if grep -q 'error:' "$S/$3.txt" && ! grep -qF "$4" "$S/$3.txt"; then
      echo "MUTANT DID NOT COMPILE ($1): that convicts nothing"; grep -m3 'error:' "$S/$3.txt"; verdict=1
    fi
    # the test's name and a failure's message share the line the runner prints, and its FAIL is on the next
    # one, so the name is what is asked for: convicted means the line of THAT test does not end in OK
    grep -F "$4" "$S/$3.txt" | grep -vq '\.\.\.OK$' || { echo "MUTANT NOT CONVICTED BY ITS TEST ($1)"; verdict=1; }
    cp init.zig.orig src/init.zig
  }

  echo "=== the production source, on Linux (root: $ROOT) ==="
  run production
  if [ "$RC" -ne 0 ]; then echo "THE PRODUCTION SOURCE FAILS ITS OWN TESTS"; verdict=1; fi
  # the tests must have RUN, not been skipped: a skip is no witness
  if grep -Eq '[1-9][0-9]* skipped' "$S/production.txt"; then echo "a test was skipped, so the question was not asked"; verdict=1; fi
  grep -F "$OWN" "$S/production.txt" | grep -q '\.\.\.OK$' || { echo "the directory test did not run and pass"; verdict=1; }
  grep -F "$SIG" "$S/production.txt" | grep -q '\.\.\.OK$' || { echo "the signal test did not run and pass"; verdict=1; }

  mutant "mutant 1: a link on the way is followed" 's/\.no_follow = true, //g' mutant1 "$OWN"
  mutant "mutant 2: the directory is not closed" '/try kernel(std\.os\.linux\.fchmod(fd, 0o700));/d' mutant2 "$OWN"
  mutant "mutant 3: not closed, and the mode is not read back" '/try kernel(std\.os\.linux\.fchmod(fd, 0o700));/d;/error\.ModeNotKept;/d' mutant3 "$OWN"
  # (the condition is changed and the line kept: an unused parameter is a compile error, which convicts nothing)
  mutant "mutant 4: a refused mount is not remembered" 's/if (machine\.within(dir, at)) return error\.MountRefused;/if (machine.within(dir, at) and false) return error.MountRefused;/' mutant4 "$OWN"
  mutant "mutant 5: a directory above the last is not asked about" 's/if (parts\.peek() != null) theMachinesOwn/if (parts.peek() != null and false) theMachinesOwn/' mutant5 "$OWN"
  if [ "$ROOT" = yes ]; then
    mutant "mutant 6: the directory is not given away" '/try kernel(std\.os\.linux\.fchown(fd, u\.uid, u\.gid));/d' mutant6 "$OWN"
    # (the readback is replaced by a use of the parameter, not deleted: an unused parameter is a compile error)
    mutant "mutant 7: not given away, and the owner is not read back" '/try kernel(std\.os\.linux\.fchown(fd, u\.uid, u\.gid));/d;s/if (st\.uid != u\.uid or st\.gid != u\.gid) return error\.NotOwnedAsDeclared;/_ = u;/' mutant7 "$OWN"
  else
    echo "=== mutants 6 and 7 are not run: they need root (a hand-over to a DIFFERENT owner); this run is uid $(id -u) ==="
  fi
  # (access for unlink: the file is asked about and left where it is)
  mutant "mutant 8: a stale signal is not cleared" 's/std\.os\.linux\.unlink(&p)/std.os.linux.access(\&p, 0)/' mutant8 "$SIG"
  mutant "mutant 9: a link is followed when a signal is read" 's/std\.os\.linux\.AT\.SYMLINK_NOFOLLOW/0/' mutant9 "$SIG"
  mutant "mutant 10: a directory counts as a signal" '/if (!std\.os\.linux\.S\.ISREG(st\.mode)) return null;/d' mutant10 "$SIG"

  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then
    echo "PROBED: a directory is made and handed over as declared, no link is followed, the ways down are the machine's, a refused mount is not built on, a signal is a regular file and a stale one is cleared, and each mutant that was run is convicted by the test named for it"
  else
    echo "PROBE FAILED"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
