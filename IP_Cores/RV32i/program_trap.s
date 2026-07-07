# Prueba de CSRs + traps (ECALL / MRET)
        addi  x5, x0, handler    # x5 = direccion del manejador
        csrw  mtvec, x5          # mtvec = handler
        addi  x6, x0, 111        # x6 = 111 (antes del trap)
        ecall                    # trap -> handler ; mepc = pc(ecall)
        addi  x7, x0, 222        # (punto de retorno) x7 = 222
        beq   x0, x0, done_main  # salta al final
handler:
        csrr  x28, mcause        # x28 = mcause (11 = ecall desde M)
        addi  x29, x0, 42        # x29 = 42 (prueba de que el handler corrio)
        csrr  x30, mepc          # x30 = mepc (direccion del ecall)
        addi  x30, x30, 4        # mepc + 4 (para retornar despues del ecall)
        csrw  mepc, x30          # escribe mepc de vuelta
        mret                     # retorna a mepc
done_main:
        beq   x0, x0, done_main  # loop infinito
