# fw_rf.s - Firmware de bring-up del RF (Paso 7, para cpu_pipeline).
# Programa el banco RF (0x6000_0000), habilita el generador de tono (TONE_FTW=0
# -> banda base DC 29491), espera a que la RX FIFO tenga >=64 muestras, dispara
# el segundo maestro (DMA propio del RF) para volcar 64 palabras a la DDR, y hace
# el doorbell (palabra 127 de la RAM local). El PS leera el checksum de la DDR.
# Registros base: x1 = RF_BASE (0x60000000).
# Offsets del banco: CTRL=0x00 FTW=0x08 CFA=0x14 CFD=0x18 RXLVL=0x1C
#                    DMAA=0x34 DMAL=0x38 DMAC=0x3C TONE=0x40
start:
        lui  x1, 0x60000        # x1 = 0x60000000 (RF_BASE)
        # FTW del NCO RX = 0x0293A800
        lui  x5, 0x0293B
        addi x5, x5, -2048      # 0x0293B000 - 2048 = 0x0293A800
        sw   x5, 8(x1)          # NCO_FTW
        # TONE_FTW = 0 (banda base DC)
        sw   x0, 64(x1)         # TONE_FTW = 0
        # coeficientes passthrough del FIR RX: tap0 = 0x7FFF, tap1..15 = 0
        sw   x0, 20(x1)         # FIR_COEF_ADDR = 0
        lui  x6, 0x8
        addi x6, x6, -1        # 0x7FFF
        sw   x6, 24(x1)        # FIR_COEF_DATA = 0x7FFF (tap0)
        addi x7, x0, 1         # k = 1
        addi x8, x0, 16        # limite
coeflp:
        sw   x7, 20(x1)        # FIR_COEF_ADDR = k
        sw   x0, 24(x1)        # FIR_COEF_DATA = 0
        addi x7, x7, 1
        blt  x7, x8, coeflp
        # habilitar rx (CTRL bit0=1, loop bit2=1 -> 0x5)
        addi x9, x0, 5
        sw   x9, 0(x1)         # CTRL
        # esperar hasta RX_FIFO_LEVEL >= 64
        addi x10, x0, 64
waitlv:
        lw   x11, 28(x1)       # RX_FIFO_LEVEL
        blt  x11, x10, waitlv
        # programar el segundo maestro RF: DMA_ADDR=0, DMA_LEN=64, DMA_CTRL=1
        sw   x0, 52(x1)        # DMA_ADDR = 0 (offset en la DDR del RF)
        addi x12, x0, 64
        sw   x12, 56(x1)      # DMA_LEN = 64
        addi x13, x0, 1
        sw   x13, 60(x1)      # DMA_CTRL = 1 (dispara)
        # esperar a que el DMA RF ARRANQUE (STATUS bit5 = 1)
        addi x14, x0, 32       # mascara bit5 (0x20)
wbusy1:
        lw   x11, 4(x1)       # STATUS
        and  x15, x11, x14
        beq  x15, x0, wbusy1  # espera hasta busy=1
        # esperar a que el DMA RF TERMINE (STATUS bit5 = 0)
wbusy0:
        lw   x11, 4(x1)       # STATUS
        and  x15, x11, x14
        bne  x15, x0, wbusy0  # espera hasta busy=0
        # doorbell: palabra 127 de la RAM local (byte 508)
        addi x21, x0, 1
        sw   x21, 508(x0)
halt:   beq  x0, x0, halt
