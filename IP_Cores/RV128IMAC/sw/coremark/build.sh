#!/bin/bash
# CoreMark bare-metal for the RV128IMAC SoC in RV64 mode (clang/lld), from the RV64IMAC port.
#   COREMARK: clone of github.com/eembc/coremark
#   ITER: iterations (10 for simulation; >= 600 on the board for the 10 s rule at 50 MHz)
#   CLK_HZ: core clock for the seconds/score (default 50 MHz, the TE0950)
set -e
cd $(dirname $0)
CM=${COREMARK:?define COREMARK=<clone of github.com/eembc/coremark>}
ITER=${ITER:-10}
CLK=${CLK_HZ:-50000000}
clang --target=riscv64-unknown-elf -march=rv64imac_zicsr -mabi=lp64 -mcmodel=medany -mno-relax \
  -O2 -ffreestanding -fno-builtin -nostdlib -static -fuse-ld=lld -Tlink.ld \
  -I. -I$CM -DITERATIONS=$ITER -DCLK_HZ=$CLK -DPERFORMANCE_RUN=1 -DFLAGS_STR='"-O2 rv64imac"' \
  crt0.S portme_rv128soc.c core_portme.c ee_printf.c \
  $CM/core_list_join.c $CM/core_main.c $CM/core_matrix.c $CM/core_state.c $CM/core_util.c \
  -o coremark_$ITER.elf
llvm-size coremark_$ITER.elf
