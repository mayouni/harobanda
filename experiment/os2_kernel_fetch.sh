#!/bin/bash
# os2_kernel_fetch.sh -- fetch the PINNED Linux LTS source once into
# vendor/linux/ (gitignored: the tarball is over GitHub's file limit, so the
# vendoring is by digest). The pin is vendor/PIN.md -- the committed record,
# and the only one a fresh clone has -- and this takes exactly the tarball
# it names. It used to take "the newest 6.12 point release", which on any
# day after the pin is a DIFFERENT kernel from the one every transcript here
# was judged on, and it wrote whatever it took into PIN.txt: a fetch that
# re-pinned silently (DOC-1). The tarball must match the pin AND kernel.org's
# own sha256sums.asc, or it is refused.
#
# Nothing is extracted here. os2_image.sh extracts into the Linux host's own
# filesystem ($HOME/harb-kernel), because a kernel tree on a Windows mount
# is an order of magnitude slower; this used to extract 1.4 GB beside the
# tarball that nothing ever read. Output: zig-out/wsl/kernel_fetch.txt
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl vendor/linux
LOG=zig-out/wsl/kernel_fetch.txt
(
  # the linux table in vendor/PIN.md: its tarball row, then the sha256 row
  # that follows it (the zig table further down has rows of the same names)
  NAME=$(awk -F'`' '/^\| tarball \| `linux-/ {print $2; exit}' vendor/PIN.md)
  SUM=$(awk -F'`' '/^\| tarball \| `linux-/ {f=1} f && /^\| sha256 \|/ {print $2; exit}' vendor/PIN.md)
  case "$NAME" in
    linux-*.tar.xz) ;;
    *) echo "vendor/PIN.md names no linux tarball -- refused"; exit 1 ;;
  esac
  if ! echo "$SUM" | grep -qE '^[0-9a-f]{64}$'; then
    echo "vendor/PIN.md has no sha256 of 64 hex for $NAME -- refused"; exit 1
  fi
  echo "pin: $NAME sha256 $SUM (vendor/PIN.md)"
  cd vendor/linux || exit 1
  BASE=https://cdn.kernel.org/pub/linux/kernel/v6.x
  curl -4 -sSf -o sha256sums.asc "$BASE/sha256sums.asc" || { echo "sha256sums fetch failed"; exit 1; }
  THEIRS=$(awk -v n="$NAME" '$2 == n {print $1; exit}' sha256sums.asc)
  if [ "$THEIRS" != "$SUM" ]; then
    echo "kernel.org says ${THEIRS:-nothing} for $NAME and the pin says $SUM -- refused"
    exit 1
  fi
  echo "kernel.org agrees with the pin"
  if [ ! -f "$NAME" ]; then
    curl -4 -sSf -o "$NAME" "$BASE/$NAME" || { echo "tarball fetch failed"; exit 1; }
  fi
  echo "$SUM  $NAME" | sha256sum -c - || { echo "DIGEST MISMATCH -- refused"; exit 1; }
  echo "$NAME $SUM" > PIN.txt
  echo "vendor/linux/$NAME -- verified; os2_image.sh extracts it where it builds"
  echo "exit 0"
) > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
