# Layer 4 fusion: ML-KEM and ML-DSA over one Keccak sponge

    PQC L4 FUSION PASS kem=95e07091fa5b3cc4 dsa=f93232f7ea2d1575 shared_sponge=1

This is where the Layer 4 integration pays off. The KEM and DSA cores each
drove their own Keccak sponge, and Keccak-f1600 is the most expensive block
in the design. The fused core has ONE sponge, muxed between the two
algorithms by an alg register.

## Why sharing is legitimate

keccak_sponge, keccak_f1600 and keccak_pkg are byte-identical in the two
trees -- same md5 for all three. That is the condition that makes one shared
instance correct rather than a coincidence, and it was checked before any
fusion RTL was written.

## The verification bar needs no new calibration

The fused core reproduces BOTH Layer 4 signatures, run back to back in one
simulation over the shared sponge:

    KEM  95e07091fa5b3cc4
    DSA  f93232f7ea2d1575

These are the signatures each core produced with its own private sponge.
Sharing the block cannot move a validated signature unless the sharing is
wrong, so a reproduced pair is proof the fusion is transparent -- not a new
test that might be miscalibrated. A single bit of leakage between algorithms,
a sponge not reset cleanly between chains, a crossed state, would have moved
at least one signature. The two chains run without a reset in between, so the
sponge really is reused across algorithms.

## Structure

Both cores are instantiated in their _sx form, identical to the verified
Layer 4 cores except the sponge is lifted to ports (xsp_*) instead of
instantiated. The wrapper owns the single keccak_sponge and muxes its inputs
by alg: '0' selects the KEM core, '1' the DSA core. Only one algorithm runs
at a time -- the same invariant that holds within each core -- so this is a
mux, not an arbiter.

## Mutations

Three, all killed. M1 is the one that matters: it freezes the sponge mux on
the KEM core, so the DSA chain drives a sponge it does not own and its
signature moves. If M1 survived, there would be a second sponge hiding
somewhere and the fusion would be a fiction. M2 freezes only the absorbed
data while control still follows alg; M3 inverts alg so each algorithm drives
the sponge while the other is selected.
