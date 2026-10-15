# cbo_test.S - Zicbom: habilitacion por menvcfg/senvcfg, permisos y fallos en
# M/S/U con Sv39, y efecto real en la D$ (dato escrito, flush, lectura).
  .section .text.init
  .globl _start
_start:
  .irp r, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
  li x\r, 0
  .endr
  la t0, m_handler
  csrw mtvec, t0
  # PMP abierta (no-op aqui, necesaria en Spike)
  li t0, -1
  csrw pmpaddr0, t0
  li t0, 0x1f
  csrw pmpcfg0, t0
  la s0, buf
  # ---- M: siempre permitido, incluso con menvcfg = 0
  cbo.clean (s0)
  cbo.flush (s0)
  cbo.inval (s0)
  li t0, 0x12345678
  sd t0, 0(s0)
  cbo.flush (s0)
  ld t1, 0(s0)
  bne t0, t1, fail
  # ---- menvcfg: WARL de CBIE (10 -> 00) y CBCFE
  li t0, 0x7F
  csrw menvcfg, t0
  csrr t1, menvcfg
  li t0, 0x21
  csrw menvcfg, t0
  csrr t1, menvcfg
  li t0, 0x61
  csrw menvcfg, t0
  csrr t1, menvcfg
  # ---- Sv39: gigapagina identidad + pagina de datos de solo lectura (R) en 0x40000000
  la t0, pt_root
  li t1, (0x80000000 >> 12) << 10 | 0xCF
  sd t1, 16(t0)
  la t2, pt_l1
  srli t1, t2, 12
  slli t1, t1, 10
  ori t1, t1, 1
  sd t1, 8(t0)
  la t3, pt_l0
  srli t1, t3, 12
  slli t1, t1, 10
  ori t1, t1, 1
  sd t1, 0(t2)
  srli t1, s0, 12
  slli t1, t1, 10
  ori t1, t1, 0x43                # V R A (sin W): CMO permitido (traduce como load)
  sd t1, 0(t3)
  srli t1, s0, 12
  slli t1, t1, 10
  ori t1, t1, 0x89                # V X D sin A: fallo (Svade)
  sd t1, 8(t3)
  la t4, u_code                   # pagina de codigo U en 0x40002000
  srli t1, t4, 12
  slli t1, t1, 10
  ori t1, t1, 0x5B                # V R X U A
  sd t1, 16(t3)
  srli t1, s0, 12                 # pagina de datos U en 0x40003000
  slli t1, t1, 10
  ori t1, t1, 0x53                # V R U A
  sd t1, 24(t3)
  srli t0, t0, 12
  li t1, 8 << 60
  or t0, t0, t1
  csrw satp, t0
  sfence.vma
  # ---- a S
  li t0, 1 << 11
  csrs mstatus, t0
  la t0, s_code
  csrw mepc, t0
  mret
s_code:
  li s1, 0x40000000
  # combinaciones de menvcfg (las cambia M via ecall a7=1, valor en a1)
  .irp cfg, 0x00, 0x10, 0x30, 0x40, 0x70
  li a7, 1
  li a1, \cfg
  ecall
  cbo.clean (s1)
  cbo.flush (s1)
  cbo.inval (s1)
  addi s3, s1, 8
  cbo.clean (s3)                  # direccion no alineada a la linea
  .endr
  li a7, 1
  li a1, 0x70
  ecall
  li s2, 0x40001000               # pagina sin A -> store page fault
  cbo.flush (s2)
  li s2, 0x0000004000000000       # no canonica -> store page fault
  cbo.clean (s2)
  li s2, 0xC0000000               # sin mapear -> store page fault
  cbo.inval (s2)
  # ---- U: senvcfg
  li a7, 2
  ecall
  csrr t0, senvcfg                # S puede leer senvcfg
  li t0, 0x7F
  csrw senvcfg, t0
  csrr t1, senvcfg
  li a7, 3                        # a U
  li a1, 0x40002000
  ecall

  .section .text.ucode, "ax", @progbits
  .align 12
u_code:
  cbo.clean (s0)                  # gigapagina sin U -> page fault
  li s2, 0x40003000
  cbo.clean (s2)                  # pagina U: permitido (senvcfg.CBCFE = 1)
  cbo.inval (s2)                  # senvcfg.CBIE = 11
  li a7, 9
  ecall
  .section .text.init
  .align 2
m_handler:
  csrr t5, mcause
  li t6, 8
  bltu t5, t6, skip
  li t6, 12
  bgeu t5, t6, skip
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  li t6, 1
  bne a7, t6, 1f
  csrw menvcfg, a1
  mret
1:
  li t6, 2
  bne a7, t6, 2f
  mret
2:
  li t6, 3
  bne a7, t6, 3f
  li t6, 0x1800
  csrc mstatus, t6                # MPP = U
  csrw mepc, a1
  mret
3:
  li t0, 1
  la t1, tohost
  sd t0, 0(t1)
4: j 4b
skip:
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret
fail:
  li t0, 3
  la t1, tohost
  sd t0, 0(t1)
5: j 5b

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
  .data
  .align 12
pt_root: .zero 4096
pt_l1: .zero 4096
pt_l0: .zero 4096
buf: .zero 4096
