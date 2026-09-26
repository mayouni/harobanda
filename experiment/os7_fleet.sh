#!/bin/bash
# os7_fleet.sh -- the whole arc of attribution, on a real device (FLT-1).
#
# A machine makes its own key on its first boot and never sends the
# private half anywhere. Until a fleet exists, only that machine can
# verify its own record -- which is attribution nobody else can test, and
# a claim nobody can test is not evidence.
#
# This runs the arc end to end and lets the negatives decide it:
#
#   1. boot machines/fleet_temoin.machine twice. The first makes the key
#      and writes entry 1 after its verdict; the second publishes the
#      public half and the record as the exact bytes that were signed.
#   2. enrol -- write that public half into a fleet file, which is what
#      enrolment IS: somebody reading a line and writing it down.
#   3. verify the record against the fleet. No secret takes part.
#   4. THE NEGATIVES, which are what decide it:
#        - one word changed in the record (the verdict, the field
#          somebody would want to change) must be caught, by position
#        - the same record offered as ANOTHER device's must be refused
#        - a member with no key enrolled must be REPORTED, never guessed
#   5. THE CARD IS REBUILT (RET-1): a new disk, so a new key. The old key
#      is RETIRED through the head the verifier printed for the old
#      card's record, and both records are heard -- the old one through
#      its head, the new one in full.
#   6. THE OLD CARD, BOOTED AGAIN -- the stolen card. Nothing is faked:
#      the saved disk goes back in, the device boots, and it goes on
#      signing with the key the fleet retired. Every entry past the head
#      must be refused, by position, however well it chains.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os7_fleet.sh
#
# Log: zig-out/wsl/fleet.txt; the judged text: machines/fleet.expected
set -u
cd "$(dirname "$0")/.." || exit 1
NAME=fleet_temoin
T=zig-out/image/$NAME/transcript.txt
W=zig-out/fleet
S=zig-out/cross/x86_64-linux-musl/harb
BODY=zig-out/wsl/fleet.body
LOG=zig-out/wsl/fleet.txt
mkdir -p zig-out/wsl
# THE LOG IS THIS RUN'S, ON EVERY PATH (RET-1). The log was copied from the
# body as the script's last act, and every `exit 1` inside the block left
# before it -- so a run that stopped because the device's boot differed
# exited 1 while fleet.txt, the file every reader is told to read, still
# said the PREVIOUS run matched and exited 0. A verdict that reaches the
# exit code and not the log convicts only whoever reads exit codes. The
# trap writes the log however the script ends; removing it first means a
# run killed outright leaves no log rather than an old green one.
rm -f "$LOG"
trap 'cp "$BODY" "$LOG" 2>/dev/null' EXIT

{
  echo "=== the device: two boots, a key made once and a record it can publish ==="
  if ! bash experiment/os2_image.sh $NAME > /dev/null 2>&1; then
    echo "the device's boot differs from machines/$NAME.expected -- see zig-out/wsl/image_$NAME.txt"; exit 1
  fi
  grep -E '^(again: )?(enrol|record) ' "$T" | sed 's/^again: //' | sed 's/^/device: /'

  KEY=$(grep -oE 'enrol '"$NAME"' ed25519 [0-9a-f]+' "$T" | tail -1 | awk '{print $4}')
  if [ -z "$KEY" ]; then echo "the device published no key"; exit 1; fi

  rm -rf "$W"; mkdir -p "$W"
  cp machines/$NAME.machine "$W/"
  grep -E '^(again: )?record seq=' "$T" | sed 's/^again: //; s/^record //' > "$W/$NAME.journal"
  N=$(grep -c . "$W/$NAME.journal")
  echo "carried: $N entr$([ "$N" = 1 ] && echo y || echo ies) off the machine, as the exact bytes that were signed"

  # The fleet BEFORE enrolment: a member that keeps a signed record and
  # that no holder of this file can speak for. The court does not refuse
  # it -- a key cannot be declared before the device that makes it exists.
  cat > "$W/before.fleet" <<EOF
DEFINE FLEET atelier AS () RATIONALE "before the device had ever booted"
DEFINE MEMBER temoin AS (
  DECLARATION "$NAME.machine"
) RATIONALE "declared before it existed, so nobody can speak for it yet"
EOF
  echo "=== the roll before enrolment ==="
  "$S" fleet "$W/before.fleet" | sed 's/^/roll: /'

  cat > "$W/after.fleet" <<EOF
DEFINE FLEET atelier AS () RATIONALE "the same fleet, after the device published who it is"
DEFINE MEMBER temoin AS (
  DECLARATION "$NAME.machine",
  KEY "$KEY"
) RATIONALE "enrolled from the line the device printed on its own console"
EOF
  echo "=== the roll after enrolment ==="
  "$S" fleet "$W/after.fleet" | sed 's/^/roll: /'

  echo "=== the act: a record verified by somebody who does not hold the secret ==="
  "$S" fleet "$W/after.fleet" verify temoin "$W/$NAME.journal" | sed 's/^/verify: /'

  echo "=== negative 1: one word changed, and it is the verdict ==="
  sed 's/verdict=matched/verdict=differed/' "$W/$NAME.journal" > "$W/tampered.journal"
  "$S" fleet "$W/after.fleet" verify temoin "$W/tampered.journal" | sed 's/^/tampered: /'

  echo "=== negative 2: the same record offered as another device's ==="
  OTHER=$(printf '%s' "$KEY" | tr '0123456789abcdef' '1234567890fedcba')
  sed "s/KEY \"$KEY\"/KEY \"$OTHER\"/" "$W/after.fleet" > "$W/other.fleet"
  "$S" fleet "$W/other.fleet" verify temoin "$W/$NAME.journal" | sed 's/^/foreign: /'

  echo "=== negative 3: a member nobody has enrolled ==="
  "$S" fleet "$W/before.fleet" verify temoin "$W/$NAME.journal" | sed 's/^/unenrolled: /'

  # ---- RET-1: the card is rebuilt, and the old one is booted again ------
  # The first card is the disk the two boots above wrote. Keep it: it is
  # the card that will be stolen.
  IMGDIR=zig-out/image/$NAME
  cp "$IMGDIR/disk0.img" "$W/card1.img"
  # The head the fleet will trust the old key THROUGH, read from the
  # verifier -- which prints it only once the record has verified. The
  # verdict is RECEIVED before its content is used (NAM-2).
  if ! V=$("$S" fleet "$W/after.fleet" verify temoin "$W/$NAME.journal"); then
    echo "the old card's record did not verify, so it has no head to trust"; exit 1
  fi
  HEAD=$(printf '%s\n' "$V" | grep -oE 'hash=[0-9a-f]{64}' | head -1 | cut -d= -f2)
  if [ ${#HEAD} != 64 ]; then echo "the verifier printed no head"; exit 1; fi

  echo "=== the card is rebuilt: a new disk, so a new key ==="
  if ! bash experiment/os2_image.sh $NAME > /dev/null 2>&1; then
    echo "the rebuilt card's boot differs from machines/$NAME.expected -- see zig-out/wsl/image_$NAME.txt"; exit 1
  fi
  KEY2=$(grep -oE 'enrol '"$NAME"' ed25519 [0-9a-f]+' "$T" | tail -1 | awk '{print $4}')
  if [ -z "$KEY2" ] || [ "$KEY2" = "$KEY" ]; then echo "the rebuilt card made no key of its own"; exit 1; fi
  grep -E '^(again: )?enrol ' "$T" | tail -1 | sed 's/^again: //' | sed 's/^/rebuilt: /'
  grep -E '^(again: )?record seq=' "$T" | sed 's/^again: //; s/^record //' > "$W/card2.journal"

  cat > "$W/rebuilt.fleet" <<EOF
DEFINE FLEET atelier AS () RATIONALE "the same fleet, after the device's card was rebuilt"
DEFINE MEMBER temoin AS (
  DECLARATION "$NAME.machine",
  KEY "$KEY2"
) RATIONALE "enrolled again, from the line the rebuilt card printed"
DEFINE RETIREMENT carte_1 AS (
  MEMBER temoin,
  KEY "$KEY",
  THROUGH "$HEAD"
) RATIONALE "the first card was replaced; its last export verified, and this is that export's head"
EOF
  echo "=== the roll after the rebuild ==="
  "$S" fleet "$W/rebuilt.fleet" | sed 's/^/roll: /'
  echo "=== the old card's record, heard through its head ==="
  "$S" fleet "$W/rebuilt.fleet" verify temoin "$W/$NAME.journal" | sed 's/^/retired: /'
  echo "=== the rebuilt card's record, heard in full ==="
  "$S" fleet "$W/rebuilt.fleet" verify temoin "$W/card2.journal" | sed 's/^/rebuilt: /'

  echo "=== negative 4: the OLD card, booted again -- the stolen card ==="
  cp "$W/card1.img" "$IMGDIR/disk0.img"
  ( cd "$IMGDIR" && timeout --foreground 120 bash boot.cmd < /dev/null > transcript_stolen.txt 2>&1 )
  sed 's/\r$//' "$IMGDIR/transcript_stolen.txt" | grep -E '^record seq=' | sed 's/^record //' > "$W/stolen.journal"
  N=$(grep -c . "$W/stolen.journal")
  echo "carried: $N entr$([ "$N" = 1 ] && echo y || echo ies) off the old card, signed with the key the fleet retired"
  "$S" fleet "$W/rebuilt.fleet" verify temoin "$W/stolen.journal" | sed 's/^/stolen: /'

  echo "=== the estate's own fleet, judged ==="
  "$S" fleet machines/salle_makeen.fleet | sed 's/^/salle: /'
} > "$BODY" 2>&1

cat "$BODY"

# The key, the fingerprint, the hash and the signature are made on the
# device from its own randomness and differ in every build. Each DISTINCT
# one becomes KEY1, KEY2, ... and FP1, FP2, ... in order of first
# appearance, so what survives normalisation is the claim that matters:
# the same key twice reads as KEY1 twice, and a key that CHANGED would
# read as KEY2 and convict (the rule IDN-1 paid for).
#
# The DECLARATION digest is deliberately NOT normalised. It is the sha256
# of a file in git, so it must be the same in every build, and pinning it
# is how a changed machine file is caught here.
# sed marks the values FIRST, with exact lengths, because [0-9a-f]+ also
# matches ordinary English -- the first run of this read the "af" of
# "after" as a fingerprint and wrote FP1 into the middle of a word. Then
# awk maps each DISTINCT marked value, which sed cannot do.
sed -e 's/\r$//' -e 's/hash=[0-9a-f]*/hash=H/g' -e 's/sig=[0-9a-f]*/sig=S/g' \
    -e 's/ed25519 \([0-9a-f]\{64\}\)/ed25519 @@K@\1@@K@/g' \
    -e 's/fingerprint \([0-9a-f]\{16\}\)/fingerprint @@F@\1@@F@/g' "$BODY" \
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
      }' > zig-out/wsl/fleet.normalised

{
  echo "=== judge ==="
  VERDICT=0
  if [ ! -f machines/fleet.expected ]; then
    echo "JUDGED: nothing pinned yet -- this run's text is at zig-out/wsl/fleet.normalised"
  elif diff -u machines/fleet.expected zig-out/wsl/fleet.normalised > zig-out/wsl/fleet.diff; then
    echo "JUDGED: the arc matches machines/fleet.expected line for line ($(grep -c . zig-out/wsl/fleet.normalised) lines)"
  else
    echo "JUDGED: FAIL -- the arc differs from machines/fleet.expected:"; cat zig-out/wsl/fleet.diff
    VERDICT=1
  fi
  echo "exit $VERDICT"
  exit "$VERDICT"
} | tee -a "$BODY"
#
# THE VERDICT IS THE BLOCK'S, NOT tee's. A pipeline exits with its LAST
# command's status, so this script exited 0 however the judge ruled, and
# nothing automated could hear it. Same defect as os2_image.sh, found by
# the guided tour's lesson 6 and then grepped for (LRN-1).
VERDICT=${PIPESTATUS[0]}

exit "$VERDICT"
