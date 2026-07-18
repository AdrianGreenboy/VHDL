        # Programa de integracion del top: ejercita cada camino del SoC
        # a traves de AXI real (lectura, escritura, byte-enables, MMIO,
        # CLINT, AMO sobre DDR) y emite marcas por la consola.
        li   x10, 0x10000000      # THR del UART
        li   x11, 0x10000005      # LSR
        # --- A: el core vive y la consola funciona por el FIFO ---
        li   x12, 65
        jal  x1, putc
        # --- B: escritura y lectura de DDR por AXI (palabra) ---
        li   x20, 0x80100000
        li   x21, 0x12345678
        sw   x21, 0(x20)
        lw   x22, 0(x20)
        bne  x21, x22, fallo
        li   x12, 66
        jal  x1, putc
        # --- C: byte-enables (sb/lbu) sobre DDR ---
        li   x23, 0xAB
        sb   x23, 5(x20)
        lbu  x24, 5(x20)
        bne  x23, x24, fallo
        lw   x25, 4(x20)          # el resto de la palabra intacto
        srli x26, x25, 8
        andi x26, x26, 255
        li   x27, 0xAB
        bne  x26, x27, fallo
        li   x12, 67
        jal  x1, putc
        # --- D: media palabra (sh/lhu) ---
        li   x5, 0xBEEF
        sh   x5, 8(x20)
        lhu  x6, 8(x20)
        bne  x5, x6, fallo
        li   x12, 68
        jal  x1, putc
        # --- E: CLINT accesible por el puerto MMIO (mtime avanza) ---
        li   x7, 0x1100BFF8
        lw   x8, 0(x7)
        li   x9, 200
e_wait: addi x9, x9, -1
        bne  x9, x0, e_wait
        lw   x13, 0(x7)
        bltu x8, x13, e_ok        # mtime debe haber avanzado
        jal  x0, fallo
e_ok:   li   x12, 69
        jal  x1, putc
        # --- F: AMO sobre DDR a traves de AXI ---
        li   x14, 0x80100100
        li   x15, 10
        sw   x15, 0(x14)
        li   x16, 5
        amoadd.w x17, x16, (x14)
        bne  x17, x15, fallo      # rd = valor viejo
        lw   x18, 0(x14)
        li   x19, 15
        bne  x18, x19, fallo      # memoria = viejo + operando
        li   x12, 70
        jal  x1, putc
        # --- G: lr/sc sobre DDR ---
        lr.w x28, (x14)
        addi x29, x28, 1
        sc.w x30, x29, (x14)
        bne  x30, x0, fallo       # sc debe triunfar
        lw   x31, 0(x14)
        li   x5, 16
        bne  x31, x5, fallo
        li   x12, 71
        jal  x1, putc
        jal  x0, fin
fallo:  li   x12, 88              # 'X'
        jal  x1, putc
fin:    li   x12, 10
        jal  x1, putc
        li   x6, 0x11100000
        li   x7, 0x5555
        sw   x7, 0(x6)
done:   beq  x0, x0, done
putc:   lbu  x28, 0(x11)
        andi x28, x28, 32
        beq  x28, x0, putc
        sw   x12, 0(x10)
        jalr x0, 0(x1)
