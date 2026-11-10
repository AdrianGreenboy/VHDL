#!/bin/bash
# build.sh - RTEMS 6.2 BSP riscv/rv64imac for the RV128IMAC SoC + the self-checking test (M4).
#   RTEMS_PREFIX: tools + BSP prefix (default /data/adrian/rtems/6, from build_toolchain.sh)
#   RTEMS_SRC:    rtems-6.2 kernel tree (default /data/adrian/rtems/src/rtems-6.2)
# Steps: patch start.S (register clearing), DTB -> header, config.ini, waf configure/build/
# install of the BSP (only when the configuration changed), then the application.
# Output: sw/rtems/rtems_test.exe (ELF with tohost; entry 0x8000_0000)
set -e
H=$(cd $(dirname $0) && pwd)
P=${RTEMS_PREFIX:-/data/adrian/rtems/6}
S=${RTEMS_SRC:-/data/adrian/rtems/src/rtems-6.2}
[ -x $P/bin/riscv-rtems6-gcc ] || { echo "no hay toolchain en $P (sw/rtems/build_toolchain.sh)" >&2; exit 1; }
[ -f $S/wscript ] || { echo "no encuentro el arbol de RTEMS en $S (RTEMS_SRC=<ruta>)" >&2; exit 1; }
export PATH=$P/bin:$PATH
mkdir -p $H/gen
python3 $H/patch_start.py $S
python3 $H/gen_dtb_header.py $H/rv128imac_soc_rtems.dts $H/gen/rv128imac-soc-dtb.h
sed "s|@DTB_HEADER@|$H/gen/rv128imac-soc-dtb.h|" $H/config.ini.in > $H/gen/config.ini
STAMP=$P/.rv128imac_bsp.sha
NEW=$(cat $H/gen/config.ini $H/gen/rv128imac-soc-dtb.h $S/bsps/riscv/shared/start/start.S | sha256sum | cut -c1-16)
if [ ! -f $STAMP ] || [ "$(cat $STAMP)" != "$NEW" ]; then
  cp $H/gen/config.ini $S/config.ini
  ( cd $S && ./waf configure --prefix=$P && ./waf && ./waf install ) > $H/gen/bsp_build.log 2>&1 \
    || { echo "BSP build FAIL (ver $H/gen/bsp_build.log)"; exit 1; }
  echo $NEW > $STAMP
  echo "BSP riscv/rv64imac instalado en $P"
fi
export PKG_CONFIG_PATH=$P/lib/pkgconfig
PC=riscv-rtems6-rv64imac
CFLAGS="$(pkg-config --cflags $PC) -O2 -g -Wall"
LDFLAGS="$(pkg-config --libs $PC)"
riscv-rtems6-gcc $CFLAGS $H/init.c $LDFLAGS -o $H/rtems_test.exe
riscv-rtems6-size $H/rtems_test.exe
echo "rtems_test.exe: $(riscv-rtems6-nm $H/rtems_test.exe | grep -w tohost) entry $(riscv-rtems6-readelf -h $H/rtems_test.exe | grep Entry | awk '{print $NF}')"
