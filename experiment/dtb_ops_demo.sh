#!/bin/bash
# dtb_ops_demo.sh -- run experiment/dtb_ops.py by hand on the Pi image's
# trees and show exactly what each derived op changed: mainline's tree ->
# the card's tree (DTB_OPS) -> the emulator's tree (QEMU_DTB_OPS), the ops
# read from the image's own image.env, the results diffed line by line.
cd "$(dirname "$0")/.." || exit 1
OUT=zig-out/image/makeen_box
[ -f "$OUT/mainline.dts" ] || { echo "no $OUT/mainline.dts -- run os2_image.sh makeen_box first"; exit 1; }
. "$OUT/image.env"
T=$(mktemp -d)
echo "== 1. mainline -> the card's tree (DTB_OPS) =="
python3 experiment/dtb_ops.py "$OUT/mainline.dts" "$T/board.dts" ${DTB_OPS:-}
echo "-- diff (mainline vs card):"; diff "$OUT/mainline.dts" "$T/board.dts" | grep '^[<>]'
echo
echo "== 2. the card's tree -> the emulator's tree (QEMU_DTB_OPS) =="
python3 experiment/dtb_ops.py "$T/board.dts" "$T/qemu.dts" ${QEMU_DTB_OPS:-}
echo "-- diff (card vs emulator):"; diff "$T/board.dts" "$T/qemu.dts" | grep '^[<>]'
echo
echo "== 3. the same as what the pipeline produced? =="
cmp -s "$T/board.dts" "$OUT/board.dts" && echo "card's tree: identical to the pipeline's" || echo "card's tree: DIFFERS from the pipeline's"
cmp -s "$T/qemu.dts" "$OUT/qemu.dts" && echo "emulator's tree: identical to the pipeline's" || echo "emulator's tree: DIFFERS from the pipeline's"
echo
echo "== 4. an op that names nothing =="
python3 experiment/dtb_ops.py "$T/board.dts" "$T/x.dts" disable:no-such-node@1234 alias:mmc9:/nowhere drop:mmc@7e300000:no-such-property
rm -rf "$T"
