#!/bin/bash
# zigcc_probe7.sh -- the real-mode corner: which flags does the kernel
# pass for arch/x86/realmode/rm/header.o, and does it name a target?
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
SRC=$HOME/harb-kernel/zigcc-x86_64/linux-6.12.109
W=$HOME/harb-zig/bin/zigcc
(
  cd "$SRC" || exit 1
  export ZIGCC_REAL=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
  rm -f arch/x86/realmode/rm/header.o
  make CC="$W" HOSTCC=gcc V=1 arch/x86/realmode/rm/header.o 2>&1 | grep -m1 'zigcc' > /tmp/rm.cmd
  echo "-- does it name a target?"; grep -o -- '--target=[^ ]*' /tmp/rm.cmd | head -1
  echo "-- which pic flags?"; grep -o -- '-f\(no-\)\?[pP][iI][cCeE]' /tmp/rm.cmd | sort -u | tr '\n' ' '; echo
  echo "-- which -m flags?"; grep -o -- '-m[0-9]*\b\|-march=[^ ]*' /tmp/rm.cmd | sort -u | tr '\n' ' '; echo
) > zig-out/wsl/zigcc_probe7.txt 2>&1
cat zig-out/wsl/zigcc_probe7.txt
