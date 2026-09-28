#!/bin/bash
# console_probe.sh -- where a machine's console really is (CON-1).
#
# CONSOLE is declared, announced and judged, and the kernel's console came
# from the board table all the same. Before deciding whether the boot line
# should follow the declaration, ask the question that decides: can the
# emulator LISTEN on whichever port a machine declares? Boots images that
# os2_image.sh already built, changing only the kernel's console= and which
# QEMU serial port feeds stdio, and counts what stdio heard. The Pi's card
# is a fresh copy of the pristine one each time, so no artifact is changed.
#
#   bash experiment/console_probe.sh     (after os2_image.sh qemu_egress
#                                          and os2_image.sh makeen_box)
# Output: zig-out/wsl/console_probe.txt, and each boot's raw text beside it.
cd "$(dirname "$0")/.." || exit 1
W=$PWD/zig-out/wsl
LOG=$W/console_probe.txt
mkdir -p "$W"
PC=zig-out/image/qemu_egress
PI=zig-out/image/makeen_box
(
  for f in "$PC/bzImage" "$PC/initramfs.cpio" "$PI/Image" "$PI/initramfs.cpio" "$PI/sd.pristine.img" "$PI/bcm2711-rpi-4-b.qemu.dtb"; do
    [ -f "$f" ] || { echo "missing $f -- boot qemu_egress and makeen_box with os2_image.sh first"; exit 1; }
  done
  # label, directory, seconds, qemu command...
  probe() {
    local label=$1 dir=$2 secs=$3; shift 3
    local raw="$W/console_probe_$label.txt"
    echo "=== $label"
    echo "    $*" | cut -c1-220
    ( cd "$dir" && timeout --foreground "$secs" "$@" < /dev/null > "$raw" 2>&1 )
    echo "    qemu exit $?; boot lines heard on stdio: $(grep -c 'boot:' "$raw")"
    grep -m2 -E 'boot: (harb init|console)' "$raw" | sed 's/^/    /'
    grep -m1 -E 'boot: judge' "$raw" | sed 's/^/    /'
  }
  X86="qemu-system-x86_64 -M pc -cpu max -m 256M -nographic -no-reboot -kernel bzImage -initrd initramfs.cpio -netdev user,id=n0 -device virtio-net-pci,netdev=n0"
  ARGS="quiet loglevel=3 rdinit=/harb -- init /etc/machine"
  # shellcheck disable=SC2086
  probe pc-ttyS0-as-today "$PC" 90 $X86 -append "console=ttyS0 $ARGS"
  # shellcheck disable=SC2086
  probe pc-ttyS3-unrouted "$PC" 60 $X86 -append "console=ttyS3 $ARGS"
  # shellcheck disable=SC2086
  probe pc-ttyS3-routed "$PC" 90 $X86 -serial null -serial null -serial null -serial mon:stdio -append "console=ttyS3 $ARGS"

  PIARGS="quiet loglevel=3 harb.slot=B harb.watchdog=off harb.expect=emulator rdinit=/harb -- init /etc/machine --halt-on-verdict"
  card() { cp "$PI/sd.pristine.img" /tmp/con1_sd.img; }
  RPI="qemu-system-aarch64 -M raspi4b -dtb bcm2711-rpi-4-b.qemu.dtb -nographic -no-reboot -kernel Image -initrd initramfs.cpio -drive file=/tmp/con1_sd.img,if=sd,format=raw"
  card
  # shellcheck disable=SC2086
  probe pi-ttyAMA0-as-today "$PI" 180 $RPI -append "console=ttyAMA0 $PIARGS"
  card
  # shellcheck disable=SC2086
  probe pi-ttyS1-unrouted "$PI" 120 $RPI -append "console=ttyS1,115200 $PIARGS"
  card
  # shellcheck disable=SC2086
  probe pi-ttyS1-routed "$PI" 180 $RPI -serial null -serial mon:stdio -append "console=ttyS1,115200 $PIARGS"
  rm -f /tmp/con1_sd.img
  echo "probe done"
) > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
