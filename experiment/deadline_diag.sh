#!/bin/bash
# deadline_diag.sh -- TIM-1's diagnostic: boot qemu_deadline's image LOUD (every kernel line, no
# `quiet`) and keep what it says about its second cpu, the MP table and the APIC, its clocksource,
# and the timers' high-resolution mode. The first boot of the machine said `cpus online [0]` on a
# `-smp 2` emulator and `timers resolve 4000000 ns` on a kernel built with HIGH_RES_TIMERS=y; the
# quiet boot line hides why. Not a gate: a reading. Needs the image built (os2_image.sh qemu_deadline).
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/deadline_diag.sh
#
# Log: zig-out/wsl/deadline_diag.txt
set -u
cd "$(dirname "$0")/.." || exit 1
OUT=zig-out/image/qemu_deadline
LOG=zig-out/wsl/deadline_diag.txt
mkdir -p zig-out/wsl
rm -f "$LOG"
[ -f "$OUT/boot.cmd" ] || { echo "no $OUT/boot.cmd: build the image first (os2_image.sh qemu_deadline)" | tee "$LOG"; exit 1; }
sed 's/quiet loglevel=3/ignore_loglevel/' "$OUT/boot.cmd" > "$OUT/boot_loud.cmd"
( cd "$OUT" && timeout --foreground 120 bash boot_loud.cmd < /dev/null > transcript_loud.txt 2>&1; echo "qemu exit $?" >> transcript_loud.txt )
{
  echo "=== the boot line"
  cat "$OUT/boot_loud.cmd"
  echo "=== lines about cpus, the MP table, the APIC, the clocksource and the timers"
  tr -d '\r' < "$OUT/transcript_loud.txt" | grep -iE 'smp|mptable|mp-table|mp table|apic|cpu[0-9]|clocksource|hrtimer|high res|tsc|hpet|acpi|brought up|allowing|processor|clockevent|tick' | head -80
  echo "=== the whole loud boot, first 220 lines"
  tr -d '\r' < "$OUT/transcript_loud.txt" | head -220
} > "$LOG" 2>&1
echo "wrote $LOG"
