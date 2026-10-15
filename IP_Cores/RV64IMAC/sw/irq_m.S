# irq_m.S - interrupciones en modo M, autoverificado (ademas del lockstep).
#  1. WFI con MIE=0 y MTIE=1: debe despertar con MTIP y seguir sin trap.
#  2. Activar MIE: la MTI pendiente se toma de inmediato.
#  3. El handler comprueba MPIE=1 y re-arma el timer; tras MRET, MIE debe
#     volver a 1 y llegar una segunda y tercera MTI (mtvec vectorizado).
#  4. MSI por el CLINT con MIE=1.
#define CLINT_MSIP      0x02000000
#define CLINT_MTIMECMP  0x02004000
#define CLINT_MTIME     0x0200BFF8

  .section .text.init
  .globl _start
_start:
  .irp r, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
  li x\r, 0
  .endr
  la    t0, vtable
  ori   t0, t0, 1                        # mtvec vectorizado
  csrw  mtvec, t0
  li    t0, 1 << 7
  csrw  mie, t0                          # MTIE
  call  arm_soon
  # 1. WFI sin MIE: despierta por MTIP, sin trap
  wfi                                    # puede volver antes (WFI-nop es legal)
  li    t1, 100000
0:
  csrr  t0, mip
  andi  t0, t0, 1 << 7
  bnez  t0, 6f
  addi  t1, t1, -1
  bnez  t1, 0b
  j     fail
6:
  bnez  s1, fail                         # con MIE=0 no debe haber trap
  # 2. MIE=1: trap inmediato
  csrsi mstatus, 8
  nop
  nop
  li    t0, 1
  bne   s1, t0, fail
  # 3. esperar segunda y tercera MTI (MIE restaurado por MRET)
  li    t1, 200000
1:
  li    t0, 3
  bge   s1, t0, 2f
  addi  t1, t1, -1
  bnez  t1, 1b
  j     fail
2:
  # 4. MSI
  li    t0, 1 << 3
  csrs  mie, t0
  li    t0, CLINT_MSIP
  li    t1, 1
  sw    t1, 0(t0)
  li    t1, 1000
3:
  bnez  s2, 4f
  addi  t1, t1, -1
  bnez  t1, 3b
  j     fail
4:
  li    a0, 0
  j     finish
fail:
  li    a0, 1
finish:
  slli  a0, a0, 1
  ori   a0, a0, 1
  la    t0, tohost
  sd    a0, 0(t0)
5: j 5b

arm_soon:                                # mtimecmp = mtime + 40
  li    t0, CLINT_MTIME
  ld    t1, 0(t0)
  addi  t1, t1, 40
  li    t0, CLINT_MTIMECMP
  sd    t1, 0(t0)
  ret

  .align 8
  .option push
  .option norvc                          # cada entrada debe medir 4 bytes
vtable:
  j     exc_handler                      # 0: excepciones
  .rept 2
  j     fail
  .endr
  j     msi_handler                      # 3
  .rept 3
  j     fail
  .endr
  j     mti_handler                      # 7
  .rept 4
  j     fail
  .endr
  .option pop

exc_handler:
  j     fail

mti_handler:
  csrr  t3, mstatus
  andi  t3, t3, 1 << 7                   # MPIE debe ser 1 (MIE era 1)
  beqz  t3, fail
  csrr  t3, mstatus
  andi  t3, t3, 1 << 3                   # MIE debe ser 0 dentro del handler
  bnez  t3, fail
  addi  s1, s1, 1
  li    t3, 3
  bge   s1, t3, 1f
  li    t3, CLINT_MTIME                  # re-armar
  ld    t4, 0(t3)
  addi  t4, t4, 60
  li    t3, CLINT_MTIMECMP
  sd    t4, 0(t3)
  mret
1:
  li    t3, -1                           # tercera: desarmar
  li    t4, CLINT_MTIMECMP
  sd    t3, 0(t4)
  mret

msi_handler:
  li    t3, CLINT_MSIP
  sw    zero, 0(t3)
  addi  s2, s2, 1
  mret

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
