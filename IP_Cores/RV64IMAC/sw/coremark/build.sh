#!/bin/bash
# CoreMark bare-metal para el RV64IMAC (clang/lld). ITER = iteraciones.
set -e
cd $(dirname $0)
CM=${COREMARK:?define COREMARK=<clon de github.com/eembc/coremark>}
ITER=${ITER:-10}
RT=${RISCV_TESTS:-}
clang --target=riscv64-unknown-elf -march=rv64imac_zicsr -mabi=lp64 -mcmodel=medany -mno-relax \
  -O2 -ffreestanding -fno-builtin -nostdlib -static -fuse-ld=lld -Tlink.ld \
  -I. -I$CM -DITERATIONS=$ITER -DPERFORMANCE_RUN=1 -DFLAGS_STR='"-O2 rv64imac"' \
  crt0.S portme_rv64.c core_portme.c ee_printf.c \
  $CM/core_list_join.c $CM/core_main.c $CM/core_matrix.c $CM/core_state.c $CM/core_util.c \
  -o coremark_$ITER.elf
llvm-size coremark_$ITER.elf
