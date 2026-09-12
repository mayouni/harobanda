#!/bin/bash
# wsl_boot.sh -- exercise the Linux build of stzos on the only Linux this
# host has (WSL Ubuntu), three ways, writing the transcripts to
# zig-out/wsl/ so a Windows session can read them byte for byte:
#   1. a rehearsal from an ordinary pid (mounts narrated, services spawned)
#   2. the refusal: init from an ordinary pid without --rehearse
#   3. PID 1 for real, inside a user+pid+mount namespace (unshare)
# Run from Windows:  wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/wsl_boot.sh
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
B=zig-out/cross/x86_64-linux-musl/stzos
M=machines/wsl_rehearsal.machine

{
  $B version; echo "exit $?"
  echo "=== 1. rehearsal from an ordinary pid ==="
  timeout 20 $B init $M --rehearse --turns 8; echo "exit $?"
  echo "=== 2. init from an ordinary pid, no --rehearse ==="
  $B init $M; echo "exit $?"
} > zig-out/wsl/rehearsal.txt 2>&1

{
  echo "=== 3. PID 1 inside a user+pid+mount namespace ==="
  timeout 20 unshare -Urpf --mount-proc $B init $M --turns 8; echo "exit $?"
} > zig-out/wsl/pid1.txt 2>&1

echo "wsl_boot: transcripts in zig-out/wsl/"
