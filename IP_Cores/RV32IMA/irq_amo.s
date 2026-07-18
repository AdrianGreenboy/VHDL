        # === interrupcion durante AMOs: la atomicidad no debe romperse ===
        li   x10, 0x10000000
        li   x11, 0x10000005
        li   x25, 0x11004000      # mtimecmp_lo
        li   x26, 0x1100BFF8      # mtime_lo
        li   x5, handler
        li   x4, 0x80000000
        add  x5, x5, x4
        csrrw x0, 0x305, x5
        sw   x0, 4(x25)           # mtimecmp_hi <- 0
        # habilitar timer con disparo muy cercano, para que las
        # interrupciones caigan en medio de la rafaga de AMOs
        lw   x6, 0(x26)
        addi x6, x6, 3
        sw   x6, 0(x25)
        li   x7, 128
        csrrs x0, 0x304, x7       # mie.MTIE = 1
        li   x7, 8
        csrrs x0, 0x300, x7       # mstatus.MIE = 1
        # rafaga de AMOs sobre la misma palabra: cada uno debe ser atomico
        li   x13, 0x80000400
        li   x14, 0
        sw   x14, 0(x13)          # mem = 0
        li   x15, 100             # 100 incrementos
        li   x16, 1
bucle:  amoadd.w x17, x16, (x13)  # mem += 1 (atomico)
        addi x15, x15, -1
        bne  x15, x0, bucle
        # verificar: mem debe ser exactamente 100
        lw   x18, 0(x13)
        li   x19, 100
        beq  x18, x19, amo_ok
        li   x12, 70              # 'F' atomicidad rota
        jal  x1, putc
        jal  x0, fin
amo_ok: li   x12, 65              # 'A' = AMOs atomicos con interrupciones
        jal  x1, putc
        # verificar que SI hubo interrupciones durante la rafaga
        beq  x20, x0, sin_irq
        li   x12, 66              # 'B' = hubo interrupciones concurrentes
        jal  x1, putc
        jal  x0, fin
sin_irq: li  x12, 78              # 'N' = no hubo interrupciones (prueba debil)
        jal  x1, putc
fin:    li   x12, 10
        jal  x1, putc
        li   x14, 0x11100000
        li   x15, 0x5555
        sw   x15, 0(x14)
done:   beq  x0, x0, done
putc:   lbu  x28, 0(x11)
        andi x28, x28, 32
        beq  x28, x0, putc
        sw   x12, 0(x10)
        jalr x0, 0(x1)
handler:
        addi x20, x20, 1
        lw   x29, 0(x26)
        li   x30, 0x40
        add  x29, x29, x30
        sw   x29, 0(x25)
        mret
