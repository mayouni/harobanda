#!/bin/bash
# os2_image.sh -- the imperative half of the image, on a Linux host (WSL
# Ubuntu here). Stages the root, lets `harb image` DERIVE the artifacts,
# builds the vendored kernel (and the board's device tree) over tinyconfig
# + the derived fragment for the derived ARCH, packs the initramfs with the
# kernel's own gen_init_cpio, makes the declared disks or the SD card,
# boots QEMU with the serial console captured, and judges the transcript
# against machines/<name>.expected.
#
#   wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os2_image.sh [machine-name]
#
# One kernel tree per ARCH under $HOME (WSL-native: building on the Windows
# mount is an order of magnitude slower). The tarball and its pin stay in
# vendor/linux/ on the Windows side. Log: zig-out/wsl/image_<name>.txt
set -u
cd "$(dirname "$0")/.." || exit 1
NAME=${1:-qemu_hello}
M=machines/$NAME.machine
OUT=zig-out/image/$NAME
LOG=zig-out/wsl/image_$NAME.txt
K=$HOME/harb-kernel
HOST_HARB=zig-out/cross/x86_64-linux-musl/harb
mkdir -p "$OUT" zig-out/wsl
{
  echo "=== derive (target) ==="
  mkdir -p "$OUT/empty"
  "$HOST_HARB" image "$M" --root "$OUT/empty" --out "$OUT" > /dev/null 2>&1 || true
  if [ ! -f "$OUT/image.env" ]; then "$HOST_HARB" image "$M" --root "$OUT/empty" --out "$OUT"; echo "derive refused before staging"; exit 1; fi
  . "$OUT/image.env"
  DTB=${DTB:-}; SD=${SD:-no}
  echo "arch $ARCH, board $BOARD, triple $TRIPLE, cross '${CROSS_COMPILE}', kernel $KERNEL_ARTIFACT, dtb '${DTB}', sd $SD"
  echo "=== stage ==="
  ROOT=$OUT/root; rm -rf "$ROOT"; mkdir -p "$ROOT/app"
  cp "zig-out/cross/$TRIPLE/harb" "$ROOT/harb" || { echo "no harb for $TRIPLE (zig build cross)"; exit 1; }
  if [ -f "zig-out/stz-$TRIPLE/bin/stzr" ]; then cp "zig-out/stz-$TRIPLE/bin/stzr" "$ROOT/stzr"; echo "stzr staged ($TRIPLE)"; else echo "stzr NOT staged (no build of stz under zig-out/stz-$TRIPLE)"; fi
  cp app/*.luau "$ROOT/app/" 2>/dev/null && echo "app staged"
  echo "=== derive ==="
  "$HOST_HARB" image "$M" --root "$ROOT" --out "$OUT" || { echo "derive refused"; exit 1; }
  for f in image.env initramfs.list kernel.fragment disk.list sd.list config.txt cmdline.txt boot.cmd expected expected.emulator; do [ -f "$OUT/$f" ] && { echo "--- $f"; cat "$OUT/$f"; }; done
  # the boot, EXPECTED, rides in the image and is judged by PID 1 itself
  # (JDG-1). A board the court emulates carries a second text through the
  # emulator's lens; the diff of the two IS the list of the emulator's lacks,
  # said here at build time rather than inferred from a failing boot.
  if [ -f "$OUT/expected.emulator" ]; then
    echo "--- the emulator's lacks (expected vs expected.emulator):"
    diff "$OUT/expected" "$OUT/expected.emulator" | grep '^[<>]' | sed 's/^</  the board: /; s/^>/  the emulator: /'
  fi
  echo "=== kernel ==="
  # HARB_CC=zigcc builds the kernel with OUR compiler (ZIGCC-1) in its own
  # tree, so the two toolchains never share objects and either can be asked
  # for the same image; the default stays the host's gcc.
  CCARGS=""; KSUB=$ARCH
  if [ "${HARB_CC:-gcc}" = zigcc ]; then
    ZIGBIN=$HOME/harb-zig/zig-x86_64-linux-0.15.2/zig
    [ -x "$ZIGBIN" ] || { echo "HARB_CC=zigcc but no zig -- run experiment/zigcc_fetch.sh"; exit 1; }
    mkdir -p "$HOME/harb-zig/bin"; cp experiment/zigcc_wrapper.sh "$HOME/harb-zig/bin/zigcc"; chmod +x "$HOME/harb-zig/bin/zigcc"
    export ZIGCC_REAL="$ZIGBIN"
    CCARGS="CC=$HOME/harb-zig/bin/zigcc HOSTCC=gcc"; KSUB=zigcc-$ARCH
    echo "compiler: $("$HOME/harb-zig/bin/zigcc" --version | head -1) (zig $("$ZIGBIN" version))"
  else
    echo "compiler: $(${CROSS_COMPILE}gcc --version | head -1)"
  fi
  PIN=$(cat vendor/linux/PIN.txt); TARBALL=${PIN%% *}; SRC=$K/src/$KSUB/${TARBALL%.tar.xz}
  echo "pin: $PIN"
  mkdir -p "$K/src/$KSUB"
  if [ ! -d "$SRC" ]; then echo "extracting into $K/src/$KSUB"; tar -xJf "vendor/linux/$TARBALL" -C "$K/src/$KSUB" || { echo "extract failed"; exit 1; }; fi
  # ONE SOURCE TREE PER ARCH, ONE BUILD DIRECTORY PER CONFIGURATION.
  #
  # Every machine asks this tree for a different kernel -- 502 options for
  # qemu_hello, 634 for qemu_egress -- and with one build directory per
  # arch each machine reconfigured and rebuilt what the machine before it
  # had just built. Measured on the SYS-1 regression: 1m16, 1m31, 2m07,
  # then SIX SECONDS for fleet_temoin, which happened to follow the one
  # machine wanting the same 559 options, then 2m23, 3m04, 3m13. Keyed by
  # the digest of the fragment, a configuration is built once and reused,
  # and two machines that want the same kernel share it.
  #
  # The build is out-of-tree, so the source stays pristine and is
  # extracted once per arch however many configurations there are. That is
  # also why the sources moved to $K/src: `make O=` refuses a tree that
  # was ever built IN, and the old $K/<arch> trees are dirty. They are
  # superseded and can be deleted (KCACHE-1).
  # The key is what the fragment ASKS FOR, not the file. The derived
  # fragment opens with a comment naming the machine it came from, so
  # hashing the file gave qemu_identity and fleet_temoin -- whose options
  # are identical, byte for byte, below that one line -- two separate
  # builds of the same kernel. Keep the CONFIG lines, and keep
  # `# CONFIG_X is not set`, which looks like a comment and is a setting.
  FRAG=$(grep -E '^(CONFIG_[A-Z0-9_]+=|# CONFIG_[A-Z0-9_]+ is not set)' "$OUT/kernel.fragment" | sha256sum | cut -c1-12)
  B=$K/build/$KSUB-$FRAG
  if [ -f "$B/$KERNEL_ARTIFACT" ]; then
    echo "kernel cache: HIT $KSUB-$FRAG -- this configuration is already built"
  else
    echo "kernel cache: MISS $KSUB-$FRAG -- first build of this configuration"
  fi
  mkdir -p "$B"
  cp "$OUT/kernel.fragment" "$B/harb.fragment"
  (
    cd "$SRC" || exit 1
    export ARCH CROSS_COMPILE
    # shellcheck disable=SC2086 -- CCARGS is empty or two plain assignments
    make -s $CCARGS O="$B" tinyconfig || exit 1
    scripts/kconfig/merge_config.sh -O "$B" -m "$B/.config" "$B/harb.fragment" > /dev/null || exit 1
    make -s $CCARGS O="$B" olddefconfig || exit 1
    echo "config: $(grep -c '=y' "$B/.config") options on"
    # every option the fragment asked for must survive olddefconfig; one that
    # did not is a dependency the fragment forgot, and it is named here
    grep -E '^CONFIG_[A-Z0-9_]+=y' "$B/harb.fragment" | while read -r want; do
      grep -q "^$want\$" "$B/.config" && echo "  $want" || echo "  $want DROPPED by olddefconfig -- a dependency is missing from the fragment"
    done
    time make -j2 $CCARGS O="$B" "$(basename "$KERNEL_ARTIFACT")" 2>&1 | tail -3
    if [ -n "$DTB" ]; then make -j2 $CCARGS O="$B" dtbs 2>&1 | tail -1; fi
    make -s $CCARGS O="$B" usr/gen_init_cpio || exit 1
  ) || { echo "kernel build failed"; exit 1; }
  cp "$B/$KERNEL_ARTIFACT" "$OUT/$KERNEL_IMAGE" || exit 1
  # the config this image's kernel was built with, kept beside it: the tree's
  # .config belongs to whichever machine of this ARCH was built last, and a
  # diagnostic that read the tree answered for the wrong machine (OS-4)
  cp "$B/.config" "$OUT/kernel.config"
  cp "$B/System.map" "$OUT/System.map"   # the symbol map of THIS kernel, for os4_syms.sh
  if [ -n "$DTB" ]; then
    cp "$B/$DTB" "$OUT/$(basename "$DTB")" || { echo "no dtb built: $DTB"; exit 1; }
    # two trees from mainline's: the CARD's (mainline + DTB_OPS: what the
    # board needs mainline does not say, e.g. the mmc aliases that make the
    # declared /dev/mmcblk0p2 hold) and the EMULATOR's (the card's +
    # QEMU_DTB_OPS: the blocks QEMU does not model, the host it plugs the
    # card into). Both derived into image.env; experiment/dtb_ops.py applies.
    DTC="$B/scripts/dtc/dtc"; BDTB="$OUT/$(basename "$DTB")"; QDTB="$OUT/$(basename "${DTB%.dtb}").qemu.dtb"
    "$DTC" -q -I dtb -O dts -o "$OUT/mainline.dts" "$BDTB" || { echo "dtc failed"; exit 1; }
    echo "-- the card's tree:"; python3 experiment/dtb_ops.py "$OUT/mainline.dts" "$OUT/board.dts" ${DTB_OPS:-}
    "$DTC" -q -I dts -O dtb -o "$BDTB" "$OUT/board.dts" || { echo "dtc (board) failed"; exit 1; }
    echo "-- the emulator's tree:"; python3 experiment/dtb_ops.py "$OUT/board.dts" "$OUT/qemu.dts" ${QEMU_DTB_OPS:-}
    "$DTC" -q -I dts -O dtb -o "$QDTB" "$OUT/qemu.dts" || { echo "dtc (qemu) failed"; exit 1; }
  fi
  echo "=== initramfs ==="
  "$B/usr/gen_init_cpio" "$OUT/initramfs.list" > "$OUT/initramfs.cpio" || { echo "cpio failed"; exit 1; }
  echo "=== disks ==="
  grep -v '^#' "$OUT/disk.list" | while read -r id dev fs size img; do
    [ -z "$id" ] && continue
    rm -f "$OUT/$img"; truncate -s "${size}M" "$OUT/$img"
    case "$fs" in
      ext4) mkfs.ext4 -F -q -L "$id" "$OUT/$img" ;;
      vfat) mkfs.vfat -n "$id" "$OUT/$img" > /dev/null ;;
    esac
    echo "$id: $img $fs ${size}M -> $dev"
  done
  if [ "$SD" = yes ]; then
    echo "=== sd card ==="
    # the board's firmware, pinned by digest after the first fetch (vendor/rpi-firmware/, gitignored)
    FW=vendor/rpi-firmware; mkdir -p "$FW"; mkdir -p "$OUT/firmware"
    if [ ! -f "$FW/start4.elf" ] || [ ! -f "$FW/fixup4.dat" ]; then
      TAG=$(curl -4 -sSf https://api.github.com/repos/raspberrypi/firmware/releases/latest | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
      echo "firmware: raspberrypi/firmware tag ${TAG:-?}"
      for f in start4.elf fixup4.dat; do
        curl -4 -sSf -o "$FW/$f" "https://raw.githubusercontent.com/raspberrypi/firmware/$TAG/boot/$f" || echo "firmware: $f NOT fetched"
      done
      [ -f "$FW/start4.elf" ] && { echo "$TAG" > "$FW/TAG.txt"; (cd "$FW" && sha256sum start4.elf fixup4.dat > PIN.txt); }
    fi
    [ -f "$FW/PIN.txt" ] && { echo "firmware pin ($(cat "$FW/TAG.txt")):"; cat "$FW/PIN.txt"; }
    cp "$FW"/start4.elf "$FW"/fixup4.dat "$OUT/firmware/" 2>/dev/null || echo "firmware: blobs missing -- the card boots in QEMU (which loads the kernel itself) but not on the board"
    # partitions: p1 at sector 2048, then p2 right after; sizes from sd.list
    P1MB=$(awk '$1=="part" && $2=="p1"{print $4}' "$OUT/sd.list"); P2FS=$(awk '$1=="part" && $2=="p2"{print $3}' "$OUT/sd.list"); P2MB=$(awk '$1=="part" && $2=="p2"{print $4}' "$OUT/sd.list")
    P1S=$((P1MB*2048)); P2S=$(( ${P2MB:-0} * 2048 ))
    # QEMU's SD model wants a power-of-two card; the partitions sit at the
    # front and the rest is unallocated, as on any real card larger than its
    # image (the first raspi4b run refused a 130 MiB card)
    NEED=$((2048 + P1S + P2S + 2048)); TOTAL=$((256*2048)); while [ "$TOTAL" -lt "$NEED" ]; do TOTAL=$((TOTAL*2)); done
    rm -f "$OUT/sd.img"; truncate -s $((TOTAL*512)) "$OUT/sd.img"
    {
      echo "label: dos"; echo "unit: sectors"
      echo "p1 : start=2048, size=$P1S, type=c, bootable"
      [ "$P2S" -gt 0 ] && echo "p2 : start=$((2048+P1S)), size=$P2S, type=83"
    } | sfdisk -q "$OUT/sd.img" || { echo "sfdisk failed"; exit 1; }
    rm -f "$OUT/boot.img"; truncate -s "${P1MB}M" "$OUT/boot.img"; mkfs.vfat -F 32 -n BOOT "$OUT/boot.img" > /dev/null
    grep '^boot ' "$OUT/sd.list" | while read -r _ name src; do
      # mtools asks on stdin when a name clashes (mmd on an existing directory
      # did, and the run hung 33 minutes on a pipe that never closes): -D s
      # skips a clash, -D o overwrites one, and stdin is /dev/null regardless
      case "$name" in */*) d=$(dirname "$name"); p=""; for seg in ${d//\// }; do p="$p/$seg"; mmd -D s -i "$OUT/boot.img" "::${p#/}" < /dev/null > /dev/null 2>&1; done ;; esac
      if [ -f "$OUT/$src" ]; then mcopy -D o -i "$OUT/boot.img" "$OUT/$src" "::$name" < /dev/null && echo "boot: $name <- $src"; else echo "boot: $name -- $src missing, skipped"; fi
    done
    dd if="$OUT/boot.img" of="$OUT/sd.img" bs=512 seek=2048 conv=notrunc status=none
    if [ "$P2S" -gt 0 ]; then
      rm -f "$OUT/data.img"; truncate -s "${P2MB}M" "$OUT/data.img"
      case "$P2FS" in ext4) mkfs.ext4 -F -q -L data "$OUT/data.img" ;; vfat) mkfs.vfat -n DATA "$OUT/data.img" > /dev/null ;; esac
      dd if="$OUT/data.img" of="$OUT/sd.img" bs=512 seek=$((2048+P1S)) conv=notrunc status=none
      echo "card: p2 $P2FS ${P2MB}M"
    fi
    sfdisk -l "$OUT/sd.img" | tail -3
    cp "$OUT/sd.img" "$OUT/sd.pristine.img"   # the card as flashed, before any boot wrote to it
  fi
  ls -la "$OUT" | grep -v '^total' | grep -v ' root$\| empty$\| firmware$'
  # HARB_NO_BOOT: derive and build the image and stop there. The
  # PAIR of machines that meet on a wire (NAM-1) is booted by
  # experiment/os6_names.sh, which needs both images built and
  # neither booted on its own -- a box with nobody to serve would
  # sit at its timeout, and a device with no server would be right
  # to say nobody answered.
  if [ -n "${HARB_NO_BOOT:-}" ]; then echo "=== boot skipped (HARB_NO_BOOT): the image is built and judged elsewhere ==="; echo "exit 0"; exit 0; fi
  echo "=== boot ==="
  # stdin from /dev/null and --foreground: run from a real terminal, QEMU
  # -nographic tries to put the tty into raw mode; under `timeout` it sits
  # in a background process group, gets SIGTTOU, and STOPS silently until
  # the timeout kills it (the author's first run, 2026-09-12). With no tty
  # on stdin it never touches the terminal.
  ( cd "$OUT" && timeout --foreground 180 bash boot.cmd < /dev/null > transcript.txt 2>&1; echo "qemu exit $?" >> transcript.txt )
  if grep -q '^  JOURNAL ' "$M" && [ "$SD" != yes ]; then
    # the same machine, booted again on the same disk (JRN-1). A record of
    # one boot proves nothing about a chain: the second boot is where the
    # first boot's entry is read back, verified and extended. A slotted
    # machine needs no extra boot here -- its steady boot is already this.
    ( cd "$OUT" && timeout --foreground 120 bash boot.cmd < /dev/null > transcript_again.txt 2>&1; echo "qemu exit $?" >> transcript_again.txt )
    echo "again: the same machine, booted again on the same disk:" >> "$OUT/transcript.txt"
    sed -e 's/
$//' "$OUT/transcript_again.txt" | sed -n '/^.*boot: harb init/,$p' | sed -e 's/^.*boot: harb init/boot: harb init/' | grep -v '^qemu exit' | sed 's/^/again: /' >> "$OUT/transcript.txt"
  fi
  if [ "$SD" = yes ] && [ -f "$OUT/boot_hold.cmd" ]; then
    # the second witness of an A/B machine: the card's config.txt after the
    # trial boot (the commit rewrote it, or did not), read from the image
    echo "card: config.txt after the trial:" >> "$OUT/transcript.txt"
    mcopy -i "$OUT/sd.img@@$((2048*512))" ::config.txt - 2>/dev/null | grep -E 'os_prefix|tryboot' | sed 's/^/card: /' >> "$OUT/transcript.txt"
    # the SAME card, booted again (IDN-1). Everything the first boot
    # decided is now this boot's starting point: the committed slot is B
    # and says so as STEADY rather than a trial, and this device's key is
    # the one the first boot made -- loaded, not created. A court that
    # never boots the same card twice can say nothing about what persists.
    ( cd "$OUT" && timeout --foreground 120 bash boot.cmd < /dev/null > transcript_steady.txt 2>&1; echo "qemu exit $?" >> transcript_steady.txt )
    echo "steady: the same card, booted again:" >> "$OUT/transcript.txt"
    sed -e 's/\r$//' "$OUT/transcript_steady.txt" | sed -n '/^.*boot: harb init/,$p' | sed -e 's/^.*boot: harb init/boot: harb init/' | grep -v '^qemu exit' | sed 's/^/steady: /' >> "$OUT/transcript.txt"

    # the rollback instrument, on a PRISTINE copy of the card (the first boot
    # committed B on sd.img; a hold on that card would be steady, not a
    # trial -- the first run of this instrument showed exactly that): the same
    # trial held -- never committed, the watchdog unfed; then whatever the
    # hardware (here: the emulator, which cannot arm it) answered
    cp "$OUT/sd.pristine.img" "$OUT/sd.hold.img"
    ( cd "$OUT" && timeout --foreground 60 bash <(sed 's/sd\.img/sd.hold.img/' boot_hold.cmd) < /dev/null > transcript_hold.txt 2>&1; echo "qemu exit $?" >> transcript_hold.txt )
    echo "hold: the same trial on a pristine card, held:" >> "$OUT/transcript.txt"
    sed -e 's/\r$//' "$OUT/transcript_hold.txt" | sed -n '/^.*boot: slot [AB] -- /,$p' | sed -e 's/^.*boot: slot \([AB]\) -- /boot: slot \1 -- /' | grep -v '^qemu exit' | sed 's/^/hold: /' >> "$OUT/transcript.txt"
    echo "card: config.txt after the held trial:" >> "$OUT/transcript.txt"
    mcopy -i "$OUT/sd.hold.img@@$((2048*512))" ::config.txt - 2>/dev/null | grep -E 'os_prefix|tryboot' | sed 's/^/card: /' >> "$OUT/transcript.txt"
  fi
  if [ "$SD" = yes ] && [ -f "$OUT/boot_unmet.cmd" ]; then
    # the judge's negative (JDG-1), on a pristine card again: the same trial
    # judged by the BOARD's expectation, which the emulator cannot meet (no
    # NIC it models, no watchdog it can arm). PID 1 must name the lines it
    # expected and did not say, hold the trial, and the card must still
    # boot A. A machine that committed here would be a machine that cannot
    # tell its own boot from another.
    cp "$OUT/sd.pristine.img" "$OUT/sd.unmet.img"
    ( cd "$OUT" && timeout --foreground 60 bash <(sed 's/sd\.img/sd.unmet.img/' boot_unmet.cmd) < /dev/null > transcript_unmet.txt 2>&1; echo "qemu exit $?" >> transcript_unmet.txt )
    echo "unmet: the same trial on a pristine card, judged by the board's expectation:" >> "$OUT/transcript.txt"
    sed -e 's/\r$//' "$OUT/transcript_unmet.txt" | sed -n '/^.*boot: slot [AB] -- /,$p' | sed -e 's/^.*boot: slot \([AB]\) -- /boot: slot \1 -- /' | grep -v '^qemu exit' | sed 's/^/unmet: /' >> "$OUT/transcript.txt"
    echo "card: config.txt after the unmet trial:" >> "$OUT/transcript.txt"
    mcopy -i "$OUT/sd.unmet.img@@$((2048*512))" ::config.txt - 2>/dev/null | grep -E 'os_prefix|tryboot' | sed 's/^/card: /' >> "$OUT/transcript.txt"
  fi
  echo "--- transcript"; cat "$OUT/transcript.txt"
  echo "=== judge ==="
  # ... and ONLY on the first line: a later section's banner (steady:,
  # again:, hold:, unmet:) kept its prefix when that section was
  # extracted, and stripping it again here erased which boot a line
  # belonged to -- several banners reading identically in one file (JRN-1).
  # The transcript is the fixture. Normalise what no two boots share -- the
  # firmware banner and terminal control bytes before PID 1's first line,
  # CRs, and the pids the kernel hands out to the SERVICES -- and diff the
  # rest against the pinned expectation. "pid 1" is kept literal: that init
  # IS PID 1 is the claim the judge must be able to convict (the first
  # judge run normalised it away and was corrected, PROTOCOL.md OS-2).
  # Anything else that differs is a finding.
  # ... and the FINGERPRINT of this device's key, which is made on the
  # device from its own randomness and is therefore different in every
  # build. It is not normalised to a constant: each DISTINCT fingerprint
  # becomes KEY1, KEY2, ... in order of first appearance, so the claim
  # that matters survives the normalisation -- the same key in three
  # boots reads as KEY1 three times, and a key that changed would read as
  # KEY2 and convict (IDN-1).
  # ... and the PUBLIC KEY a device publishes with `attest --export`,
  # the same way. The values are MARKED by sed at their exact lengths
  # first, because /[0-9a-f]+/ matches ordinary English too: the fleet
  # witness's first run read the "af" of "after" as a fingerprint and
  # wrote a normalised token into the middle of a word (FLT-1).
  sed -e 's/\r$//' "$OUT/transcript.txt" \
    | sed -n '/^.*boot: harb init/,$p' | sed -e '1s/^.*boot: harb init/boot: harb init/' \
    | sed -E 's/pid ([2-9]|[1-9][0-9]+)\b/pid N/g' \
    | sed -e 's/hash=[0-9a-f]\{64\}/hash=H/g' -e 's/sig=[0-9a-f]\{128\}/sig=S/g' \
    | sed -e 's/ed25519 \([0-9a-f]\{64\}\)/ed25519 @@K@\1@@K@/g' -e 's/fingerprint \([0-9a-f]\{16\}\)/fingerprint @@K@\1@@K@/g' \
    | awk '{ while (match($0, /@@K@[0-9a-f]+@@K@/)) { fp = substr($0, RSTART + 4, RLENGTH - 8); if (!(fp in seen)) { n++; seen[fp] = "KEY" n } $0 = substr($0, 1, RSTART - 1) seen[fp] substr($0, RSTART + RLENGTH) } print }' \
    | sed -e '/^qemu exit$/d; /^qemu exit [0-9]*$/d' > "$OUT/transcript.normalised"
  # A machine with no pin yet is not a failure: this run is how its
  # first transcript gets made. A pin that REFUSES the transcript is.
  VERDICT=0
  if [ ! -f "machines/$NAME.expected" ]; then
    echo "JUDGED: no expectation pinned for $NAME yet -- machines/$NAME.expected is missing; this boot's normalised transcript is at $OUT/transcript.normalised"
  elif diff -u "machines/$NAME.expected" "$OUT/transcript.normalised" > "$OUT/transcript.diff"; then
    echo "JUDGED: the boot transcript matches machines/$NAME.expected line for line ($(wc -l < "$OUT/transcript.normalised") lines)"
  else
    echo "JUDGED: FAIL -- the transcript differs from machines/$NAME.expected:"; cat "$OUT/transcript.diff"
    VERDICT=1
  fi
  echo "exit $VERDICT"
  exit "$VERDICT"
} 2>&1 | tee "$LOG"
# everything above streams to the terminal AND to the log, so a run from
# a real terminal shows its progress (the first run looked hung: it wrote
# only the log, and its QEMU was stopped on the tty -- see the boot step)
#
# THE VERDICT IS THE BLOCK'S, NOT tee's. A pipeline exits with its LAST
# command's status, so for as long as this script ended at the `tee`
# above it exited 0 whatever happened inside -- a refused pin, a kernel
# build that failed, a missing cross binary, a cpio that never ran. The
# judge convicted on screen and nothing automated could hear it, which
# is the one thing a judge may not do. Every `exit 1` in the block above
# was swallowed the same way. Found by the guided tour's own lesson 6
# (LRN-1): the reader breaks a pin, watches JUDGED: FAIL, and the script
# reports success.
exit "${PIPESTATUS[0]}"
