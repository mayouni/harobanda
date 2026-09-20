#!/bin/bash
# zigcc_probe5.sh -- zig cc refuses -fno-pic because its resolved target
# (musl) requires position independent code, although the kernel already
# passes --target=x86_64-linux-gnu. Does zig's own spelling of the target
# change its mind, and does the kernel's percpu asm then compile?
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
SRC=$HOME/harb-kernel/zigcc-x86_64/linux-6.12.109
{
  cd "$SRC" || exit 1
  printf 'int f(void){return 1;}\n' > /tmp/t.c
  echo "== a. --target=gnu (clang spelling) + -fno-pic =="
  $Z cc --target=x86_64-linux-gnu -fno-pic -c -o /tmp/a.o /tmp/t.c; echo "rc $?"
  echo "== b. -target gnu (zig spelling) + -fno-pic =="
  $Z cc -target x86_64-linux-gnu -fno-pic -c -o /tmp/b.o /tmp/t.c; echo "rc $?"
  echo "== c. zig spelling, freestanding-ish: -target x86_64-freestanding =="
  $Z cc -target x86_64-freestanding -fno-pic -c -o /tmp/c.o /tmp/t.c; echo "rc $?"
  echo "== d. the kernel's percpu header, zig spelling + -fno-pic =="
  BASE="-nostdinc -I./arch/x86/include -I./arch/x86/include/generated -I./include -I./arch/x86/include/uapi -I./arch/x86/include/generated/uapi -I./include/uapi -I./include/generated/uapi -include ./include/linux/compiler-version.h -include ./include/linux/kconfig.h -include ./include/linux/compiler_types.h -D__KERNEL__ -fintegrated-as -std=gnu11 -m64 -mno-red-zone -mcmodel=kernel -Os -fno-stack-protector -Wno-unused-command-line-argument -fno-PIE"
  rm -f /tmp/d.o
  $Z cc -target x86_64-linux-gnu -fno-pic $BASE -c -o /tmp/d.o init/main.c 2>&1 | head -8; echo "obj: $([ -s /tmp/d.o ] && echo yes || echo no)"
  echo "== f. the kernel's own file on zig's FREESTANDING target =="
  rm -f /tmp/f.o
  $Z cc -target x86_64-freestanding -fno-pic $BASE -c -o /tmp/f.o init/main.c 2>&1 | head -8; echo "obj: $([ -s /tmp/f.o ] && echo yes || echo no)"
  echo "== g. and a second, heavier one (the percpu users) =="
  rm -f /tmp/g.o
  $Z cc -target x86_64-freestanding -fno-pic $BASE -c -o /tmp/g.o arch/x86/events/utils.c 2>&1 | head -5; echo "obj: $([ -s /tmp/g.o ] && echo yes || echo no)"
  echo "== e. the same without -fno-pic (to show the constraint error) =="
  rm -f /tmp/e.o
  $Z cc -target x86_64-linux-gnu $BASE -c -o /tmp/e.o init/main.c 2>&1 | grep -m1 -E 'error' ; echo "obj: $([ -s /tmp/e.o ] && echo yes || echo no)"
} > "$OLDPWD/zig-out/wsl/zigcc_probe5.txt" 2>&1
cd "$(dirname "$0")/.." && cat zig-out/wsl/zigcc_probe5.txt
