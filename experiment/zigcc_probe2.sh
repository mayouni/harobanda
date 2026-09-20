#!/bin/bash
# zigcc_probe2.sh -- the exact command the kernel runs for the .s target
# that produces nothing, run by hand, to name the flag responsible.
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
export ZIGCC_REAL=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
W=$HOME/harb-zig/bin/zigcc
SRC=$HOME/harb-kernel/zigcc-x86_64/linux-6.12.109
{
  cd "$SRC" || exit 1
  rm -f scripts/mod/devicetable-offsets.s
  echo "== the command, from V=1 =="
  make CC="$W" HOSTCC=gcc V=1 scripts/mod/devicetable-offsets.s 2>&1 | grep -E "devicetable-offsets\.s" | grep zigcc | tail -1 | tee /tmp/cmd.txt
  echo "== does the file exist now? =="
  ls -la scripts/mod/devicetable-offsets.s 2>&1
  echo "== the same command with -o replaced by a plain path =="
  CMD=$(cat /tmp/cmd.txt)
  if [ -n "$CMD" ]; then
    rm -f /tmp/out.s
    eval "${CMD/-o scripts\/mod\/devicetable-offsets.s/-o /tmp/out.s}" ; echo "rc $?"
    ls -la /tmp/out.s 2>&1
    echo "== and with -Wp,-MMD dropped =="
    rm -f /tmp/out2.s
    CLEAN=$(echo "$CMD" | sed -E 's/-Wp,-MMD,[^ ]+ //; s#-o scripts/mod/devicetable-offsets.s#-o /tmp/out2.s#')
    eval "$CLEAN"; echo "rc $?"
    ls -la /tmp/out2.s 2>&1
  fi
} > "$OLDPWD/zig-out/wsl/zigcc_probe2.txt" 2>&1
cd "$(dirname "$0")/.." && cat zig-out/wsl/zigcc_probe2.txt
