# GEMV general por tiles con DMA. y = A*x, tamano M x N en tiempo de ejecucion.
# El A72 escribe en la DDR (desde DDR_BASE):
#   [0]=M  [1]=N  [2..]=A (M*N, row-major)  [..]=x (N)  [..]=y (M)
# El core lee M,N del header, trae x y cada fila por DMA (bursts), calcula el
# producto punto local, acumula y, y hace DMA de y de vuelta. Doorbell al final.
#
# Limites: N<=64, M<=64 (para que quepan los tiles en la RAM local de 256).
# RAM local:  x en word 0..N-1 ; fila en word 128.. ; y en word 192.. ; header 64/65
#
# Registros DMA en 0x40000000: SRC=0 DST=4 LEN=8 CTRL=12 STATUS=16
#   CTRL: 1 = leer (DDR->local) ; 3 = escribir (local->DDR)

        lui  x31, 0x40000        # base de registros DMA

        # --- DMA del header (M,N): DDR[0..1] -> local word 64/65 ---
        addi x10, x0, 0          # src = 0
        addi x11, x0, 256        # dst = byte 256 (word 64)
        addi x12, x0, 2          # len = 2
        addi x13, x0, 1          # leer
        jal  x1, dma_go
        lw   x2, 256(x0)         # M
        lw   x3, 260(x0)         # N

        # --- offsets en la DDR (en bytes) ---
        addi x7, x0, 8           # A base = 8
        mul  x20, x2, x3         # M*N
        slli x20, x20, 2         # M*N*4
        add  x8, x7, x20         # x base = 8 + M*N*4
        slli x21, x3, 2          # N*4
        add  x9, x8, x21         # y base = x base + N*4

        # --- DMA de x (N palabras): DDR[x8] -> local word 0 ---
        addi x10, x8, 0
        addi x11, x0, 0
        addi x12, x3, 0          # len = N
        addi x13, x0, 1
        jal  x1, dma_go

        # --- lazo de filas i = 0..M-1 ---
        addi x4, x0, 0           # i = 0
row_loop:
        bge  x4, x2, done
        # DMA fila i (N palabras): DDR[8 + i*N*4] -> local word 128 (byte 512)
        mul  x22, x4, x3         # i*N
        slli x22, x22, 2         # i*N*4
        add  x10, x7, x22        # src = 8 + i*N*4
        addi x11, x0, 512        # dst = byte 512 (word 128)
        addi x12, x3, 0          # len = N
        addi x13, x0, 1
        jal  x1, dma_go
        # dot = sum_{j} row[j]*x[j]
        addi x6, x0, 0           # dot = 0
        addi x5, x0, 0           # j = 0
dot_loop:
        bge  x5, x3, dot_done
        slli x23, x5, 2          # j*4
        addi x25, x23, 512       # dir byte de row[j]
        lw   x26, 0(x25)         # row[j]
        lw   x27, 0(x23)         # x[j]  (base j*4, offset 0)
        mul  x28, x26, x27
        add  x6, x6, x28
        addi x5, x5, 1
        jal  x0, dot_loop
dot_done:
        # y[i] = dot  -> local word 192+i (byte 768 + i*4)
        slli x29, x4, 2
        addi x30, x29, 768
        sw   x6, 0(x30)
        addi x4, x4, 1
        jal  x0, row_loop
done:
        # --- DMA de y (M palabras): local word 192 -> DDR[y9] ---
        addi x10, x0, 768        # src = byte 768 (word 192)
        addi x11, x9, 0          # dst = y base DDR
        addi x12, x2, 0          # len = M
        addi x13, x0, 3          # escribir
        jal  x1, dma_go
        # doorbell
        addi x14, x0, 1
        sw   x14, 508(x0)        # word 127
halt:   beq  x0, x0, halt

# --- subrutina DMA: x10=src x11=dst x12=len x13=ctrl ; usa x14 ; ret por x1 ---
dma_go:
        sw   x10, 0(x31)
        sw   x11, 4(x31)
        sw   x12, 8(x31)
        sw   x13, 12(x31)
dma_poll:
        lw   x14, 16(x31)
        bne  x14, x0, dma_poll
        jalr x0, 0(x1)
