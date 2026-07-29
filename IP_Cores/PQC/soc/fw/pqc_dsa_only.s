# pqc_dsa_only.s -- solo cadena DSA (valida f93232f7ea2d1575)
    lui  x1, 0xD0000
    li   x12, 0x9FFAAC08
    li   x13, 0x5635BC91
    addi x5, x0, 1
    sw   x5, 0(x1)           # CTRL=1 DSA
    li   x10, 0xCBF29CE4
    li   x11, 0x84222325
    li   x5, 0
    sw   x5, 12(x1)          # ADDR
    li   x5, 0xA9
    sw   x5, 16(x1)
    li   x5, 0x91
    sw   x5, 16(x1)
    li   x5, 0xFD
    sw   x5, 16(x1)
    li   x5, 0x42
    sw   x5, 16(x1)
    li   x5, 0xB0
    sw   x5, 16(x1)
    li   x5, 0x71
    sw   x5, 16(x1)
    li   x5, 0xD4
    sw   x5, 16(x1)
    li   x5, 0x9C
    sw   x5, 16(x1)
    li   x5, 0x48
    sw   x5, 16(x1)
    li   x5, 0xAE
    sw   x5, 16(x1)
    li   x5, 0x3E
    sw   x5, 16(x1)
    li   x5, 0x75
    sw   x5, 16(x1)
    li   x5, 0xC6
    sw   x5, 16(x1)
    li   x5, 0x47
    sw   x5, 16(x1)
    li   x5, 0x45
    sw   x5, 16(x1)
    li   x5, 0x9E
    sw   x5, 16(x1)
    li   x5, 0x0D
    sw   x5, 16(x1)
    li   x5, 0xAA
    sw   x5, 16(x1)
    li   x5, 0xD1
    sw   x5, 16(x1)
    li   x5, 0xE1
    sw   x5, 16(x1)
    li   x5, 0xBA
    sw   x5, 16(x1)
    li   x5, 0x35
    sw   x5, 16(x1)
    li   x5, 0x6A
    sw   x5, 16(x1)
    li   x5, 0x04
    sw   x5, 16(x1)
    li   x5, 0x80
    sw   x5, 16(x1)
    li   x5, 0x19
    sw   x5, 16(x1)
    li   x5, 0x12
    sw   x5, 16(x1)
    li   x5, 0xD3
    sw   x5, 16(x1)
    li   x5, 0x29
    sw   x5, 16(x1)
    li   x5, 0x4B
    sw   x5, 16(x1)
    li   x5, 0xCF
    sw   x5, 16(x1)
    li   x5, 0xF8
    sw   x5, 16(x1)
    addi x5, x0, 4
    jal  x28, run_op
    li   x14, 256
    li   x15, 1952
    jal  x28, fold_region
    li   x14, 2304
    li   x15, 4032
    jal  x28, fold_region
    li   x14, 2304
    li   x22, 0
    li   x15, 4032
    jal  x28, move_region
    li   x14, 256
    li   x22, 6144
    li   x15, 1952
    jal  x28, move_region
    li   x5, 4096
    sw   x5, 12(x1)          # ADDR
    li   x5, 0x9F
    sw   x5, 16(x1)
    li   x5, 0x09
    sw   x5, 16(x1)
    li   x5, 0xC1
    sw   x5, 16(x1)
    li   x5, 0xB9
    sw   x5, 16(x1)
    li   x5, 0xAE
    sw   x5, 16(x1)
    li   x5, 0x38
    sw   x5, 16(x1)
    li   x5, 0xCA
    sw   x5, 16(x1)
    li   x5, 0x8D
    sw   x5, 16(x1)
    li   x5, 0x75
    sw   x5, 16(x1)
    li   x5, 0x69
    sw   x5, 16(x1)
    li   x5, 0x08
    sw   x5, 16(x1)
    li   x5, 0xB3
    sw   x5, 16(x1)
    li   x5, 0xE1
    sw   x5, 16(x1)
    li   x5, 0x09
    sw   x5, 16(x1)
    li   x5, 0x9B
    sw   x5, 16(x1)
    li   x5, 0xD3
    sw   x5, 16(x1)
    li   x5, 0x75
    sw   x5, 16(x1)
    li   x5, 0x55
    sw   x5, 16(x1)
    li   x5, 0x7B
    sw   x5, 16(x1)
    li   x5, 0x3E
    sw   x5, 16(x1)
    li   x5, 0x73
    sw   x5, 16(x1)
    li   x5, 0xF4
    sw   x5, 16(x1)
    li   x5, 0x4B
    sw   x5, 16(x1)
    li   x5, 0x52
    sw   x5, 16(x1)
    li   x5, 0xC7
    sw   x5, 16(x1)
    li   x5, 0x76
    sw   x5, 16(x1)
    li   x5, 0x50
    sw   x5, 16(x1)
    li   x5, 0xFF
    sw   x5, 16(x1)
    li   x5, 0xC0
    sw   x5, 16(x1)
    li   x5, 0x2B
    sw   x5, 16(x1)
    li   x5, 0xC6
    sw   x5, 16(x1)
    li   x5, 0x24
    sw   x5, 16(x1)
    li   x5, 0x3F
    sw   x5, 16(x1)
    li   x5, 0x10
    sw   x5, 16(x1)
    li   x5, 0x1E
    sw   x5, 16(x1)
    li   x5, 0x82
    sw   x5, 16(x1)
    li   x5, 0x31
    sw   x5, 16(x1)
    li   x5, 0xD8
    sw   x5, 16(x1)
    li   x5, 0xCE
    sw   x5, 16(x1)
    li   x5, 0xFB
    sw   x5, 16(x1)
    li   x5, 0xC9
    sw   x5, 16(x1)
    li   x5, 0xF8
    sw   x5, 16(x1)
    li   x5, 0x06
    sw   x5, 16(x1)
    li   x5, 0x87
    sw   x5, 16(x1)
    li   x5, 0xB3
    sw   x5, 16(x1)
    li   x5, 0xC3
    sw   x5, 16(x1)
    li   x5, 0xF8
    sw   x5, 16(x1)
    li   x5, 0x96
    sw   x5, 16(x1)
    li   x5, 0xAC
    sw   x5, 16(x1)
    li   x5, 0x81
    sw   x5, 16(x1)
    li   x5, 0x64
    sw   x5, 16(x1)
    li   x5, 0xF3
    sw   x5, 16(x1)
    li   x5, 0xA0
    sw   x5, 16(x1)
    li   x5, 0xE3
    sw   x5, 16(x1)
    li   x5, 0x78
    sw   x5, 16(x1)
    li   x5, 0x5D
    sw   x5, 16(x1)
    li   x5, 0x1F
    sw   x5, 16(x1)
    li   x5, 0xD1
    sw   x5, 16(x1)
    li   x5, 0x2B
    sw   x5, 16(x1)
    li   x5, 0x0C
    sw   x5, 16(x1)
    li   x5, 0x20
    sw   x5, 16(x1)
    li   x5, 0x4B
    sw   x5, 16(x1)
    li   x5, 0xCF
    sw   x5, 16(x1)
    li   x5, 0x0F
    sw   x5, 16(x1)
    addi x5, x0, 5
    jal  x28, run_op
    li   x14, 8192
    li   x15, 3309
    jal  x28, fold_region
    li   x14, 8192
    li   x22, 2176
    li   x15, 3309
    jal  x28, move_region
    li   x14, 6144
    li   x22, 0
    li   x15, 1952
    jal  x28, move_region
    li   x5, 2048
    sw   x5, 12(x1)          # ADDR
    li   x5, 0x9F
    sw   x5, 16(x1)
    li   x5, 0x09
    sw   x5, 16(x1)
    li   x5, 0xC1
    sw   x5, 16(x1)
    li   x5, 0xB9
    sw   x5, 16(x1)
    li   x5, 0xAE
    sw   x5, 16(x1)
    li   x5, 0x38
    sw   x5, 16(x1)
    li   x5, 0xCA
    sw   x5, 16(x1)
    li   x5, 0x8D
    sw   x5, 16(x1)
    li   x5, 0x75
    sw   x5, 16(x1)
    li   x5, 0x69
    sw   x5, 16(x1)
    li   x5, 0x08
    sw   x5, 16(x1)
    li   x5, 0xB3
    sw   x5, 16(x1)
    li   x5, 0xE1
    sw   x5, 16(x1)
    li   x5, 0x09
    sw   x5, 16(x1)
    li   x5, 0x9B
    sw   x5, 16(x1)
    li   x5, 0xD3
    sw   x5, 16(x1)
    li   x5, 0x75
    sw   x5, 16(x1)
    li   x5, 0x55
    sw   x5, 16(x1)
    li   x5, 0x7B
    sw   x5, 16(x1)
    li   x5, 0x3E
    sw   x5, 16(x1)
    li   x5, 0x73
    sw   x5, 16(x1)
    li   x5, 0xF4
    sw   x5, 16(x1)
    li   x5, 0x4B
    sw   x5, 16(x1)
    li   x5, 0x52
    sw   x5, 16(x1)
    li   x5, 0xC7
    sw   x5, 16(x1)
    li   x5, 0x76
    sw   x5, 16(x1)
    li   x5, 0x50
    sw   x5, 16(x1)
    li   x5, 0xFF
    sw   x5, 16(x1)
    li   x5, 0xC0
    sw   x5, 16(x1)
    li   x5, 0x2B
    sw   x5, 16(x1)
    li   x5, 0xC6
    sw   x5, 16(x1)
    li   x5, 0x24
    sw   x5, 16(x1)
    li   x5, 0x3F
    sw   x5, 16(x1)
    li   x5, 0x10
    sw   x5, 16(x1)
    li   x5, 0x1E
    sw   x5, 16(x1)
    li   x5, 0x82
    sw   x5, 16(x1)
    li   x5, 0x31
    sw   x5, 16(x1)
    li   x5, 0xD8
    sw   x5, 16(x1)
    li   x5, 0xCE
    sw   x5, 16(x1)
    li   x5, 0xFB
    sw   x5, 16(x1)
    li   x5, 0xC9
    sw   x5, 16(x1)
    li   x5, 0xF8
    sw   x5, 16(x1)
    li   x5, 0x06
    sw   x5, 16(x1)
    li   x5, 0x87
    sw   x5, 16(x1)
    li   x5, 0xB3
    sw   x5, 16(x1)
    li   x5, 0xC3
    sw   x5, 16(x1)
    li   x5, 0xF8
    sw   x5, 16(x1)
    li   x5, 0x96
    sw   x5, 16(x1)
    li   x5, 0xAC
    sw   x5, 16(x1)
    li   x5, 0x81
    sw   x5, 16(x1)
    li   x5, 0x64
    sw   x5, 16(x1)
    li   x5, 0xF3
    sw   x5, 16(x1)
    li   x5, 0xA0
    sw   x5, 16(x1)
    li   x5, 0xE3
    sw   x5, 16(x1)
    li   x5, 0x78
    sw   x5, 16(x1)
    li   x5, 0x5D
    sw   x5, 16(x1)
    li   x5, 0x1F
    sw   x5, 16(x1)
    li   x5, 0xD1
    sw   x5, 16(x1)
    li   x5, 0x2B
    sw   x5, 16(x1)
    li   x5, 0x0C
    sw   x5, 16(x1)
    li   x5, 0x20
    sw   x5, 16(x1)
    li   x5, 0x4B
    sw   x5, 16(x1)
    li   x5, 0xCF
    sw   x5, 16(x1)
    li   x5, 0x0F
    sw   x5, 16(x1)
    li   x5, 3309
    sw   x5, 20(x1)
    addi x5, x0, 6
    jal  x28, run_op
    addi x17, x0, 1
    xor  x11, x11, x17
    mul   x18, x11, x13
    mulhu x19, x11, x13
    mul   x20, x11, x12
    mul   x21, x10, x13
    add   x19, x19, x20
    add   x19, x19, x21
    addi  x11, x18, 0
    addi  x10, x19, 0
    sw   x10, 8(x0)
    sw   x11, 12(x0)
    li   x16, 0x00C0FFEE
    sw   x16, 32(x0)
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
    sw   x20, 508(x0)
halt:
    beq  x0, x0, halt

# ---- subrutina fold_region: x14=addr, x15=len; foldea len bytes en x10:x11 ----
fold_region:
    sw   x14, 12(x1)          # ADDR = addr
    lw   x0, 16(x1)           # dummy ceba
    addi x16, x0, 0           # k=0
fr_loop:
    lw   x17, 16(x1)          # byte
    xor  x11, x11, x17        # s_lo ^= b
    mul   x18, x11, x13       # ll_lo
    mulhu x19, x11, x13       # ll_hi
    mul   x20, x11, x12       # s_lo*p4_hi (low)
    mul   x21, x10, x13       # s_hi*p4_lo (low)
    add   x19, x19, x20
    add   x19, x19, x21
    addi  x11, x18, 0         # s_lo
    addi  x10, x19, 0         # s_hi
    addi x16, x16, 1
    blt  x16, x15, fr_loop
    jalr x0, 0(x28)           # return


# ---- subrutina move_region: x14=src, x22=dst, x15=len. Copia en el core ----
move_region:
    addi x16, x0, 0           # k=0
mv_loop:
    add  x17, x14, x16        # src+k
    sw   x17, 12(x1)          # ADDR=src+k
    lw   x0, 16(x1)           # dummy ceba
    lw   x18, 16(x1)          # byte leido
    add  x17, x22, x16        # dst+k
    sw   x17, 12(x1)          # ADDR=dst+k
    sw   x18, 16(x1)          # escribe byte
    addi x16, x16, 1
    blt  x16, x15, mv_loop
    jalr x0, 0(x28)           # return


# ---- subrutina run_op: x5=CMD value; dispara y espera done ----
run_op:
    sw   x5, 4(x1)            # CMD
    lui  x23, 0x1000          # guarda grande
ro_wait:
    lw   x6, 8(x1)
    andi x6, x6, 128          # done_sticky b7
    bne  x6, x0, ro_done
    addi x23, x23, -1
    bne  x23, x0, ro_wait
ro_done:
    jalr x0, 0(x28)           # return
