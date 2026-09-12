#!/bin/bash
# os4_dt_probe.sh -- the BCM2711 device-tree nodes QEMU's raspi4b does not
# model (the AON L2 interrupt controller faulted the first boot), and the
# in-tree dtc that can disable them for the emulator court.
S=$HOME/stzos-kernel/arm64/linux-6.12.109
D=$S/arch/arm/boot/dts/broadcom   # the bcm2711 dtsi files live under arm/, included by the arm64 dts
{
  echo "== 7ef00100 in bcm2711.dtsi =="; grep -n -B2 -A8 '7ef00100' "$D/bcm2711.dtsi" | head -30
  echo "== l2-intc users =="; grep -n 'l2-intc\|aon_intr' "$D/bcm2711.dtsi" "$D/bcm2711-rpi.dtsi" "$D/bcm2711-rpi-4-b.dts" | head -12
  echo "== dtc =="; ls -la "$S/scripts/dtc/dtc" 2>&1; which dtc
  echo "== emmc2 / mailbox / watchdog nodes =="; grep -n 'emmc2\|mailbox@\|watchdog@\|compatible = "brcm,bcm2711-emmc2"\|brcm,bcm2835-pm' "$D/bcm2711.dtsi" "$D/bcm283x.dtsi" | head -12
} > "$(dirname "$0")/../zig-out/wsl/os4_dt_probe.txt" 2>&1
cat "$(dirname "$0")/../zig-out/wsl/os4_dt_probe.txt"
