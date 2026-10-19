#!/bin/bash
# front_seed.sh -- seed a front's root on the disk the image script just made (FRONT-1).
#
# Run by os2_image.sh when HARB_DISK_SEED names it, with the image directory as its one
# argument, after the disks are made and before the boot. It writes the root certificate
# and key the scene generated (zig-out/front/ca/) into the data disk under /front -- which
# the front's STATE makes /data/front at boot -- owned by the front's identity (2020:2020),
# the key readable by nobody else. The floor never generates this root and Caddy never
# did either: it is enrolment by hand, as a device's key is (FLT-1), and the fleet will
# declare it by its fingerprint.
#
# debugfs writes into the ext4 image without mounting it; the files it makes are root's,
# so each is given its owner and mode by hand, and the directory too -- PID 1 hands the
# directory itself over at boot (OWN-1), and what is INSIDE it keeps what it was seeded with.
set -u
OUT=$1
cd "$(dirname "$0")/.." || exit 1
CA=zig-out/front/ca
[ -f "$CA/root.crt" ] && [ -f "$CA/root.key" ] || { echo "seed: no root under $CA (the scene makes it before the image)"; exit 1; }
# disk.list names a disk by its device, not by the mount's name: /dev/vda is the data mount's
# device in machines/qemu_front.machine
IMG=$(awk '!/^#/ && $2 == "/dev/vda" {print $5; exit}' "$OUT/disk.list")
[ -n "$IMG" ] && [ -f "$OUT/$IMG" ] || { echo "seed: no disk for /dev/vda in $OUT/disk.list"; exit 1; }
D="$OUT/$IMG"
run() { debugfs -w -R "$1" "$D" > /dev/null 2>&1 || { echo "seed: debugfs refused: $1"; exit 1; }; }
run "mkdir /front"
run "write $CA/root.crt /front/root.crt"
run "write $CA/root.key /front/root.key"
for f in /front /front/root.crt /front/root.key; do
  run "set_inode_field $f uid 2020"
  run "set_inode_field $f gid 2020"
done
run "set_inode_field /front mode 040700"
run "set_inode_field /front/root.crt mode 0100644"
run "set_inode_field /front/root.key mode 0100600"
echo "seed: /front on $IMG -- root.crt and root.key, owned by 2020:2020, the key closed (0600), fingerprint $(openssl x509 -in "$CA/root.crt" -outform DER | sha256sum | cut -c1-16)"
