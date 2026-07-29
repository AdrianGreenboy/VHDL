# Layer 3A: ML-KEM-768 KeyGen sequencer

Status: PASS. Four ACVP-traceable vectors, ek (1184 bytes) and dk (2400 bytes)
compared byte for byte, plus five intermediate polynomial checkpoints.

    PQC L3A KEYGEN PASS vectors=4 sig=c268044aef8e69c0

## Bugs found during bring-up

Nine defects, in the order they were found. Six of the nine were variations of
one underlying mistake: treating a synchronous interface as if it responded
combinationally.

1. **Byte address space overflow.** dk ends at byte 4192, past the 12-bit
   limit. Widened to 13 bits and 8 KB, dk base moved to 2048. GHDL reported it
   as `TO_UNSIGNED: vector truncated`, buried among metavalue warnings.

2. **Missing settle states in four absorb loops** (d, sigma, rho, ek). The byte
   memory is synchronous: an address issued this cycle yields data next cycle.

3. **Missing settle in the squeeze loops.** The sponge registers its output on
   the same edge that consumes the read enable, so the first byte was stored
   twice. The corrected three-state pattern was verified against the sponge in
   isolation before being applied.

4. **Multiple drivers on sp_re.** The sequencer drove it as an output port
   while a concurrent assignment also muxed the samplers onto it. VHDL resolved
   the two to 'X' and the sponge never advanced. The symptom was "the sponge
   returns the same byte forever", pointing at the sponge rather than the
   wiring. Fixed with an explicit three-way mux gated by samp_run.

5. **Single-port byte memory used for simultaneous read and write.** Gave it a
   dedicated read port.

6. **Collapsed init pulse. This was the root cause of the longest hunt.**
   `sp_init <= '1'` followed by `sp_init <= '0'` inside the same conditional is
   a single signal assignment: the last one wins and the pulse never leaves.
   The first init worked only by accident, because sp_ready was still low right
   after reset. Every later init silently did nothing, so the sponge stayed in
   SHA3-512 with a dirty state and the sampler consumed a stream that matched
   no hash function at all. Fixed by splitting each init into an unconditional
   pulse state and a separate wait state.

7. **Mode and init asserted in the same cycle**, which initialises the sponge
   with the previous mode. Fixed with a mode-setup state one cycle earlier.

8. **Missing settle in the three byte-copy loops** (rho into ek, ek into dk,
   z into dk). This one survived until ek byte 1152, with all 1152 bytes of
   t_hat already correct.

9. **Stop-after-stage logic overwritten.** `fsm <= S_DONE` was followed by
   further assignments in the same branch, so the halt never took effect and
   the checkpoint read a slot that had already moved on. Fixed with else
   branches.

Two further defects were introduced by the address widening itself: a global
12-to-13-bit substitution also caught `c0`, `c1` and the return type of
`canon`, which are 12-bit coefficients rather than addresses. A Kyber
coefficient needs 12 bits because q = 3329 < 4096; widening them broke the
codec bound checks. Worth remembering: a mechanical width change must
distinguish address buses from data of a coincidentally similar width.

## What made this tractable

The checkpoint testbench. Halting after each stage and comparing one
polynomial against the ACVP-validated model turned "ek is wrong" after 900
microseconds of simulation into "CP1 coefficient 0 is wrong" after 10
microseconds. Bugs 6 and 7 were both found inside CP1, before any of the
lattice arithmetic had run.

The five stages, in execution order:

    CP1  s[0] after SamplePolyCBD      sig=75f3cc35383c1408
    CP2  s_hat[0] after forward NTT    sig=59431426bd4081c3
    CP3  s_hat[0] lifted by R^2        sig=c278736c497820e6
    CP4  A[0][0] from SampleNTT        sig=aad3cc0a59b8137c
    CP5  accumulator after K basemuls  sig=499d4925529bf09d

## Domain rules exercised here

Both traps from doc/DOMAIN_RULES.md are now covered by mutations that fail:

- Exactly one basemul operand carries the R^2 lift (M2).
- dk encodes the unlifted s_hat, so the lift goes into a scratch slot. Lifting
  in place yields a correct ek and a silently wrong dk (M1, M8).
- SampleNTT output is already in the NTT domain and is never transformed.
- A[i][j] uses seed bytes (j, i) in that order (M3).
