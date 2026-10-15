# soc_usart.S - Capa 4: el RV64 habla con una IP_Core real a traves del SoC.
#   Arranca desde la boot ROM (0x1000), que salta aqui (0x8000_0000).
#   1. USART de IP_Cores en la ranura 0 (0x1001_0000), bucle interno, irq -> PLIC 2.
#   2. Envia N bytes; la irq del USART llega al core como MEI via el PLIC; el handler
#      reclama, vacia RXDATA y completa. Se comparan los bytes recibidos.
#   3. Ventana AXI4-Lite (0x2000_0000): escrituras de 32/64 bit y lectura de vuelta.
#   4. UART 16550 del SoC: escribe "OK\n" por el THR.
#   5. Lecturas de 64 bit a la ranura MMIO (se parten en dos de 32 bit).
#define USART   0x10010000
#define PLIC    0x0C000000
#define AXIL    0x20000000
#define UART    0x10000000
#define N       8
  .section .text.init
  .globl _start
_start:
  la sp, stack_top
  la t0, m_handler
  csrw mtvec, t0
  # ---- PLIC: prioridad[2]=1, enable ctx0 bit 2, umbral 0
  li s0, PLIC
  li t0, 1
  sw t0, 8(s0)                    # prioridad fuente 2
  li t1, 0x2000
  add t1, s0, t1
  li t0, 1 << 2
  sw t0, 0(t1)                    # enable ctx0
  li t1, 0x200000
  add t1, s0, t1
  sw zero, 0(t1)                  # umbral ctx0
  # ---- USART: 2 Mbaud, RX watermark = 1, irq rx_wm, CTRL = EN|TX|RX|LOOP
  li s1, USART
  li t0, 0x51EB851F
  sw t0, 0x08(s1)
  li t0, 1
  sw t0, 0x24(s1)                 # WM: RX watermark 1
  li t0, 1
  sw t0, 0x1C(s1)                 # IRQ_EN: rx_wm
  li t0, 0x87
  sw t0, 0x00(s1)
  # ---- interrupciones externas en M
  li t0, 1 << 11
  csrs mie, t0
  csrsi mstatus, 8
  # ---- enviar N bytes
  li s2, 0
1:
  la t1, txbytes
  add t1, t1, s2
  lbu t0, 0(t1)
  sw t0, 0x0C(s1)
  addi s2, s2, 1
  li t1, N
  blt s2, t1, 1b
  # ---- esperar a recibirlos (s3 = recibidos, lo incrementa el handler)
  li t2, 2000000
2:
  li t1, N
  bge s3, t1, 3f
  addi t2, t2, -1
  bnez t2, 2b
  li a0, 2                        # timeout: la irq no llego
  j finish
3:
  csrci mstatus, 8
  # ---- comparar
  li s2, 0
4:
  la t1, txbytes
  add t1, t1, s2
  lbu t0, 0(t1)
  la t1, rxbytes
  add t1, t1, s2
  lbu t3, 0(t1)
  bne t0, t3, bad_data
  addi s2, s2, 1
  li t1, N
  blt s2, t1, 4b
  # ---- AXI4-Lite: 32 y 64 bit
  li s4, AXIL
  li t0, 0x12345678
  sw t0, 4(s4)
  li t0, 0x0123456789ABCDEF
  sd t0, 8(s4)
  lwu t1, 4(s4)
  ld t2, 8(s4)
  li t0, 0x12345678 ^ 0xA5A50000
  bne t1, t0, bad_axil
  # ---- lectura de 64 bit de la ranura MMIO (RXLVL @0x18 + IRQ_EN @0x1C)
  ld t0, 0x18(s1)
  srli t1, t0, 32
  li t3, 1
  bne t1, t3, bad_mmio64          # IRQ_EN = 1
  # ---- UART del SoC
  li s5, UART
  li t0, 'O'
  sb t0, 0(s5)
  li t0, 'K'
  sb t0, 0(s5)
  li t0, 10
  sb t0, 0(s5)
  lbu t0, 5(s5)                   # LSR
  li a0, 0
  j finish
bad_data:   li a0, 3
            j finish
bad_axil:   li a0, 4
            j finish
bad_mmio64: li a0, 5
            j finish

  .align 2
m_handler:
  csrr t5, mcause
  bgez t5, m_exc
  li t6, PLIC + 0x200004
  lw t4, 0(t6)                    # claim
  li a1, 2
  bne t4, a1, m_bad_id
5:
  lw a2, 0x18(s1)                 # RXLVL
  beqz a2, 6f
  lw a3, 0x10(s1)                 # RXDATA (pop)
  la a4, rxbytes
  add a4, a4, s3
  sb a3, 0(a4)
  addi s3, s3, 1
  j 5b
6:
  sw t4, 0(t6)                    # complete
  mret
m_bad_id:
  li a0, 6
  j finish
m_exc:
  addi a0, t5, 100
finish:
  slli a0, a0, 1
  ori a0, a0, 1
  la t0, tohost
  sd a0, 0(t0)
7: j 7b

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
  .data
txbytes: .byte 0x5A, 0xC3, 0x00, 0xFF, 0x41, 0x7E, 0x81, 0x24
rxbytes: .zero 16
  .align 4
  .zero 2048
stack_top:
