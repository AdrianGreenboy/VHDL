#!/usr/bin/env python3
"""test_mmio_oracle.py - Audit 2026-11 self-test of the register-level oracle.
Checks the semantics the RTL now implements (see AUDIT_FIXES.md): region wrap,
empty region, W1C sticky flags, clr_cnt, re-arm, periodic accumulate."""
from ecc_oracle import encode
from mmio_oracle import (EccMmio, STATUS, CONTROL, REGION_BASE, REGION_LEN,
                         PERIOD, CE_COUNT, LAST_ADDR, INJ_ADDR, INJ_MASK_LO,
                         INJ_MASK_HI, INJ_CTRL)

D = 32
m = EccMmio(D)
m.load_clean([0x1000 + i for i in range(D)])

def inj(a, lo):
    m.write(INJ_ADDR, a); m.write(INJ_MASK_LO, lo); m.write(INJ_MASK_HI, 0)
    m.write(INJ_CTRL, 0x3)

# re-arm: two sweeps, each counts its own error
inj(5, 0x10); m.write(CONTROL, 0x3); assert m.read(CE_COUNT) == 1
inj(6, 0x10); m.write(CONTROL, 0x3); assert m.read(CE_COUNT) == 1
# W1C
assert m.read(STATUS) & 0x8
m.write(STATUS, 0x8); assert not (m.read(STATUS) & 0x8) and m.read(CE_COUNT) == 1
# clr_cnt
m.write(CONTROL, 0x4); assert m.read(CE_COUNT) == 0
# region with wrap
inj(1, 4); inj(5, 4); inj(30, 4)
m.write(REGION_BASE, 30); m.write(REGION_LEN, 4); m.write(CONTROL, 0x3)
assert m.read(CE_COUNT) == 2 and m.read(LAST_ADDR) == 1
assert m.mem[5] != encode(0x1005) and m.mem[1] == encode(0x1001)
m.write(REGION_LEN, 0); m.write(CONTROL, 0x3); assert m.read(CE_COUNT) == 0
m.write(REGION_BASE, 0); m.write(REGION_LEN, D)
# periodic accumulates, PERIOD=0 disarms
m.write(PERIOD, 40); m.write(CONTROL, 0x1)
assert m.read(STATUS) & 0x10
c0 = m.read(CE_COUNT); inj(9, 1 << 16); m.periodic()
assert m.read(CE_COUNT) == c0 + 1 and m.mem[9] == encode(0x1009)
m.write(PERIOD, 0); assert not (m.read(STATUS) & 0x10)
print("TEST_MMIO_ORACLE PASS")
