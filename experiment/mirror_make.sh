#!/bin/bash
# mirror_make.sh -- stage the estate's source mirror: every file vendor/PIN.md pins, each checked against the pin
# before it is staged (STZ-OS-RULING-04, and ruling 19's last item). Nothing is uploaded here: the files, their
# SHA256SUMS and MIRROR.txt land in zig-out/mirror-release/, and publishing them is a separate act
# (`gh release create`), named in MIRROR.txt.
#
# What a file is checked against is vendor/PIN.md and nothing else: a file whose digest is not the pin's refuses the
# whole mirror. RingServ is pinned by its git REF, so its bundle is checked by cloning it and reading the ref back.
#
#   bash experiment/mirror_make.sh
#
# Output: zig-out/mirror-release/ and zig-out/wsl/mirror_make.txt. Exit 0 only with every file staged and checked.
set -u
cd "$(dirname "$0")/.." || exit 1
OUT=zig-out/mirror-release
LOG=zig-out/wsl/mirror_make.txt
mkdir -p zig-out/wsl
rm -f "$LOG"

# a cell of vendor/PIN.md: the value in backticks of the first row named $2 at or after the first row matching $1
cell() { awk -F'`' -v start="$1" -v row="$2" 'index($0, start) == 1 {f = 1} f && index($0, "| " row " |") == 1 {print $2; exit}' vendor/PIN.md; }

{
  rm -rf "$OUT"; mkdir -p "$OUT"
  fail=0
  stage() { # $1 = path under vendor/, $2 = sha256|sha512, $3 = the digest the pin gives
    local f=$1 kind=$2 want=$3 got
    [ -n "$want" ] || { echo "REFUSED: vendor/PIN.md gives no $kind for $(basename "$f")"; fail=1; return; }
    [ -f "$f" ] || { echo "REFUSED: $f is not here -- fetch it first"; fail=1; return; }
    got=$(${kind}sum "$f" | awk '{print $1}')
    if [ "$got" != "$want" ]; then echo "REFUSED: $f has $kind $got and the pin says $want"; fail=1; return; fi
    cp "$f" "$OUT/"
    echo "staged: $(basename "$f") -- $kind matches vendor/PIN.md ($(stat -c %s "$f") bytes)"
  }

  KNAME=$(cell '| tarball | `linux-' tarball)
  stage "vendor/linux/$KNAME" sha256 "$(cell '| tarball | `linux-' sha256)"
  ZL=$(cell '| tarball | `zig-x86_64-linux-' tarball)
  stage "vendor/zig/$ZL" sha256 "$(cell '| tarball | `zig-x86_64-linux-' sha256)"
  ZW=$(cell '| archive | `zig-x86_64-windows-' archive)
  stage "vendor/zig/$ZW" sha256 "$(cell '| archive | `zig-x86_64-windows-' sha256)"
  CN=$(cell '| tarball | `caddy_' tarball)
  stage "vendor/caddy/$CN" sha512 "$(cell '| tarball | `caddy_' sha512)"
  stage vendor/rpi-firmware/start4.elf sha256 "$(cell '| tag | `' 'start4.elf sha256')"
  stage vendor/rpi-firmware/fixup4.dat sha256 "$(cell '| tag | `' 'fixup4.dat sha256')"
  stage vendor/rpi-firmware/LICENCE.broadcom sha256 "$(cell '| tag | `' 'LICENCE.broadcom sha256')"

  # RingServ: the bundle must give back the ref the pin names, and nothing is read of it but its git objects
  REF=$(awk -F'`' '/^\| ref \| `/ {print $2; exit}' vendor/PIN.md)
  B=vendor/ringserv/ringserv-${REF:0:8}.bundle
  T=$(mktemp -d)
  if [ -z "$REF" ]; then echo "REFUSED: vendor/PIN.md names no RingServ ref"; fail=1
  elif [ ! -f "$B" ]; then echo "REFUSED: $B is not here"; fail=1
  elif ! git clone -q --no-checkout "$B" "$T/r" -b ringserv-pin 2> /dev/null; then echo "REFUSED: $B does not clone"; fail=1
  elif [ "$(git -C "$T/r" rev-parse HEAD)" != "$REF" ]; then echo "REFUSED: $B gives $(git -C "$T/r" rev-parse HEAD), and the pin names $REF"; fail=1
  else cp "$B" "$OUT/"; echo "staged: $(basename "$B") -- cloned, and its branch ringserv-pin is the pinned ref ($(stat -c %s "$B") bytes)"; fi
  rm -rf "$T"

  [ "$fail" = 0 ] || { echo "the mirror is NOT staged: a file above is refused"; echo "exit 1"; exit 1; }

  {
    echo "Harobanda's source mirror -- every file vendor/PIN.md pins, checked against it before it was staged."
    echo "The pins in the repository are the authority; this list and SHA256SUMS let the mirror be checked on its own."
    echo "Restore and check: experiment/mirror_restore.sh (or: download every asset, then sha256sum -c SHA256SUMS)."
    echo
    echo "$KNAME -- the kernel's source (GPL-2.0, its own COPYING inside); pin: the linux table, sha256"
    echo "$ZL -- the Linux Zig (MIT, its LICENSE inside); pin: the Linux Zig table, sha256"
    echo "$ZW -- the Windows Zig that builds harb (MIT, its LICENSE inside); pin: the Windows Zig table, sha256"
    echo "$CN -- Caddy, the front's proxy (Apache-2.0, its LICENSE inside); pin: the Caddy table, sha512"
    echo "$(basename "$B") -- RingServ's source at $REF, a git bundle (MIT, its LICENSE inside); pin: the RingServ ref"
    echo "start4.elf, fixup4.dat -- the Pi 4 firmware (Broadcom's licence, LICENCE.broadcom, beside them); pin: the firmware table"
    echo
    echo "Not here, by the author's ruling of 2026-11-08 (\"leave them out and say so\"): the host's build tools (gcc, make, flex, bison, bc) and QEMU, Ubuntu's compiled packages. A rebuild from this mirror alone still needs an Ubuntu archive for them."
  } > "$OUT/MIRROR.txt"
  # the sums cover MIRROR.txt too: written after it, so the restore downloads nothing it does not check
  # (plain "digest  name" lines: Git Bash's sha256sum marks every name with `*` for binary mode, and a name with a
  # mark is not a file the release has)
  ( cd "$OUT" && sha256sum -- * | sed 's/ [*]/  /' > SHA256SUMS )
  echo "=== staged in $OUT ==="
  for f in "$OUT"/*; do echo "$(stat -c %s "$f") $(basename "$f")"; done
  echo "exit 0"
} 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
