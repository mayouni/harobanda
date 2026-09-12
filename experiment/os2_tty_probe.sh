#!/bin/bash
# os2_tty_probe.sh -- run the image pipeline under a real pseudo-terminal,
# the way a person's terminal does, so the tty behaviour of QEMU under
# `timeout` is exercised (the author's first run stopped there). Prints the
# run's last lines and how long the boot step took.
cd "$(dirname "$0")/.." || exit 1
NAME=${1:-qemu_hello}
START=$(date +%s)
script -qec "bash experiment/os2_image.sh $NAME" /dev/null > /dev/null 2>&1
END=$(date +%s)
echo "tty probe: $NAME ran under a pty in $((END-START)) s"
grep -E 'JUDGED|qemu exit' "zig-out/wsl/image_$NAME.txt"
