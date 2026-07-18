        # === Paso 6b-1: compatibilidad con el boot del kernel ===
        li   x10, 0x10000000      # UART THR
        li   x11, 0x10000005      # UART LSR
        # --- prueba A: fence y fence.i se retiran como nop ---
        li   x5, 7
        fence
        addi x5, x5, 1            # debe ejecutarse tras la fence
        fence.i
        addi x5, x5, 1
        li   x6, 9
        bne  x5, x6, fallo
        li   x12, 65              # 'A'
        jal  x1, putc
        # --- prueba B: lh/lhu con extension de signo ---
        li   x13, 0x80000800
        li   x14, 0xFFFF8123
        sw   x14, 0(x13)          # mem = 0xFFFF8123
        lh   x15, 0(x13)          # half bajo 0x8123 -> signo: 0xFFFF8123
        bne  x15, x14, fallo
        lhu  x16, 0(x13)          # sin signo: 0x00008123
        li   x17, 0x00008123
        bne  x16, x17, fallo
        lh   x18, 2(x13)          # half alto 0xFFFF -> 0xFFFFFFFF
        li   x19, -1
        bne  x18, x19, fallo
        li   x12, 66              # 'B'
        jal  x1, putc
        # --- prueba C: mhartid lee 0 ---
        csrrs x20, 0xF14, x0
        bne  x20, x0, fallo
        li   x12, 67              # 'C'
        jal  x1, putc
        # --- prueba D: PMP se escribe/lee sin trap y lee 0 ---
        li   x21, 0x1F
        csrrw x0, 0x3A0, x21      # pmpcfg0: escritura ignorada
        csrrs x22, 0x3A0, x0      # lectura: 0
        bne  x22, x0, fallo
        csrrw x0, 0x3B0, x21      # pmpaddr0
        csrrs x23, 0x3B0, x0
        bne  x23, x0, fallo
        li   x12, 68              # 'D'
        jal  x1, putc
        # --- prueba E: mip refleja mtip (timer disparado, MIE=0) ---
        li   x25, 0x11004000
        sw   x0, 4(x25)           # mtimecmp_hi = 0
        li   x7, 1
        sw   x7, 0(x25)           # mtimecmp_lo = 1 (no-cero: armado; con
                                  # mtime > 1 el mtip sube de inmediato)
        li   x8, 30
esp_e:  addi x8, x8, -1
        bne  x8, x0, esp_e
        csrrs x24, 0x344, x0      # mip
        srli x24, x24, 7
        andi x24, x24, 1          # bit MTIP
        li   x9, 1
        bne  x24, x9, fallo
        li   x12, 69              # 'E'
        jal  x1, putc
        # --- prueba G: wfi habilita mstatus.MIE (paridad emulador) ---
        li   x7, 8
        csrrc x0, 0x300, x7       # MIE <- 0
        # nota: mie (0x304) sigue en 0 -> el wfi no puede disparar nada,
        # solo debe dejar mstatus.MIE=1
        wfi
        csrrs x9, 0x300, x0
        andi x9, x9, 8
        beq  x9, x0, fallo        # MIE debe haber quedado en 1
        li   x12, 71              # 'G'
        jal  x1, putc
        jal  x0, fin
fallo:  li   x12, 70              # 'F'
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
