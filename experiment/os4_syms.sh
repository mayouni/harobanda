#!/bin/bash
# os4_syms.sh -- resolve kernel addresses from a panic against System.map
# (tinyconfig has no KALLSYMS, so the trace prints bare addresses).
#   os4_syms.sh <addr> [<addr> ...]      addresses as printed, with or without 0x
SRC=$HOME/stzos-kernel/arm64/linux-6.12.109
for a in "$@"; do
  a=${a#0x}
  awk -v want="$a" 'BEGIN{best=""} { if ($1 <= want) { best=$1" "$3 } else { exit } } END { print want" -> "best }' "$SRC/System.map"
done
