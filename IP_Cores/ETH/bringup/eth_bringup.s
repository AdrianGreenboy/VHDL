# =============================================================================
#  eth_bringup.s  -  Firmware RV32 de bring-up del MAC Ethernet (capa 5).
#  Solo usa el subconjunto de asm.py: addi/add/sub/and/or/xor/sll/srl,
#  mul, lw/sw, beq/bne/blt, jal/jalr, lui, li. SIN la/lbu/.byte.
#
#  Ejecuta el guion del ISS en LOOP_INT y deja la firma de 8 palabras en la
#  RAM local (words 0..7). El verificador del PS la vuelca por DMA a DDR.
#
#  Las direcciones MAC/src se generan byte a byte con seleccion aritmetica
#  (sin tablas en memoria). fbyte(dst_kind, seed, i):
#    i<6   -> dst: kind0 propia[i], kind1 0xFF, kind2 ajena[i]
#    6..11 -> src[i-6]
#    12    -> 0x08     13 -> 0x00
#    i>=14 -> (seed*13 + (i-14)*5 + 9) & 255
#  propia = 02 AA BB CC DD EE ; ajena = 02 99 88 77 66 55 ; src = 0A..0F
#
#  eth_mmio 0xD0000000: 00 CTRL 04 MACLO 08 MACHI 10 STAT 14 TXD 18 RXD
#  MAC propia -> MACLO 0xCCBBAA02 MACHI 0x0000EEDD
# =============================================================================

    lui  x1, 0xD0000         # base MMIO

    li   x16, 0xCCBBAA02
    sw   x16, 4(x1)          # MACLO
    li   x16, 0x0000EEDD
    sw   x16, 8(x1)          # MACHI
    addi x16, x0, 3
    sw   x16, 0(x1)          # CTRL = EN | LOOP

# Trama 0: seed 0 plen 46 dst propia(0)
    addi x4, x0, 0
    addi x5, x0, 46
    addi x20, x0, 0
    jal  x28, send_frame
    jal  x28, read_frame
    sw   x10, 0(x0)
    sw   x13, 4(x0)
    li   x16, 0xFFFFFFFF
    sw   x16, 16(x1)

# Trama 1: seed 1 plen 100 dst propia
    addi x4, x0, 1
    addi x5, x0, 100
    addi x20, x0, 0
    jal  x28, send_frame
    jal  x28, read_frame
    sw   x11, 8(x0)
    sw   x13, 12(x0)
    li   x16, 0xFFFFFFFF
    sw   x16, 16(x1)

# Trama 2: seed 2 plen 46 broadcast(1)
    addi x4, x0, 2
    addi x5, x0, 46
    addi x20, x0, 1
    jal  x28, send_frame
    jal  x28, read_frame
    sw   x12, 16(x0)
    li   x16, 0xFFFFFFFF
    sw   x16, 16(x1)

# Trama 3: seed 3 plen 46 ajena(2) -> descartada
    addi x4, x0, 3
    addi x5, x0, 46
    addi x20, x0, 2
    jal  x28, send_frame
# esperar a que el MAC procese la trama y active RX_DROP (b19), con guard.
# x24 = contador de guarda (~1M ciclos, de sobra para TX+loopback+RX+filtrado)
    lui  x24, 0x100          # guard ~= 1M
t3_wait:
    lw   x15, 16(x1)         # STAT
    srli x16, x15, 19
    andi x16, x16, 1         # RX_DROP
    bne  x16, x0, t3_drop    # llego -> guardar 0xD40D
    addi x24, x24, -1
    bne  x24, x0, t3_wait    # sigue esperando
    addi x17, x0, 0          # timeout: no se filtro (guardar 0)
    jal  x0, t3_st
t3_drop:
    li   x17, 0x0000D40D
t3_st:
    sw   x17, 20(x0)
    li   x16, 0xFFFFFFFF
    sw   x16, 16(x1)

# sig[6] control
    li   x16, 0x4C6D2BDF
    sw   x16, 24(x0)

# Trama 5: seed 5 plen 1500 MTU dst propia
    addi x4, x0, 5
    li   x5, 1500
    addi x20, x0, 0
    jal  x28, send_frame
    jal  x28, read_frame
    sw   x13, 28(x0)
    li   x16, 0xFFFFFFFF
    sw   x16, 16(x1)

# ---- centinela en word 8 (byte 32) ANTES del DMA ----
    li   x16, 0x00C0FFEE
    sw   x16, 32(x0)         # word 8 = centinela

# ---- volcar firma+centinela (words 0..8) a DDR por DMA doorbell ----
# Registros DMA en 0x40000000: 00 SRC, 04 DST, 08 LEN, 0C CTRL(b0 start,b1 dir)
# ddr_addr = ddr_base + dst; el PS fijo ddr_base=0x70000000, dst=0 -> 0x70000000
    lui  x25, 0x40000        # base DMA
    addi x16, x0, 0
    sw   x16, 0(x25)         # SRC = local word 0
    addi x16, x0, 0
    sw   x16, 4(x25)         # DST = DDR offset 0
    addi x16, x0, 9
    sw   x16, 8(x25)         # LEN = 9 palabras (8 firma + centinela)
    addi x16, x0, 3
    sw   x16, 12(x25)        # CTRL = start | dir=1 (local->DDR)
dma_wait:
    lw   x16, 16(x25)        # STATUS: b0 busy pegajoso
    andi x16, x16, 1
    bne  x16, x0, dma_wait

done:
    beq  x0, x0, done

# ---------------------------------------------------------------------------
# send_frame: x4 seed, x5 plen, x20 dst_kind ; ret x28
# x6 i, x7 len, x8 byte, x9 tmp, x21 eof, x23 tmp2
# ---------------------------------------------------------------------------
send_frame:
    addi x7, x5, 14
    addi x6, x0, 0
sf_loop:
    addi x9, x0, 6
    blt  x6, x9, sf_dst
    addi x9, x0, 12
    blt  x6, x9, sf_src
    addi x9, x0, 12
    beq  x6, x9, sf_ty0
    addi x9, x0, 13
    beq  x6, x9, sf_ty1
    jal  x0, sf_pay
sf_dst:
    beq  x20, x0, sf_mine
    addi x9, x0, 1
    beq  x20, x9, sf_bc
    jal  x0, sf_other
sf_mine:
    # propia[i]: 02 AA BB CC DD EE  (selecciona por i)
    li   x23, 0x02
    beq  x6, x0, sf_have
    addi x9, x0, 1
    li   x23, 0xAA
    beq  x6, x9, sf_have
    addi x9, x0, 2
    li   x23, 0xBB
    beq  x6, x9, sf_have
    addi x9, x0, 3
    li   x23, 0xCC
    beq  x6, x9, sf_have
    addi x9, x0, 4
    li   x23, 0xDD
    beq  x6, x9, sf_have
    li   x23, 0xEE            # i==5
    jal  x0, sf_have
sf_bc:
    li   x23, 0xFF
    jal  x0, sf_have
sf_other:
    # ajena[i]: 02 99 88 77 66 55
    li   x23, 0x02
    beq  x6, x0, sf_have
    addi x9, x0, 1
    li   x23, 0x99
    beq  x6, x9, sf_have
    addi x9, x0, 2
    li   x23, 0x88
    beq  x6, x9, sf_have
    addi x9, x0, 3
    li   x23, 0x77
    beq  x6, x9, sf_have
    addi x9, x0, 4
    li   x23, 0x66
    beq  x6, x9, sf_have
    li   x23, 0x55
    jal  x0, sf_have
sf_src:
    # src[i-6]: 0A 0B 0C 0D 0E 0F  = 0x0A + (i-6)
    addi x23, x6, -6
    addi x23, x23, 10
    jal  x0, sf_have
sf_ty0:
    li   x23, 0x08
    jal  x0, sf_have
sf_ty1:
    addi x23, x0, 0
    jal  x0, sf_have
sf_pay:
    addi x9, x0, 13
    mul  x23, x4, x9         # seed*13
    addi x16, x6, -14
    addi x9, x0, 5
    mul  x16, x16, x9        # (i-14)*5
    add  x23, x23, x16
    addi x23, x23, 9
    andi x23, x23, 255
sf_have:
    addi x8, x23, 0          # byte en x8
    addi x9, x7, -1
    addi x21, x0, 0
    bne  x6, x9, sf_noeof
    addi x21, x0, 1
sf_noeof:
    slli x9, x21, 8
    or   x9, x9, x8
    sw   x9, 20(x1)          # TXD
    addi x6, x6, 1
    blt  x6, x7, sf_loop
    jalr x0, 0(x28)

# ---------------------------------------------------------------------------
# read_frame: espera RX_OK, lee RXD hasta EOF ; ret x28
# x10 suma, x11 xor, x12 first, x13 long, x22 first-flag
# ---------------------------------------------------------------------------
read_frame:
rf_wait:
    lw   x15, 16(x1)
    srli x16, x15, 16
    andi x16, x16, 1
    beq  x16, x0, rf_wait
    addi x10, x0, 0
    addi x11, x0, 0
    addi x12, x0, 0
    addi x13, x0, 0
    addi x22, x0, 0
rf_loop:
    lw   x16, 24(x1)
    srli x17, x16, 31
    beq  x17, x0, rf_done
    andi x9, x16, 255
    add  x10, x10, x9
    xor  x11, x11, x9
    bne  x22, x0, rf_nofirst
    addi x12, x9, 0
    addi x22, x0, 1
rf_nofirst:
    addi x13, x13, 1
    srli x17, x16, 8
    andi x17, x17, 1
    bne  x17, x0, rf_done
    jal  x0, rf_loop
rf_done:
    jalr x0, 0(x28)
