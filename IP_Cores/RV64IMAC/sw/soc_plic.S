# soc_plic.S - Capa 4: PLIC del SoC, contexto 1 (S hart0), como lo usa Linux.
#   1. Relectura de registros: prioridad, enable ctx1 (bit 0 cableado a 0), umbral ctx1.
#   2. Umbral: con prioridad 1 y umbral 1 la irq del USART queda pendiente (0x1000)
#      pero no llega al core.
#   3. SEI delegada a S: el handler de S reclama en 0x201004 (id 2), vacia RXDATA y
#      completa; N bytes por el bucle interno del USART de IP_Cores.
#   4. Claim sin nada pendiente devuelve 0.
#   Fallos (a0): 2 relectura prio, 3 relectura enable, 4 relectura umbral, 5 irq con
#   umbral, 6 pendiente no visible, 7 timeout, 8 id malo, 9 datos, 10 claim vacio,
#   11 trap inesperado en S, 12 trap inesperado en M.
#define USART   0x10010000
#define PLIC    0x0C000000
#define N       6
  .section .text.init
  .globl _start
_start:
  la sp, stack_top
  la t0, m_handler
  csrw mtvec, t0
  li s0, PLIC
  li s1, USART
  la s3, count
  sd zero, 0(s3)
  # ---- 1. relectura
  li t0, 5
  sw t0, 8(s0)                    # prio[2] = 5
  li t0, 0xFF
  sw t0, 12(s0)                   # prio[3] = 0xFF -> 7
  lw t1, 8(s0)
  li t2, 5
  li a0, 2
  bne t1, t2, finish
  lw t1, 12(s0)
  li t2, 7
  bne t1, t2, finish
  li t3, 0x2080
  add s4, s0, t3                  # s4 = enable ctx1
  li t0, -1
  sw t0, 0(s4)
  lwu t1, 0(s4)
  li t2, 0xFFFFFFFE
  li a0, 3
  bne t1, t2, finish
  li t3, 0x201000
  add s5, s0, t3                  # s5 = umbral ctx1, s5+4 = claim ctx1
  li t0, 3
  sw t0, 0(s5)
  lw t1, 0(s5)
  li a0, 4
  bne t1, t0, finish
  # ---- configuracion: solo fuente 2 en ctx1, prioridad 1, umbral 1 (bloquea)
  li t0, 1 << 2
  sw t0, 0(s4)
  sw zero, 12(s0)
  li t0, 1
  sw t0, 8(s0)
  sw t0, 0(s5)
  li t3, 0x2000
  add t3, s0, t3
  sw zero, 0(t3)                  # ctx0 sin fuentes
  # ---- USART: 2 Mbaud, RX watermark 1, irq rx_wm, EN|TX|RX|LOOP
  li t0, 0x51EB851F
  sw t0, 0x08(s1)
  li t0, 1
  sw t0, 0x24(s1)
  sw t0, 0x1C(s1)
  li t0, 0x87
  sw t0, 0x00(s1)
  # ---- delegacion SEI y paso a S
  li t0, 1 << 9
  csrs mideleg, t0
  la t0, s_handler
  csrw stvec, t0
  li t0, 1 << 9
  csrs sie, t0
  li t0, 3 << 11
  csrc mstatus, t0
  li t0, 1 << 11
  csrs mstatus, t0
  la t0, s_code
  csrw mepc, t0
  mret

s_code:
  csrsi sstatus, 2
  # ---- 2. un byte con umbral 1: pendiente pero sin irq
  li t0, 0x5A
  sw t0, 0x0C(s1)
  li t2, 30000
1:addi t2, t2, -1
  bnez t2, 1b
  ld t0, 0(s3)
  li a0, 5
  bnez t0, s_fin
  li t1, 0x1000
  add t1, s0, t1
  lw t0, 0(t1)
  andi t0, t0, 1 << 2
  li a0, 6
  beqz t0, s_fin
  # ---- 3. umbral 0: llega la irq del byte pendiente y luego N-1 mas
  sw zero, 0(s5)
  la s6, txbytes
  li s7, 1
2:li t1, N
  bge s7, t1, 3f
  add t1, s6, s7
  lbu t0, 0(t1)
  sw t0, 0x0C(s1)
  addi s7, s7, 1
  j 2b
3:li t2, 2000000
4:ld t0, 0(s3)
  li t1, N
  bge t0, t1, 5f
  addi t2, t2, -1
  bnez t2, 4b
  li a0, 7
  j s_fin
5:csrci sstatus, 2
  li s7, 0                        # comparar (el primero es 0x5A)
6:la t1, rxbytes
  add t1, t1, s7
  lbu t0, 0(t1)
  add t1, s6, s7
  lbu t3, 0(t1)
  li a0, 9
  bne t0, t3, s_fin
  addi s7, s7, 1
  li t1, N
  blt s7, t1, 6b
  # ---- 4. claim vacio
  lw t0, 4(s5)
  li a0, 10
  bnez t0, s_fin
  li a0, 0
s_fin:
  ecall

  .align 2
s_handler:
  csrr t5, scause
  li t6, (1 << 63) | 9
  bne t5, t6, s_bad
  lw t4, 4(s5)                    # claim ctx1
  li t6, 2
  bne t4, t6, s_badid
7:lw a2, 0x18(s1)                 # RXLVL
  beqz a2, 8f
  lw a3, 0x10(s1)                 # RXDATA
  ld a4, 0(s3)
  la a5, rxbytes
  add a5, a5, a4
  sb a3, 0(a5)
  addi a4, a4, 1
  sd a4, 0(s3)
  j 7b
8:sw t4, 4(s5)                    # complete
  sret
s_bad:
  li a0, 11
  ecall
s_badid:
  li a0, 8
  ecall

  .align 2
m_handler:
  csrr t5, mcause
  li t6, 9                        # ecall desde S: fin con a0
  beq t5, t6, finish
  li a0, 12
finish:
  slli a0, a0, 1
  ori a0, a0, 1
  la t0, tohost
  sd a0, 0(t0)
9: j 9b

  .data
txbytes: .byte 0x5A, 0x11, 0xC3, 0x7E, 0x00, 0xFF
  .align 3
count: .dword 0
rxbytes: .space 16
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
