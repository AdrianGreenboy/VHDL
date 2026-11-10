# crt0.S - arranque bare-metal para CoreMark: pila, .bss a cero, main, fin por HTIF.
  .section .text.init
  .globl _start
_start:
  .irp r, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
  li x\r, 0
  .endr
  la sp, _stack_top
  la t0, __bss_start
  la t1, _end
1: bgeu t0, t1, 2f
  sd zero, 0(t0)
  addi t0, t0, 8
  j 1b
2:
  call main
  slli a0, a0, 1
  ori a0, a0, 1
  la t0, tohost
  sd a0, 0(t0)
3: j 3b
  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
  .bss
  .align 4
  .space 65536
_stack_top:
