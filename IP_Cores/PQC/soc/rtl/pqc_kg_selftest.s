# pqc_probe_vec.s -- KEM KeyGen con la SEMILLA DEL VECTOR ACVP.
# Carga d||z reales, dispara KeyGen, lee ek, FNV-1a 32b, vuelca a DDR.
# FNV esperado del ek del vector: 0x33C532BD
    lui  x1, 0xD0000           # base MMIO PQC
    sw   x0, 0(x1)             # CTRL=0 (KEM)
    sw   x0, 12(x1)          # ADDR = 0
    li   x5, 0xE5
    sw   x5, 16(x1)          # DATA=byte0 (0xE5); ADDR++
    li   x5, 0x82
    sw   x5, 16(x1)          # DATA=byte1 (0x82); ADDR++
    li   x5, 0xB7
    sw   x5, 16(x1)          # DATA=byte2 (0xB7); ADDR++
    li   x5, 0xD7
    sw   x5, 16(x1)          # DATA=byte3 (0xD7); ADDR++
    li   x5, 0x5E
    sw   x5, 16(x1)          # DATA=byte4 (0x5E); ADDR++
    li   x5, 0x6C
    sw   x5, 16(x1)          # DATA=byte5 (0x6C); ADDR++
    li   x5, 0x80
    sw   x5, 16(x1)          # DATA=byte6 (0x80); ADDR++
    li   x5, 0xB0
    sw   x5, 16(x1)          # DATA=byte7 (0xB0); ADDR++
    li   x5, 0x5A
    sw   x5, 16(x1)          # DATA=byte8 (0x5A); ADDR++
    li   x5, 0xE3
    sw   x5, 16(x1)          # DATA=byte9 (0xE3); ADDR++
    li   x5, 0x92
    sw   x5, 16(x1)          # DATA=byte10 (0x92); ADDR++
    li   x5, 0xA1
    sw   x5, 16(x1)          # DATA=byte11 (0xA1); ADDR++
    li   x5, 0xFC
    sw   x5, 16(x1)          # DATA=byte12 (0xFC); ADDR++
    li   x5, 0x9F
    sw   x5, 16(x1)          # DATA=byte13 (0x9F); ADDR++
    li   x5, 0x71
    sw   x5, 16(x1)          # DATA=byte14 (0x71); ADDR++
    li   x5, 0x53
    sw   x5, 16(x1)          # DATA=byte15 (0x53); ADDR++
    li   x5, 0xB1
    sw   x5, 16(x1)          # DATA=byte16 (0xB1); ADDR++
    li   x5, 0x23
    sw   x5, 16(x1)          # DATA=byte17 (0x23); ADDR++
    li   x5, 0x90
    sw   x5, 16(x1)          # DATA=byte18 (0x90); ADDR++
    li   x5, 0xFD
    sw   x5, 16(x1)          # DATA=byte19 (0xFD); ADDR++
    li   x5, 0x99
    sw   x5, 16(x1)          # DATA=byte20 (0x99); ADDR++
    li   x5, 0x93
    sw   x5, 16(x1)          # DATA=byte21 (0x93); ADDR++
    li   x5, 0x03
    sw   x5, 16(x1)          # DATA=byte22 (0x03); ADDR++
    li   x5, 0x68
    sw   x5, 16(x1)          # DATA=byte23 (0x68); ADDR++
    li   x5, 0xCC
    sw   x5, 16(x1)          # DATA=byte24 (0xCC); ADDR++
    li   x5, 0x67
    sw   x5, 16(x1)          # DATA=byte25 (0x67); ADDR++
    li   x5, 0xA7
    sw   x5, 16(x1)          # DATA=byte26 (0xA7); ADDR++
    li   x5, 0x68
    sw   x5, 16(x1)          # DATA=byte27 (0x68); ADDR++
    li   x5, 0xBA
    sw   x5, 16(x1)          # DATA=byte28 (0xBA); ADDR++
    li   x5, 0xEB
    sw   x5, 16(x1)          # DATA=byte29 (0xEB); ADDR++
    li   x5, 0xC8
    sw   x5, 16(x1)          # DATA=byte30 (0xC8); ADDR++
    li   x5, 0xA0
    sw   x5, 16(x1)          # DATA=byte31 (0xA0); ADDR++
    li   x5, 0x1C
    sw   x5, 16(x1)          # DATA=byte32 (0x1C); ADDR++
    li   x5, 0xDA
    sw   x5, 16(x1)          # DATA=byte33 (0xDA); ADDR++
    li   x5, 0xCB
    sw   x5, 16(x1)          # DATA=byte34 (0xCB); ADDR++
    li   x5, 0x87
    sw   x5, 16(x1)          # DATA=byte35 (0x87); ADDR++
    li   x5, 0x40
    sw   x5, 16(x1)          # DATA=byte36 (0x40); ADDR++
    li   x5, 0xC0
    sw   x5, 16(x1)          # DATA=byte37 (0xC0); ADDR++
    li   x5, 0xB8
    sw   x5, 16(x1)          # DATA=byte38 (0xB8); ADDR++
    li   x5, 0x7C
    sw   x5, 16(x1)          # DATA=byte39 (0x7C); ADDR++
    li   x5, 0x4A
    sw   x5, 16(x1)          # DATA=byte40 (0x4A); ADDR++
    li   x5, 0x37
    sw   x5, 16(x1)          # DATA=byte41 (0x37); ADDR++
    li   x5, 0x95
    sw   x5, 16(x1)          # DATA=byte42 (0x95); ADDR++
    li   x5, 0x75
    sw   x5, 16(x1)          # DATA=byte43 (0x75); ADDR++
    li   x5, 0xF1
    sw   x5, 16(x1)          # DATA=byte44 (0xF1); ADDR++
    li   x5, 0x87
    sw   x5, 16(x1)          # DATA=byte45 (0x87); ADDR++
    li   x5, 0xB3
    sw   x5, 16(x1)          # DATA=byte46 (0xB3); ADDR++
    li   x5, 0x67
    sw   x5, 16(x1)          # DATA=byte47 (0x67); ADDR++
    li   x5, 0xCB
    sw   x5, 16(x1)          # DATA=byte48 (0xCB); ADDR++
    li   x5, 0xFA
    sw   x5, 16(x1)          # DATA=byte49 (0xFA); ADDR++
    li   x5, 0x3B
    sw   x5, 16(x1)          # DATA=byte50 (0x3B); ADDR++
    li   x5, 0x30
    sw   x5, 16(x1)          # DATA=byte51 (0x30); ADDR++
    li   x5, 0x0B
    sw   x5, 16(x1)          # DATA=byte52 (0x0B); ADDR++
    li   x5, 0xF5
    sw   x5, 16(x1)          # DATA=byte53 (0xF5); ADDR++
    li   x5, 0x91
    sw   x5, 16(x1)          # DATA=byte54 (0x91); ADDR++
    li   x5, 0xB1
    sw   x5, 16(x1)          # DATA=byte55 (0xB1); ADDR++
    li   x5, 0x09
    sw   x5, 16(x1)          # DATA=byte56 (0x09); ADDR++
    li   x5, 0xF7
    sw   x5, 16(x1)          # DATA=byte57 (0xF7); ADDR++
    li   x5, 0x98
    sw   x5, 16(x1)          # DATA=byte58 (0x98); ADDR++
    li   x5, 0x16
    sw   x5, 16(x1)          # DATA=byte59 (0x16); ADDR++
    li   x5, 0xE9
    sw   x5, 16(x1)          # DATA=byte60 (0xE9); ADDR++
    li   x5, 0xCB
    sw   x5, 16(x1)          # DATA=byte61 (0xCB); ADDR++
    li   x5, 0xE8
    sw   x5, 16(x1)          # DATA=byte62 (0xE8); ADDR++
    li   x5, 0xF0
    sw   x5, 16(x1)          # DATA=byte63 (0xF0); ADDR++
    addi x6, x0, 4
    sw   x6, 4(x1)             # CMD start op=00 (KeyGen)
    lui  x24, 0x800            # guarda ~8M
wkg:
    lw   x7, 8(x1)
    andi x8, x7, 128           # done_sticky b7
    bne  x8, x0, kg_ok
    addi x24, x24, -1
    bne  x24, x0, wkg
    li   x10, 0xDEAD0001
    jal  x0, dump
kg_ok:
    li   x10, 0x811C9DC5       # FNV offset
    li   x14, 0x01000193       # FNV prime
    addi x11, x0, 0
    addi x12, x0, 0
    addi x13, x0, 0
    addi x15, x0, 0
    addi x16, x0, 1184
    addi x17, x0, 512
    sw   x17, 12(x1)          # ADDR=512 (ek)
    lw   x0, 16(x1)           # dummy alinea latencia
ekl:
    lw   x18, 16(x1)          # byte ek
    xor  x10, x10, x18
    mul  x10, x10, x14
    bne  x15, x0, nofirst
    addi x12, x18, 0
nofirst:
    addi x9, x0, 16
    bge  x15, x9, no16
    add  x11, x11, x18
no16:
    addi x13, x18, 0
    addi x15, x15, 1
    blt  x15, x16, ekl
dump:
    sw   x10, 0(x0)           # [0] FNV de ek
    sw   x11, 4(x0)           # [1] suma primeros 16
    sw   x12, 8(x0)           # [2] primer byte
    sw   x13, 12(x0)          # [3] ultimo byte
    li   x16, 0x00C0FFEE
    sw   x16, 32(x0)          # [8] centinela
    lui  x25, 0x40000
    sw   x0, 0(x25)
    sw   x0, 4(x25)
    addi x16, x0, 9
    sw   x16, 8(x25)
    addi x16, x0, 3
    sw   x16, 12(x25)
dwait:
    lw   x16, 16(x25)
    andi x16, x16, 1
    bne  x16, x0, dwait
    addi x20, x0, 1
    sw   x20, 508(x0)         # doorbell
done:
    beq  x0, x0, done
