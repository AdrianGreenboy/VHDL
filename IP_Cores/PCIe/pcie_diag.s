_start:
    lui   x5, 0x80000          # base MMIO PCIe
    # arrancar EP
    addi  x7, x0, 9
    lui   x8, 0x80000
    addi  x8, x8, 0x100
    sw    x7, 0(x8)            # CONTROL_EP = 9
    # arrancar RC
    addi  x7, x0, 9
    sw    x7, 0(x5)            # CONTROL_RC = 9
    # esperar un poco (que entrene)
    lui   x8, 0x00100
spin:
    addi  x8, x8, -1
    bne   x8, x0, spin
    # leer STATUS RC -> local word[0]
    lw    x10, 4(x5)
    sw    x10, 0(x0)
    # leer STATUS EP -> local word[1]
    lui   x8, 0x80000
    addi  x8, x8, 0x100
    lw    x10, 4(x8)
    sw    x10, 4(x0)
    # leer MWR_CNT RC -> local word[2]
    lw    x10, 36(x5)
    sw    x10, 8(x0)
    # leer CONTROL RC (readback) -> local word[3]
    lw    x10, 0(x5)
    sw    x10, 12(x0)
    # marcador -> local word[5]
    lui   x7, 0x0C0FF
    addi  x7, x7, 0x2E0
    sw    x7, 20(x0)
    # DMA local->DDR, 6 palabras
    lui   x1, 0x40000
    sw    x0, 0(x1)           # src=0
    sw    x0, 4(x1)           # dst=0
    addi  x4, x0, 6
    sw    x4, 8(x1)           # len=6
    addi  x8, x0, 3
    sw    x8, 12(x1)          # CTRL=3
polld:
    lw    x9, 16(x1)
    bne   x9, x0, polld
halt:
    jal   x0, halt
