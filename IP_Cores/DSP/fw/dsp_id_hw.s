# =============================================================================
# dsp_id_hw.s  -  Bring-up Fase A: leer ID del IP DSP y mandarlo a DDR.
#
# Prueba la cadena completa de bring-up con la operacion mas trivial:
#   1. lee ID del DSP (base 0x9000_0000, offset 0x00) -> debe ser 0xD5B10100
#   2. escribe firma [centinela, ID] en RAM local (offsets 0 y 4)
#   3. DMA local->DDR (dst=ddr_base+0), LEN=2 palabras
#   4. doorbell (palabra 127) -> IRQ PL->PS
#   5. halt
#
# Mapa DMA (base 0x4000_0000): 0x00=src 0x04=dst 0x08=len 0x0C=CTRL 0x10=STATUS
#   CTRL (w): bit0=start, bit1=dir (0=DDR->local, 1=local->DDR). local->DDR => 3
#   STATUS (r): bit0=busy (pegajoso hasta fin de transferencia)
# Doorbell: sw a palabra 127 (offset 508) de RAM local.
# asm.py: sin la/lbu/.byte; direcciones con lui+addi (lui pre-shift 12).
#
# Layout en RAM local:
#   word[0] = 0xD1A6C0DE  (centinela)
#   word[1] = ID leido
# =============================================================================

# --- leer ID del DSP ---
        lui  x5, 0x90000        # x5 = 0x9000_0000 (base DSP)
        lw   x6, 0(x5)          # x6 = ID (offset 0x00)

# --- escribir centinela + ID en RAM local ---
        lui  x7, 0xD1A6C        # x7 = 0xD1A6C000
        addi x7, x7, 0x0DE      # x7 = 0xD1A6C0DE  (centinela)
        sw   x7, 0(x0)          # RAM local word[0] = centinela
        sw   x6, 4(x0)          # RAM local word[1] = ID

# --- programar DMA local->DDR ---
        lui  x1, 0x40000        # x1 = base registros DMA (0x4000_0000)
        addi x2, x0, 0
        sw   x2, 0(x1)          # src = 0 (indice local, byte 0)
        addi x3, x0, 0
        sw   x3, 4(x1)          # dst = 0 (offset en DDR, byte 0 -> ddr_base)
        addi x4, x0, 2
        sw   x4, 8(x1)          # len = 2 palabras
        addi x8, x0, 3
        sw   x8, 12(x1)         # CTRL: bit0=start + bit1=dir(local->DDR) = 3
polld:  lw   x9, 16(x1)
        bne  x9, x0, polld      # esperar busy=0 (STATUS 0x10)

# --- doorbell ---
        addi x10, x0, 1
        sw   x10, 508(x0)       # palabra 127 -> IRQ PL->PS

halt:   beq  x0, x0, halt
