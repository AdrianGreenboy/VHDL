# boot.S - boot ROM del SoC RV64IMAC (0x0000_1000, 4 KiB).
# El banco de registros no tiene reset (spec sec. 8): se ponen a cero x1..x31.
# Convencion de arranque RISC-V: a0 = hartid, a1 = DTB, salto a la DRAM.
  .section .text
  .globl _start
_start:
  .irp r, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
  li x\r, 0
  .endr
  csrr a0, mhartid
  la a1, dtb
  li t0, 0x80000000
  jr t0
  .align 3
dtb:
  .incbin DTB_FILE
