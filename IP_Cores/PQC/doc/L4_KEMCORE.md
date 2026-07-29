# Layer 4: ML-KEM core integration

    PQC L4 KEMCORE PASS keygen+encaps+decaps chained sig=95e07091fa5b3cc4

The three ML-KEM operations on ONE shared datapath, running a complete
encapsulation lifecycle. Six integration mutations, all killed.

## Derived from the Decaps top

The core was derived from the Decaps top level rather than written fresh,
because that top already carries the superset of datapath signals: both
codecs (codec_12 for the message, codec_ct for the compressed ciphertext)
and the rejected flag. KeyGen uses only the first codec, so its cct outputs
are forced idle in the mux. Reconstructing the 59-signal union by hand would
have been the error-prone path.

Three integration errors surfaced and were fixed: op did not reach the entity
because rejected sat at a different position than assumed; samp_sel is a
scalar std_logic, not a 2-bit vector; and grant is 0..4, not a slot index.

## The byte maps collide, and the driver resolves it

KeyGen writes dk at 2048 and Encaps writes ct at 2048. In the standalone
Layer 3A tests this never showed, because each operation ran alone with its
own freshly staged dk. In the chain, Encaps overwrites the dk that Decaps
needs.

The fix is in the driver, not the RTL. The byte maps are frozen: changing
them would invalidate every Layer 3A signature. So the driver parks dk above
the region Encaps uses and restores it before Decaps, which is the
moving-bytes-between-operations that overlapping maps require and exactly what
software above the core would do. The same decision was made for the ML-DSA
core, where sk moves from 2304 to 0.

The failure was diagnosed by reading intermediates rather than guessing: the
recovered message m2 was wrong from its first byte, the implicit rejection
fired, and Kout returned the rejection secret. That pointed at corrupt input,
and reading dk[0] before Decaps confirmed it held ct[0].

## Two checks, and why one alone would be a lie

Every intermediate is compared against the ACVP bytes, and the two shared
secrets must match: Encaps's K and Decaps's Kout. The round trip alone is the
cheaper test -- it shrinks the vector ROM and proves the operations agree
with each other -- but a core with a wrong NTT constant used by all three
would round trip perfectly and not be ML-KEM. That is the RTL-vs-RTL common
mode the Phase 0 test closed in the SpaceWire and 1553 cores, so both checks
are present.
