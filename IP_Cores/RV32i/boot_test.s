# =============================================================================
#  boot_test.s - audit-2026-11 boot-ROM test program (tb_boot_rom).
#  Runs straight out of the boot ROM image copied by boot_loader: sums 1..10
#  into DMEM word 64 and rings the doorbell (DMEM word 127) -> irq_out.
# =============================================================================
        addi  x1, x0, 0             # acc
        addi  x2, x0, 1             # i
        addi  x3, x0, 11            # limit
loop:   add   x1, x1, x2
        addi  x2, x2, 1
        blt   x2, x3, loop
        sw    x1, 256(x0)           # DMEM[64] = 55
        lw    x4, 256(x0)           # read back (sync DMEM path)
        addi  x4, x4, 1
        sw    x4, 260(x0)           # DMEM[65] = 56
        addi  x5, x0, 1
        sw    x5, 508(x0)           # doorbell DMEM[127]
halt:   beq   x0, x0, halt
