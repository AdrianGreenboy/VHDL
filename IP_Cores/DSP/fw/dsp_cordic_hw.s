# =============================================================================
# dsp_cordic_hw.s  -  Bring-up Fase B: CORDIC rotacion en silicio.
#
# Secuencia (de dsp_soc_prog.txt):
#   CORDA(0x14) = 0x2000        angulo
#   CTRL(0x04)  = 0x07          START|FUNC=CROT (0b011<<1 | 1)
#   poll STATUS(0x08) bit1 (DONE)
#   RESLO(0x1C) = cos  (esperado 0x5A81)
#   RESHI(0x20) = sin  (esperado 0x5A84)
#
# Layout DDR: word[0]=centinela word[1]=cos word[2]=sin
# Base DSP=0x9000_0000. DMA base=0x4000_0000 (CTRL 0x0C: bit0=start,bit1=dir).
# =============================================================================

        lui  x5, 0x90000        # x5 = base DSP 0x9000_0000

# --- escribir angulo CORDA=0x2000 ---
        lui  x6, 0x2           # 0x2 << 12 = 0x2000
        sw   x6, 20(x5)         # CORDA offset 0x14 = 20

# --- lanzar CORDIC rot: CTRL=0x07 ---
        addi x7, x0, 0x07
        sw   x7, 4(x5)          # CTRL offset 0x04

# --- poll DONE (STATUS bit1) ---
pollc:  lw   x8, 8(x5)          # STATUS offset 0x08
        andi x9, x8, 0x02       # bit1 = DONE
        beq  x9, x0, pollc

# --- leer cos y sin ---
        lw   x10, 28(x5)        # RESLO offset 0x1C = 28 (cos)
        lw   x11, 32(x5)        # RESHI offset 0x20 = 32 (sin)

# --- escribir centinela + resultados en RAM local ---
        lui  x12, 0xD1A6C
        addi x12, x12, 0x0DE    # centinela 0xD1A6C0DE
        sw   x12, 0(x0)         # word[0]
        sw   x10, 4(x0)         # word[1] = cos
        sw   x11, 8(x0)         # word[2] = sin

# --- DMA local->DDR, LEN=3 ---
        lui  x1, 0x40000        # base DMA
        addi x2, x0, 0
        sw   x2, 0(x1)          # src=0
        sw   x2, 4(x1)          # dst=0 (ddr_base)
        addi x3, x0, 3
        sw   x3, 8(x1)          # len=3
        addi x4, x0, 3
        sw   x4, 12(x1)         # CTRL: start|dir(local->DDR)=3
polld:  lw   x9, 16(x1)
        bne  x9, x0, polld

# --- doorbell ---
        addi x13, x0, 1
        sw   x13, 508(x0)

halt:   beq  x0, x0, halt
