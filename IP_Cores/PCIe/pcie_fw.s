# ============================================================================
# pcie_fw.s -- PCIE IP v1, firmware de bring-up (Layer 4)
#
# Conduce el periferico PCIe desde el RV32IM y vuelca una FIRMA de 5 palabras a
# DDR (0x70000000) por el patron DMA doorbell. La firma debe coincidir
# bit-identica con el oraculo pcie_iss.py:
#   sig[0] link_up    = 0x00000001
#   sig[1] mwr_cnt    = 0x00000004
#   sig[2] bar0_last  = 0x44444444
#   sig[3] cpld_b0    = 0x0000004A
#   sig[4] mrd_data   = 0x33333333
#
# Restricciones del ensamblador (~/rv32i/asm.py):
#   - RV32I: constantes de 32 bits con lui+addi (sin 'la')
#   - lw/sw unicamente (sin lbu/.byte)
#   - jalr rd, N(rs1)
#   - lui carga imm<<12
#
# Mapa MMIO (base 0x80000000, offset de byte):
#   0x00 CONTROL  0x04 STATUS   0x10 TX_DATA  0x18 RX_DATA  0x1C RX_CTRL
#   0x20 BAR0_LAST 0x24 MWR_CNT
#
# NOTA: este firmware asume que el EP se arranca por su propio camino (en el SoC
# real, el otro extremo del enlace). El bring-up del RC es lo que se codifica.
# ============================================================================

# ---- convencion de registros ----
#   x5  (t0) = base MMIO (0x80000000)
#   x6  (t1) = base DDR firma (0x70000000)
#   x7  (t2) = temporal
#   x8  (s0) = temporal / contador
#   x9  (s1) = puntero de escritura de firma en DDR
#   x10 (a0) = valor leido / a escribir

_start:
    # t0 = 0x80000000 (base MMIO). lui carga imm<<12: 0x80000<<12 = 0x80000000
    lui   x5, 0x80000
    # t1 = 0x70000000 (base DDR)
    lui   x6, 0x70000
    # s1 = t1 (puntero de firma)
    addi  x9, x6, 0

    # ===== 1) habilitar y entrenar: CONTROL = 0x9 (start|en) =====
    addi  x7, x0, 9
    sw    x7, 0(x5)              # MMIO[0x00] = 0x9

wait_link:
    lw    x10, 4(x5)            # STATUS
    andi  x10, x10, 1          # link_up = bit0
    beq   x10, x0, wait_link    # repetir hasta link_up=1
    # firma[0] = link_up (1)
    sw    x10, 0(x9)
    addi  x9, x9, 4

    # ===== 2) MWr3 de 4 DW a BAR0 (28 bytes) =====
    # header: 40 00 00 04 | 00 00 04 00 | 00 00 00 00
    # payload: 11x4 22x4 33x4 44x4
    # cada byte se escribe en TX_DATA (0x10); el ULTIMO lleva bit8=1 (0x100)

    # --- header ---
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

    # --- payload 0x11 x4 ---
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
    # 0x44 x3 + ultimo con bit8 (last)
    addi  x7, x0, 0x44
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    sw    x7, 16(x5)
    # ultimo byte: 0x44 | 0x100 = 0x144
    addi  x7, x0, 0x144
    sw    x7, 16(x5)

    # esperar mwr_cnt >= 4 (leido del EP; en el SoC real es el banco del EP.
    # aqui, para el modelo de firmware unico, se lee MWR_CNT del periferico)
wait_mwr:
    lw    x10, 36(x5)          # MWR_CNT (0x24)
    addi  x8, x0, 4
    blt   x10, x8, wait_mwr
    # firma[1] = mwr_cnt
    sw    x10, 0(x9)
    addi  x9, x9, 4
    # firma[2] = bar0_last (0x20)
    lw    x10, 32(x5)
    sw    x10, 0(x9)
    addi  x9, x9, 4

    # ===== 3) MRd3 addr 8 (12 bytes) -> CplD =====
    # header: 00 00 00 01 | 00 00 05 00 | 00 00 00 08 (last)
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
    # ultimo: 0x08 | 0x100 = 0x108
    addi  x7, x0, 0x108
    sw    x7, 16(x5)

    # esperar CplD en FIFO RX (RX_CTRL.level >= 16, bits[15:8])
wait_cpld:
    lw    x10, 28(x5)          # RX_CTRL (0x1C)
    srli  x10, x10, 8          # level a bits bajos
    andi  x10, x10, 0xFF
    addi  x8, x0, 16
    blt   x10, x8, wait_cpld

    # drenar y localizar el CplD (byte 0x4A). Leemos hasta 33 bytes buscando 4A.
    # x8 = contador de bytes restantes; x11 = flag encontrado
    addi  x8, x0, 40            # tope de lectura
    addi  x11, x0, 0           # indice
    # buscamos 0x4A; al hallarlo, los 4 bytes en +12 son el dato
find_cpld:
    lw    x10, 24(x5)          # RX_DATA (0x18) -- auto-avanza
    addi  x12, x0, 0x4A
    beq   x10, x12, got_cpld
    addi  x8, x8, -1
    blt   x0, x8, find_cpld
    # no encontrado: firma[3]=0, firma[4]=0
    sw    x0, 0(x9)
    addi  x9, x9, 4
    sw    x0, 0(x9)
    addi  x9, x9, 4
    jal   x0, dma_doorbell

got_cpld:
    # firma[3] = 0x4A
    addi  x10, x0, 0x4A
    sw    x10, 0(x9)
    addi  x9, x9, 4
    # saltar 11 bytes (posiciones 1..11) para llegar al dato (bytes 12..15)
    addi  x8, x0, 11
skip11:
    lw    x7, 24(x5)           # descartar
    addi  x8, x8, -1
    blt   x0, x8, skip11
    # leer 4 bytes del dato y ensamblar big-endian
    lw    x10, 24(x5)          # byte 12 (MSB)
    slli  x10, x10, 24
    lw    x7, 24(x5)           # byte 13
    slli  x7, x7, 16
    or    x10, x10, x7
    lw    x7, 24(x5)           # byte 14
    slli  x7, x7, 8
    or    x10, x10, x7
    lw    x7, 24(x5)           # byte 15 (LSB)
    or    x10, x10, x7
    # firma[4] = dato del CplD
    sw    x10, 0(x9)
    addi  x9, x9, 4

dma_doorbell:
    # ===== DMA doorbell: la firma ya esta en DDR (0x70000000..+20).
    # El PS la lee tras el doorbell. Aqui el firmware senaliza fin escribiendo
    # un marcador en 0x70000014 (tras las 5 palabras).
    lui   x7, 0x0C0FF          # marcador 0x0C0FFEE0 -> valor de "hecho"
    addi  x7, x7, 0x2E0        # (patron arbitrario reconocible)
    sw    x7, 20(x6)           # DDR[0x70000014] = marcador fin

halt:
    jal   x0, halt             # bucle infinito (core detenido logicamente)
