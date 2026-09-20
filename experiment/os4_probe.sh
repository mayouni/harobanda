#!/bin/bash
# os4_probe.sh -- what this host can do for a Raspberry Pi 4 image without
# the board: QEMU's raspi4b machine and its properties, the vendored
# kernel's BCM2711 support and device tree, the SD-image tools. Output:
# zig-out/wsl/os4_probe.txt
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl
SRC=$HOME/harb-kernel/arm64/linux-6.12.109
{
  echo "== qemu machines (raspi) =="; qemu-system-aarch64 -M help | grep -i raspi
  echo "== raspi4b properties =="; qemu-system-aarch64 -M raspi4b,help 2>&1 | head -20
  echo "== raspi4b devices =="; qemu-system-aarch64 -M raspi4b -nographic -monitor none -serial none -display none -S -qmp stdio <<< '{"execute":"qmp_capabilities"}{"execute":"query-block"}{"execute":"quit"}' 2>&1 | head -5
  echo "== kernel: bcm2711 dts =="; ls "$SRC/arch/arm64/boot/dts/broadcom/" | grep -i 2711
  echo "== kernel: ARCH_BCM options =="; grep -n -A3 'config ARCH_BCM2835' "$SRC/arch/arm64/Kconfig.platforms" | head -12
  echo "== kernel: genet / sdhci-iproc / bcm2835aux / mbox =="
  grep -n '^config BCMGENET\|^config MMC_SDHCI_IPROC\|^config SERIAL_8250_BCM2835AUX\|^config BCM2835_MBOX\|^config RASPBERRYPI_FIRMWARE\|^config MMC_BCM2835' -r "$SRC/drivers" | head
  echo "== tools =="; which sfdisk mkfs.vfat mtools mcopy losetup dd truncate; mcopy --version 2>&1 | head -1
  echo "== git =="; which git; git --version
} > zig-out/wsl/os4_probe.txt 2>&1
tail -2 zig-out/wsl/os4_probe.txt
