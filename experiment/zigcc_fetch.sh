#!/bin/bash
# zigcc_fetch.sh -- fetch the Linux Zig toolchain ONCE, by digest, into
# vendor/zig/ (gitignored, like the kernel tarball), and extract it inside
# WSL where the kernel is built. The Windows Zig cross-compiles harb for
# Linux, but driving `make` needs a native Linux compiler, and this is the
# one whose C front end the kernel will be built with (ZIGCC-1).
# Output: zig-out/wsl/zigcc_fetch.txt
set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl vendor/zig
VER=0.15.2
NAME=zig-x86_64-linux-$VER.tar.xz
SUM=02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239
DEST=$HOME/harb-zig
{
  echo "pin: $NAME sha256 $SUM"
  cd "$(dirname "$0")/../vendor/zig" || exit 1
  if [ ! -f "$NAME" ]; then
    curl -4 -sSfL -o "$NAME" "https://ziglang.org/download/$VER/$NAME" || { echo "fetch failed"; exit 1; }
  fi
  echo "$SUM  $NAME" | sha256sum -c - || { echo "DIGEST MISMATCH -- refused"; exit 1; }
  echo "$NAME $SUM" > PIN.txt
  mkdir -p "$DEST"
  if [ ! -x "$DEST/${NAME%.tar.xz}/zig" ]; then
    tar -xJf "$NAME" -C "$DEST" || { echo "extract failed"; exit 1; }
  fi
  Z="$DEST/${NAME%.tar.xz}/zig"
  echo "zig: $Z"
  "$Z" version
  "$Z" cc --version | head -2
  echo "exit 0"
} > zig-out/wsl/zigcc_fetch.txt 2>&1
cd "$(dirname "$0")/.." && tail -5 zig-out/wsl/zigcc_fetch.txt
