#!/bin/bash
# regress.sh -- every pinned boot, one after another, each judged against its pin: the pre-commit gate
# for a change to PID 1, the image or the standing lines. A monolithic suite, run ONCE per task (PX) and
# never after every edit; the inner loop is one machine's boot, named on the command line.
#
# The single machines go through os2_image.sh, the scenes through their own scripts, and the four
# promises through judge_guarantees.sh after the flagship's boot. Each log is REMOVED before its run,
# and the exit code and the seconds are printed beside the verdict, because a loop that read a previous
# run's green log beside a command that had not run printed a verdict for a run that did not happen
# (FWD-1). The two scenes that need RingServ built (experiment/ringserv_build.ps1) are SKIPPED, by
# name, when it is not: a gate that could not run is named, never counted (PX).
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/regress.sh [name...]
#
# Names: a machine under machines/ with a pin, or a scene -- guarantees, names, fleet, time, cloud,
# links. With no name it runs everything, about half an hour, one heavy job at a time. Log:
# zig-out/wsl/regress.txt, this run's or absent. Exit 0 only if every boot that ran matched its pin;
# what was skipped is printed by name.
set -u
cd "$(dirname "$0")/.." || exit 1
LOG=zig-out/wsl/regress.txt
mkdir -p zig-out/wsl
rm -f "$LOG"
WANT="$*"
MACHINES="qemu_hello qemu_egress qemu_confine qemu_budget qemu_identity qemu_own qemu_forward qemu_deadline fleet_temoin makeen_qemu makeen_box"
(
  fails=0; ran=0
  wanted() { [ -z "$WANT" ] && return 0; case " $WANT " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
  one() { # $1 = label, $2 = the log the command writes (or - to keep its stdout), $3.. = the command
    local label=$1 log=$2; shift 2
    local t0=$SECONDS rc v
    if [ "$log" = - ]; then log=zig-out/wsl/regress_$label.txt; rm -f "$log"; "$@" > "$log" 2>&1; rc=$?
    else rm -f "$log"; "$@" > /dev/null 2>&1; rc=$?; fi
    v=$(grep -m1 '^JUDGED' "$log" 2>/dev/null | cut -c1-96)
    printf '%-14s exit %d %5d s  %s\n' "$label" "$rc" $((SECONDS - t0)) "${v:-NO VERDICT: no log at $log}"
    ran=$((ran + 1)); [ "$rc" -eq 0 ] || fails=$((fails + 1))
  }
  skip() { echo "$1: SKIPPED -- $2"; }
  echo "=== every pinned boot, against its pin ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
  for m in $MACHINES; do
    if wanted "$m"; then one "$m" "zig-out/wsl/image_$m.txt" bash experiment/os2_image.sh "$m"; else skip "$m" "not named"; fi
  done
  if wanted guarantees; then one guarantees - bash experiment/judge_guarantees.sh; else skip guarantees "not named"; fi
  if wanted names; then one names zig-out/wsl/names.txt bash experiment/os6_names.sh; else skip names "not named"; fi
  if wanted fleet; then one fleet zig-out/wsl/fleet.txt bash experiment/os7_fleet.sh; else skip fleet "not named"; fi
  if wanted time; then one time zig-out/wsl/time.txt bash experiment/os10_time.sh; else skip time "not named"; fi
  for s in cloud:os9_cloud.sh links:os8_links.sh; do
    n=${s%%:*}; f=${s#*:}
    if ! wanted "$n"; then skip "$n" "not named"
    elif [ ! -f zig-out/ringserv/ringserv ]; then skip "$n" "RingServ is not built under zig-out/ringserv (powershell experiment/ringserv_build.ps1)"
    else one "$n" "zig-out/wsl/$n.txt" bash "experiment/$f"; fi
  done
  echo "=== verdict: $ran ran, $fails failed ==="
  if [ "$fails" -eq 0 ]; then echo "REGRESSION GREEN: every boot that ran matched its pin"; else echo "REGRESSION RED"; fi
  echo "exit $((fails > 0))"
  exit $((fails > 0))
) 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
