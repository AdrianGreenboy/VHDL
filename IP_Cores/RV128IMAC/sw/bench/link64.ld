/* link64.ld - bench64 (RV64 mode) at 0x8000_0000 */
OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS
{
  . = 0x80000000;
  .text : { *(.text.init) *(.text*) }
  . = ALIGN(64);
  .tohost : { *(.tohost) }
  .bss (NOLOAD) : ALIGN(64) { *(.bss*) }
}
