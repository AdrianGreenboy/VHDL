# GEMV por tiles con DMA: y = A*x  (A es 3x3, x es 3, en la DDR)
# El core programa la DMA para traer x y cada fila de A desde la DDR a la RAM
# local, calcula el producto punto localmente, y al final hace DMA de y a la DDR.
#
# Mapa DDR (offsets en bytes):  A en 0 (9 palabras), x en 36 (3), y en 48 (3)
# Mapa local (bytes):  local_x en 0,  local_row en 64,  local_y en 128
# Registros DMA en 0x40000000: SRC=0, DST=4, LEN=8, CTRL=12, STATUS=16
#   CTRL: bit0=start, bit1=dir (0=DDR->local, 1=local->DDR)

        lui  x1, 0x40000        # x1 = base de registros DMA

        # --- DMA de x: DDR[36] (3 palabras) -> local_x (byte 0) ---
        addi x5, x0, 36
        sw   x5, 0(x1)          # SRC = 36
        addi x6, x0, 0
        sw   x6, 4(x1)          # DST = 0
        addi x7, x0, 3
        sw   x7, 8(x1)          # LEN = 3
        addi x8, x0, 1
        sw   x8, 12(x1)         # CTRL = start, dir=0 (lectura)
pollx:  lw   x9, 16(x1)
        bne  x9, x0, pollx      # espera busy=0

        # --- lazo de filas i = 0..2 ---
        addi x2,  x0, 0         # i = 0
        addi x20, x0, 3         # M = 3
rowlp:
        addi x10, x0, 12
        mul  x11, x2, x10       # src = i*12  (fila i de A)
        sw   x11, 0(x1)         # SRC
        addi x12, x0, 64
        sw   x12, 4(x1)         # DST = 64 (local_row)
        addi x7, x0, 3
        sw   x7, 8(x1)          # LEN = 3
        addi x8, x0, 1
        sw   x8, 12(x1)         # start, lectura
pollr:  lw   x9, 16(x1)
        bne  x9, x0, pollr

        # dot = row[0]*x[0] + row[1]*x[1] + row[2]*x[2]
        lw   x13, 64(x0)        # row[0]
        lw   x14, 0(x0)         # x[0]
        mul  x15, x13, x14
        lw   x13, 68(x0)        # row[1]
        lw   x14, 4(x0)         # x[1]
        mul  x16, x13, x14
        add  x15, x15, x16
        lw   x13, 72(x0)        # row[2]
        lw   x14, 8(x0)         # x[2]
        mul  x16, x13, x14
        add  x15, x15, x16      # x15 = producto punto

        # local_y[i] = dot   (byte 128 + i*4)
        addi x17, x0, 128
        addi x18, x0, 4
        mul  x19, x2, x18
        add  x17, x17, x19
        sw   x15, 0(x17)

        addi x2, x2, 1
        blt  x2, x20, rowlp

        # --- DMA de y: local_y (byte 128, 3 palabras) -> DDR[48] ---
        addi x5, x0, 128
        sw   x5, 0(x1)          # SRC = 128 (local)
        addi x6, x0, 48
        sw   x6, 4(x1)          # DST = 48 (DDR)
        addi x7, x0, 3
        sw   x7, 8(x1)          # LEN = 3
        addi x8, x0, 3
        sw   x8, 12(x1)         # CTRL = start + dir=1 (escritura local->DDR)
polly:  lw   x9, 16(x1)
        bne  x9, x0, polly

halt:   beq  x0, x0, halt
