# Acelerador: suma de cuadrados de un arreglo en DMEM.
# Convencion de memoria (palabras de la DMEM):
#   [0]      N (cantidad de elementos)          <- lo escribe Linux
#   [1..N]   arreglo de entradas                 <- lo escribe Linux
#   [64]     resultado (sum de x[k]^2)           -> lo escribe el core
#   [65]     bandera "listo" (1 = terminado)     -> lo escribe el core (al final)
        lw   x2, 0(x0)        # N = DMEM[0]
        addi x3, x0, 0        # acc = 0
        addi x4, x0, 1        # k = 1
        addi x5, x2, 1        # limite = N+1
loop:   bge  x4, x5, done_c   # si k >= N+1, termina
        slli x6, x4, 2        # offset de byte = k*4
        lw   x8, 0(x6)        # x8 = DMEM[k]
        mul  x9, x8, x8       # x8^2
        add  x3, x3, x9       # acc += x8^2
        addi x4, x4, 1        # k++
        beq  x0, x0, loop
done_c: addi x10, x0, 256     # direccion del resultado (palabra 64 = byte 256)
        sw   x3, 0(x10)       # DMEM[64] = acc
        addi x11, x0, 1
        sw   x11, 260(x0)     # DMEM[65] = 1 (listo)
halt:   beq  x0, x0, halt     # detente aqui
