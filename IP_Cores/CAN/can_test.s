# prueba del IP CAN desde el RV32 (loop_int: nodos A y B internos, wired-AND)
#
# Fase A: self-test A->B, trama base id=0x123 dlc=8 datos 0x0123456789ABCDEF.
#         Se leen del FIFO de B los 13 bytes del registro empaquetado y se
#         guardan campos clave.
# Fase B: B->A, trama extendida remota id=0x15A5A5A5 dlc=5. Se guarda el
#         primer byte (flags+ID alto = 0x75) y el DLC.
# Fase C: arbitraje simultaneo: A (id 0x0F0) gana, B (id 0x123) reintenta.
#         Se captura el sticky ARB_B y se comprueba que llegan ambas tramas.
# Fase D: doorbell 1337 en local[3] y reporte de local[0..15] a la DDR del
#         SoC con el dma_burst. El doorbell viaja DENTRO de la rafaga.
#
# Registros CAN en 0xA0000000:
#   CTRL=0x00 STAT=0x04 BTR=0x08
#   TXID_A=0x10 TXDLC_A=0x14 TXDH_A=0x18 TXDL_A=0x1C CMD_A=0x20
#   RXFIFO_A=0x24 CNT_A=0x28
#   TXID_B=0x30 TXDLC_B=0x34 TXDH_B=0x38 TXDL_B=0x3C CMD_B=0x40
#   RXFIFO_B=0x44 CNT_B=0x48
#   LVL=0x50 IRQ_EN=0x54 IRQ_STAT=0x58 WM=0x5C
# STAT stickies: b16 TXDONE_A b17 TXDONE_B b18 ARB_A b19 ARB_B
#               b24 RXV_A b25 RXV_B
# Registros DMA del SoC en 0x40000000: SRC=0 DST=4 LEN=8 CTRL=12 STATUS=16

        lui  x1, 0xA0000        # x1 = base registros CAN
        lui  x2, 0x40000        # x2 = base registros DMA del SoC

        # --- configuracion (inmediatos SEPARADOS: el A72 los parchea) ---
        # BTR = (campo alto TSEG1|TSEG2|SJW) OR (BRP). El BRP va en su propia
        # addi para que el bring-up lo parchee sin tocar el resto del registro.
        lui  x5, 0x16           # campo alto del BTR: 0x00015C00 (tras el addi)
        addi x5, x5, -1024      # 0x00015C00: tseg1=12 tseg2=5 sjw=1 brp=0
        addi x4, x0, 9          # <- prog[4]: BRP (parcheable; 9 = 500 kbit/s)
        or   x5, x5, x4         # BTR completo
        sw   x5, 8(x1)          # BTR
        addi x5, x0, 131        # <- prog[7]: CTRL (parcheable; 0x83=EN_A|EN_B|LOOP)
        sw   x5, 0(x1)          # CTRL

        # --- fase A: A -> B, trama base id=0x123 dlc=8 ---
        addi x5, x0, 291        # 0x123
        sw   x5, 16(x1)         # TXID_A
        addi x5, x0, 8
        sw   x5, 20(x1)         # TXDLC_A
        lui  x5, 0x01234        # 0x01234000
        addi x5, x5, 1383       # 0x01234567
        sw   x5, 24(x1)         # TXDH_A (bytes 0-3)
        lui  x5, 0x89ABD        # 0x89ABD000
        addi x5, x5, -529       # 0x89ABCDEF
        sw   x5, 28(x1)         # TXDL_A (bytes 4-7)
        addi x5, x0, 1
        sw   x5, 32(x1)         # CMD_A = GO

        lui  x20, 0x10          # x20 = 0x10000 mascara TXDONE_A (bit16)
        lui  x23, 0x2000        # x23 = mascara RXV_B (bit25 = 0x02000000)
waitA:  lw   x6, 4(x1)          # STAT
        and  x7, x6, x20
        beq  x7, x0, waitA      # esperar TXDONE_A
        sw   x0, 4(x1)          # limpiar stickies

        # leer los 13 bytes del registro de B: byte0..byte4 = flags/ID/DLC
        lw   x9, 68(x1)         # RXFIFO_B pop byte0 (flags+ID[28:24] = 0x00)
        andi x9, x9, 255
        sw   x9, 0(x0)          # local[0] = 0x00
        lw   x9, 68(x1)         # byte1 (ID[23:16] = 0x00)
        lw   x9, 68(x1)         # byte2 (ID[15:8] = 0x01)
        andi x9, x9, 255
        sw   x9, 4(x0)          # local[1] = 0x01
        lw   x9, 68(x1)         # byte3 (ID[7:0] = 0x23)
        andi x9, x9, 255
        sw   x9, 8(x0)          # local[2] = 0x23
        lw   x9, 68(x1)         # byte4 (DLC = 0x08)
        andi x9, x9, 255
        sw   x9, 16(x0)         # local[4] = 0x08
        # bytes 5..12 = datos; guardar byte5 (dato0 = 0x01) y XOR de los 8
        lw   x9, 68(x1)         # dato0 (0x01)
        andi x9, x9, 255
        add  x10, x0, x9        # acumulador XOR
        sw   x9, 20(x0)         # local[5] = 0x01
        addi x12, x0, 7
lpayA:  lw   x9, 68(x1)         # datos 1..7
        andi x9, x9, 255
        xor  x10, x10, x9
        addi x12, x12, -1
        bne  x12, x0, lpayA
        sw   x10, 24(x0)        # local[6] = XOR de los 8 datos (0x00)

        # --- fase B: B -> A, extendida remota id=0x15A5A5A5 dlc=5 ---
        lui  x5, 0x75A5A        # 0x75A5A000: IDE|RTR|id alto
        addi x5, x5, 1445       # 0x75A5A5A5
        sw   x5, 48(x1)         # TXID_B
        addi x5, x0, 5
        sw   x5, 52(x1)         # TXDLC_B
        addi x5, x0, 1
        sw   x5, 64(x1)         # CMD_B = GO
        lui  x24, 0x20          # x24 = mascara TXDONE_B (bit17 = 0x00020000)
waitB:  lw   x6, 4(x1)          # STAT
        and  x7, x6, x24
        beq  x7, x0, waitB      # esperar TXDONE_B
        sw   x0, 4(x1)          # limpiar stickies
        lw   x9, 36(x1)         # RXFIFO_A pop byte0 (flags+ID alto = 0x75)
        andi x9, x9, 255
        sw   x9, 28(x0)         # local[7] = 0x75
        lw   x9, 36(x1)         # byte1
        lw   x9, 36(x1)         # byte2
        lw   x9, 36(x1)         # byte3
        lw   x9, 36(x1)         # byte4 = DLC (0x05)
        andi x9, x9, 255
        sw   x9, 32(x0)         # local[8] = 0x05
        # drenar los 8 datos restantes (trama remota: todos 0x00)
        addi x12, x0, 8
drnA:   lw   x9, 36(x1)
        addi x12, x12, -1
        bne  x12, x0, drnA

        # --- fase C: arbitraje simultaneo A(0x0F0) vs B(0x123) ---
        addi x5, x0, 240        # 0x0F0 (A gana)
        sw   x5, 16(x1)         # TXID_A
        addi x5, x0, 1
        sw   x5, 20(x1)         # TXDLC_A
        lui  x5, 0xAA000        # 0xAA000000: dato0 = 0xAA
        sw   x5, 24(x1)         # TXDH_A
        sw   x0, 28(x1)         # TXDL_A = 0
        addi x5, x0, 291        # 0x123 (B pierde)
        sw   x5, 48(x1)         # TXID_B
        addi x5, x0, 1
        sw   x5, 52(x1)         # TXDLC_B
        lui  x5, 0xBB000        # 0xBB000000: dato0 = 0xBB
        sw   x5, 56(x1)         # TXDH_B
        sw   x0, 60(x1)         # TXDL_B = 0
        addi x5, x0, 1
        sw   x5, 64(x1)         # CMD_B = GO
        addi x5, x0, 1
        sw   x5, 32(x1)         # CMD_A = GO (mismo grid: arbitraje real)
        # esperar ambos TXDONE (A y B via reintento)
        lui  x25, 0x30          # x25 = mascara TXDONE_A|TXDONE_B (0x00030000)
waitC:  lw   x6, 4(x1)          # STAT
        and  x7, x6, x25
        bne  x7, x25, ckarb     # aun no ambos: revisar y seguir
        beq  x0, x0, cdone
ckarb:  lw   x8, 4(x1)          # capturar ARB_B (bit19) durante la espera
        lui  x26, 0x80          # bit19 ARB_B = 0x00080000
        and  x8, x8, x26
        or   x11, x11, x8       # x11 acumula el sticky ARB_B visto
        beq  x0, x0, waitC
cdone:  lw   x8, 4(x1)
        lui  x26, 0x80
        and  x8, x8, x26
        or   x11, x11, x8
        srli x11, x11, 19       # -> 1 si ARB_B se activo
        sw   x11, 36(x0)        # local[9] = 1
        sw   x0, 4(x1)          # limpiar stickies
        # trama ganadora de A en B: byte4=DLC(1), primer dato=0xAA
        lw   x9, 68(x1)         # byte0
        lw   x9, 68(x1)         # byte1
        lw   x9, 68(x1)         # byte2
        lw   x9, 68(x1)         # byte3 (ID bajo = 0xF0)
        andi x9, x9, 255
        sw   x9, 40(x0)         # local[10] = 0xF0
        lw   x9, 68(x1)         # byte4 = DLC
        lw   x9, 68(x1)         # dato0 = 0xAA
        andi x9, x9, 255
        sw   x9, 44(x0)         # local[11] = 0xAA
        addi x12, x0, 7
drnB2:  lw   x9, 68(x1)
        addi x12, x12, -1
        bne  x12, x0, drnB2
        # trama de reintento de B en A: primer dato = 0xBB
        lw   x9, 36(x1)         # byte0
        lw   x9, 36(x1)         # byte1
        lw   x9, 36(x1)         # byte2
        lw   x9, 36(x1)         # byte3 (ID bajo = 0x23)
        andi x9, x9, 255
        sw   x9, 48(x0)         # local[12] = 0x23
        lw   x9, 36(x1)         # byte4 = DLC
        lw   x9, 36(x1)         # dato0 = 0xBB
        andi x9, x9, 255
        sw   x9, 52(x0)         # local[13] = 0xBB

        # --- fase D: doorbell y reporte ---
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
