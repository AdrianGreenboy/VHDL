# prueba del IP SPI desde el RV32 (con MISO en loopback en el TB)
#
# Fase A (PIO):  manda 0x5A y 0xC3 por TXDATA, espera fin, lee RXLVL y los
#                dos bytes de vuelta; guarda los tres valores en RAM local.
# Fase B (DMA):  transferencia full-duplex de 32 bytes DDRspi[0] -> DDRspi[256],
#                espera done por STATUS (bits 7:8).
# Fase C:        marca 1337 en local[3] y reporta local[0..3] a la DDR del SoC
#                con el dma_burst (dir local->DDR). El TB verifica ambas DDR.
#
# Registros SPI en 0x50000000:
#   CTRL=0 STATUS=4 CLKDIV=8 TXDATA=12 RXDATA=16 TXLVL=20 RXLVL=24
#   DMA_TXA=28 DMA_RXA=32 DMA_LEN=36 DMA_CTRL=40
# Registros DMA del SoC en 0x40000000: SRC=0 DST=4 LEN=8 CTRL=12 STATUS=16

        lui  x1, 0x50000        # x1 = base registros SPI
        lui  x2, 0x40000        # x2 = base registros DMA del SoC

        # --- configuracion SPI (inmediatos SEPARADOS: el A72 los parchea) ---
        addi x5, x0, 1          # <- prog[2]: CLKDIV (parcheable)
        sw   x5, 8(x1)          # CLKDIV
        addi x5, x0, 129        # <- prog[4]: CTRL (parcheable; 0x81 = en+loop_int)
        sw   x5, 0(x1)          # CTRL

        # --- fase A: PIO, dos bytes en eco ---
        addi x5, x0, 90         # 0x5A
        sw   x5, 12(x1)         # TXDATA
        addi x5, x0, 195        # 0xC3
        sw   x5, 12(x1)         # TXDATA
polla:  lw   x6, 4(x1)          # STATUS
        andi x6, x6, 3          # bit0=busy, bit1=tx_empty
        addi x7, x0, 2
        bne  x6, x7, polla      # espera busy=0 y tx_empty=1
        lw   x8, 24(x1)         # RXLVL (espero 2)
        sw   x8, 0(x0)          # local[0] = rxlvl
        lw   x9, 16(x1)         # RXDATA (pop) -> 0x5A
        sw   x9, 4(x0)          # local[1]
        lw   x9, 16(x1)         # RXDATA (pop) -> 0xC3
        sw   x9, 8(x0)          # local[2]

        # --- fase B: DMA del SPI, 32 bytes DDRspi[0] -> eco -> DDRspi[256] ---
        sw   x0, 28(x1)         # DMA_TXA = 0
        addi x5, x0, 256
        sw   x5, 32(x1)         # DMA_RXA = 256
        addi x5, x0, 32
        sw   x5, 36(x1)         # DMA_LEN = 32 bytes
        addi x5, x0, 7
        sw   x5, 40(x1)         # DMA_CTRL = start + tx_en + rx_en
        addi x7, x0, 384        # mascara: busy_sticky(7) | done(8)
        addi x8, x0, 256        # esperado: done=1, busy=0
pollb:  lw   x6, 4(x1)          # STATUS
        and  x6, x6, x7
        bne  x6, x8, pollb

        # --- marca de exito ---
        addi x5, x0, 1337
        sw   x5, 12(x0)         # local[3] = 1337

        # --- fase C: reporta local[0..3] a la DDR del SoC ---
        sw   x0, 0(x2)          # SRC = 0 (local, bytes)
        sw   x0, 4(x2)          # DST = 0 (DDR, bytes)
        addi x5, x0, 4
        sw   x5, 8(x2)          # LEN = 4 palabras
        addi x5, x0, 3
        sw   x5, 12(x2)         # CTRL = start + dir=1 (local -> DDR)
pollc:  lw   x6, 16(x2)         # STATUS (busy pegajoso)
        bne  x6, x0, pollc

halt:   beq  x0, x0, halt
