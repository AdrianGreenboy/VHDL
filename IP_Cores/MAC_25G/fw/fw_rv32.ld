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
