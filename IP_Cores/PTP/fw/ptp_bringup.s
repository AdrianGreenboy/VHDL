# ptp_bringup.s - bring-up del IP PTP: core RV32IM controla el IP en 0x6000_0000,
# escribe la firma en RAM local, la copia a DDR por DMA, y hace doorbell.
# Mapa: 0x0 RAM local | 0x4000_0000 regs DMA | 0x6000_0000 IP PTP
# Firma en RAM local words 120..126 (bytes 480..504); DMA -> DDR[0..].
    li   x5, 0x60000000        # base IP PTP
    li   x31, 0x40000000       # base regs DMA
    # ---- configurar el IP ----
    li   x7, 0x6
    sw   x7, 0(x5)
    li   x7, 0x00400010
    sw   x7, 4(x5)
    li   x7, 0x00112233
    sw   x7, 16(x5)
    li   x7, 0x44556677
    sw   x7, 20(x5)
    li   x7, 0x1
    sw   x7, 24(x5)
    li   x7, 0xF
    sw   x7, 64(x5)
    # ---- FLUJO 1: Sync ----
    li   x7, 0xF
    sw   x7, 36(x5)
    li   x7, 0x1
    sw   x7, 12(x5)
    jal  x1, wait_status0
    lw   x7, 36(x5)
    sw   x7, 480(x0)           # firma word120 = STATUS
    # ---- FLUJO 2: peer-delay ----
    li   x7, 0xF
    sw   x7, 36(x5)
    li   x7, 0x2
    sw   x7, 12(x5)
    jal  x1, wait_status2
    lw   x7, 48(x5)            # MPD_LO
    sw   x7, 484(x0)           # firma word121 = MPD_LO
    lw   x7, 52(x5)            # MPD_HI
    sw   x7, 488(x0)           # firma word122 = MPD_HI
    # ---- FLUJO 3: esclavo ----
    li   x7, 0x7
    sw   x7, 0(x5)
    li   x7, 0xF
    sw   x7, 36(x5)
    li   x7, 0x1
    sw   x7, 12(x5)
    jal  x1, wait_status3
    lw   x7, 56(x5)            # OFFSET
    sw   x7, 492(x0)           # firma word123 = OFFSET
    li   x7, 0x0000D0ED
    sw   x7, 496(x0)           # firma word124 = doorbell marca
    # ---- DMA de la firma (5 palabras) local word120 -> DDR[0] ----
    addi x10, x0, 480          # src = byte 480 (word 120)
    addi x11, x0, 0            # dst = DDR offset 0
    addi x12, x0, 5            # len = 5 palabras
    addi x13, x0, 3            # ctrl = local->DDR
    jal  x1, dma_go
    # ---- doorbell ----
    addi x14, x0, 1
    sw   x14, 508(x0)          # word 127
halt:
    jal  x0, halt
# --- subrutina DMA: x10=src x11=dst x12=len x13=ctrl; usa x14; ret x1 ---
dma_go:
    sw   x10, 0(x31)
    sw   x11, 4(x31)
    sw   x12, 8(x31)
    sw   x13, 12(x31)
dma_poll:
    lw   x14, 16(x31)
    bne  x14, x0, dma_poll
    jalr x0, 0(x1)
wait_status0:
    lw   x8, 36(x5)
    andi x8, x8, 0x1
    beq  x8, x0, wait_status0
    jalr x0, 0(x1)
wait_status2:
    lw   x8, 36(x5)
    andi x8, x8, 0x4
    beq  x8, x0, wait_status2
    jalr x0, 0(x1)
wait_status3:
    lw   x8, 36(x5)
    andi x8, x8, 0x8
    beq  x8, x0, wait_status3
    jalr x0, 0(x1)
