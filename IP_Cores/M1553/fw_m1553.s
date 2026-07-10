# =============================================================================
#  fw_m1553.s  -  Firmware de bring-up del IP MIL-STD-1553B (capa 5, silicio)
#  Licencia: MIT
#
#  Ejecuta el MISMO guion que la capa 4 (ISS), 100% en LOOP_INT:
#    1) configura RTADDR (RT0=5, RT1=9) y CTRL = EN|LOOP_INT
#    2) BC->RT0 wc=4 ; 3) RT0->BC wc=3 ; 4) RT0->RT1 wc=2
#    5) broadcast wc=2 ; 6) timeout (RT ausente)
#    7) escribe una firma de 8 palabras en RAM local y hace doorbell al DMA
#       para volcarla a la DDR (dir=1 local->DDR); el done_pulse del sw a la
#       palabra DONE_WORD dispara la IRQ PL->PS y el PS lee la firma.
#
#  Mapa 1553 (base 0xC000_0000):
#    0x00 CTRL  0x04 RTADDR  0x08 CMD  0x0C MSG  0x10 STAT
#    0x14 TXD   0x18 RXD     0x1C IRQEN 0x20 RESULT
#  Mapa DMA (base 0x4000_0000): 0x00 SRC 0x04 DST 0x08 LEN 0x0C CTRL 0x10 STAT
#  RAM local en 0x0000_0000. La firma va a las words 0..7 de la RAM local.
#
#  Ensamblar:  python3 ~/rv32i/asm.py fw_m1553.s fw_m1553.mem
#  y cargar fw_m1553.mem como IMEM_INIT del SoC (o por la ventana IMEM del
#  axil_soc desde el PS).
#
#  Convencion de registros:
#    x3  = base 1553 (0xC000_0000)
#    x4  = base DMA  (0x4000_0000)
#    x5  = scratch / valores de MSG
#    x6  = scratch
#    x7  = acumulador de firma
#    x8  = contador de bucle
#    x9  = puntero de firma en RAM local (word index * 4)
#    x10 = lectura de STAT / RXD / RESULT
# =============================================================================

        li   x3, 0xC0000000        # base 1553
        li   x4, 0x40000000        # base DMA
        addi x9, x0, 0             # puntero de firma en RAM local = 0

        # --- Paso 1: configurar ---
        li   x5, 0x00000905        # RT1=9 (b12:8), RT0=5 (b4:0)
        sw   x5, 4(x3)             # RTADDR
        addi x5, x0, 3             # EN | LOOP_INT
        sw   x5, 0(x3)             # CTRL

        # pequena espera a que arranquen los nucleos (~unos us)
        li   x8, 2000
w_init: addi x8, x8, -1
        bne  x8, x0, w_init

# -----------------------------------------------------------------------------
#  Paso 2: BC->RT0 wc=4
# -----------------------------------------------------------------------------
        li   x5, 0x0000B100
        sw   x5, 20(x3)            # TXD
        li   x5, 0x0000B101
        sw   x5, 20(x3)
        li   x5, 0x0000B102
        sw   x5, 20(x3)
        li   x5, 0x0000B103
        sw   x5, 20(x3)
        # MSG: rtrt=0 tr=0 rt=5 sa=3 wc=4  -> 0x00004194
        li   x5, 0x00004194
        sw   x5, 12(x3)            # MSG
        jal  x1, do_go
        # sig[0] = stat1 (RESULT bajo)
        lw   x10, 32(x3)           # RESULT
        andi x10, x10, 0xFFF       # (stat1 cabe en 12 bits para 0x2800? no)
        lw   x10, 32(x3)           # releer completo
        lui  x6, 0x10              # mascara 0xFFFF via lui/addi
        addi x6, x6, -1            # x6 = 0x0000FFFF
        and  x10, x10, x6
        sw   x10, 0(x9)            # firma[0]
        addi x9, x9, 4
        # sig[1] = suma de 4 datos RX
        addi x7, x0, 0             # acc
        addi x8, x0, 4             # 4 palabras
p2rx:   lw   x10, 24(x3)          # RXD (pop-on-read)
        and  x10, x10, x6         # dato (16 b)
        add  x7, x7, x10
        addi x8, x8, -1
        bne  x8, x0, p2rx
        and  x7, x7, x6
        sw   x7, 0(x9)            # firma[1]
        addi x9, x9, 4
        li   x5, 0xFFFFFFFF
        sw   x5, 16(x3)            # limpiar stickies (STAT)

# -----------------------------------------------------------------------------
#  Paso 3: RT0->BC wc=3
# -----------------------------------------------------------------------------
        li   x5, 0x0000E200
        sw   x5, 20(x3)
        li   x5, 0x0000E201
        sw   x5, 20(x3)
        li   x5, 0x0000E202
        sw   x5, 20(x3)
        # MSG: rtrt=0 tr=1 rt=5 sa=2 wc=3  -> 0x00003116
        li   x5, 0x00003116
        sw   x5, 12(x3)
        jal  x1, do_go
        lw   x10, 32(x3)
        and  x10, x10, x6
        sw   x10, 0(x9)           # firma[2] = stat1
        addi x9, x9, 4
        # sig[3] = xor de 3 datos
        addi x7, x0, 0
        lw   x10, 24(x3)
        and  x10, x10, x6
        xor  x7, x7, x10
        lw   x10, 24(x3)
        and  x10, x10, x6
        xor  x7, x7, x10
        lw   x10, 24(x3)
        and  x10, x10, x6
        xor  x7, x7, x10
        sw   x7, 0(x9)           # firma[3]
        addi x9, x9, 4
        li   x5, 0xFFFFFFFF
        sw   x5, 16(x3)

# -----------------------------------------------------------------------------
#  Paso 4: RT0->RT1 wc=2
# -----------------------------------------------------------------------------
        li   x5, 0x0000F300
        sw   x5, 20(x3)
        li   x5, 0x0000F301
        sw   x5, 20(x3)
        # MSG: rtrt=1 tr=0 rt=5 sa=4 wc=2 rt2=9 sa2=4
        #   b0=1 b6:2=00101 b11:7=00100 b16:12=00010 b21:17=01001 b26:22=00100
        #   = 0x0112_2215 (calculado: rt2=9<<17, sa2=4<<22):
        li   x5, 0x01122215
        sw   x5, 12(x3)
        jal  x1, do_go
        lw   x10, 32(x3)          # RESULT completo (stat2<<16 | stat1)
        sw   x10, 0(x9)           # firma[4]
        addi x9, x9, 4
        # sig[5] = and de 2 datos
        lw   x5, 24(x3)
        and  x5, x5, x6
        lw   x10, 24(x3)
        and  x10, x10, x6
        and  x10, x10, x5
        sw   x10, 0(x9)          # firma[5]
        addi x9, x9, 4
        li   x5, 0xFFFFFFFF
        sw   x5, 16(x3)

# -----------------------------------------------------------------------------
#  Paso 5: broadcast wc=2 -> BCR en ambos
# -----------------------------------------------------------------------------
        li   x5, 0x0000B4B4
        sw   x5, 20(x3)
        li   x5, 0x0000B5B5
        sw   x5, 20(x3)
        # MSG: rtrt=0 tr=0 rt=31 sa=6 wc=2 -> 0x0000237C
        li   x5, 0x0000237C
        sw   x5, 12(x3)
        jal  x1, do_go
        # esperar un poco a que se asienten los BCR
        li   x8, 500
w_bc:   addi x8, x8, -1
        bne  x8, x0, w_bc
        lw   x10, 16(x3)          # STAT
        # sig[6] = (RT0_BCR<<1)|RT1_BCR ; b26=RT0_BCR, b27=RT1_BCR
        srli x5, x10, 26          # b26 -> bit0
        andi x5, x5, 3            # {RT1_BCR, RT0_BCR} en bits {1,0}? b26,b27
        # b26=RT0_BCR (bit0 tras shift), b27=RT1_BCR (bit1 tras shift)
        # queremos (RT0_BCR<<1)|RT1_BCR = swap de los dos bits
        andi x6, x5, 1            # RT0_BCR
        slli x6, x6, 1            # <<1
        srli x7, x5, 1           # RT1_BCR
        or   x7, x7, x6
        lui  x6, 0x10
        addi x6, x6, -1           # restaurar mascara 0xFFFF en x6
        sw   x7, 0(x9)           # firma[6]
        addi x9, x9, 4
        # drenar las 4 palabras de broadcast (2 RT0 + 2 RT1)
        addi x8, x0, 4
p5rx:   lw   x10, 24(x3)
        addi x8, x8, -1
        bne  x8, x0, p5rx
        li   x5, 0xFFFFFFFF
        sw   x5, 16(x3)

# -----------------------------------------------------------------------------
#  Paso 6: timeout (RT ausente = 12)
# -----------------------------------------------------------------------------
        # MSG: rtrt=0 tr=1 rt=12 sa=2 wc=2 -> 0x00002132
        li   x5, 0x00002132
        sw   x5, 12(x3)
        jal  x1, do_go
        lw   x10, 16(x3)          # STAT
        srli x5, x10, 18          # b18 = TOUT
        andi x5, x5, 1
        beq  x5, x0, no_tout
        li   x7, 0x0000DEAD
        jal  x0, sig7
no_tout:addi x7, x0, 0
sig7:   sw   x7, 0(x9)           # firma[7]
        addi x9, x9, 4
        li   x5, 0xFFFFFFFF
        sw   x5, 16(x3)

# -----------------------------------------------------------------------------
#  Paso 7: DMA doorbell (RAM local 0..7 -> DDR)
# -----------------------------------------------------------------------------
        sw   x0, 0(x4)            # DMA SRC = local 0
        sw   x0, 4(x4)            # DMA DST = DDR offset 0
        addi x5, x0, 8
        sw   x5, 8(x4)            # DMA LEN = 8
        addi x5, x0, 3            # start | dir=1 (local->DDR)
        sw   x5, 12(x4)          # DMA CTRL
w_dma:  lw   x10, 16(x4)         # DMA STATUS
        andi x10, x10, 1         # busy
        bne  x10, x0, w_dma

        # doorbell PL->PS: sw a la palabra DONE_WORD (127) de la RAM local.
        # done_pulse en el top se dispara con un sw cuya direccion (bits alto=00
        # region local) tiene addr[ADDR_W-1:2] == DONE_WORD. Con DONE_WORD=127
        # el offset es 127*4 = 508 = 0x1FC.
        li   x6, 0x000001FC       # direccion de la palabra DONE_WORD
        addi x5, x0, 1
        sw   x5, 0(x6)            # done_pulse -> IRQ PL->PS

done:   jal  x0, done            # loop infinito (el PS toma el control)

# -----------------------------------------------------------------------------
#  subrutina: pulsa GO y espera DONE por polling de STAT.b16
# -----------------------------------------------------------------------------
do_go:  addi x5, x0, 4           # bit2 = GO
        sw   x5, 8(x3)            # CMD
wg:     lw   x10, 16(x3)         # STAT
        srli x5, x10, 16         # b16 = DONE
        andi x5, x5, 1
        beq  x5, x0, wg
        jalr x0, 0(x1)
