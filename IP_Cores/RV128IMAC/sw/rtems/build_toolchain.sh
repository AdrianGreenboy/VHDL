#!/bin/bash
# build_toolchain.sh - RTEMS 6.2 tools for RISC-V (gcc, binutils, newlib, gdb) with the
# RTEMS Source Builder. One time; downloads the sources (needs network), ~1-2 h.
#   RTEMS_PREFIX: install prefix (default /data/adrian/rtems/6)
#   RTEMS_WORK:   where the sources and the build go (default /data/adrian/rtems/src)
set -e
P=${RTEMS_PREFIX:-/data/adrian/rtems/6}
W=${RTEMS_WORK:-/data/adrian/rtems/src}
mkdir -p $W && cd $W
for f in rtems-source-builder-6.2 rtems-6.2; do
  [ -f $f.tar.xz ] || wget -q --show-progress https://ftp.rtems.org/pub/rtems/releases/6/6.2/sources/$f.tar.xz
  [ -d $f ] || tar xf $f.tar.xz
done
cd rtems-source-builder-6.2/rtems
../source-builder/sb-check
../source-builder/sb-set-builder --prefix=$P --log=$W/rsb-riscv.log 6/rtems-riscv
$P/bin/riscv-rtems6-gcc --version | head -1
