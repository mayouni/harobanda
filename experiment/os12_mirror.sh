#!/bin/bash
# os12_mirror.sh -- a world's directory is kept on another machine, and nobody's word but the source's makes it a copy (MIR-1).
#
# STZ-OS-RULING-19 orders a MIRROR: a declared copy of a world's directory on another member, over a link the fleet
# names, verified by the fleet's keys. This runs the arc end to end on two machines on one wire, and lets the negatives
# decide it. The disks are read back from the DISK and not from either machine's word, and every claim of the keeper
# is held against what the source's disk says:
#
#   0. enrol       each machine, booted alone, makes a key of its own and publishes the public half. Enrolment is
#                  somebody reading those lines and writing them down -- here into COPIES of the two machine files
#                  and of the fleet, because a design cannot state a key a device makes on its own first boot (FLT-1).
#   1. declared    the source holds a ledger (a file of a few hundred kilobytes, a log, a small database, an empty
#                  directory, and the note its world writes). The keeper, on the same wire, asks for it. It keeps a
#                  copy, and the copy on its disk is, file for file, the directory on the source's disk.
#   2. changed     the source's directory changes while the machines are down (a file rewritten, one gone, one new, a
#                  directory made and one removed): the copy follows.
#   3. impostor    a different machine answers from the source's address with a perfectly good signature of its own,
#                  and a ledger with one file forged. The keeper refuses the listing at the door, and the copy it
#                  already had is untouched: the forged file reached no disk.
#   4. stranger    a keeper that is not the device the source gives to (a key it made itself, enrolled nowhere) asks.
#                  The source closes on it without a word, and it keeps nothing.
#   5. link        a symbolic link appears in the world's directory, owned by the world, pointing at the machine's
#                  password file. The source will not give a directory with a link in it, says so, and the copy stays
#                  the last one that verified.
#   6. hard link   the world makes a HARD link to the machine's own device key: a regular file, in the world's own
#                  directory, whose owner is the machine. The source gives only what the world owns, refuses, and the
#                  key's bytes are found on no disk of the keeper's: the confused-deputy attack, and the floor's answer.
#   7. alone       the source is gone. The keeper's copy is the thing that is there when the original is not.
#   8. the cut     what a pull cut short by the power left on the keeper's disk -- a staging place and the records
#                  that were waiting for it -- is gone after the next boot, and the copy it had verifies.
#   9. tampered    a file of the copy is changed on the keeper's disk while the machine is off, and the source is not
#                  there to heal it: the witness convicts the copy, and the machine's own judge convicts the boot.
#  10. the host    checks what the keeper kept with the fleet file and no secret, and then the negatives: a file changed,
#                  one added, one removed, the listing changed, another source's key, a mirror that does not exist, and
#                  a fleet whose data must stay where the keeper does not.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os12_mirror.sh
#
# Log: zig-out/wsl/mirror.txt; the judged text: machines/mirror.expected
set -u
cd "$(dirname "$0")/.." || exit 1
H=zig-out/cross/x86_64-linux-musl/harb
FLEET=machines/mirror_cloud.fleet
SRC=mirror_source
KEEP=mirror_keeper
PLAIN=mirror_keeper_plain
OS=zig-out/image/$SRC
OK=zig-out/image/$KEEP
OP=zig-out/image/$PLAIN
D=zig-out/mirror
LOG=zig-out/wsl/mirror.txt
PORT=${HARB_MIRROR_PORT:-14800}
mkdir -p zig-out/wsl
# THE LOG IS THIS RUN'S, ON EVERY PATH (RET-1): removed first, so a run killed outright leaves no log rather than an
# old green one; and the machines this script starts are ended however it ends
rm -f "$LOG" zig-out/wsl/mirror.body zig-out/wsl/mirror.full zig-out/wsl/mirror.normalised zig-out/wsl/mirror.diff
trap 'pkill -f "name m12-" 2>/dev/null' EXIT

# The hardware addresses come from the DECLARATION, never from a constant here (HDW-1). A refused fleet does not answer
# empty: it prints its refusal and exits 1, so the verdict is read and not the emptiness (NAM-2).
if ! SRC_MAC=$("$H" fleet "$FLEET" hardware depot); then echo "the fleet is refused, so there are no devices to be:"; echo "$SRC_MAC"; exit 1; fi
if ! KEEP_MAC=$("$H" fleet "$FLEET" hardware annex); then echo "the fleet is refused, so there are no devices to be:"; echo "$KEEP_MAC"; exit 1; fi
if [ -z "$SRC_MAC" ] || [ -z "$KEEP_MAC" ]; then echo "the fleet named no hardware for these members -- $H fleet $FLEET"; exit 1; fi
for tool in debugfs e2fsck mkfs.ext4 diff find python3; do
  command -v "$tool" > /dev/null || { echo "$tool is needed to read the disks back"; exit 1; }
done

# A machine's boot line, put on this round's wire and given a name to be ended by. The user-mode netdev QEMU is given by
# default is a network of one; a socket netdev is a real L2 segment between exactly two machines, which is what a
# question and its answer need.
wire() { # $1 = boot.cmd, $2 = listen|connect|user, $3 = port, $4 = mac, $5 = a name
  local netdev="-netdev user,id=n0"
  case "$2" in
    listen)  netdev="-netdev socket,id=n0,listen=:$3" ;;
    connect) netdev="-netdev socket,id=n0,connect=127.0.0.1:$3" ;;
  esac
  sed -e "s|-netdev user,id=n0|$netdev|" \
      -e "s|-device virtio-net-pci,netdev=n0|-device virtio-net-pci,netdev=n0,mac=$4|" \
      -e "s|^qemu-system-x86_64 |qemu-system-x86_64 -name m12-$5 |" "$1"
}

# A machine is up when it has SAID it is: waiting for a line the machine itself printed beats sleeping for a number
# somebody guessed.
await_line() { # $1 = transcript, $2 = fixed text, $3 = seconds
  local n=0
  while [ "$n" -lt $(( $3 * 4 )) ]; do
    grep -qF "$2" "$1" 2>/dev/null && return 0
    sleep 0.25; n=$((n+1))
  done
  return 1
}

raw() { sed -e 's/\r$//' "$1"; }
# a key a device published: `enrol <machine> ed25519 <64 hex>`, the last one a boot said
published() { raw "$1" | grep -oE "enrol $2 ed25519 [0-9a-f]{64}" | tail -1 | awk '{print $4}'; }

# Each round is on a port of its own: a port a machine was just ended on is not one to listen on again at once
ROUND=0
SJOB=""
KJOB=""
source_up() { # $1 = label, $2 = the disk the source boots from
  rm -f "$OS/transcript_$1.txt"
  cp "$2" "$OS/disk0.img"
  wire "$OS/boot.cmd" listen "$((PORT + ROUND))" "$SRC_MAC" "src-$1" > "$OS/boot_pair.cmd"
  ( cd "$OS" && timeout --foreground 900 bash boot_pair.cmd < /dev/null > "transcript_$1.txt" 2>&1 ) &
  SJOB=$!
  if ! await_line "$OS/transcript_$1.txt" "not when the asking does" 150; then
    echo "the source never said it was up -- see $OS/transcript_$1.txt"
    return 1
  fi
}
source_down() { # $1 = label, $2 = where to keep the disk it leaves
  sleep 1   # the console's last bytes: a line seen whole may not yet have its end
  pkill -f "name m12-src-$1 " 2>/dev/null
  wait "$SJOB" 2>/dev/null
  cp "$OS/disk0.img" "$2"
}
keeper_up() { # $1 = label, $2 = the disk, $3 = wire|alone, $4 = the image directory
  local dir=${4:-$OK}
  rm -f "$dir/transcript_$1.txt"
  cp "$2" "$dir/disk0.img"
  if [ "$3" = alone ]; then wire "$dir/boot.cmd" user 0 "$KEEP_MAC" "kp-$1" > "$dir/boot_pair.cmd"
  else wire "$dir/boot.cmd" connect "$((PORT + ROUND))" "$KEEP_MAC" "kp-$1" > "$dir/boot_pair.cmd"; fi
  ( cd "$dir" && timeout --foreground 900 bash boot_pair.cmd < /dev/null > "transcript_$1.txt" 2>&1 ) &
  KJOB=$!
  if ! await_line "$dir/transcript_$1.txt" "still taking a copy from" 240; then
    echo "the keeper never finished its boot -- see $dir/transcript_$1.txt"
    return 1
  fi
}
keeper_down() { # $1 = label, $2 = where to keep the disk it leaves, $3 = the image directory
  sleep 1
  pkill -f "name m12-kp-$1 " 2>/dev/null
  wait "$KJOB" 2>/dev/null
  cp "${3:-$OK}/disk0.img" "$2"
}

# ---- reading a disk back --------------------------------------------------------------------------------
# A machine that was ended mid-write leaves a journal to replay; the disk is copied, replayed and checked before it is read.
settle() { # $1 = a disk image a machine was ended on: its journal is replayed and the disk checked before anything is written to it
  e2fsck -fy "$1" > /dev/null 2>&1
  [ $? -le 2 ] || { echo "disk: $1 could not be replayed and checked"; return 1; }
}
witness() { # $1 = disk image, $2 = the replayed copy
  cp "$1" "$2"
  e2fsck -fy "$2" > /dev/null 2>&1
  [ $? -le 2 ] || { echo "disk: $1 could not be replayed and checked"; return 1; }
}
dump_dir() { # $1 = a replayed image, $2 = a directory on it, $3 = where on the host
  rm -rf "$3"; mkdir -p "$3"
  debugfs -R "rdump $2 $3" "$1" > /dev/null 2>&1
}
# (The ledger's world writes a file called `note` at every boot, and the machine is ended a moment after: the guest has
# not flushed it, so the source's DISK holds it empty or not at all while the keeper -- which read it from the live
# machine -- holds all six bytes. That is the one file two readbacks cannot agree on, and it is left out of the counts and
# the comparisons; the keeper's copy of it is still held to its listing, by the host's `mirror verify` below.)
tally() { # $1 = a directory on the host
  local f d b
  f=$(find "$1" -type f ! -name note | wc -l); d=$(find "$1" -mindepth 1 -type d | wc -l)
  b=$(find "$1" -type f ! -name note -printf '%s\n' | awk '{s+=$1} END {print s+0}')
  echo "$f files besides the note, $d directories, $b bytes"
}
same_tree() { diff -r -x note "$1" "$2" > /dev/null 2>&1 && echo yes || echo no; }
# the keeper's disk after a round: its copy, the listing it was verified against, and the line about its last attempt
read_keeper() { # $1 = label, $2 = the disk
  witness "$2" "$D/k_$1.img" || return 1
  dump_dir "$D/k_$1.img" /copy "$D/k_$1"
  debugfs -R "cat /copy.manifest" "$D/k_$1.img" 2> /dev/null > "$D/k_$1.manifest"
  debugfs -R "cat /copy.last" "$D/k_$1.img" 2> /dev/null | sed -e 's/\r$//' > "$D/k_$1.last"
}
read_source() { # $1 = label, $2 = the disk
  witness "$2" "$D/s_$1.img" || return 1
  dump_dir "$D/s_$1.img" /ledger "$D/s_$1"
}
has() { debugfs -R "stat $2" "$1" 2>&1 | grep -q 'File not found' && echo no || echo yes; }

# ---- changing the source's disk from outside, as the world's identity ----------------------------------
# The files are the world's: uid and gid 2000, as PID 1 hands its directory over. What the world did not make is not.
as_world() { # $1 = disk, $2 = a path on it
  debugfs -w -R "sif $2 uid 2000" "$1" > /dev/null 2>&1
  debugfs -w -R "sif $2 gid 2000" "$1" > /dev/null 2>&1
}
put_file() { # $1 = disk, $2 = path on it, $3 = content
  printf '%s' "$3" > "$D/put.tmp"
  debugfs -w -R "rm $2" "$1" > /dev/null 2>&1
  debugfs -w -R "write $D/put.tmp $2" "$1" > /dev/null 2>&1
  debugfs -w -R "sif $2 mode 0100600" "$1" > /dev/null 2>&1
  as_world "$1" "$2"
}
put_blob() { # $1 = disk, $2 = path on it, $3 = bytes
  head -c "$3" /dev/urandom > "$D/put.tmp"
  debugfs -w -R "rm $2" "$1" > /dev/null 2>&1
  debugfs -w -R "write $D/put.tmp $2" "$1" > /dev/null 2>&1
  debugfs -w -R "sif $2 mode 0100600" "$1" > /dev/null 2>&1
  as_world "$1" "$2"
}
put_dir() { # $1 = disk, $2 = path on it
  debugfs -w -R "mkdir $2" "$1" > /dev/null 2>&1
  debugfs -w -R "sif $2 mode 040700" "$1" > /dev/null 2>&1
  as_world "$1" "$2"
}
leaked() { # $1 = a file, $2 = a disk image: whether the file's bytes are anywhere on the disk
  python3 -c 'import sys; k = open(sys.argv[1], "rb").read(); d = open(sys.argv[2], "rb").read(); print("yes" if k in d else "no")' "$1" "$2"
}

# The scene. It is a subshell, so that an `exit 1` inside it ends the scene and not the script: the log below is still
# assembled from whatever was said, and the verdict is FAIL.
(
  rm -rf "$D"; mkdir -p "$D"

  echo "=== the images: built from the declarations, and not booted ==="
  # (the verdict of the build is READ, and the image it leaves is removed first: a build that fails must not leave the
  # last run's image to be mistaken for this one's -- NAM-2)
  build() { # $1 = the image name, $2 = the machine file
    rm -f "zig-out/image/$1/boot.cmd"
    if ! HARB_MACHINE_FILE="$2" HARB_NO_BOOT=1 bash experiment/os2_image.sh "$1" > /dev/null 2>&1 || [ ! -f "zig-out/image/$1/boot.cmd" ]; then
      echo "$1: IMAGE NOT BUILT -- see zig-out/wsl/image_$1.txt"; return 1
    fi
    echo "$1: image built ($(grep -c . "zig-out/image/$1/expected") expected lines)"
  }
  build $SRC machines/$SRC.machine || exit 1
  build $KEEP machines/$KEEP.machine || exit 1
  cp "$OS/disk0.img" "$D/source.fresh.img"
  cp "$OK/disk0.img" "$D/keeper.fresh.img"

  echo "=== round 0: each machine booted alone makes its key and publishes the public half ==="
  ROUND=0
  source_up enrol "$D/source.fresh.img" || { source_down enrol "$D/source.enrol.img"; exit 1; }
  source_down enrol "$D/source.img"
  SKEY=$(published "$OS/transcript_enrol.txt" $SRC)
  if [ -z "$SKEY" ]; then echo "the source published no key"; exit 1; fi
  keeper_up enrol "$D/keeper.fresh.img" alone || { keeper_down enrol "$D/keeper.enrol.img"; exit 1; }
  keeper_down enrol "$D/keeper.img"
  DKEY=$(published "$OK/transcript_enrol.txt" $KEEP)
  if [ -z "$DKEY" ]; then echo "the keeper published no key"; exit 1; fi
  if [ "$SKEY" = "$DKEY" ]; then echo "the two devices made one key"; exit 1; fi
  echo "enrolled: each device's key, as the line it printed on its own console"

  # the declarations, with the keys written where a design cannot: the source's MIRROR_FOR, the keeper's MIRROR_KEY, and
  # the fleet's KEY for each. Two places for each key that must agree, and the fleet court holds them to it (FR86, FR87).
  sed -e "s|MIRROR_FOR \"\\(ab\\)\\{32\\}\"|MIRROR_FOR \"$DKEY\"|" machines/$SRC.machine > "$D/$SRC.machine"
  sed -e "s|MIRROR_KEY \"a\\{64\\}\"|MIRROR_KEY \"$SKEY\"|" machines/$KEEP.machine > "$D/$KEEP.machine"
  sed -e "s|KEY \"a\\{64\\}\"|KEY \"$SKEY\"|" -e "s|KEY \"\\(ab\\)\\{32\\}\"|KEY \"$DKEY\"|" "$FLEET" > "$D/mirror_cloud.fleet"
  if ! grep -qF "MIRROR_FOR \"$DKEY\"" "$D/$SRC.machine" || ! grep -qF "MIRROR_KEY \"$SKEY\"" "$D/$KEEP.machine" \
     || ! grep -qF "KEY \"$SKEY\"" "$D/mirror_cloud.fleet" || ! grep -qF "KEY \"$DKEY\"" "$D/mirror_cloud.fleet"; then
    echo "the keys were not written into the copies"; exit 1
  fi
  echo "=== the roll: both enrolled, the copy named ==="
  "$H" fleet "$D/mirror_cloud.fleet" | sed 's/^/roll: /'
  [ "${PIPESTATUS[0]}" = 0 ] || { echo "the enrolled fleet is refused"; exit 1; }

  # the keeper that checks without waiting for a fresh attempt: the witness of a copy nothing can heal
  sed -e 's|"--wait", "60", "--fresh"|"--wait", "5"|' "$D/$KEEP.machine" > "$D/${PLAIN}.machine"
  if cmp -s "$D/$KEEP.machine" "$D/${PLAIN}.machine"; then echo "the plain keeper differs from the keeper in nothing"; exit 1; fi

  echo "=== the images again, from the enrolled declarations ==="
  build $SRC "$D/$SRC.machine" || exit 1
  build $KEEP "$D/$KEEP.machine" || exit 1
  build $PLAIN "$D/${PLAIN}.machine" || exit 1

  # ---- the ledger: what the world has kept ---------------------------------------------------------------
  cp "$D/source.img" "$D/source.r1.img"
  settle "$D/source.r1.img" || exit 1
  # (the directory PID 1 makes for the world is not on the disk yet: the machine was ended before the kernel wrote it. It
  # is made here as PID 1 makes it -- the world's, closed -- and PID 1 takes it as it finds it, as it must for a database
  # that outlives a boot)
  put_dir "$D/source.r1.img" /ledger
  put_file "$D/source.r1.img" /ledger/accounts.db "account 1: 120.50
account 2: 7.00
"
  put_dir "$D/source.r1.img" /ledger/logs
  put_file "$D/source.r1.img" /ledger/logs/monday.log "opened 08:00
closed 19:30
"
  put_dir "$D/source.r1.img" /ledger/empty
  put_blob "$D/source.r1.img" /ledger/blob.bin 300000
  # (a seed that did not take must stop the scene, or every comparison below is a comparison of nothing with nothing)
  for f in /ledger/accounts.db /ledger/logs/monday.log /ledger/blob.bin; do
    [ "$(has "$D/source.r1.img" $f)" = yes ] || { echo "the ledger could not be seeded: $f is not on the source's disk"; exit 1; }
  done

  echo "=== round 1: declared -- the source holds a ledger, and the keeper asks for it ==="
  ROUND=1
  source_up declared "$D/source.r1.img" || { source_down declared "$D/source.r1.after.img"; exit 1; }
  keeper_up declared "$D/keeper.img" wire || { keeper_down declared "$D/keeper.r1.img"; source_down declared "$D/source.r1.after.img"; exit 1; }
  keeper_down declared "$D/keeper.r1.img"
  source_down declared "$D/source.r1.after.img"
  read_keeper r1 "$D/keeper.r1.img" || exit 1
  read_source r1 "$D/source.r1.after.img" || exit 1
  echo "disk: round 1 -- the source's /data/ledger holds $(tally "$D/s_r1/ledger")"
  echo "disk: round 1 -- the keeper's /data/copy holds $(tally "$D/k_r1/copy")"
  echo "disk: round 1 -- it is, file for file, the directory the source's disk holds: $(same_tree "$D/s_r1/ledger" "$D/k_r1/copy")"
  echo "disk: round 1 -- /data/copy.last says: $(cat "$D/k_r1.last")"

  echo "=== round 2: changed -- the directory changes while the machines are down, and the copy follows ==="
  ROUND=2
  cp "$D/source.r1.after.img" "$D/source.r2.img"
  settle "$D/source.r2.img" || exit 1
  put_file "$D/source.r2.img" /ledger/accounts.db "account 1: 121.50
account 2: 7.00
account 3: 0.00
"
  debugfs -w -R "rm /ledger/logs/monday.log" "$D/source.r2.img" > /dev/null 2>&1
  put_file "$D/source.r2.img" /ledger/logs/tuesday.log "opened 08:05
"
  debugfs -w -R "rmdir /ledger/empty" "$D/source.r2.img" > /dev/null 2>&1
  put_dir "$D/source.r2.img" /ledger/archive
  source_up changed "$D/source.r2.img" || { source_down changed "$D/source.r2.after.img"; exit 1; }
  keeper_up changed "$D/keeper.r1.img" wire || { keeper_down changed "$D/keeper.r2.img"; source_down changed "$D/source.r2.after.img"; exit 1; }
  keeper_down changed "$D/keeper.r2.img"
  source_down changed "$D/source.r2.after.img"
  read_keeper r2 "$D/keeper.r2.img" || exit 1
  read_source r2 "$D/source.r2.after.img" || exit 1
  echo "disk: round 2 -- the source's /data/ledger holds $(tally "$D/s_r2/ledger")"
  echo "disk: round 2 -- the keeper's /data/copy holds $(tally "$D/k_r2/copy")"
  echo "disk: round 2 -- it is, file for file, the directory the source's disk holds: $(same_tree "$D/s_r2/ledger" "$D/k_r2/copy")"
  echo "disk: round 2 -- the file the source removed is gone from the copy: $([ -e "$D/k_r2/copy/logs/monday.log" ] && echo no || echo yes)"
  echo "disk: round 2 -- the copy of round 1 and the copy of round 2 are the same directory: $(same_tree "$D/k_r1/copy" "$D/k_r2/copy")"
  echo "disk: round 2 -- /data/copy.last says: $(cat "$D/k_r2.last")"

  echo "=== round 3: an impostor -- a different machine answers from the source's address, with a ledger of its own ==="
  ROUND=3
  # the source's machine on a disk that never held the source's key, so it makes a key of its own, and a ledger in
  # which one file is forged
  cp "$D/source.r2.after.img" "$D/impostor.img"
  settle "$D/impostor.img" || exit 1
  debugfs -w -R "rm /device.key" "$D/impostor.img" > /dev/null 2>&1
  put_file "$D/impostor.img" /ledger/accounts.db "account 1: 999999.00
"
  source_up impostor "$D/impostor.img" || { source_down impostor "$D/impostor.after.img"; exit 1; }
  keeper_up impostor "$D/keeper.r2.img" wire || { keeper_down impostor "$D/keeper.r3.img"; source_down impostor "$D/impostor.after.img"; exit 1; }
  keeper_down impostor "$D/keeper.r3.img"
  source_down impostor "$D/impostor.after.img"
  IKEY=$(published "$OS/transcript_impostor.txt" $SRC)
  if [ -z "$IKEY" ] || [ "$IKEY" = "$SKEY" ]; then echo "the impostor has no key of its own"; exit 1; fi
  read_keeper r3 "$D/keeper.r3.img" || exit 1
  echo "disk: round 3 -- the keeper's /data/copy is the copy it had before the impostor answered: $(same_tree "$D/k_r2/copy" "$D/k_r3/copy")"
  echo "disk: round 3 -- the forged ledger reached the keeper's disk: $(grep -rqF 999999 "$D/k_r3/copy" && echo yes || echo no)"
  echo "disk: round 3 -- /data/copy.last says: $(cat "$D/k_r3.last")"

  echo "=== round 4: a stranger -- a keeper that is not the device the source gives to asks for the ledger ==="
  ROUND=4
  source_up stranger "$D/source.r2.after.img" || { source_down stranger "$D/source.r4.after.img"; exit 1; }
  keeper_up stranger "$D/keeper.fresh.img" wire || { keeper_down stranger "$D/keeper.r4.img"; source_down stranger "$D/source.r4.after.img"; exit 1; }
  keeper_down stranger "$D/keeper.r4.img"
  source_down stranger "$D/source.r4.after.img"
  witness "$D/keeper.r4.img" "$D/k_r4.img" || exit 1
  debugfs -R "cat /copy.last" "$D/k_r4.img" 2> /dev/null | sed -e 's/\r$//' > "$D/k_r4.last"
  echo "disk: round 4 -- the stranger's disk holds a copy of the ledger: $(has "$D/k_r4.img" /copy)"
  echo "disk: round 4 -- /data/copy.last says: $(cat "$D/k_r4.last")"

  echo "=== round 5: a link -- the world makes a symbolic link in its own directory, to the machine's password file ==="
  ROUND=5
  cp "$D/source.r2.after.img" "$D/source.r5.img"
  settle "$D/source.r5.img" || exit 1
  debugfs -w -R "symlink /ledger/stolen /etc/passwd" "$D/source.r5.img" > /dev/null 2>&1
  as_world "$D/source.r5.img" /ledger/stolen
  source_up link "$D/source.r5.img" || { source_down link "$D/source.r5.after.img"; exit 1; }
  keeper_up link "$D/keeper.r3.img" wire || { keeper_down link "$D/keeper.r5.img"; source_down link "$D/source.r5.after.img"; exit 1; }
  keeper_down link "$D/keeper.r5.img"
  source_down link "$D/source.r5.after.img"
  read_keeper r5 "$D/keeper.r5.img" || exit 1
  echo "disk: round 5 -- the keeper's /data/copy is the copy it had: $(same_tree "$D/k_r2/copy" "$D/k_r5/copy")"
  echo "disk: round 5 -- /data/copy.last says: $(cat "$D/k_r5.last")"

  echo "=== round 6: a hard link -- the world makes a regular file in its own directory that is the machine's own device key ==="
  ROUND=6
  cp "$D/source.r2.after.img" "$D/source.r6.img"
  settle "$D/source.r6.img" || exit 1
  debugfs -R "dump /device.key $D/source.key" "$D/source.r6.img" > /dev/null 2>&1
  debugfs -w -R "ln /device.key /ledger/mykey" "$D/source.r6.img" > /dev/null 2>&1
  source_up hardlink "$D/source.r6.img" || { source_down hardlink "$D/source.r6.after.img"; exit 1; }
  keeper_up hardlink "$D/keeper.r5.img" wire || { keeper_down hardlink "$D/keeper.r6.img"; source_down hardlink "$D/source.r6.after.img"; exit 1; }
  keeper_down hardlink "$D/keeper.r6.img"
  source_down hardlink "$D/source.r6.after.img"
  read_keeper r6 "$D/keeper.r6.img" || exit 1
  read_source r6 "$D/source.r6.after.img" || exit 1
  echo "disk: round 6 -- the source's /data/ledger/mykey is the device key itself, under another name: $(cmp -s "$D/source.key" "$D/s_r6/ledger/mykey" && echo yes || echo no)"
  echo "disk: round 6 -- the keeper's /data/copy is the copy it had: $(same_tree "$D/k_r2/copy" "$D/k_r6/copy")"
  echo "disk: round 6 -- the source's device key is anywhere on the keeper's disk: $(leaked "$D/source.key" "$D/keeper.r6.img")"
  echo "disk: round 6 -- /data/copy.last says: $(cat "$D/k_r6.last")"

  echo "=== round 7: alone -- the source is gone, and what the keeper kept is the thing that is there ==="
  keeper_up alone "$D/keeper.r6.img" alone || { keeper_down alone "$D/keeper.r7.img"; exit 1; }
  keeper_down alone "$D/keeper.r7.img"
  read_keeper r7 "$D/keeper.r7.img" || exit 1
  echo "disk: round 7 -- the keeper's /data/copy is the copy it had: $(same_tree "$D/k_r2/copy" "$D/k_r7/copy")"
  echo "disk: round 7 -- /data/copy.last says: $(cat "$D/k_r7.last")"

  echo "=== round 8: the cut -- what a pull cut short left on the keeper's disk, and a boot after it ==="
  cp "$D/keeper.r7.img" "$D/keeper.r8.img"
  e2fsck -fy "$D/keeper.r8.img" > /dev/null 2>&1
  debugfs -w -R "mkdir /copy.new" "$D/keeper.r8.img" > /dev/null 2>&1
  printf 'half a file' > "$D/put.tmp"
  debugfs -w -R "write $D/put.tmp /copy.new/half" "$D/keeper.r8.img" > /dev/null 2>&1
  debugfs -w -R "write $D/put.tmp /copy.manifest.new" "$D/keeper.r8.img" > /dev/null 2>&1
  debugfs -w -R "write $D/put.tmp /copy.last.new" "$D/keeper.r8.img" > /dev/null 2>&1
  echo "disk: round 8 -- before the boot the keeper's disk holds the staging place: $(has "$D/keeper.r8.img" /copy.new), its record: $(has "$D/keeper.r8.img" /copy.manifest.new)"
  keeper_up cut "$D/keeper.r8.img" alone || { keeper_down cut "$D/keeper.r8b.img"; exit 1; }
  keeper_down cut "$D/keeper.r8b.img"
  read_keeper r8 "$D/keeper.r8b.img" || exit 1
  echo "disk: round 8 -- after it the staging place is gone: $([ "$(has "$D/k_r8.img" /copy.new)" = no ] && echo yes || echo no), and so is the record that waited for it: $([ "$(has "$D/k_r8.img" /copy.manifest.new)" = no ] && echo yes || echo no)"
  echo "disk: round 8 -- the keeper's /data/copy is the copy it had: $(same_tree "$D/k_r2/copy" "$D/k_r8/copy")"

  echo "=== round 8, again: the cut between the first two renames -- the copy set aside, the new one not yet in its place ==="
  cp "$D/keeper.r8b.img" "$D/keeper.r8c.img"
  settle "$D/keeper.r8c.img" || exit 1
  debugfs -w -R "link /copy /copy.old" "$D/keeper.r8c.img" > /dev/null 2>&1
  debugfs -w -R "unlink /copy" "$D/keeper.r8c.img" > /dev/null 2>&1
  debugfs -w -R "mkdir /copy.new" "$D/keeper.r8c.img" > /dev/null 2>&1
  debugfs -w -R "write $D/put.tmp /copy.manifest.new" "$D/keeper.r8c.img" > /dev/null 2>&1
  echo "disk: round 8 -- before the boot the keeper holds no /data/copy: $([ "$(has "$D/keeper.r8c.img" /copy)" = no ] && echo yes || echo no), and holds the copy it set aside: $(has "$D/keeper.r8c.img" /copy.old)"
  keeper_up setaside "$D/keeper.r8c.img" alone || { keeper_down setaside "$D/keeper.r8d.img"; exit 1; }
  keeper_down setaside "$D/keeper.r8d.img"
  read_keeper r8d "$D/keeper.r8d.img" || exit 1
  echo "disk: round 8 -- after it the copy is back where it was, and is the copy it had: $(same_tree "$D/k_r2/copy" "$D/k_r8d/copy"), and the set-aside name is gone: $([ "$(has "$D/k_r8d.img" /copy.old)" = no ] && echo yes || echo no)"

  echo "=== round 9: tampered -- a file of the copy is changed on the keeper's disk, and nothing is there to heal it ==="
  cp "$D/keeper.r8d.img" "$D/keeper.r9.img"
  settle "$D/keeper.r9.img" || exit 1
  sed -e 's/1/9/' "$D/k_r8d/copy/accounts.db" > "$D/put.tmp"
  cmp -s "$D/put.tmp" "$D/k_r8d/copy/accounts.db" && { echo "the tampered file is not different"; exit 1; }
  debugfs -w -R "rm /copy/accounts.db" "$D/keeper.r9.img" > /dev/null 2>&1
  debugfs -w -R "write $D/put.tmp /copy/accounts.db" "$D/keeper.r9.img" > /dev/null 2>&1
  keeper_up tampered "$D/keeper.r9.img" alone "$OP" || { keeper_down tampered "$D/keeper.r9b.img" "$OP"; exit 1; }
  keeper_down tampered "$D/keeper.r9b.img" "$OP"
  echo "disk: round 9 -- the witness convicted the copy: $(grep -q 'does not match its listing' "$OP/transcript_tampered.txt" && echo yes || echo no), and the machine's boot was judged to match its expectation: $(grep -q 'boot: judge -- the boot matches' "$OP/transcript_tampered.txt" && echo yes || echo no)"

  echo "=== round 10: no disk -- the mount a copy lies on is refused by the kernel, and neither machine says what it cannot keep ==="
  # a machine that says it gives, or takes, a copy and cannot (NS-1) says why on the console and does not say it does, so
  # its boot differs from its expectation: the copy of a keeper whose disk was refused would be made in RAM, report that it
  # was kept, and be gone with the power
  nodisk() { # $1 = a label, $2 = the image directory
    sed -e 's# -drive if=none,file=disk0.img,format=raw,id=d0 -device [a-z-]*,drive=d0##' "$2/boot.cmd" > "$2/boot_nodisk.cmd"
    if cmp -s "$2/boot.cmd" "$2/boot_nodisk.cmd"; then echo "$1: the boot line carries no disk to take away"; return 1; fi
    rm -f "$2/transcript_$1.txt"
    ( cd "$2" && timeout --foreground 240 bash boot_nodisk.cmd < /dev/null > "transcript_$1.txt" 2>&1 )
    echo "exit $?" >> "$2/transcript_$1.txt"
  }
  nodisk srcnodisk "$OS" || exit 1
  nodisk keepnodisk "$OK" || exit 1
  echo "disk: round 10 -- the source, with no disk, said it gives the ledger: $(grep -q 'boot: mirror -- lan gives' "$OS/transcript_srcnodisk.txt" && echo yes || echo no)"
  echo "disk: round 10 -- the keeper, with no disk, said it takes a copy: $(grep -q 'boot: mirror -- takes' "$OK/transcript_keepnodisk.txt" && echo yes || echo no)"

  # ---- the host: what a holder of the fleet file can say about what the keeper kept --------------------
  audit() { # $1 = label, then the arguments of `harb mirror verify`
    local label=$1; shift
    "$H" mirror verify "$@" 2>&1 | sed "s/^/$label: /"
    echo "$label: exit ${PIPESTATUS[0]}"
  }
  echo "=== the host: the copy of round 1 and the copy of round 2, by somebody who holds only the fleet file ==="
  audit first "$D/mirror_cloud.fleet" ledger_copy "$D/k_r1.manifest" "$D/k_r1/copy"
  audit second "$D/mirror_cloud.fleet" ledger_copy "$D/k_r2.manifest" "$D/k_r2/copy"
  echo "=== ... and the copy the keeper held when the source was gone ==="
  audit alone "$D/mirror_cloud.fleet" ledger_copy "$D/k_r7.manifest" "$D/k_r7/copy"

  echo "=== negative 1: one byte of one file changed ==="
  rm -rf "$D/neg"; mkdir -p "$D/neg"; cp -r "$D/k_r2/copy" "$D/neg/changed"
  sed -i -e 's/1/9/' "$D/neg/changed/accounts.db"
  audit changed "$D/mirror_cloud.fleet" ledger_copy "$D/k_r2.manifest" "$D/neg/changed"

  echo "=== negative 2: a file the listing does not list ==="
  cp -r "$D/k_r2/copy" "$D/neg/added"; printf 'unlisted' > "$D/neg/added/extra.txt"
  audit added "$D/mirror_cloud.fleet" ledger_copy "$D/k_r2.manifest" "$D/neg/added"

  echo "=== negative 3: a file the listing lists, gone ==="
  cp -r "$D/k_r2/copy" "$D/neg/removed"; rm "$D/neg/removed/accounts.db"
  audit removed "$D/mirror_cloud.fleet" ledger_copy "$D/k_r2.manifest" "$D/neg/removed"

  echo "=== negative 4: the listing changed after it was signed ==="
  D1=$(grep -m1 '^file ' "$D/k_r2.manifest" | awk '{print substr($2, 1, 8)}')
  sed -e "0,/^file $D1/s//file 00000000/" "$D/k_r2.manifest" > "$D/neg/listing.changed"
  cmp -s "$D/neg/listing.changed" "$D/k_r2.manifest" && { echo "the listing did not change"; exit 1; }
  audit listing "$D/mirror_cloud.fleet" ledger_copy "$D/neg/listing.changed" "$D/k_r2/copy"

  echo "=== negative 5: the same listing, offered to a fleet that takes its copy from another machine ==="
  mkdir -p "$D/other"
  sed -e "s|MIRROR_KEY \"$SKEY\"|MIRROR_KEY \"$IKEY\"|" "$D/$KEEP.machine" > "$D/other/$KEEP.machine"
  cp "$D/$SRC.machine" "$D/other/"
  sed -e "s|KEY \"$SKEY\"|KEY \"$IKEY\"|" "$D/mirror_cloud.fleet" > "$D/other/other.fleet"
  audit foreign "$D/other/other.fleet" ledger_copy "$D/k_r2.manifest" "$D/k_r2/copy"

  echo "=== negative 6: a mirror the fleet never declared ==="
  audit nameless "$D/mirror_cloud.fleet" nowhere "$D/k_r2.manifest" "$D/k_r2/copy"

  echo "=== negative 7: nothing to verify ==="
  : > "$D/neg/none.manifest"
  audit nothing "$D/mirror_cloud.fleet" ledger_copy "$D/neg/none.manifest" "$D/k_r2/copy"

  echo "=== negative 8: a fleet whose data must stay in the shop, and a keeper in the warehouse ==="
  mkdir -p "$D/law"
  cp "$D/$SRC.machine" "$D/$KEEP.machine" "$D/law/"
  { cat "$D/mirror_cloud.fleet"; printf 'DEFINE RESIDENCY records AS (\n  TERRITORY shop\n) RATIONALE "The ledger stays in the shop"\n'; } > "$D/law/law.fleet"
  "$H" fleet "$D/law/law.fleet" 2>&1 | sed 's/^/law: /'
  echo "law: exit ${PIPESTATUS[0]}"
) > zig-out/wsl/mirror.body 2>&1
SCENE=$?

# Assemble one text from the boots. Each section is cut at ITS OWN first `boot: harb init` and the firmware noise before it
# dropped -- on the first line only, or a later section's banner loses which boot it belonged to (the JRN-1 defect). A boot
# the scene never reached says so, rather than leaving a gap that reads as quiet.
section() { # $1 = file, $2 = prefix
  if [ ! -f "$1" ]; then echo "$2: (no transcript: the scene stopped before this boot)"; return; fi
  sed -e 's/\r$//' "$1" \
    | sed -n '/^.*boot: harb init/,$p' \
    | sed -e '1s/^.*boot: harb init/boot: harb init/' \
    | sed -E 's/pid ([2-9]|[1-9][0-9]+)\b/pid N/g' \
    | sed -e '/^qemu exit$/d; /^qemu exit [0-9]*$/d; /^exit [0-9]*$/d' \
    | sed -e '/terminating on signal/d' \
    | sed "s/^/$2: /"
}
{
  cat zig-out/wsl/mirror.body
  echo "=== what each machine said ==="
  echo "enrol source: the source, booted alone on a disk that has never held its key:"
  section "$OS/transcript_enrol.txt" srcenrol
  echo "enrol keeper: the keeper, booted alone on a disk that has never held its key:"
  section "$OK/transcript_enrol.txt" keepenrol
  echo "declared source: the source with the ledger, answering before anybody has asked:"
  section "$OS/transcript_declared.txt" source1
  echo "declared keeper: the keeper, asking for the first time:"
  section "$OK/transcript_declared.txt" keeper1
  echo "changed keeper: the same keeper, after the directory changed:"
  section "$OK/transcript_changed.txt" keeper2
  echo "impostor: a different machine, with a key of its own, answering from the source's address:"
  section "$OS/transcript_impostor.txt" impostor
  echo "impostor keeper: the same keeper, answered by it:"
  section "$OK/transcript_impostor.txt" keeper3
  echo "stranger keeper: a keeper that is not the device the source gives to:"
  section "$OK/transcript_stranger.txt" stranger
  echo "link keeper: the same keeper, while the source's directory holds a link:"
  section "$OK/transcript_link.txt" keeper5
  echo "hard link keeper: the same keeper, while the source's directory holds the device key under another name:"
  section "$OK/transcript_hardlink.txt" keeper6
  echo "alone keeper: the same keeper, with nobody on the wire:"
  section "$OK/transcript_alone.txt" alone
  echo "cut keeper: the same keeper, with what a cut pull leaves on its disk, and nobody on the wire:"
  section "$OK/transcript_cut.txt" cut
  echo "set-aside keeper: the same keeper, with its copy set aside and the new one not yet in its place, and nobody on the wire:"
  section "$OK/transcript_setaside.txt" setaside
  echo "tampered keeper: the keeper that does not wait for a fresh attempt, with a file of its copy changed and nobody on the wire:"
  section "$OP/transcript_tampered.txt" tampered
  echo "no-disk source: the source, with no disk behind its mount:"
  section "$OS/transcript_srcnodisk.txt" srcnodisk
  echo "no-disk keeper: the keeper, with no disk behind its mount:"
  section "$OK/transcript_keepnodisk.txt" keepnodisk
} > zig-out/wsl/mirror.full

# The key, the fingerprint and the signature are made on the device and differ in every build. Each DISTINCT key becomes
# KEY1, KEY2, ... and each DISTINCT fingerprint FP1, FP2, ... in order of first appearance, so what survives
# normalisation is the claim that matters: the same key twice reads as KEY1 twice, and a key that CHANGED would read as
# KEY2 and convict (IDN-1). The values are MARKED by sed at their exact lengths first, because [0-9a-f]+ also matches
# ordinary English (FLT-1: the "af" of "after").
sed -e 's/\r$//' \
    -e 's/declaration=[0-9a-f]\{16\}/declaration=D/g' \
    -e 's/ed25519 \([0-9a-f]\{64\}\)/ed25519 @@K@\1@@K@/g' \
    -e 's/fingerprint \([0-9a-f]\{16\}\)/fingerprint @@F@\1@@F@/g' \
    -e 's/enrolled as \([0-9a-f]\{16\}\)/enrolled as @@F@\1@@F@/g' \
    -e 's/signed by \([0-9a-f]\{16\}\) for this device (\([0-9a-f]\{16\}\))/signed by @@F@\1@@F@ for this device (@@F@\2@@F@)/g' \
    -e 's/signed by \([0-9a-f]\{16\}\) for \([0-9a-f]\{16\}\), the two keys/signed by @@F@\1@@F@ for @@F@\2@@F@, the two keys/g' zig-out/wsl/mirror.full \
  | awk '
      {
        while (match($0, /@@K@[0-9a-f]+@@K@/)) {
          v = substr($0, RSTART + 4, RLENGTH - 8)
          if (!(v in K)) { nk++; K[v] = "KEY" nk }
          $0 = substr($0, 1, RSTART - 1) K[v] substr($0, RSTART + RLENGTH)
        }
        while (match($0, /@@F@[0-9a-f]+@@F@/)) {
          v = substr($0, RSTART + 4, RLENGTH - 8)
          if (!(v in F)) { nf++; F[v] = "FP" nf }
          $0 = substr($0, 1, RSTART - 1) F[v] substr($0, RSTART + RLENGTH)
        }
        print
      }' > zig-out/wsl/mirror.normalised

{
  cat zig-out/wsl/mirror.full
  echo "=== judge ==="
  VERDICT=0
  if [ "$SCENE" != 0 ]; then
    echo "JUDGED: FAIL -- the scene stopped before it was done (exit $SCENE); what it said is above"
    VERDICT=1
  elif [ ! -f machines/mirror.expected ]; then
    echo "JUDGED: nothing pinned yet -- this run's text is at zig-out/wsl/mirror.normalised"
  elif diff -u machines/mirror.expected zig-out/wsl/mirror.normalised > zig-out/wsl/mirror.diff; then
    echo "JUDGED: the arc matches machines/mirror.expected line for line ($(wc -l < zig-out/wsl/mirror.normalised) lines)"
  else
    echo "JUDGED: FAIL -- the arc differs from machines/mirror.expected:"; cat zig-out/wsl/mirror.diff
    VERDICT=1
  fi
  echo "exit $VERDICT"
  exit "$VERDICT"
} 2>&1 | tee "$LOG"
#
# THE VERDICT IS THE BLOCK'S, NOT tee's: a pipeline exits with its LAST command's status (VDCT-1), so the status of the
# block is read from PIPESTATUS.
exit "${PIPESTATUS[0]}"
