# Firmware autocontenido de verificacion del codec + contadores (sin DMA, sin PS).
# Genera 4 palabras conocidas con el codec, inyecta errores, las corrige, y deja
# CE/DED en RAM local. Verifica el camino completo codec-MMIO + bumps.
        li   x31, 0x80000000
        li   x30, 0
        li   x5, 4
        sw   x5, 72(x31)           # CONTROL=clr_counters
        # --- generar palabra limpia: encode(0xDEADBEEF) ---
        li   x6, 0xDEADBEEF
        sw   x6, 4(x31)            # ENC_IN
        lw   x7, 8(x31)            # ENC_OUT_LO
        lw   x8, 12(x31)           # ENC_OUT_HI
        # inyectar 1-bit: flip bit 7 del LO
        xori x7, x7, 0x80
        # decodificar (debe corregir)
        sw   x7, 16(x31)           # DEC_IN_LO
        sw   x8, 20(x31)           # DEC_IN_HI
        lw   x9, 28(x31)           # DEC_STATUS
        srli x10, x9, 9
        andi x10, x10, 1           # corrected?
        beq  x10, x0, no_ce
        lw   x11, 24(x31)          # DEC_DATA (debe ser 0xDEADBEEF)
        sw   x11, 24(x30)          # RAM[0x18] = dato corregido
        sw   x0, 132(x31)          # CE_BUMP
no_ce:
        # inyectar 2-bit: flip bits 3 y 30 del LO de una palabra limpia nueva
        li   x6, 0x12345678
        sw   x6, 4(x31)            # ENC_IN
        lw   x7, 8(x31)            # ENC_OUT_LO
        lw   x8, 12(x31)           # ENC_OUT_HI
        li   x12, 0x40000008       # bits 3 y 30
        xor  x7, x7, x12
        sw   x7, 16(x31)           # DEC_IN_LO
        sw   x8, 20(x31)           # DEC_IN_HI
        lw   x9, 28(x31)           # DEC_STATUS
        srli x10, x9, 8
        andi x10, x10, 1           # ded?
        beq  x10, x0, no_ded
        sw   x0, 136(x31)          # DED_BUMP
no_ded:
        lw   x1, 88(x31)           # CE_COUNT (esperado 1)
        lw   x2, 92(x31)           # DED_COUNT (esperado 1)
        sw   x1, 16(x30)           # RAM[0x10]
        sw   x2, 20(x30)           # RAM[0x14]
        li   x3, 0xABCD
        sw   x3, 508(x30)
h:      beq  x0, x0, h
