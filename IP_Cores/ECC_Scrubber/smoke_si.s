        li   x31, 0x80000040        # base scrubber (ID en 0x40)
        lw   x1,  0(x31)            # leer ID -> debe ser 0x5C520020
        li   x30, 0
        sw   x1,  16(x30)           # RAM[0x10] = ID leido
        li   x2,  0xABCD
        sw   x2,  508(x30)          # doorbell palabra 127
d:      beq  x0, x0, d
