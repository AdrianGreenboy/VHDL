# prueba del IP SpaceWire desde el RV32 (LOOP_INT: un codec en self-loopback)
#
# Fase A: bring-up del enlace hasta Run y captura del sticky RUNOK.
# Fase B: datos por loopback (0xA5, 0x5A, EOP) leidos con pop-on-read + VALID.
# Fase C: time-code 0x3C: sticky TICK, valor y contador.
# Fase D: rafaga de 16 bytes (1..16) con verificacion por XOR (= 0x10).
# Fase E: estado final: enlace en Run (5) y FIFO RX vacio.
# Fase F: parcheo de DIV a 2 (50 Mbit/s), re-arranque y un byte de ida y vuelta.
# Fase G: doorbell 1337 en local[3] y reporte de local[0..15] a la DDR del
#         SoC con el dma_burst. El doorbell viaja DENTRO de la rafaga.
#
# Registros SPW en 0xB0000000:
#   CTRL=0x00 DIV=0x04 CMD=0x08 TIME=0x0C STAT=0x10 TXD=0x14 RXD=0x18 IRQEN=0x1C
# CTRL: b0 EN, b1 START, b2 AUTOSTART, b3 DISABLE, b4 LOOP_INT
# STAT vivos: b2:0 estado, b3 RUN, b4 TX_SPACE, b5 RX_AVAIL, b14:8 rx_level
# STAT stickies: b16 PAR b17 ESC b18 DISC b19 CRED b20 TICK b21 LINKDOWN
#                b22 RUNOK b23 TXOVF b24 RXOVF
# RXD: pop-on-read, b8:0 caracter (b8=1: b0=0 EOP, b0=1 EEP), b31 VALID
# Registros DMA del SoC en 0x40000000: SRC=0 DST=4 LEN=8 CTRL=12 STATUS=16

        lui  x1, 0xB0000        # x1 = base registros SPW
        lui  x2, 0x40000        # x2 = base registros DMA del SoC

        # --- configuracion (inmediatos SEPARADOS: el A72 los parchea) ---
        addi x4, x0, 10         # <- DIV (parcheable; 10=10M, 5=20M, 4=25M, 2=50M)
        sw   x4, 4(x1)          # DIV
        addi x5, x0, 19         # <- CTRL (parcheable; 0x13 = EN|START|LOOP_INT)
        sw   x5, 0(x1)          # CTRL

        # --- fase A: esperar Run y capturar RUNOK ---
        addi x20, x0, 8         # mascara RUN (bit3)
waitR:  lw   x6, 16(x1)         # STAT
        and  x7, x6, x20
        beq  x7, x0, waitR
        lui  x21, 0x400         # mascara RUNOK (bit22 = 0x00400000)
        lw   x6, 16(x1)
        and  x7, x6, x21
        srli x7, x7, 22
        sw   x7, 0(x0)          # local[0] = 1
        sw   x0, 16(x1)         # limpiar stickies

        # --- fase B: 0xA5, 0x5A y EOP por loopback ---
        addi x5, x0, 165        # 0xA5
        sw   x5, 20(x1)         # TXD
        addi x5, x0, 90         # 0x5A
        sw   x5, 20(x1)
        addi x5, x0, 256        # 0x100 = EOP
        sw   x5, 20(x1)
        lui  x22, 0x80000       # mascara VALID (bit31)
rd1:    lw   x9, 24(x1)         # RXD (pop-on-read; sin VALID no consume)
        and  x7, x9, x22
        beq  x7, x0, rd1
        andi x9, x9, 255
        sw   x9, 4(x0)          # local[1] = 0xA5
rd2:    lw   x9, 24(x1)
        and  x7, x9, x22
        beq  x7, x0, rd2
        andi x9, x9, 255
        sw   x9, 8(x0)          # local[2] = 0x5A
rd3:    lw   x9, 24(x1)
        and  x7, x9, x22
        beq  x7, x0, rd3
        andi x9, x9, 511        # bits 8:0
        sw   x9, 16(x0)         # local[4] = 0x100 (EOP)

        # --- fase C: time-code 0x3C ---
        addi x5, x0, 60         # 0x3C
        sw   x5, 12(x1)         # TIME (latch + tick)
        lui  x23, 0x100         # mascara TICK (bit20 = 0x00100000)
waitT:  lw   x6, 16(x1)         # STAT
        and  x7, x6, x23
        beq  x7, x0, waitT
        lw   x9, 12(x1)         # TIME: b7:0 ultimo valor, b15:8 contador
        andi x10, x9, 255
        sw   x10, 20(x0)        # local[5] = 0x3C
        srli x9, x9, 8
        andi x9, x9, 255
        sw   x9, 24(x0)         # local[6] = 1
        sw   x0, 16(x1)         # limpiar stickies

        # --- fase D: rafaga de 16 bytes (1..16) con XOR ---
        addi x12, x0, 16
        addi x13, x0, 1
txlp:   sw   x13, 20(x1)        # TXD
        addi x13, x13, 1
        addi x12, x12, -1
        bne  x12, x0, txlp
        addi x12, x0, 16
        add  x10, x0, x0        # acumulador XOR
rxlp:   lw   x9, 24(x1)         # RXD
        and  x7, x9, x22
        beq  x7, x0, rxlp
        andi x9, x9, 255
        xor  x10, x10, x9
        addi x12, x12, -1
        bne  x12, x0, rxlp
        sw   x10, 28(x0)        # local[7] = XOR(1..16) = 0x10

        # --- fase E: estado final ---
        lw   x6, 16(x1)         # STAT
        andi x7, x6, 7          # estado del enlace
        sw   x7, 32(x0)         # local[8] = 5 (Run)
        andi x7, x6, 32         # RX_AVAIL
        sw   x7, 36(x0)         # local[9] = 0 (FIFO RX vacio)

        # --- fase F: DIV a 2 (50 Mbit/s) y re-arranque ---
        sw   x0, 0(x1)          # CTRL = 0 (nucleo en reset sincrono)
        addi x5, x0, 2          # <- DIV = 2 (parcheable)
        sw   x5, 4(x1)
        addi x5, x0, 19
        sw   x5, 0(x1)          # CTRL = EN|START|LOOP_INT
waitR2: lw   x6, 16(x1)
        and  x7, x6, x20
        beq  x7, x0, waitR2
        addi x5, x0, 195        # 0xC3
        sw   x5, 20(x1)         # TXD
rd4:    lw   x9, 24(x1)
        and  x7, x9, x22
        beq  x7, x0, rd4
        andi x9, x9, 255
        sw   x9, 40(x0)         # local[10] = 0xC3

        # --- fase G: doorbell y reporte ---
        addi x5, x0, 1337
        sw   x5, 12(x0)         # local[3] = 1337 (viaja dentro de la rafaga)
        sw   x0, 0(x2)          # SRC = 0 (local)
        sw   x0, 4(x2)          # DST = 0 (DDR)
        addi x5, x0, 16
        sw   x5, 8(x2)          # LEN = 16 palabras
        addi x5, x0, 3
        sw   x5, 12(x2)         # CTRL = start + dir=1 (local -> DDR)
pollc:  lw   x6, 16(x2)         # STATUS (busy pegajoso)
        bne  x6, x0, pollc

halt:   beq  x0, x0, halt
