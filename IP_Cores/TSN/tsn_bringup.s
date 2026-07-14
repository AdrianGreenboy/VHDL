# tsn_bringup.s - bring-up del switch TSN 4x4: el core RV32IM controla el IP
# en 0x6000_0000, programa la tabla, inyecta 8 tramas por el inyector, lee los
# 20 contadores a RAM local, los copia a DDR por DMA y hace doorbell.
# Mapa: 0x0 RAM local (256 words) | 0x4000_0000 regs DMA | 0x6000_0000 IP TSN
#
# Programa IDENTICO a tb_tsn_soc.vhd / iss_tsn.py (SIG 64476b7f):
#   enable; tabla MAC(p)->p (p=0..3); 8 inyecciones; leer RX/TX/OVF/FCS/TAG.
#
# Firma en RAM local words 100..120 (bytes 400..480):
#   word100..119 = 20 contadores (RX0..3 TX0..3 OVF0..3 FCS0..3 TAG0..3)
#   word120      = 0x0000D0ED (sentinela)
# DMA: 21 palabras local[word100] -> DDR[0]. Doorbell: word 127.
#
# Mapa de registros del IP (offset de byte):
#   0x000 CONTROL  0x008 TBL_MAC_LO  0x00C TBL_MAC_HI  0x010 TBL_IDX
#   0x020 INJ_CTRL 0x024 INJ_LEN     0x028 INJ_WDATA   0x02C INJ_STATUS
#   0x040+ RX  0x050+ TX  0x060+ OVF  0x070+ FCS  0x080+ TAG
#
# asm.py: li = 2 palabras; jalr rd, N(rs1); offsets decimales; sin la/lbu/.byte.
# Las direcciones/constantes de 32 bits se cargan con li.

    li   x5, 0x60000000        # base IP TSN
    li   x31, 0x40000000       # base regs DMA

    # ---- enable ----
    li   x7, 0x1
    sw   x7, 0(x5)             # CONTROL = enable

    # ==== programar tabla: MAC(p) -> puerto p, idx p ====
    # MAC(p) = 02:00:00:00:00:(01+p). LO = 0x000000(01+p); HI = vld|port|0x0200
    # --- entrada 0: MAC ...01 -> puerto 0 ---
    li   x7, 0x00000001
    sw   x7, 8(x5)             # TBL_MAC_LO
    li   x7, 0x80000200        # vld=1 port=0 MAC[47:32]=0x0200
    sw   x7, 12(x5)            # TBL_MAC_HI
    li   x7, 0x0
    sw   x7, 16(x5)            # TBL_IDX=0 (dispara)
    # --- entrada 1: MAC ...02 -> puerto 1 ---
    li   x7, 0x00000002
    sw   x7, 8(x5)
    li   x7, 0x80010200        # vld=1 port=1
    sw   x7, 12(x5)
    li   x7, 0x1
    sw   x7, 16(x5)
    # --- entrada 2: MAC ...03 -> puerto 2 ---
    li   x7, 0x00000003
    sw   x7, 8(x5)
    li   x7, 0x80020200        # vld=1 port=2
    sw   x7, 12(x5)
    li   x7, 0x2
    sw   x7, 16(x5)
    # --- entrada 3: MAC ...04 -> puerto 3 ---
    li   x7, 0x00000004
    sw   x7, 8(x5)
    li   x7, 0x80030200        # vld=1 port=3
    sw   x7, 12(x5)
    li   x7, 0x3
    sw   x7, 16(x5)

    # ==== 8 inyecciones (valores verificados contra ISS, SIG 64476b7f) ====
    # cada inject empuja 15 palabras (60 B), fija LEN, dispara y espera.
    # x20=w0(dst[0..3]) x21=w1(dst[4],dst[5],src[0],src[1]) x22=w2(src[2..5])
    # x23=psel. inject_tag mete tag 802.1Q (contador TAG).
    # --- inj0 p0->MAC(1) ---
    li   x20, 0x00000002
    li   x21, 0x00020200
    li   x22, 0x01000000
    li   x23, 0x0
    jal  x1, inject
    # --- inj1 p2->MAC(3) ---
    li   x20, 0x00000002
    li   x21, 0x00020400
    li   x22, 0x03000000
    li   x23, 0x2
    jal  x1, inject
    # --- inj2 p1->bcast ---
    li   x20, 0xFFFFFFFF
    li   x21, 0x0002FFFF
    li   x22, 0x02000000
    li   x23, 0x1
    jal  x1, inject
    # --- inj3 p3->unknown flood ---
    li   x20, 0x0D0C0B0A
    li   x21, 0x00020F0E
    li   x22, 0x04000000
    li   x23, 0x3
    jal  x1, inject
    # --- inj4 p0->MAC(2) TAGGED ---
    li   x20, 0x00000002
    li   x21, 0x00020300
    li   x22, 0x01000000
    li   x23, 0x0
    jal  x1, inject_tag
    # --- inj5 p1->MAC(1) filtrada ---
    li   x20, 0x00000002
    li   x21, 0x00020200
    li   x22, 0x02000000
    li   x23, 0x1
    jal  x1, inject
    # --- inj6 p2->MAC(0) ---
    li   x20, 0x00000002
    li   x21, 0x00020100
    li   x22, 0x03000000
    li   x23, 0x2
    jal  x1, inject
    # --- inj7 p3->bcast ---
    li   x20, 0xFFFFFFFF
    li   x21, 0x0002FFFF
    li   x22, 0x04000000
    li   x23, 0x3
    jal  x1, inject

    # ==== leer los 20 contadores a RAM local (words 100..119) ====
    # RX 0x040..0x04C, TX 0x050.., OVF 0x060.., FCS 0x070.., TAG 0x080..
    lw   x7, 64(x5)
    sw   x7, 400(x0)           # word100 RX0
    lw   x7, 68(x5)
    sw   x7, 404(x0)           # RX1
    lw   x7, 72(x5)
    sw   x7, 408(x0)           # RX2
    lw   x7, 76(x5)
    sw   x7, 412(x0)           # RX3
    lw   x7, 80(x5)
    sw   x7, 416(x0)           # TX0
    lw   x7, 84(x5)
    sw   x7, 420(x0)           # TX1
    lw   x7, 88(x5)
    sw   x7, 424(x0)           # TX2
    lw   x7, 92(x5)
    sw   x7, 428(x0)           # TX3
    lw   x7, 96(x5)
    sw   x7, 432(x0)           # OVF0
    lw   x7, 100(x5)
    sw   x7, 436(x0)           # OVF1
    lw   x7, 104(x5)
    sw   x7, 440(x0)           # OVF2
    lw   x7, 108(x5)
    sw   x7, 444(x0)           # OVF3
    lw   x7, 112(x5)
    sw   x7, 448(x0)           # FCS0
    lw   x7, 116(x5)
    sw   x7, 452(x0)           # FCS1
    lw   x7, 120(x5)
    sw   x7, 456(x0)           # FCS2
    lw   x7, 124(x5)
    sw   x7, 460(x0)           # FCS3
    lw   x7, 128(x5)
    sw   x7, 464(x0)           # TAG0
    lw   x7, 132(x5)
    sw   x7, 468(x0)           # TAG1
    lw   x7, 136(x5)
    sw   x7, 472(x0)           # TAG2
    lw   x7, 140(x5)
    sw   x7, 476(x0)           # TAG3
    li   x7, 0x0000D0ED
    sw   x7, 480(x0)           # word120 sentinela

    # ==== DMA firma (21 palabras) local word100 -> DDR[0] ====
    addi x10, x0, 400          # src = byte 400 (word 100)
    addi x11, x0, 0            # dst = DDR offset 0
    addi x12, x0, 21           # len = 21 palabras
    addi x13, x0, 3            # ctrl = local->DDR
    jal  x1, dma_go

    # ==== doorbell ====
    addi x14, x0, 1
    sw   x14, 508(x0)          # word 127
halt:
    jal  x0, halt

# --- subrutina inject: x20=w0 x21=w1 x22=w2 x23=psel; usa x6,x8,x9 ---
# empuja 15 palabras (w0,w1,w2, ethertype+padding), fija LEN=60, dispara, espera.
inject:
    li   x6, 0x60000000
    li   x8, 0x2               # INJ clr buffer (b1)
    sw   x8, 44(x6)            # 0x02C
    sw   x20, 40(x6)           # 0x028 push w0
    sw   x21, 40(x6)           # push w1
    sw   x22, 40(x6)           # push w2
    li   x8, 0x00000008        # w3: byte12=0x08 byte13=0x00 (ethertype 0x0800)
    sw   x8, 40(x6)            # push w3 (bytes 12-15)
    li   x8, 0xA5A5A5A5        # padding
    addi x9, x0, 11            # quedan 15-4 = 11 palabras de padding
inj_pad:
    sw   x8, 40(x6)
    addi x9, x9, -1
    bne  x9, x0, inj_pad
    li   x8, 60
    sw   x8, 36(x6)            # 0x024 INJ_LEN = 60
    addi x8, x23, 4           # go (bit2) | psel
    sw   x8, 32(x6)            # 0x020 INJ_CTRL (dispara)
inj_wait:
    lw   x8, 44(x6)           # INJ_STATUS
    andi x8, x8, 0x1
    bne  x8, x0, inj_wait     # esperar busy=0
    # margen fijo de reenvio (~4000 ciclos): bucle de espera
    li   x8, 4000
inj_marg:
    addi x8, x8, -1
    bne  x8, x0, inj_marg
    jalr x0, 0(x1)

# --- subrutina inject_tag: como inject pero con tag 802.1Q en bytes 12-15 ---
# el ethertype real va desplazado; para el contador TAG basta 0x8100 en 12-13.
inject_tag:
    li   x6, 0x60000000
    li   x8, 0x2
    sw   x8, 44(x6)
    sw   x20, 40(x6)          # w0
    sw   x21, 40(x6)          # w1
    sw   x22, 40(x6)          # w2
    li   x8, 0x00008100       # w3: byte12=0x00? OJO: byte12 en [7:0]
    # byte12=0x81 byte13=0x00 => w3 bytes = 81,00,00,64 (TCI 0x0064) -> 0x64000081
    li   x8, 0x64000081
    sw   x8, 40(x6)           # push w3 (bytes 12-15: 81 00 00 64)
    li   x8, 0x00000008       # w4: byte16=0x08 byte17=0x00 (ethertype tras tag)
    sw   x8, 40(x6)           # push w4
    li   x8, 0xA5A5A5A5
    addi x9, x0, 10           # 15-5 = 10 palabras de padding
inj_tpad:
    sw   x8, 40(x6)
    addi x9, x9, -1
    bne  x9, x0, inj_tpad
    li   x8, 60
    sw   x8, 36(x6)
    addi x8, x23, 4
    sw   x8, 32(x6)
inj_twait:
    lw   x8, 44(x6)
    andi x8, x8, 0x1
    bne  x8, x0, inj_twait
    li   x8, 4000
inj_tmarg:
    addi x8, x8, -1
    bne  x8, x0, inj_tmarg
    jalr x0, 0(x1)

# --- subrutina DMA: x10=src x11=dst x12=len x13=ctrl; usa x14; ret x1 ---
dma_go:
    sw   x10, 0(x31)
    sw   x11, 4(x31)
    sw   x12, 8(x31)
    sw   x13, 12(x31)
dma_poll:
    lw   x14, 16(x31)
    bne  x14, x0, dma_poll
    jalr x0, 0(x1)
