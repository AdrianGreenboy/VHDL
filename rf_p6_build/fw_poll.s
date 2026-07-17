; fw_poll.s - Firmware de captura RF por polling (capa 4).
; Programa el lazo RF, espera por RX_FIFO_LEVEL >= N, dispara DMA a DDR y halt.
; Registros base: a0 = RF_BASE (0x60000000), a1 = DDR_BASE (0x70000000).
; Constantes: N_CAP = 64 muestras.
start:
    lui  a0, 0x60000        ; a0 = 0x60000000 (RF_BASE)
    lui  a1, 0x70000        ; a1 = 0x70000000 (DDR_BASE)
    ; programar FTW = 0x0293A800  (0x800 no cabe en imm12; usar 0x0293B - 2048)
    lui  t0, 0x0293B        ; t0 = 0x0293B000
    addi t0, t0, -2048      ; t0 = 0x0293A800  (-2048 es el limite inferior valido)
    sw   t0, 0x08(a0)       ; NCO_FTW
    ; cargar coeficientes passthrough del RX FIR: tap0 = 0x7FFF, tap1..15 = 0
    ; FIR_COEF_ADDR=0x14, FIR_COEF_DATA=0x18. Escribir DATA dispara coef_we.
    addi t6, zero, 0        ; addr = 0
    sw   t6, 0x14(a0)       ; FIR_COEF_ADDR = 0
    lui  t1, 0x8            ; t1 = 0x8000
    addi t1, t1, -1        ; t1 = 0x7FFF
    sw   t1, 0x18(a0)       ; FIR_COEF_DATA = 0x7FFF  (tap0)
    addi s2, zero, 1        ; k = 1
    addi s3, zero, 16       ; limite
coefloop:
    sw   s2, 0x14(a0)       ; FIR_COEF_ADDR = k
    sw   zero, 0x18(a0)     ; FIR_COEF_DATA = 0  (tap k)
    addi s2, s2, 1
    blt  s2, s3, coefloop
    ; rx_en = 1, loop_en = 1  (CTRL bit0 y bit2 = 0x5)
    addi t1, zero, 0x5
    sw   t1, 0x00(a0)       ; CTRL
    ; esperar hasta RX_FIFO_LEVEL >= 64
    addi t2, zero, 64       ; umbral
wait_lvl:
    lw   t3, 0x1C(a0)       ; RX_FIFO_LEVEL
    blt  t3, t2, wait_lvl   ; si nivel < 64, seguir esperando
    ; configurar DMA: addr = DDR_BASE, len = 64, ctrl = 1 (start)
    sw   a1, 0x34(a0)       ; DMA_ADDR
    addi t4, zero, 64
    sw   t4, 0x38(a0)       ; DMA_LEN
    addi t5, zero, 1
    sw   t5, 0x3C(a0)       ; DMA_CTRL (dispara)
    ecall
