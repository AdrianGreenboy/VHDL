# =============================================================================
#  bus_err_test.s - audit-2026-11 directed test of AXI access faults
#  (tb_bus_err). DDR at core address 0x8000_0000 (mem_subsys AXI window);
#  the DDR model answers SLVERR for DDR word 8 (core address 0x8000_0020).
#  Handler logs (mcause, mtval) at local 0x100 and returns to mepc+4.
# =============================================================================
        addi  x5, x0, handler
        csrw  mtvec, x5
        addi  x31, x0, 256
        addi  x30, x0, 0
        li    x20, 0x80000000
        li    x10, 0xCAFEF00D
        sw    x10, 0(x20)           # OK: DDR[0]
        li    x11, 0x5A5A5A5A
        addi  x15, x0, 1911         # 0x777 sentinel
        lw    x11, 32(x20)          # T1 load access fault, mtval 0x80000020, x11 kept
        addi  x12, x11, 1           # consumer runs after return: 0x5A5A5A5B
        sw    x10, 32(x20)          # T2 store access fault, mtval 0x80000020
        lw    x13, 0(x20)           # OK: 0xCAFEF00D
        lw    x15, 32(x20)          # T3 load fault with a div right behind it
        div   x16, x10, x10         # = 1
        sw    x30, 252(x0)          # trap count -> local word 63
halt:   beq   x0, x0, halt
handler:
        csrr  x28, mcause
        sw    x28, 0(x31)
        csrr  x29, mtval
        sw    x29, 4(x31)
        addi  x31, x31, 8
        addi  x30, x30, 1
        csrr  x27, mepc
        addi  x27, x27, 4
        csrw  mepc, x27
        mret
