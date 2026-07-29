# Layer 3B: ML-DSA-65 Sign sequencer

Eight ACVP vectors, each compared byte for byte against the reference
signature, with the final kappa checked before the bytes. Four frozen
checkpoints inspect the first iteration.

## The message is not stored

mu is a 64-byte input and the sequencer never sees the message. The ACVP
vectors alone reach 7583 bytes and a message may be arbitrarily long, so a
fixed buffer would be a limit invented by the implementation rather than
required by the algorithm. It was verified against the model that mu is the
only message-derived value any later step needs. The host computes
mu = SHAKE256(tr || mprime, 64) with the sponge already validated in silicon.

## kappa is in the signature on purpose

The iteration count is data-dependent, between 1 and 12 across these vectors.
kappa is a deterministic function of the inputs, not a timing measurement,
and it is the only observable that separates "the rejection loop ran the
right number of times" from "the loop happened to produce the right bytes".
Mutation M2 is killed by kappa alone.

## Mutations validated before being written

Seven candidates were run against the Python model before any went into the
mutation script. Three were observable, one was observable only on vectors
that reject on z, one was a genuine no-op, and two were structurally masked:

    A row order reversed        no-op: the accumulator is a commutative sum
    z bound off by one          masked
    r0 bound off by one         masked

The bound mutations were pursued rather than assumed. Over 300 messages the
closest approach from below was 524091 against a bound of 524092, so the
boundary is reachable, and a search found message "zb-00082" whose iteration
3 lands exactly on it. With the relaxed bound that iteration passes the z
check and the signature still does not change, because the same iteration
then fails the r0 check at 261782 against 261692. Making it observable would
need a candidate sitting exactly on the z bound that also passes r0, ct0 and
the hint weight.

This is the fourth structurally-masked check in this core, after the ct0
rejection, hint decode rule 1, and the Decaps early exit.

## The defect the checkpoints could not see

The first iteration was correct from early on. Every checkpoint passed while
the full run still disagreed with ACVP, with small deltas that appeared at
iteration 1 and not before.

The cause was in the sampler: sgn is OR-ed in one byte at a time and was
cleared only on reset, never per invocation. The first SampleInBall of a run
was therefore always clean and every later one accumulated the previous
call's sign bits, flipping a handful of signs in c. Sign calls the sampler
once per rejection-loop iteration, so the second iteration onwards was wrong
by a small amount.

The sampler testbench could not have caught this: it asserts reset between
vectors, which clears sgn and makes the two behaviours identical. That is why
its signature did not move when the bug was fixed. The testbench now runs the
SampleInBall cases back to back with only the stream position reset, and that
version fails on the unfixed RTL with a sign flip, got 8380416 where 1 was
expected.

The general shape is worth keeping: a testbench that resets between cases
cannot see state that carries across cases, and a block used repeatedly
inside a loop must be tested the way the loop uses it.

## Other defects found

By reading before simulating: the setup phase was missing entirely, so
s1, s2 and t0 were never unpacked or transformed; c_hat was destroyed by the
in-place pointwise product, which needs it L + 2K times; hw_cnt was reset
only on the reject path.

In simulation: ii was too narrow for the setup index, which reaches L+2K-1;
a 96-bit product was assigned to a 64-bit variable, the fourth instance in
this core after mont_d, twog2_quot and the FNV accumulator; w and w1 were
written to the same slot although both are needed, w for the wcs2 subtraction
and w1 for the encode; the codec had no unpack modes for s or t0 at all, so
the setup was packing from empty slots; cod_base was 13 bits while the
signature lives at 8192, above the 13-bit ceiling, the same class of defect
as the ML-KEM 12-to-13 bit widening; the byte memory settle was missing in
the signature assembly; and all three product-then-INTT paths issued the
start in the same state that observed the previous done, so ntt_done was
still asserted and the transform never ran.

The last of these was found by comparing against the setup path, which had
the same structure written correctly.

## A misdiagnosis, recorded

Two probes gave readings that were off by one cycle and led to wrong
conclusions: one reported y as differing by 172233 while z, which is y plus a
small product, was off by only 8, which is arithmetically impossible. Signals
with a cycle of latency should not be sampled in the state that sets the
address. Reading through the hp_ inspection port, straight from memory, is
what actually located both the empty s1 slots and the correct c_tilde at
iteration 1.
