# soc_timer.S - Capa 4: temporizador del CLINT real del SoC (no el del TB).
#   1. M: mtimecmp = mtime + D con sd; MTI tomada 3 veces (bucle de espera como el
#      cpu_relax de Linux: ld / bne / div por cero / pause / j).
#   2. Ruta OpenSBI: STI delegada. MTI en M -> borra MTIE, pone mip.STIP, mret.
#      S atiende STI y pide el siguiente evento por ecall (borra STIP, rearma
#      mtimecmp y MTIE), como sbi_set_timer. 3 STI en S.
#   Codigos de fallo (a0): 2 = timeout esperando MTI, 3 = timeout esperando STI,
#   4 = trap inesperado en M, 5 = trap inesperado en S.
#define CLINT   0x02000000
#define MTIMECMP 0x4000
#define MTIME   0xBFF8
#define D       40
#define LIMIT   200000
  .section .text.init
  .globl _start
_start:
  la sp, stack_top
  la t0, m_handler
  csrw mtvec, t0
  li s0, CLINT
  li t0, 0x4000
  add s1, s0, t0                  # s1 = &mtimecmp
  li t0, 0xBFF8
  add s2, s0, t0                  # s2 = &mtime
  la s3, counter
  sd zero, 0(s3)
  # ---- parte 1: MTI en M
  ld t0, 0(s2)
  addi t0, t0, D
  sd t0, 0(s1)
  li t0, 1 << 7
  csrs mie, t0
  csrsi mstatus, 8
  li s4, 3
  li s5, LIMIT
1:ld a1, 0(s3)
  bge a1, s4, 2f
  div a2, a1, zero
  .word 0x0100000f                # pause
  addi s5, s5, -1
  bnez s5, 1b
  li a0, 2
  j finish
2:csrci mstatus, 8
  li t0, 1 << 7
  csrc mie, t0
  # ---- parte 2: ruta OpenSBI (STI delegada en S)
  sd zero, 0(s3)
  li t0, -1
  sd t0, 0(s1)                    # mtimecmp lejos
  li t0, 1 << 5
  csrs mideleg, t0
  la t0, s_handler
  csrw stvec, t0
  li t0, 1 << 5
  csrs sie, t0                    # STIE
  li t0, 1 << 7
  csrs mie, t0                    # MTIE (M siempre habilitado desde S)
  ld t0, 0(s2)
  addi t0, t0, D
  sd t0, 0(s1)
  li t0, 3 << 11
  csrc mstatus, t0
  li t0, 1 << 11
  csrs mstatus, t0                # MPP = S
  la t0, s_code
  csrw mepc, t0
  mret

s_code:
  csrsi sstatus, 2                # SIE
  li s4, 3
  li s5, LIMIT
3:ld a1, 0(s3)
  bge a1, s4, 4f
  div a2, a1, zero
  .word 0x0100000f
  addi s5, s5, -1
  bnez s5, 3b
  li a0, 3
  li a7, 1
  ecall
4:li a0, 0
  li a7, 1
  ecall                           # fin

  .align 2
s_handler:
  csrr t0, scause
  li t1, (1 << 63) | 5
  bne t0, t1, s_bad
  ld t0, 0(s3)
  addi t0, t0, 1
  sd t0, 0(s3)
  li a7, 0
  ecall                           # sbi_set_timer
  sret
s_bad:
  li a0, 5
  li a7, 1
  ecall

  .align 2
m_handler:
  csrr t5, mcause
  li t6, (1 << 63) | 7
  beq t5, t6, m_mti
  li t6, 9                        # ecall desde S
  beq t5, t6, m_ecall
  li a0, 4
  j finish
m_mti:
  csrr t6, mstatus
  srli t6, t6, 11
  andi t6, t6, 3
  li t5, 3
  bne t6, t5, 5f                  # vino de S: inyectar STIP como OpenSBI
  ld t5, 0(s3)                    # parte 1: contar y rearmar
  addi t5, t5, 1
  sd t5, 0(s3)
  ld t5, 0(s2)
  addi t5, t5, D
  sd t5, 0(s1)
  mret
5:li t5, 1 << 7
  csrc mie, t5
  li t5, 1 << 5
  csrs mip, t5
  mret
m_ecall:
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  bnez a7, finish                 # a7=1: fin con a0
  li t5, 1 << 5
  csrc mip, t5
  ld t5, 0(s2)
  addi t5, t5, D
  sd t5, 0(s1)
  li t5, 1 << 7
  csrs mie, t5
  mret
finish:
  slli a0, a0, 1
  ori a0, a0, 1
  la t0, tohost
  sd a0, 0(t0)
7: j 7b

  .data
  .align 3
counter: .dword 0
  .align 4
  .space 1024
stack_top:

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
