#!/bin/bash
# mirror_restore.sh -- the source mirror judged by what CONSUMES it: a restore, and a rebuild with no network.
#
# STZ-OS-RULING-04 judged the first mirror by downloading it whole and checking every digest. Ruling 19's last item
# asks more: that a cloud be rebuilt from the mirror with no outside network at all. So this does three things:
#
#   1. restore    every file of the release, downloaded into an EMPTY directory, and `sha256sum -c SHA256SUMS`
#   2. no network a namespace with no interface but loopback; a request to the outside is made inside it and must fail
#   3. rebuild    inside that namespace, a copy of what this repository publishes (git's files, nothing it ignores)
#                 is given every pinned file from the restore ALONE -- the fetch scripts with HARB_MIRROR, which
#                 check each against vendor/PIN.md and ask the network nothing -- and then: harb built with the
#                 restored Linux Zig; the kernel built from the restored tarball, from nothing (a home of its own,
#                 so no cached build can stand in for it), and qemu_egress booted and judged against its pin; and
#                 RingServ built from the restored bundle with the same Zig
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/mirror_restore.sh [--from <dir>]
#
# --from <dir> restores from a directory instead of the release (mirror_make.sh's zig-out/mirror-release), to try the
# judge before anything is published. Run as root (a namespace with no network is made with `unshare -n`).
# Log: zig-out/wsl/mirror_restore.txt. Exit 0 only when every step above held.
set -u
cd "$(dirname "$0")/.." || exit 1
R=$PWD
TAG=vendor-mirror-2026-11-08
URL=https://github.com/mayouni/harobanda/releases/download/$TAG
FROM=""
[ "${1:-}" = --from ] && FROM=$(cd "${2:?--from needs a directory}" && pwd)
S=$HOME/harb-restore
LOG=$R/zig-out/wsl/mirror_restore.txt
mkdir -p "$R/zig-out/wsl"
rm -f "$LOG"
{
  [ "$(id -u)" = 0 ] || { echo "run as root: unshare -n needs it"; echo "exit 1"; exit 1; }
  rm -rf "$S"; mkdir -p "$S/mirror" "$S/home"
  M=$S/mirror

  echo "=== 1. restore: every file of the mirror, into an empty directory ==="
  if [ -n "$FROM" ]; then
    echo "from: the directory $FROM (a trial before publishing)"
    cp "$FROM"/* "$M/" || { echo "copy failed"; echo "exit 1"; exit 1; }
  else
    echo "from: the release $TAG of this repository"
    curl -4 -sSfL -o "$M/SHA256SUMS" "$URL/SHA256SUMS" || { echo "no SHA256SUMS at $URL"; echo "exit 1"; exit 1; }
    for f in $(awk '{sub(/^[*]/, "", $2); print $2}' "$M/SHA256SUMS"); do
      curl -4 -sSfL -o "$M/$f" "$URL/$f" || { echo "could not download $f"; echo "exit 1"; exit 1; }
    done
  fi
  (cd "$M" && sha256sum -c SHA256SUMS) | sed 's/^/sums: /'
  [ "${PIPESTATUS[0]}" = 0 ] || { echo "the restore does not match its own SHA256SUMS"; echo "exit 1"; exit 1; }
  echo "restored: $(ls "$M" | wc -l) files, $(du -sm "$M" | awk '{print $1}') MB, every one matching SHA256SUMS"

  echo "=== the copy: what this repository publishes, and nothing it ignores ==="
  T=$S/tree; mkdir -p "$T"
  git -c safe.directory='*' -C "$R" ls-files -z --cached --others --exclude-standard \
    | (cd "$R" && tar --null -T - -cf -) | tar -xf - -C "$T" || { echo "copy failed"; echo "exit 1"; exit 1; }
  echo "files: $(find "$T" -type f | wc -l); vendor/ holds: [$(cd "$T/vendor" && find . -type f | sort | tr '\n' ' ')]"

  echo "=== 2 and 3. with no network: every pinned file from the restore alone, then the rebuild ==="
  # everything below runs in ONE namespace with no network; HOME is a fresh one, so nothing cached on this host --
  # the extracted Zig, Zig's own cache, the kernel's build directories -- can stand in for what the restore gave
  cat > "$S/offline.sh" << 'OFFLINE'
set -u
cd "$T" || exit 1
export HOME=$S/home HARB_MIRROR=$M HARB_ZIG_DEST=$S/home/harb-zig ZIG_GLOBAL_CACHE_DIR=$S/home/zig-cache
step() { # $1 = label, then the command: its exit code is said, and a failure ends the run
  local label=$1; shift
  local t0=$SECONDS
  "$@" > "$S/step_$label.txt" 2>&1
  local rc=$?
  echo "$label: exit $rc ($((SECONDS - t0)) s)"
  [ "$rc" = 0 ] || { echo "$label FAILED -- its output:"; tail -15 "$S/step_$label.txt"; exit 1; }
}
echo "network: interfaces here, as the kernel says: $(ip -o link show | awk -F': ' '{print $2}' | tr '\n' ' ')"
if curl -4 -sS --max-time 8 -o /dev/null https://ziglang.org/ 2> /dev/null; then echo "network: ziglang.org ANSWERED -- this is not a run without a network"; exit 1; fi
echo "network: a request to ziglang.org failed -- there is no way out of this namespace"
step zig bash experiment/zigcc_fetch.sh
grep -E '^(pin|taken)' zig-out/wsl/zigcc_fetch.txt | sed 's/^/  /'
Z=$S/home/harb-zig/zig-x86_64-linux-0.15.2/zig
step kernel bash experiment/os2_kernel_fetch.sh
grep -E '^(pin|taken|vendor)' zig-out/wsl/kernel_fetch.txt | sed 's/^/  /'
step caddy bash experiment/caddy_fetch.sh
grep -E '^(taken|verified|extracted)' zig-out/wsl/caddy_fetch.txt | sed -E 's/ \(([0-9]+) bytes, sha256 [0-9a-f]+\)/ (\1 bytes)/; s/^/  /'
fw_check() { # the firmware in the restore against vendor/PIN.md's three digests
  local f want
  for f in start4.elf fixup4.dat LICENCE.broadcom; do
    want=$(awk -F'`' -v r="| $f sha256 |" 'index($0, r) == 1 {print $2; exit}' vendor/PIN.md)
    [ -n "$want" ] || { echo "vendor/PIN.md gives no digest for $f"; return 1; }
    [ "$(sha256sum "$M/$f" | awk '{print $1}')" = "$want" ] || { echo "$f does not match vendor/PIN.md"; return 1; }
  done
}
step firmware fw_check
echo "  the firmware in the restore matches vendor/PIN.md's three digests"
step harb "$Z" build cross -j2
echo "  harb built with the restored Zig: $(ls zig-out/cross | tr '\n' ' ')"
step boot bash experiment/os2_image.sh qemu_egress
grep -E '^JUDGED' zig-out/wsl/image_qemu_egress.txt | sed 's/^/  /'
# the kernel that booted was built HERE: under this run's own fresh home, so no build cached on this host stood in
KB=$(ls -d "$S"/home/harb-kernel/build/x86_64-* 2> /dev/null | head -1)
[ -n "$KB" ] && [ -f "$KB/arch/x86/boot/bzImage" ] || { echo "no kernel was built under this run's own home -- the boot used something else"; exit 1; }
echo "  the kernel was built in this run, from the restored tarball: $(basename "$KB")"
REF=$(awk -F'`' '/^\| ref \| `/ {print $2; exit}' vendor/PIN.md)
step ringserv_clone git clone -q "$M/ringserv-${REF:0:8}.bundle" "$S/ringserv" -b ringserv-pin
[ "$(git -C "$S/ringserv" rev-parse HEAD)" = "$REF" ] || { echo "the bundle did not give the pinned ref"; exit 1; }
echo "  the bundle gave $REF, the ref vendor/PIN.md pins"
step ringserv_build sh -c "cd '$S/ringserv' && '$Z' build -j2 -Dtarget=x86_64-linux-musl"
echo "  RingServ built from the bundle with the restored Zig: $(ls -1 "$S"/ringserv/zig-out/bin | tr '\n' ' ')"
exit 0
OFFLINE
  T=$T S=$S M=$M unshare -n -- bash -c "ip link set lo up 2> /dev/null; T='$T' S='$S' M='$M' bash '$S/offline.sh'"
  RC=$?
  if [ "$RC" = 0 ] && grep -q '^JUDGED: .* matches' "$T/zig-out/wsl/image_qemu_egress.txt"; then
    echo "RESTORED: every pinned file came from the mirror alone, and with no network harb, the kernel and RingServ were built from it and qemu_egress matched its pin"
    echo "exit 0"; exit 0
  fi
  echo "NOT RESTORED: the run above stopped or the boot did not match its pin (exit $RC)"
  echo "exit 1"; exit 1
} 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
