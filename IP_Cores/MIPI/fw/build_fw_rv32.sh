#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 18 - MIPI CSI-2 RX
# Build the RV32 firmware into a flat binary for IMEM loading by the PS.
#
# The PS (fw_ps / mipiverify) reads this .bin word-by-word and writes it into
# the soft core's instruction memory through the axil_soc IMEM window (0x1000),
# then releases the core.
#
# Two paths:
#   (A) GCC RV32 cross-compiler (preferred - supports full C)
#   (B) your ~/rv32i/asm.py (only if you hand-translate; note its limits:
#       lacks 'la', 'lbu', '.byte'; jalr format 'jalr rd, N(rs1)'; lui pre-shifts)
# =============================================================================
set -e

MIPI=$HOME/vhdl_repo/IP_Cores/MIPI
FW=$MIPI/fw
OUT=$FW/fw_rv32.bin

cd $FW

# ---- (A) GCC RV32IM, bare-metal, no stdlib ----------------------------------
# Harvard architecture: instruction fetch hits IMEM (dp_ram), load/store hits the
# separate local RAM (mem_subsys_dma). Both are based at 0x0 but in different
# access spaces, so code and data share the low addresses without conflict.
# Code+rodata -> IMEM (4 KB). Stack + result slots -> local RAM (256 words).
# Firmware uses NO globals/.data/.bss; it writes fixed result slots directly,
# so we only need .text/.rodata in IMEM and a stack in local RAM.
cat > fw_rv32.ld <<'LD'
OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
  IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 1K    /* u_imem dp_ram DEPTH=256 words */
}
SECTIONS {
  .text : {
    KEEP(*(.text._start))    /* _start MUST be the first instruction at 0x0 */
    *(.text*)
    *(.rodata*)
    . = ALIGN(4);
  } > IMEM
  /* discard everything that is not executable code: ELF notes, comments,
     build-id, debug, and attributes would otherwise land before/around .text
     and corrupt the flat binary. */
  /DISCARD/ : {
    *(.note*)
    *(.comment*)
    *(.riscv.attributes)
    *(.eh_frame*)
    *(.debug*)
  }
}
LD

# minimal crt0: set stack pointer, call main
cat > crt0.S <<'ASM'
.section .text._start
.global _start
_start:
    li   sp, 0x00000190     /* stack in words 100..119, results at 120..127 */
    call main
1:  j 1b
ASM

RVGCC=${RVGCC:-riscv64-unknown-elf-gcc}
RVOBJCOPY=${RVOBJCOPY:-riscv64-unknown-elf-objcopy}

# If the Xilinx/Vitis toolchain isn't on PATH, add it:
#   export PATH=$PATH:$HOME/Xilinx/2025.2.1/Vitis/gnu/riscv/lin/bin
if ! command -v $RVGCC >/dev/null 2>&1; then
  export PATH=$PATH:$HOME/Xilinx/2025.2.1/Vitis/gnu/riscv/lin/bin
fi

$RVGCC -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -O2 -ffreestanding \
   -fno-asynchronous-unwind-tables -fno-unwind-tables \
   -Wl,--build-id=none \
   -T fw_rv32.ld crt0.S fw_rv32.c -o fw_rv32.elf

$RVOBJCOPY -O binary fw_rv32.elf $OUT

echo "== fw_rv32.bin size: $(stat -c%s $OUT) bytes =="
# sanity: must fit in IMEM (1 KB = 256 words)
sz=$(stat -c%s $OUT)
if [ $sz -gt 1024 ]; then echo "ERROR: firmware exceeds 1KB IMEM (256 words)"; exit 1; fi

# also produce a .mem for GHDL simulation (dp_ram INIT_FILE), padded to 256 words
python3 bin2mem.py $OUT $FW/fw_rv32.mem 256
echo "== fw_rv32.bin (silicon) + fw_rv32.mem (simulation) ready =="
