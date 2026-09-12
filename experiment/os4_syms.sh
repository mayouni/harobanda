#!/bin/bash
# os4_syms.sh -- resolve kernel addresses from a panic against the symbol
# map of the kernel that panicked (tinyconfig has no KALLSYMS, so a trace
# prints bare addresses).
#
#   os4_syms.sh [-m <machine>] <addr> [<addr> ...]
#
# The map is the one saved beside that machine's image by os2_image.sh
# (zig-out/image/<machine>/System.map, default machine makeen_box), never
# the kernel tree's: the tree's map belongs to whichever machine of that
# ARCH was built last. For each address, the greatest symbol at or below
# it is printed with the offset into it. Addresses are padded to 16 hex
# digits before the text comparison, and the offset is computed in bash
# (64-bit), not awk (a double loses the low bits of 0xffff8000...).
cd "$(dirname "$0")/.." || exit 1
MACHINE=makeen_box
if [ "${1:-}" = "-m" ]; then MACHINE=$2; shift 2; fi
MAP=zig-out/image/$MACHINE/System.map
[ -f "$MAP" ] || { echo "no $MAP -- run os2_image.sh $MACHINE first"; exit 1; }
echo "map: $MAP ($(wc -l < "$MAP") symbols)"
for a in "$@"; do
  a=$(printf '%016s' "$(echo "${a#0x}" | tr 'A-F' 'a-f')" | tr ' ' '0')
  line=$(awk -v want="$a" '{ if ($1 <= want) { best = $1 " " $3 } else { exit } } END { print best }' "$MAP")
  if [ -z "$line" ]; then echo "$a -> below the first symbol"; continue; fi
  best=${line%% *}; name=${line#* }
  off=$(( 0x$a - 0x$best ))
  printf '%s -> %s+0x%x\n' "$a" "$name" "$off"
done
