        # stub de arranque: replica el estado inicial de mini-rv32ima
        # (a0 = hartid = 0, a1 = direccion fisica del DTB) y salta al kernel
        li   x10, 0
        li   x11, 0x83FFF940
        li   x5, 0x80000000
        jalr x0, 0(x5)
