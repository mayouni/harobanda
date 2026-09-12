#!/bin/bash
# zigcc_clean_vdso.sh -- drop the VDSO objects of the zig cc tree. They
# are the one part of the kernel compiled position-INDEPENDENT, so an
# object left over from a run whose flags were wrong survives an
# incremental build and fails the link with the same message forever.
S=$HOME/stzos-kernel/zigcc-${1:-x86_64}/linux-6.12.109/arch/x86/entry/vdso
rm -fv "$S"/*.o "$S"/*.so "$S"/*.so.dbg 2>/dev/null | tail -3
echo "vdso objects dropped"
