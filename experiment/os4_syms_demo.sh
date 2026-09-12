#!/bin/bash
# os4_syms_demo.sh -- exercise os4_syms.sh against the current Pi kernel's
# map: take three known symbols, add an offset inside each, and resolve. The
# names that come back must be the names we started from, with the offsets
# we added; an address below every symbol must say so.
cd "$(dirname "$0")/.." || exit 1
MAP=zig-out/image/makeen_box/System.map
A=$(awk '$3 ~ /^brcmstb_l2_intc_of_init/{print $1; exit}' "$MAP")
B=$(awk '$3=="kernel_init"{print $1; exit}' "$MAP")
C=$(awk '$3=="clk_gate_readl"{print $1; exit}' "$MAP")
echo "known: brcmstb_l2_intc_of_init=$A kernel_init=$B clk_gate_readl=$C"
A2=$(printf '%x' $(( 0x$A + 0x78 ))); B2=$(printf '%x' $(( 0x$B + 0x1c ))); C2=$(printf '%x' $(( 0x$C + 0x28 )))
bash experiment/os4_syms.sh "$A2" "$B2" "$C2" 0x0
