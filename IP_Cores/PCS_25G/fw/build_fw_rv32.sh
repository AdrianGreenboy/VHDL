#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 19 - PCS 64B/66B @ 25G
# Compila el firmware RV32 a binario plano para que el PS lo cargue en IMEM.
#
# El PS (fw_ps / pcsverify) lee este .bin palabra a palabra y lo escribe en la
# memoria de instrucciones del soft core por la ventana IMEM del axil_soc
# (0x1000), y despues libera el core.
#
# Calcado del build del Core 18 (MIPI), que dio silicon pass.
# =============================================================================
set -e

PCS=$HOME/vhdl_repo/IP_Cores/PCS_25G
FW=$PCS/fw
OUT=$FW/fw_rv32.bin

cd $FW

# ---- linker script: arquitectura Harvard ------------------------------------
# El fetch de instrucciones va a IMEM (dp_ram); load/store va a la RAM local
# separada (mem_subsys_dma). Ambas basadas en 0x0 pero en espacios distintos.
# El firmware no usa globales/.data/.bss: escribe ranuras fijas de resultado,
# asi que solo necesitamos .text/.rodata en IMEM y pila en la RAM local.
cat > fw_rv32.ld <<'LD'
OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
  IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 1K    /* u_imem dp_ram DEPTH=256 */
}
SECTIONS {
  .text : {
    KEEP(*(.text._start))    /* _start DEBE ser la primera instruccion en 0x0 */
    *(.text*)
    *(.rodata*)
    . = ALIGN(4);
  } > IMEM
  /* descartar todo lo que no sea codigo ejecutable: notas ELF, comentarios,
     build-id, debug y atributos corromperian el binario plano. */
  /DISCARD/ : {
    *(.note*)
    *(.comment*)
    *(.riscv.attributes)
    *(.eh_frame*)
    *(.debug*)
  }
}
LD

# ---- crt0 minimo: pila y salto a main ---------------------------------------
cat > crt0.S <<'ASM'
.section .text._start
.global _start
_start:
    li   sp, 0x00000190     /* pila en palabras 100..119, resultados 118..127 */
    call main
1:  j 1b
ASM

RVGCC=${RVGCC:-riscv64-unknown-elf-gcc}
RVOBJCOPY=${RVOBJCOPY:-riscv64-unknown-elf-objcopy}

if ! command -v $RVGCC >/dev/null 2>&1; then
  export PATH=$PATH:$HOME/Xilinx/2025.2.1/Vitis/gnu/riscv/lin/bin
fi

$RVGCC -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -O2 -ffreestanding \
   -fno-asynchronous-unwind-tables -fno-unwind-tables \
   -Wl,--build-id=none \
   -T fw_rv32.ld crt0.S fw_rv32.c -o fw_rv32.elf

$RVOBJCOPY -O binary fw_rv32.elf $OUT

sz=$(stat -c%s $OUT)
echo "== fw_rv32.bin: $sz bytes =="
if [ $sz -gt 1024 ]; then
  echo "ERROR: el firmware excede 1KB de IMEM (256 palabras)"
  exit 1
fi

# ---- variante SIM_FAST: misma logica, ventanas de medida cortas -------------
# Solo para los testbenches de GHDL (tb_soc_pcs*): permite iterar en ~0.2 ms
# simulados en vez de 2.75 ms. El binario de silicio es el de arriba.
$RVGCC -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -O2 -ffreestanding \
   -DSIM_FAST \
   -fno-asynchronous-unwind-tables -fno-unwind-tables \
   -Wl,--build-id=none \
   -T fw_rv32.ld crt0.S fw_rv32.c -o fw_rv32_sim.elf
$RVOBJCOPY -O binary fw_rv32_sim.elf $FW/fw_rv32_sim.bin
echo "== fw_rv32_sim.bin: $(stat -c%s $FW/fw_rv32_sim.bin) bytes =="

# .mem para simulacion GHDL (INIT_FILE del dp_ram), rellenado a 256 palabras
B2M=$HOME/vhdl_repo/IP_Cores/MIPI/fw/bin2mem.py
if [ -f $B2M ]; then
  python3 $B2M $OUT $FW/fw_rv32.mem 256
  python3 $B2M $FW/fw_rv32_sim.bin $FW/fw_rv32_sim.mem 256
  echo "== fw_rv32.mem (silicio) + fw_rv32_sim.mem (simulacion rapida) listos =="
else
  echo "== .bin listos (bin2mem.py no encontrado, sin .mem) =="
fi
