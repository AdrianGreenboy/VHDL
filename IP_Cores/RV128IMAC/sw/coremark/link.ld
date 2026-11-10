OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
  . = 0x80000000;
  .text.init : { *(.text.init) }
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }
  .text : { *(.text*) }
  .rodata : { *(.rodata*) *(.srodata*) }
  .data : { *(.data*) *(.sdata*) }
  . = ALIGN(8);
  __bss_start = .;
  .bss : { *(.sbss*) *(.bss*) *(COMMON) }
  . = ALIGN(8);
  _end = .;
}
