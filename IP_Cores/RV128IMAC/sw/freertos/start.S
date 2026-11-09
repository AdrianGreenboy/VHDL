# start.S - entry at 0x8000_0000 (where the boot ROM jumps; also ENTRY for tb_core/tb_cpu).
# Machine mode: stack, gp, .bss to zero, mtvec -> FreeRTOS trap handler, main().
  .section .text.init, "ax"
  .globl _start
_start:
  # The register file has no defined reset value (the RTL powers up with all ones,
  # the ISS with zeros): clear x1..x31 so no saved callee register carries garbage.
  # The boot ROM of the SoC already does this; tb_core/tb_cpu start here directly.
  li x1, 0
  li x2, 0
  li x3, 0
  li x4, 0
  li x5, 0
  li x6, 0
  li x7, 0
  li x8, 0
  li x9, 0
  li x10, 0
  li x11, 0
  li x12, 0
  li x13, 0
  li x14, 0
  li x15, 0
  li x16, 0
  li x17, 0
  li x18, 0
  li x19, 0
  li x20, 0
  li x21, 0
  li x22, 0
  li x23, 0
  li x24, 0
  li x25, 0
  li x26, 0
  li x27, 0
  li x28, 0
  li x29, 0
  li x30, 0
  li x31, 0
  .option push
  .option norelax
  la gp, __global_pointer$
  .option pop
  la sp, __stack_top
  csrw mie, zero
  la t0, freertos_risc_v_trap_handler
  csrw mtvec, t0
  la t0, __bss_start
  la t1, __bss_end
1:
  bgeu t0, t1, 2f
  sd zero, 0(t0)
  addi t0, t0, 8
  j 1b
2:
  call main
  li a0, 3                      # main returned: fail code 3
  call finish
3:
  j 3b
