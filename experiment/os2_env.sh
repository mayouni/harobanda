#!/bin/bash
# os2_env.sh -- the OS-2 build environment inside WSL Ubuntu, installed on
# the author's ruling of 2026-09-12 ("install qemu, gcc and make in WSL and
# go for OS-2"). Everything a minimal x86_64 kernel build and a QEMU boot
# need, nothing else. Output to zig-out/wsl/env.txt (read it from Windows).
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
{
  export DEBIAN_FRONTEND=noninteractive
  # port 80 is blocked on this network (probe: http times out, https answers 200): apt goes over https
  sed -i "s#http://#https://#g" /etc/apt/sources.list.d/ubuntu.sources
  apt-get -o Acquire::ForceIPv4=true update -qq
  apt-get -o Acquire::ForceIPv4=true install -y -qq --no-install-recommends \
    qemu-system-x86 gcc make flex bison bc libelf-dev libssl-dev cpio xz-utils curl ca-certificates perl python3 file
  echo "=== versions ==="
  gcc --version | head -1
  make --version | head -1
  qemu-system-x86_64 --version | head -1
  flex --version; bison --version | head -1; bc --version | head -1
  which cpio xz curl
  echo "exit $?"
} > zig-out/wsl/env.txt 2>&1
tail -12 zig-out/wsl/env.txt
