#!/bin/bash
# os8_links.sh -- two links, three machines, and a till that reaches the server it names
# (FWD-1), and since FRONT-2 reaches it through the DOOR too: the box ends TLS for the till.
#
# The smallest cloud (doc/CLOUD.md, rung 2 and rung 3b): a box that is the way between a front
# link and a core link, a till on the front, a server on the core. Three QEMU processes joined by
# two socket netdevs -- one L2 segment per link, each between exactly two machines -- because no
# machine proves anything alone: a box with nobody to carry for would sit at its timeout, and a
# till with no box would be right to say nobody answered.
#
#   box     machines/cloud_front.machine with machines/front.pack placed on it (`harb place`):
#           two NICs. It serves both links, forwards between them and says so; and it is the
#           door of the front link: Caddy ends TLS on 443 as front.cloud, the box's own name
#           there, under a root this script makes BY HAND and seeds on the box's disk
#           (experiment/front_seed.sh), and reaches the server on the core link in plain HTTP.
#   core    machines/cloud_core.machine with machines/ringserv.pack placed on it: RingServ,
#           listening on the core link, behind the box. It takes the address the box promised it
#           and says it is serving.
#   till    machines/cloud_till.machine. It learns its address, the router and the resolver from
#           the box, asks for commons.core.cloud, CONNECTS to it through the box and says what it
#           answered; asks the same through the door over TLS, trusting the root's public half it
#           was given (machines/cloud_till.stage) and nothing else; asks the box's OTHER name on
#           the same port and is refused by its own client; then asks for two names it must not
#           be given.
#
# The fleet says who the door is (machines/cloud_links.fleet, FRONT): which member, on which
# link, by what name, under which root -- by its fingerprint, which a repository cannot know
# because the root is made at every run. So the fingerprint is written into a COPY of the fleet,
# which is what enrolment is (as os10_time.sh enrols a key), the copy is judged, and the till's
# own line -- "signed under the root fingerprint ..." -- is held to what the copy declares.
#
# Three rounds, and the second and third are what make the first mean something:
#
#   crossing   the declared till. A packet crosses, and comes back; and the door answers.
#   stranger   the same till image with a hardware address nobody declared. It gets no lease, so
#              it learns no router and no resolver, and reaches nothing -- not the server, not
#              the door. That is the register's reach and no more: the box leases an address, a
#              router and a resolver to the devices it declared and to nobody else. It does NOT
#              stop a device that chose its own address and set the box as its gateway --
#              forwarding filters nothing, and being admitted to a lease is not being admitted
#              to the way (a filter is rung 6).
#   closed     the same set with a box that does NOT forward (its declaration, less one clause).
#              It is silent about the far link -- the name does not exist for the till -- and the
#              till reaches nothing by the way: forwarding is what makes the way, and names follow
#              the way, never the other way round. THE DOOR STILL ANSWERS: a front is a way of its
#              own. FORWARD governs the packets that pass THROUGH the box; a proxy is the box asking
#              the server on the till's behalf, by its own leg on the core link. Which is why the
#              fleet declares a FRONT, as it declares a ROUTE: a front on a member of two links is
#              a door to the second link, route or no route, and the declaration is the fleet
#              saying it was meant.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os8_links.sh
#
# Needs RingServ built (powershell experiment/ringserv_build.ps1), as os9_cloud.sh does, Caddy
# fetched (experiment/caddy_fetch.sh), and openssl.
# Log: zig-out/wsl/links.txt; the judged text: machines/cloud_links.expected
set -u
cd "$(dirname "$0")/.." || exit 1
H=zig-out/cross/x86_64-linux-musl/harb
FLEET=machines/cloud_links.fleet
LOG=zig-out/wsl/links.txt
PORT=${HARB_LINKS_PORT:-14600}
BOX=cloud_front
FRONT=cloud_front_door            # the box with the front placed on it
CLOSED=cloud_front_closed         # the same, less FORWARD
TILL=cloud_till
CORE=cloud_core_ringserv
CA=zig-out/front/ca               # the root, made here at every run and never in git
D=zig-out/placed/links            # the fleet and its machines, with the root's fingerprint written in
OF=zig-out/image/$FRONT
OX=zig-out/image/$CLOSED
OT=zig-out/image/$TILL
OC=zig-out/image/$CORE
mkdir -p zig-out/wsl zig-out/placed "$D"

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

# the box without its one clause: the same declaration (with the front placed) less FORWARD,
# judged before it is imaged
make_closed() {
  sed -e '/^  FORWARD yes$/d' -e 's|^  CONSOLE "/dev/ttyS0",$|  CONSOLE "/dev/ttyS0"|' zig-out/placed/$FRONT.machine > zig-out/placed/$CLOSED.machine
  "$H" check zig-out/placed/$CLOSED.machine > /dev/null
}

{
  [ -x zig-out/caddy/caddy ] || { echo "no Caddy under zig-out/caddy (experiment/caddy_fetch.sh)"; exit 1; }
  [ -f zig-out/ringserv/ringserv ] || { echo "no RingServ under zig-out/ringserv (powershell experiment/ringserv_build.ps1)"; exit 1; }
  command -v openssl > /dev/null || { echo "no openssl"; exit 1; }

  echo "=== the root the door signs under: made by hand, here, and seeded on the box's disk ==="
  rm -rf "$CA"; mkdir -p "$CA"
  openssl ecparam -genkey -name prime256v1 -noout -out "$CA/root.key" 2> /dev/null || { echo "openssl could not make the key"; exit 1; }
  openssl req -x509 -new -key "$CA/root.key" -days 3650 -subj "/CN=Harobanda front" -out "$CA/root.crt" 2> /dev/null || { echo "openssl could not make the certificate"; exit 1; }
  FP=$(openssl x509 -in "$CA/root.crt" -outform DER | sha256sum | cut -c1-16)
  echo "root: $(openssl x509 -in "$CA/root.crt" -noout -subject | sed 's/^subject=//'), fingerprint $FP"

  # The fleet, with the fingerprint written where a design cannot know it: a COPY beside copies
  # of the three machine files, because a fleet file resolves its declarations beside itself.
  echo "=== the fleet, enrolled with the root's fingerprint, and judged ==="
  cp machines/$BOX.machine machines/$TILL.machine machines/cloud_core.machine "$D/"
  sed -e "s|ROOT \"a\{16\}\"|ROOT \"$FP\"|" "$FLEET" > "$D/cloud_links.fleet"
  grep -qF "ROOT \"$FP\"" "$D/cloud_links.fleet" || { echo "the fingerprint was not written into the copy of the fleet"; exit 1; }
  "$H" fleet "$D/cloud_links.fleet" | sed 's/^/roll: /' | tee zig-out/wsl/links.roll
  [ "${PIPESTATUS[0]}" = 0 ] || { echo "the enrolled fleet is refused"; exit 1; }
  # what the fleet says the door is, read back from the copy: member, link, name, address, root
  if ! DOOR=$("$H" fleet "$D/cloud_links.fleet" front door); then
    echo "the fleet names no front called door:"; echo "$DOOR"; exit 1
  fi
  DOOR_HOST=$(echo "$DOOR" | awk '{print $3}'); DOOR_ROOT=$(echo "$DOOR" | awk '{print $5}')
  [ "$DOOR_ROOT" = "$FP" ] || { echo "the fleet copy declares the root $DOOR_ROOT and the root made here is $FP"; exit 1; }
  echo "door: $DOOR"

  # The hardware addresses come from the DECLARATION, never from a constant here (HDW-1): the
  # fleet says which device each member is, and the box's peers promise addresses to exactly those.
  if ! TILL_MAC=$("$H" fleet "$D/cloud_links.fleet" hardware till); then
    echo "the fleet is refused, so there are no devices to be:"; echo "$TILL_MAC"; exit 1
  fi
  if ! CORE_MAC=$("$H" fleet "$D/cloud_links.fleet" hardware core); then
    echo "the fleet is refused, so there are no devices to be:"; echo "$CORE_MAC"; exit 1
  fi
  STRANGER_MAC=52:54:00:77:77:77    # nobody, and deliberately in no declaration
  if [ -z "$TILL_MAC" ] || [ -z "$CORE_MAC" ]; then
    echo "the fleet named no hardware for these members -- $H fleet $FLEET"; exit 1
  fi

  echo "=== the core: machines/cloud_core.machine with machines/ringserv.pack placed on it ==="
  rm -f zig-out/placed/$CORE.machine
  "$H" place machines/cloud_core.machine machines/ringserv.pack --out zig-out/placed/$CORE.machine || { echo "JUDGED: the placement was refused, so there is nothing to boot"; exit 1; }
  echo "=== the box: machines/$BOX.machine with machines/front.pack placed on it ==="
  rm -f zig-out/placed/$FRONT.machine
  "$H" place machines/$BOX.machine machines/front.pack --out zig-out/placed/$FRONT.machine || { echo "JUDGED: the front's placement was refused, so there is nothing to boot"; exit 1; }
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
  # the two boxes carry Caddy and its configuration, and their disks are seeded with the root;
  # the till carries the root's public half; the core, the server
  build $FRONT  HARB_MACHINE_FILE=zig-out/placed/$FRONT.machine  HARB_STAGE=machines/cloud_front.stage HARB_DISK_SEED=experiment/front_seed.sh
  build $CLOSED HARB_MACHINE_FILE=zig-out/placed/$CLOSED.machine HARB_STAGE=machines/cloud_front.stage HARB_DISK_SEED=experiment/front_seed.sh
  build $TILL   HARB_STAGE=machines/cloud_till.stage
  build $CORE   HARB_MACHINE_FILE=zig-out/placed/$CORE.machine HARB_STAGE=machines/ringserv_core.stage

  # one round: the box and the core are machines that wait, and the till is a machine that asks
  # and ends. $1 = label, $2 = the box's image dir, $3 = the till's hardware address, $4 = the
  # line that says the box is up -- its own verdict, which it gives once both its servers are
  # serving (a box that forwards starts them after the kernel has said it is the way) and the
  # door is ready, $5 = the first port (two wires: this and the next)
  round() {
    local label=$1 obox=$2 mac=$3 boxline=$4 pa=$5 pb=$(( $5 + 1 ))
    rm -f "$obox/transcript_$label.txt" "$OT/transcript_$label.txt" "$OC/transcript_$label.txt"
    # the box listens on both wires; the core and the till connect, one to each
    rewire "$obox/boot.cmd" "$obox/boot_pair.cmd" n0 listen "$pa" "" n1 listen "$pb" ""
    rewire "$OC/boot.cmd"   "$OC/boot_pair.cmd"   n0 connect "$pb" "$CORE_MAC"
    rewire "$OT/boot.cmd"   "$OT/boot_pair.cmd"   n0 connect "$pa" "$mac"
    # the core and the box must keep serving while the till asks: the emulator's
    # `--halt-on-verdict` ends a machine whose worlds are all ready, which is right for a court
    # and wrong for a server -- and the box carries one now, the door
    sed -i -e 's/ --halt-on-verdict//' "$OC/boot_pair.cmd" "$obox/boot_pair.cmd"
    ( cd "$obox" && timeout --foreground 240 bash boot_pair.cmd < /dev/null > "transcript_$label.txt" 2>&1 ) &
    local boxjob=$!
    if ! await_line "$obox/transcript_$label.txt" "$boxline" 150; then
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
  round declared "$OF" "$TILL_MAC" "boot: judge --" "$PORT"
  echo "=== round 2: a device nobody declared ==="
  round stranger "$OF" "$STRANGER_MAC" "boot: judge --" "$((PORT+2))"
  echo "=== round 3: a box that does not forward ==="
  round closed "$OX" "$TILL_MAC" "boot: judge --" "$((PORT+4))"

  # The root the till TRUSTED is the root the fleet DECLARES, or the scene fails before any pin
  # is consulted: the till's own line carries the fingerprint of the root that signed for the
  # door, and the fleet copy carries the one made here. Two readings of one fact, held together.
  if ! grep -qF "signed under the root fingerprint $FP" "$OT/transcript_declared.txt" 2>/dev/null; then
    echo "JUDGED: FAIL -- the till's door line does not carry the root the fleet declares ($FP):"
    grep -F "get https://front.cloud" "$OT/transcript_declared.txt" 2>/dev/null || echo "(no door line at all)"
    echo "exit 1"; exit 1
  fi
  echo "door: the till trusted the root $FP, which is the root the fleet declares"

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
    echo "roll: the fleet, with the root's fingerprint written in: who the door is, and under which root:"
    cat zig-out/wsl/links.roll
    echo "box: the way between the links and the door of the front one, before anyone has asked:"
    section "$OF/transcript_declared.txt" box
    echo "core: the server, behind the box:"
    section "$OC/transcript_declared.txt" core
    echo "till: the declared device, which knows nothing and asks:"
    section "$OT/transcript_declared.txt" till
    echo "stranger: the same till, with a hardware address nobody declared:"
    section "$OT/transcript_stranger.txt" stranger
    echo "closed box: the same box less its one clause, which serves both links and is the way between neither, and is still the door:"
    section "$OX/transcript_closed.txt" closedbox
    echo "closed: the same till, with that box:"
    section "$OT/transcript_closed.txt" closed
  } > zig-out/wsl/links.full
  # The root is made at every run, so its fingerprint differs in every build: each DISTINCT
  # fingerprint becomes FP1, FP2, ... in order of first appearance (IDN-1's shape, os10_time.sh's
  # instrument). What survives is the claim that matters: the fleet's ROOT and the root the till
  # was answered under read as the SAME FP1, and a door signed by another root would read as FP2
  # and convict. The value is MARKED at its exact length first, because [0-9a-f]+ also matches
  # ordinary English (FLT-1: the "af" of "after").
  sed -e 's/root fingerprint \([0-9a-f]\{16\}\)/root fingerprint @@F@\1@@F@/g' \
      -e 's/under the root \([0-9a-f]\{16\}\)/under the root @@F@\1@@F@/g' zig-out/wsl/links.full \
    | awk '
        {
          while (match($0, /@@F@[0-9a-f]+@@F@/)) {
            v = substr($0, RSTART + 4, RLENGTH - 8)
            if (!(v in F)) { nf++; F[v] = "FP" nf }
            $0 = substr($0, 1, RSTART - 1) F[v] substr($0, RSTART + RLENGTH)
          }
          print
        }' > zig-out/wsl/links.normalised
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
