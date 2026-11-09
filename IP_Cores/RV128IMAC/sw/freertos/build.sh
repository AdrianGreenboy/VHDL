#!/bin/bash
# build.sh - FreeRTOS V11.1.0 self-check for the RV128IMAC SoC in RV64 mode (M4).
#   FREERTOS_KERNEL: FreeRTOS-Kernel tree at tag V11.1.0
#     git clone --depth 1 --branch V11.1.0 https://github.com/FreeRTOS/FreeRTOS-Kernel.git
# Output: sw/freertos/freertos_test (ELF with tohost, entry 0x8000_0000)
set -e
H=$(cd $(dirname $0) && pwd)
K=${FREERTOS_KERNEL:-$HOME/FreeRTOS-Kernel}
[ -f $K/tasks.c ] || { echo "no encuentro FreeRTOS-Kernel en $K (FREERTOS_KERNEL=<ruta>)" >&2; exit 1; }
P=$K/portable/GCC/RISC-V
CF="--target=riscv64-unknown-elf -march=rv64imac_zicsr_zifencei -mabi=lp64 -mcmodel=medany -mno-relax
    -O2 -g -ffreestanding -fno-builtin -nostdlib -Wall -Wno-unused-parameter
    -I$H/libc -I$H -I$K/include -I$P"
SRC="$H/main.c $K/tasks.c $K/queue.c $K/list.c $K/timers.c $K/event_groups.c $K/portable/MemMang/heap_4.c $P/port.c"
clang $CF -c -x assembler-with-cpp $H/start.S -o $H/start.o
clang $CF -c -x assembler-with-cpp $P/portASM.S -o $H/portASM.o
OBJ="$H/start.o $H/portASM.o"
for s in $SRC; do o=$H/$(basename ${s%.c}).o; clang $CF -c $s -o $o; OBJ="$OBJ $o"; done
clang $CF -fuse-ld=lld -static -Wl,-T,$H/link.ld -Wl,--no-relax $OBJ -o $H/freertos_test
llvm-objdump -h $H/freertos_test | grep -E "text|data|bss|tohost"
echo "freertos_test: $(llvm-nm $H/freertos_test | grep -w tohost)"
