#!/bin/bash
# RMX2020 bring-up helper: merge the oppo6769 overlay into the mt6768 platform dtb and
# create an Image.gz-dtb that contains the merged dtb (independent of the dtbo partition).
# usage: scripts/rmx2020_merge_dtb.sh <out-dir> [oppo6769_19741|oppo6769_19747|oppo6769_206AC]
# needs: fdtoverlay (apt install device-tree-compiler)
set -e
OUT=${1:?out dir}
P=${2:-oppo6769_19741}
D=$OUT/arch/arm64/boot/dts/mediatek
B=$OUT/arch/arm64/boot
fdtoverlay -i $D/mt6768.dtb -o $D/mt6768-$P.dtb $D/$P.dtbo
cat $B/Image.gz $D/mt6768-$P.dtb > $B/Image.gz-dtb-$P
ls -l $B/Image.gz-dtb-$P
