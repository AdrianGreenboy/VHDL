# pqc_selftest_full.s -- self-test PQC completo (KEM+DSA, FNV-64 global)
# Reproduce KEM=95e07091fa5b3cc4  DSA=f93232f7ea2d1575
    lui  x1, 0xD0000          # base MMIO
    li   x12, 0x9FFAAC08      # p4_hi
    li   x13, 0x5635BC91      # p4_lo

# ================= CADENA KEM (alg=0) =================
    sw   x0, 0(x1)            # CTRL=0 KEM
    li   x10, 0xCBF29CE4      # sigk init hi
    li   x11, 0x84222325      # sigk init lo
# cargar semilla d@0, z@32
    li   x5, 0
    sw   x5, 12(x1)          # ADDR
    li   x5, 0xE5
    sw   x5, 16(x1)
    li   x5, 0x82
    sw   x5, 16(x1)
    li   x5, 0xB7
    sw   x5, 16(x1)
    li   x5, 0xD7
    sw   x5, 16(x1)
    li   x5, 0x5E
    sw   x5, 16(x1)
    li   x5, 0x6C
    sw   x5, 16(x1)
    li   x5, 0x80
    sw   x5, 16(x1)
    li   x5, 0xB0
    sw   x5, 16(x1)
    li   x5, 0x5A
    sw   x5, 16(x1)
    li   x5, 0xE3
    sw   x5, 16(x1)
    li   x5, 0x92
    sw   x5, 16(x1)
    li   x5, 0xA1
    sw   x5, 16(x1)
    li   x5, 0xFC
    sw   x5, 16(x1)
    li   x5, 0x9F
    sw   x5, 16(x1)
    li   x5, 0x71
    sw   x5, 16(x1)
    li   x5, 0x53
    sw   x5, 16(x1)
    li   x5, 0xB1
    sw   x5, 16(x1)
    li   x5, 0x23
    sw   x5, 16(x1)
    li   x5, 0x90
    sw   x5, 16(x1)
    li   x5, 0xFD
    sw   x5, 16(x1)
    li   x5, 0x99
    sw   x5, 16(x1)
    li   x5, 0x93
    sw   x5, 16(x1)
    li   x5, 0x03
    sw   x5, 16(x1)
    li   x5, 0x68
    sw   x5, 16(x1)
    li   x5, 0xCC
    sw   x5, 16(x1)
    li   x5, 0x67
    sw   x5, 16(x1)
    li   x5, 0xA7
    sw   x5, 16(x1)
    li   x5, 0x68
    sw   x5, 16(x1)
    li   x5, 0xBA
    sw   x5, 16(x1)
    li   x5, 0xEB
    sw   x5, 16(x1)
    li   x5, 0xC8
    sw   x5, 16(x1)
    li   x5, 0xA0
    sw   x5, 16(x1)
    li   x5, 32
    sw   x5, 12(x1)          # ADDR
    li   x5, 0x1C
    sw   x5, 16(x1)
    li   x5, 0xDA
    sw   x5, 16(x1)
    li   x5, 0xCB
    sw   x5, 16(x1)
    li   x5, 0x87
    sw   x5, 16(x1)
    li   x5, 0x40
    sw   x5, 16(x1)
    li   x5, 0xC0
    sw   x5, 16(x1)
    li   x5, 0xB8
    sw   x5, 16(x1)
    li   x5, 0x7C
    sw   x5, 16(x1)
    li   x5, 0x4A
    sw   x5, 16(x1)
    li   x5, 0x37
    sw   x5, 16(x1)
    li   x5, 0x95
    sw   x5, 16(x1)
    li   x5, 0x75
    sw   x5, 16(x1)
    li   x5, 0xF1
    sw   x5, 16(x1)
    li   x5, 0x87
    sw   x5, 16(x1)
    li   x5, 0xB3
    sw   x5, 16(x1)
    li   x5, 0x67
    sw   x5, 16(x1)
    li   x5, 0xCB
    sw   x5, 16(x1)
    li   x5, 0xFA
    sw   x5, 16(x1)
    li   x5, 0x3B
    sw   x5, 16(x1)
    li   x5, 0x30
    sw   x5, 16(x1)
    li   x5, 0x0B
    sw   x5, 16(x1)
    li   x5, 0xF5
    sw   x5, 16(x1)
    li   x5, 0x91
    sw   x5, 16(x1)
    li   x5, 0xB1
    sw   x5, 16(x1)
    li   x5, 0x09
    sw   x5, 16(x1)
    li   x5, 0xF7
    sw   x5, 16(x1)
    li   x5, 0x98
    sw   x5, 16(x1)
    li   x5, 0x16
    sw   x5, 16(x1)
    li   x5, 0xE9
    sw   x5, 16(x1)
    li   x5, 0xCB
    sw   x5, 16(x1)
    li   x5, 0xE8
    sw   x5, 16(x1)
    li   x5, 0xF0
    sw   x5, 16(x1)
# KeyGen
    addi x5, x0, 4            # op=00 start
    jal  x28, run_op
# fold ek(512,1184), dk(2048,2400)
    li   x14, 512
    li   x15, 1184
    jal  x28, fold_region
    li   x14, 2048
    li   x15, 2400
    jal  x28, fold_region
# park dk: mover 2048->5000 (2400B)
    li   x14, 2048
    li   x22, 5000
    li   x15, 2400
    jal  x28, move_region
# cargar m@0
    li   x5, 0
    sw   x5, 12(x1)          # ADDR
    li   x5, 0xE1
    sw   x5, 16(x1)
    li   x5, 0x33
    sw   x5, 16(x1)
    li   x5, 0x51
    sw   x5, 16(x1)
    li   x5, 0x65
    sw   x5, 16(x1)
    li   x5, 0xBE
    sw   x5, 16(x1)
    li   x5, 0x49
    sw   x5, 16(x1)
    li   x5, 0x3A
    sw   x5, 16(x1)
    li   x5, 0x20
    sw   x5, 16(x1)
    li   x5, 0xA3
    sw   x5, 16(x1)
    li   x5, 0x1D
    sw   x5, 16(x1)
    li   x5, 0xB0
    sw   x5, 16(x1)
    li   x5, 0x89
    sw   x5, 16(x1)
    li   x5, 0x72
    sw   x5, 16(x1)
    li   x5, 0x1A
    sw   x5, 16(x1)
    li   x5, 0x02
    sw   x5, 16(x1)
    li   x5, 0x3E
    sw   x5, 16(x1)
    li   x5, 0x08
    sw   x5, 16(x1)
    li   x5, 0xA4
    sw   x5, 16(x1)
    li   x5, 0x97
    sw   x5, 16(x1)
    li   x5, 0xE6
    sw   x5, 16(x1)
    li   x5, 0xD2
    sw   x5, 16(x1)
    li   x5, 0x05
    sw   x5, 16(x1)
    li   x5, 0xF3
    sw   x5, 16(x1)
    li   x5, 0xD8
    sw   x5, 16(x1)
    li   x5, 0x7E
    sw   x5, 16(x1)
    li   x5, 0x4A
    sw   x5, 16(x1)
    li   x5, 0x69
    sw   x5, 16(x1)
    li   x5, 0x8B
    sw   x5, 16(x1)
    li   x5, 0xE0
    sw   x5, 16(x1)
    li   x5, 0x59
    sw   x5, 16(x1)
    li   x5, 0x87
    sw   x5, 16(x1)
    li   x5, 0x60
    sw   x5, 16(x1)
# Encaps
    addi x5, x0, 5           # op=01 start (b0=1,b2=1)
    jal  x28, run_op
# fold ct(2048,1088), ss(32,32)
    li   x14, 2048
    li   x15, 1088
    jal  x28, fold_region
    li   x14, 32
    li   x15, 32
    jal  x28, fold_region
# mover ct 2048->0 (1088B), restaurar dk 5000->2048 (2400B)
    li   x14, 2048
    li   x22, 0
    li   x15, 1088
    jal  x28, move_region
    li   x14, 5000
    li   x22, 2048
    li   x15, 2400
    jal  x28, move_region
# Decaps
    addi x5, x0, 6           # op=10 start (b1=1,b2=1)
    jal  x28, run_op
# fold Kout(1280,32)
    li   x14, 1280
    li   x15, 32
    jal  x28, fold_region
# guardar sigk en RAM local [0]=hi [1]=lo
    sw   x10, 0(x0)
    sw   x11, 4(x0)

# ================= CADENA DSA (alg=1) =================
    addi x5, x0, 1
    sw   x5, 0(x1)           # CTRL=1 DSA
    li   x10, 0xCBF29CE4     # sigd init hi
    li   x11, 0x84222325     # sigd init lo
# cargar xi@0
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
# KeyGen
    addi x5, x0, 4
    jal  x28, run_op
# fold pk(256,1952), sk(2304,4032)
    li   x14, 256
    li   x15, 1952
    jal  x28, fold_region
    li   x14, 2304
    li   x15, 4032
    jal  x28, fold_region
# mover sk 2304->0 (4032B), guardar pk: mover 256->6144 temporal (1952B)
    li   x14, 2304
    li   x22, 0
    li   x15, 4032
    jal  x28, move_region
    li   x14, 256
    li   x22, 6144          # park pk temporal
    li   x15, 1952
    jal  x28, move_region
# cargar mu@4096
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
# Sign
    addi x5, x0, 5
    jal  x28, run_op
# fold sig(8192,3309)
    li   x14, 8192
    li   x15, 3309
    jal  x28, fold_region
# mover sig 8192->2176 (3309B), pk 6144->0 (1952B), cargar mu@2048
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
# siglen=3309; Verify
    li   x5, 3309
    sw   x5, 20(x1)          # SIGLEN
    addi x5, x0, 6
    jal  x28, run_op
# fold(result=1): foldeamos el byte 1
    xor  x11, x11, x0        # (s_lo ^= 0 primero? no: fold del valor 1)
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
# guardar sigd en RAM local [2]=hi [3]=lo
    sw   x10, 8(x0)
    sw   x11, 12(x0)

# ================= centinela + DMA a DDR =================
    li   x16, 0x00C0FFEE
    sw   x16, 32(x0)         # [8] centinela
    lui  x25, 0x40000
    sw   x0, 0(x25)          # SRC=0
    sw   x0, 4(x25)          # DST=0
    addi x16, x0, 9
    sw   x16, 8(x25)         # LEN=9
    addi x16, x0, 3
    sw   x16, 12(x25)        # CTRL start|dir
dwait:
    lw   x16, 16(x25)
    andi x16, x16, 1
    bne  x16, x0, dwait
    addi x20, x0, 1
    sw   x20, 508(x0)        # doorbell
halt:
    beq  x0, x0, halt

# ================= subrutinas =================

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
