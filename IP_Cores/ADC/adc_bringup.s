# adc_bringup.s - bring-up del ADC delta-sigma soft IP v1: el core RV32IM
# configura el IP en 0x6000_0000 (FINC + CTRL en=1/src=0/OSR=256), espera
# nivel >= 64 en la FIFO, drena 64 muestras a RAM local (words 0..63),
# escribe la sentinela 0xADC0FEED en word 64, copia 65 palabras a DDR[0]
# por el DMA del SoC (0x4000_0000) y hace doorbell (word 127).
# Programa IDENTICO en efecto a iss_adc.py (oraculo de capa 4).
#
# Mapa del IP (offset de byte): 0x00 CTRL  0x08 TEST_FINC  0x0C FIFO_LEVEL
#                               0x10 FIFO_DATA (pop en lectura)
# Regs DMA SoC: 0x00 SRC  0x04 DST  0x08 LEN  0x0C CTRL  0x10 STATUS
#
# asm.py: li = 2 palabras; sin la/lbu/.byte; offsets decimales o hex.

    li   x5, 0x60000000        # base IP ADC
    li   x31, 0x40000000       # base regs DMA del SoC

    # ---- configurar generador: FINC explicito ----
    li   x7, 0x00193000
    sw   x7, 8(x5)             # TEST_FINC

    # ---- CTRL: enable=1, src_sel=0, osr_sel=11 (OSR 256) -> 0xD ----
    li   x7, 0xD
    sw   x7, 0(x5)

    # ---- esperar FIFO_LEVEL >= 64 ----
    li   x8, 64
espera:
    lw   x9, 12(x5)            # FIFO_LEVEL
    blt  x9, x8, espera

    # ---- drenar 64 muestras a RAM local words 0..63 ----
    li   x10, 0                # puntero local (bytes)
    li   x11, 64               # contador
drena:
    lw   x9, 16(x5)            # FIFO_DATA (pop)
    sw   x9, 0(x10)
    addi x10, x10, 4
    addi x11, x11, -1
    bne  x11, x0, drena

    # ---- sentinela en word 64 (x10 = 256) ----
    li   x7, 0xADC0FEED
    sw   x7, 0(x10)

    # ---- DMA: 65 palabras local[0] -> DDR[0] (dir=1) ----
    sw   x0, 0(x31)            # SRC = 0 (byte local)
    sw   x0, 4(x31)            # DST = 0 (offset DDR)
    li   x7, 65
    sw   x7, 8(x31)            # LEN
    li   x7, 3                 # start | dir(local->DDR)
    sw   x7, 12(x31)

    # ---- esperar fin del DMA (busy pegajoso) ----
dpoll:
    lw   x9, 16(x31)           # STATUS
    andi x9, x9, 1
    bne  x9, x0, dpoll

    # ---- doorbell: word 127 de la RAM local (byte 508) ----
    li   x7, 0x0000D0ED
    li   x10, 508
    sw   x7, 0(x10)

fin:
    jal  x0, fin
