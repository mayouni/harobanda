#!/bin/bash
# wsl_boot.sh -- exercise the Linux build of harb on the only Linux this
# host has (WSL Ubuntu), three ways, writing the transcripts to
# zig-out/wsl/ so a Windows session can read them byte for byte:
#   1. a rehearsal from an ordinary pid (mounts narrated, services spawned)
#   2. the refusal: init from an ordinary pid without --rehearse
#   3. PID 1 for real, inside a user+pid+mount namespace (unshare)
# --turns 12, not 8, since HLT-1: the run has to outlive one HEALTH window
# (signals declares 2 s and, being a flock that creates its path once and
# never touches it again, is exactly the world HEALTH exists to catch).
# Run from Windows:  wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/wsl_boot.sh
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
B=zig-out/cross/x86_64-linux-musl/harb
M=machines/wsl_rehearsal.machine
# the declared signals are files: a run must not inherit the last run's
# (a stale signal would make a daemon ready before it ever started)
rm -f /tmp/harb-signals.ready /tmp/harb-mute.ready

{
  $B version; echo "exit $?"
  echo "=== 1. rehearsal from an ordinary pid ==="
  timeout 20 $B init $M --rehearse --turns 12; echo "exit $?"
  echo "=== 2. init from an ordinary pid, no --rehearse ==="
  $B init $M; echo "exit $?"
} > zig-out/wsl/rehearsal.txt 2>&1

rm -f /tmp/harb-signals.ready /tmp/harb-mute.ready
{
  echo "=== 3. PID 1 inside a user+pid+mount namespace ==="
  timeout 20 unshare -Urpf --mount-proc $B init $M --turns 12; echo "exit $?"
} > zig-out/wsl/pid1.txt 2>&1
rm -f /tmp/harb-signals.ready /tmp/harb-mute.ready

echo "wsl_boot: transcripts in zig-out/wsl/"
