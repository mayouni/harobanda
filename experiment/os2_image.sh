#!/bin/bash
# os2_image.sh -- the imperative half of the image, on a Linux host (WSL
# Ubuntu here). Stages the root, lets `stzos image` DERIVE the artifacts,
# builds the vendored kernel over tinyconfig + the derived fragment for the
# derived ARCH, packs the initramfs with the kernel's own gen_init_cpio,
# makes the declared disks, boots QEMU with the serial console captured,
# and judges the transcript against machines/<name>.expected.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh [machine-name]
#
# One kernel tree per ARCH under $HOME (WSL-native: building on the Windows
# mount is an order of magnitude slower). The tarball and its pin stay in
# vendor/linux/ on the Windows side. Log: zig-out/wsl/image_<name>.txt
set -u
cd "$(dirname "$0")/.." || exit 1
NAME=${1:-qemu_hello}
M=machines/$NAME.machine
OUT=zig-out/image/$NAME
LOG=zig-out/wsl/image_$NAME.txt
K=$HOME/stzos-kernel
HOST_STZOS=zig-out/cross/x86_64-linux-musl/stzos
mkdir -p "$OUT" zig-out/wsl
{
  echo "=== derive (arch) ==="
  # a first derivation with an empty root only to learn the triple; refused is expected
  mkdir -p "$OUT/empty"
  "$HOST_STZOS" image "$M" --root "$OUT/empty" --out "$OUT" > /dev/null 2>&1 || true
  if [ ! -f "$OUT/image.env" ]; then "$HOST_STZOS" image "$M" --root "$OUT/empty" --out "$OUT"; echo "derive refused before staging"; exit 1; fi
  . "$OUT/image.env"
  echo "arch $ARCH, triple $TRIPLE, cross '${CROSS_COMPILE}', kernel $KERNEL_ARTIFACT"
  echo "=== stage ==="
  ROOT=$OUT/root; rm -rf "$ROOT"; mkdir -p "$ROOT/app"
  cp "zig-out/cross/$TRIPLE/stzos" "$ROOT/stzos" || { echo "no stzos for $TRIPLE (zig build cross)"; exit 1; }
  if [ -f "zig-out/stz-$TRIPLE/bin/stzr" ]; then cp "zig-out/stz-$TRIPLE/bin/stzr" "$ROOT/stzr"; echo "stzr staged ($TRIPLE)"; else echo "stzr NOT staged (no build of stz under zig-out/stz-$TRIPLE)"; fi
  cp app/*.luau "$ROOT/app/" 2>/dev/null && echo "app staged"
  echo "=== derive ==="
  "$HOST_STZOS" image "$M" --root "$ROOT" --out "$OUT" || { echo "derive refused"; exit 1; }
  for f in initramfs.list kernel.fragment image.env disk.list boot.cmd; do echo "--- $f"; cat "$OUT/$f"; done
  echo "=== kernel ==="
  PIN=$(cat vendor/linux/PIN.txt); TARBALL=${PIN%% *}; SRC=$K/$ARCH/${TARBALL%.tar.xz}
  echo "pin: $PIN"
  mkdir -p "$K/$ARCH"
  if [ ! -d "$SRC" ]; then echo "extracting into $K/$ARCH"; tar -xJf "vendor/linux/$TARBALL" -C "$K/$ARCH" || { echo "extract failed"; exit 1; }; fi
  cp "$OUT/kernel.fragment" "$SRC/stzos.fragment"
  (
    cd "$SRC" || exit 1
    export ARCH CROSS_COMPILE
    make -s tinyconfig || exit 1
    scripts/kconfig/merge_config.sh -m .config stzos.fragment > /dev/null || exit 1
    make -s olddefconfig || exit 1
    echo "config: $(grep -c '=y' .config) options on"
    # every option the fragment asked for must survive olddefconfig; one that
    # did not is a dependency the fragment forgot, and it is named here
    grep -E '^CONFIG_[A-Z0-9_]+=y' stzos.fragment | while read -r want; do
      grep -q "^$want\$" .config && echo "  $want" || echo "  $want DROPPED by olddefconfig -- a dependency is missing from the fragment"
    done
    time make -j2 "$(basename "$KERNEL_ARTIFACT")" 2>&1 | tail -3
    make -s usr/gen_init_cpio || exit 1
  ) || { echo "kernel build failed"; exit 1; }
  cp "$SRC/$KERNEL_ARTIFACT" "$OUT/$KERNEL_IMAGE" || exit 1
  echo "=== initramfs ==="
  "$SRC/usr/gen_init_cpio" "$OUT/initramfs.list" > "$OUT/initramfs.cpio" || { echo "cpio failed"; exit 1; }
  echo "=== disks ==="
  grep -v '^#' "$OUT/disk.list" | while read -r id dev fs size img; do
    [ -z "$id" ] && continue
    rm -f "$OUT/$img"; truncate -s "${size}M" "$OUT/$img"
    case "$fs" in
      ext4) mkfs.ext4 -F -q -L "$id" "$OUT/$img" ;;
      vfat) mkfs.vfat -n "$id" "$OUT/$img" > /dev/null ;;
    esac
    echo "$id: $img $fs ${size}M -> $dev"
  done
  ls -la "$OUT" | grep -v '^total' | grep -v ' root$\| empty$'
  echo "=== boot ==="
  ( cd "$OUT" && timeout 180 bash boot.cmd > transcript.txt 2>&1; echo "qemu exit $?" >> transcript.txt )
  echo "--- transcript"; cat "$OUT/transcript.txt"
  echo "=== judge ==="
  # The transcript is the fixture. Normalise what no two boots share -- the
  # firmware banner and terminal control bytes before PID 1's first line,
  # CRs, and the pids the kernel hands out to the SERVICES -- and diff the
  # rest against the pinned expectation. "pid 1" is kept literal: that init
  # IS PID 1 is the claim the judge must be able to convict (the first
  # judge run normalised it away and was corrected, PROTOCOL.md OS-2).
  # Anything else that differs is a finding.
  sed -e 's/\r$//' "$OUT/transcript.txt" \
    | sed -n '/^.*boot: stzos init/,$p' | sed -e 's/^.*boot: stzos init/boot: stzos init/' \
    | sed -E 's/pid ([2-9]|[1-9][0-9]+)\b/pid N/g' \
    | sed -e '/^qemu exit/d' > "$OUT/transcript.normalised"
  if [ ! -f "machines/$NAME.expected" ]; then
    echo "JUDGED: no expectation pinned for $NAME yet -- machines/$NAME.expected is missing; this boot's normalised transcript is at $OUT/transcript.normalised"
  elif diff -u "machines/$NAME.expected" "$OUT/transcript.normalised" > "$OUT/transcript.diff"; then
    echo "JUDGED: the boot transcript matches machines/$NAME.expected line for line ($(wc -l < "$OUT/transcript.normalised") lines)"
  else
    echo "JUDGED: FAIL -- the transcript differs from machines/$NAME.expected:"; cat "$OUT/transcript.diff"
  fi
  echo "exit 0"
} > "$LOG" 2>&1
tail -3 "$LOG"
