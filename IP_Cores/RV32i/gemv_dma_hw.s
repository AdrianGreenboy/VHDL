# GEMV por tiles con DMA + doorbell (version hardware)
# y = A*x  (A 3x3, x 3, en la DDR).  Al terminar escribe el doorbell (palabra
# 127 de la RAM local) para disparar la IRQ PL->PS.
        lui  x1, 0x40000        # base de registros DMA
        addi x5, x0, 36
        sw   x5, 0(x1)
        addi x6, x0, 0
        sw   x6, 4(x1)
        addi x7, x0, 3
        sw   x7, 8(x1)
        addi x8, x0, 1
        sw   x8, 12(x1)
pollx:  lw   x9, 16(x1)
        bne  x9, x0, pollx
        addi x2,  x0, 0
        addi x20, x0, 3
rowlp:
        addi x10, x0, 12
        mul  x11, x2, x10
        sw   x11, 0(x1)
        addi x12, x0, 64
        sw   x12, 4(x1)
        addi x7, x0, 3
        sw   x7, 8(x1)
        addi x8, x0, 1
        sw   x8, 12(x1)
pollr:  lw   x9, 16(x1)
        bne  x9, x0, pollr
        lw   x13, 64(x0)
        lw   x14, 0(x0)
        mul  x15, x13, x14
        lw   x13, 68(x0)
        lw   x14, 4(x0)
        mul  x16, x13, x14
        add  x15, x15, x16
        lw   x13, 72(x0)
        lw   x14, 8(x0)
        mul  x16, x13, x14
        add  x15, x15, x16
        addi x17, x0, 128
        addi x18, x0, 4
        mul  x19, x2, x18
        add  x17, x17, x19
        sw   x15, 0(x17)
        addi x2, x2, 1
        blt  x2, x20, rowlp
        addi x5, x0, 128
        sw   x5, 0(x1)
        addi x6, x0, 48
        sw   x6, 4(x1)
        addi x7, x0, 3
        sw   x7, 8(x1)
        addi x8, x0, 3
        sw   x8, 12(x1)
polly:  lw   x9, 16(x1)
        bne  x9, x0, polly
        addi x21, x0, 1
        sw   x21, 508(x0)       # doorbell: palabra 127 -> IRQ
halt:   beq  x0, x0, halt
