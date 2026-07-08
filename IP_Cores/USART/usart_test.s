# prueba del IP USART desde el RV32 (loop_int: eco interno, sin pads)
#
# Fase A (PIO):  manda 0x5A y 0xC3 por TXDATA, espera el eco por RXLVL, lee
#                los dos bytes de vuelta; guarda los tres valores en RAM local.
# Fase B (DMA):  canales CONCURRENTES: TX DMA lee 32 bytes de DDRusart[0],
#                pasan por la linea en eco, RX DMA los escribe en
#                DDRusart[256]; espera ambos dones por DMA_STAT (bits 3:0).
# Fase C:        marca 1337 en local[3] y reporta local[0..3] a la DDR del SoC
#                con el dma_burst (dir local->DDR). El TB verifica ambas DDR.
#
# Registros USART en 0x60000000:
#   CTRL=0 STAT=4 BAUD=8 TXDATA=12 RXDATA=16 TXLVL=20 RXLVL=24
#   IRQ_EN=28 IRQ_STAT=32 WM=36 IDLE_TO=40
#   DMA_TXA=48 DMA_TXLEN=52 DMA_RXA=56 DMA_RXLEN=60 DMA_CTRL=64
#   DMA_STAT=68 DMA_RXCNT=72
# Registros DMA del SoC en 0x40000000: SRC=0 DST=4 LEN=8 CTRL=12 STATUS=16

        lui  x1, 0x60000        # x1 = base registros USART
        lui  x2, 0x40000        # x2 = base registros DMA del SoC

        # --- configuracion (inmediatos SEPARADOS: el A72 los parchea) ---
        lui  x5, 0x51EB8        # <- prog[2]: BAUD alto (parcheable)
        addi x5, x5, 1311       # <- prog[3]: BAUD bajo; par = K de 2 Mbaud
        sw   x5, 8(x1)          # BAUD (0x51EB851F)
        addi x5, x0, 20         # <- prog[5]: IDLE_TO (parcheable)
        sw   x5, 40(x1)         # IDLE_TO = 20 tiempos de bit
        addi x5, x0, 135        # <- prog[7]: CTRL (parcheable; 0x87=en|tx|rx|loop)
        sw   x5, 0(x1)          # CTRL

        # --- fase A: PIO, dos bytes en eco ---
        addi x5, x0, 90         # 0x5A
        sw   x5, 12(x1)         # TXDATA
        addi x5, x0, 195        # 0xC3
        sw   x5, 12(x1)         # TXDATA
        addi x7, x0, 2
polla:  lw   x6, 24(x1)         # RXLVL
        bne  x6, x7, polla      # espera los 2 bytes del eco
        lw   x8, 24(x1)         # RXLVL (=2) para el reporte
        sw   x8, 0(x0)          # local[0] = rxlvl
        lw   x9, 16(x1)         # RXDATA (pop) -> 0x5A
        sw   x9, 4(x0)          # local[1]
        lw   x9, 16(x1)         # RXDATA (pop) -> 0xC3
        sw   x9, 8(x0)          # local[2]

        # --- fase B: DMA de dos canales, 32 bytes DDRu[0] -> eco -> DDRu[256] ---
        sw   x0, 48(x1)         # DMA_TXA = 0
        addi x5, x0, 32
        sw   x5, 52(x1)         # DMA_TXLEN = 32 bytes
        addi x5, x0, 256
        sw   x5, 56(x1)         # DMA_RXA = 256
        addi x5, x0, 32
        sw   x5, 60(x1)         # DMA_RXLEN = 32 bytes
        addi x5, x0, 3
        sw   x5, 64(x1)         # DMA_CTRL = tx_start | rx_start (concurrentes)
        addi x7, x0, 15         # mascara bits 3:0: tx_busy|rx_busy|tx_done|rx_done
        addi x8, x0, 12         # esperado: dones=1,1 y busys=0,0
pollb:  lw   x6, 68(x1)         # DMA_STAT
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
