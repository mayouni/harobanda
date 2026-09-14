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
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os7_fleet.sh
#
# Log: zig-out/wsl/fleet.txt; the judged text: machines/fleet.expected
set -u
cd "$(dirname "$0")/.." || exit 1
NAME=fleet_temoin
T=zig-out/image/$NAME/transcript.txt
W=zig-out/fleet
S=zig-out/cross/x86_64-linux-musl/stzos
BODY=zig-out/wsl/fleet.body
LOG=zig-out/wsl/fleet.txt
mkdir -p zig-out/wsl

{
  echo "=== the device: two boots, a key made once and a record it can publish ==="
  bash experiment/os2_image.sh $NAME > /dev/null 2>&1
  if [ ! -f "$T" ]; then echo "no transcript -- see zig-out/wsl/image_$NAME.txt"; exit 1; fi
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
  if [ ! -f machines/fleet.expected ]; then
    echo "JUDGED: nothing pinned yet -- this run's text is at zig-out/wsl/fleet.normalised"
  elif diff -u machines/fleet.expected zig-out/wsl/fleet.normalised > zig-out/wsl/fleet.diff; then
    echo "JUDGED: the arc matches machines/fleet.expected line for line ($(grep -c . zig-out/wsl/fleet.normalised) lines)"
  else
    echo "JUDGED: FAIL -- the arc differs from machines/fleet.expected:"; cat zig-out/wsl/fleet.diff
  fi
  echo "exit 0"
} | tee -a "$BODY"

cp "$BODY" "$LOG"
