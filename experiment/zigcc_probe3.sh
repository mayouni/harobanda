#!/bin/bash
# zigcc_probe3.sh -- is it the -Wp SPELLING of the depfile, or dependency
# generation with -S at all? Three spellings of the same request, on the
# kernel's own file, with everything else identical.
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
export ZIGCC_REAL=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
SRC=$HOME/harb-kernel/zigcc-x86_64/linux-6.12.109
Z=$ZIGCC_REAL
{
  cd "$SRC" || exit 1
  BASE="-nostdinc -I./arch/x86/include -I./arch/x86/include/generated -I./include -I./arch/x86/include/uapi -I./arch/x86/include/generated/uapi -I./include/uapi -I./include/generated/uapi -include ./include/linux/compiler-version.h -include ./include/linux/kconfig.h -include ./include/linux/compiler_types.h -D__KERNEL__ --target=x86_64-linux-gnu -fintegrated-as -std=gnu11 -m64 -mno-red-zone -mcmodel=kernel -Os -fno-stack-protector -Wno-unused-command-line-argument"
  F=scripts/mod/devicetable-offsets.c
  echo "== 1. -S with NO depfile =="
  rm -f /tmp/p1.s; $Z cc $BASE -S -o /tmp/p1.s $F; echo "rc $?; out: $([ -f /tmp/p1.s ] && echo yes || echo no)"
  echo "== 2. -S with -Wp,-MMD,<path> (what the kernel passes) =="
  rm -f /tmp/p2.s /tmp/p2.d; $Z cc $BASE -Wp,-MMD,/tmp/p2.d -S -o /tmp/p2.s $F; echo "rc $?; out: $([ -f /tmp/p2.s ] && echo yes || echo no); dep: $([ -f /tmp/p2.d ] && echo yes || echo no)"
  echo "== 3. -S with -MMD -MF <path> (the driver spelling) =="
  rm -f /tmp/p3.s /tmp/p3.d; $Z cc $BASE -MMD -MF /tmp/p3.d -S -o /tmp/p3.s $F; echo "rc $?; out: $([ -f /tmp/p3.s ] && echo yes || echo no); dep: $([ -f /tmp/p3.d ] && echo yes || echo no)"
  echo "== 4. -c with -MMD -MF (the ordinary object rule, for contrast) =="
  rm -f /tmp/p4.o /tmp/p4.d; $Z cc $BASE -MMD -MF /tmp/p4.d -c -o /tmp/p4.o $F; echo "rc $?; out: $([ -f /tmp/p4.o ] && echo yes || echo no); dep: $([ -f /tmp/p4.d ] && echo yes || echo no)"
  echo "== 5. what the wrapper actually runs, printed =="
  ZIGCC_REAL=/bin/echo "$OLDPWD/experiment/zigcc_wrapper.sh" $BASE -Wp,-MMD,/tmp/p5.d -S -o /tmp/p5.s $F | tr ' ' '\n' | grep -E '^-(MMD|MF|Wp|S|c)$|^-Wp' | head
} > "$OLDPWD/zig-out/wsl/zigcc_probe3.txt" 2>&1
cd "$(dirname "$0")/.." && cat zig-out/wsl/zigcc_probe3.txt
