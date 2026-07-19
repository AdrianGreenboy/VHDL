        # Test dirigido del bug de MUL con producto negativo.
        # 0xAF * 0xCCCCCCCD = 0x0000008C00000023 -> MUL debe dar 0x00000023.
        # Con resize() sobre signed el bit 31 quedaba a '1' (0x80000023).
        # Este caso lo genera el kernel real en la division por constante
        # de printf, y bloqueaba el boot.
        li   x10, 0x10000000
        li   x11, 0x10000005
        # --- A: el caso exacto del kernel ---
        li   x5, 0xAF
        li   x6, 0xCCCCCCCD
        mul  x7, x5, x6
        li   x8, 0x23
        bne  x7, x8, fallo
        li   x12, 65
        jal  x1, putc
        # --- B: MUL negativo x positivo ---
        li   x5, -7
        li   x6, 3
        mul  x7, x5, x6
        li   x8, -21
        bne  x7, x8, fallo
        li   x12, 66
        jal  x1, putc
        # --- C: MULH con producto positivo grande ---
        li   x5, -3
        li   x6, 0xA0000000
        mulh x7, x5, x6
        li   x8, 1
        bne  x7, x8, fallo
        li   x12, 67
        jal  x1, putc
        # --- D: MULHU maximo ---
        li   x5, 0xFFFFFFFF
        li   x6, 0xFFFFFFFF
        mulhu x7, x5, x6
        li   x8, 0xFFFFFFFE
        bne  x7, x8, fallo
        li   x12, 68
        jal  x1, putc
        # --- E: MULHSU ---
        li   x5, -1
        li   x6, 0xFFFFFFFF
        mulhsu x7, x5, x6
        li   x8, 0xFFFFFFFF
        bne  x7, x8, fallo
        li   x12, 69
        jal  x1, putc
        jal  x0, fin
fallo:  li   x12, 88
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
