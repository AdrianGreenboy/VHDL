# Layer 3B scope freeze: ML-DSA-65 Sign

Frozen with Adrian before any RTL. Changing any of this later invalidates
signatures, so it is recorded here rather than left implicit in the testbench.

## Checkpoints (frozen)

  SP1  y of the FIRST iteration, straight out of ExpandMask
  SP2  w1 after Decompose, first iteration
  SP3  c_tilde, the challenge
  SP4  candidate z of the FIRST iteration, EVEN IF THAT ITERATION IS REJECTED
  SP5  final kappa and the complete signature

SP4 is the one that earns its place. If the loop rejects correctly but the
candidate was computed wrongly, SP5 can still land on the right answer by
compensation. This is the same reasoning that separated EP4 from EP5 in
Encaps, where lifting both basemul operands left u correct and corrupted only
v, so a checkpoint on u alone would have passed with a wrong ciphertext.

## End-of-simulation signature (frozen)

The signature covers the produced bytes AND the final kappa.

Including kappa is deliberate. Everywhere in ML-KEM the signature covers only
produced data, never cycle counts, because rejection sampling makes timing
non-portable. kappa is different: it is not a timing measurement, it is a
deterministic function of the inputs, and it is the only observable that
distinguishes "the loop ran the right number of times" from "the loop
happened to produce the right bytes". A mutation that changes the iteration
count while still terminating on a valid signature would otherwise survive.

## Constant-time criterion (frozen)

The Decaps criterion does not apply and must not be reused. In Decaps the
total spread was bounded because the runtime should not depend on the
ciphertext. In Sign the runtime MUST vary: the rejection loop runs a
data-dependent number of times.

The property is weaker and narrower: ML-DSA is constant time with respect to
the SECRET KEY, not with respect to the message. No timing assertion on total
runtime will be written for Sign. Nothing weaker will be silently substituted
either; if a timing property is tested at all it will be stated explicitly.

## Measured loop behaviour, 8 ACVP vectors (deterministic variant)

  vec  iters  final kappa  rejection reasons
   0     3       15        r0, r0
   1     7       35        r0, z, r0, r0, z, r0
   2     5       25        r0, r0, r0, z
   3     4       20        z, z, z
   4     1        5        none
   5    12       60        r0, z, r0, z, z, z, r0, r0, r0, r0, z
   6     2       10        r0
   7     1        5        none

  LL = 5, so kappa = 5 * iters. Range 1 to 12 iterations.

Vectors 4 and 7 accept on the first iteration, so SP4 is observable both with
and without a preceding rejection across this set.

## Rejection branch coverage: RESOLVED, and the two cases differ

Sign has FOUR rejection conditions. The ACVP vectors exercise two:

  z    ||z||inf >= GAMMA1 - BETA        11 times
  r0   ||LowBits(w - c*s2)||inf >= ...  16 times
  ct0  ||c*t0||inf >= GAMMA2             never
  h    hint weight > OMEGA               never

Both untaken branches were investigated. They turned out to be different in
kind, which matters for how each is handled.

### h (hint weight) is reachable: construct inputs

Across the ACVP vectors the hint weight peaks at 48 of OMEGA = 55, so the
branch is live and merely unvisited. A short search over messages against the
existing keys found one on the eighth attempt:

    message b"hintprobe-000008" against the vector 6 key triggers h

That case will be added to the vector file so the h mutation can be killed.
This is the same shape of fix as the Decaps byte-0 rejection vectors.

### ct0 is UNREACHABLE: it is a defensive check, not a live branch

The ct0 rejection cannot be triggered by any well-formed key. t0 holds the
low D bits from Power2Round, so every coefficient satisfies |t0| <= 2^(D-1)
= 4096, and c has exactly TAU = 49 nonzero coefficients of magnitude 1.
Therefore

    ||c*t0||inf  <=  TAU * 2^(D-1)  =  49 * 4096  =  200704
    GAMMA2                                        =  261888

so the condition ||c*t0||inf >= GAMMA2 is unsatisfiable. This is not a gap in
the vector set.

It was checked rather than argued. Over 40 freshly generated keys the maximum
observed was 73143, 27.9 percent of GAMMA2. A t0 built adversarially to
maximise the product against the actual challenge, choosing each coefficient
to match the sign of its negacyclic partner, reached exactly 200704, which is
the theoretical bound to the digit, and still 76.6 percent of GAMMA2.

Consequence for the mutation set: a mutation that removes or breaks the ct0
check CANNOT be killed by any input, and must not be written as though it
could. It will be recorded as an unreachable defensive check with the bound
above as the justification, rather than left as a silently surviving mutation
or quietly dropped. The check stays in the RTL because it costs little and
guards against a malformed key reaching the signing path, but the test suite
will state plainly that it is not exercised and why.
