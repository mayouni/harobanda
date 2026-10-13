#!/bin/bash
# deadline_probe.sh -- the reservation's boot, probed (TIM-1): the pin must match, and four things the seat
# refuses must each be refused for the reason the seat names.
#
# machines/qemu_deadline.machine is the only judge of what PID 1 DOES with a reservation: the partition it makes
# of a core, the SCHED_DEADLINE it hands a world before the exec, the kernel's admission beside a reservation it
# already holds, and what the worlds say of themselves from inside. A pin that has only ever been seen to match
# is a claim (VDCT-1), so this runs the boot on the production source first, then puts one thing wrong at a
# time -- one in the hardware, three in a scratch copy of the source -- and requires each to be caught by the
# line that names it:
#
#   h1  the emulator is handed ONE core for a machine that declares two        the kernel says RANGE to `cpuset.cpus`,
#       (no source changes: `-smp 1` on the derived boot line)                  and the reserved worlds are NOT STARTED
#   m1  the court's bound forgets the share the kernel holds for the ordinary   the kernel refuses the second world's
#       tasks' own server (95 % instead of 90), and a machine asks the 95th    reservation: DoesNotFit (EBUSY), NOT STARTED
#       -- what the first draft of this seat did, and what its first boot found
#   m2  the partition is CLAIMED and never made (the read-back is skipped)      the witness, from inside the world, says
#                                                                               `on core 0` with no `and no other`: the
#                                                                               world runs on the machine's cores, not its
#   m3  the core is given and the partition is not (cpuset.cpus written,        the kernel's own rule: a deadline task may
#       cpuset.cpus.partition not, and the read-back fooled)                   not have fewer cpus than its domain, EPERM
#                                                                               -- NoPrivilege, NOT STARTED
#
# Each mutant must differ from the source, compile, and FAIL the boot's judge on the named line -- never merely fail.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/deadline_probe.sh [h1 m1 m2 m3]
#
# With no argument it runs the production boot and all four, about six boots and three builds (m1 waits out the
# image script's 180 s: its one started world stays, and nothing ends the machine); with names it runs the
# production boot and those, and PRINTS the ones it skipped. One heavy job at a time: it builds and boots on this
# machine. It uses $HOME/harb-deadline-probe and the kernel cache under $HOME, never this repository's zig-out.
#
# Log: zig-out/wsl/deadline_probe.txt, this run's or absent. Exit 0 only if the production boot matches its pin and
# every probe that was run is convicted by its line.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-deadline-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/deadline_probe.txt
ALL="h1 m1 m2 m3"
WANT=${*:-$ALL}
for w in $WANT; do case " $ALL " in *" $w "*) ;; *) echo "usage: deadline_probe.sh [$ALL]"; exit 2 ;; esac; done
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
  [ -f machines/qemu_deadline.expected ] || { echo "no pin for qemu_deadline: nothing to probe against"; exit 1; }
  grep -q 'fn partitionOf' src/init.zig || { echo "src/init.zig has no partitionOf: nothing to probe"; exit 1; }
  verdict=0
  OUT=zig-out/image/qemu_deadline
  IMG=zig-out/wsl/image_qemu_deadline.txt

  build() { # the machine the boot runs: the one binary, cross-built for Linux, in the copy
    local t0=$SECONDS
    "$Z" build cross -j2 > "$S/build.txt" 2>&1
    local rc=$?
    echo "    built in $((SECONDS - t0)) s"
    return $rc
  }
  boot() { # the copy's own image script: leaves its verdict in RC and its log in $IMG
    local t0=$SECONDS
    rm -f "$IMG"
    bash experiment/os2_image.sh qemu_deadline > "$S/boot.out" 2>&1
    RC=$?
    echo "    the boot ran $((SECONDS - t0)) s, exit $RC: $(grep -m1 '^JUDGED' "$IMG" 2>/dev/null | cut -c1-110)"
  }
  wants() { case " $WANT " in *" $1 "*) return 0 ;; *) echo "=== $1 $2 -- SKIPPED (not named on the command line) ==="; return 1 ;; esac; }
  transcript() { tr -d '\r' < "$1"; }

  echo "=== the production source: its own boot, built and run in the copy, against its pin ==="
  if ! build; then echo "THE PRODUCTION SOURCE DOES NOT BUILD"; grep -m5 'error:' "$S/build.txt"; echo "exit 1"; exit 1; fi
  boot
  if [ "$RC" -ne 0 ] || ! grep -q '^JUDGED: the boot transcript matches' "$IMG" 2>/dev/null; then
    echo "THE PRODUCTION SOURCE FAILS ITS OWN BOOT IN THE COPY: no probe can be convicted by a boot that is red already"
    tail -5 "$S/boot.out"; verdict=1
  fi

  if wants h1 "the emulator is handed one core for a machine that declares two"; then
    echo "=== h1: the emulator is handed one core for a machine that declares two ==="
    sed 's/ -smp 2 / -smp 1 /' "$OUT/boot.cmd" > "$OUT/boot_smp1.cmd"
    if cmp -s "$OUT/boot.cmd" "$OUT/boot_smp1.cmd"; then echo "the boot line carries no -smp 2 to take away"; verdict=1; else
      t0=$SECONDS
      ( cd "$OUT" && timeout --foreground 120 bash boot_smp1.cmd < /dev/null > transcript_smp1.txt 2>&1; echo "qemu exit $?" >> transcript_smp1.txt )
      echo "    the boot ran $((SECONDS - t0)) s"
      T=$OUT/transcript_smp1.txt
      if transcript "$T" | grep -q 'the boot matches its expectation'; then echo "H1 SURVIVED: the machine judged a one-core boot a match"; verdict=1; fi
      if transcript "$T" | grep -q 'core 1 could not be made a partition of its own: the kernel says cpuset.cpus refused (RANGE)' \
         && transcript "$T" | grep -q 'control -- NOT STARTED: its core is not a partition of its own'; then
        echo "convicted: the kernel says the core is out of range, and the reserved worlds are not started:"
        transcript "$T" | grep -m2 'could not be made a partition\|NOT STARTED' | cut -c1-150
      else echo "H1 NOT CONVICTED BY ITS LINES"; transcript "$T" | grep 'boot: ' | head -12; verdict=1; fi
    fi
  fi

  # one thing put wrong in the source: $1 = label, $2 = the file, $3 = the sed program, $4 = the line the boot's
  # transcript must carry, $5 = a description. The copy's machine file may be changed too ($6 = a sed program for
  # machines/qemu_deadline.machine, or empty). The mutant must differ, compile, FAIL the judge, and carry $4.
  mutant() {
    local label=$1 file=$2 prog=$3 line=$4 what=$5 mprog=${6:-}
    wants "$label" "$what" || return
    echo "=== $label: $what ==="
    cp "$file" "$file.orig"; cp machines/qemu_deadline.machine machine.orig
    sed -i "$prog" "$file"
    if cmp -s "$file" "$file.orig"; then echo "the mutation did not apply"; verdict=1; cp "$file.orig" "$file"; return; fi
    if [ -n "$mprog" ]; then
      sed -i "$mprog" machines/qemu_deadline.machine
      if cmp -s machines/qemu_deadline.machine machine.orig; then echo "the machine's change did not apply"; verdict=1; fi
    fi
    if ! build; then
      echo "MUTANT DID NOT COMPILE ($label): that convicts nothing"; grep -m3 'error:' "$S/build.txt"; verdict=1
    else
      boot
      if [ "$RC" -eq 0 ]; then echo "MUTANT SURVIVED ($label): the boot matched its pin with the thing put wrong"; verdict=1
      elif transcript "$OUT/transcript.txt" | grep -q -- "$line"; then
        echo "convicted: the judge refuses the boot, and the transcript says why:"; transcript "$OUT/transcript.txt" | grep -m1 -- "$line" | cut -c1-160
      else
        echo "MUTANT NOT CONVICTED BY ITS LINE ($label: wanted '$line')"; transcript "$OUT/transcript.txt" | grep 'boot: \|reserved: ' | head -14 | cut -c1-150; verdict=1
      fi
    fi
    cp "$file.orig" "$file"; rm -f "$file.orig"; cp machine.orig machines/qemu_deadline.machine; rm -f machine.orig
  }

  MC=src/machine.zig; IN=src/init.zig
  mutant m1 "$MC" 's|^pub const reservable_bw: u64 = (950_000 << bw_shift) / 1_000_000 - (50_000 << bw_shift) / 1_000_000;|pub const reservable_bw: u64 = (950_000 << bw_shift) / 1_000_000;|' \
    'second -- NOT STARTED: the kernel refused its reservation (DoesNotFit)' \
    "the court's bound forgets the server's share, and a machine asks the 95th per cent" \
    's/^  RUNTIME 700,/  RUNTIME 750,/'
  mutant m2 "$IN" '/^fn partitionOf(/a\    if (true) return partition_kind;' \
    'on core 0: as the kernel reports it' \
    'the partition is claimed and never made'
  # the partition file is written `member` (a no-op: the group stays an ordinary member) and the read-back's
  # comparison is switched off, so PID 1 believes the core set apart. A `return` in place of the write was
  # the first shape of this mutant, and Zig refused the lines after it as unreachable: a mutant that does
  # not compile convicts nothing, so the mutation must leave a program behind it
  mutant m3 "$IN" 's|writeKernelFileErrno(part, partition_kind)|writeKernelFileErrno(part, "member")|; s|if (!std.mem.eql(u8, said, partition_kind)) {|if (false and !std.mem.eql(u8, said, partition_kind)) {|' \
    'control -- NOT STARTED: the kernel refused its reservation (NoPrivilege)' \
    'the core is given and the partition is not'

  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then
    echo "PROBED: the production boot matches its pin, and each thing put wrong that was run is refused on the line that names it"
  else
    echo "PROBE FAILED"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
