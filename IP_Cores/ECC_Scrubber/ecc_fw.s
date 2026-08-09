# =============================================================================
#  ecc_fw.s - Firmware RV32 del ECC scrubber (Layer 4). Core 20 HERCOSSNUX.
#
#  Mapa de memoria (dmem del RV32):
#    0x0000_0000  RAM local (stack/datos del firmware)   addr(31)=0
#    0x8000_0000  regbank del scrubber (MMIO)            addr(31)=1
#       +0x00 ID      +0x04 STATUS  +0x08 CONTROL
#       +0x0C REGION_BASE +0x10 REGION_LEN +0x14 PERIOD
#       +0x18 CE_COUNT +0x1C DED_COUNT
#       +0x20 FIRST_ADDR +0x24 FIRST_SYN +0x28 LAST_ADDR +0x2C LAST_SYN
#       +0x30 INJ_ADDR +0x34 INJ_MASK_LO +0x38 INJ_MASK_HI +0x3C INJ_CTRL
#       +0x40 SCRATCH
#    0x8000_1000  ventana de datos: palabra i -> LO=+i*8, HI=+i*8+4
#
#  Config por SCRATCH externo: el bit0 de la palabra de config (cargada por el
#  PS/TB en la RAM local addr 0) elige run A (scrub ON) o run B (scrub OFF).
#  Aqui el firmware SIEMPRE arma las inyecciones; el scrub se corre solo si
#  cfg&1. Para el contraste, el TB corre dos veces con distinto cfg.
#
#  Resultado escrito en RAM local:
#    [0x10] = CE_COUNT
#    [0x14] = DED_COUNT
#    [0x18] = FIRST_SYN
#    [0x1C] = LAST_SYN
#    [0x20] = firma FNV de (region 39b LO||HI por palabra) ++ CE ++ DED
#    doorbell: sw a palabra DONE_WORD (127 -> offset 0x1FC)
#
#  FNV-1a-32: h=0x811C9DC5; por byte: h^=b; h*=0x01000193.
#  Aqui firmamos por PALABRA de 32b (no byte) para simplificar: mezclamos LO y HI
#  como dos words. El oraculo Python replica EXACTA esta variante word-wise.
# =============================================================================

        # --- registros base ---
        li   x31, 0x80000000        # base MMIO scrubber
        li   x30, 0                 # base RAM local

        # --- leer config (RAM local palabra 0) ---
        lw   x29, 0(x30)            # x29 = cfg
        li   x28, 32                # N = REGION_LEN (32 palabras)

        # --- configurar region ---
        sw   x0,  12(x31)         # REGION_BASE = 0
        sw   x28, 16(x31)         # REGION_LEN = 32

        # --- inject inmediato 1-bit en addr 5, bit 7 ---
        li   x5,  5
        sw   x5,  48(x31)         # INJ_ADDR = 5
        li   x6,  0x80             # bit 7
        sw   x6,  52(x31)         # INJ_MASK_LO
        sw   x0,  56(x31)         # INJ_MASK_HI = 0
        li   x7,  3               # arm(1) | mode=inmediato(1<<1)
        sw   x7,  60(x31)         # INJ_CTRL

        # --- inject inmediato 2-bit en addr 12 (DED) ---
        li   x5,  12
        sw   x5,  48(x31)
        li   x6,  0x40000008       # bits 3 y 30
        sw   x6,  52(x31)
        sw   x0,  56(x31)
        li   x7,  3
        sw   x7,  60(x31)

        # --- inject on-read 1-bit en addr 20, bit 34 (usa MASK_HI) ---
        li   x5,  20
        sw   x5,  48(x31)
        sw   x0,  52(x31)
        li   x6,  4               # bit (34-32)=2 -> 1<<2 = 4
        sw   x6,  56(x31)
        li   x7,  1               # arm(1) | mode=on-read(0)
        sw   x7,  60(x31)

        # --- correr scrub solo si cfg&1 ---
        andi x8, x29, 1
        beq  x8, x0, skip_scrub
        li   x9,  1
        sw   x9,  8(x31)        # CONTROL.scrub_en = 1
        # esperar done: poll STATUS bit1
wait_done:
        lw   x10, 4(x31)        # STATUS
        andi x11, x10, 2          # bit1 = done
        beq  x11, x0, wait_done
skip_scrub:

        # --- leer contadores y sticky ---
        lw   x12, 24(x31)        # CE_COUNT
        lw   x13, 28(x31)        # DED_COUNT
        lw   x14, 36(x31)        # FIRST_SYN
        lw   x15, 44(x31)        # LAST_SYN
        sw   x12, 16(x30)        # RAM[0x10] = CE
        sw   x13, 20(x30)        # RAM[0x14] = DED
        sw   x14, 24(x30)        # RAM[0x18] = FIRST_SYN
        sw   x15, 28(x30)        # RAM[0x1C] = LAST_SYN

        # --- firmar la region: FNV word-wise sobre LO,HI de cada palabra ---
        li   x16, 0x811C9DC5      # h = FNV offset basis
        li   x17, 0x01000193      # FNV prime
        li   x18, 0                # i = 0
        li   x19, 0x80001000      # base ventana de datos
fnv_loop:
        bge  x18, x28, fnv_done
        slli x20, x18, 3          # i*8
        add  x21, x19, x20        # &LO
        lw   x22, 0(x21)          # LO (bits 31:0)
        lw   x23, 4(x21)          # HI (bits 38:32)
        # h = (h ^ LO) * prime
        xor  x16, x16, x22
        mul  x16, x16, x17
        # h = (h ^ HI) * prime
        xor  x16, x16, x23
        mul  x16, x16, x17
        addi x18, x18, 1
        jal  x0, fnv_loop
fnv_done:
        # mezclar CE y DED en la firma (word-wise)
        xor  x16, x16, x12
        mul  x16, x16, x17
        xor  x16, x16, x13
        mul  x16, x16, x17
        sw   x16, 32(x30)        # RAM[0x20] = firma

        # --- doorbell: palabra 127 (offset 0x1FC) ---
        li   x24, 0xABCD
        sw   x24, 508(x30)

done:   beq  x0, x0, done
