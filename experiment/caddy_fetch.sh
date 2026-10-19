#!/bin/bash
# caddy_fetch.sh -- fetch the Caddy release vendor/PIN.md pins, verify it by digest, extract the one binary.
#
# Caddy is the proxy that terminates TLS in front of a cloud (STZ-OS-RULING-18): the estate's rule is that no
# repository vendors a TLS or crypto stack, and the front is a program placed by a pack like any server.
# It is vendored the way the kernel is -- by DIGEST, never committed: the release archive is fetched from
# GitHub, refused unless its sha512 is the one vendor/PIN.md records (the digest Caddy publishes beside the
# release, read once and written there), and the `caddy` binary inside it goes to zig-out/caddy/caddy, which
# machines/front.stage names. vendor/caddy/ keeps the archive (gitignored) and PIN.txt, the record of what
# was taken.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/caddy_fetch.sh
#
# Output: zig-out/wsl/caddy_fetch.txt. Exit 0 only with a verified archive and an extracted binary.
set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p zig-out/wsl vendor/caddy zig-out/caddy
LOG=zig-out/wsl/caddy_fetch.txt
{
  # the caddy table in vendor/PIN.md: its tarball row, then the sha512 row
  NAME=$(awk -F'`' '/^\| tarball \| `caddy_/ {print $2; exit}' vendor/PIN.md)
  SUM=$(awk -F'`' '/^\| tarball \| `caddy_/ {f=1} f && /^\| sha512 \|/ {print $2; exit}' vendor/PIN.md)
  VER=$(echo "$NAME" | sed -E 's/^caddy_([0-9.]+)_linux_amd64\.tar\.gz$/\1/')
  case "$NAME" in
    caddy_*_linux_amd64.tar.gz) ;;
    *) echo "vendor/PIN.md names no caddy tarball -- refused"; exit 1 ;;
  esac
  if ! echo "$SUM" | grep -qE '^[0-9a-f]{128}$'; then
    echo "vendor/PIN.md has no sha512 of 128 hex for $NAME -- refused"; exit 1
  fi
  URL="https://github.com/caddyserver/caddy/releases/download/v$VER/$NAME"
  echo "pin: $NAME"
  echo "sha512: $SUM"
  if [ ! -f "vendor/caddy/$NAME" ]; then
    echo "fetching $URL"
    curl -4 -sSfL -o "vendor/caddy/$NAME.part" "$URL" || { echo "fetch failed"; rm -f "vendor/caddy/$NAME.part"; exit 1; }
    mv "vendor/caddy/$NAME.part" "vendor/caddy/$NAME"
  else
    echo "already here: vendor/caddy/$NAME"
  fi
  GOT=$(sha512sum "vendor/caddy/$NAME" | awk '{print $1}')
  if [ "$GOT" != "$SUM" ]; then
    echo "REFUSED: vendor/caddy/$NAME has sha512 $GOT, and the pin says $SUM"
    rm -f "vendor/caddy/$NAME"
    exit 1
  fi
  echo "verified: sha512 matches the pin"
  rm -f zig-out/caddy/caddy
  tar -xzf "vendor/caddy/$NAME" -C zig-out/caddy caddy || { echo "the archive holds no caddy binary"; exit 1; }
  chmod +x zig-out/caddy/caddy
  BIN_SUM=$(sha256sum zig-out/caddy/caddy | awk '{print $1}')
  echo "extracted: zig-out/caddy/caddy ($(stat -c %s zig-out/caddy/caddy) bytes, sha256 $BIN_SUM)"
  zig-out/caddy/caddy version | head -1
  {
    echo "tarball $NAME"
    echo "sha512 $SUM"
    echo "binary zig-out/caddy/caddy sha256 $BIN_SUM"
    echo "fetched $(date -u +%Y-%m-%dT%H:%M:%SZ) from $URL"
  } > vendor/caddy/PIN.txt
  echo "record: vendor/caddy/PIN.txt"
  echo "exit 0"
} 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
