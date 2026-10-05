#!/bin/bash
# time_scene_probe.sh -- the scene that judges the time seat is itself judged: a bug put back is a scene that fails on the line that names it (TIME-1).
#
# experiment/os10_time.sh boots two machines on one wire and pins what they say. It is the only judge of what PID 1
# DOES with a time -- the responder it forks, the question it asks after its record is written, the answer it keeps --
# and a pin that has never been seen to fail on the bug it exists for is a claim and not evidence (VDCT-1). The unit
# tests and the grammars' courts are probed one mutation at a time by experiment/time_probe.sh; this probes the boot.
# It puts back, one at a time and in a scratch copy of the sources, five bugs the seat had or an independent review
# named, builds the machine from the mutated source, runs the WHOLE scene, and requires that the scene FAIL, and that
# its diff against the pin carry a line of the section the bug changes:
#
#   s1  the witness fails (exit 1) on a kept statement that does not verify   a line of the `cut:` boot
#       -- a witness that gates the trial's commit must not fail on what is advisory
#   s2  the asker asks about the entry's public `hash=`, not its whole line   a line of the `dated:` audit
#       -- anybody could compute the next one and hold a genuine signature that dates an entry not yet written
#   s3  the responder keeps the clock it read at its first question           the `clock:` line says no
#       -- a clock is read at every question
#   s4  an authority whose clock will not answer says that it answers         a line of the `deadclock:` boot
#       -- a promise the machine announces and cannot keep (NS-1)
#   s5  the asker does not check the signature of the answer it keeps         a line of `till6:` or `disk:`
#       -- an impostor with a good signature of its own is refused at the door
#
# It first runs the scene on the UNMUTATED copy, which must match its pin: a mutant convicted by a scene that was
# red anyway is no conviction. What it does not reach: the same bugs one level down are the unit tests' and the
# courts' (experiment/time_probe.sh), and what a mutant that never reaches the boot is (a rule of the grammar) is
# the court's.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/time_scene_probe.sh [s1 s2 s3 s4 s5]
#
# With no argument it runs the baseline and all five, which is the pre-commit gate for the seat and takes about the
# time of six scenes; with names it runs the baseline and those, and PRINTS the ones it skipped. One heavy job
# at a time: it builds and boots on this machine, and nothing else may be running (the machine stops dead under memory
# pressure). It uses $HOME/harb-time-scene-probe and the kernel caches under $HOME, never this repository's zig-out,
# so it may be run beside nothing but must not be run beside experiment/os10_time.sh (one wire, one port).
#
# Log: zig-out/wsl/time_scene_probe.txt, this run's or absent. Exit 0 only if the unmutated scene matches its pin
# and every mutant that was run is convicted by its line.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-time-scene-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/time_scene_probe.txt
ALL="s1 s2 s3 s4 s5"
WANT=${*:-$ALL}
for w in $WANT; do case " $ALL " in *" $w "*) ;; *) echo "usage: time_scene_probe.sh [$ALL]"; exit 2 ;; esac; done
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  # the kernel's tarball and its pin are not published (gitignored, 142 MB): the copy borrows them, read only
  [ -f "$R/vendor/linux/PIN.txt" ] || { echo "no vendor/linux/PIN.txt in this repository: the image script cannot find the kernel's pin"; exit 1; }
  mkdir -p "$S/vendor" && ln -s "$R/vendor/linux" "$S/vendor/linux" || { echo "could not borrow vendor/linux"; exit 1; }
  cd "$S" || exit 1
  grep -q 'pub fn respond' src/timeserve.zig || { echo "src/timeserve.zig has no respond: nothing to probe"; exit 1; }
  verdict=0

  build() { # the machine the scene boots: the one binary, cross-built for Linux
    local t0=$SECONDS
    "$Z" build cross -j2 > "$S/build.txt" 2>&1
    local rc=$?
    echo "    built in $((SECONDS - t0)) s"
    return $rc
  }
  scene() { # leaves the scene's verdict in RC, its log in zig-out/wsl/time.txt and its diff in zig-out/wsl/time.diff
    local t0=$SECONDS
    rm -f zig-out/wsl/time.txt zig-out/wsl/time.diff
    bash experiment/os10_time.sh > "$S/scene.out" 2>&1
    RC=$?
    echo "    the scene ran $((SECONDS - t0)) s, exit $RC: $(grep -m1 '^JUDGED' zig-out/wsl/time.txt 2>/dev/null | cut -c1-110)"
  }

  echo "=== the production source: its own scene, built and run in the copy ==="
  if ! build; then echo "THE PRODUCTION SOURCE DOES NOT BUILD"; grep -m5 'error:' "$S/build.txt"; echo "exit 1"; exit 1; fi
  scene
  if [ "$RC" -ne 0 ] || ! grep -q '^JUDGED: the arc matches' zig-out/wsl/time.txt 2>/dev/null; then
    echo "THE PRODUCTION SOURCE FAILS ITS OWN SCENE IN THE COPY: no mutant can be convicted by a scene that is red already"
    tail -5 "$S/scene.out"; verdict=1
  fi

  # one bug put back: $1 = label, $2 = the file, $3 = the sed program, $4 = an extended regular expression that
  # one line of the scene's diff against its pin must match. The mutant must differ from the source, compile, make
  # the scene FAIL, and be convicted by THAT section -- not merely by a scene that stopped for another reason
  smutant() {
    local label=${1%%:*}
    case " $WANT " in *" $label "*) ;; *) echo "=== $1 -- SKIPPED (not named on the command line) ==="; return ;; esac
    echo "=== $1 ==="
    cp "$2" "$2.orig"
    sed -i "$3" "$2"
    if cmp -s "$2" "$2.orig"; then echo "the mutation did not apply"; verdict=1; rm -f "$2.orig"; return; fi
    if ! build; then
      echo "MUTANT DID NOT COMPILE ($1): that convicts nothing"; grep -m3 'error:' "$S/build.txt"; verdict=1
    else
      scene
      if [ "$RC" -eq 0 ]; then
        echo "MUTANT SURVIVED ($1): the scene passed with the bug put back"; verdict=1
      elif grep -Eq "$4" zig-out/wsl/time.diff 2> /dev/null; then
        echo "convicted: the scene fails, and its diff says so:"; grep -E -m2 "$4" zig-out/wsl/time.diff | cut -c1-150
      else
        echo "MUTANT NOT CONVICTED BY ITS LINE ($1: wanted a diff line matching /$4/)"
        grep -m5 '^[-+]' zig-out/wsl/time.diff 2> /dev/null | cut -c1-150; tail -3 "$S/scene.out"; verdict=1
      fi
    fi
    cp "$2.orig" "$2"; rm -f "$2.orig"
  }

  TS=src/timeserve.zig; IN=src/init.zig; MN=src/main.zig

  smutant "s1: the witness fails on a kept statement that does not verify" $MN \
    's/_ = try timeaudit\.read(arena, out, key, kept, text);/if (!(try timeaudit.read(arena, out, key, kept, text)).clean()) return 1;/' \
    '^[-+]cut: '

  # (the line stays used: an unused constant is a compile error, which convicts nothing)
  smutant "s2: the asker asks about the entry's public hash" $IN \
    's/const entry = timeattest\.entryDigest(last);/_ = last; const entry = check.last_hash;/' \
    '^[-+]dated: '

  smutant "s3: the responder keeps the clock it read at its first question" $TS \
    "s/const t = readRtc(clock) catch return null;/const t = cachedRtc(clock) catch return null;/
\$a\\
var cached_rtc: ?i64 = null;\\
fn cachedRtc(clock: []const u8) ClockError!i64 {\\
    if (cached_rtc) |c| return c;\\
    const t = try readRtc(clock);\\
    cached_rtc = t;\\
    return t;\\
}" \
    '^\+clock: .*: no$'

  # (the failure is said and then ignored: the block yields a time instead of leaving the loop, so it compiles)
  smutant "s4: an authority whose clock will not answer says it answers" $IN \
    "s/_ = timeserve\.readRtc(clock) catch |e| {/_ = timeserve.readRtc(clock) catch |e| blk: {/
/this machine will not sign a time it cannot read/{n;s/continue;/break :blk 0;/}" \
    '^[-+]deadclock: '

  # (the key stays used, or an unused parameter is a compile error and the mutant convicts nothing)
  smutant "s5: the asker does not check the signature of the answer it keeps" $TS \
    's/switch (timeattest\.verify(datagram, key)) {/switch (@as(timeattest.Verdict, if (timeattest.parse(datagram) != null and key.bytes.len > 0) .ok else .malformed)) {/' \
    '^[-+](till6|disk): '

  SKIPPED=""
  for w in $ALL; do case " $WANT " in *" $w "*) ;; *) SKIPPED="$SKIPPED $w" ;; esac; done
  [ -n "$SKIPPED" ] && echo "skipped by name:$SKIPPED"

  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then
    echo "PROBED: the production scene matches its pin, and every bug that was put back ($WANT) fails the scene on the line that names it"
  else
    echo "PROBE FAILED"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
