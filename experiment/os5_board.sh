#!/bin/bash
# os5_board.sh -- OS-5: the card meets the board, in one script.
#
# Written BEFORE the hardware arrives, and rehearsed against the
# emulator's own transcript, so that the first real boot is a command and
# not an improvisation. Four acts:
#
#   card              what to flash, its digests, and the check that the
#                     card's boot line carries NO court instrument
#   listen <dev> [s]  capture the board's console to a file
#   judge <file>      the three judges on a captured boot
#   rehearse          judge the emulator's pinned transcript instead of a
#                     board, to prove this script with no hardware at all
#
# IT NEVER WRITES TO A DEVICE. Flashing is the one act here that can
# destroy a computer if a letter is wrong, so this script prints the
# command and the author runs it, with the device they named.
#
#   bash experiment/os5_board.sh card
set -u
cd "$(dirname "$0")/.." || exit 1
NAME=makeen_box
IMG=zig-out/image/$NAME
M=machines/$NAME.machine
STZOS=${STZOS:-}
if [ -z "$STZOS" ]; then
  for c in ./zig-out/bin/stzos.exe ./zig-out/bin/stzos ./zig-out/cross/x86_64-linux-musl/stzos; do
    [ -x "$c" ] && { STZOS=$c; break; }
  done
fi
[ -n "$STZOS" ] || { echo "os5_board: no stzos binary (zig build)"; exit 1; }

act=${1:-card}

case "$act" in

card)
  echo "=== the card, and what is on it ==="
  if [ ! -f "$IMG/sd.img" ]; then
    echo "no card image at $IMG/sd.img -- build it first:"
    echo "  wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh $NAME"
    exit 1
  fi
  echo "machine:  $M"
  echo "          sha256 $(sha256sum "$M" | cut -d' ' -f1)"
  echo "card:     $IMG/sd.img"
  echo "          $(stat -c '%s bytes' "$IMG/sd.img"), sha256 $(sha256sum "$IMG/sd.img" | cut -d' ' -f1)"
  echo "kernel:   $(sha256sum "$IMG/Image" 2>/dev/null | cut -d' ' -f1)"
  echo "initramfs: $(sha256sum "$IMG/initramfs.cpio" 2>/dev/null | cut -d' ' -f1)"
  echo
  echo "--- the boot the BOARD expects of itself ($IMG/expected):"
  sed 's/^/    /' "$IMG/expected"
  echo
  echo "--- what the emulator could not keep (the two lines OS-5 turns over):"
  diff "$IMG/expected" "$IMG/expected.emulator" | grep '^[<>]' | sed 's/^</    the board: /; s/^>/    the emulator: /'
  echo
  echo "=== the card's own boot line carries no instrument of the court ==="
  # every instrument is the EMULATOR's: the watchdog turned off, the lens
  # chosen, the boot halted at the verdict. A card that carried one would
  # be a box that behaves like a court, which is the one thing a box on a
  # counter must never do.
  bad=0
  for f in "$IMG"/cmdline.*.txt; do
    [ -f "$f" ] || continue
    line=$(cat "$f")
    echo "  $(basename "$f"): $line"
    for instrument in "stzos.watchdog=off" "stzos.expect=" "--halt-on-verdict" "--hold"; do
      case "$line" in *"$instrument"*) echo "    REFUSED: it carries $instrument, which is the emulator's"; bad=1 ;; esac
    done
  done
  if [ "$bad" = 1 ]; then echo "=== do NOT flash this card ==="; exit 1; fi
  echo "  clean: the card boots the box, not the court"
  echo
  echo "=== flashing (this script will not do it) ==="
  echo "  the image is a whole card: partition table, boot partition, /data. Write it RAW."
  echo "  Windows:  Raspberry Pi Imager -> Use custom -> $(pwd)/$IMG/sd.img"
  echo "            (or balenaEtcher; both refuse a system disk, which is why they are named first)"
  echo "  Linux:    sudo dd if=$IMG/sd.img of=/dev/sdX bs=4M conv=fsync status=progress"
  echo "            READ /dev/sdX TWICE. lsblk first. A wrong letter is a wiped computer."
  echo
  echo "=== the wire ==="
  echo "  a USB-serial adapter at 3.3 V, on the Pi's header:"
  echo "    pin  6  GND  -> GND"
  echo "    pin  8  GPIO 14 (TXD) -> the adapter's RX"
  echo "    pin 10  GPIO 15 (RXD) -> the adapter's TX"
  echo "  115200 8N1. Do NOT connect the adapter's 5 V."
  echo "  the machine declares CONSOLE /dev/ttyS1 -- the mini-UART on those pins."
  echo
  echo "then:  bash experiment/os5_board.sh listen /dev/ttyUSB0 120"
  ;;

listen)
  dev=${2:-}
  secs=${3:-120}
  [ -n "$dev" ] || { echo "os5_board listen <serial-device> [seconds]"; exit 1; }
  if [ ! -e "$dev" ]; then
    echo "no such device: $dev"
    echo "  Linux: the adapter is usually /dev/ttyUSB0 (ls /dev/ttyUSB* /dev/ttyACM*)"
    echo "  WSL:   a USB device must be attached first, from an elevated PowerShell:"
    echo "           usbipd list"
    echo "           usbipd attach --wsl --busid <BUSID>"
    exit 1
  fi
  mkdir -p zig-out/board
  out=zig-out/board/$NAME-$(date +%Y%m%d-%H%M%S).txt
  echo "listening on $dev at 115200 for ${secs}s -> $out"
  echo "power the board now (or pull and replace its power)."
  stty -F "$dev" 115200 cs8 -cstopb -parenb raw -echo 2>/dev/null || echo "stty refused; the capture may still work"
  timeout "$secs" cat "$dev" | tee "$out"
  echo
  echo "captured $(grep -c '' "$out") line(s) -> $out"
  echo "then:  bash experiment/os5_board.sh judge $out"
  ;;

judge|rehearse)
  if [ "$act" = rehearse ]; then
    file=machines/$NAME.expected
    lens="--lens emulator"
    echo "=== REHEARSAL: no board. Judging the emulator's pinned transcript instead,"
    echo "    through the emulator's lens, to prove this script before the hardware."
    echo "    (that file holds THREE card boots -- the trial, the held trial and the"
    echo "     unmet one -- so 'also said' carries all three.)"
  else
    file=${2:-}
    lens=""
    [ -n "$file" ] || { echo "os5_board judge <captured-file>"; exit 1; }
    [ -f "$file" ] || { echo "no such file: $file"; exit 1; }
    echo "=== the board's first boot, judged three ways: $file"
  fi
  echo
  echo "--- 1. the BOARD's own verdict (what PID 1 said about its own boot)"
  if grep -q "boot: judge --" "$file"; then
    grep "boot: judge --" "$file" | sed 's/^.*boot: judge -- /    /'
  else
    echo "    the machine gave no verdict: it never reached readiness, or it carries no expectation"
  fi
  echo
  echo "--- 2. the COURT's verdict (the same judge, run from the host)"
  # shellcheck disable=SC2086
  "$STZOS" judge "$M" "$file" $lens | sed 's/^/    /'
  echo
  echo "--- 3. the four standing promises"
  "$STZOS" guarantees "$M" "$file" | sed 's/^/    /'
  echo
  if [ "$act" = judge ]; then
    echo "--- 4. what a board is expected to say that the emulator could not"
    diff "$IMG/expected" "$IMG/expected.emulator" 2>/dev/null | grep '^<' | sed 's/^< /    /'
    echo "    and what only a board can show: the watchdog's real countdown, and a"
    echo "    tryboot flag that needs a vendored patch to bcm2835_wdt.c (mainline"
    echo "    ignores the restart argument), until which a trial is asked for by hand."
  fi
  ;;

*)
  echo "os5_board.sh card | listen <dev> [seconds] | judge <file> | rehearse"
  exit 1
  ;;
esac
