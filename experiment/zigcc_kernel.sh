#!/bin/bash
# zigcc_kernel.sh -- build the vendored kernel with OUR compiler instead of
# the host's gcc (ZIGCC-1). The architecture table has said since OS-2 that
# `zig cc` is the destination and gcc was the stand-in; this measures what
# that costs and whether the boot is the same.
#
#   wsl -d Ubuntu -- bash .../experiment/zigcc_kernel.sh [machine-name]
#
# A SEPARATE tree per arch under $HOME/harb-kernel/zigcc-<arch>/, so the
# gcc-built trees the three courts use stay intact and fast. The kernel
# detects clang from CC and configures itself accordingly, so tinyconfig,
# the merge and olddefconfig are all re-run under it. GNU binutils still
# link and strip: zig exposes a C front end, not ld.lld, so the honest
# claim is "the compiler is ours", not "no foreign tool in the chain".
# Log: zig-out/wsl/zigcc_<machine>.txt
set -u
cd "$(dirname "$0")/.." || exit 1
NAME=${1:-qemu_hello}
OUT=zig-out/image/$NAME
LOG=zig-out/wsl/zigcc_$NAME.txt
mkdir -p zig-out/wsl
ZIG=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
WRAP=$HOME/harb-zig/bin
{
  [ -x "$ZIG" ] || { echo "no zig at $ZIG -- run experiment/zigcc_fetch.sh first"; exit 1; }
  [ -f "$OUT/image.env" ] || { echo "no $OUT/image.env -- run os2_image.sh $NAME first"; exit 1; }
  . "$OUT/image.env"
  echo "machine $NAME: arch $ARCH, board $BOARD, kernel $KERNEL_ARTIFACT"
  # one wrapper per role; the kernel calls $(CC) in many shapes and a
  # single word is safer than "zig cc" with a space
  mkdir -p "$WRAP"
  cp experiment/zigcc_wrapper.sh "$WRAP/zigcc"; chmod +x "$WRAP/zigcc"
  export ZIGCC_REAL="$ZIG"
  printf '#!/bin/sh\nexec %s ar "$@"\n' "$ZIG" > "$WRAP/zigar"; chmod +x "$WRAP/zigar"
  "$WRAP/zigcc" --version | head -1
  PIN=$(cat vendor/linux/PIN.txt); TARBALL=${PIN%% *}; K=$HOME/harb-kernel/zigcc-$ARCH; SRC=$K/${TARBALL%.tar.xz}
  mkdir -p "$K"
  if [ ! -d "$SRC" ]; then echo "extracting into $K"; tar -xJf "vendor/linux/$TARBALL" -C "$K" || exit 1; fi
  cp "$OUT/kernel.fragment" "$SRC/harb.fragment"
  (
    cd "$SRC" || exit 1
    export ARCH CROSS_COMPILE
    M="make CC=$WRAP/zigcc HOSTCC=gcc"
    echo "=== tinyconfig ==="; $M -s tinyconfig 2>&1 | tail -5 || exit 1
    echo "=== merge + olddefconfig ==="
    scripts/kconfig/merge_config.sh -m .config harb.fragment > /dev/null || exit 1
    $M -s olddefconfig 2>&1 | tail -5 || exit 1
    echo "clang detected by kconfig: $(grep -c '^CONFIG_CC_IS_CLANG=y' .config) (1 = yes)"
    echo "version: $(grep '^CONFIG_CC_VERSION_TEXT' .config)"
    echo "config: $(grep -c '=y' .config) options on"
    grep -E '^CONFIG_[A-Z0-9_]+=y' harb.fragment | while read -r want; do
      grep -q "^$want\$" .config || echo "  $want DROPPED by olddefconfig"
    done
    echo "=== build ==="
    time $M -j2 "$(basename "$KERNEL_ARTIFACT")" > "$OLDPWD/zig-out/wsl/zigcc_build.txt" 2>&1
    rc=$?
    echo "make exit $rc"
    echo "-- lines: $(wc -l < "$OLDPWD/zig-out/wsl/zigcc_build.txt")"
    echo "-- every error line:"; grep -n -i -E 'error|unsupported|unknown argument|no such file' "$OLDPWD/zig-out/wsl/zigcc_build.txt" | head -25
    echo "-- the last 15:"; tail -15 "$OLDPWD/zig-out/wsl/zigcc_build.txt"
    [ $rc -eq 0 ] || exit 1
  ) || { echo "BUILD FAILED"; exit 1; }
  ls -la "$SRC/$KERNEL_ARTIFACT"
  echo "exit 0"
} > "$LOG" 2>&1
tail -30 "$LOG"
