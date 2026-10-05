#!/bin/bash
# os10_time.sh -- a record is dated by somebody else's word, and by nobody's otherwise (TIME-1).
#
# The floor has no date. A device keeps a signed record that is ORDERED and UNDATED, and a fleet that wants
# dates names the one member whose word about the time it takes (STZ-OS-RULING-07: attested, never assumed).
# This runs the arc end to end, on two machines on one wire, and lets the negatives decide it:
#
#   0. the authority, booted alone: a machine with a clock (the emulator's, a fixed point that runs with the
#      virtual machine) and a key of its own, which it publishes. Enrolment is somebody reading that line and
#      writing it down -- here into COPIES of the fleet and of the till's declaration, because a design cannot
#      state a key a device makes on its own first boot (FLT-1).
#   1. declared    the till boots three times with the authority on the wire. After the record it writes it
#                  asks the authority how late the entry it has just written can be, and keeps the answer if,
#                  and only if, it is the authority's word about THAT entry. It publishes the record and the
#                  statements as the exact bytes, and says what it makes of them.
#   2. alone       the authority is gone. The till boots twice more: what the authority had said stays said,
#                  the entries after it are ORDERED and UNDATED, and no date is made up for them.
#   3. impostor    a different machine answers from the authority's address, with a perfectly good signature
#                  of its own. The till refuses it at the door -- and the disk, read back from the DISK and
#                  not from the machine's word, holds the statements the authority gave and not the impostor's.
#   4. the cut     a statement the power cut short is put on the till's disk, and the till is booted: its witness
#                  says the line is not a statement and does not fail, because it gates the trial's commit.
#   5. the broken  an authority whose clock will not answer, and one with no link to answer on: each says so,
#                  does NOT say it answers, and so differs from what it expects (a promise it cannot keep is not made).
#   6. the host    checks what the till published with the fleet file and no secret: the record is the till's
#                  (the device's key) and its entries are dated (the authority's key); then the negatives: a
#                  statement changed, another authority, an entry removed, a record cut at its end, nothing to
#                  verify, and a fleet that takes its time from nobody.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os10_time.sh
#
# Log: zig-out/wsl/time.txt; the judged text: machines/time.expected
set -u
cd "$(dirname "$0")/.." || exit 1
H=zig-out/cross/x86_64-linux-musl/harb
FLEET=machines/time_cloud.fleet
CLOCK=time_clockbox
TILL=time_till
OA=zig-out/image/$CLOCK
OD=zig-out/image/${CLOCK}_dead
OT=zig-out/image/$TILL
D=zig-out/time
LOG=zig-out/wsl/time.txt
PORT=${HARB_TIME_PORT:-14700}
BOOTS=6      # what the till's journal holds when its disk is read back: three declared, two alone, one answered by an impostor
mkdir -p zig-out/wsl
# THE LOG IS THIS RUN'S, ON EVERY PATH (RET-1): removed first, so a run killed outright leaves no log rather
# than an old green one; and the machines this script starts are ended however it ends
rm -f "$LOG" zig-out/wsl/time.body zig-out/wsl/time.full zig-out/wsl/time.normalised zig-out/wsl/time.diff
trap 'pkill -f "socket,id=n0,listen=:$PORT" 2>/dev/null; pkill -f "socket,id=n0,listen=:$((PORT+1))" 2>/dev/null' EXIT

# The hardware addresses come from the DECLARATION, never from a constant here (HDW-1). A refused fleet
# does not answer empty: it prints its refusal and exits 1, so the verdict is read and not the emptiness (NAM-2).
if ! CLOCK_MAC=$("$H" fleet "$FLEET" hardware clockbox); then
  echo "the fleet is refused, so there are no devices to be:"; echo "$CLOCK_MAC"; exit 1
fi
if ! TILL_MAC=$("$H" fleet "$FLEET" hardware till); then
  echo "the fleet is refused, so there are no devices to be:"; echo "$TILL_MAC"; exit 1
fi
if [ -z "$CLOCK_MAC" ] || [ -z "$TILL_MAC" ]; then
  echo "the fleet named no hardware for these members -- $H fleet $FLEET"; exit 1
fi

# A machine's boot line, put on this round's wire. The user-mode netdev QEMU is given by default is a
# network of one; a socket netdev is a real L2 segment between exactly two machines, which is what a
# question and its answer need.
wire() { # $1 = boot.cmd, $2 = listen|connect|user, $3 = port, $4 = mac
  local netdev="-netdev user,id=n0"
  case "$2" in
    listen)  netdev="-netdev socket,id=n0,listen=:$3" ;;
    connect) netdev="-netdev socket,id=n0,connect=127.0.0.1:$3" ;;
  esac
  sed -e "s|-netdev user,id=n0|$netdev|" \
      -e "s|-device virtio-net-pci,netdev=n0|-device virtio-net-pci,netdev=n0,mac=$4|" "$1"
}

# A machine is up when it has SAID it is: waiting for a line the machine itself printed beats sleeping for a
# number somebody guessed.
await_line() { # $1 = transcript, $2 = fixed text, $3 = seconds
  local n=0
  while [ "$n" -lt $(( $3 * 4 )) ]; do
    grep -qF "$2" "$1" 2>/dev/null && return 0
    sleep 0.25; n=$((n+1))
  done
  return 1
}

raw() { sed -e 's/\r$//' "$1"; }
# what a till published: `record` lines or `statement` lines of one boot's console, as the bytes themselves
exported() { raw "$1" | grep -E "^$2 " | sed "s/^$2 //"; }
# a key a device published: `enrol <machine> ed25519 <64 hex>`, the last one a boot said
published() { raw "$1" | grep -oE "enrol $2 ed25519 [0-9a-f]{64}" | tail -1 | awk '{print $4}'; }

AJOB=""
authority_up() { # $1 = label, $2 = port, $3 = the disk the authority boots from, $4 = the line that says it is up
  rm -f "$OA/transcript_$1.txt"
  cp "$3" "$OA/disk0.img"
  wire "$OA/boot.cmd" listen "$2" "$CLOCK_MAC" > "$OA/boot_pair.cmd"
  ( cd "$OA" && timeout --foreground 600 bash boot_pair.cmd < /dev/null > "transcript_$1.txt" 2>&1 ) &
  AJOB=$!
  if ! await_line "$OA/transcript_$1.txt" "${4:-boot: time -- lan answers}" 90; then
    echo "the authority never said '${4:-boot: time -- lan answers}' -- see $OA/transcript_$1.txt"
    return 1
  fi
}
authority_down() { # $1 = port
  sleep 1   # the console's last bytes: a line seen whole may not yet have its end
  pkill -f "socket,id=n0,listen=:$1" 2>/dev/null
  wait "$AJOB" 2>/dev/null
}
till_boot() { # $1 = label, $2 = port of the wire it is on, or "alone": a network of one, with nobody on it
  rm -f "$OT/transcript_$1.txt"
  if [ "$2" = alone ]; then wire "$OT/boot.cmd" user 0 "$TILL_MAC" > "$OT/boot_pair.cmd"
  else wire "$OT/boot.cmd" connect "$2" "$TILL_MAC" > "$OT/boot_pair.cmd"; fi
  ( cd "$OT" && timeout --foreground 150 bash boot_pair.cmd < /dev/null > "transcript_$1.txt" 2>&1 )
  echo "exit $?" >> "$OT/transcript_$1.txt"
}

# The scene. It is a subshell, so that an `exit 1` inside it ends the scene and not the script: the log
# below is still assembled from whatever was said, and the verdict is FAIL.
(
  rm -rf "$D"; mkdir -p "$D"

  echo "=== the authority, booted alone: it makes its key and publishes the public half ==="
  # built and NOT booted by the image script: a machine that serves never halts, so its own boot would run to
  # the script's timeout. It is up when it says its last line, which comes after its witness has published.
  # (the verdict of the build is READ, and the image it leaves is removed first: a build that fails must not leave
  # the last run's image to be mistaken for this one's -- NAM-2)
  rm -f "$OA/boot.cmd"
  if ! HARB_NO_BOOT=1 bash experiment/os2_image.sh $CLOCK > /dev/null 2>&1 || [ ! -f "$OA/boot.cmd" ]; then
    echo "$CLOCK: IMAGE NOT BUILT -- see zig-out/wsl/image_$CLOCK.txt"; exit 1
  fi
  echo "$CLOCK: image built ($(grep -c . "$OA/expected") expected lines)"
  cp "$OA/disk0.img" "$D/authority.fresh.img"
  # (the END of its last line: the first words of it are on the console before the rest, and a machine ended
  # between the two leaves a transcript that stops mid-word -- a pin that holds only when the kill is late enough)
  authority_up enrol "$PORT" "$D/authority.fresh.img" "not when the asking does" || { authority_down "$PORT"; exit 1; }
  authority_down "$PORT"
  KEY=$(published "$OA/transcript_enrol.txt" $CLOCK)
  if [ -z "$KEY" ]; then echo "the authority published no key"; exit 1; fi
  # the disk the boot left holds the key (the device fsyncs it before it says it has one): the authority of every round
  cp "$OA/disk0.img" "$D/authority.img"
  echo "enrolled: the authority's key, as the line it printed on its own console"

  # the declarations, with the key written where a design cannot: the till's TIME_KEY and the fleet's KEY for
  # the authority. Two places that must agree, and the fleet court holds them to it (FR58).
  cp machines/$CLOCK.machine "$D/"
  sed -e "s|TIME_KEY \"a\{64\}\"|TIME_KEY \"$KEY\"|" machines/$TILL.machine > "$D/$TILL.machine"
  sed -e "s|KEY \"a\{64\}\"|KEY \"$KEY\"|" "$FLEET" > "$D/time_cloud.fleet"
  if ! grep -qF "TIME_KEY \"$KEY\"" "$D/$TILL.machine" || ! grep -qF "KEY \"$KEY\"" "$D/time_cloud.fleet"; then
    echo "the key was not written into the copies"; exit 1
  fi
  echo "=== the roll: the authority enrolled, the till not yet (it has not made its key) ==="
  "$H" fleet "$D/time_cloud.fleet" | sed 's/^/roll: /'
  [ "${PIPESTATUS[0]}" = 0 ] || { echo "the enrolled fleet is refused"; exit 1; }

  echo "=== the till's image (built, not booted) ==="
  rm -f "$OT/boot.cmd"
  if ! HARB_MACHINE_FILE="$D/$TILL.machine" HARB_NO_BOOT=1 bash experiment/os2_image.sh $TILL > /dev/null 2>&1 || [ ! -f "$OT/boot.cmd" ]; then
    echo "$TILL: IMAGE NOT BUILT -- see zig-out/wsl/image_$TILL.txt"; exit 1
  fi
  echo "$TILL: image built ($(grep -c . "$OT/expected") expected lines)"

  BASE=$(sed -n 's/.*-rtc base=\([^,]*\),.*/\1/p' "$OA/boot.cmd")
  BASE_T=$(date -u -d "${BASE/T/ }" +%s)
  if [ -z "$BASE" ] || [ -z "$BASE_T" ]; then echo "the emulator's clock base is not in the boot line"; exit 1; fi

  echo "=== round 1: declared -- the authority on the wire, the till booted three times on one disk ==="
  authority_up declared "$PORT" "$D/authority.img" || { authority_down "$PORT"; exit 1; }
  for n in 1 2 3; do till_boot declared$n "$PORT"; done
  authority_down "$PORT"

  # the till's own key, published at its first boot: the fleet can now say whose the record is
  TKEY=$(published "$OT/transcript_declared1.txt" $TILL)
  if [ -z "$TKEY" ]; then echo "the till published no key"; exit 1; fi
  sed -e "s|^\\(  DECLARATION \"$TILL.machine\",\\)\$|\\1\\n  KEY \"$TKEY\",|" "$D/time_cloud.fleet" > "$D/enrolled.fleet"
  echo "=== the roll: both enrolled ==="
  "$H" fleet "$D/enrolled.fleet" | sed 's/^/roll: /'
  [ "${PIPESTATUS[0]}" = 0 ] || { echo "the fleet with both keys is refused"; exit 1; }

  echo "=== round 2: alone -- nobody on the wire, the till booted twice more ==="
  for n in 1 2; do till_boot alone$n alone; done

  echo "=== round 3: an impostor -- a different machine answers from the authority's address ==="
  # the same authority image on a disk that never held the authority's key, so it makes a key of its own
  read -r DID DDEV DFS DSIZE DIMG < <(grep -v '^#' "$OA/disk.list" | head -1)
  rm -f "$D/impostor.img"; truncate -s "${DSIZE}M" "$D/impostor.img"; mkfs.ext4 -F -q -L "$DID" "$D/impostor.img"
  authority_up impostor "$((PORT+1))" "$D/impostor.img" || { authority_down "$((PORT+1))"; exit 1; }
  till_boot impostor "$((PORT+1))"
  authority_down "$((PORT+1))"
  IKEY=$(published "$OA/transcript_impostor.txt" $CLOCK)
  if [ -z "$IKEY" ] || [ "$IKEY" = "$KEY" ]; then echo "the impostor has no key of its own"; exit 1; fi

  # ---- what the disk says, which is not what PID 1 says ------------------------------------------
  echo "=== the till's disk, read back from the disk itself ==="
  command -v debugfs > /dev/null && command -v e2fsck > /dev/null || { echo "disk: debugfs and e2fsck (e2fsprogs) are needed to read the disk back"; exit 1; }
  cp "$OT/disk0.img" "$D/till.witness.img"
  e2fsck -fy "$D/till.witness.img" > /dev/null 2>&1
  [ $? -le 2 ] || { echo "disk: the disk could not be replayed and checked"; exit 1; }
  debugfs -R "cat /journal.time" "$D/till.witness.img" 2> /dev/null | sed -e 's/\r$//' > "$D/till.kept"
  debugfs -R "cat /journal" "$D/till.witness.img" 2> /dev/null | sed -e 's/\r$//' > "$D/till.journal"
  exported "$OT/transcript_alone2.txt" statement > "$D/alone2.statements"
  exported "$OT/transcript_alone2.txt" record > "$D/alone2.record"
  KEPT=$(grep -c . "$D/till.kept")
  if cmp -s "$D/till.kept" "$D/alone2.statements"; then
    echo "disk: /data/journal.time holds $KEPT statements, byte for byte the ones the till published before the impostor answered, and none of the impostor's"
  else
    echo "disk: /data/journal.time DIFFERS from what the till published ($KEPT lines): the impostor's answer was kept, or a kept statement changed"
  fi
  ENTRIES=$(grep -c . "$D/till.journal")
  if [ "$ENTRIES" = "$BOOTS" ]; then
    echo "disk: /data/journal holds $ENTRIES entries, one for each of the $BOOTS boots"
  else
    echo "disk: /data/journal holds $ENTRIES entries and the till booted $BOOTS times"
  fi

  # ---- round 4: a statement the power cut short -------------------------------------------------------
  # A power cut in the middle of an append leaves a last line with no end. Time is advisory, so the witness
  # that reads it must SAY the line is not a statement and must not fail: it is a service whose exit gates a
  # trial's commit, and a boot held back for ever by a shortened line is a boot the authority's absence
  # would have cost nothing. (That the next statement kept is not run onto the cut line is `keep`'s unit
  # test; this boot is the witness's.) The line is put where a cut would leave it: on the disk itself.
  echo "=== round 4: a statement the power cut short, on the till's disk -- and a boot it must not hold back ==="
  e2fsck -fy "$OT/disk0.img" > /dev/null 2>&1
  [ $? -le 2 ] || { echo "disk: the till's disk could not be replayed and checked"; exit 1; }
  debugfs -R "cat /journal.time" "$OT/disk0.img" 2> /dev/null > "$D/cut.kept"
  printf 'time authority=abab' >> "$D/cut.kept"
  debugfs -w -R "rm /journal.time" "$OT/disk0.img" > /dev/null 2>&1
  debugfs -w -R "write $D/cut.kept /journal.time" "$OT/disk0.img" > /dev/null 2>&1
  till_boot cut alone

  # ---- round 5: an authority that cannot keep what it declares ------------------------------------------
  # Said only after asking (CON-1): a machine that declares itself the authority and has no clock that answers, or
  # no link to answer on, says so on the console and does NOT say it answers -- so its own boot differs from what
  # it expects (NS-1), where the first version of the responder's fork said the line before it knew.
  echo "=== round 5: an authority whose clock will not answer, and one with no link to answer on ==="
  sed -e 's|CLOCK "/dev/rtc0"|CLOCK "/dev/rtc1"|' "$D/$CLOCK.machine" > "$D/${CLOCK}_dead.machine"
  "$H" check "$D/${CLOCK}_dead.machine" > /dev/null || { echo "the authority without its clock is refused by the court"; exit 1; }
  rm -f "$OD/boot.cmd"
  if ! HARB_MACHINE_FILE="$D/${CLOCK}_dead.machine" HARB_NO_BOOT=1 bash experiment/os2_image.sh ${CLOCK}_dead > /dev/null 2>&1 || [ ! -f "$OD/boot.cmd" ]; then
    echo "${CLOCK}_dead: IMAGE NOT BUILT -- see zig-out/wsl/image_${CLOCK}_dead.txt"; exit 1
  fi
  rm -f "$OD/transcript_dead.txt"
  ( cd "$OD" && timeout --foreground 120 bash boot.cmd < /dev/null > transcript_dead.txt 2>&1 )
  echo "exit $?" >> "$OD/transcript_dead.txt"
  cp "$D/authority.img" "$OA/disk0.img"
  sed -e 's# -netdev user,id=n0 -device virtio-net-pci,netdev=n0##' "$OA/boot.cmd" > "$OA/boot_nolink.cmd"
  if cmp -s "$OA/boot.cmd" "$OA/boot_nolink.cmd"; then echo "nolink: the boot line carries no network card to take away"; exit 1; fi
  rm -f "$OA/transcript_nolink.txt"
  ( cd "$OA" && timeout --foreground 120 bash boot_nolink.cmd < /dev/null > transcript_nolink.txt 2>&1 )
  echo "exit $?" >> "$OA/transcript_nolink.txt"

  # ---- the host: what a holder of the fleet file can say about what the till published ---------------
  exported "$OT/transcript_declared3.txt" statement > "$D/declared3.statements"
  exported "$OT/transcript_declared3.txt" record > "$D/declared3.record"

  # the clock the statements read is the emulator's: a fixed base that runs with the virtual machine. The
  # pin cannot hold a minute that depends on how fast an emulator booted (BDG-1), so it is asserted here.
  # (The base is a fixed day in the past: it is the host's own clock being outside this half hour that tells
  # an RTC that was read from a clock that was not.)
  # ... and STRICTLY later each time: the authority reads its clock at every question, so statements asked at
  # boots that are seconds apart state different seconds, where one that kept its boot's reading would state one
  check_clock() { # $1 = statements, $2 = what they are
    local prev=$BASE_T ok=yes n=0 line t first=yes
    while read -r line; do
      t=$(printf '%s' "$line" | sed -n 's/.* t=\([0-9]*\) .*/\1/p')
      if [ -z "$t" ] || [ "$t" -gt $(( BASE_T + 1800 )) ]; then ok=no
      elif [ "$first" = yes ]; then [ "$t" -ge "$BASE_T" ] || ok=no
      else [ "$t" -gt "$prev" ] || ok=no; fi
      first=no; prev=${t:-$prev}; n=$((n+1))
    done < "$1"
    echo "clock: $n statements ($2), the first no earlier than the emulator's clock base, each later than the one before, all within half an hour of the base: $ok"
  }
  echo "=== the clock the statements read ==="
  check_clock "$D/alone2.statements" "the ones the till kept"

  audit() { # $1 = label, then the arguments of `harb time verify`
    local label=$1; shift
    "$H" time verify "$@" 2>&1 | sed "s/^/$label: /"
    echo "$label: exit ${PIPESTATUS[0]}"
  }
  echo "=== the host: the record's entries, dated, by somebody who holds only the fleet file ==="
  audit dated "$D/enrolled.fleet" "$D/declared3.statements" "$D/declared3.record"
  echo "=== ... and whose they are, by the same file and the other key ==="
  "$H" fleet "$D/enrolled.fleet" verify till "$D/declared3.record" | sed 's/^/whose: /'
  echo "whose: exit ${PIPESTATUS[0]}"
  echo "=== the host: after the authority went away -- what it said stays said, and what came after is undated ==="
  audit mixed "$D/enrolled.fleet" "$D/alone2.statements" "$D/alone2.record"

  echo "=== negative 1: one second added to a statement ==="
  T1=$(sed -n '1s/.* t=\([0-9]*\) .*/\1/p' "$D/alone2.statements")
  sed -e "1s/ t=$T1 / t=$((T1 + 1)) /" "$D/alone2.statements" > "$D/changed.statements"
  audit changed "$D/enrolled.fleet" "$D/changed.statements" "$D/alone2.record"

  echo "=== negative 2: the same statements, offered to a fleet that takes its time from another machine ==="
  mkdir -p "$D/other"
  cp "$D/$CLOCK.machine" "$D/other/"
  sed -e "s|TIME_KEY \"$KEY\"|TIME_KEY \"$IKEY\"|" "$D/$TILL.machine" > "$D/other/$TILL.machine"
  sed -e "s|KEY \"$KEY\"|KEY \"$IKEY\"|" "$D/enrolled.fleet" > "$D/other/other.fleet"
  audit foreign "$D/other/other.fleet" "$D/alone2.statements" "$D/alone2.record"

  echo "=== negative 3: an entry taken out of the record ==="
  sed -e '3d' "$D/alone2.record" > "$D/removed.record"
  audit removed "$D/enrolled.fleet" "$D/alone2.statements" "$D/removed.record"

  echo "=== negative 4: the record cut at its end, which still hashes and chains ==="
  sed -n '1,2p' "$D/alone2.record" > "$D/cut.record"
  audit cut "$D/enrolled.fleet" "$D/alone2.statements" "$D/cut.record"

  echo "=== negative 5: nothing to verify ==="
  : > "$D/none.statements"
  audit nothing "$D/enrolled.fleet" "$D/none.statements" "$D/alone2.record"

  echo "=== negative 6: a fleet that takes its time from nobody ==="
  audit nobody machines/salle_makeen.fleet "$D/alone2.statements" "$D/alone2.record"
) > zig-out/wsl/time.body 2>&1
SCENE=$?

# Assemble one text from the boots. Each section is cut at ITS OWN first `boot: harb init` and the firmware
# noise before it dropped -- on the first line only, or a later section's banner loses which boot it belonged
# to (the JRN-1 defect). A boot the scene never reached says so, rather than leaving a gap that reads as quiet.
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
  cat zig-out/wsl/time.body
  echo "=== what each machine said ==="
  echo "enrol: the machine with the clock, booted on a disk that has never held its key:"
  section "$OA/transcript_enrol.txt" enrol
  echo "authority: the same machine on the disk that holds it, answering, before anybody has asked:"
  section "$OA/transcript_declared.txt" authority
  for n in 1 2 3; do
    echo "till $n: declared, with the authority on the wire:"
    section "$OT/transcript_declared$n.txt" "till$n"
  done
  for n in 1 2; do
    echo "alone $n: the authority gone, nobody on the wire:"
    section "$OT/transcript_alone$n.txt" "alone$n"
  done
  echo "impostor: a different machine, with a key of its own, answering from the authority's address:"
  section "$OA/transcript_impostor.txt" impostor
  echo "till 6: the same till, answered by it:"
  section "$OT/transcript_impostor.txt" till6
  echo "cut: the same till, with a statement the power cut short on its disk, and nobody on the wire:"
  section "$OT/transcript_cut.txt" cut
  echo "deadclock: the authority's declaration with a clock that is not there:"
  section "$OD/transcript_dead.txt" deadclock
  echo "nolink: the authority, on the disk that holds its key, with no network card to answer on:"
  section "$OA/transcript_nolink.txt" nolink
} > zig-out/wsl/time.full

# The key, the fingerprint, the hash, the signature, the entry digest and the time are made on the device or by its
# clock and differ in every build. Each DISTINCT key becomes KEY1, KEY2, ... and each DISTINCT fingerprint
# FP1, FP2, ... in order of first appearance, so what survives normalisation is the claim that matters: the
# same key twice reads as KEY1 twice, and a key that CHANGED would read as KEY2 and convict (IDN-1). The
# values are MARKED by sed at their exact lengths first, because [0-9a-f]+ also matches ordinary English
# (FLT-1: the "af" of "after"). The declaration digest is normalised here -- unlike the fleet's arc -- because
# the till's declaration carries the authority's key, which is new in every build.
sed -e 's/\r$//' \
    -e 's/declaration=[0-9a-f]\{16\}/declaration=D/g' \
    -e 's/hash=[0-9a-f]\{64\}/hash=H/g' -e 's/prev=[0-9a-f]\{64\}/prev=H/g' -e 's/sig=[0-9a-f]\{128\}/sig=S/g' \
    -e 's/entry=[0-9a-f]\{64\}/entry=H/g' -e 's/ t=[0-9]\{6,\} / t=T /g' \
    -e 's/ed25519 \([0-9a-f]\{64\}\)/ed25519 @@K@\1@@K@/g' \
    -e 's/fingerprint \([0-9a-f]\{16\}\)/fingerprint @@F@\1@@F@/g' \
    -e 's/authority=\([0-9a-f]\{16\}\)/authority=@@F@\1@@F@/g' \
    -e 's/word of \([0-9a-f]\{16\}\)/word of @@F@\1@@F@/g' \
    -e 's/word of key \([0-9a-f]\{16\}\)/word of key @@F@\1@@F@/g' \
    -e 's/\(the entry\|last entry\) [0-9a-f]\{8\}\b/\1 H8/g' \
    -e 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\} UTC/<time>/g' zig-out/wsl/time.full \
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
      }' > zig-out/wsl/time.normalised

{
  cat zig-out/wsl/time.full
  echo "=== judge ==="
  VERDICT=0
  if [ "$SCENE" != 0 ]; then
    echo "JUDGED: FAIL -- the scene stopped before it was done (exit $SCENE); what it said is above"
    VERDICT=1
  elif [ ! -f machines/time.expected ]; then
    echo "JUDGED: nothing pinned yet -- this run's text is at zig-out/wsl/time.normalised"
  elif diff -u machines/time.expected zig-out/wsl/time.normalised > zig-out/wsl/time.diff; then
    echo "JUDGED: the arc matches machines/time.expected line for line ($(wc -l < zig-out/wsl/time.normalised) lines)"
  else
    echo "JUDGED: FAIL -- the arc differs from machines/time.expected:"; cat zig-out/wsl/time.diff
    VERDICT=1
  fi
  echo "exit $VERDICT"
  exit "$VERDICT"
} 2>&1 | tee "$LOG"
#
# THE VERDICT IS THE BLOCK'S, NOT tee's: a pipeline exits with its LAST command's status (VDCT-1), so the
# status of the block is read from PIPESTATUS.
exit "${PIPESTATUS[0]}"
