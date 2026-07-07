# Prueba de interrupcion de timer (CLINT)
        li   x5, handler         # x5 = direccion del manejador
        csrw mtvec, x5           # mtvec = handler

        li   x4, 0x02004000      # &mtimecmp (low)
        addi x6, x0, 30
        sw   x6, 0(x4)           # mtimecmp_low = 30
        li   x7, 0x02004004      # &mtimecmp (high)
        sw   x0, 0(x7)           # mtimecmp_high = 0

        addi x8, x0, 0x80        # bit 7 = MTIE
        csrw mie, x8             # habilita interrupcion de timer
        addi x9, x0, 0x8         # bit 3 = MIE
        csrw mstatus, x9         # habilita interrupciones globales

        addi x20, x0, 0          # contador de loop
        addi x21, x0, 0          # sentinela (0 hasta que el handler corra)
        addi x22, x0, 200        # limite
loop:
        addi x20, x20, 1         # trabajo del programa principal
        blt  x20, x22, loop      # 200 iteraciones (el irq ocurre en el camino)
        beq  x0, x0, done

handler:
        csrr x28, mcause         # x28 = 0x80000007 (interrupcion de timer)
        li   x21, 0xABCD         # sentinela: el handler corrio
        li   x4, 0x02004000
        li   x6, 0xFFFFFFFF
        sw   x6, 0(x4)           # mtimecmp muy grande -> desactiva el timer
        mret                     # retorna al programa principal

done:
        beq  x0, x0, done        # loop infinito
