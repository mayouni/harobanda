#!/bin/bash
# os9_cloud.sh -- the first server placed on a machine, and booted (SRV-2).
#
# The scene is the cloud ladder's rung 1 (doc/CLOUD.md): the machine
# machines/qemu_cloud.machine grants what a server world asks, the pack
# machines/ringserv.pack asks for it, `harb place` composes the two and hands
# them to the one court, and the result is imaged, booted and judged like any
# machine -- against machines/qemu_cloud_ringserv.expected. The server is a
# real RingServ, built from the source ref vendor/PIN.md pins by
# experiment/ringserv_build.ps1 (it is not in git), and the world that runs it
# is `harb ready`, which says the server is serving only while it answers
# /health (src/ready.zig).
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os9_cloud.sh
#
# Log: zig-out/wsl/image_qemu_cloud_ringserv.txt (os2_image.sh's), and this
# script's own steps above it in zig-out/wsl/cloud.txt.
set -u
cd "$(dirname "$0")/.." || exit 1
NAME=qemu_cloud_ringserv
HOST=machines/qemu_cloud.machine
PACKS=machines/ringserv.pack
STAGE=machines/ringserv.stage
H=zig-out/cross/x86_64-linux-musl/harb
PLACED=zig-out/placed/$NAME.machine
LOG=zig-out/wsl/cloud.txt
mkdir -p zig-out/placed zig-out/wsl
rm -f "$PLACED"
{
  echo "=== place: $PACKS on $HOST ==="
  "$H" place "$HOST" $PACKS --out "$PLACED" || { echo "JUDGED: the placement was refused, so there is nothing to boot"; exit 1; }
  [ -f "$PLACED" ] || { echo "place said it wrote $PLACED and it is not there"; exit 1; }
  [ -f zig-out/ringserv/ringserv ] || { echo "no RingServ under zig-out/ringserv (powershell experiment/ringserv_build.ps1)"; exit 1; }
  echo "=== boot the placed machine ==="
  HARB_MACHINE_FILE="$PLACED" HARB_STAGE="$STAGE" bash experiment/os2_image.sh "$NAME"
  RC=$?
  echo "os2_image.sh exit $RC"
  exit $RC
} 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
