#!/bin/bash
# ports_probe.sh -- a world held to the ports it declares, probed (PORT-1): the pin must match, and three things
# the seat does must each be caught, when taken away, by the line that names it.
#
# machines/qemu_ports.machine is the only judge of what PID 1 DOES with a PORTS clause: the Landlock rule set that
# holds a world to its declared ports, the capability for a port below 1024 kept through the drop of identity and
# raised for the world, and the kernel it derived with Landlock in it. A pin that has only ever been seen to match is
# a claim (VDCT-1), so this runs the boot on the production source first, then takes one thing away at a time, in a
# scratch copy of the source, and requires each to be caught by the line that names it:
#
#   m1  the capability is not raised after the drop of identity        `front`, told it may bind 443, is REFUSED it
#       (raiseBind returns before it does anything)                      (ACCES), and the pin refuses the boot
#   m2  the rule set is not applied (restrict returns before it does)   `front` BINDS 8443, a port it was never given --
#                                                                       the capability alone is a grant to everything
#                                                                       below 1024 and no bar above it
#   m3  the kernel is derived WITHOUT Landlock                           PID 1 asks the kernel at the world's start and
#       (the line dropped from the fragment: a kernel build)             does not start it: `the kernel cannot hold it
#                                                                       to its ports (no landlock)`
#
# Each mutant must differ from the source, compile, FAIL the boot's judge, and carry its line -- never merely fail.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/ports_probe.sh [m1 m2 m3]
#
# With no argument it runs the production boot and all three, four boots and three builds (m3 builds a kernel, which
# the cache under $HOME may already hold); with names it runs the production boot and those, and PRINTS the ones it
# skipped. One heavy job at a time: it builds and boots on this machine. It uses $HOME/harb-ports-probe and the
# kernel cache under $HOME, never this repository's zig-out.
#
# Log: zig-out/wsl/ports_probe.txt, this run's or absent. Exit 0 only if the production boot matches its pin and
# every probe that was run is convicted by its line.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-ports-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/ports_probe.txt
ALL="m1 m2 m3"
WANT=${*:-$ALL}
for w in $WANT; do case " $ALL " in *" $w "*) ;; *) echo "usage: ports_probe.sh [$ALL]"; exit 2 ;; esac; done
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
  [ -f machines/qemu_ports.expected ] || { echo "no pin for qemu_ports: nothing to probe against"; exit 1; }
  grep -q 'pub fn restrict' src/ports.zig || { echo "src/ports.zig has no restrict: nothing to probe"; exit 1; }
  verdict=0
  OUT=zig-out/image/qemu_ports
  IMG=zig-out/wsl/image_qemu_ports.txt

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
    bash experiment/os2_image.sh qemu_ports > "$S/boot.out" 2>&1
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

  # one thing taken away in the source: $1 = label, $2 = the file, $3 = the sed program, $4 = the line the boot's
  # transcript must carry, $5 = a description. The mutant must differ, compile, FAIL the judge, and carry $4.
  mutant() {
    local label=$1 file=$2 prog=$3 line=$4 what=$5
    wants "$label" "$what" || return
    echo "=== $label: $what ==="
    cp "$file" "$file.orig"
    sed -i "$prog" "$file"
    if cmp -s "$file" "$file.orig"; then echo "the mutation did not apply"; verdict=1; cp "$file.orig" "$file"; return; fi
    if ! build; then
      echo "MUTANT DID NOT COMPILE ($label): that convicts nothing"; grep -m3 'error:' "$S/build.txt"; verdict=1
    else
      boot
      if [ "$RC" -eq 0 ]; then echo "MUTANT SURVIVED ($label): the boot matched its pin with the thing taken away"; verdict=1
      elif transcript "$OUT/transcript.txt" | grep -q -- "$line"; then
        echo "convicted: the judge refuses the boot, and the transcript says why:"; transcript "$OUT/transcript.txt" | grep -m1 -- "$line" | cut -c1-170
      else
        echo "MUTANT NOT CONVICTED BY ITS LINE ($label: wanted '$line')"; transcript "$OUT/transcript.txt" | grep 'boot: \|bound: ' | head -14 | cut -c1-150; verdict=1
      fi
    fi
    cp "$file.orig" "$file"; rm -f "$file.orig"
  }

  PO=src/ports.zig; IM=src/image.zig
  mutant m1 "$PO" '/^pub fn raiseBind() ?\[\]const u8 {/a\    if (true) return null;' \
    'bound: 443 -- REFUSED (ACCES)' \
    "the capability for a port below 1024 is not raised after the drop of identity"
  mutant m2 "$PO" '/^pub fn restrict(ports: \[\]const u16) ?\[\]const u8 {/a\    if (true) return null;' \
    'bound: 8443 -- BOUND as uid 2010' \
    "the rule set is not applied, and the capability alone bars nothing above 1024"
  mutant m3 "$IM" '/CONFIG_SECURITY_LANDLOCK=y/d' \
    'front -- NOT STARTED: the kernel cannot hold it to its ports (no landlock)' \
    "the kernel is derived without Landlock, and PID 1 reads that back at the world's start"

  echo "=== verdict ==="
  if [ "$verdict" -eq 0 ]; then
    echo "PROBED: the production boot matches its pin, and each thing taken away that was run is refused on the line that names it"
  else
    echo "NOT PROBED: something above survived, did not compile, or was not convicted by its line"
  fi
  echo "exit $verdict"
  exit "$verdict"
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
