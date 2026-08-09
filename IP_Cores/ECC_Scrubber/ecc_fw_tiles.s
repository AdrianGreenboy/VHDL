# =============================================================================
#  ecc_fw_tiles.s - Firmware RV32 de barrido por tiles (Layer 5). Core 20.
#
#  Corrige una region ECC que vive en DDR, procesandola en tiles que caben en la
#  RAM local. Por cada palabra ECC de 64b (2 words 32b: LO,HI) usa el acelerador
#  de codec MMIO para decodificar/corregir, y cuenta CE/DED por auto-incremento.
#
#  Mapa de memoria (dmem del RV32):
#    0x0000_0000  RAM local (config del PS + buffer de tile)
#    0x4000_0000  registros DMA:  SRC(00) DST(04) LEN(08) CTRL(0C) STATUS(10)
#    0x8000_0000  regbank scrubber:
#       codec:  ENC_IN(04) ENC_OUT_LO(08) ENC_OUT_HI(0C)
#               DEC_IN_LO(10) DEC_IN_HI(14) DEC_DATA(18) DEC_STATUS(1C)
#       scrub:  CE_COUNT(58) DED_COUNT(5C) CONTROL(48) CE_BUMP(84) DED_BUMP(88)
#
#  Config del PS en RAM local:
#    [0x00] cfg      bit0 = scrub ON (corregir) / OFF (solo pasar sin corregir)
#    [0x04] n_words  numero de palabras ECC de 64b en la region
#    [0x08] ddr_off  offset de la region en DDR (byte address relativo a ddr_base)
#
#  Buffer de tile en RAM local: a partir de 0x40 (word 16). Tile = 128 palabras
#  ECC = 256 words de 32b. Doorbell: palabra 127 (offset 0x1FC).
#
#  DEC_STATUS: bit6:0 syndrome, bit8 ded, bit9 corrected.
# =============================================================================

        li   x31, 0x80000000        # base scrubber MMIO
        li   x29, 0x40000000        # base registros DMA
        li   x30, 0                 # base RAM local

        # limpiar contadores del scrubber: CONTROL bit2 = clr_counters
        li   x5,  4
        sw   x5,  72(x31)         # CONTROL = clr_counters

        # leer config
        lw   x28, 0(x30)           # cfg
        lw   x27, 4(x30)           # n_words (palabras ECC 64b)
        lw   x26, 8(x30)           # ddr_off

        # constantes de tile
        li   x25, 128              # palabras ECC por tile
        li   x24, 0x40             # base buffer de tile en RAM local (byte off)

        li   x20, 0                # word_idx global (palabra ECC procesada)
tile_loop:
        bge  x20, x27, all_done
        # palabras restantes = n_words - word_idx
        sub  x21, x27, x20
        # tile_words = min(restantes, 128)
        blt  x21, x25, use_rem
        add  x22, x0, x25
        jal  x0, have_tw
use_rem:
        add  x22, x0, x21
have_tw:
        # words32 = tile_words * 2
        slli x23, x22, 1           # x23 = tile_words*2 (words de 32b a mover)

        # --- DMA DDR->local ---
        # SRC = ddr_off + word_idx*8   (cada palabra ECC = 8 bytes)
        slli x6, x20, 3            # word_idx*8
        add  x6, x26, x6          # ddr_off + word_idx*8
        sw   x6,  0(x29)        # DMA SRC
        sw   x24, 4(x29)        # DMA DST = buffer local (byte off 0x40)
        sw   x23, 8(x29)        # DMA LEN = words32
        li   x7,  1               # start(1) | dir=0 (DDR->local)
        sw   x7,  12(x29)        # DMA CTRL
wait_dma1:
        lw   x8,  16(x29)        # DMA STATUS
        andi x8, x8, 1            # bit0 busy
        bne  x8, x0, wait_dma1

        # --- corregir cada palabra del tile con el codec ---
        add  x9,  x30, x24         # ptr = &local[0x40]
        add  x10, x0, x22          # cnt = tile_words
        andi x11, x28, 1          # scrub_on = cfg&1
        beq  x11, x0, skip_correct
corr_loop:
        beq  x10, x0, corr_done
        lw   x12, 0(x9)            # LO
        lw   x13, 4(x9)            # HI
        sw   x12, 16(x31)        # DEC_IN_LO
        sw   x13, 20(x31)        # DEC_IN_HI (dispara decode combinacional)
        lw   x14, 28(x31)        # DEC_STATUS
        # corrected? bit9
        srli x15, x14, 9
        andi x15, x15, 1
        beq  x15, x0, chk_ded
        # CE: leer dato corregido, reencodar, reescribir LO/HI
        lw   x16, 24(x31)        # DEC_DATA (dato corregido)
        sw   x16, 4(x31)        # ENC_IN
        lw   x17, 8(x31)        # ENC_OUT_LO
        lw   x18, 12(x31)        # ENC_OUT_HI
        sw   x17, 0(x9)            # LO corregido
        sw   x18, 4(x9)            # HI corregido
        sw   x0,  132(x31)        # CE_BUMP (auto-incremento)
        jal  x0, next_word
chk_ded:
        # ded? bit8
        srli x15, x14, 8
        andi x15, x15, 1
        beq  x15, x0, next_word
        sw   x0,  136(x31)        # DED_BUMP
next_word:
        addi x9,  x9,  8           # siguiente palabra (LO,HI)
        addi x10, x10, -1
        jal  x0, corr_loop
corr_done:
skip_correct:
        # --- DMA local->DDR (devolver tile corregido) ---
        sw   x24, 0(x29)        # DMA SRC = buffer local
        slli x6, x20, 3
        add  x6, x26, x6
        sw   x6,  4(x29)        # DMA DST = ddr_off + word_idx*8
        sw   x23, 8(x29)        # LEN = words32
        li   x7,  3               # start(1) | dir=1 (local->DDR)
        sw   x7,  12(x29)        # DMA CTRL
wait_dma2:
        lw   x8,  16(x29)
        andi x8, x8, 1
        bne  x8, x0, wait_dma2

        # avanzar
        add  x20, x20, x22         # word_idx += tile_words
        jal  x0, tile_loop

all_done:
        # leer contadores finales y guardarlos en RAM local para el PS
        lw   x1, 88(x31)         # CE_COUNT
        lw   x2, 92(x31)         # DED_COUNT
        sw   x1, 16(x30)         # RAM[0x10] = CE
        sw   x2, 20(x30)         # RAM[0x14] = DED

        # doorbell
        li   x3, 0xABCD
        sw   x3, 508(x30)
halt:   beq  x0, x0, halt
