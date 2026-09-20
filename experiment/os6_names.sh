#!/bin/bash
# os6_names.sh -- the first time two Harobanda machines meet on a wire (NAM-1).
#
# One box that is the network's own server of addresses and names, one
# till that declares nothing and asks. They are booted TOGETHER, in two
# QEMU processes joined by a socket netdev, because neither proves
# anything alone: a box with nobody to serve would sit at its timeout,
# and a device with no server would be right to say nobody answered.
#
# Three rounds, and the third is the point of the whole seat:
#
#   box       the server, once. It says who it is, who it serves, and
#             what address each of them gets, and then it waits.
#   till      the declared device. It learns its address, the name of
#             the network and where to ask, then asks for the printer
#             BY NAME and gets the number it was never told.
#   stranger  the SAME image with a hardware address nobody declared.
#             It gets nothing at all, and says so in the words the DHCP
#             client has always used: no server answered on this network.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os6_names.sh
#
# Log: zig-out/wsl/names.txt; the judged text: machines/names.expected
set -u
cd "$(dirname "$0")/.." || exit 1
BOX=makeen_names
TILL=caisse_makeen
OB=zig-out/image/$BOX
OT=zig-out/image/$TILL
LOG=zig-out/wsl/names.txt
PORT=${HARB_NAMES_PORT:-14567}
FLEET=machines/salle_makeen.fleet
S=zig-out/cross/x86_64-linux-musl/harb
# Read from the DECLARATION, never from a constant here (HDW-1). These
# two addresses used to be literals in this file, which made this script
# the only place in the estate where a fact about a deployment lived
# outside a declaration -- and the fleet court had no way to check that
# the address the box promises and the device that claims it are one.
# Ask for the addresses, and READ THE VERDICT rather than the emptiness
# of the answer. A refused fleet does not answer empty: it prints the
# refusal on stdout and exits 1, so `[ -z ... ]` was false and this
# script went on to boot QEMU with a MAC that was a whole sentence. It
# then failed four steps later with "the box never said it was serving",
# which is a symptom and not the cause. Same family as VDCT-1: the
# verdict existed and the caller was not reading it.
if ! TILL_MAC=$("$S" fleet "$FLEET" hardware caisse); then
  echo "the fleet is refused, so there are no devices to be:"; echo "$TILL_MAC"; exit 1
fi
if ! BOX_MAC=$("$S" fleet "$FLEET" hardware boitier); then
  echo "the fleet is refused, so there are no devices to be:"; echo "$BOX_MAC"; exit 1
fi
STRANGER_MAC=52:54:00:77:77:77    # nobody, and deliberately in no declaration
mkdir -p zig-out/wsl
if [ -z "$TILL_MAC" ] || [ -z "$BOX_MAC" ]; then
  echo "the fleet named no hardware for these members -- $S fleet $FLEET"; exit 1
fi

# Rewrite a derived boot.cmd onto the pair's own wire. The user-mode
# netdev QEMU is given by default is a network of one; a socket netdev
# is a real L2 segment between exactly two machines, which is what a
# server and a client need to be able to say anything to each other.
wire() { # $1 = boot.cmd, $2 = listen|connect, $3 = port, $4 = mac
  sed -e "s|-netdev user,id=n0|-netdev socket,id=n0,$2=$([ "$2" = connect ] && echo 127.0.0.1):$3|" \
      -e "s|-device virtio-net-pci,netdev=n0|-device virtio-net-pci,netdev=n0,mac=$4|" "$1"
}

# The box is up when it has SAID it is serving. Waiting for a line the
# machine itself printed beats sleeping for a number somebody guessed:
# the wire is ready exactly when the server says it is.
await_server() { # $1 = transcript, $2 = seconds
  local n=0
  while [ "$n" -lt $(( $2 * 4 )) ]; do
    grep -q 'boot: names salle -- makeen' "$1" 2>/dev/null && return 0
    sleep 0.25; n=$((n+1))
  done
  return 1
}

{
  echo "=== images (built, not booted) ==="
  for m in $BOX $TILL; do
    HARB_NO_BOOT=1 bash experiment/os2_image.sh "$m" > /dev/null 2>&1
    if [ -f "zig-out/image/$m/boot.cmd" ]; then
      echo "$m: image built ($(grep -c . "zig-out/image/$m/expected") expected lines)"
    else
      echo "$m: IMAGE NOT BUILT -- see zig-out/wsl/image_$m.txt"; echo "exit 1"; exit 1
    fi
  done

  round() { # $1 = label, $2 = mac, $3 = port
    rm -f "$OB/transcript_$1.txt" "$OT/transcript_$1.txt"
    wire "$OB/boot.cmd"  listen  "$3" "$BOX_MAC" > "$OB/boot_pair.cmd"
    wire "$OT/boot.cmd"  connect "$3" "$2"       > "$OT/boot_pair.cmd"
    ( cd "$OB" && timeout --foreground 90 bash boot_pair.cmd < /dev/null > "transcript_$1.txt" 2>&1 ) &
    local boxjob=$!
    if await_server "$OB/transcript_$1.txt" 40; then
      ( cd "$OT" && timeout --foreground 60 bash boot_pair.cmd < /dev/null > "transcript_$1.txt" 2>&1 )
      echo "exit $?" >> "$OT/transcript_$1.txt"
    else
      echo "the box never said it was serving -- see $OB/transcript_$1.txt"
    fi
    # the box is a machine that waits: nothing but this ends it
    pkill -f "socket,id=n0,listen=:$3" 2>/dev/null
    wait "$boxjob" 2>/dev/null
  }

  echo "=== round 1: the declared till ==="
  round declared "$TILL_MAC" "$PORT"
  echo "=== round 2: a device nobody declared ==="
  round stranger "$STRANGER_MAC" "$((PORT+1))"

  # Assemble one text from three boots. Each section is cut at ITS OWN
  # first `boot: harb init` and the firmware noise before it dropped --
  # on the first line only, or a later section's banner loses which boot
  # it belonged to (the JRN-1 defect).
  section() { # $1 = file, $2 = prefix
    sed -e 's/\r$//' "$1" \
      | sed -n '/^.*boot: harb init/,$p' \
      | sed -e '1s/^.*boot: harb init/boot: harb init/' \
      | sed -E 's/pid ([2-9]|[1-9][0-9]+)\b/pid N/g' \
      | sed -e '/^qemu exit$/d; /^qemu exit [0-9]*$/d; /^exit [0-9]*$/d' \
      | sed -e '/terminating on signal/d' \
      | sed "s/^/$2: /"
  }
  {
    echo "box: the network's own server of names, before anyone has asked:"
    section "$OB/transcript_declared.txt" box
    echo "till: the declared device, which knows nothing and asks:"
    section "$OT/transcript_declared.txt" till
    echo "stranger: the same image, with a hardware address nobody declared:"
    section "$OT/transcript_stranger.txt" stranger
  } > zig-out/wsl/names.normalised
  echo "--- transcript"; cat zig-out/wsl/names.normalised
  echo "=== judge ==="
  VERDICT=0
  if [ ! -f machines/names.expected ]; then
    echo "JUDGED: nothing pinned yet -- this run's text is at zig-out/wsl/names.normalised"
  elif diff -u machines/names.expected zig-out/wsl/names.normalised > zig-out/wsl/names.diff; then
    echo "JUDGED: the two machines said what machines/names.expected says, line for line ($(wc -l < zig-out/wsl/names.normalised) lines)"
  else
    echo "JUDGED: FAIL -- the pair differs from machines/names.expected:"; cat zig-out/wsl/names.diff
    VERDICT=1
  fi
  echo "exit $VERDICT"
  exit "$VERDICT"
} 2>&1 | tee "$LOG"
#
# THE VERDICT IS THE BLOCK'S, NOT tee's. A pipeline exits with its LAST
# command's status, so this script exited 0 however the judge ruled, and
# nothing automated could hear it. Same defect as os2_image.sh, found by
# the guided tour's lesson 6 and then grepped for (LRN-1).
exit "${PIPESTATUS[0]}"
