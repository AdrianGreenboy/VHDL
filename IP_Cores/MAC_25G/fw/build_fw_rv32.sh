#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 20 - MAC 25G
# Compila el firmware RV32 a binario plano (para que el PS lo cargue en IMEM)
# y genera los .mem de simulacion. Calcado del build del Core 19.
#
#   bash fw/build_fw_rv32.sh
# Toolchain: riscv64-unknown-elf-gcc (o el de Vitis, se busca solo).
# Salidas en fw/: fw_rv32.bin/.mem (silicio, N=100000) y
#                 fw_rv32_sim.bin/.mem (SIM_FAST, N=64, para la capa 5 GHDL)
# =============================================================================
set -e
FW=$(cd "$(dirname "$0")" && pwd)
cd "$FW"

cat > fw_rv32.ld <<'LD'
OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
  IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 1K    /* dp_ram DEPTH=256 */
}
SECTIONS {
  .text : {
    KEEP(*(.text._start))
    *(.text*)
    *(.rodata*)
    *(.srodata*)
    . = ALIGN(4);
  } > IMEM
  /DISCARD/ : {
    *(.note*) *(.comment*) *(.riscv.attributes) *(.eh_frame*) *(.debug*)
  }
}
LD

cat > crt0.S <<'ASM'
.section .text._start
.global _start
_start:
    li   sp, 0x00000190     /* pila bajo la palabra 100; resultados 103..127 */
    call main
1:  j 1b
ASM

RVGCC=${RVGCC:-riscv64-unknown-elf-gcc}
RVOBJCOPY=${RVOBJCOPY:-riscv64-unknown-elf-objcopy}
if ! command -v "$RVGCC" >/dev/null 2>&1; then
  export PATH=$PATH:$HOME/Xilinx/2025.2.1/Vitis/gnu/riscv/lin/bin
fi

CFLAGS="-march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -Os -ffreestanding \
        -fno-asynchronous-unwind-tables -fno-unwind-tables -msmall-data-limit=0 \
        -Wl,--build-id=none -T fw_rv32.ld"

build() {   # build <salida> [defines]
  local out=$1; shift
  $RVGCC $CFLAGS "$@" crt0.S fw_rv32.c -o "$out.elf"
  $RVOBJCOPY -O binary "$out.elf" "$out.bin"
  local sz
  sz=$(stat -c%s "$out.bin")
  echo "== $out.bin: $sz bytes =="
  if [ "$sz" -gt 1024 ]; then
    echo "ERROR: el firmware excede 1 KB de IMEM (256 palabras)"; exit 1
  fi
  python3 - "$out.bin" "$out.mem" <<'PY'
import sys
data = open(sys.argv[1], 'rb').read()
data += b'\x00' * (-len(data) % 4)
words = [int.from_bytes(data[i:i+4], 'little') for i in range(0, len(data), 4)]
words += [0] * (256 - len(words))
open(sys.argv[2], 'w').write(''.join('%08X\n' % w for w in words))
PY
}

build fw_rv32
build fw_rv32_sim -DSIM_FAST
echo "== fw_rv32.mem (silicio) y fw_rv32_sim.mem (simulacion) listos =="
