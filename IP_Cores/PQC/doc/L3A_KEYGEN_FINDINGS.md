# Layer 3A KeyGen bring-up: findings so far

Status: **not passing yet**. rho matches (the KGC checkpoint clears), ek
diverges from byte 0. The failure is downstream of the initial hash, in the
lattice arithmetic or its sequencing.

## Bugs found and fixed during this bring-up

1. **Byte address space overflow.** dk ends at byte 4192 with the original
   base addresses, past the 12-bit limit. Widened to 13 bits and 8 KB, dk base
   moved to 2048. Caught by GHDL's `TO_UNSIGNED: vector truncated` warning,
   which was otherwise buried in the log.

2. **Missing settle states in every absorb loop.** The byte memory is
   synchronous, so an address issued this cycle yields data next cycle. Four
   absorb loops (d, sigma, rho, ek) sampled `by_dout` one cycle early. Fixed
   with an explicit wait state per loop.

3. **Missing settle state in every squeeze loop.** The sponge registers its
   output on the same edge that consumes `sp_re`. Without a settle cycle the
   first byte is stored twice and the stream shifts. Verified the corrected
   three-state pattern against the sponge in isolation before applying it.

4. **Multiple drivers on `sp_re`.** The sequencer drove it as an output port
   while a concurrent assignment also muxed the two samplers onto it. VHDL
   resolved the two drivers to 'X' and the sponge never advanced, which
   presented as "the sponge returns the same byte forever". Fixed with an
   explicit three-way mux gated by a new `samp_run` signal, so exactly one
   source drives it at any time.

   This is the one worth remembering: a multiply-driven `std_logic` control
   line does not fail loudly. It fails as a stuck value, and the symptom
   points at the innocent block.

5. **Single-port byte memory used for simultaneous read and write.** The
   sequencer reads one address while writing another during squeeze-to-memory
   and byte copies. Gave the byte memory a dedicated read port.

## What the checkpoint bought

The KGC line (rho, sigma) in the vector file is what made bugs 2 to 4
tractable: each one presented as "rho is wrong at byte N", which is a
five-line window to inspect, rather than "ek is wrong" after 900 microseconds
of simulation covering fifteen sponge invocations, six NTTs and nine
pointwise multiplies.

## Next debug step

Add checkpoints for the intermediate polynomials, in this order:

  1. s[0] after CBD, before NTT      (isolates the sampler path)
  2. s_hat[0] after NTT              (isolates the NTT through the arbiter)
  3. lifted s_hat[0]                 (isolates the R^2 lift)
  4. A[0][0] after SampleNTT         (isolates matrix expansion and seed order)
  5. t_hat[0] after the accumulation (isolates basemul accumulation)

`gen_l3a.py` can emit all five from the FSM model, which already matches ACVP.
The RTL testbench then reads the corresponding polynomial slot through the
host port and compares. Each checkpoint is one polynomial: 256 coefficients,
cheap to compare and unambiguous about which stage diverged.
