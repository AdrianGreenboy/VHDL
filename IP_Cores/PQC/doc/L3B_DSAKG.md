# Layer 3B: ML-DSA-65 KeyGen

    PQC L3B DSAKG PASS cases=8 sig=af470b97689ada71

Eight ACVP vectors, public AND secret key compared byte for byte. Four
checkpoints. Nine mutations, all killed.

## Both halves are compared, and one mutation proves why

pk is a function of t1 alone. A defect confined to s1, s2 or t0 leaves pk
bit-identical and only corrupts sk, and those three are exactly what Sign
later consumes. Mutation M6 -- s2 drawn from a restarted index space instead
of continuing s1's -- was validated against the model as producing an
IDENTICAL public key, and it is killed by the secret key comparison and by
nothing else.

That distinction was visible during bring-up too: pk passed all 1952 bytes
while sk failed at byte 128 exactly, which is where the packed s1 begins.

## Three defects

**s1 transformed in place.** sk carries the plain s1 and the forward NTT ran
over it. Third instance in this core after Sign's y and the c_hat product,
so s1_hat now lives in its own slots and the copy is explicit.

**Power2Round captured one cycle early.** The address assigned takes effect
the next cycle and the memory presents data the cycle after that, so the
capture read the previous coefficient. Sign has the same read-modify-write
structure written correctly with three states, and comparing against it is
what located this.

**cnt not reset before the s1 copy.** It is left at 63 by the ExpandS absorb
loop, so the copy started at coefficient 63 and the first quarter of s1_hat
was never written.

That last one is worth recording for how it was found rather than what it
was. The observed s1_hat matched no transform of s1 at all: not the forward
NTT, not the lifted version, not a double transform, not a shifted copy, not
s2. Several rounds went into testing transform variants before the obvious
conclusion -- that when a result matches no plausible variant of the
operation, the operation is fine and the INPUT is wrong. The measurement that
settled it was halting after the copy and before the NTT and dumping the
destination: S1H[0..5] were zero and S1H[255] was correct, which points at a
wrong starting index and nothing else.

The general form: test the inputs before testing more variants of the
operation.

## Structure

KeyGen is the simplest of the three ML-DSA operations. Single pass, no
rejection loop, no failure outcome, so the runtime is fixed and there is
nothing to expose beyond the key pair: no reason code as in Verify, no kappa
as in Sign. Every primitive it needs was already verified -- ExpandA and
ExpandS in the sampler, Power2Round in the rounding package, the t1, s and t0
pack modes in the codec -- and A is regenerated per (r,s) from rho rather
than stored, as in Sign.

"A transposed" was considered as a mutation and dropped: K and L differ, so
transposing the index is an out-of-range access rather than a behaviour
change. The same candidate was dropped for the same reason in Sign.
