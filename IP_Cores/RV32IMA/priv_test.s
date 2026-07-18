        # === Paso 6b-1: viaje de privilegios M -> U -> M (ruta de userspace) ===
        li   x10, 0x10000000
        li   x11, 0x10000005
        li   x5, handler
        li   x4, 0x80000000
        add  x5, x5, x4
        csrrw x0, 0x305, x5       # mtvec
        # --- prueba A: mstatus es plano (lo escrito se lee tal cual) ---
        li   x6, 0x00AA0088
        csrrw x0, 0x300, x6
        csrrs x7, 0x300, x0
        bne  x7, x6, fallo
        li   x12, 65              # 'A'
        jal  x1, putc
        # --- prueba B: mret con MPP=00 baja a U-mode ---
        li   x6, 0x00000080       # MPIE=1, MPP=00 (U)
        csrrw x0, 0x300, x6
        li   x8, umode
        li   x4, 0x80000000
        add  x8, x8, x4
        csrrw x0, 0x341, x8       # mepc <- umode
        li   x20, 0               # marcador de fase
        mret                      # baja a U-mode y salta a umode
        jal  x0, fallo            # no debe ejecutarse
umode:  # --- ahora en U-mode ---
        li   x12, 66              # 'B' = llegamos a codigo tras el mret
        jal  x1, putc
        li   x20, 1               # fase: en U
        ecall                     # trap: causa DEBE ser 8 (desde U)
        # --- de vuelta en M tras el handler (mepc avanzado por el handler) ---
        li   x12, 69              # 'E' = round-trip completo
        jal  x1, putc
        jal  x0, fin
handler:
        # verificar mcause: 8 si venimos de U (x20=1)
        csrrs x21, 0x342, x0      # mcause
        li   x22, 1
        bne  x20, x22, h_fallo    # solo esperamos el ecall de U
        li   x22, 8
        bne  x21, x22, h_fallo    # causa 8 = ecall desde U-mode
        li   x12, 67              # 'C' = causa 8 correcta
        jal  x1, putc
        # verificar mstatus.MPP == 00 (el trap guardo el privilegio U)
        csrrs x23, 0x300, x0
        srli x23, x23, 11
        andi x23, x23, 3
        bne  x23, x0, h_fallo     # MPP debe ser 00 (veniamos de U)
        li   x12, 68              # 'D' = MPP registro el privilegio U
        jal  x1, putc
        # avanzar mepc mas alla del ecall y retornar (MPP=00... pero para
        # volver a M ponemos MPP=11 antes del mret, como hace el kernel)
        csrrs x24, 0x341, x0      # mepc
        addi x24, x24, 4
        csrrw x0, 0x341, x24
        csrrs x25, 0x300, x0
        li   x26, 0x1800
        or   x25, x25, x26        # MPP <- 11 (retornar a M)
        csrrw x0, 0x300, x25
        mret
h_fallo: li  x12, 70              # 'F'
        jal  x1, putc
        jal  x0, fin
fallo:  li   x12, 70
        jal  x1, putc
fin:    li   x12, 10
        jal  x1, putc
        li   x14, 0x11100000
        li   x15, 0x5555
        sw   x15, 0(x14)
done:   beq  x0, x0, done
putc:   lbu  x28, 0(x11)
        andi x28, x28, 32
        beq  x28, x0, putc
        sw   x12, 0(x10)
        jalr x0, 0(x1)
