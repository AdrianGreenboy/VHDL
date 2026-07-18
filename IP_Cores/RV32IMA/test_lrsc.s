        li   x10, 0x80000500
        li   x11, 42
        sw   x11, 0(x10)          # mem[0x500] = 42
        # caso 1: lr/sc sin interferencia -> sc EXITO
        lr.w x12, (x10)           # x12 = 42, reserva armada
        addi x13, x0, 100
        sc.w x14, x13, (x10)      # sc: exito, x14=0, mem=100
        # caso 2: lr / store normal / sc -> sc FALLA (reserva rota)
        lr.w x15, (x10)           # x15 = 100, reserva armada
        addi x16, x0, 55
        sw   x16, 0(x10)          # store normal ROMPE la reserva, mem=55
        addi x17, x0, 200
        sc.w x18, x17, (x10)      # sc: FALLA (x18=1), mem sigue 55 (no escribe)
        lw   x19, 0(x10)          # x19 = 55 (el sc fallo, no escribio 200)
        # guardar evidencia
        li   x20, 0x80000510
        sw   x14, 0(x20)          # 0 (exito caso 1)
        sw   x18, 4(x20)          # 1 (fallo caso 2)
        sw   x19, 8(x20)          # 55 (sc fallido no escribio)
        li   x14, 0x11100000
        li   x15, 0x5555
        sw   x15, 0(x14)
done:   beq  x0, x0, done
