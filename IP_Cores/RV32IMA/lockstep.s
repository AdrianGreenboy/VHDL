        # --- IM: aritmetica basica ---
        addi x1,  x0, 6
        addi x2,  x0, 7
        mul  x3,  x1, x2          # x3 = 42
        addi x4,  x0, 100
        divu x5,  x4, x1          # x5 = 16
        rem  x6,  x4, x1          # x6 = 4
        sub  x7,  x2, x1          # x7 = 1
        # --- cobertura extension M completa ---
        addi x16, x0, -100        # x16 = -100
        addi x17, x0, 7           # x17 = 7
        div  x18, x16, x17        # x18 = -100/7 = -14 (signed)
        rem  x19, x16, x17        # x19 = -100 rem 7 = -2 (signed)
        remu x28, x4,  x1         # x28 = 100 remu 6 = 4
        mulh x29, x16, x17        # x29 = alta de (-100)*7 signed
        mulhu x30, x4, x1         # x30 = alta de 100*6 unsigned = 0
        # --- loop con branch ---
        addi x10, x0, 0
        addi x11, x0, 1
        addi x12, x0, 6
loop:   add  x10, x10, x11        # acc += i
        addi x11, x11, 1
        blt  x11, x12, loop       # acc = 15
        # --- base de datos en DDR: x13 = 0x80000200 ---
        lui  x13, 0x80000
        addi x13, x13, 512        # x13 = 0x80000200
        # --- store/load ---
        sw   x3,  0(x13)          # mem[0x200] = 42
        lw   x14, 0(x13)          # x14 = 42
        # --- extension A: AMOs sobre 0x80000210 ---
        addi x20, x13, 16         # x20 = 0x80000210
        addi x21, x0, 100
        sw   x21, 0(x20)          # mem[0x210] = 100
        lr.w x22, (x20)           # x22 = 100 (reserva)
        addi x23, x0, 5
        sc.w x24, x23, (x20)      # mem[0x210] = 5, x24 = 0 (exito)
        addi x25, x0, 10
        amoadd.w x26, x25, (x20)  # x26 = 5 (viejo), mem = 15
        addi x27, x0, 3
        amoswap.w x28, x27, (x20) # x28 = 15 (viejo), mem = 3
        addi x29, x0, 6
        amoor.w  x30, x29, (x20)  # x30 = 3 (viejo), mem = 7
        addi x31, x0, 12
        amoand.w x5,  x31, (x20)  # x5 = 7 (viejo), mem = 4
        addi x6,  x0, 1
        amoxor.w x7,  x6,  (x20)  # x7 = 4 (viejo), mem = 5
        addi x8,  x0, 2
        amomin.w x9,  x8,  (x20)  # x9 = 5 (viejo), mem = 2
        addi x1,  x0, 99
        amomax.w x2,  x1,  (x20)  # x2 = 2 (viejo), mem = 99
        # --- guardar resultado final del AMO en 0x80000220 ---
        addi x3, x13, 32          # x3 = 0x80000220
        lw   x4, 0(x20)           # x4 = 99 (mem final)
        sw   x4, 0(x3)            # mem[0x220] = 99
        # --- POWEROFF via syscon 0x11100000 <- 0x5555 ---
        li   x14, 0x11100000
        li   x15, 0x5555
        sw   x15, 0(x14)          # POWEROFF
done:   beq  x0, x0, done        # por si acaso
