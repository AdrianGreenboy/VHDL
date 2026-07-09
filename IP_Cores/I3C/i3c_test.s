# prueba del IP I3C desde el RV32 (loop_int: controller<->target internos)
#
# Fase A: ENTDAA completo por registros: header 0x7E/W, CCC 0x07, ronda de
#         colecta (8 bytes de PID+BCR+DCR por RX con pop-on-read), asignacion
#         de DA 0x30, segunda ronda que debe NACKear (capturada ANTES de
#         limpiar STAT) y STOP. Se guardan byte0, byte7 y el XOR de los 8.
# Fase B: escritura privada de 0xA5 y 0x3C; nivel y bytes de la FIFO TRX.
# Fase C: lectura privada: TTX precargada con 3 bytes, dos lecturas (la
#         segunda con RLAST|STOP = seize durante T alto).
# Fase D: IBI por TREQ: espera de IBI_REQ, IBIADDR, ibiack, mandatory byte
#         y t_bit final.
# Fase E: doorbell 1337 en local[3] y reporte de local[0..15] a la DDR del
#         SoC con el dma_burst. El TB verifica la DDR.
#
# Registros I3C en 0x90000000:
#   CTRL=0 STAT=4 SCLDIV=8 CMD=12 RX=16 IBIADDR=20 TCFG=24 TPIDL=28
#   TPIDH=32 TBDCR=36 TSTATW=40 TDA=44 TLEN=48 TREQ=52 TTX=56 TRX=60
#   LVL=64 IRQ_EN=68 IRQ_STAT=72 WM=76
# Bits de CMD: [7:0] dato, [8] START, [9] STOP, [10] READ, [11] RLAST,
#              [12] NOBYTE, [13] DAA, [14] DAADR, [15] IBIACK, [16] IBINAK
# STAT: vivos b3=ACK_IN b4=T_BIT b2=IBI_REQ; sticky b16=DONE
# Registros DMA del SoC en 0x40000000: SRC=0 DST=4 LEN=8 CTRL=12 STATUS=16

        lui  x1, 0x90000        # x1 = base registros I3C
        lui  x2, 0x40000        # x2 = base registros DMA del SoC
        lui  x20, 0x10          # x20 = 0x10000 (mascara DONE, bit16)
        addi x22, x0, 8         # x22 = mascara ACK_IN (bit3)

        # --- configuracion (inmediatos SEPARADOS: el A72 los parchea) ---
        lui  x5, 0x180          # <- DIV_OD = 24 en bits 31:16 (1.04 MHz OD)
        addi x5, x5, 7          # <- prog[5]: DIV_PP (parcheable; 7 = 3.125 MHz)
        sw   x5, 8(x1)          # SCLDIV
        addi x5, x0, 82         # SA = 0x52
        sw   x5, 24(x1)         # TCFG
        lui  x5, 0x67ABD
        addi x5, x5, -529       # PID[31:0] = 0x67ABCDEF
        sw   x5, 28(x1)         # TPIDL
        addi x5, x0, 1113       # PID[47:32] = 0x0459
        sw   x5, 32(x1)         # TPIDH
        lui  x5, 0x9CC
        addi x5, x5, 1606       # MDB=0x9C DCR=0xC6 BCR=0x46
        sw   x5, 36(x1)         # TBDCR
        lui  x5, 0x1
        addi x5, x5, 564        # GETSTATUS = 0x1234
        sw   x5, 40(x1)         # TSTATW
        addi x5, x0, 131        # <- prog[20]: CTRL (parcheable; 0x83=EN|TEN|LOOP)
        sw   x5, 0(x1)          # CTRL

        # --- fase A: ENTDAA ---
        addi x5, x0, 508        # 0x1FC = START | 0x7E/W
        sw   x5, 12(x1)
        jal  x31, wdone
        addi x5, x0, 7          # CCC ENTDAA
        sw   x5, 12(x1)
        jal  x31, wdone
        lui  x5, 0x2            # 0x2000 = DAA
        sw   x5, 12(x1)
        jal  x31, wdone

        lw   x9, 16(x1)         # RX pop -> byte0 (0x04)
        andi x9, x9, 255
        sw   x9, 0(x0)          # local[0]
        add  x10, x0, x9        # acumulador XOR
        addi x12, x0, 6
lpay:   lw   x9, 16(x1)         # RX pop -> bytes 1..6
        andi x9, x9, 255
        xor  x10, x10, x9
        addi x12, x12, -1
        bne  x12, x0, lpay
        lw   x9, 16(x1)         # RX pop -> byte7 (0xC6)
        andi x9, x9, 255
        xor  x10, x10, x9
        sw   x9, 4(x0)          # local[1]
        sw   x10, 8(x0)         # local[2] = XOR de los 8 (0x33)

        lui  x5, 0x4
        addi x5, x5, 96         # 0x4060 = DAADR | DA 0x30<<1
        sw   x5, 12(x1)
        jal  x31, wdone
        lw   x9, 44(x1)         # TDA (esperado 0x730)
        sw   x9, 16(x0)         # local[4]

        lui  x5, 0x2            # segunda ronda DAA: debe NACKear
        sw   x5, 12(x1)
polln:  lw   x6, 4(x1)          # STAT: esperar DONE SIN limpiar
        and  x7, x6, x20
        beq  x7, x0, polln
        and  x7, x6, x22        # capturar ACK_IN (bit3)
        srli x7, x7, 3          # -> 1 (NACK)
        sw   x7, 20(x0)         # local[5] = 1
        sw   x0, 4(x1)          # limpiar stickies
        lui  x5, 0x1
        addi x5, x5, 512        # 0x1200 = NOBYTE | STOP
        sw   x5, 12(x1)
        jal  x31, wdone

        # --- fase B: escritura privada (0xA5, 0x3C) ---
        addi x5, x0, 508        # START | 0x7E/W
        sw   x5, 12(x1)
        jal  x31, wdone
        addi x5, x0, 352        # 0x160 = START(Sr) | DA 0x30/W
        sw   x5, 12(x1)
        jal  x31, wdone
        addi x5, x0, 165        # 0xA5
        sw   x5, 12(x1)
        jal  x31, wdone
        addi x5, x0, 572        # 0x23C = STOP | 0x3C
        sw   x5, 12(x1)
        jal  x31, wdone

        lw   x8, 64(x1)         # LVL
        srli x8, x8, 16
        andi x8, x8, 63         # nivel TRX
        sw   x8, 24(x0)         # local[6] = 2
        lw   x9, 60(x1)         # TRX pop -> 0xA5
        andi x9, x9, 255
        sw   x9, 28(x0)         # local[7]
        lw   x9, 60(x1)         # TRX pop -> 0x3C
        andi x9, x9, 255
        sw   x9, 32(x0)         # local[8]

        # --- fase C: lectura privada con seize ---
        addi x5, x0, 17         # TTX <- 0x11
        sw   x5, 56(x1)
        addi x5, x0, 34         # TTX <- 0x22
        sw   x5, 56(x1)
        addi x5, x0, 51         # TTX <- 0x33 (queda en cola: el seize ve T=1)
        sw   x5, 56(x1)
        addi x5, x0, 508        # START | 0x7E/W
        sw   x5, 12(x1)
        jal  x31, wdone
        addi x5, x0, 353        # 0x161 = START(Sr) | DA 0x30/R
        sw   x5, 12(x1)
        jal  x31, wdone
        addi x5, x0, 1024       # 0x400 = READ
        sw   x5, 12(x1)
        jal  x31, wdone
        lw   x9, 16(x1)         # RX pop -> 0x11
        andi x9, x9, 255
        sw   x9, 36(x0)         # local[9]
        li   x5, 3584           # 0xE00 = READ | RLAST | STOP (seize)
        sw   x5, 12(x1)
        jal  x31, wdone
        lw   x9, 16(x1)         # RX pop -> 0x22
        andi x9, x9, 255
        sw   x9, 40(x0)         # local[10]

        # --- fase D: IBI con mandatory byte ---
        addi x5, x0, 1
        sw   x5, 52(x1)         # TREQ: IBI_GO
pollb:  lw   x6, 4(x1)          # STAT: esperar IBI_REQ (bit2, nivel)
        andi x7, x6, 4
        beq  x7, x0, pollb
        lw   x9, 20(x1)         # IBIADDR -> 0x61
        andi x9, x9, 255
        sw   x9, 44(x0)         # local[11]
        lui  x5, 0x8            # 0x8000 = IBIACK
        sw   x5, 12(x1)
        jal  x31, wdone
        addi x5, x0, 1024       # READ del mandatory byte
        sw   x5, 12(x1)
        jal  x31, wdone
        lw   x6, 4(x1)          # STAT: t_bit vivo (bit4)
        andi x7, x6, 16
        srli x7, x7, 4
        sw   x7, 52(x0)         # local[13] = 0
        lw   x9, 16(x1)         # RX pop -> 0x9C
        andi x9, x9, 255
        sw   x9, 48(x0)         # local[12]
        lui  x5, 0x1
        addi x5, x5, 512        # NOBYTE | STOP
        sw   x5, 12(x1)
        jal  x31, wdone

        # --- fase E: doorbell y reporte ---
        addi x5, x0, 1337
        sw   x5, 12(x0)         # local[3] = 1337
        sw   x0, 0(x2)          # SRC = 0 (local)
        sw   x0, 4(x2)          # DST = 0 (DDR)
        addi x5, x0, 16
        sw   x5, 8(x2)          # LEN = 16 palabras
        addi x5, x0, 3
        sw   x5, 12(x2)         # CTRL = start + dir=1 (local -> DDR)
pollc:  lw   x6, 16(x2)         # STATUS (busy pegajoso)
        bne  x6, x0, pollc

halt:   beq  x0, x0, halt

# --- subrutina: espera DONE y limpia stickies (retorno en x31) ---
wdone:  lw   x6, 4(x1)          # STAT
        and  x7, x6, x20
        beq  x7, x0, wdone
        sw   x0, 4(x1)          # cualquier escritura a STAT limpia
        jalr x0, 0(x31)
