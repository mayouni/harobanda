#!/bin/bash
# zigcc_boot_diag.sh -- the zig cc kernel builds but prints nothing. Is it
# dead before the decompressor, or after it? earlyprintk speaks from the
# decompressor itself, before any console is set up.
cd "$(dirname "$0")/.." || exit 1
OUT=zig-out/image/qemu_hello
{
  echo "== the image under test =="
  ls -la "$OUT/bzImage"
  echo "== earlyprintk, 30 s =="
  ( cd "$OUT" && timeout --foreground 30 qemu-system-x86_64 -M pc -cpu max -m 256M -nographic -no-reboot \
      -kernel bzImage -initrd initramfs.cpio \
      -append "console=ttyS0 earlyprintk=serial,ttyS0,115200 loglevel=8 rdinit=/stzos -- init /etc/machine" < /dev/null 2>&1 | head -40 )
  echo "qemu exit $?"
} > zig-out/wsl/zigcc_boot_diag.txt 2>&1
cat zig-out/wsl/zigcc_boot_diag.txt
