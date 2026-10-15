# irq_storm.S - Capa 2/3 dirigida: interrupciones asincronas sobre codigo mixto.
#  M: MTI con periodo pseudoaleatorio; reinyecta STI delegada a S (como OpenSBI)
#     y atiende ecall de S (borra STIP / dispara MSI por el CLINT).
#  S: atiende STI, cuenta, pide a M que borre STIP. Ejecuta la carga util:
#     mul/div, ld/sd, AMO, LR/SC, saltos y RVC.
# El oraculo es el lockstep contra iss64.py; al final se exige >= 20 STI.
#define CLINT_MSIP      0x02000000
#define CLINT_MTIMECMP  0x02004000
#define CLINT_MTIME     0x0200BFF8

  .section .text.init
  .globl _start
_start:
  # el banco de registros no tiene reset (spec sec. 8): inicializarlo
  .irp r, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
  li    x\r, 0
  .endr
  la    sp, stack_top
  la    t0, m_stack_top
  csrw  mscratch, t0
  la    t0, m_handler
  csrw  mtvec, t0
  li    t0, (1 << 5) | (1 << 1)          # STIP, SSIP delegadas a S
  csrw  mideleg, t0
  li    t0, (1 << 7) | (1 << 3)          # MTIE, MSIE
  csrw  mie, t0
  li    s11, 0x1234567                   # LFSR de M
  call  arm_timer
  la    t0, s_handler
  csrw  stvec, t0
  li    t0, 1 << 11                      # MPP = S
  csrs  mstatus, t0
  la    t0, s_main
  csrw  mepc, t0
  mret

# -------------------------------------------------------------- M
arm_timer:                               # mtimecmp = mtime + 5 + (lfsr & 63)
  srli  t1, s11, 1
  andi  t2, s11, 1
  neg   t2, t2
  li    t3, 0xB4BCD35C
  and   t2, t2, t3
  xor   s11, t1, t2
  andi  t1, s11, 63
  addi  t1, t1, 5
  li    t0, CLINT_MTIME
  ld    t2, 0(t0)
  add   t2, t2, t1
  li    t0, CLINT_MTIMECMP
  sd    t2, 0(t0)
  ret

  .align 2
m_handler:
  csrrw sp, mscratch, sp                 # pila propia de M: S no ve nada cambiado
  addi  sp, sp, -64
  sd    ra, 0(sp)
  sd    t0, 8(sp)
  sd    t1, 16(sp)
  sd    t2, 24(sp)
  sd    t3, 32(sp)
  sd    t5, 40(sp)
  sd    t6, 48(sp)
  csrr  t5, mcause
  bltz  t5, m_irq
  li    t6, 9                            # ecall desde S
  bne   t5, t6, m_bad
  csrr  t6, mepc
  addi  t6, t6, 4
  csrw  mepc, t6
  beqz  a7, 1f
  li    t6, CLINT_MSIP                   # a7 != 0: disparar MSI
  li    t5, 1
  sw    t5, 0(t6)
  j     m_ret
1:
  li    t6, 1 << 5                       # a7 == 0: borrar STIP
  csrc  mip, t6
  j     m_ret
m_irq:
  slli  t5, t5, 1
  srli  t5, t5, 1
  li    t6, 7
  beq   t5, t6, m_timer
  li    t6, 3
  bne   t5, t6, m_bad
  li    t6, CLINT_MSIP                   # MSI: bajarla y contarla
  sw    zero, 0(t6)
  addi  s9, s9, 1
  j     m_ret
m_timer:
  call  arm_timer
  li    t6, 1 << 5                       # inyectar STI en S
  csrs  mip, t6
  addi  s8, s8, 1
m_ret:
  ld    ra, 0(sp)
  ld    t0, 8(sp)
  ld    t1, 16(sp)
  ld    t2, 24(sp)
  ld    t3, 32(sp)
  ld    t5, 40(sp)
  ld    t6, 48(sp)
  addi  sp, sp, 64
  csrrw sp, mscratch, sp
  mret
m_bad:
  li    a0, 3
  j     finish

# -------------------------------------------------------------- S
  .align 2
s_handler:
  csrw  sscratch, a7
  csrr  a7, scause
  bgez  a7, s_bad
  addi  s10, s10, 1                      # STI atendida
  li    a7, 0
  ecall                                  # M borra STIP
  csrr  a7, sscratch
  sret
s_bad:
  li    a0, 5
  j     finish

s_main:
  li    t0, 1 << 5
  csrs  sie, t0                          # STIE
  csrsi sstatus, 2                       # SIE
  la    s0, buf
  li    s1, 3000                         # iteraciones
  li    s2, 0x9E3779B97F4A7C15
  li    s3, 0
  li    a7, 0
loop:
  mul   s2, s2, s1
  addi  s2, s2, 7
  divu  t0, s2, s1
  remw  t1, s2, s1
  add   s3, s3, t0
  xor   s3, s3, t1
  andi  t2, s1, 0x1F8
  add   t2, t2, s0
  sd    s3, 0(t2)
  ld    t3, 8(t2)
  c.add s3, t3
  amoadd.d t4, s1, (s0)
  c.addi s3, 1
1:
  lr.d  t5, (s0)
  add   t5, t5, s3
  sc.d  t6, t5, (s0)
  bnez  t6, 1b
  andi  t0, s1, 255
  bnez  t0, 2f
  li    a7, 1                            # cada 256 iteraciones: MSI via M
  ecall
  li    a7, 0
2:
  c.addi s1, -1
  bnez  s1, loop
  li    t0, 20
  blt   s10, t0, few_irq
  li    a0, 0
  j     finish
few_irq:
  li    a0, 7
finish:
  slli  a0, a0, 1
  ori   a0, a0, 1
  la    t0, tohost
  sd    a0, 0(t0)
3: j 3b

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0

  .data
  .align 6
buf: .zero 1024
  .zero 4096
stack_top:
  .zero 1024
m_stack_top:
