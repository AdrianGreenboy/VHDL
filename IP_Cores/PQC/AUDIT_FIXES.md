# PQC core - audit fixes (branch audit-2026-11)

Scope: `IP_Cores/PQC/` only. Every finding below was re-verified against the
pre-audit sources before it was changed. `soc/rtl/` keeps byte-identical copies
of every file in `rtl/` (checked by `verif/run_regress.sh`, which aborts if
they diverge); the SoC scripts keep analysing `soc/rtl/`.

Regression entry point (new): `verif/run_regress.sh quick|kat|audit|full|<name>`
runs every testbench directly against `rtl/` (the historical `pqc_l*.sh` and
`soc/deploy_*.sh` installers embed pre-audit copies and now refuse to run
unless `PQC_ALLOW_LEGACY_INSTALL=1`).

## 1. Findings and changes

| Sev | Finding (re-verified) | Change (file:line) | Verification |
|-----|-----------------------|--------------------|--------------|
| ALTA | `poly_mem` read `ra`, `rb` and `wa` (for `bm_drdata`) from one array with one write: 3R1W, unmappable to SRAM. | `rtl/poly_mem.vhd:162-305`: two identical 1R1W copies (`mem_a`, `mem_b`, both written by every write); copy A also serves the basemul RMW read, selected by a new strobe `bm_dre` (`:238`) driven by `basemul_k.d_re` (`rtl/basemul_k.vhd:43,184,209`; basemul never consumes operand A in that cycle). Each copy is one word-organised array (`G_ZB`=16 lanes x 16 bit, lane write mask) = one 1R1W macro with bit mask / FPGA SDP BRAM with byte enables. 16-bit `std_logic_vector`, no initialiser. Same treatment for `poly_mem_d` (also 2R1W; `rtl/poly_mem_d.vhd:109-190`, `G_ZB`=8 lanes x 32 bit). | Cycle-exact (read-first kept, latencies unchanged): all KATs bit-exact. New `verif/tb_mem_banks.vhd` (20 000 random ops, every client, same-address read/write, strobed RMW, copy equality via external names, wipes). `tb_poly_mem` updated (strobed RMW read). `mutate_pm.sh` re-anchored + 3 new mutants (copy B unwritten, wrong lane, lane select): 9/9 killed. |
| ALTA | `kem_decaps.rejected` (c /= c') exported through `kem_core_sx` and `pqc_core.kem_rej` to STATUS b2: plaintext-checking / decryption-failure oracle. | `rtl/kem_decaps.vhd:70,1326`: generic `G_DEBUG_REJ` (default false) - output is constant '0', no logic. Port removed from `kem_core_sx` (`:464` open) and `pqc_core`; STATUS b2 reads 0 (`soc/rtl/pqc_mmio.vhd`). Only verification wrappers `kem_decaps_top`/`kem_core` set `G_DEBUG_REJ => true`. | `tb_decaps` (debug wrapper) unchanged, 10 ACVP vectors incl. 6 rejections. New `verif/tb_host_guard.vhd`: Decaps of a valid and of a 1-bit-corrupted ciphertext (Kbar from `oracle/mlkem768.py`, `verif/kem_rej_vectors.txt`): both Kout KAT-exact, identical start-to-done latency, identical host view of all 8 KB except c and Kout. |
| ALTA | `byte_mem_d`, `poly_mem`, `poly_mem_d` typed `array of integer` with `(others => 0)`. | All four memories now `std_logic_vector` storage without initial value (`byte_mem.vhd:97`, `byte_mem_d.vhd:55`, `poly_mem.vhd:162`, `poly_mem_d.vhd:109`). The GHDL segfault no longer reproduces with GHDL 4.1 (tested up to 6016x64 and 2048x64 with aggregate initialiser). Byte memories are single-address 1RW (all users drive A and B from identical muxes; a sim assertion enforces it) with `G_LANES`=8 byte mask; on a write cycle the output holds (true 1RW). | Unwritten words are 'U' in simulation: a read-before-write that reached the datapath would break the bit-exact KATs or raise numeric_std metavalue warnings; the logs of all KAT runs show metavalue warnings only in the first nanoseconds, before reset. |
| MEDIA | `pqc_round_pkg` `make_hint` data-dependent while loops in an RTL package. | ML-DSA integer models (Power2Round, Decompose, MakeHint, UseHint; no RTL user) moved to `verif/pqc_round_ref_pkg.vhd`; `rtl/pqc_round_pkg.vhd` keeps only ML-KEM Compress/Decompress. | `tb_round` same signature `2737c3aa27b645a1`; `mutate_l2.sh` retargeted, 12/12 killed. |
| MEDIA | `codec_d.p_row` combinational from `row`, strobes registered: last clear write of each hint row landed in the next row (row 5 in row 0). | `rtl/codec_d.vhd:113,122,336,392,457`: `prow_r` registered with `p_raddr/p_waddr/p_we`. | `tb_codec_d` gains a monitor: k-th clear write must hit (k/256, k mod 256). Fails on the pre-audit `codec_d`, passes now; CODECD signature unchanged. |
| MEDIA | `kem_core_sx`/`dsa_core_sx` `sel` from unlatched `op`; "11" out of range. | `op_r` latched on an accepted start (`kem_core_sx.vhd:388-407`, `dsa_core_sx.vhd:249-265`); start accepted only when idle and op /= "11", else `cmd_err`. done/busy no longer muxed by `sel` (avoids a comb. loop). | `tb_host_guard`: op changed mid-run, op "11", re-start while busy -> outputs KAT-exact, err(1) set. |
| MEDIA | `pqc_core` sponge mux on unregistered `alg`. | `rtl/pqc_core.vhd:130-150`: `alg_eff` frozen while any core is busy/zeroizing; starts for the non-selected algorithm or while the other core is busy are dropped and flagged. | `tb_host_guard`: alg toggled during KEM KeyGen, DSA start during KEM, KEM start during DSA -> KAT-exact, err(1). `mutate_fusion.sh` re-anchored on `alg_eff`. |
| MEDIA | Host mux overrides byte memory mid-operation and reads intermediates. | `host_act = h_sel and not busy` (`kem_core_sx.vhd:561`, `dsa_core_sx.vhd:438`); host reads masked to 0x00 outside the staging/output windows of the last op (`host_rd_ok`, `:272`/`:222`, registered so latency is unchanged). Host scratch: KEM >= 5760, DSA >= 11520; firmware/tb park areas moved there (`soc/fw/*.s`, `gen_selftest.py`, `tb_pqc_core`). | `tb_host_guard`: host writes during busy do not corrupt ek/dk/pk, reads during busy return 0, sigma / m2..Kbar / rho',K are non-zero in memory but read 0. |
| MEDIA | `keccak_sponge` drops init/din_we/absorb_done/dout_re silently. | `rtl/keccak_sponge.vhd:126-158,178-191,289`: sticky `err` (+`err_clr`) -> `pqc_core.err(0)` -> STATUS b10. | New `verif/tb_sponge_err.vhd` (each violation flagged, legal SHA3-256 path clean). `tb_zeroize` asserts err = 0000 after all six operations (no false positives in real flows). |
| BAJA | ~530 lines dead RTL in `sampler_misc` (`sampler_rej_d/bnd_d/ball_d/mask_d`, `cval`); dead states. | Moved to `legacy/sampler_misc_l1_d.vhd` (only `tb_sampler` uses them). Removed `S_TC_RNEXT` (dsa_sign), `S_HE_ROW`, `S_HD_NEXT` (codec_d). | `tb_sampler` same signature; `mutate_samp.sh` retargeted, 10/10 killed. |
| BAJA | Unbounded `iter`/`kappa`. | `rtl/dsa_sign.vhd:29-46,75,1532`: `G_MAX_ITER`=814 (P(>814 iterations) = 0.804^814 < 2^-256 for p ~ 0.196, expected ~5.1 iterations; kappa <= 4070). On the bound: abort, `err` with done, core wipes sk and the partial signature; `pqc_core.err(2)` / STATUS b12. | New `verif/tb_sign_bound.vhd` on a 3-iteration vector: bound 3 -> exact signature; bound 2 -> err(2), signature area zero (host and memory). |
| BAJA | Norm checks exit at the first out-of-bound coefficient. | `dsa_sign.vhd:1201,1219,1312,1330,1389,1450`: every coefficient scanned, reject flag OR-ed, decision after the whole vector (ct0 folded into the hint check). | Sign KATs incl. kappa (iteration count) bit-exact. Cost: only rejected iterations pay the rest of the scan (see section 2). |
| BAJA | `byte_mem` header said 4 KB, `G_SIZE`=8192. | Header rewritten (`rtl/byte_mem.vhd:1-35`). | - |
| FEATURE | Key zeroization. | `G_ZEROIZE` (default true) on `kem_core_sx`, `dsa_core_sx`, `pqc_core`. After KeyGen/Encaps/Decaps and DSA KeyGen/Sign the core wipes the byte regions holding secrets/intermediates that are not outputs (tables `C_ZLO/C_ZHI`), the whole polynomial memory (both copies, one row per cycle) and the sponge state (state cleared, one f(0) permutation flushes `keccak_f1600`), then pulses done (`kem_core_sx.vhd:264-270,608-700`, `dsa_core_sx.vhd:214-220,470-570`). Verify handles public data only: no wipe. `zeroize` input (CMD b3) wipes everything, aborting a running op (soft reset of the sequencers); `zdone` -> STATUS b9 sticky, `zbusy` b8. A ZEROIZE that arrives during an automatic wipe is queued; a ZEROIZE in the cycle an operation finishes replaces that operation's done by zdone. Every wipe ends with a one-cycle soft reset of the sequencers and datapath blocks. | New `verif/tb_zeroize.vhd`: full KEM and DSA chains KAT-exact; after every op every byte the core wrote outside the outputs is 0, secret inputs are 0, both poly copies and the sponge state are 0; ZEROIZE command -> all 24 KB + poly memories 0; ZEROIZE aborting KeyGen -> no done, all 0, next KeyGen KAT-exact; err = 0000. |

Also fixed: `tb_ntt` (Layer 1) failed in the baseline because L3B later
overwrote `verif/ntt_d_vectors.txt` with another format; the original L1 file
was restored from `pqc_l1_ntt.sh` as `verif/ntt_d_l1_vectors.txt`.

## 2. Cycle counts (100 MHz testbench, `tb_pqc_core` chain, start -> done)

| Operation | Before | After (G_ZEROIZE=true) | Delta |
|-----------|-------:|------:|------:|
| ML-KEM KeyGen | 91 630 | 92 065 | +435 (+0.47 %) |
| ML-KEM Encaps | 106 625 | 107 061 | +436 (+0.41 %) |
| ML-KEM Decaps | 156 745 | 157 209 | +464 (+0.30 %) |
| ML-DSA KeyGen | 295 496 | 297 004 | +1 508 (+0.51 %) |
| ML-DSA Sign (chain vector, 1 iteration) | 641 840 | 643 348 | +1 508 (+0.23 %) |
| ML-DSA Verify | 347 874 | 347 875 | +1 |

With `G_ZEROIZE => false` the restructured design is cycle-identical to the
baseline (measured: Decaps 156 745 in `tb_host_guard`).

Sign over the nine `dsa_sign_vectors.txt` vectors (`tb_dsa_sign`, sequencer
only, no zeroization in that wrapper), showing the cost of the constant-time
norm checks: only rejected iterations pay the rest of a scan.

| Vector | Iterations | Before | After | Delta |
|-------:|-----------:|-------:|------:|------:|
| 0 | 3 | 1 442 145 | 1 448 911 | +6 766 |
| 1 | 7 | 2 895 477 | 2 913 103 | +17 626 |
| 2 | 5 | 2 165 724 | 2 180 977 | +15 253 |
| 3 | 4 | 1 622 297 | 1 626 681 | +4 384 |
| 4 | 1 | 641 843 | 641 843 | 0 |
| 5 | 12 | 4 665 409 | 4 705 053 | +39 644 |
| 6 | 2 | 1 041 214 | 1 045 452 | +4 238 |
| 7 | 1 | 641 920 | 641 920 | 0 |
| 8 | 16 | 6 276 696 | 6 319 181 | +42 485 |
| all | 51 | 21 392 725 | 21 523 121 | +130 396 (+0.61 %) |

That is about 3.1 k cycles per rejected iteration (bound: 5.1 k for a z
reject, 6.1 k for an r0 reject). A follow-up that would more than pay for it:
fuse the ||z|| test into the z = y + c*s1 write loop (saves the separate
5 x 256 x 4-cycle scan on every iteration, accepted ones included).

The memory restructuring itself is cycle-exact (0 cycles). All extra cycles
are the auto-zeroization (G_ZEROIZE=false gives the pre-audit counts) plus one
cycle: after a wipe the sponge is idle with ready=0, so the first
`S_*_INIT_P` waits for the init to be processed instead of passing on the
stale ready of the previous squeeze. Wipe rates are set by the generics
(`poly_mem.G_ZB`, `poly_mem_d.G_ZB`, `G_LANES`); wider words trade macro
shape for fewer cycles.

## 3. Test results

Simulator: GHDL 4.1 (mcode, and gcc backend for the long KATs). "Baseline"
= the unmodified tree (snapshot of `audit-2026-11` HEAD) run with the same
runner. Signatures are data hashes, so "identical" means bit-exact outputs.

| Test (runner name) | Baseline | After |
|--------------------|----------|-------|
| L1 keccak, sampler; L2 codec, round; L3 basemul | PASS | PASS, signatures identical |
| L1 ntt (`tb_ntt`) | FAIL (vector file clobbered by L3B) | PASS `f97e6012235b5fba` (as documented in `pqc_l1_ntt.sh`) |
| L3A codec12, poly_mem, datapath, codec_ct, KeyGen checkpoints 1-5, Encaps checkpoints 2-5 | PASS | PASS, identical |
| L3B ntt_d, sampler_d, round_d, codec_d (+ new p_row monitor), DSA KeyGen/Sign/Verify checkpoints | PASS | PASS, identical |
| ACVP KATs: KEM KeyGen (4), Encaps (4), Decaps (10, 6 implicit rejections) | PASS | PASS, identical |
| ACVP KATs: DSA KeyGen (8), Verify (22: 4 accept, 18 reject) | PASS / PASS (`183a67e1ba95f501`) | PASS, identical |
| ACVP KATs: DSA Sign (9 vectors, kappa checked) | PASS `cef491e2e25e7f39` | PASS, identical |
| L4 kem_core, dsa_core chains | PASS / PASS (`f93232f7ea2d1575`) | PASS, identical |
| L4 fusion `tb_pqc_core` | PASS `95e07091fa5b3cc4` / `f93232f7ea2d1575` | PASS, identical |
| L5 SoC + RV32 firmware (`tb_kemonly`, `tb_dsaonly`, 40 MHz) | KEM `95E07091FA5B3CC4`, DSA `F93232F7EA2D1575` | identical (firmware with moved park areas) |
| Python: `run_kat.py` (60 ACVP cases), `fsm_model.py`, `dsa_fsm_model.py`, `selftest_ref_portable.py` | PASS | unchanged |
| New: mem_banks, sponge_err, host_guard, sign_bound (2 and 3), zeroize | - | PASS (mcode; see note in `run_regress.sh`) |
| Mutations: mutate (keccak), _bm, _codec, _l2, _pm, _samp | all killed | all killed (pm 9/9 incl. 3 new) |
| Mutations: _ntt, _roundd | ntt meaningless (tb failed) | all killed |
| Mutations: _c12 | M3, M8 "not caught" (stale anchors) | same, pre-existing |
| Mutation of the new zeroize test (Decaps c2 region one word short) | - | killed (byte 5608 reported) |
| `soc/fw/selftest_ref.py` | FAIL (hard-coded /home/claude/pqc paths) | not changed; the portable variant passes |

## 4. Deferred / not done

- **Expensive mutation suites not re-run** (`mutate_dec/enc/kg/dsakg/dsasign/
  dsaver/kemcore/l4core/fusion/codecd/nttd/sampd/roundd/cct`): each mutant is
  a full KAT simulation and the host has 2 shared CPUs. Anchors that the
  audit invalidated were updated (`mutate_dsasign.sh` M1/M4/M10 + new M11,
  `mutate_fusion.sh` M1-M3, `mutate_pm/l2/samp/ntt`); the cheap suites were
  re-run (section 3). `mutate_c12.sh` M3/M8 have stale anchors already in the
  baseline (12-bit address era) and were left as found.
- **Background (non-blocking) wipe.** The remaining overhead (section 2) is
  the polynomial wipe, done before `done`. Hiding it behind host read-back
  needs a deferred-start queue; not done.
- **Inputs are consumed.** With `G_ZEROIZE` the dk input of Decaps and the sk
  input of Sign are wiped, so the host must re-stage dk (2400 B) / sk
  (4032 B) for every operation. Over the byte window that host traffic is a
  system-level cost comparable to the zeroization itself; if batches of
  Decaps/Sign with one key are needed, a "keep keys" option (drop the dk/sk
  regions from `C_ZLO/C_ZHI`, rely on the ZEROIZE command) is a two-line
  change but was not made: it contradicts the requested policy.
- **Register residue.** Wipes cover the byte memories, both polynomial
  memories and the sponge; a one-cycle soft reset after each wipe clears the
  datapath registers that have a reset clause. Registers without one (e.g.
  basemul operand registers, codec accumulators, NTT pipeline) may still
  hold fragments of the last secret; a full register scrub was not done.
- **Silicon/FPGA re-validation.** No Vivado here: BRAM count (both
  polynomial memories are now duplicated: KEM 2 x 110.6 kbit, DSA 2 x 385
  kbit), timing (new 2:1 read-port muxes, window comparators, `alg_eff`
  mux) and the TE0950 self-test must be re-run. Firmware park areas moved
  (KEM 5000 -> 5760, DSA 6144 -> 11520); expected signatures are unchanged.
- **ASIC macros.** The polynomial copies need two-port (1R + 1W, e.g.
  1RW+1R) macros with a bit/lane mask; the byte memories need single-port
  1RW macros with a byte mask. Availability of two-port macros in the IHP
  SG13G2 open PDK must be confirmed (sky130 OpenRAM provides 1RW1R); if only
  1RW exists, the polynomial memories need another scheme. Wide words
  (256 bit) are built from several macros side by side.
- **Docs.** `doc/L3*/L4*` describe pre-audit behaviour (e.g. the rejected
  flag); README register map and this file are current.

## 5. Risk notes (needs lab evaluation)

- **Rejection-loop leakage (ML-DSA).** Norm checks are now constant time per
  check, but which check rejected an iteration, the number of iterations,
  SampleInBall's data-dependent run time (rejected challenges) and the
  hint-encode time remain observable. The first two are public by FIPS 204
  design; the challenge timing of rejected iterations needs evaluation
  against current literature.
- **No masking / no hiding.** Power and EM side channels are unprotected
  (frozen scope). NTT, basemul, CBD, Decompress(m) and the FO re-encryption
  operate on unmasked secrets; single-trace attacks on the NTT and on the
  message encoding in Decaps are realistic at 130 nm. Lab evaluation (TVLA,
  profiled attacks) is required before flight use with long-term keys.
- **Zeroization leaks Hamming weight.** Overwriting secrets with zero
  dissipates power proportional to the bits cleared; a random-fill pass
  before the zero pass would hide that. Not done.
- **Decaps select.** Compare and select stay branch-free and the latency is
  proven identical for accept and reject in simulation; residual leakage of
  the select mask (one register, 8 bits) is a power side channel, not a
  timing one, and needs the lab.
- **Fault injection.** No redundancy: a fault in the c = c' comparison or in
  keep_msk turns Decaps into a key-recovery oracle; a fault on the Sign
  norm checks can release a signature with an out-of-bound z. The iteration
  bound and the zeroize abort give an error path, not fault detection.
  Duplicate-and-compare of the FO check and of the norm flag is recommended
  for the flight variant.
- **SEU / scrubbing.** Memories have no ECC; a single upset in a stored key
  corrupts outputs silently (or turns a valid signature into a reject).
