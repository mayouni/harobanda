#!/bin/bash
# zigcc_fetch.sh -- fetch the Linux Zig toolchain ONCE, by digest, into
# vendor/zig/ (gitignored, like the kernel tarball), and extract it inside
# WSL where the kernel is built. The Windows Zig cross-compiles harb for
# Linux, but driving `make` needs a native Linux compiler, and this is the
# one whose C front end the kernel will be built with (ZIGCC-1).
# Output: zig-out/wsl/zigcc_fetch.txt
set -u
cd "$(dirname "$0")/.." || exit 1
ROOT=$PWD
mkdir -p zig-out/wsl vendor/zig
# the pin is vendor/PIN.md's Linux Zig table, its tarball row and the sha256 row after it -- read, never restated
# here, so that the file and this script cannot disagree (HDW-1; the script carried its own copy until LOSS-1's seat)
NAME=$(awk -F'`' '/^\| tarball \| `zig-x86_64-linux-/ {print $2; exit}' vendor/PIN.md)
SUM=$(awk -F'`' '/^\| tarball \| `zig-x86_64-linux-/ {f=1} f && /^\| sha256 \|/ {print $2; exit}' vendor/PIN.md)
VER=$(echo "$NAME" | sed -E 's/^zig-x86_64-linux-([0-9.]+)\.tar\.xz$/\1/')
DEST=${HARB_ZIG_DEST:-$HOME/harb-zig}
{
  case "$NAME" in zig-x86_64-linux-*.tar.xz) ;; *) echo "vendor/PIN.md names no Linux zig tarball -- refused"; exit 1 ;; esac
  echo "$SUM" | grep -qE '^[0-9a-f]{64}$' || { echo "vendor/PIN.md has no sha256 of 64 hex for $NAME -- refused"; exit 1; }
  echo "pin: $NAME sha256 $SUM"
  cd "$ROOT/vendor/zig" || exit 1
  if [ -n "${HARB_MIRROR:-}" ]; then
    # the estate's mirror, restored to a directory: copied from there, nothing asked of the network
    [ -f "$HARB_MIRROR/$NAME" ] || { echo "the mirror at $HARB_MIRROR holds no $NAME -- refused"; exit 1; }
    cp "$HARB_MIRROR/$NAME" "$NAME.part" && mv "$NAME.part" "$NAME" || { echo "copy from the mirror failed"; exit 1; }
    echo "taken from the mirror at $HARB_MIRROR: the network not asked, the pin is the judge"
  elif [ ! -f "$NAME" ]; then
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
STATUS=$?
# the verdict is the block's, never tail's (VDCT-1): `cd ... && tail` used to be the last command, so a refused
# digest exited 0 -- and its relative cd failed from inside vendor/zig, so a good fetch exited 1 (found by the
# source mirror's restore, the first caller to read this script's exit code)
cd "$ROOT" && tail -5 zig-out/wsl/zigcc_fetch.txt
exit $STATUS
