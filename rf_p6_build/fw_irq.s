; fw_irq.s - Variante IRQ del firmware de captura RF (capa 4).
; En vez de sondear RX_FIFO_LEVEL, habilita IRQ con umbral 64 y sondea el bit0
; de IRQ_STAT (que se latch-ea cuando rx_level >= umbral). Al dispararse, limpia
; IRQ_STAT (W1C) y arranca el DMA. Produce el MISMO contenido en DDR que polling.
; a0 = RF_BASE (0x60000000), a1 = DDR_BASE (0x70000000).
start:
    lui  a0, 0x60000        ; RF_BASE
    lui  a1, 0x70000        ; DDR_BASE
    ; FTW = 0x0293A800
    lui  t0, 0x0293B
    addi t0, t0, -2048
    sw   t0, 0x08(a0)       ; NCO_FTW
    ; coeficientes passthrough del RX FIR
    addi t6, zero, 0
    sw   t6, 0x14(a0)       ; FIR_COEF_ADDR = 0
    lui  t1, 0x8
    addi t1, t1, -1        ; 0x7FFF
    sw   t1, 0x18(a0)       ; tap0 = 0x7FFF
    addi s2, zero, 1
    addi s3, zero, 16
coefloop:
    sw   s2, 0x14(a0)
    sw   zero, 0x18(a0)
    addi s2, s2, 1
    blt  s2, s3, coefloop
    ; configurar IRQ: umbral = 64, habilitar
    addi t2, zero, 64
    sw   t2, 0x30(a0)       ; IRQ_THRESH = 64
    addi t3, zero, 1
    sw   t3, 0x28(a0)       ; IRQ_EN = 1
    ; rx_en = 1, loop_en = 1
    addi t1, zero, 0x5
    sw   t1, 0x00(a0)       ; CTRL
    ; esperar hasta que IRQ_STAT bit0 = 1
wait_irq:
    lw   t4, 0x2C(a0)       ; IRQ_STAT
    andi t4, t4, 1
    beq  t4, zero, wait_irq
    ; limpiar IRQ (W1C)
    addi t5, zero, 1
    sw   t5, 0x2C(a0)       ; IRQ_STAT W1C
    ; arrancar DMA
    sw   a1, 0x34(a0)       ; DMA_ADDR
    addi t4, zero, 64
    sw   t4, 0x38(a0)       ; DMA_LEN
    addi t5, zero, 1
    sw   t5, 0x3C(a0)       ; DMA_CTRL
    ecall
