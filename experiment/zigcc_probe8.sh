#!/bin/bash
# what the kernel's own Makefile says REALMODE_CFLAGS is
S=$HOME/harb-kernel/zigcc-x86_64/linux-6.12.109
cd "$(dirname "$0")/.." || exit 1
{
  echo "== REALMODE_CFLAGS in arch/x86/Makefile =="
  grep -n -A8 '^REALMODE_CFLAGS' "$S/arch/x86/Makefile" | head -14
  echo "== CLANG_FLAGS referenced there? =="
  grep -n 'CLANG_FLAGS' "$S/arch/x86/Makefile" | head -5
  echo "== realmode/rm/Makefile KBUILD_CFLAGS =="
  grep -n 'KBUILD_CFLAGS' "$S/arch/x86/realmode/rm/Makefile" | head -5
} > zig-out/wsl/zigcc_probe8.txt 2>&1
cat zig-out/wsl/zigcc_probe8.txt
