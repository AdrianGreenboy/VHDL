# =============================================================================
#  adcs_test.s  -  Firmware de bring-up del IP ADCS en el SoC RV32IM
#  Licencia: MIT
#
#  Secuencia:
#    1. Programa punteros DDR (H, g, U), dims y parametros en los registros del
#       ADCS (region 0xA000_0000).
#    2. START con MODE_LOAD_H  -> espera STATUS.done (el IP carga H de DDR).
#    3. START con MODE_MPC_PGD -> espera STATUS.done (solve + STORE_U a DDR).
#    4. Lee 5 palabras de U desde DDR (el IP ya las dejo alli por su maestro
#       propio), calcula una firma de 32 bits (rotl^xor, mismo esquema que las
#       capas de sim), la escribe con un sentinela en la RAM local, y dispara el
#       dma_burst del SoC para volcar el reporte a la DDR reservada con doorbell.
#
#  Registros del ADCS (base 0xA000_0000, offsets):
#    0x00 CTRL(START=bit0)  0x04 STATUS(done=bit0,busy=1,err=2)  0x08 MODE
#    0x0C NDIM  0x10 MAXITER  0x14 STEP(f32)  0x18 UMAX(f32)
#    0x1C HBASE  0x20 GBASE  0x24 UBASE  0x28 ITERCNT  0x2C VERSION  0x44 DEBUG
#
#  Registros del dma_burst del SoC (base 0x4000_0000):
#    0x00 SRC  0x04 DST  0x08 LEN(1..256)  0x0C CTRL(start=b0,dir=b1)  0x10 STATUS(busy=b0)
#
#  Convenciones de este SoC: DDR se accede via el dma_burst; la RAM local es la
#  region baja (0x0). El PS precarga H y g en DDR y lee el reporte por doorbell.
#  Punteros DDR aqui son OFFSETS desde ddr_base (el dma_burst suma ddr_base).
#
#  Parametros del caso de prueba (deben coincidir con el vector de sim):
#    n=8, maxiter=2, step=0.881230 (0x3F61984A), umax=0.05 (0x3D4CCCCD)
#    H en DDR offset 0x0000, g en 0x4000, U en 0x8000 (mismos que tb_adcs_top)
# =============================================================================

        # --- bases ---
        li   x5,  0xA0000000        # base regs ADCS
        li   x6,  0x40000000        # base regs dma_burst del SoC

        # --- programar punteros DDR y dims en el ADCS ---
        li   x7,  0x00000000        # HBASE (offset DDR)
        sw   x7,  28(x5)
        li   x7,  0x00002000        # GBASE
        sw   x7,  32(x5)
        li   x7,  0x00008000        # UBASE
        sw   x7,  36(x5)
        li   x7,  8                 # NDIM = 8
        sw   x7,  12(x5)
        li   x7,  2                 # MAXITER = 2
        sw   x7,  16(x5)
        li   x7,  0x3F61984A        # STEP = 0.881230f
        sw   x7,  20(x5)
        li   x7,  0x3D4CCCCD        # UMAX = 0.05f
        sw   x7,  24(x5)

        # --- START LOAD_H (MODE=2) ---
        li   x7,  2                 # MODE_LOAD_H
        sw   x7,  8(x5)
        li   x7,  1                 # CTRL.START
        sw   x7,  0(x5)
wait_h:
        lw   x8,  4(x5)          # STATUS
        andi x8,  x8, 1             # done bit
        beq  x8,  x0, wait_h

        # --- START MPC_PGD (MODE=0) ---
        li   x7,  0                 # MODE_MPC_PGD
        sw   x7,  8(x5)
        li   x7,  1                 # CTRL.START
        sw   x7,  0(x5)
wait_m:
        lw   x8,  4(x5)          # STATUS
        andi x8,  x8, 1
        beq  x8,  x0, wait_m

        # --- leer 5 palabras de U desde DDR via dma_burst (DDR->local) ---
        # trae U[0..4] (offset DDR 0x8000) a la RAM local en word 100 (0x190)
        li   x7,  0x00008000        # SRC = UBASE
        sw   x7,  0(x6)
        li   x7,  0x00000190        # DST local = word 100
        sw   x7,  4(x6)
        li   x7,  5                 # LEN = 5 palabras
        sw   x7,  8(x6)
        li   x7,  1                 # CTRL: start=1, dir=0 (DDR->local)
        sw   x7,  12(x6)
wait_d1:
        lw   x8,  16(x6)          # STATUS.busy
        andi x8,  x8, 1
        bne  x8,  x0, wait_d1

        # --- calcular firma rotl^xor sobre U[0..4] en RAM local ---
        li   x9,  0x00000190        # puntero local a U (byte addr = word*4? no:
                                    #   la RAM se direcciona por byte; word100=400)
        # OJO: DST del dma es indice de palabra local; en la RAM local el core
        # accede por direccion de byte. word 100 -> byte 400 = 0x190.
        li   x10, 0                 # firma = 0
        li   x11, 0                 # i = 0
        li   x12, 5                 # limite
sig_loop:
        lw   x13, 0(x9)             # U[i]
        # rotl(firma,1): (firma<<1) | (firma>>31)
        slli x14, x10, 1
        srli x15, x10, 31
        or   x10, x14, x15
        xor  x10, x10, x13
        addi x9,  x9, 4
        addi x11, x11, 1
        blt  x11, x12, sig_loop

        # --- escribir firma + sentinela en RAM local (words 4..5) ---
        li   x16, 0x0000D1A6        # sentinela (0xD1A6, estilo ptp_dump)
        sw   x16, 16(x0)            # local word 4 = sentinela
        sw   x10, 20(x0)            # local word 5 = firma
        sw   x8,  24(x0)            # local word 6 = ultimo STATUS (debug)

        # --- doorbell: dma_burst local->DDR (reporte) ---
        # sube words 4..6 (byte 16, 3 palabras) a DDR reservada offset 0xC000
        li   x7,  0x00000010        # SRC local = byte 16 (word 4)
        sw   x7,  0(x6)
        li   x7,  0x0000C000        # DST DDR = offset 0xC000 (reporte)
        sw   x7,  4(x6)
        li   x7,  3                 # LEN = 3 palabras
        sw   x7,  8(x6)
        li   x7,  3                 # CTRL: start=1, dir=1 (local->DDR)
        sw   x7,  12(x6)
wait_d2:
        lw   x8,  16(x6)
        andi x8,  x8, 1
        bne  x8,  x0, wait_d2

        # --- doorbell final: escribir palabra 127 de RAM local ---
        li   x17, 0x0000D0ED        # doorbell (0xD0ED)
        sw   x17, 508(x0)           # local word 127 = doorbell (byte 508)

done:
        beq  x0, x0, done          # loop infinito
