# =============================================================================
#  exc_test.s - audit-2026-11 directed test of synchronous exceptions
#  (tb_exc). Every trap is logged by the handler as (mcause, mtval) pairs at
#  DMEM byte 0x100 upward; the handler returns to mepc+4. The testbench checks
#  the log, the trap count and the architectural state (registers/memory).
#  Register use: x31 log pointer, x30 trap count, x27-x29 handler scratch,
#  x5 mtvec setup, x9 = 0, x11/x15/x17 sentinels (must survive faulting ops).
# =============================================================================
        addi  x5, x0, handler
        csrw  mtvec, x5
        addi  x31, x0, 256          # log at DMEM 0x100
        addi  x30, x0, 0            # trap count
        addi  x9, x0, 0             # x9 = 0 (non-x0 register holding zero)
        li    x10, 0x11223344
        sw    x10, 0(x0)            # mem[0] = 0x11223344
        li    x11, 0x5A5A5A5A       # sentinel for faulting loads
        addi  x15, x0, 1365         # sentinel for faulting jalr (0x555)
        addi  x17, x0, 1911         # sentinel for load-use + misaligned (0x777)
t_ill0: .word 0x00000000            # T1 illegal: all zeros
t_ill1: .word 0xFFFFFFFF            # T2 illegal: all ones
t_ill2: .word 0x4000F033            # T3 illegal: OP_REG funct7=0100000 with AND
t_ill3: .word 0x00200073            # T4 illegal: SYSTEM f3=000, unknown imm (uret)
t_ill4: .word 0x00004073            # T5 illegal: SYSTEM f3=100
t_ill5: .word 0x7C002373            # T6 illegal: csrrs x6, 0x7C0, x0 (unimplemented CSR)
t_ill6: csrw  mhartid, x10          # T7 illegal: write to read-only CSR
        csrrs x6, mhartid, x0       # legal: pure read of RO CSR (rs1 = x0) -> x6 = 0
t_ill7: csrrs x7, mhartid, x9       # T8 illegal: rs1 = x9 (holds 0) is still a write attempt
        csrr  x8, misa              # legal: x8 = 0x40001100
t_lw1:  lw    x11, 1(x0)            # T9  load misaligned, mtval = 1
t_lh3:  lh    x11, 3(x0)            # T10 load misaligned, mtval = 3
        lhu   x12, 2(x0)            # legal: x12 = 0x00001122
        lb    x13, 3(x0)            # legal: x13 = 0x00000011
t_sw2:  sw    x10, 2(x0)            # T11 store misaligned, mtval = 2 (memory untouched)
t_sh5:  sh    x10, 5(x0)            # T12 store misaligned, mtval = 5
        sb    x0, 1(x0)             # legal: mem[0] = 0x11220044
        lw    x14, 0(x0)            # x14 = 0x11220044
        addi  x16, x0, t_tgt
t_jr:   jalr  x15, 2(x16)           # T13 instr misaligned, mtval = t_tgt+2, x15 kept
t_jal:  .word 0x0020006F            # T14 jal x0, +2 -> instr misaligned, mtval = t_jal+2
t_beq:  .word 0x00000163            # T15 beq x0, x0, +2 (taken) -> mtval = t_beq+2
        .word 0x00001163            # bne x0, x0, +2 (not taken): no trap
        fence                       # legal NOP
        fence.i                     # legal NOP
        wfi                         # legal NOP
t_ecall: ecall                      # T16 ecall: mcause 11, mtval must be 0
t_lu:   lw    x17, 1(x0)            # T17 misaligned load while the next instr waits on it
        addi  x18, x17, 1           # executes after the trap: x18 = 0x778
        sw    x30, 252(x0)          # trap count -> mem[63]
t_tgt:  beq   x0, x0, t_tgt         # done (also the aligned jalr base)
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
