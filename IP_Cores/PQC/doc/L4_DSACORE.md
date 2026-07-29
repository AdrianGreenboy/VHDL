# Layer 4: ML-DSA core integration

    PQC L4 DSACORE PASS keygen+sign+verify chained sig=f93232f7ea2d1575

The three ML-DSA operations on ONE shared datapath, running a complete key
lifecycle rather than one operation against a vector file. Seven integration
mutations, all killed.

## What Layer 3B could not have caught

Each operation had its own top level, and each instantiated its own sponge,
NTT unit, sampler, codec and memories. Three copies of Keccak-f1600 is the
single most expensive mistake available in this design, and no per-operation
testbench could see it because each was correct in isolation.

The datapath now exists once and the sequencers are muxed by an operation
register. Only one operation runs at a time, so this is a mux rather than an
arbiter: there is no concurrency to resolve, and encoding that invariant
directly is cheaper and easier to argue about than a bus. Mutation M2, which
broadcasts start to all three sequencers, is what shows the test can see the
invariant being violated.

## Two checks, and why one alone would be a lie

Every intermediate is compared against the ACVP expected bytes, and Verify
must accept the signature KeyGen and Sign produced.

The second alone is the cheaper test and the more tempting one: it shrinks
the vector ROM from 27.6 KB to 160 bytes and proves the operations agree with
each other. But a core with a wrong constant in the NTT tables would use it
in all three operations, interoperate with itself perfectly, and not be
ML-DSA. That is the RTL-vs-RTL common mode the Phase 0 test was built to
close in the SpaceWire and 1553 cores, and it is why the ACVP comparison
stays.

The chain carries the core's own output: the driver moves the bytes KeyGen
produced into the addresses Sign reads, and the signature Sign produced into
the addresses Verify reads, rather than reloading the vector at each step.

## Overlapping slot maps

The three sequencers share one polynomial memory and their maps overlap
heavily -- KeyGen's s1_hat sits where Sign keeps hint data. That is safe only
because operations are strictly sequential and every sequencer writes each
slot before reading it.

The self-test exercises that ordering, but passing does not prove the
property: an ordering violation has to be shown to be visible. That is what
the integration mutations are for, and M4, M5 and M6 -- which break the
codec's paths into the shared memories -- are the ones that would fire on a
sharing error.

## Byte maps left alone

The three sequencers keep the byte maps they were verified with, and those
maps disagree: KeyGen writes sk at 2304 while Sign reads it at 0. Unifying
them would invalidate every Layer 3B signature for no gain, so the driver
moves bytes instead, which is what the software above will do anyway.
