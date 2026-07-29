# Layer 3B: ML-DSA rounding primitives

Status: PASS.

    PQC L3B ROUNDD PASS vectors=49 sweep=4096 sig=126e9be822432668

Power2Round, Decompose (HighBits and LowBits) and UseHint, as pure functions.
Forty-nine vectors including every interesting boundary, plus a 4096-point
sweep checking the defining identities. Ten mutations, all killed.

## Verified exhaustively, not by sampling

Before any RTL was written, the intended implementations were checked against
mldsa65.py over ALL 8380417 residues:

    power2round   0 mismatches
    decompose     0 mismatches
    r - (r*MUL >> SH)*2*GAMMA2 == r mod 2*GAMMA2   0 mismatches

That matters here more than elsewhere. A comparison written as >= instead of
> flips a whole class of inputs, and a divide constant off by one is exact for
small values and wrong only near the top of the range. Both defects are
invisible to a handful of random vectors: mutations M1, M2 and M5 inject
exactly those and are killed only because the boundary residues are in the
vector list and the sweep reaches the top of the modulus.

## No dividers in the datapath

Two divisions appear in the specification and neither survives into RTL.

Decompose divides by 2*GAMMA2 = 523776 and also needs the remainder. Both
come from one multiply-shift, mul 8396809 then shift right 42: the quotient
directly, the remainder as r - quotient*2*GAMMA2. A `mod` operator would
synthesise a real divider, and a sixteen-deep subtract chain would be no
better.

UseHint computes (r1 +- 1) mod m with m = (q-1)/(2*GAMMA2) = 16. Sixteen is a
power of two, so this is a 4-bit wraparound rather than a modulo. That holds
only because r1 never leaves [0, 15], which was checked against the oracle
rather than assumed, and the testbench asserts the bound on every sweep point.

## Bugs found

Three, all mine, and the third is worth recording because the testbench was
wrong rather than the RTL.

1. **Width truncation in p2r_lo.** signed('0' & r(12 downto 0)) is 14 bits
   assigned to a 15-bit variable.

2. **Product width in twog2_quot.** resize(r,64) * to_unsigned(c,32) is 96
   bits assigned to 64. This is the same defect that bit mont_d in
   ntt_d_unit: the product width is the sum of the operand widths, not the
   width of the destination. Fixed by sizing the operands explicitly, 24 by
   24 into 48.

3. **The testbench identity was off by one.** The sweep asserted
   r1*2*GAMMA2 + r0 = r, allowing r - q + 1 at the wraparound. The correct
   alternative is r - q. This flagged CORRECT RTL at r = 8120449, where the
   oracle also returns (0, -259968). The RTL was right and the check was
   wrong, which is worth stating plainly: the first instinct on a failure is
   to suspect the design, and here that instinct would have wasted the time.
