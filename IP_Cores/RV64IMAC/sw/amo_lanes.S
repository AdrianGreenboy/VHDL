# amo_lanes.S - AMO.W y LR/SC.W en ambos carriles de 32 bit de una palabra de 64.
#   Las riscv-tests solo usan el operando en offset 0 (carril bajo). Aqui cada AMO
#   se hace en +0 y en +4 y despues se lee la palabra de 64 bit completa: el valor
#   viejo (rd) y la memoria se comparan en lockstep contra el ISS (y el ISS contra
#   Spike). Mata "AMO en el carril 0" en la D$.
#define AMOW(op)              \
  li t0, 0x8000000180000001;  \
  sd t0, 0(s0);               \
  sd s2, 8(s0);               \
  op a0, s1, (s0);            \
  op a1, s1, (s5);            \
  op a2, s3, (s6);            \
  ld a3, 0(s0);               \
  ld a4, 8(s0);               \
  add s4, s4, a0;  xor s4, s4, a1;  add s4, s4, a2; \
  xor s4, s4, a3;  add s4, s4, a4;

  .section .text.init
  .globl _start
_start:
  la s0, buf
  addi s5, s0, 4
  addi s6, s0, 12
  li s1, 0x7FFFFFF3
  li s2, 0x00000005FFFFFFFE
  li s3, -9
  li s4, 0
  AMOW(amoswap.w)
  AMOW(amoadd.w)
  AMOW(amoxor.w)
  AMOW(amoand.w)
  AMOW(amoor.w)
  AMOW(amomin.w)
  AMOW(amomax.w)
  AMOW(amominu.w)
  AMOW(amomaxu.w)
  # LR/SC en el carril alto y bajo
  li t0, 0x1234567889ABCDEF
  sd t0, 0(s0)
  lr.w a0, (s5)
  addi a0, a0, 1
  sc.w a1, a0, (s5)
  lr.w a2, (s0)
  addi a2, a2, -1
  sc.w a3, a2, (s0)
  ld a4, 0(s0)
  # comprobacion propia ademas del lockstep: 0x12345679_89ABCDEE
  li t1, 0x1234567989ABCDEE
  bne a4, t1, fail
  bnez a1, fail
  bnez a3, fail
  # amoadd.w en +4 con resultado conocido
  li t0, 0x0000000100000002
  sd t0, 0(s0)
  li t1, 0x10
  amoadd.w a0, t1, (s5)
  ld a1, 0(s0)
  li t2, 0x0000001100000002
  bne a1, t2, fail
  li t2, 1
  bne a0, t2, fail
  li a0, 0
  j finish
fail:
  li a0, 1
finish:
  slli a0, a0, 1
  ori a0, a0, 1
  la t0, tohost
  sd a0, 0(t0)
1: j 1b

  .data
  .align 4
buf: .dword 0, 0

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
