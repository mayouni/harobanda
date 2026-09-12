#!/bin/bash
# os4_diag.sh -- when the raspi4b boot prints nothing: boot the same image
# with an early console and the full log level, list the config facts that
# decide an early hang (from the config saved BESIDE the image, never the
# tree's -- that one belongs to whichever arm64 machine was built last), and
# show the emulator tree's aliases. Output: zig-out/wsl/os4_diag.txt
cd "$(dirname "$0")/.." || exit 1
OUT=zig-out/image/makeen_box
SRC=$HOME/stzos-kernel/arm64/linux-6.12.109
{
  echo "== config facts =="
  for o in ARM_GIC ARM_GIC_V3 ARM_ARCH_TIMER CLK_BCM2835 COMMON_CLK SERIAL_AMBA_PL011_CONSOLE SERIAL_8250_BCM2835AUX ARM64_4K_PAGES ARM64_VA_BITS_48 ARM64_VA_BITS_39 SMP PSCI ARM_PSCI_FW RASPBERRYPI_FIRMWARE MAILBOX BCM2835_MBOX PINCTRL_BCM2835 CLK_RASPBERRYPI ARM64_ERRATUM_843419 SERIAL_EARLYCON EARLY_PRINTK CMDLINE_FORCE DEBUG_LL; do
    grep -E "^CONFIG_$o=" "$OUT/kernel.config" || echo "# CONFIG_$o unset"
  done
  echo "== the emulator tree's aliases and chosen =="
  "$SRC/scripts/dtc/dtc" -q -I dtb -O dts "$OUT/bcm2711-rpi-4-b.qemu.dtb" | grep -A9 'aliases {' | head -12
  "$SRC/scripts/dtc/dtc" -q -I dtb -O dts "$OUT/bcm2711-rpi-4-b.qemu.dtb" | grep -A3 'chosen {' | head -5
  echo "== earlycon boot, 90 s, full log in zig-out/wsl/os4_diag_boot.txt =="
  ( cd "$OUT" && timeout 90 qemu-system-aarch64 -M raspi4b -dtb bcm2711-rpi-4-b.qemu.dtb -nographic -no-reboot -kernel Image -initrd initramfs.cpio -drive file=sd.img,if=sd,format=raw -append "earlycon=pl011,mmio32,0xfe201000 console=ttyAMA0 loglevel=8 rdinit=/stzos -- init /etc/machine" > ../../wsl/os4_diag_boot.txt 2>&1; echo "qemu exit $?" )
  echo "lines: $(wc -l < zig-out/wsl/os4_diag_boot.txt)"; echo "-- last 70 lines:"; grep -iE "mmc|sdhci|sdhost|blk|partition|p1 p2|genet|eth0|watchdog|wdt|mailbox|firmware" zig-out/wsl/os4_diag_boot.txt | head -40
} > zig-out/wsl/os4_diag.txt 2>&1
tail -3 zig-out/wsl/os4_diag.txt
