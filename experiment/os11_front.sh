#!/bin/bash
# os11_front.sh -- the front of a cloud placed on a machine and booted (FRONT-1).
#
# The scene is the port half of the cloud ladder's rung 3b made whole on one machine
# (doc/CLOUD.md): machines/qemu_front.machine grants, three packs are placed on it in
# order -- the server (machines/ringserv.pack), the front (machines/front.pack: Caddy,
# STZ-OS-RULING-18, ending TLS on 443 as an identity that is not root and binding no
# other port) and three questions to the front (machines/front_witness.pack) -- and the
# result is imaged, booted and judged like any machine, against machines/qemu_front_placed.expected.
#
# The root the front signs under is made HERE, by hand, before the image: a private key
# and a self-signed certificate (openssl), seeded on the data disk owned by the front's
# identity (experiment/front_seed.sh, through os2_image.sh's HARB_DISK_SEED), with only
# the public half staged into the image for the questions that must trust it. The floor
# never generates it, and neither does Caddy. Its fingerprint is printed here and said by
# the questions in the transcript, where the judge reads it as KEY1: a root made once per
# run is a different root every run, and the pin holds that it is ONE root, declared and
# trusted, never which.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os11_front.sh
#
# Needs RingServ built (powershell experiment/ringserv_build.ps1), Caddy fetched
# (experiment/caddy_fetch.sh) and the cross build. Log: zig-out/wsl/front.txt (this
# script's steps), with os2_image.sh's own at zig-out/wsl/image_qemu_front_placed.txt.
set -u
cd "$(dirname "$0")/.." || exit 1
NAME=qemu_front_placed   # the image and its pin are the PLACED machine's: qemu_front.machine alone carries no world
HOST=machines/qemu_front.machine
H=zig-out/cross/x86_64-linux-musl/harb
CA=zig-out/front/ca
LOG=zig-out/wsl/front.txt
mkdir -p zig-out/placed zig-out/wsl
{
  [ -x "$H" ] || { echo "no cross-built harb at $H (zig build cross)"; exit 1; }
  [ -x zig-out/caddy/caddy ] || { echo "no caddy at zig-out/caddy/caddy (experiment/caddy_fetch.sh)"; exit 1; }
  [ -f zig-out/ringserv/ringserv ] || { echo "no RingServ under zig-out/ringserv (powershell experiment/ringserv_build.ps1)"; exit 1; }
  echo "=== the root, made by hand and never by the floor ==="
  rm -rf "$CA"; mkdir -p "$CA"
  openssl ecparam -genkey -name prime256v1 -noout -out "$CA/root.key" 2> /dev/null || { echo "openssl could not make the key"; exit 1; }
  openssl req -x509 -new -key "$CA/root.key" -days 3650 -subj "/CN=Harobanda front" -out "$CA/root.crt" 2> /dev/null || { echo "openssl could not make the certificate"; exit 1; }
  echo "root: $(openssl x509 -in "$CA/root.crt" -noout -subject | sed 's/^subject=//'), fingerprint $(openssl x509 -in "$CA/root.crt" -outform DER | sha256sum | cut -c1-16)"
  echo "=== place: three packs on $HOST, in order ==="
  P1=zig-out/placed/${NAME}_1.machine; P2=zig-out/placed/${NAME}_2.machine; PLACED=zig-out/placed/$NAME.machine
  rm -f "$P1" "$P2" "$PLACED"
  "$H" place "$HOST" machines/ringserv.pack --out "$P1" || { echo "JUDGED: the server's placement was refused, so there is nothing to boot"; exit 1; }
  "$H" place "$P1" machines/front.pack --after ringserv --out "$P2" || { echo "JUDGED: the front's placement was refused, so there is nothing to boot"; exit 1; }
  "$H" place "$P2" machines/front_witness.pack --out "$PLACED" || { echo "JUDGED: the questions' placement was refused, so there is nothing to boot"; exit 1; }
  [ -f "$PLACED" ] || { echo "place said it wrote $PLACED and it is not there"; exit 1; }
  echo "placed: $PLACED ($(grep -c '^DEFINE SERVICE' "$PLACED") services, $(grep -c '^DEFINE USER' "$PLACED") identities)"
  echo "=== image, seed, boot, judge ==="
  HARB_MACHINE_FILE="$PLACED" HARB_STAGE=machines/qemu_front.stage HARB_DISK_SEED=experiment/front_seed.sh bash experiment/os2_image.sh "$NAME"
  RC=$?
  echo "os2_image.sh exit $RC"
  exit $RC
} 2>&1 | tee "$LOG"
exit "${PIPESTATUS[0]}"
