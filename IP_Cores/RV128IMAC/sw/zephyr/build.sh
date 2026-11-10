#!/bin/bash
# build.sh - Zephyr (v4.4.0, SDK 1.0.1) kernel tests for the board rv128imac_soc (M4).
#   ZEPHYR_BASE: zephyr tree at v4.4.0 (west workspace), venv with west active
# Output: sw/zephyr/out/<test>.elf (ELF with tohost; entry 0x8000_0000)
set -e
H=$(cd $(dirname $0) && pwd)
ZB=${ZEPHYR_BASE:-/data/adrian/zephyrproject/zephyr}
[ -f $ZB/VERSION ] || { echo "no encuentro Zephyr en $ZB (ZEPHYR_BASE=<ruta>)" >&2; exit 1; }
TESTS=${*:-"tests/kernel/common tests/kernel/queue"}
mkdir -p $H/out $H/build
for t in $TESTS; do
  n=$(basename $t)
  ( cd $ZB && west build -p always -b rv128imac_soc $t -d $H/build/$n -- \
      -DZEPHYR_EXTRA_MODULES=$H -DCONFIG_ZTEST_TC_UTIL_USER_OVERRIDE=y ) > $H/build/$n.log 2>&1 \
    || { echo "build FAIL $t (ver $H/build/$n.log)"; exit 1; }
  cp $H/build/$n/zephyr/zephyr.elf $H/out/$n.elf
  echo "$n: $(grep -E 'RAM:' $H/build/$n.log | head -1 | tr -s ' ')"
done
