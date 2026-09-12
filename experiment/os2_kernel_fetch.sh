#!/bin/bash
# os2_kernel_fetch.sh -- fetch the Linux LTS 6.12 source ONCE into
# vendor/linux/ (gitignored: the tarball is over GitHub's file limit, so the
# vendoring is by digest -- vendor/PIN.md records the name and sha256 and
# this script refuses a tarball that does not match). Verified against
# kernel.org's own sha256sums.asc, then extracted. Output: zig-out/wsl/kernel_fetch.txt
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl vendor/linux
{
  cd vendor/linux || exit 1
  BASE=https://cdn.kernel.org/pub/linux/kernel/v6.x
  curl -4 -sSf -o sha256sums.asc "$BASE/sha256sums.asc" || { echo "sha256sums fetch failed"; exit 1; }
  LINE=$(grep -E ' linux-6\.12\.[0-9]+\.tar\.xz$' sha256sums.asc | sort -k2 -V | tail -1)
  NAME=$(echo "$LINE" | awk '{print $2}')
  SUM=$(echo "$LINE" | awk '{print $1}')
  echo "pin: $NAME sha256 $SUM"
  if [ ! -f "$NAME" ]; then
    curl -4 -sSf -o "$NAME" "$BASE/$NAME" || { echo "tarball fetch failed"; exit 1; }
  fi
  echo "$SUM  $NAME" | sha256sum -c - || { echo "DIGEST MISMATCH -- refused"; exit 1; }
  DIR=${NAME%.tar.xz}
  if [ ! -d "$DIR" ]; then
    tar -xJf "$NAME" || { echo "extract failed"; exit 1; }
  fi
  echo "source: vendor/linux/$DIR"
  ls "$DIR" | head -5
  echo "$NAME $SUM" > PIN.txt
  echo "exit 0"
} > zig-out/wsl/kernel_fetch.txt 2>&1
cat zig-out/wsl/kernel_fetch.txt
