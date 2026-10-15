#!/bin/bash
# build_linux.sh - kernel Linux para el SoC RV64IMAC con LLVM (clang/lld).
# Uso: build_linux.sh <arbol linux> <dir salida>
set -e
LX=$(realpath $1); OUT=$(realpath -m $2); H=$(dirname $(realpath $0))
mkdir -p $OUT/rootfs
clang --target=riscv64-unknown-linux -march=rv64imac -mabi=lp64 -mno-relax -nostdlib -static -fuse-ld=lld \
  -Wl,-Ttext=0x10000 $H/init.S -o $OUT/rootfs/init
sed "s|file /init init|file /init $OUT/rootfs/init|" $H/initramfs.list > $OUT/rootfs/initramfs.list
M="make -C $LX O=$OUT ARCH=riscv LLVM=1"
$M tinyconfig > /dev/null
sed "s|CONFIG_INITRAMFS_SOURCE=\"initramfs.list\"|CONFIG_INITRAMFS_SOURCE=\"$OUT/rootfs/initramfs.list\"|" $H/rv64imac.config > $OUT/frag.config
$LX/scripts/kconfig/merge_config.sh -m -O $OUT $OUT/.config $OUT/frag.config > /dev/null
$M olddefconfig > /dev/null
$M -j${JOBS:-$(nproc)} Image
ls -la $OUT/arch/riscv/boot/Image
