        li   x10, 0x80000400
        li   x11, 0xAABBCCDD
        sw   x11, 0(x10)          # palabra base
        # sb en los 4 lanes de 0x410
        li   x12, 0x80000410
        addi x13, x0, 0x11
        sb   x13, 0(x12)          # lane 0
        addi x14, x0, 0x22
        sb   x14, 1(x12)          # lane 1
        addi x15, x0, 0x33
        sb   x15, 2(x12)          # lane 2
        addi x16, x0, 0x44
        sb   x16, 3(x12)          # lane 3
        lw   x17, 0(x12)          # x17 = 0x44332211
        # sh en los 2 lanes de 0x420
        li   x18, 0x80000420
        li   x19, 0x5566
        sh   x19, 0(x18)          # lanes 0-1
        li   x20, 0x7788
        sh   x20, 2(x18)          # lanes 2-3
        lw   x21, 0(x18)          # x21 = 0x77885566
        # lb/lbu/lh/lhu de los lanes
        lb   x22, 3(x12)          # x22 = 0x44 (sign-ext)
        lbu  x23, 2(x12)          # x23 = 0x33
        lh   x24, 2(x18)          # x24 = 0x7788 (sign-ext -> 0xFFFF7788)
        lhu  x25, 0(x18)          # x25 = 0x5566
        # guardar resultados para comparar
        li   x26, 0x80000430
        sw   x17, 0(x26)
        sw   x21, 4(x26)
        sw   x22, 8(x26)
        sw   x24, 12(x26)
        li   x14, 0x11100000
        li   x15, 0x5555
        sw   x15, 0(x14)
done:   beq  x0, x0, done
