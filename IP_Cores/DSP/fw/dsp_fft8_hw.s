# =============================================================================
# dsp_fft8_hw.s  -  Bring-up Fase C: FFT N=8 forward en silicio.
#   Valida el ping-pong SDP (Frente 1) y el buffer DATA en BRAM (Frente 2).
#
# Secuencia:
#   LOG2N(0x0C) = 3
#   DATA(0x1000..) = 8 palabras de entrada (im<<16|re)
#   CTRL(0x04) = 0x01   START|FUNC=FFTF (0b000<<1|1)
#   poll STATUS(0x08) bit1 DONE
#   leer DATA(0x1000..) = 8 resultados
#   -> RAM local [centinela, 8 resultados] -> DMA DDR -> doorbell
#
# Base DSP=0x9000_0000. DATA offset 0x1000. Contrato BRAM: llenar->operar->
# esperar DONE->leer (nunca escribir-leer-inmediato).
#
# Entrada (guardada en IMEM como datos via secuencia de li+sw):
#   1000,-500,300,800,-200,600,-100,400 (todo real)
#   palabras: 3E8, FE0C, 12C, 320, FF38, 258, FF9C, 190
# =============================================================================

        lui  x5, 0x90000        # base DSP

# --- LOG2N = 3 ---
        addi x6, x0, 3
        sw   x6, 12(x5)         # LOG2N offset 0x0C

# --- llenar DATA[0..7] (offset 0x1000 = 4096) ---
# x7 = puntero a DATA (base + 0x1000)
        addi x7, x5, 0          # x7 = base DSP
        lui  x8, 0x1            # 0x1000
        add  x7, x7, x8         # x7 = base + 0x1000 = DATA[0]

# DATA[0]=0x000003E8 (1000)
        addi x9, x0, 1000
        sw   x9, 0(x7)
# DATA[1]=0x0000FE0C (-500)
        lui  x9, 0x10
        addi x9, x9, -500
        sw   x9, 4(x7)
# DATA[2]=0x0000012C (300)
        addi x9, x0, 300
        sw   x9, 8(x7)
# DATA[3]=0x00000320 (800)
        addi x9, x0, 800
        sw   x9, 12(x7)
# DATA[4]=0x0000FF38 (-200)
        lui  x9, 0x10
        addi x9, x9, -200
        sw   x9, 16(x7)
# DATA[5]=0x00000258 (600)
        addi x9, x0, 600
        sw   x9, 20(x7)
# DATA[6]=0x0000FF9C (-100)
        lui  x9, 0x10
        addi x9, x9, -100
        sw   x9, 24(x7)
# DATA[7]=0x00000190 (400)
        addi x9, x0, 400
        sw   x9, 28(x7)

# --- lanzar FFT forward: CTRL=0x01 ---
        addi x11, x0, 0x01
        sw   x11, 4(x5)

# --- poll DONE ---
pollf:  lw   x12, 8(x5)
        andi x13, x12, 0x02
        beq  x13, x0, pollf

# --- leer DATA[0..7] y escribir a RAM local [1..8], centinela en [0] ---
        lui  x14, 0xD1A6C
        addi x14, x14, 0x0DE
        sw   x14, 0(x0)         # centinela en word[0]

# leer 8 resultados. x7 sigue apuntando a DATA[0].
        lw   x15, 0(x7)
        sw   x15, 4(x0)
        lw   x15, 4(x7)
        sw   x15, 8(x0)
        lw   x15, 8(x7)
        sw   x15, 12(x0)
        lw   x15, 12(x7)
        sw   x15, 16(x0)
        lw   x15, 16(x7)
        sw   x15, 20(x0)
        lw   x15, 20(x7)
        sw   x15, 24(x0)
        lw   x15, 24(x7)
        sw   x15, 28(x0)
        lw   x15, 28(x7)
        sw   x15, 32(x0)

# --- DMA local->DDR, LEN=9 (centinela + 8 resultados) ---
        lui  x1, 0x40000
        addi x2, x0, 0
        sw   x2, 0(x1)          # src=0
        sw   x2, 4(x1)          # dst=0
        addi x3, x0, 9
        sw   x3, 8(x1)          # len=9
        addi x4, x0, 3
        sw   x4, 12(x1)         # start|dir local->DDR
polld:  lw   x9, 16(x1)
        bne  x9, x0, polld

# --- doorbell ---
        addi x16, x0, 1
        sw   x16, 508(x0)

halt:   beq  x0, x0, halt
