#!/bin/bash
# board_pack.sh - prepara en <dir> todo lo que corre en la TE0950 con el SoC (M5, PC):
#   * modo RV128: las pruebas bare-metal de sw/tests (las de las capas 2-4b)
#   * modo RV64:  riscv-tests -p- del RV64IMAC, FreeRTOS, Zephyr (queue, common), RTEMS
# Cada programa: <name>.bin (imagen plana desde 0x8000_0000) y una linea en list.txt:
#   <name> <rv64|rv128> <divisor UART> <tohost>
# Copia tambien rv128_soc_load.c y run_all.sh. Uso: fpga/soc/board_pack.sh <dir>
set -e
H=$(cd $(dirname $0) && pwd)
ROOT=$(cd $H/../.. && pwd)
R64=$ROOT/../RV64IMAC
OUT=${1:?uso: board_pack.sh <dir>}
mkdir -p $OUT
: > $OUT/list.txt
OBJCOPY=$(command -v llvm-objcopy || command -v riscv64-unknown-elf-objcopy)
NM=$(command -v llvm-nm || command -v riscv64-unknown-elf-nm)
elf() {  # elf <name> <file.elf>: modo RV64, divisor 1
  local th
  th=$($NM $2 | awk '$3 == "tohost" {print $1}')
  [ -n "$th" ] || { echo "sin tohost: $2" >&2; return; }
  $OBJCOPY -O binary $2 $OUT/$1.bin
  echo "$1 rv64 1 0x$th" >> $OUT/list.txt
}
# --- modo RV128: sw/tests/<name>.bin + .sym (rv128asm)
for b in $ROOT/sw/tests/*.bin; do
  n=$(basename $b .bin)
  th=$(awk '$2 == "tohost" {print $1}' ${b%.bin}.sym)
  cp $b $OUT/$n.bin
  echo "$n rv128 1 0x$th" >> $OUT/list.txt
done
# --- modo RV64
for e in $R64/sw/tests/*-p-*; do                 # ELFs sin extension (no .dump/.hex)
  n=$(basename $e); case $n in *.*) continue ;; esac
  case $n in *pmpaddr*|*ma_data*) continue ;; esac   # waived as in RV64IMAC: no PMP, misaligned traps
  [ -f $e ] && elf $n $e
done
[ -f $ROOT/sw/freertos/freertos_test ] && elf freertos_test $ROOT/sw/freertos/freertos_test
for z in queue common; do [ -f $ROOT/sw/zephyr/out/$z.elf ] && elf zephyr_$z $ROOT/sw/zephyr/out/$z.elf; done
[ -f $ROOT/sw/rtems/rtems_test.exe ] && elf rtems_test $ROOT/sw/rtems/rtems_test.exe
# --- rendimiento: CoreMark (build con CLK_HZ=60000000 ITER=1200: >= 10 s a 60 MHz) y microbenchmarks
for c in $ROOT/sw/coremark/coremark_*.elf; do [ -f $c ] && elf $(basename $c .elf) $c; done
if [ -f $ROOT/sw/bench/out/bench128.bin ]; then
  cp $ROOT/sw/bench/out/bench128.bin $OUT/
  echo "bench128 rv128 1 0x$(awk '$2 == "tohost" {print $1}' $ROOT/sw/bench/out/bench128.sym)" >> $OUT/list.txt
fi
[ -f $ROOT/sw/bench/out/bench64 ] && elf bench64 $ROOT/sw/bench/out/bench64
# --- RV128 Forth: self-checking tests and demos (UART divisor 1) + interactive image
#     (UART_DIV, default 33 = 115200 baud at 60 MHz)
if python3 $ROOT/sw/forth/gen_tests.py $ROOT/sw/forth/tests > /dev/null &&
   python3 $ROOT/sw/forth/build.py --no-run --out $ROOT/sw/forth/out \
       $ROOT/sw/forth/tests/t_*.fs $ROOT/sw/forth/demos/*.fs > /dev/null; then
  for f in $ROOT/sw/forth/tests/t_*.fs $ROOT/sw/forth/demos/*.fs; do
    n=$(basename $f .fs)
    cp $ROOT/sw/forth/out/$n.bin $OUT/forth_$n.bin
    echo "forth_$n rv128 1 0x$(awk '$2 == "tohost" {print $1}' $ROOT/sw/forth/out/$n.sym)" >> $OUT/list.txt
  done
  python3 $ROOT/sw/forth/build.py --uart-div ${UART_DIV:-33} --out $ROOT/sw/forth/out_board > /dev/null &&
    cp $ROOT/sw/forth/out_board/forth.bin $OUT/forth.bin
fi
cp $H/rv128_soc_load.c $H/run_all.sh $OUT/
# el PetaLinux de la placa no trae gcc: cargador estatico para aarch64 si hay compilador cruzado
if command -v aarch64-linux-gnu-gcc > /dev/null; then
  aarch64-linux-gnu-gcc -O2 -static -o $OUT/rv128_soc_load $H/rv128_soc_load.c
else
  echo "aviso: sin aarch64-linux-gnu-gcc (sudo apt install gcc-aarch64-linux-gnu): compila rv128_soc_load aparte" >&2
fi
echo "$(wc -l < $OUT/list.txt) programas en $OUT ($(grep -c ' rv128 ' $OUT/list.txt) RV128, $(grep -c ' rv64 ' $OUT/list.txt) RV64)"
