#!/bin/bash
# zigcc_probe.sh -- what `zig cc` does with the argument shapes the kernel
# build uses, on one three-line file, so a wall found in a 500-file build
# can be named in one line. Output: zig-out/wsl/zigcc_probe.txt
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
export ZIGCC_REAL=$HOME/stzos-zig/zig-x86_64-linux-0.15.2/zig
W=$HOME/stzos-zig/bin/zigcc
T=$(mktemp -d)
printf 'int f(void){return 1;}\n' > "$T/t.c"
{
  echo "== -S -o out.s (as any compiler is asked for assembly) =="
  rm -f "$T/a.s"; "$W" -S -o "$T/a.s" "$T/t.c"; echo "rc $?; exists: $([ -f "$T/a.s" ] && echo yes || echo no)"
  echo "== -S -o out.s -c (the kernel's .s rule, with -c in c_flags) =="
  rm -f "$T/b.s"; "$W" -S -o "$T/b.s" -c "$T/t.c"; echo "rc $?; exists: $([ -f "$T/b.s" ] && echo yes || echo no)"
  echo "== -c -o out.o (the ordinary object rule) =="
  rm -f "$T/c.o"; "$W" -c -o "$T/c.o" "$T/t.c"; echo "rc $?; exists: $([ -f "$T/c.o" ] && echo yes || echo no)"
  echo "== -E -o out.i (preprocess) =="
  rm -f "$T/d.i"; "$W" -E -o "$T/d.i" "$T/t.c"; echo "rc $?; exists: $([ -f "$T/d.i" ] && echo yes || echo no)"
  echo "== where does -c come from? the kernel's c_flags for a .s target =="
  grep -n 'cmd_cc_s_c' "$HOME/stzos-kernel/zigcc-x86_64/linux-6.12.109/scripts/Makefile.build" | head -3
  grep -rn 'KBUILD_CPPFLAGS.*-c\b\|^CC_FLAGS.*-c\b' "$HOME/stzos-kernel/zigcc-x86_64/linux-6.12.109/Makefile" | head -3
} > zig-out/wsl/zigcc_probe.txt 2>&1
rm -rf "$T"
cat zig-out/wsl/zigcc_probe.txt
