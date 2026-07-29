# Layer 3A: ML-KEM-768 Encaps sequencer

Status: PASS. Four ACVP-traceable vectors: shared secret K (32 bytes) and
ciphertext (1088 bytes) compared byte for byte, plus four intermediate
polynomial checkpoints.

    PQC L3A ENCAPS PASS vectors=4 sig=ad5c907bbb4cef35

    EP2  y_hat[0] after NTT and R^2 lift   sig=64186ac5586e21f4
    EP3  A^T[0][0] from SampleNTT          sig=fa943adf1bc98f88
    EP4  u[0] before compression           sig=7c5a209110a6df50
    EP5  v before compression              sig=e273f9efb7c7984b

EP1 is r as a byte string rather than a polynomial, so it is not part of the
polynomial checkpoint testbench; the hash chain that produces it is covered
end to end by the shared secret comparison, which is checked before the
ciphertext for exactly that reason.

## The lift trap, and why EP5 exists

Exactly one basemul operand carries the R^2 lift. In Encaps that operand is
y_hat; t_hat arrives from ByteDecode in the plain NTT domain and must not be
lifted.

Lifting both is not a loud failure. It leaves u completely correct and
corrupts only v. Mutation M1 does exactly this, and the testbench reports:

    TB FAIL encaps 0 ct byte 960

Byte 960 is the first byte of c2. All 960 bytes of c1, the entire u vector,
match. A checkpoint on u alone would have passed while the ciphertext was
wrong, which is why the stage list separates EP4 from EP5 rather than
checking the accumulator once.

## Bugs found during bring-up

None in the sequencer. Encaps passed its full ACVP comparison on the first
run after the RTL analysed.

This is worth recording because it is a direct consequence of the KeyGen
bring-up. Six of the nine KeyGen bugs were variations of one mistake, treating
a synchronous interface as combinational, and all four resulting patterns were
applied here preventively rather than discovered again:

  1. The sponge mode is established one state before the init pulse, so the
     sponge never initialises with the previous mode.
  2. Every init is an unconditional single-cycle pulse followed by a separate
     wait state, so the assert and the clear cannot collapse into one
     assignment that never leaves.
  3. Every byte-memory read has an explicit settle state before the data is
     sampled, in all five absorb loops and both squeeze loops.
  4. sp_re is driven through one explicit mux gated by samp_run, never by a
     port and a concurrent assignment at the same time.

Mutations M10, M11 and M12 re-inject those exact defects and are all killed,
so the patterns are constrained by the test rather than merely present.

Two small issues surfaced during integration, both caught at analysis time:
C_QK is declared identically in two packages and needed qualifying, and
indexing an unsigned yields a single bit rather than a vector, so the message
bit had to be tested rather than converted.

## Structure

56 sequencer steps. The parts that differ from KeyGen:

- H(ek) is computed here rather than read from a key, since Encaps receives
  ek rather than dk.
- G absorbs m and H(ek), which are not adjacent in memory, so the absorb is
  two separate address runs rather than one.
- rho is read from inside ek at offset 384*K, with no copy to scratch.
- A^T[i][j] uses seed bytes (i, j), the transpose of KeyGen's (j, i).
- Both u and v need an inverse NTT, which KeyGen never exercised.
- Decompress_1 of the message is folded into the v accumulate loop: one
  message byte covers eight coefficients, so the byte is fetched once every
  eight and held.
