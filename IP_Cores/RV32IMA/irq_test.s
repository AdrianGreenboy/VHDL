        # === Paso 6a-2: interrupciones de timer y software ===
        li   x10, 0x10000000      # UART THR
        li   x11, 0x10000005      # UART LSR
        li   x25, 0x11004000      # mtimecmp_lo
        li   x26, 0x1100BFF8      # mtime_lo
        # --- instalar handler (asm.py resuelve etiquetas sin la base) ---
        li   x5, handler
        li   x4, 0x80000000
        add  x5, x5, x4
        csrrw x0, 0x305, x5       # mtvec <- handler
        # --- prueba 1: con MIE=0 la interrupcion NO debe tomarse ---
        # programar mtimecmp muy cerca para que mtip suba pronto
        sw   x0, 4(x25)           # mtimecmp_hi <- 0 (reset lo deja en 0xFFFFFFFF)
        lw   x6, 0(x26)           # mtime_lo
        addi x6, x6, 24           # dispara durante espera1 (con MIE=0)
        sw   x6, 0(x25)           # mtimecmp_lo <- mtime+24
        li   x7, 128
        csrrs x0, 0x304, x7       # mie.MTIE = 1 (bit 7)
        # mstatus.MIE sigue en 0: NO debe haber trap
        li   x20, 0               # contador de interrupciones
        li   x6, 0                # marcador de mepc invalido
        li   x8, 200
espera1: addi x8, x8, -1
        bne  x8, x0, espera1      # gastar ciclos con mtip activo
        bne  x20, x0, fallo       # si hubo trap con MIE=0 -> fallo
        li   x12, 65              # 'A' = MIE=0 respetado
        jal  x1, putc
        # --- prueba 2: habilitar MIE, la interrupcion debe llegar ---
        li   x7, 8
        csrrs x0, 0x300, x7       # mstatus.MIE = 1 (bit 3)
        # Bucle de espera con efecto observable en cada vuelta: x9 cuenta
        # las iteraciones y x2 las duplica. Si un mepc desplazado hiciera
        # que el mret saltara una de las dos instrucciones, la relacion
        # x2 == 2*x9 se rompe y lo detectamos.
        li   x9, 0
        li   x2, 0
espera2: addi x9, x9, 1
        addi x2, x2, 2
        beq  x20, x0, espera2     # esperar la primera interrupcion
        # comprobar la invariante del bucle: x2 debe ser exactamente 2*x9
        add  x3, x9, x9
        bne  x2, x3, fallo        # mepc desplazado -> invariante rota
        beq  x20, x0, fallo
        li   x12, 66              # 'B' = interrupcion de timer tomada
        jal  x1, putc
        # --- prueba 3: verificar mcause (bit31=1, causa=7) ---
        li   x13, 7
        bne  x22, x13, fallo      # x22 = mcause & 0x7FFFFFFF
        bne  x23, x0, cause_ok    # x23 = bit 31 (debe ser != 0)
        jal  x0, fallo
cause_ok:
        li   x12, 67              # 'C' = mcause de interrupcion correcto
        jal  x1, putc
        # --- prueba 4: varias interrupciones seguidas ---
        li   x13, 3
espera3: blt  x20, x13, espera3   # esperar a 3 interrupciones
        li   x12, 68              # 'D' = reprogramacion del timer OK
        jal  x1, putc
        # --- prueba 5: deshabilitar MIE y confirmar que cesan ---
        li   x7, 8
        csrrc x0, 0x300, x7       # mstatus.MIE = 0
        add  x24, x20, x0         # guardar contador actual
        li   x8, 300
espera4: addi x8, x8, -1
        bne  x8, x0, espera4
        bne  x20, x24, fallo      # si subio, MIE=0 no se respeto
        li   x12, 69              # 'E' = MIE=0 detiene las interrupciones
        jal  x1, putc
        jal  x0, fin
fallo:  li   x12, 70              # 'F'
        jal  x1, putc
fin:    li   x12, 10              # '\n'
        jal  x1, putc
        li   x14, 0x11100000
        li   x15, 0x5555
        sw   x15, 0(x14)
done:   beq  x0, x0, done
        # --- putc ---
putc:   lbu  x13, 0(x11)
        andi x13, x13, 32
        beq  x13, x0, putc
        sw   x12, 0(x10)
        jalr x0, 0(x1)
        # --- handler de interrupciones ---
handler:
        addi x20, x20, 1          # contar la interrupcion
        csrrs x21, 0x342, x0      # x21 <- mcause
        # Verificacion fuerte de mepc: la instruccion interrumpida debe
        # REINTENTARSE. Contamos las ejecuciones del bucle de espera con un
        # contador que solo avanza si la instruccion se reintenta; si mepc
        # estuviera desplazado a pc+4, el mret saltaria fuera del bucle y
        # el contador quedaria descuadrado.
        csrrs x31, 0x341, x0      # x31 <- mepc (inspeccion)
        li   x28, 0x7FFFFFFF
        and  x22, x21, x28        # x22 = causa sin el bit 31
        srli x23, x21, 31         # x23 = bit 31 (1 = interrupcion)
        # reprogramar mtimecmp para la siguiente
        lw   x29, 0(x26)          # mtime_lo
        li   x30, 0x400           # margen amplio: el programa debe poder
        add  x29, x29, x30        # imprimir y avanzar entre interrupciones
        sw   x29, 0(x25)          # mtimecmp_lo <- mtime+0x400
        mret
