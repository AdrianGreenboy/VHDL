        # --- Paso 5: salida por UART + poweroff via syscon ---
        li   x10, 0x10000000      # base UART (THR)
        li   x11, 0x10000005      # LSR
        # --- comprobar el valor COMPLETO del LSR (debe ser 0x60) ---
        lbu  x20, 0(x11)
        li   x21, 0x60
        beq  x20, x21, lsr_ok
        li   x12, 69              # 'E' de error: LSR inesperado
        jal  x1, putc
        li   x14, 0x11100000
        li   x15, 0x5555
        sw   x15, 0(x14)          # poweroff temprano
lsr_ok:
        # imprimir "HERCOSSNUX\n" caracter por caracter,
        # esperando THRE (bit 5 del LSR) antes de cada uno.
        li   x12, 72              # 'H'
        jal  x1, putc
        li   x12, 69              # 'E'
        jal  x1, putc
        li   x12, 82              # 'R'
        jal  x1, putc
        li   x12, 67              # 'C'
        jal  x1, putc
        li   x12, 79              # 'O'
        jal  x1, putc
        li   x12, 83              # 'S'
        jal  x1, putc
        li   x12, 83              # 'S'
        jal  x1, putc
        li   x12, 78              # 'N'
        jal  x1, putc
        li   x12, 85              # 'U'
        jal  x1, putc
        li   x12, 88              # 'X'
        jal  x1, putc
        li   x12, 10              # '\n'
        jal  x1, putc
        # --- poweroff ---
        li   x14, 0x11100000
        li   x15, 0x5555
        sw   x15, 0(x14)
done:   beq  x0, x0, done
        # --- subrutina putc: espera THRE y escribe x12 en THR ---
putc:   lbu  x13, 0(x11)          # leer LSR (registro de byte, dir no alineada)
        andi x13, x13, 32         # bit 5 = THRE
        beq  x13, x0, putc        # si no listo, reintentar
        sw   x12, 0(x10)          # THR <- caracter
        jalr x0, 0(x1)            # return
