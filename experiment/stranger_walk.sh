#!/bin/bash
# stranger_walk.sh -- walk the tour's boots with only what a stranger has
# (LRN-3). A copy of the files this repository publishes -- what git tracks
# or would track, nothing it ignores -- goes into $HOME/harb-stranger: no
# zig-out, no stz build, no vendored kernel. The one concession: the kernel
# tarball is SEEDED from this copy's vendor/linux to spare a 142 MB
# download, and os2_kernel_fetch.sh then verifies it against the pin and
# kernel.org exactly as it would a download. The Linux zig is the pinned
# one experiment/zigcc_fetch.sh keeps under $HOME/harb-zig.
#
#   bash experiment/stranger_walk.sh [act ...]
#
#   act: a machine name, booted with os2_image.sh; `guarantees`
#        (judge_guarantees.sh); `names` (os6_names.sh); `fleet`
#        (os7_fleet.sh). Default: every boot the tour asks a reader for.
#
# This repository's own zig-out is never read or written, except for the
# report: zig-out/wsl/stranger.txt, and each act's log beside it.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
S=$HOME/harb-stranger
Z=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
W=$R/zig-out/wsl
LOG=$W/stranger.txt
mkdir -p "$W"
rm -f "$LOG"
# the tour's boots, in the tour's order: lessons 4-6 and 11, 7-9, 10, 12-13,
# 14, 15, 17 and 18
ACTS=${*:-qemu_egress qemu_confine qemu_budget qemu_identity fleet names makeen_box guarantees}
(
  echo "=== the stranger's copy ==="
  [ -x "$Z" ] || { echo "no Linux zig at $Z -- run experiment/zigcc_fetch.sh first"; exit 1; }
  mkdir -p "$S"
  # a fresh tree every walk, except the stranger's OWN build outputs, which
  # they would keep between tries too
  find "$S" -mindepth 1 -maxdepth 1 ! -name zig-out ! -name .zig-cache -exec rm -rf {} +
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$S" || { echo "copy failed"; exit 1; }
  if ls -d "$S"/zig-out/stz-* > /dev/null 2>&1; then
    echo "the copy holds an stz build -- that is not a stranger's"; exit 1
  fi
  echo "files: $(find "$S" -type f -not -path '*/zig-out/*' -not -path '*/.zig-cache/*' | wc -l)"
  echo "vendor/linux before the fetch: [$(ls "$S/vendor/linux" 2> /dev/null | tr '\n' ' ')]"
  cd "$S" || exit 1

  echo "=== zig build cross -j2 ==="
  "$Z" build cross -j2 > "$W/stranger_build.txt" 2>&1
  echo "exit $?"
  echo "built: $(ls zig-out/cross 2> /dev/null | tr '\n' ' ')"

  echo "=== bash experiment/os2_kernel_fetch.sh (the tarball seeded) ==="
  TARBALL=$(awk -F'`' '/^\| tarball \| `linux-/ {print $2; exit}' vendor/PIN.md)
  mkdir -p vendor/linux
  [ -e "vendor/linux/$TARBALL" ] || ln -s "$R/vendor/linux/$TARBALL" "vendor/linux/$TARBALL"
  bash experiment/os2_kernel_fetch.sh > /dev/null 2>&1
  echo "exit $?"
  cat zig-out/wsl/kernel_fetch.txt

  for a in $ACTS; do
    START=$(date +%s)
    case "$a" in
      guarantees) CMD=judge_guarantees.sh; OUT=zig-out/guarantees/makeen_box.txt ;;
      names) CMD=os6_names.sh; OUT=zig-out/wsl/names.txt ;;
      fleet) CMD=os7_fleet.sh; OUT=zig-out/wsl/fleet.txt ;;
      *) CMD="os2_image.sh $a"; OUT=zig-out/wsl/image_$a.txt ;;
    esac
    echo "=== bash experiment/$CMD ==="
    # shellcheck disable=SC2086
    bash experiment/$CMD > "$W/stranger_$a.console.txt" 2>&1
    echo "exit $? after $(( $(date +%s) - START ))s"
    [ -f "$OUT" ] && cp "$OUT" "$W/stranger_$a.txt"
    grep -h -E "NOT staged|image: refused|derive refused|kernel cache|JUDGED|not built|of 4 promised" \
      "$W/stranger_$a.console.txt" | head -12
    if [ -d "zig-out/image/$a" ]; then
      echo "left in zig-out/image/$a: $(ls "zig-out/image/$a" | tr '\n' ' ')"
    fi
  done
  echo "walk done"
) > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
