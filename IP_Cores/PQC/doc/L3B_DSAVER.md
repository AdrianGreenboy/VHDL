# Layer 3B: ML-DSA-65 Verify

    PQC L3B DSAVER PASS cases=22 accept=4 reject=18 sig=183a67e1ba95f501

Twenty ACVP sigver vectors plus two constructed cases. Four checkpoints.
Nine mutations, all killed.

## Reason codes, and why a verdict bit is not enough

Verify returns a single bit. A signature over twenty-two booleans cannot tell
a rejection from a rejection for the right reason: under that output every
rejection branch is interchangeable, and a mutation that swaps one for
another passes unnoticed. The reason code is exposed alongside the verdict
and goes into the signature, for the same reason kappa does in Sign.

    0 accepted   1 wrong length   2 hint decode   3 z bound   4 c_tilde mismatch

Mutation M9 changes only the reason code on a mismatch, leaving the verdict
correct, and is killed by nothing else.

## Coverage measured before the RTL, not after

The twenty ACVP vectors exercise three of the five outcomes:

    accept              4
    c_tilde mismatch   11
    hint decode         5
    wrong length        0
    z bound             0

The last two are live but unvisited. This core has now made the same mistake
four times -- the Decaps early exit, the sampler z == q case, hint decode
rule 1, and the Sign hint weight -- so the two cases were constructed before
any RTL was written: a signature one byte short, and one whose z has a
coefficient exactly on GAMMA1 - BETA, which is the only value at which >= and
> differ. Mutations M2, M3 and M4 are observable on nothing else.

## Two defects

**Found by reading.** cod_mode "1010" was used to unpack t1 and no such mode
existed: the codec had no 10-bit unsigned unpack. This is exactly the defect
that bit Sign, where the setup was packing from empty slots because the s and
t0 unpack modes were missing, and there it cost a long chase from a failing
signature. Here it was caught before the first simulation.

**Found in simulation, diagnosed in one step.** The R^2 lift was missing on
A o z_hat. There are two distinct pointwise products in Verify, A o z_hat and
c_hat o t1_hat, and each needs exactly one lifted operand; c_hat carried it
for the second and z_hat had been forgotten for the first.

VP1 passed and VP2 did not, which is the signature of this class of defect:
the A o z_hat term is short by one factor of R while the c_hat term is
correct, and nothing is visible until the two are summed. Rather than probing
signals, five lift combinations were evaluated against the model and
liftZ=0 liftC=1 reproduced the observed 2183610 exactly. That comparison
turned a failure into a diagnosis in a single step, against the several
rounds of mis-sampled probes the equivalent Sign defect cost.

## Structure

Verify is deterministic and single-pass, so unlike Sign the runtime is fixed
once the early checks pass. The top level is derived from the Sign top with
the sequencer swapped, so the arbitration logic is literally the same code
already exercised by every Sign vector.

mu is a 64-byte input and the message is never stored, consistent with Sign.
tr = SHAKE256(pk, 64) is bounded, but mu = SHAKE256(tr || mprime) is not.
