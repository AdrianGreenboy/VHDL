#!/bin/bash
# build.sh - RV128 vs RV64 microbenchmarks: out/bench128.{bin,sym} (rv128asm) and
# out/bench64 (ELF, clang). Same kernels, data and checksums (gen_bench.py).
set -e
H=$(cd $(dirname $0) && pwd)
mkdir -p $H/out
python3 $H/gen_bench.py $H/out
python3 $H/../../rv128asm.py $H/out/bench128.S -o $H/out/bench128.bin --sym $H/out/bench128.sym
clang --target=riscv64-unknown-elf -march=rv64imac_zicsr_zicntr -mabi=lp64 -mno-relax -nostdlib -static \
  -fuse-ld=lld -Wl,-T,$H/link64.ld $H/out/bench64.S -o $H/out/bench64
echo "bench128: $(stat -c %s $H/out/bench128.bin) bytes, bench64: $(llvm-size $H/out/bench64 | tail -1 | awk '{print $1}') bytes of text"
