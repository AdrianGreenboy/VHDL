        # === Paso 6a-1: CSR + traps por excepcion ===
        li   x10, 0x10000000      # UART THR
        li   x11, 0x10000005      # UART LSR
        # --- instalar el handler en mtvec ---
        # asm.py resuelve etiquetas como offset desde 0; el core corre
        # desde 0x80000000, asi que sumamos la base de carga.
        li   x5, handler
        li   x4, 0x80000000
        add  x5, x5, x4
        csrrw x0, 0x305, x5       # mtvec <- 0x80000000 + handler
        # --- probar mscratch: escribir y leer ---
        li   x6, 0x12345678
        csrrw x0, 0x340, x6       # mscratch <- 0x12345678
        csrrs x7, 0x340, x0       # x7 <- mscratch (lectura pura)
        beq  x6, x7, mscratch_ok
        li   x12, 70              # 'F' fallo
        jal  x1, putc
        jal  x0, fin
mscratch_ok:
        li   x12, 65              # 'A' = mscratch OK
        jal  x1, putc
        # --- probar csrrs con set de bits ---
        li   x8, 0x0000000F
        csrrw x0, 0x340, x0       # mscratch <- 0
        csrrs x9, 0x340, x8       # mscratch |= 0xF ; x9 = valor viejo (0)
        csrrs x9, 0x340, x0       # x9 <- mscratch (debe ser 0xF)
        li   x13, 0x0000000F
        beq  x9, x13, csrrs_ok
        li   x12, 70              # 'F'
        jal  x1, putc
        jal  x0, fin
csrrs_ok:
        li   x12, 66              # 'B' = csrrs OK
        jal  x1, putc
        # --- probar csrrc con clear de bits ---
        li   x8, 0x00000005
        csrrc x9, 0x340, x8       # mscratch &= ~0x5 -> 0xA
        csrrs x9, 0x340, x0
        li   x13, 0x0000000A
        beq  x9, x13, csrrc_ok
        li   x12, 70
        jal  x1, putc
        jal  x0, fin
csrrc_ok:
        li   x12, 67              # 'C' = csrrc OK
        jal  x1, putc
        # --- disparar ECALL: el handler imprime 'D' y retorna ---
        li   x20, 0               # contador de traps atendidos
        ecall
        # tras el mret volvemos aqui
        li   x13, 1
        beq  x20, x13, ecall_ok
        li   x12, 70
        jal  x1, putc
        jal  x0, fin
ecall_ok:
        li   x12, 69              # 'E' = ecall+mret OK
        jal  x1, putc
        # --- verificar mcause y mepc guardados por el trap ---
        li   x13, 11              # cause 11 = ecall from M-mode
        beq  x21, x13, cause_ok
        li   x12, 70
        jal  x1, putc
        jal  x0, fin
cause_ok:
        li   x12, 71              # 'G' = mcause OK
        jal  x1, putc
fin:    li   x12, 10              # '\n'
        jal  x1, putc
        li   x14, 0x11100000
        li   x15, 0x5555
        sw   x15, 0(x14)          # poweroff
done:   beq  x0, x0, done
        # --- subrutina putc ---
putc:   lbu  x13, 0(x11)
        andi x13, x13, 32
        beq  x13, x0, putc
        sw   x12, 0(x10)
        jalr x0, 0(x1)
        # --- handler de traps ---
        # imprime 'D', incrementa x20, guarda mcause en x21,
        # avanza mepc para saltar la instruccion ecall, y retorna.
handler:
        addi x20, x20, 1          # contamos el trap
        csrrs x21, 0x342, x0      # x21 <- mcause
        csrrs x22, 0x341, x0      # x22 <- mepc
        addi x22, x22, 4          # apuntar despues del ecall
        csrrw x0, 0x341, x22      # mepc <- mepc+4
        li   x12, 68              # 'D' desde el handler
        jal  x1, putc
        mret
