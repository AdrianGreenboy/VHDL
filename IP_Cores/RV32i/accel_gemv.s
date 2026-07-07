# Acelerador GEMV: y[M] = A[M][N] * x[N]
# Convencion de la DMEM (indices de palabra):
#   [0]                 M (filas)                 <- Linux
#   [1]                 N (columnas)              <- Linux
#   [2 .. 2+M*N-1]      A en row-major            <- Linux
#   [2+M*N .. +N-1]     x (vector)                <- Linux
#   [64 .. 64+M-1]      y (resultado)             -> core
#   [80]                bandera "listo" (=1)      -> core (al final)
        lw   x1, 0(x0)         # M
        lw   x2, 4(x0)         # N
        addi x3, x0, 8         # A_ptr = &A[0][0] (byte addr de la palabra 2)
        mul  x5, x1, x2        # M*N
        slli x5, x5, 2         # M*N*4 (bytes)
        add  x6, x3, x5        # x_ptr = A_ptr + M*N*4
        addi x7, x0, 256       # y_ptr = palabra 64 (byte 256)
        addi x8, x0, 0         # i = 0
row:    bge  x8, x1, done_g    # si i >= M -> fin
        addi x9, x0, 0         # acc = 0
        addi x10, x0, 0        # j = 0
        mul  x11, x8, x2       # i*N
        slli x11, x11, 2       # *4
        add  x11, x3, x11      # &A[i][0]
col:    bge  x10, x2, endrow   # si j >= N -> fin de fila
        slli x12, x10, 2       # j*4
        add  x13, x11, x12     # &A[i][j]
        lw   x14, 0(x13)       # A[i][j]
        add  x15, x6, x12      # &x[j]
        lw   x16, 0(x15)       # x[j]
        mul  x17, x14, x16     # A[i][j]*x[j]
        add  x9, x9, x17       # acc += producto
        addi x10, x10, 1       # j++
        beq  x0, x0, col
endrow: slli x18, x8, 2        # i*4
        add  x19, x7, x18      # &y[i]
        sw   x9, 0(x19)        # y[i] = acc
        addi x8, x8, 1         # i++
        beq  x0, x0, row
done_g: addi x20, x0, 1
        sw   x20, 508(x0)      # DMEM[127] = 1 (doorbell "listo" -> IRQ)
halt:   beq  x0, x0, halt
