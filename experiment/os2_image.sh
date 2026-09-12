#!/bin/bash
# os2_image.sh -- the imperative half of OS-2, on a Linux host (WSL Ubuntu
# here). Stages the root, lets `stzos image` DERIVE the three artifacts,
# builds the vendored kernel over tinyconfig + the derived fragment, packs
# the initramfs with the kernel's own gen_init_cpio, boots it in QEMU with
# the serial console captured, and leaves the transcript beside the image.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh [machine-name]
#
# The kernel tree lives in $HOME (WSL-native): building on the Windows mount
# is an order of magnitude slower. The tarball and its pin stay in
# vendor/linux/ on the Windows side. Log: zig-out/wsl/image_<name>.txt
set -u
cd "$(dirname "$0")/.." || exit 1
NAME=${1:-qemu_hello}
M=machines/$NAME.machine
OUT=zig-out/image/$NAME
LOG=zig-out/wsl/image_$NAME.txt
K=$HOME/stzos-kernel
STZOS=zig-out/cross/x86_64-linux-musl/stzos
mkdir -p "$OUT" zig-out/wsl
{
  echo "=== stage ==="
  ROOT=$OUT/root; rm -rf "$ROOT"; mkdir -p "$ROOT/app"
  cp "$STZOS" "$ROOT/stzos"
  if [ -f zig-out/stz-x86_64-linux-musl/bin/stzr ]; then cp zig-out/stz-x86_64-linux-musl/bin/stzr "$ROOT/stzr"; echo "stzr staged"; else echo "stzr NOT staged (no Linux build of stz under zig-out/stz-x86_64-linux-musl)"; fi
  cp app/*.luau "$ROOT/app/" 2>/dev/null && echo "app staged"
  echo "=== derive ==="
  "$STZOS" image "$M" --root "$ROOT" --out "$OUT" || { echo "derive refused"; exit 1; }
  echo "--- initramfs.list"; cat "$OUT/initramfs.list"
  echo "--- kernel.fragment"; cat "$OUT/kernel.fragment"
  echo "--- boot.cmd"; cat "$OUT/boot.cmd"
  echo "=== kernel ==="
  PIN=$(cat vendor/linux/PIN.txt); TARBALL=${PIN%% *}; SRC=$K/${TARBALL%.tar.xz}
  echo "pin: $PIN"
  mkdir -p "$K"
  if [ ! -d "$SRC" ]; then echo "extracting into $K"; tar -xJf "vendor/linux/$TARBALL" -C "$K" || { echo "extract failed"; exit 1; }; fi
  cp "$OUT/kernel.fragment" "$SRC/stzos.fragment"
  (
    cd "$SRC" || exit 1
    make -s tinyconfig || exit 1
    scripts/kconfig/merge_config.sh -m .config stzos.fragment > /dev/null || exit 1
    make -s olddefconfig || exit 1
    echo "config: $(grep -c '=y' .config) options on"
    for o in 64BIT SERIAL_8250_CONSOLE BLK_DEV_INITRD DEVTMPFS PROC_FS BINFMT_ELF FUTEX; do grep -q "^CONFIG_$o=y" .config && echo "  CONFIG_$o=y" || echo "  CONFIG_$o MISSING"; done
    time make -j2 bzImage 2>&1 | tail -3
    make -s usr/gen_init_cpio || exit 1
  ) || { echo "kernel build failed"; exit 1; }
  cp "$SRC/arch/x86/boot/bzImage" "$OUT/bzImage" || exit 1
  echo "=== initramfs ==="
  "$SRC/usr/gen_init_cpio" "$OUT/initramfs.list" > "$OUT/initramfs.cpio" || { echo "cpio failed"; exit 1; }
  ls -la "$OUT" | grep -v '^total'
  echo "=== boot ==="
  ( cd "$OUT" && timeout 120 bash boot.cmd > transcript.txt 2>&1; echo "qemu exit $?" >> transcript.txt )
  # pid 1 of the QEMU boot after --no-reboot: the kernel restarts, QEMU exits 0
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
  if diff -u "machines/$NAME.expected" "$OUT/transcript.normalised" > "$OUT/transcript.diff"; then
    echo "JUDGED: the boot transcript matches machines/$NAME.expected line for line ($(wc -l < "$OUT/transcript.normalised") lines)"
  else
    echo "JUDGED: FAIL -- the transcript differs from machines/$NAME.expected:"; cat "$OUT/transcript.diff"
  fi
  echo "exit 0"
} > "$LOG" 2>&1
tail -3 "$LOG"
