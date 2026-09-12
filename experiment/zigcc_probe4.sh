#!/bin/bash
# zigcc_probe4.sh -- can the one request zig cc mishandles be split into
# two it handles? Pass 1: the assembly, no dependency flags. Pass 2: the
# dependency file, preprocessor only. Both outputs real; nothing forged.
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
Z=$HOME/stzos-zig/zig-x86_64-linux-0.15.2/zig
SRC=$HOME/stzos-kernel/zigcc-x86_64/linux-6.12.109
{
  cd "$SRC" || exit 1
  BASE="-nostdinc -I./arch/x86/include -I./arch/x86/include/generated -I./include -I./arch/x86/include/uapi -I./arch/x86/include/generated/uapi -I./include/uapi -I./include/generated/uapi -include ./include/linux/compiler-version.h -include ./include/linux/kconfig.h -include ./include/linux/compiler_types.h -D__KERNEL__ --target=x86_64-linux-gnu -fintegrated-as -std=gnu11 -m64 -mno-red-zone -mcmodel=kernel -Os -fno-stack-protector -Wno-unused-command-line-argument"
  F=scripts/mod/devicetable-offsets.c
  rm -f /tmp/q.s /tmp/q.d
  echo "== pass 1: -S, no dependency flags =="
  $Z cc $BASE -S -o /tmp/q.s $F; echo "rc $?; asm: $([ -s /tmp/q.s ] && echo yes || echo no)"
  echo "== pass 2: the same command plus -E -MM -MF dep -o /dev/null =="
  $Z cc $BASE -S -o /tmp/q.s $F -E -MM -MF /tmp/q.d -o /dev/null; echo "rc $?; dep: $([ -s /tmp/q.d ] && echo yes || echo no); asm still there: $([ -s /tmp/q.s ] && echo yes || echo no)"
  echo "-- the depfile's first line:"; head -1 /tmp/q.d 2>/dev/null
  echo "-- how many prerequisites:"; tr ' ' '\n' < /tmp/q.d 2>/dev/null | grep -c '\.h$'
} > "$OLDPWD/zig-out/wsl/zigcc_probe4.txt" 2>&1
cd "$(dirname "$0")/.." && cat zig-out/wsl/zigcc_probe4.txt
