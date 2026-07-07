# Prueba del puerto maestro AXI: escribe y lee la DDR externa.
# Region alta (bit 31 = 1) -> sale por el maestro AXI a la DDR.
# Region baja -> RAM local de 1 ciclo.
        lui  x1, 0x80000       # x1 = 0x80000000 (base de la DDR)
        addi x2, x0, 42
        sw   x2, 0(x1)         # DDR[0] = 42   (escritura maestra)
        addi x3, x0, 99
        sw   x3, 4(x1)         # DDR[1] = 99
        lw   x4, 0(x1)         # x4 = DDR[0]   (lectura maestra) -> 42
        lw   x5, 4(x1)         # x5 = DDR[1]   -> 99
        add  x6, x4, x5        # x6 = 141
        sw   x6, 8(x1)         # DDR[2] = 141
        sw   x6, 0(x0)         # local[0] = 141 (region baja, 1 ciclo)
halt:   beq  x0, x0, halt
