#!/bin/bash
# safe_probe.sh -- the hosted half of the safe state, probed (SAFE-1): the two reserved machines must match
# their pins, and four things the seat refuses must each be refused for the reason the seat names.
#
# machines/qemu_tick.machine is the judge of the kernel's WORD on an overrun arriving: its reserved neighbour
# listens for SIGXCPU, says so once, and only then marks ready, so a machine whose kernel never sends the word
# never says ready. machines/qemu_deadline.machine is the judge of WHERE the reservation is taken: `second` runs
# behind a stand-in process (it declares no `process`) and still reads back SCHED_DEADLINE. A pin that has only
# ever been seen to match is a claim (VDCT-1), so this runs both boots on the production source first, then
# puts one thing wrong at a time, in a scratch copy of the source, and requires each to be caught by the line
# that names it:
#
#   m1  the reservation carries no SCHED_FLAG_DL_OVERRUN                    the seat's Linux unit tests: the word never
#       (the flag dropped from attrOf)                                      reaches a listening world, and a deaf one is
#                                                                           not ended -- two tests red, run as root
#   m2  the word is NOT held before the reservation is taken               qemu_deadline: `control` is ended by SIGXCPU
#       (holdOverruns skipped in confine.apply)                             during its own loading, and the transcript
#                                                                           says `killed by signal 24 -- SIGXCPU`
#   m3  the reservation is taken BEFORE the stand-in forks the world        qemu_deadline: `second` reads back `no
#       (the order before SAFE-1)                                           reservation`, and the pin refuses the boot
#   m4  the timed kernel is derived WITHOUT posix timers                    qemu_tick: PID 1 reads it back before any
#       (CONFIG_POSIX_TIMERS dropped from the fragment: the first kernel    reservation -- `keeps no posix timers` --
#       this seat booted, found by the neighbour marking nothing for 180 s)  and starts no reserved world
#
# Each mutant must differ from the source, compile, and FAIL its judge on the named line -- never merely fail.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/safe_probe.sh [m1 m2 m3 m4]
#
# With no argument it runs the production boots and all four, about five boots, one kernel build (m4's
# fragment differs) and four cross builds; with names it runs the production boots and those, and PRINTS the
# ones it skipped. One heavy job at a time: it builds and boots on this machine. It uses $HOME/harb-safe-probe
# and the kernel cache under $HOME, never this repository's zig-out.
#
# Log: zig-out/wsl/safe_probe.txt, this run's or absent. Exit 0 only if both production boots match their pins
# and every probe that was run is convicted by its line.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-safe-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/safe_probe.txt
ALL="m1 m2 m3 m4"
WANT=${*:-$ALL}
for w in $WANT; do case " $ALL " in *" $w "*) ;; *) echo "usage: safe_probe.sh [$ALL]"; exit 2 ;; esac; done
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
(
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  [ -f "$R/vendor/linux/PIN.txt" ] || { echo "no vendor/linux/PIN.txt in this repository: the image script cannot find the kernel's pin"; exit 1; }
  mkdir -p "$S/vendor" && ln -s "$R/vendor/linux" "$S/vendor/linux" || { echo "could not borrow vendor/linux"; exit 1; }
  cd "$S" || exit 1
  for m in qemu_tick qemu_deadline; do [ -f "machines/$m.expected" ] || { echo "no pin for $m: nothing to probe against"; exit 1; }; done
  grep -q 'fn holdOverruns' src/reserve.zig || { echo "src/reserve.zig has no holdOverruns: nothing to probe"; exit 1; }
  verdict=0

  build() { # the machine the boot runs: the one binary, cross-built for Linux, in the copy
    local t0=$SECONDS
    "$Z" build cross -j2 > "$S/build.txt" 2>&1
    local rc=$?
    echo "    built in $((SECONDS - t0)) s"
    return $rc
  }
  boot() { # $1 = the machine; leaves its verdict in RC, its log in $IMG, its transcript under $OUT
    local m=$1 t0=$SECONDS
    OUT=zig-out/image/$m; IMG=zig-out/wsl/image_$m.txt
    rm -f "$IMG"
    bash experiment/os2_image.sh "$m" > "$S/boot.out" 2>&1
    RC=$?
    echo "    $m: the boot ran $((SECONDS - t0)) s, exit $RC: $(grep -m1 '^JUDGED' "$IMG" 2>/dev/null | cut -c1-110)"
  }
  wants() { case " $WANT " in *" $1 "*) return 0 ;; *) echo "=== $1 $2 -- SKIPPED (not named on the command line) ==="; return 1 ;; esac; }
  transcript() { tr -d '\r' < "$1"; }
  units() { # the seat's own unit tests, on this kernel, as whoever runs this ($1 = a label for the log)
    "$Z" test src/reserve.zig > "$S/units_$1.txt" 2>&1
    local rc=$?
    echo "    reserve.zig tests: exit $rc -- $(grep -E 'passed|failed' "$S/units_$1.txt" | tail -1)"
    return $rc
  }

  echo "=== the production source: both boots, built and run in the copy, against their pins (uid $(id -u)) ==="
  if ! build; then echo "THE PRODUCTION SOURCE DOES NOT BUILD"; grep -m5 'error:' "$S/build.txt"; echo "exit 1"; exit 1; fi
  for m in qemu_tick qemu_deadline; do
    boot "$m"
    if [ "$RC" -ne 0 ] || ! grep -q '^JUDGED: the boot transcript matches' "$IMG" 2>/dev/null; then
      echo "THE PRODUCTION SOURCE FAILS ITS OWN BOOT OF $m IN THE COPY: no probe can be convicted by a boot that is red already"
      tail -5 "$S/boot.out"; verdict=1
    fi
  done
  echo "=== the production source: the seat's unit tests on this kernel ==="
  if ! units prod; then echo "THE SEAT'S TESTS FAIL ON THE PRODUCTION SOURCE"; grep -m5 -E 'FAIL|error' "$S/units_prod.txt"; verdict=1; fi
  if grep -Eq '[1-9][0-9]* skipped' "$S/units_prod.txt"; then echo "    (some of the seat's tests were SKIPPED here: not root, or no reservation possible -- m1 cannot convict)"; fi

  # one thing put wrong in the source: $1 = label, $2 = the file, $3 = the sed program, $4 = the machine to
  # boot (or `units`), $5 = the line the transcript must carry (or, for units, the test that must fail),
  # $6 = a description. The mutant must differ, compile, FAIL its judge, and carry $5.
  mutant() {
    local label=$1 file=$2 prog=$3 judge=$4 line=$5 what=$6
    wants "$label" "$what" || return
    echo "=== $label: $what ==="
    cp "$file" "$file.orig"
    sed -i "$prog" "$file"
    if cmp -s "$file" "$file.orig"; then echo "the mutation did not apply"; verdict=1; cp "$file.orig" "$file"; return; fi
    if [ "$judge" = units ]; then
      if units "$label"; then echo "MUTANT SURVIVED ($label): the seat's tests passed with the thing put wrong"; verdict=1
      elif grep -q -- "$line" "$S/units_$label.txt"; then
        echo "convicted: the tests fail, and the one that names it is among them:"; grep -m1 -- "$line" "$S/units_$label.txt" | cut -c1-160
      else echo "MUTANT NOT CONVICTED BY ITS TEST ($label: wanted '$line')"; grep -E 'FAIL|error' "$S/units_$label.txt" | head -6; verdict=1; fi
    elif ! build; then
      echo "MUTANT DID NOT COMPILE ($label): that convicts nothing"; grep -m3 'error:' "$S/build.txt"; verdict=1
    else
      boot "$judge"
      if [ "$RC" -eq 0 ]; then echo "MUTANT SURVIVED ($label): the boot matched its pin with the thing put wrong"; verdict=1
      elif transcript "$OUT/transcript.txt" | grep -q -- "$line"; then
        echo "convicted: the judge refuses the boot, and the transcript says why:"; transcript "$OUT/transcript.txt" | grep -m1 -- "$line" | cut -c1-170
      else
        echo "MUTANT NOT CONVICTED BY ITS LINE ($label: wanted '$line')"; transcript "$OUT/transcript.txt" | grep 'boot: \|reserved: \|spin: ' | head -14 | cut -c1-150; verdict=1
      fi
    fi
    cp "$file.orig" "$file"; rm -f "$file.orig"
  }

  RS=src/reserve.zig; CF=src/confine.zig; IM=src/image.zig
  mutant m1 "$RS" 's|^        .flags = SCHED_FLAG_RESET_ON_FORK \| SCHED_FLAG_DL_OVERRUN,|        .flags = SCHED_FLAG_RESET_ON_FORK,|' \
    units "the kernel's word on an overrun reaches a world that listens" \
    "the reservation carries no overrun flag"
  mutant m2 "$CF" 's|^        reserve.holdOverruns();|        // (the word is not held: the mutant)|' \
    qemu_deadline 'killed by signal 24 -- SIGXCPU' \
    "the word is not held before the reservation is taken, and ends the world during its loading"
  # the take block is copied in front of the stand-in's fork and the one in place is made unreachable but
  # still compiled (an `if` on a null optional with the same capture): the order before SAFE-1
  mutant m3 "$CF" '/^    if (!c.process) pids: {/i\    if (reservation) |r0| { reserve.holdOverruns(); reserve.take(r0) catch |e0| { done.reservation = e0; return done; }; }
s|^    if (reservation) \|r\| {$|    if (@as(?machine.Reservation, null)) \|r\| {|' \
    qemu_deadline 'reserved: no reservation -- this world runs under policy 0 on 1 core' \
    "the reservation is taken before the stand-in forks the world, as before SAFE-1"
  mutant m4 "$IM" 's|\\nCONFIG_POSIX_TIMERS=y\\n", .{});|\\n", .{});|' \
    qemu_tick 'keeps no posix timers' \
    "the timed kernel is derived without posix timers, and PID 1 reads that back before any reservation"

  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then
    echo "PROBED: both production boots match their pins, the seat's tests pass, and each thing put wrong that was run is refused on the line that names it"
  else
    echo "NOT PROBED: something above survived, did not compile, or was not convicted by its line"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
