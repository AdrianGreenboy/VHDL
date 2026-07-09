# prueba del IP IIC desde el RV32 (loop_int: maestro<->esclavo internos, sin pads)
#
# Fase A: escritura maestro->esclavo de 0x5A y 0xC3 por CMD; el esclavo los
#         junta en su FIFO SRX; se leen de vuelta por SRX (pop-on-read) y se
#         guardan nivel y bytes en RAM local.
# Fase B: lectura maestro<-esclavo: se precarga 0xA5 en STX, START repetido
#         de lectura, byte a MRD.
# Fase C: NACK con direccion ajena (0x33): se captura el sticky NACK ANTES
#         de limpiar STAT y se cierra con NOBYTE|STOP.
# Fase D: marca 1337 en local[3] y reporta local[0..7] a la DDR del SoC con
#         el dma_burst (dir local->DDR). El TB verifica la DDR.
#
# Registros IIC en 0x70000000:
#   CTRL=0 STAT=4 SCLDIV=8 CMD=12 MRD=16 SADDR=20 STX=24 SRX=28
#   LVL=32 IRQ_EN=36 IRQ_STAT=40 WM=44
# Bits de CMD: [7:0] dato, [8] START, [9] STOP, [10] READ, [11] ACKOUT,
#              [12] NOBYTE. Stickies de STAT: MDONE=b16, NACK=b18.
# Registros DMA del SoC en 0x40000000: SRC=0 DST=4 LEN=8 CTRL=12 STATUS=16

        lui  x1, 0x70000        # x1 = base registros IIC
        lui  x2, 0x40000        # x2 = base registros DMA del SoC
        lui  x20, 0x10          # x20 = 0x10000 (mascara MDONE, bit16)
        lui  x21, 0x40          # x21 = 0x40000 (mascara NACK,  bit18)

        # --- configuracion (inmediatos SEPARADOS: el A72 los parchea) ---
        addi x5, x0, 24         # <- prog[4]: SCLDIV (parcheable; 24 = 1 MHz)
        sw   x5, 8(x1)          # SCLDIV
        addi x5, x0, 42         # <- prog[6]: SADDR (parcheable; 0x2A)
        sw   x5, 20(x1)         # SADDR
        addi x5, x0, 135        # <- prog[8]: CTRL (parcheable; 0x87=EN|SEN|STRETCH|LOOP)
        sw   x5, 0(x1)          # CTRL

        # --- fase A: escritura loop maestro->esclavo (0x5A, 0xC3) ---
        addi x5, x0, 340        # 0x154 = START | 0x54 (addr 0x2A/W)
        sw   x5, 12(x1)         # CMD
        jal  x31, wdone
        addi x5, x0, 90         # 0x5A
        sw   x5, 12(x1)
        jal  x31, wdone
        addi x5, x0, 707        # 0x2C3 = STOP | 0xC3
        sw   x5, 12(x1)
        jal  x31, wdone

        lw   x8, 32(x1)         # LVL
        andi x8, x8, 511        # nivel SRX [8:0]
        sw   x8, 0(x0)          # local[0] = 2
        lw   x9, 28(x1)         # SRX (pop) -> 0x5A
        andi x9, x9, 255
        sw   x9, 4(x0)          # local[1]
        lw   x9, 28(x1)         # SRX (pop) -> 0xC3
        andi x9, x9, 255
        sw   x9, 8(x0)          # local[2]

        # --- fase B: lectura loop con STX precargado (0xA5) ---
        addi x5, x0, 165        # 0xA5
        sw   x5, 24(x1)         # STX push
        addi x5, x0, 341        # 0x155 = START | 0x55 (addr 0x2A/R)
        sw   x5, 12(x1)
        jal  x31, wdone
        li   x5, 3584           # 0xE00 = READ | ACKOUT(NACK) | STOP
        sw   x5, 12(x1)
        jal  x31, wdone
        lw   x9, 16(x1)         # MRD
        andi x9, x9, 255
        sw   x9, 16(x0)         # local[4] = 0xA5

        # --- fase C: NACK con direccion ajena (0x33) ---
        addi x5, x0, 358        # 0x166 = START | 0x66 (addr 0x33/W)
        sw   x5, 12(x1)
polln:  lw   x6, 4(x1)          # STAT: esperar MDONE SIN limpiar
        and  x7, x6, x20
        beq  x7, x0, polln
        and  x7, x6, x21        # capturar NACK (bit18)
        srli x7, x7, 18         # -> 1
        sw   x7, 20(x0)         # local[5] = 1
        sw   x0, 4(x1)          # limpiar stickies
        li   x5, 4608           # 0x1200 = NOBYTE | STOP (cierre tras NACK)
        sw   x5, 12(x1)
        jal  x31, wdone

        # --- fase D: doorbell y reporte ---
        addi x5, x0, 1337
        sw   x5, 12(x0)         # local[3] = 1337
        sw   x0, 0(x2)          # SRC = 0 (local, bytes)
        sw   x0, 4(x2)          # DST = 0 (DDR, bytes)
        addi x5, x0, 8
        sw   x5, 8(x2)          # LEN = 8 palabras
        addi x5, x0, 3
        sw   x5, 12(x2)         # CTRL = start + dir=1 (local -> DDR)
pollc:  lw   x6, 16(x2)         # STATUS (busy pegajoso)
        bne  x6, x0, pollc

halt:   beq  x0, x0, halt

# --- subrutina: espera MDONE y limpia stickies (retorno en x31) ---
wdone:  lw   x6, 4(x1)          # STAT
        and  x7, x6, x20
        beq  x7, x0, wdone
        sw   x0, 4(x1)          # cualquier escritura a STAT limpia
        jalr x0, 0(x31)
