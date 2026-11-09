/* link.ld - FreeRTOS image in DRAM at 0x8000_0000 (1 MiB). */
OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 1M }
SECTIONS
{
  .text : { *(.text.init) *(.text .text.*) } > RAM
  .rodata : ALIGN(8) { *(.rodata .rodata.* .srodata .srodata.*) } > RAM
  .data : ALIGN(8) {
    *(.data .data.*)
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*)
  } > RAM
  .tohost : ALIGN(64) { *(.tohost) } > RAM
  .bss (NOLOAD) : ALIGN(8) {
    __bss_start = .;
    *(.sbss .sbss.* .bss .bss.* COMMON)
    . = ALIGN(8);
    __bss_end = .;
  } > RAM
  __stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
