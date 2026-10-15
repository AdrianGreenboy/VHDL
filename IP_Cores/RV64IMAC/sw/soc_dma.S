# soc_dma.S - DMA NO coherente de una IP_Core real gestionado con Zicbom.
#   El USART de IP_Cores (ranura 0) transmite por DMA un buffer de la DRAM y lo
#   recibe por DMA en otro (bucle interno). La D$ es write-back y el DMA no la ve:
#     antes de TX: cbo.clean  (el DMA debe leer lo que escribio la CPU)
#     antes de RX: cbo.flush  (que no quede una linea sucia que pise lo recibido)
#     tras  RX:    cbo.inval  (que la CPU no lea la copia vieja de su cache)
#   Fin de RX por irq (rx_done) via PLIC. Se compara byte a byte.
#define USART   0x10010000
#define PLIC    0x0C000000
#define N       192                    # 3 lineas de 64 B
  .section .text.init
  .globl _start
_start:
  la sp, stack_top
  la t0, m_handler
  csrw mtvec, t0
  la s4, txbuf
  la s5, rxbuf
  # ---- 1. datos de TX escritos por la CPU (quedan sucios en la D$)
  li t0, 0
1:
  li t1, 37
  mul t2, t0, t1
  addi t2, t2, 11
  add t3, s4, t0
  sb t2, 0(t3)
  addi t0, t0, 1
  li t1, N
  blt t0, t1, 1b
  # ---- 2. buffer de RX con basura, y flush
  li t0, 0
  li t2, 0xEEEEEEEEEEEEEEEE
2:
  add t3, s5, t0
  sd t2, 0(t3)
  addi t0, t0, 8
  li t1, N
  blt t0, t1, 2b
  .irp off, 0, 64, 128
  addi t3, s5, \off
  cbo.flush (t3)
  addi t3, s4, \off
  cbo.clean (t3)                 # ---- 3. TX visible para el DMA
  .endr
  # ---- 4. PLIC y MEI
  li s0, PLIC
  li t0, 1
  sw t0, 8(s0)
  li t1, 0x2000
  add t1, s0, t1
  li t0, 1 << 2
  sw t0, 0(t1)
  li t1, 0x200000
  add t1, s0, t1
  sw zero, 0(t1)
  li t0, 1 << 11
  csrs mie, t0
  csrsi mstatus, 8
  # ---- 5. USART: 6 Mbaud, bucle interno, DMA RX y TX
  li s1, USART
  li t0, 0xF5C28F5C
  sw t0, 0x08(s1)
  li t0, 20
  sw t0, 0x28(s1)
  li t0, 0x87
  sw t0, 0x00(s1)
  li t1, 0x80000000
  sub t0, s5, t1
  sw t0, 0x38(s1)                # DMA_RXA
  li t0, N
  sw t0, 0x3C(s1)                # DMA_RXLEN
  sub t0, s4, t1
  sw t0, 0x30(s1)                # DMA_TXA
  li t0, N
  sw t0, 0x34(s1)                # DMA_TXLEN
  li t0, 0x23                    # tx_start | rx_start | irq_en_rxdone
  sw t0, 0x40(s1)
  # ---- 6. esperar rx_done (lo marca el handler)
  li t2, 3000000
3:
  bnez s3, 4f
  addi t2, t2, -1
  bnez t2, 3b
  li a0, 2
  j finish
4:
  csrci mstatus, 8
  lw t0, 0x48(s1)                # DMA_RXCNT
  li t1, N
  bne t0, t1, bad_cnt
  # ---- 7. invalidar y comparar
  .irp off, 0, 64, 128
  addi t3, s5, \off
  cbo.inval (t3)
  .endr
  li t0, 0
5:
  add t3, s4, t0
  lbu t1, 0(t3)
  add t3, s5, t0
  lbu t2, 0(t3)
  bne t1, t2, bad_data
  addi t0, t0, 1
  li t1, N
  blt t0, t1, 5b
  li a0, 0
  j finish
bad_cnt:  li a0, 3
          j finish
bad_data: li a0, 4
          j finish

  .align 2
m_handler:
  csrr t5, mcause
  bgez t5, m_exc
  li t6, PLIC + 0x200004
  lw t4, 0(t6)                   # claim
  lw a2, 0x44(s1)                # DMA_STAT
  andi a3, a2, 1 << 3            # rx_done
  beqz a3, 6f
  li s3, 1
  li a3, 0x03                    # DMA_CTRL: bajar irq_en_rxdone (bits 5:4 en cada escritura)
  sw zero, 0x40(s1)
6:
  sw a2, 0x44(s1)                # limpiar stickies
  sw t4, 0(t6)                   # complete
  mret
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
  .align 6
txbuf: .zero N
  .align 6
rxbuf: .zero N
  .align 4
  .zero 2048
stack_top:
