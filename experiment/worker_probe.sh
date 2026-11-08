#!/bin/bash
# worker_probe.sh -- a world started for one job and ended after it, probed (WORKER-1): the pin must match, and
# four walls PID 1 puts round a job must each be caught, when taken away, by the line that names it.
#
# machines/qemu_worker.machine is the judge of what PID 1 DOES for a worker. The unit tests judge the filter
# program and the file acts; only a boot judges that PID 1 applies them to a real worker. A pin that has only ever
# been seen to match is a claim (VDCT-1), so this runs the boot on the production source first, then takes one
# thing away at a time, in a scratch copy of the source, and requires each to be caught by the line that names it:
#
#   m1  a worker keeps its sockets (the confinement     job one's report: `a netlink socket -- ALLOWED`
#       derived as any other world's)                    -- the kernel of a machine with no network has no
#                                                       unix or inet family to give (it answers AFNOSUPPORT
#                                                       for both, found by this probe's first run), and
#                                                       netlink it has; so the production report's PERM for
#                                                       all four is the FILTER's answer, not the kernel's
#   m2  the Landlock rule set is not applied            job one's report: `read /etc/machine -- ALLOWED`
#       (holdToScratch returns before it does anything)
#   m3  the worker's stdout is the console               the worker's own line on the console, unprefixed
#       (the redirection into its folder dropped)
#   m4  the LIMIT is noticed and nothing is ended         job three: `NO ANSWER after 60 s`
#       (the kill of its group dropped)
#
# Each mutant must differ from the source, compile, FAIL the boot's judge, and carry its line -- never merely fail.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/worker_probe.sh [m1 m2 m3 m4]
#
# With no argument it runs the production boot and all four, five boots and five builds, one heavy job at a time
# (m4's boot runs to the emulator's timeout); with names, the production boot and those, and it PRINTS the ones
# it skipped. It uses $HOME/harb-worker-probe and the kernel cache under $HOME, never this repository's zig-out.
#
# Log: zig-out/wsl/worker_probe.txt, this run's or absent. Exit 0 only if the production boot matches its pin and
# every probe that was run is convicted by its line.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-worker-probe
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
LOG=$R/zig-out/wsl/worker_probe.txt
ALL="m1 m2 m3 m4"
WANT=${*:-$ALL}
for w in $WANT; do case " $ALL " in *" $w "*) ;; *) echo "usage: worker_probe.sh [$ALL]"; exit 2 ;; esac; done
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
  [ -f machines/qemu_worker.expected ] || { echo "no pin for qemu_worker: nothing to probe against"; exit 1; }
  verdict=0
  OUT=zig-out/image/qemu_worker
  IMG=zig-out/wsl/image_qemu_worker.txt

  build() {
    local t0=$SECONDS
    "$Z" build cross -j2 > "$S/build.txt" 2>&1
    local rc=$?
    echo "    built in $((SECONDS - t0)) s"
    return $rc
  }
  boot() {
    local t0=$SECONDS
    rm -f "$IMG"
    bash experiment/os2_image.sh qemu_worker > "$S/boot.out" 2>&1
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
        echo "MUTANT NOT CONVICTED BY ITS LINE ($label: wanted '$line')"; transcript "$OUT/transcript.txt" | grep 'work: \|job: ' | head -14 | cut -c1-150; verdict=1
      fi
    fi
    cp "$file.orig" "$file"; rm -f "$file.orig"
  }

  mutant m1 src/confine.zig 's/\.sockets = svc\.jobs == null/.sockets = true/' \
    'report: a netlink socket -- ALLOWED' \
    "a worker keeps its sockets: the confinement derived as any other world's"
  mutant m2 src/work.zig '/^pub fn holdToScratch(/a\    if (true) return null;' \
    'report: read /etc/machine -- ALLOWED' \
    "the Landlock rule set is not applied, and the worker reads the machine's own file"
  mutant m3 src/init.zig '/dup2(@intCast(so), 1)/d' \
    '^untrusted: this line is the worker' \
    "the worker's stdout is left on the console, where code nobody vouched for writes beside the floor"
  mutant m4 src/init.zig '/endGroup(svc, s\.job_pid);/d' \
    'job: three -- NO ANSWER after 60 s' \
    "the LIMIT is noticed and nothing is ended"

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
