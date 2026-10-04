#!/bin/bash
# os8_links.sh -- two links, three machines, and a till that reaches the server it names (FWD-1).
#
# The smallest cloud (doc/CLOUD.md, rung 2): a box that is the way between a front link and a
# core link, a till on the front, a server on the core. Three QEMU processes joined by two socket
# netdevs -- one L2 segment per link, each between exactly two machines -- because no machine
# proves anything alone: a box with nobody to carry for would sit at its timeout, and a till
# with no box would be right to say nobody answered.
#
#   box     machines/cloud_front.machine, two NICs. It serves both links, forwards between them
#           and says so; once, and then it waits.
#   core    machines/cloud_core.machine with machines/ringserv.pack placed on it (`harb place`):
#           RingServ, listening on the core link, behind the box. It takes the address the box
#           promised it and says it is serving.
#   till    machines/cloud_till.machine. It learns its address, the router and the resolver from
#           the box, asks for commons.core.cloud, CONNECTS to it through the box and says what it
#           answered, then asks for two names it must not be given.
#
# Three rounds, and the second and third are what make the first mean something:
#
#   crossing   the declared till. A packet crosses, and comes back.
#   stranger   the same till image with a hardware address nobody declared. It gets no lease, so
#              it learns no router and no resolver, and reaches nothing: a box that now forwards
#              admits no more devices than before.
#   closed     the same set with a box that does NOT forward (its declaration, less one clause).
#              It is silent about the far link -- the name does not exist for the till -- and the
#              till reaches nothing: forwarding is what makes the way, and names follow the way,
#              never the other way round.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os8_links.sh
#
# Needs RingServ built (powershell experiment/ringserv_build.ps1), as os9_cloud.sh does.
# Log: zig-out/wsl/links.txt; the judged text: machines/cloud_links.expected
set -u
cd "$(dirname "$0")/.." || exit 1
H=zig-out/cross/x86_64-linux-musl/harb
FLEET=machines/cloud_links.fleet
LOG=zig-out/wsl/links.txt
PORT=${HARB_LINKS_PORT:-14600}
FRONT=cloud_front
CLOSED=cloud_front_closed
TILL=cloud_till
CORE=cloud_core_ringserv
OF=zig-out/image/$FRONT
OX=zig-out/image/$CLOSED
OT=zig-out/image/$TILL
OC=zig-out/image/$CORE
mkdir -p zig-out/wsl zig-out/placed

# The hardware addresses come from the DECLARATION, never from a constant here (HDW-1): the
# fleet says which device each member is, and the box's peers promise addresses to exactly those.
if ! TILL_MAC=$("$H" fleet "$FLEET" hardware till); then
  echo "the fleet is refused, so there are no devices to be:"; echo "$TILL_MAC"; exit 1
fi
if ! CORE_MAC=$("$H" fleet "$FLEET" hardware core); then
  echo "the fleet is refused, so there are no devices to be:"; echo "$CORE_MAC"; exit 1
fi
STRANGER_MAC=52:54:00:77:77:77    # nobody, and deliberately in no declaration
if [ -z "$TILL_MAC" ] || [ -z "$CORE_MAC" ]; then
  echo "the fleet named no hardware for these members -- $H fleet $FLEET"; exit 1
fi

# Rewrite a derived boot.cmd onto this round's wires. The user-mode netdev QEMU is given by
# default is a network of one; a socket netdev is a real L2 segment between exactly two
# machines. Arguments after the two files are quadruples: <netdev id> <listen|connect> <port> <mac or "">.
rewire() { # $1 = derived boot.cmd, $2 = the rewritten one
  local in=$1 out=$2; shift 2
  cp "$in" "$out"
  while [ $# -ge 4 ]; do
    local id=$1 mode=$2 port=$3 mac=$4; shift 4
    local host=""; [ "$mode" = connect ] && host=127.0.0.1
    sed -i -e "s|-netdev user,id=$id|-netdev socket,id=$id,$mode=$host:$port|" "$out"
    if [ -n "$mac" ]; then
      sed -i -e "s|-device virtio-net-pci,netdev=$id|-device virtio-net-pci,netdev=$id,mac=$mac|" "$out"
    fi
  done
}

# A machine is up when it has SAID it is: waiting for a line the machine itself printed beats
# sleeping for a number somebody guessed.
await_line() { # $1 = transcript, $2 = fixed text, $3 = seconds
  local n=0
  while [ "$n" -lt $(( $3 * 4 )) ]; do
    grep -qF "$2" "$1" 2>/dev/null && return 0
    sleep 0.25; n=$((n+1))
  done
  return 1
}

# the box without its one clause: the same declaration less FORWARD, judged before it is imaged
make_closed() {
  sed -e '/^  FORWARD yes$/d' -e 's|^  CONSOLE "/dev/ttyS0",$|  CONSOLE "/dev/ttyS0"|' machines/cloud_front.machine > zig-out/placed/$CLOSED.machine
  "$H" check zig-out/placed/$CLOSED.machine > /dev/null
}

{
  echo "=== the core: machines/cloud_core.machine with machines/ringserv.pack placed on it ==="
  rm -f zig-out/placed/$CORE.machine
  "$H" place machines/cloud_core.machine machines/ringserv.pack --out zig-out/placed/$CORE.machine || { echo "JUDGED: the placement was refused, so there is nothing to boot"; exit 1; }
  [ -f zig-out/ringserv/ringserv ] || { echo "no RingServ under zig-out/ringserv (powershell experiment/ringserv_build.ps1)"; exit 1; }
  echo "=== the box without its one clause ==="
  make_closed || { echo "the box without FORWARD is refused: $CLOSED"; exit 1; }
  echo "zig-out/placed/$CLOSED.machine: judged"

  echo "=== images (built, not booted) ==="
  build() { # $1 = image name, then the environment of os2_image.sh for it
    local name=$1; shift
    env "$@" HARB_NO_BOOT=1 bash experiment/os2_image.sh "$name" > /dev/null 2>&1
    if [ -f "zig-out/image/$name/boot.cmd" ]; then
      echo "$name: image built ($(grep -c . "zig-out/image/$name/expected") expected lines)"
    else
      echo "$name: IMAGE NOT BUILT -- see zig-out/wsl/image_$name.txt"; echo "exit 1"; exit 1
    fi
  }
  build $FRONT
  build $CLOSED HARB_MACHINE_FILE=zig-out/placed/$CLOSED.machine
  build $TILL
  build $CORE HARB_MACHINE_FILE=zig-out/placed/$CORE.machine HARB_STAGE=machines/ringserv_core.stage

  # one round: the box and the core are machines that wait, and the till is a machine that asks
  # and ends. $1 = label, $2 = the box's image dir, $3 = the till's hardware address, $4 = the
  # line that says the box is serving, $5 = the first port (two wires: this and the next)
  round() {
    local label=$1 obox=$2 mac=$3 boxline=$4 pa=$5 pb=$(( $5 + 1 ))
    rm -f "$obox/transcript_$label.txt" "$OT/transcript_$label.txt" "$OC/transcript_$label.txt"
    # the box listens on both wires; the core and the till connect, one to each
    rewire "$obox/boot.cmd" "$obox/boot_pair.cmd" n0 listen "$pa" "" n1 listen "$pb" ""
    rewire "$OC/boot.cmd"   "$OC/boot_pair.cmd"   n0 connect "$pb" "$CORE_MAC"
    rewire "$OT/boot.cmd"   "$OT/boot_pair.cmd"   n0 connect "$pa" "$mac"
    # the core must keep serving while the till asks: the emulator's `--halt-on-verdict` ends a
    # machine whose worlds are all ready, which is right for a court and wrong for a server
    sed -i -e 's/ --halt-on-verdict//' "$OC/boot_pair.cmd"
    ( cd "$obox" && timeout --foreground 150 bash boot_pair.cmd < /dev/null > "transcript_$label.txt" 2>&1 ) &
    local boxjob=$!
    if ! await_line "$obox/transcript_$label.txt" "$boxline" 60; then
      echo "the box never said it was serving -- see $obox/transcript_$label.txt"
      pkill -f "listen=:$pa" 2>/dev/null; wait "$boxjob" 2>/dev/null; return
    fi
    ( cd "$OC" && timeout --foreground 150 bash boot_pair.cmd < /dev/null > "transcript_$label.txt" 2>&1 ) &
    local corejob=$!
    # not "ready" but the machine's own verdict, which comes once the server has held its health
    # window: a till that finished sooner would have the core killed before it had judged itself,
    # and the pinned text would depend on how fast an emulator booted (BDG-1: a margin, not a fixture)
    if ! await_line "$OC/transcript_$label.txt" "boot: judge --" 90; then
      echo "the core never judged its own boot -- see $OC/transcript_$label.txt"
    else
      ( cd "$OT" && timeout --foreground 90 bash boot_pair.cmd < /dev/null > "transcript_$label.txt" 2>&1 )
      echo "exit $?" >> "$OT/transcript_$label.txt"
    fi
    pkill -f "connect=127.0.0.1:$pb" 2>/dev/null
    pkill -f "listen=:$pa" 2>/dev/null
    wait "$corejob" 2>/dev/null
    wait "$boxjob" 2>/dev/null
  }

  echo "=== round 1: the declared till ==="
  round declared "$OF" "$TILL_MAC" "boot: forward -- between front and core" "$PORT"
  echo "=== round 2: a device nobody declared ==="
  round stranger "$OF" "$STRANGER_MAC" "boot: forward -- between front and core" "$((PORT+2))"
  echo "=== round 3: a box that does not forward ==="
  round closed "$OX" "$TILL_MAC" "boot: names core -- core.cloud" "$((PORT+4))"

  # Assemble one text from the boots. Each section is cut at ITS OWN first `boot: harb init` and
  # the firmware noise before it dropped -- on the first line only, or a later section's banner
  # loses which boot it belonged to (the JRN-1 defect).
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
    echo "box: the way between the links, before anyone has asked:"
    section "$OF/transcript_declared.txt" box
    echo "core: the server, behind the box:"
    section "$OC/transcript_declared.txt" core
    echo "till: the declared device, which knows nothing and asks:"
    section "$OT/transcript_declared.txt" till
    echo "stranger: the same till, with a hardware address nobody declared:"
    section "$OT/transcript_stranger.txt" stranger
    echo "closed box: the same box less its one clause, which serves both links and is the way between neither:"
    section "$OX/transcript_closed.txt" closedbox
    echo "closed: the same till, with that box:"
    section "$OT/transcript_closed.txt" closed
  } > zig-out/wsl/links.normalised
  echo "--- transcript"; cat zig-out/wsl/links.normalised
  echo "=== judge ==="
  VERDICT=0
  if [ ! -f machines/cloud_links.expected ]; then
    echo "JUDGED: nothing pinned yet -- this run's text is at zig-out/wsl/links.normalised"
  elif diff -u machines/cloud_links.expected zig-out/wsl/links.normalised > zig-out/wsl/links.diff; then
    echo "JUDGED: the three machines said what machines/cloud_links.expected says, line for line ($(wc -l < zig-out/wsl/links.normalised) lines)"
  else
    echo "JUDGED: FAIL -- the set differs from machines/cloud_links.expected:"; cat zig-out/wsl/links.diff
    VERDICT=1
  fi
  echo "exit $VERDICT"
  exit "$VERDICT"
} 2>&1 | tee "$LOG"
#
# THE VERDICT IS THE BLOCK'S, NOT tee's: a pipeline exits with its LAST command's status
# (VDCT-1), so the status of the block is read from PIPESTATUS.
exit "${PIPESTATUS[0]}"
