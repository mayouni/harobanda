#!/bin/bash
# os14_loss.sh -- a member is destroyed while the fleet runs, and the fleet's roll says what was lost (LOSS-1, STZ-OS-RULING-19).
#
# Ruling 19 orders a loss drill: a scene that destroys a member while the fleet runs, and shows the rest serve,
# re-judge themselves and say what was lost. Every scene before this one built a fleet and none broke one. This one
# takes the mirror's two machines -- a source whose world keeps a ledger, and a keeper that holds a verified copy of
# it -- and gives each a signed record of its boots (JOURNAL), which is the one thing the drill adds to them: the
# machine files are DERIVED from machines/mirror_source.machine and machines/mirror_keeper.machine by that one line,
# so the drill cannot drift from the machines the mirror's own pin judges.
#
#   0. enrol       each machine, booted alone, makes a key and publishes it; the keys are written into COPIES of the
#                  two machine files and of the fleet (FLT-1)
#   1. running     the source holds a ledger, the keeper takes a copy; both disks are read back, and the first roll is
#                  called over the two records as their disks hold them
#   2. the loss    both boot again on one wire. Once each has judged its own boot and written it in its record, the
#                  source is DESTROYED: its emulator is killed outright and every disk image of it is deleted. The
#                  keeper goes on asking, and the scene waits for its disk to say its last attempt was silent
#   3. the rest    the keeper's disk: the copy it held is the ledger the source's disk held at round 1, file for file;
#                  and the host checks the copy with the fleet file and no secret
#   4. re-judged   the keeper booted alone, with the source gone for good: its boot matches its declaration without
#                  the source, and its witness reads the copy back from its disk and says nobody answered. (Its
#                  expectation does not hold the last-attempt line, so its judge alone could not see the loss: the
#                  witness's line and the disk are what say it)
#   5. what was lost the second roll, against the first: the keeper WROTE (its record is longer, and still its own); the
#                  source is ABSENT, with what the first roll held of it. Then the scene, and not the fleet, reads the
#                  destroyed source's own console for the entry it appended in its last boot: that entry was on the
#                  disk that is gone and no roll ever held it. The fleet's own answer is the roll's line, and no more
#   6. a new card  a machine built from the same declaration on a new disk makes a new key. Its record is NOT the
#                  member's: a replacement is a new device until somebody enrols it (RET-1's rule for a dead card)
#
# What this is NOT: a failover. Nothing here moves the ledger's world to the keeper or makes the keeper answer for
# the source; the floor keeps a verified copy and says what was lost, and what to run from the copy is a person's act.
# Nor does it measure what the ledger's world wrote after the keeper's last good copy: the ledger does not change in
# round 2, and a copy is the last COMPLETE one, so what a source writes between two pulls is lost with it, unmeasured.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os14_loss.sh
#
# Log: zig-out/wsl/loss.txt; the judged text: machines/loss.expected
set -u
cd "$(dirname "$0")/.." || exit 1
H=zig-out/cross/x86_64-linux-musl/harb
FLEET=machines/mirror_cloud.fleet
SRC=loss_source
KEEP=loss_keeper
OS=zig-out/image/$SRC
OK=zig-out/image/$KEEP
D=zig-out/loss
LOG=zig-out/wsl/loss.txt
PORT=${HARB_LOSS_PORT:-14900}
mkdir -p zig-out/wsl
# THE LOG IS THIS RUN'S, ON EVERY PATH (RET-1)
rm -f "$LOG" zig-out/wsl/loss.body zig-out/wsl/loss.full zig-out/wsl/loss.normalised zig-out/wsl/loss.diff
# machines are named for THIS run (its process number), so ending them never ends another run's
TAG=m14-$$
trap 'pkill -f "name $TAG-" 2>/dev/null' EXIT

# the hardware addresses are the DECLARATION's (HDW-1), and a refused fleet's answer is read as a refusal (NAM-2)
if ! SRC_MAC=$("$H" fleet "$FLEET" hardware depot); then echo "the fleet is refused:"; echo "$SRC_MAC"; exit 1; fi
if ! KEEP_MAC=$("$H" fleet "$FLEET" hardware annex); then echo "the fleet is refused:"; echo "$KEEP_MAC"; exit 1; fi
for tool in debugfs e2fsck diff find; do
  command -v "$tool" > /dev/null || { echo "$tool is needed to read the disks back"; exit 1; }
done

# a machine's boot line on this round's wire, named so it can be ended (a socket netdev is one segment between two)
wire() { # $1 = boot.cmd, $2 = listen|connect|user, $3 = port, $4 = mac, $5 = a name
  local netdev="-netdev user,id=n0"
  case "$2" in
    listen)  netdev="-netdev socket,id=n0,listen=:$3" ;;
    connect) netdev="-netdev socket,id=n0,connect=127.0.0.1:$3" ;;
  esac
  sed -e "s|-netdev user,id=n0|$netdev|" \
      -e "s|-device virtio-net-pci,netdev=n0|-device virtio-net-pci,netdev=n0,mac=$4|" \
      -e "s|^qemu-system-x86_64 |qemu-system-x86_64 -name $TAG-$5 |" "$1"
}
# a machine is up when it has SAID so
await_line() { # $1 = transcript, $2 = fixed text, $3 = seconds
  local n=0
  while [ "$n" -lt $(( $3 * 4 )) ]; do
    grep -qF "$2" "$1" 2>/dev/null && return 0
    sleep 0.25; n=$((n+1))
  done
  return 1
}
raw() { sed -e 's/\r$//' "$1"; }
published() { raw "$1" | grep -oE "enrol $2 ed25519 [0-9a-f]{64}" | tail -1 | awk '{print $4}'; }
alive() { pgrep -f "name $TAG-$1 " > /dev/null && echo yes || echo no; }

ROUND=0
SJOB=""
KJOB=""
source_up() { # $1 = label, $2 = the disk the source boots from, $3 = listen|user
  rm -f "$OS/transcript_$1.txt"
  cp "$2" "$OS/disk0.img"
  wire "$OS/boot.cmd" "${3:-listen}" "$((PORT + ROUND))" "$SRC_MAC" "src-$1" > "$OS/boot_pair.cmd"
  ( cd "$OS" && timeout --foreground 900 bash boot_pair.cmd < /dev/null > "transcript_$1.txt" 2>&1 ) &
  SJOB=$!
  if ! await_line "$OS/transcript_$1.txt" "not when the asking does" 150; then
    echo "the source never said it was up -- see $OS/transcript_$1.txt"; return 1
  fi
}
source_down() { # $1 = label, $2 = where to keep the disk it leaves
  sleep 1
  pkill -f "name $TAG-src-$1 " 2>/dev/null
  wait "$SJOB" 2>/dev/null
  cp "$OS/disk0.img" "$2"
}
keeper_up() { # $1 = label, $2 = the disk, $3 = wire|alone
  rm -f "$OK/transcript_$1.txt"
  cp "$2" "$OK/disk0.img"
  if [ "$3" = alone ]; then wire "$OK/boot.cmd" user 0 "$KEEP_MAC" "kp-$1" > "$OK/boot_pair.cmd"
  else wire "$OK/boot.cmd" connect "$((PORT + ROUND))" "$KEEP_MAC" "kp-$1" > "$OK/boot_pair.cmd"; fi
  ( cd "$OK" && timeout --foreground 900 bash boot_pair.cmd < /dev/null > "transcript_$1.txt" 2>&1 ) &
  KJOB=$!
  if ! await_line "$OK/transcript_$1.txt" "still taking a copy from" 240; then
    echo "the keeper never finished its boot -- see $OK/transcript_$1.txt"; return 1
  fi
}
keeper_down() { # $1 = label, $2 = where to keep the disk it leaves
  sleep 1
  pkill -f "name $TAG-kp-$1 " 2>/dev/null
  wait "$KJOB" 2>/dev/null
  cp "$OK/disk0.img" "$2"
}

# ---- reading a disk back: replayed first, because a machine ended mid-run is a power cut (MIR-1) ----------
settle() { e2fsck -fy "$1" > /dev/null 2>&1; [ $? -le 2 ] || { echo "disk: $1 could not be replayed and checked"; return 1; }; }
witness() { cp "$1" "$2"; settle "$2"; }
dump_dir() { rm -rf "$3"; mkdir -p "$3"; debugfs -R "rdump $2 $3" "$1" > /dev/null 2>&1; }
has() { debugfs -R "stat $2" "$1" 2>&1 | grep -q 'File not found' && echo no || echo yes; }
# a member's record, as its disk holds it: what is BROUGHT to a roll is what was collected, and here that is the disk
record_of() { # $1 = a replayed image, $2 = where on the host
  debugfs -R "cat /journal" "$1" 2> /dev/null > "$2"
  [ -s "$2" ] || { echo "disk: no record on $1"; return 1; }
}
entries() { grep -c . "$1"; }
# (the ledger's world writes `note` at every boot and the machine is ended a moment after, so the source's disk can
# hold it short while the keeper, which read it from the live machine, holds it whole: left out of the comparison,
# and held to its listing by the host's `mirror verify`, as in the mirror's own scene)
tally() {
  local f d b
  f=$(find "$1" -type f ! -name note | wc -l); d=$(find "$1" -mindepth 1 -type d | wc -l)
  b=$(find "$1" -type f ! -name note -printf '%s\n' | awk '{s+=$1} END {print s+0}')
  echo "$f files besides the note, $d director$([ "$d" = 1 ] && echo y || echo ies), $b bytes"
}
same_tree() { diff -r -x note "$1" "$2" > /dev/null 2>&1 && echo yes || echo no; }
as_world() { debugfs -w -R "sif $2 uid 2000" "$1" > /dev/null 2>&1; debugfs -w -R "sif $2 gid 2000" "$1" > /dev/null 2>&1; }
put_file() {
  printf '%s' "$3" > "$D/put.tmp"
  debugfs -w -R "rm $2" "$1" > /dev/null 2>&1
  debugfs -w -R "write $D/put.tmp $2" "$1" > /dev/null 2>&1
  debugfs -w -R "sif $2 mode 0100600" "$1" > /dev/null 2>&1
  as_world "$1" "$2"
}
put_blob() {
  head -c "$3" /dev/urandom > "$D/put.tmp"
  debugfs -w -R "write $D/put.tmp $2" "$1" > /dev/null 2>&1
  debugfs -w -R "sif $2 mode 0100600" "$1" > /dev/null 2>&1
  as_world "$1" "$2"
}
put_dir() {
  debugfs -w -R "mkdir $2" "$1" > /dev/null 2>&1
  debugfs -w -R "sif $2 mode 040700" "$1" > /dev/null 2>&1
  as_world "$1" "$2"
}
# one call of the roll: its words with a label before every line, and the exit code after them
roll() { # $1 = label, then the arguments of `harb roll`
  local label=$1; shift
  "$H" roll "$@" 2>&1 | sed "s/^/$label: /"
  echo "$label: exit ${PIPESTATUS[0]}"
}
audit() { # $1 = label, then the arguments of `harb mirror verify`
  local label=$1; shift
  "$H" mirror verify "$@" 2>&1 | sed "s/^/$label: /"
  echo "$label: exit ${PIPESTATUS[0]}"
}

# The moments the rolls are called at. Nothing here is dated (the fleet names no time authority), so the caller's
# clock is the only time in a roll, and fixed moments make the same records give the same roll on every run.
FIRST_AT=2026-11-08T09:00Z
SECOND_AT=2026-11-08T17:00Z
THIRD_AT=2026-11-09T09:00Z

(
  rm -rf "$D"; mkdir -p "$D"
  [ -x "$H" ] || { echo "no cross-built harb at $H -- zig build cross -j2"; exit 1; }

  echo "=== the two machines: the mirror's pair, each also keeping a signed record of its boots ==="
  # the ONE line the drill adds, after the IDENTITY each already declares
  for pair in mirror_source:$SRC mirror_keeper:$KEEP; do
    from=${pair%%:*}; to=${pair#*:}
    sed -e "/^  IDENTITY \"\\/data\\/device.key\",\$/a\\  JOURNAL \"/data/journal\"," "machines/$from.machine" > "$D/$from.base"
    if [ "$(diff "machines/$from.machine" "$D/$from.base" | grep -c '^>')" != 1 ] || ! grep -qF 'JOURNAL "/data/journal",' "$D/$from.base"; then
      echo "$to: the record was not added to machines/$from.machine as one line"; exit 1
    fi
    echo "$to: machines/$from.machine, and one line more: JOURNAL \"/data/journal\""
  done

  build() { # $1 = the image name, $2 = the machine file
    rm -f "zig-out/image/$1/boot.cmd"
    if ! HARB_MACHINE_FILE="$2" HARB_NO_BOOT=1 bash experiment/os2_image.sh "$1" > /dev/null 2>&1 || [ ! -f "zig-out/image/$1/boot.cmd" ]; then
      echo "$1: IMAGE NOT BUILT -- see zig-out/wsl/image_$1.txt"; return 1
    fi
    echo "$1: image built ($(grep -c . "zig-out/image/$1/expected") expected lines)"
  }
  build $SRC "$D/mirror_source.base" || exit 1
  build $KEEP "$D/mirror_keeper.base" || exit 1
  cp "$OS/disk0.img" "$D/source.fresh.img"
  cp "$OK/disk0.img" "$D/keeper.fresh.img"

  echo "=== round 0: each machine booted alone makes its key and publishes the public half ==="
  ROUND=0
  # the source is ended only once it has written this boot in its record. The keeper's enrol boot writes none, on
  # every run: its witness finds no copy and exits 1, and a one-shot that fails holds back the verdict, which is what
  # an entry is written after (JDG-1) -- so its record starts at round 1, one entry shorter than the source's
  source_up enrol "$D/source.fresh.img" user || { source_down enrol "$D/source.enrol.img"; exit 1; }
  await_line "$OS/transcript_enrol.txt" "boot: journal -- " 120 || { echo "the source never wrote its record"; exit 1; }
  source_down enrol "$D/source.img"
  SKEY=$(published "$OS/transcript_enrol.txt" mirror_source)
  [ -n "$SKEY" ] || { echo "the source published no key"; exit 1; }
  keeper_up enrol "$D/keeper.fresh.img" alone || { keeper_down enrol "$D/keeper.enrol.img"; exit 1; }
  keeper_down enrol "$D/keeper.img"
  DKEY=$(published "$OK/transcript_enrol.txt" mirror_keeper)
  [ -n "$DKEY" ] || { echo "the keeper published no key"; exit 1; }
  [ "$SKEY" != "$DKEY" ] || { echo "the two devices made one key"; exit 1; }
  echo "enrolled: each device's key, as the line it printed on its own console"
  sed -e "s|MIRROR_FOR \"\\(ab\\)\\{32\\}\"|MIRROR_FOR \"$DKEY\"|" "$D/mirror_source.base" > "$D/mirror_source.machine"
  sed -e "s|MIRROR_KEY \"a\\{64\\}\"|MIRROR_KEY \"$SKEY\"|" "$D/mirror_keeper.base" > "$D/mirror_keeper.machine"
  sed -e "s|KEY \"a\\{64\\}\"|KEY \"$SKEY\"|" -e "s|KEY \"\\(ab\\)\\{32\\}\"|KEY \"$DKEY\"|" "$FLEET" > "$D/loss.fleet"
  if ! grep -qF "MIRROR_FOR \"$DKEY\"" "$D/mirror_source.machine" || ! grep -qF "MIRROR_KEY \"$SKEY\"" "$D/mirror_keeper.machine" \
     || ! grep -qF "KEY \"$SKEY\"" "$D/loss.fleet" || ! grep -qF "KEY \"$DKEY\"" "$D/loss.fleet"; then
    echo "the keys were not written into the copies"; exit 1
  fi
  echo "=== the fleet: both enrolled, the copy named, each keeping a record ==="
  "$H" fleet "$D/loss.fleet" | sed 's/^/fleet: /'
  [ "${PIPESTATUS[0]}" = 0 ] || { echo "the enrolled fleet is refused"; exit 1; }

  echo "=== the images again, from the enrolled declarations ==="
  build $SRC "$D/mirror_source.machine" || exit 1
  build $KEEP "$D/mirror_keeper.machine" || exit 1

  # the ledger, seeded on the source's disk as its world's (uid 2000); a seed that did not take stops the scene
  cp "$D/source.img" "$D/source.r1.img"
  settle "$D/source.r1.img" || exit 1
  put_dir "$D/source.r1.img" /ledger
  put_file "$D/source.r1.img" /ledger/accounts.db "account 1: 120.50
account 2: 7.00
"
  put_dir "$D/source.r1.img" /ledger/logs
  put_file "$D/source.r1.img" /ledger/logs/monday.log "opened 08:00
closed 19:30
"
  put_blob "$D/source.r1.img" /ledger/blob.bin 300000
  for f in /ledger/accounts.db /ledger/logs/monday.log /ledger/blob.bin; do
    [ "$(has "$D/source.r1.img" $f)" = yes ] || { echo "the ledger could not be seeded: $f is not on the source's disk"; exit 1; }
  done

  echo "=== round 1: running -- the source holds a ledger, the keeper takes a copy ==="
  ROUND=1
  source_up running "$D/source.r1.img" || { source_down running "$D/source.r1.after.img"; exit 1; }
  keeper_up running "$D/keeper.img" wire || { keeper_down running "$D/keeper.r1.img"; source_down running "$D/source.r1.after.img"; exit 1; }
  await_line "$OS/transcript_running.txt" "boot: journal -- " 120 || { echo "the source never wrote its record"; exit 1; }
  await_line "$OK/transcript_running.txt" "boot: journal -- " 120 || { echo "the keeper never wrote its record"; exit 1; }
  keeper_down running "$D/keeper.r1.img"
  source_down running "$D/source.r1.after.img"
  witness "$D/source.r1.after.img" "$D/s_r1.img" || exit 1
  witness "$D/keeper.r1.img" "$D/k_r1.img" || exit 1
  dump_dir "$D/s_r1.img" /ledger "$D/s_r1"
  dump_dir "$D/k_r1.img" /copy "$D/k_r1"
  echo "disk: round 1 -- the source's /data/ledger holds $(tally "$D/s_r1/ledger")"
  echo "disk: round 1 -- the keeper's /data/copy is, file for file, that directory: $(same_tree "$D/s_r1/ledger" "$D/k_r1/copy")"
  mkdir -p "$D/first"
  record_of "$D/s_r1.img" "$D/first/depot.record" || exit 1
  record_of "$D/k_r1.img" "$D/first/annex.record" || exit 1
  echo "disk: round 1 -- the source's record holds $(entries "$D/first/depot.record") entries, the keeper's $(entries "$D/first/annex.record")"

  echo "=== the first roll: both records, collected from their disks ==="
  roll first "$D/loss.fleet" "$D/first" --at "$FIRST_AT" --out "$D/first.roll"

  echo "=== round 2: the loss -- both machines run, and the source is destroyed while they do ==="
  ROUND=2
  source_up drill "$D/source.r1.after.img" || { source_down drill "$D/source.r2.after.img"; exit 1; }
  keeper_up drill "$D/keeper.r1.img" wire || { keeper_down drill "$D/keeper.r2.img"; source_down drill "$D/source.r2.after.img"; exit 1; }
  # each has judged its boot and written it in its record before the loss: the source's entry is on its disk only
  await_line "$OS/transcript_drill.txt" "boot: journal -- " 120 || { echo "the source never wrote its record"; exit 1; }
  await_line "$OK/transcript_drill.txt" "boot: journal -- " 120 || { echo "the keeper never wrote its record"; exit 1; }
  echo "drill: both machines are running and each has written this boot in its record: source $(alive src-drill), keeper $(alive kp-drill)"
  sleep 1
  pkill -KILL -f "name $TAG-src-drill " 2>/dev/null
  wait "$SJOB" 2>/dev/null
  rm -f "$OS/disk0.img" "$D"/source*.img "$D"/s_r1.img
  # counted over EVERY disk image under the source's directories, not over the names just deleted: a count of what
  # rm was told to remove cannot fail (the review of LOSS-1). What the scene still holds of the source is named:
  # its directory as round 1's disk held it and its record as the first roll was brought it, readings taken before
  # the loss, which the comparisons below use -- and which no member of the fleet holds
  echo "drill: the source is destroyed -- its emulator killed outright: $(alive src-drill) running; disk images of it left: $(find "$OS" "$D" -maxdepth 1 -name '*.img' ! -name 'keeper*' ! -name 'k_*' 2> /dev/null | wc -l)"
  echo "drill: what the scene keeps of it, read before the loss and held by no member: its directory as round 1's disk held it, and its record as the first roll was brought it"
  # The keeper tries the source every 5 s, and an attempt in flight at the loss gives up only at its own limit: a
  # source killed outright sends no reset, so the keeper waits out up to listing_ms (300 s) for a listing, stall_ms
  # (30 s) inside a file, then 5 s, then a connect of 5 s (src/mirrorserve.zig). A guessed sleep under that is a
  # flake (the review of LOSS-1 found the first one was 45 s). So the scene waits for the keeper's OWN word: a copy of
  # its disk, replayed, read until the line about its last attempt says nobody answered, for up to 400 s.
  silent=no; n=0
  while [ "$n" -lt 80 ]; do
    cp "$OK/disk0.img" "$D/peek.img" 2> /dev/null && e2fsck -fy "$D/peek.img" > /dev/null 2>&1
    if debugfs -R "cat /copy.last" "$D/peek.img" 2> /dev/null | grep -q '^silent '; then silent=yes; break; fi
    sleep 5; n=$((n + 1))
  done
  rm -f "$D/peek.img"
  echo "drill: after the loss the keeper went on asking, and its disk came to say its last attempt was silent: $silent"
  [ "$silent" = yes ] || { echo "the keeper never said nobody answered, in 400 s"; keeper_down drill "$D/keeper.r2.img"; exit 1; }
  echo "drill: the keeper's emulator is still running: $(alive kp-drill) (a running emulator is not a working machine: the line above is the keeper's own word)"
  keeper_down drill "$D/keeper.r2.img"

  echo "=== the rest: what the keeper's disk holds after the loss ==="
  witness "$D/keeper.r2.img" "$D/k_r2.img" || exit 1
  dump_dir "$D/k_r2.img" /copy "$D/k_r2"
  debugfs -R "cat /copy.manifest" "$D/k_r2.img" 2> /dev/null > "$D/k_r2.manifest"
  debugfs -R "cat /copy.last" "$D/k_r2.img" 2> /dev/null | sed -e 's/\r$//' > "$D/k_r2.last"
  echo "disk: the keeper's /data/copy holds $(tally "$D/k_r2/copy")"
  echo "disk: it is, file for file, the ledger the source's disk held at round 1: $(same_tree "$D/s_r1/ledger" "$D/k_r2/copy")"
  echo "disk: /data/copy.last says: $(cat "$D/k_r2.last")"
  echo "=== the host: the copy, checked by somebody who holds only the fleet file ==="
  audit kept "$D/loss.fleet" ledger_copy "$D/k_r2.manifest" "$D/k_r2/copy"

  echo "=== round 3: re-judged -- the keeper boots alone, with the source gone for good ==="
  ROUND=3
  keeper_up after "$D/keeper.r2.img" alone || { keeper_down after "$D/keeper.r3.img"; exit 1; }
  await_line "$OK/transcript_after.txt" "boot: journal -- " 120 || { echo "the keeper never wrote its record"; exit 1; }
  keeper_down after "$D/keeper.r3.img"
  witness "$D/keeper.r3.img" "$D/k_r3.img" || exit 1
  dump_dir "$D/k_r3.img" /copy "$D/k_r3"
  echo "disk: round 3 -- the keeper's /data/copy is the copy it held at the loss: $(same_tree "$D/k_r2/copy" "$D/k_r3/copy")"

  echo "=== the second roll: what was lost -- the keeper's record is brought, and nobody can bring the source's ==="
  mkdir -p "$D/second"
  record_of "$D/k_r3.img" "$D/second/annex.record" || exit 1
  echo "disk: the keeper's record holds $(entries "$D/second/annex.record") entries"
  roll second "$D/loss.fleet" "$D/second" --since "$D/first.roll" --at "$SECOND_AT" --out "$D/second.roll"
  # what the source's own console said of the boot it was destroyed in, against what the roll held: the difference is
  # the loss, and the scene reads both numbers rather than writing one
  LOST=$(raw "$OS/transcript_drill.txt" | sed -n 's/.*boot: journal -- .* entry \([0-9]*\) appended.*/\1/p' | tail -1)
  # (the second roll keeps the anchor of the last roll that held the member: what it says is still owed)
  HELD=$(sed -n 's/^member depot .* entries=\([0-9]*\) .*/\1/p' "$D/second.roll" | head -1)
  if [ -z "$LOST" ] || [ -z "$HELD" ] || [ "$LOST" -le "$HELD" ]; then
    echo "lost: the scene cannot say what was lost -- the console said entry '${LOST}', the roll held '${HELD}'"; exit 1
  fi
  if [ "$LOST" = $((HELD + 1)) ]; then gone="entry $LOST was"; else gone="entries $((HELD + 1)) to $LOST were"; fi
  echo "lost: read by the scene off the destroyed source's own console, which no member of the fleet holds: it appended entry $LOST in the boot it was destroyed in; the last roll that held it held $HELD -- $gone on the disk that is gone, and no roll ever held it"

  echo "=== round 4: a new card -- the source's declaration on a new disk, and the record it keeps ==="
  ROUND=4
  build $SRC "$D/mirror_source.machine" > /dev/null || exit 1
  cp "$OS/disk0.img" "$D/new.fresh.img"
  source_up newcard "$D/new.fresh.img" user || { source_down newcard "$D/new.after.img"; exit 1; }
  await_line "$OS/transcript_newcard.txt" "boot: journal -- " 120 || { echo "the new card never wrote its record"; exit 1; }
  source_down newcard "$D/new.after.img"
  NKEY=$(published "$OS/transcript_newcard.txt" mirror_source)
  [ -n "$NKEY" ] && [ "$NKEY" != "$SKEY" ] || { echo "the new card has no key of its own"; exit 1; }
  witness "$D/new.after.img" "$D/n.img" || exit 1
  mkdir -p "$D/third"
  cp "$D/second/annex.record" "$D/third/"
  record_of "$D/n.img" "$D/third/depot.record" || exit 1
  n=$(entries "$D/third/depot.record")
  echo "disk: the new card's record holds $n entr$([ "$n" = 1 ] && echo y || echo ies), signed by a key of its own"
  roll third "$D/loss.fleet" "$D/third" --since "$D/second.roll" --at "$THIRD_AT"
) > zig-out/wsl/loss.body 2>&1
SCENE=$?

section() { # $1 = file, $2 = prefix
  if [ ! -f "$1" ]; then echo "$2: (no transcript: the scene stopped before this boot)"; return; fi
  sed -e 's/\r$//' "$1" \
    | sed -n '/^.*boot: harb init/,$p' \
    | sed -e '1s/^.*boot: harb init/boot: harb init/' \
    | sed -E 's/pid ([2-9]|[1-9][0-9]+)\b/pid N/g' \
    | sed -e '/^qemu exit$/d; /^qemu exit [0-9]*$/d; /^exit [0-9]*$/d' \
    | sed -e '/terminating on signal/d' \
    | sed -E 's/^.*: line [0-9]+: +[0-9]+ Killed +qemu-system.*$/(the emulator was killed here, outright: the line the shell printed for it names a process and is not kept)/' \
    | sed "s/^/$2: /"
}
{
  cat zig-out/wsl/loss.body
  echo "=== what each machine said ==="
  echo "running source: the source with the ledger, round 1:"
  section "$OS/transcript_running.txt" source1
  echo "running keeper: the keeper, taking its copy, round 1:"
  section "$OK/transcript_running.txt" keeper1
  echo "drill source: the source in the boot it was destroyed in -- what its console said before it was killed:"
  section "$OS/transcript_drill.txt" source2
  echo "drill keeper: the keeper in the same run, until it was ended 45 s after the loss:"
  section "$OK/transcript_drill.txt" keeper2
  echo "after keeper: the keeper, booted alone after the loss:"
  section "$OK/transcript_after.txt" keeper3
} > zig-out/wsl/loss.full

# keys, fingerprints and the record's digests are made on the device and differ in every run: each DISTINCT value
# becomes KEY1, FP1, H1 ... in order of first appearance, so the same value twice reads the same and a value that
# changed reads as a new name (IDN-1). Values are marked at their exact lengths first ([0-9a-f]+ matches English).
sed -e 's/\r$//' \
    -e 's/declaration=[0-9a-f]\{16\}/declaration=D/g' \
    -e 's/ed25519 \([0-9a-f]\{64\}\)/ed25519 @@K@\1@@K@/g' \
    -e 's/\(^\|[^@0-9a-f]\)\([0-9a-f]\{64\}\)\([^@0-9a-f]\|$\)/\1@@H@\2@@H@\3/g' \
    -e 's/head \([0-9a-f]\{8\}\)\([,;: ]\|$\)/head @@H@\1@@H@\2/g' \
    -e 's/fingerprint \([0-9a-f]\{16\}\)/fingerprint @@F@\1@@F@/g' \
    -e 's/enrolled as \([0-9a-f]\{16\}\)/enrolled as @@F@\1@@F@/g' \
    -e 's/signed by \([0-9a-f]\{16\}\)/signed by @@F@\1@@F@/g' \
    -e 's/for this device (\([0-9a-f]\{16\}\))/for this device (@@F@\1@@F@)/g' \
    -e 's/ for \([0-9a-f]\{16\}\), the two keys/ for @@F@\1@@F@, the two keys/g' zig-out/wsl/loss.full \
  | awk '
      {
        while (match($0, /@@K@[0-9a-f]+@@K@/)) {
          v = substr($0, RSTART + 4, RLENGTH - 8); if (!(v in K)) { nk++; K[v] = "KEY" nk }
          $0 = substr($0, 1, RSTART - 1) K[v] substr($0, RSTART + RLENGTH)
        }
        while (match($0, /@@H@[0-9a-f]+@@H@/)) {
          v = substr($0, RSTART + 4, RLENGTH - 8); if (!(v in Hh)) { nh++; Hh[v] = "H" nh }
          $0 = substr($0, 1, RSTART - 1) Hh[v] substr($0, RSTART + RLENGTH)
        }
        while (match($0, /@@F@[0-9a-f]+@@F@/)) {
          v = substr($0, RSTART + 4, RLENGTH - 8); if (!(v in F)) { nf++; F[v] = "FP" nf }
          $0 = substr($0, 1, RSTART - 1) F[v] substr($0, RSTART + RLENGTH)
        }
        print
      }' > zig-out/wsl/loss.normalised

{
  cat zig-out/wsl/loss.full
  echo "=== judge ==="
  VERDICT=0
  if [ "$SCENE" != 0 ]; then
    echo "JUDGED: FAIL -- the scene stopped before it was done (exit $SCENE); what it said is above"
    VERDICT=1
  elif [ ! -f machines/loss.expected ]; then
    echo "JUDGED: nothing pinned yet -- this run's text is at zig-out/wsl/loss.normalised"
  elif diff -u machines/loss.expected zig-out/wsl/loss.normalised > zig-out/wsl/loss.diff; then
    echo "JUDGED: the drill matches machines/loss.expected line for line ($(wc -l < zig-out/wsl/loss.normalised) lines)"
  else
    echo "JUDGED: FAIL -- the drill differs from machines/loss.expected:"; cat zig-out/wsl/loss.diff
    VERDICT=1
  fi
  echo "exit $VERDICT"
  exit "$VERDICT"
} 2>&1 | tee "$LOG"
# the verdict is the block's, not tee's (VDCT-1)
exit "${PIPESTATUS[0]}"
