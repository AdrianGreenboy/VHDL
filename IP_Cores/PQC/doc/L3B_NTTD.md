# Layer 3B: ML-DSA NTT-D datapath

Status: PASS.

    PQC L3B NTTD PASS fwd=10 inv=10 pmul=10 sig=b0594944690ca09f

Thirty cases against mldsa65.py, compared coefficient by coefficient: ten
forward transforms, ten inverse transforms, ten coefficient-wise products.
Ten mutations, all killed.

## Three differences from the Kyber datapath

Structurally this is ntt_unit with the widths doubled, but three things
differ and each is a place to get it wrong quietly.

### The product is coefficient-wise, not a paired basemul

Kyber needs basemul because x^256+1 factors into 128 quadratics over its
modulus, so coefficients pair up and each pair carries a zeta twist. The
Dilithium modulus admits a full 256-point transform, so the product is
simply a[i]*b[i] with no pairing and no zeta. One unit therefore serves all
three operations.

### The Montgomery constant is sign-specific

The reduction uses the subtractive convention

    t = (a * C_QINVD) truncated to signed 32
    r = (a - t * q) >> 32

which requires C_QINVD = 58728449. The value 4236238847 that appears
elsewhere is the same number negated modulo 2^32; it is q^-1 for the ADDITIVE
convention. Both appear in the literature and substituting one for the other
produces plausible-looking wrong products rather than an obvious failure.
This was checked rather than assumed: 4236238847 = -58728449 mod 2^32, and
only 58728449 satisfies the subtractive identity over 2000 random pairs.
Mutation M1 flips the sign and is killed.

### Coefficients are signed 32-bit with no intermediate reduction

Growth was measured rather than bounded on paper: the forward transform peaks
at 28015249 and the inverse at 99120476 across 40 random polynomials, needing
26 and 28 signed bits. 32 bits leaves more than fourfold headroom, so no
reduction is inserted between layers.

The testbench compares canonically, reducing into [0, q) before checking. The
datapath is correct modulo q without being reduced, and forcing it to reduce
would cost cycles the algorithm never asks for.

## Bugs found during bring-up

Three, two of them mine and one worth recording as a pattern.

1. **midx frozen at a len boundary.** The oracle increments the root index at
   the top of every start-loop iteration, which includes the first block of
   each new layer. My first version advanced it only within a layer, so the
   first block of each new len silently reused the previous root. The first
   butterfly was correct, which is what made it confusing: the failure
   appeared only after the first layer boundary. Mutation M2 re-injects it.

2. **Intermediate width overflow in mont_d.** resize(a,64) * to_signed(c,32)
   is 96 bits wide and was being assigned to a 64-bit variable. Only the low
   32 bits of that product are ever used, so the fix was to multiply the low
   32 bits of a by the constant and keep the low 32 of the result, which is
   arithmetically identical and keeps every intermediate inside a declared
   width.

3. **FNV accumulator truncation.** s * x"00000100000001b3" is 128 bits and
   needs an explicit resize to 64. GHDL catches this as a bound check failure
   at runtime rather than at analysis.

The debugging path for the first bug is worth noting: rather than reasoning
further about which zeta should apply where, the RTL was instrumented to
print the first few butterflies and compared against the same quantities
computed by hand from the oracle. The first butterfly matched exactly, which
localised the fault to the layer transition immediately.
