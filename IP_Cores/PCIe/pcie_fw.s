# ============================================================================
# pcie_fw.s -- PCIE IP v1, firmware de bring-up (Layer 5, SoC real)
#
# Conduce el periferico PCIe desde el RV32IM y vuelca una FIRMA a DDR via el
# patron DMA doorbell (validado en dsp_id_hw.s). En el SoC real la region 0x7
# NO existe: las escrituras a DDR se hacen escribiendo en RAM LOCAL (offsets
# desde x0) y luego un DMA local->DDR (base 0x4000_0000).
#
# Layout en RAM local (palabras):
#   word[0] = link_up
#   word[1] = mwr_cnt
#   word[2] = bar0_last
#   word[3] = cpld_b0
#   word[4] = mrd_data
#   word[5] = marcador 0x0C0FFEE0
#   word[8] = STATUS RC (diagnostico)
#   word[9] = STATUS EP (diagnostico)
#   word[10]= STATUS RC final (diagnostico)
# DMA: src=0, dst=0, len=11 -> DDR[0..10] en 0x70000000..0x70000028
#
# Mapa MMIO PCIe (base 0x80000000): 0x00 CONTROL 0x04 STATUS 0x10 TX_DATA
#   0x18 RX_DATA 0x1C RX_CTRL 0x20 BAR0_LAST 0x24 MWR_CNT ; EP en +0x100
# Mapa DMA (base 0x40000000): 0x00 src 0x04 dst 0x08 len 0x0C CTRL 0x10 STATUS
#   CTRL: bit0=start bit1=dir(1=local->DDR) => 3 ; STATUS bit0=busy
#
# Registros:
#   x5 = base MMIO PCIe (0x80000000)
#   x9 = puntero de escritura en RAM LOCAL (byte offset desde 0)
# ============================================================================

_start:
    lui   x5, 0x80000          # base MMIO PCIe
    addi  x9, x0, 0            # puntero de firma en RAM LOCAL (offset 0)

    # ===== 0) arrancar el EP (banco addr(8)=1 -> offset 0x100) =====
    addi  x7, x0, 9
    lui   x8, 0x80000
    addi  x8, x8, 0x100
    sw    x7, 0(x8)            # CONTROL_EP = 0x9

    # ===== 1) habilitar y entrenar el RC: CONTROL = 0x9 =====
    addi  x7, x0, 9
    sw    x7, 0(x5)            # CONTROL_RC = 0x9

    # --- DIAGNOSTICO: STATUS RC/EP -> RAM local word[8]/word[9] ---
    lw    x10, 4(x5)           # STATUS RC
    sw    x10, 32(x0)          # local word[8]
    lui   x8, 0x80000
    addi  x8, x8, 0x100
    lw    x10, 4(x8)           # STATUS EP
    sw    x10, 36(x0)          # local word[9]

    # esperar link_up (contador limitado)
    lui   x8, 0x01000
wait_link:
    lw    x10, 4(x5)
    andi  x10, x10, 1
    addi  x8, x8, -1
    beq   x8, x0, link_giveup
    beq   x10, x0, wait_link
    jal   x0, link_ok
link_giveup:
    lw    x10, 4(x5)
    sw    x10, 40(x0)          # local word[10] = STATUS RC final
link_ok:
    # word[0] = link_up
    sw    x10, 0(x9)
    addi  x9, x9, 4

    # ===== 2) MWr3 de 4 DW a BAR0 (28 bytes) =====
    addi  x7, x0, 0x40
    sw    x7, 16(x5)
    addi  x7, x0, 0x00
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    addi  x7, x0, 0x04
    sw    x7, 16(x5)
    addi  x7, x0, 0x00
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    addi  x7, x0, 0x04
    sw    x7, 16(x5)
    addi  x7, x0, 0x00
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    # payload 0x11 x4
    addi  x7, x0, 0x11
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    # 0x22 x4
    addi  x7, x0, 0x22
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    # 0x33 x4
    addi  x7, x0, 0x33
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    # 0x44 x3 + last(bit8)
    addi  x7, x0, 0x44
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    addi  x7, x0, 0x144
    sw    x7, 16(x5)

    # base del EP para leer sus contadores (recibe el MWr)
    lui   x13, 0x80000
    addi  x13, x13, 0x100
wait_mwr:
    lw    x10, 36(x13)         # MWR_CNT del EP (0x80000124)
    addi  x8, x0, 4
    blt   x10, x8, wait_mwr
    # word[1] = mwr_cnt
    sw    x10, 0(x9)
    addi  x9, x9, 4
    # word[2] = bar0_last del EP (0x80000120)
    lw    x10, 32(x13)
    sw    x10, 0(x9)
    addi  x9, x9, 4

    # ===== 3) MRd3 addr 8 -> CplD =====
    addi  x7, x0, 0x00
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    addi  x7, x0, 0x01
    sw    x7, 16(x5)
    addi  x7, x0, 0x00
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    addi  x7, x0, 0x05
    sw    x7, 16(x5)
    addi  x7, x0, 0x00
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    addi  x7, x0, 0x108
    sw    x7, 16(x5)

wait_cpld:
    lw    x10, 28(x5)          # RX_CTRL
    srli  x10, x10, 8
    andi  x10, x10, 0xFF
    addi  x8, x0, 16
    blt   x10, x8, wait_cpld

    addi  x8, x0, 40
    addi  x11, x0, 0
find_cpld:
    lw    x10, 24(x5)          # RX_DATA
    addi  x12, x0, 0x4A
    beq   x10, x12, got_cpld
    addi  x8, x8, -1
    blt   x0, x8, find_cpld
    # no encontrado: word[3]=0, word[4]=0
    sw    x0, 0(x9)
    addi  x9, x9, 4
    sw    x0, 0(x9)
    addi  x9, x9, 4
    jal   x0, dma_doorbell
got_cpld:
    # word[3] = 0x4A
    addi  x10, x0, 0x4A
    sw    x10, 0(x9)
    addi  x9, x9, 4
    addi  x8, x0, 11
skip11:
    lw    x7, 24(x5)
    addi  x8, x8, -1
    blt   x0, x8, skip11
    lw    x10, 24(x5)
    slli  x10, x10, 24
    lw    x7, 24(x5)
    slli  x7, x7, 16
    or    x10, x10, x7
    lw    x7, 24(x5)
    slli  x7, x7, 8
    or    x10, x10, x7
    lw    x7, 24(x5)
    or    x10, x10, x7
    # word[4] = mrd_data
    sw    x10, 0(x9)
    addi  x9, x9, 4

dma_doorbell:
    # word[5] = marcador 0x0C0FFEE0 en RAM local
    lui   x7, 0x0C100          # 0x0C100000
    addi  x7, x7, -0x120       # 0x0C0FFEE0 (0x0C100000 - 0x120)
    sw    x7, 20(x0)          # local word[5] = marcador

    # ===== DMA local->DDR: copiar word[0..10] (11 palabras) =====
    lui   x1, 0x40000         # base registros DMA
    addi  x2, x0, 0
    sw    x2, 0(x1)           # src = 0 (RAM local, byte 0)
    addi  x3, x0, 0
    sw    x3, 4(x1)           # dst = 0 (offset DDR -> ddr_base = 0x70000000)
    addi  x4, x0, 11
    sw    x4, 8(x1)           # len = 11 palabras
    addi  x8, x0, 3
    sw    x8, 12(x1)          # CTRL = start|dir(local->DDR) = 3
polld:
    lw    x9, 16(x1)
    bne   x9, x0, polld       # esperar busy=0

halt:
    jal   x0, halt
