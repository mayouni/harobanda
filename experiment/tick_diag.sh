#!/bin/bash
# tick_diag.sh -- the latency witness read in five settings (TCK-1): a reading, not a gate.
#
# machines/qemu_tick.machine measures how late a reserved world wakes beside a reserved spinner and an
# unreserved one. Its first boot said 66 ms at the median on a 1 ms period, which no neighbour could
# cause (a neighbour holds the core for its runtime at most) -- so the question is where the lateness
# comes from: the emulator's own timers, the reserved neighbour, the unreserved hog, or the witness.
# This boots the witness in five settings derived from the machine file by taking things away, and
# prints the five measured lines side by side:
#
#   alone        the witness reserved on core 1, no spinners
#   loose        the witness with NO reservation, no spinners (it lands on core 0 with PID 1)
#   neighbour    the witness reserved beside the reserved spinner on core 1, no hog
#   full         the machine as declared (neighbour on core 1, hog on core 0)
#   hogged       the witness with NO reservation beside the hog, nothing reserved at all: the image then
#                carries no timed kernel, and an absolute sleep of 1 ms costs a jiffy (4 ms) every period
#   broken       lesson 12's BREAK IT: the machine as declared with only the witness's reservation taken
#                away -- the neighbour keeps the kernel timed, and the witness lands on core 0 with the hog
#
# Each setting is a scratch machine under zig-out/scratch, imaged and booted by os2_image.sh through
# HARB_MACHINE_FILE; none is pinned, and none is judged here: the numbers are this host's.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/tick_diag.sh [alone loose neighbour full hogged]
#
# Log: zig-out/wsl/tick_diag.txt. About five boots.
set -u
cd "$(dirname "$0")/.." || exit 1
LOG=zig-out/wsl/tick_diag.txt
S=zig-out/scratch
mkdir -p zig-out/wsl "$S"
rm -f "$LOG"
ALL="alone loose neighbour full hogged broken"
WANT=${*:-$ALL}
M=machines/qemu_tick.machine
# the RUN line of a witness with no reservation keeps its period and deadline: the arguments say them
(
  derive() { # $1 = setting -> $S/qemu_tick_$1.machine
    local out=$S/qemu_tick_$1.machine
    case $1 in
      alone)     sed -e '/^DEFINE SERVICE neighbour AS/,/^) RATIONALE/d' -e '/^DEFINE SERVICE hog AS/,/^) RATIONALE/d' -e 's/^  AFTER \[neighbour, hog\],$//' "$M" > "$out" ;;
      loose)     sed -e '/^DEFINE SERVICE neighbour AS/,/^) RATIONALE/d' -e '/^DEFINE SERVICE hog AS/,/^) RATIONALE/d' -e 's/^  AFTER \[neighbour, hog\],$//' "$M" \
                   | awk '/^DEFINE SERVICE tick AS/{t=1} t && /^  (PERIOD|DEADLINE|RUNTIME|CORE) /{next} {print}' > "$out" ;;
      neighbour) sed -e '/^DEFINE SERVICE hog AS/,/^) RATIONALE/d' -e 's/^  AFTER \[neighbour, hog\],$/  AFTER [neighbour],/' "$M" > "$out" ;;
      full)      cp "$M" "$out" ;;
      hogged)    sed -e '/^DEFINE SERVICE neighbour AS/,/^) RATIONALE/d' -e 's/^  AFTER \[neighbour\],$//' -e 's/^  AFTER \[neighbour, hog\],$/  AFTER [hog],/' "$M" \
                   | awk '/^DEFINE SERVICE tick AS/{t=1} t && /^  (PERIOD|DEADLINE|RUNTIME|CORE) /{next} {print}' > "$out" ;;
      broken)    awk '/^DEFINE SERVICE tick AS/{t=1} t && /^  (PERIOD|DEADLINE|RUNTIME|CORE) /{next} {print}' "$M" > "$out" ;;
    esac
    sed -i "s/^DEFINE MACHINE qemu_tick AS/DEFINE MACHINE qemu_tick_$1 AS/" "$out"
    echo "$out"
  }
  for s in $WANT; do
    case " $ALL " in *" $s "*) ;; *) echo "usage: tick_diag.sh [$ALL]"; exit 2 ;; esac
    f=$(derive "$s")
    echo "=== $s: $f"
    zig-out/cross/x86_64-linux-musl/harb check "$f" | cut -c1-120 || { echo "the court refuses this setting"; continue; }
    t0=$SECONDS
    rm -f "zig-out/wsl/image_qemu_tick_$s.txt"
    HARB_MACHINE_FILE=$f bash experiment/os2_image.sh "qemu_tick_$s" > /dev/null 2>&1
    rc=$?
    echo "    booted in $((SECONDS - t0)) s, exit $rc"
    tr -d '\r' < "zig-out/image/qemu_tick_$s/transcript.txt" | grep -E '^(tick|spin): ' | cut -c1-200
  done
  echo "=== the measured lines, side by side"
  for s in $WANT; do printf '%-10s %s\n' "$s" "$(tr -d '\r' < "zig-out/image/qemu_tick_$s/transcript.txt" 2>/dev/null | grep -m1 '^tick: measured' | cut -c17-)"; done
) 2>&1 | tee "$LOG"
