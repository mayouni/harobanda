#!/bin/bash
# zigcc_probe6.sh -- the last question of ZIGCC-1: zig's FREESTANDING
# target is the only one that accepts -fno-pic. Does the kernel's own
# source compile on it? One file, all output kept.
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
SRC=$HOME/harb-kernel/zigcc-x86_64/linux-6.12.109
OUTF=zig-out/wsl/zigcc_probe6.txt
BASE="-nostdinc -I./arch/x86/include -I./arch/x86/include/generated -I./include -I./arch/x86/include/uapi -I./arch/x86/include/generated/uapi -I./include/uapi -I./include/generated/uapi -include ./include/linux/compiler-version.h -include ./include/linux/kconfig.h -include ./include/linux/compiler_types.h -D__KERNEL__ -std=gnu11 -m64 -mno-red-zone -mcmodel=kernel -Os -fno-stack-protector -Wno-unused-command-line-argument -fno-PIE"
(
  cd "$SRC" || exit 1
  rm -f /tmp/f.o
  $Z cc -target x86_64-freestanding -fno-pic $BASE -c -o /tmp/f.o init/main.c > /tmp/f.log 2>&1
  echo "rc $?"
  echo "object: $([ -s /tmp/f.o ] && echo yes || echo no)"
  echo "warnings: $(grep -c 'warning:' /tmp/f.log)"
  echo "errors:   $(grep -c 'error:' /tmp/f.log)"
  echo "-- the first three error lines, if any:"
  grep 'error:' /tmp/f.log | head -3
  echo "== the same, WITH -fintegrated-as (which the kernel passes) =="
  rm -f /tmp/h.o
  $Z cc -target x86_64-freestanding -fno-pic -fintegrated-as $BASE -c -o /tmp/h.o init/main.c > /tmp/h.log 2>&1
  echo "rc $?; object: $([ -s /tmp/h.o ] && echo yes || echo no); errors: $(grep -c 'error:' /tmp/h.log)"
  grep 'error:' /tmp/h.log | head -3
  echo "== and a percpu-heavy file, with -fintegrated-as =="
  rm -f /tmp/i.o
  $Z cc -target x86_64-freestanding -fno-pic -fintegrated-as $BASE -c -o /tmp/i.o arch/x86/events/utils.c > /tmp/i.log 2>&1
  echo "rc $?; object: $([ -s /tmp/i.o ] && echo yes || echo no); errors: $(grep -c 'error:' /tmp/i.log)"
  grep 'error:' /tmp/i.log | head -3
) > "$OUTF" 2>&1
cat "$OUTF"
