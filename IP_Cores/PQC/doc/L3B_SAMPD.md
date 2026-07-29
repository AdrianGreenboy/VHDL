# Layer 3B: ML-DSA samplers

Status: PASS.

    PQC L3B SAMPD PASS ntt=9 bnd=8 msk=8 ball=8 sig=b518e5241f86de0f

Thirty-three cases against mldsa65.py, compared coefficient by coefficient.
Twelve mutations, all killed.

One unit with four modes, sharing the Keccak sponge that is already
silicon-validated from the ML-KEM phase:

    "00"  RejNTTPoly     (ExpandA)     SHAKE128, 3 bytes per candidate
    "01"  RejBoundedPoly (ExpandS)     SHAKE256, 2 nibbles per byte
    "10"  ExpandMask                   SHAKE256, no rejection
    "11"  SampleInBall                 SHAKE256, rejection on index

## The refill that is not a restart

The reference model, on running short of stream, squeezes a LONGER output and
re-parses from the beginning. Read literally that is a restart, and building
the RTL around it would mean carrying restart bookkeeping and re-deriving
already-accepted coefficients.

It is not a restart. SHAKE is an extendable output function, so a longer
squeeze is a prefix-extension of the shorter one and the accepted
coefficients are identical either way. This was checked against the oracle
over 200 seeds before any RTL was written, comparing a continuous-squeeze
implementation against the model's re-squeeze version. The sequencer
therefore pulls bytes on demand from one continuous stream and never
restarts.

Measured worst-case consumption over those 200 seeds:

    RejNTTPoly      774 bytes    acceptance rate q/2^23 = 0.9990
    RejBoundedPoly  250 bytes    acceptance rate 9/16   = 0.5625
    ExpandMask      640 bytes    fixed, exactly 32 * 20 bits
    SampleInBall    264 bytes

No budget is hardcoded in the RTL: each mode reads until it has 256 accepted
coefficients, so an unlucky seed simply consumes more stream. The testbench
supplies a bounded stream and fails if a sampler reads past it, which is how
a rejection loop that never terminates would present itself.

## Two surviving mutations, two different diagnoses

Both were investigated before changing anything, because a surviving mutation
is a hypothesis rather than a conclusion. They turned out to be different in
kind.

### M2 was a real coverage gap

Accepting z == q instead of rejecting it survived. The condition arises with
probability 2^-23, so across the roughly 2048 candidates the SHAKE-derived
vectors draw it is expected 0.0002 times. The branch was live but unvisited.

The fix is the same shape as the Decaps byte-0 rejection vectors: a synthetic
stream whose first candidate is exactly q, appended as a ninth SNTT case. It
is deliberately not a SHAKE output, because the sampler must reject z == q
regardless of where the bytes came from and the sponge is verified elsewhere.
With that case present M2 is killed.

### M7 was a no-op mutation

Changing the emit threshold from nbit >= 20 to nbit >= 19 survived, and no
input could have killed it. Bytes arrive 8 bits at a time and the accumulator
drops by 20 per emitted coefficient, so nbit only ever takes the values
8, 12, 16, 20 and 24. It is never exactly 19, which makes the two thresholds
indistinguishable.

That is a badly formulated mutation, not a test gap. Rewritten to corrupt the
field mask, acc(19 downto 0) to acc(18 downto 0), which is what actually
selects the coefficient bits, and then killed.

## Representation

Samplers emit signed representatives, matching the rest of the ML-DSA
datapath, and the testbench canonicalises into [0, q) before comparing. This
showed up first in ExpandMask, where GAMMA1 - field is negative for roughly
half the coefficients while the oracle stores the value reduced modulo q. The
two differ by exactly q and denote the same element; requiring the RTL to
reduce would add cycles the algorithm never asks for.
