# HERCOSSNUX PQC IP Core - Frozen Scope (v1.0)

Frozen on 2026-07-21 with Adrian. No RTL exists before this document. Any
change to this scope requires a new revision of this file, committed before
the change is implemented.

## 1. What the core is

A single IP core, `PQC`, implementing two NIST post-quantum standards in
full, at one fixed security level each:

- **ML-KEM-768** per **FIPS 203 (final, August 2024)**: KeyGen, Encaps,
  Decaps (internal variants driven by seeds supplied over AXI).
- **ML-DSA-65** per **FIPS 204 (final, August 2024)**: KeyGen, Sign, Verify.
  Signing implements the FIPS 204 hedged construction with the 32-byte `rnd`
  value supplied as an input register; writing all zeros yields the FIPS 204
  deterministic variant, which is what all KAT layers and silicon bring-up
  use. Both variants are therefore covered by construction.
  Pure ML-DSA only (no pre-hash HashML-DSA, no external-mu interface).

Explicitly excluded: ML-KEM-512/1024, ML-DSA-44/87, round-3
Kyber/Dilithium compatibility, SLH-DSA, X-Wing/hybrid modes, DPA/masking
countermeasures (see Section 6).

## 2. Frozen architecture decisions

| # | Decision | Frozen choice |
|---|----------|---------------|
| 1 | Standard | FIPS 203 / FIPS 204 final (not round-3) |
| 2 | Parameter sets | ML-KEM-768 + ML-DSA-65 only (CNSA 2.0 category) |
| 3 | NTT datapaths | Two dedicated units (q=3329/12-bit and q=8380417/23-bit), serialized: never active simultaneously |
| 4 | ML-DSA signing | Hedged per FIPS 204 with rnd register; rnd=0 = deterministic variant |
| 5 | Packaging | One IP core `PQC` (Keccak core shared internally) |
| 6 | Keccak throughput | 2 rounds/cycle, 12 cycles per f[1600] permutation |

## 3. Hardware architecture (frozen at block level)

- One shared **Keccak-f[1600]** core (2 rounds/cycle) with a mode wrapper
  providing SHAKE128, SHAKE256, SHA3-256, SHA3-512 with incremental squeeze
  (required by rejection samplers).
- **NTT-K** unit: q=3329, 12-bit coefficients, zeta=17, 7 layers,
  base-case pairwise multiply. Reduction by subtract/shift networks only.
- **NTT-D** unit: q=8380417, 23-bit coefficients, zeta=1753, 8 layers.
  Reduction by subtract/shift networks only. The VHDL `mod` operator is
  banned from all datapaths (documented divider-inference hazard).
- Coefficient and byte storage in the canonical SDP BRAM mold (512x32,
  one sync write, one sync read port, `ram_style="block"`).
- Samplers: CBD (eta=2), uniform rejection (12-bit and 23-bit),
  bounded rejection (eta=4), SampleInBall (tau=49), ExpandMask.
- Top-level FSMs: KEM.KeyGen / KEM.Encaps / KEM.Decaps /
  DSA.KeyGen / DSA.Sign / DSA.Verify, one command register, one busy/done
  status register, one result code register.
- **Constant-time policy** (in scope): no branches, no memory addresses,
  and no loop trip counts depend on secret data *within one rejection
  iteration*. Rejection counts themselves are public by design (FIPS 203/204
  property). The Decaps ciphertext comparison and the implicit-rejection
  select are constant-time.

## 4. Interfaces (frozen)

- AXI-Lite slave at `0x8000_0000/64K`: command, status, seed/rnd/message
  staging registers, doorbell.
- Large objects (ek 1184 B, dk 2400 B, ct 1088 B; pk 1952 B, sk 4032 B,
  sig 3309 B, messages) move via the validated DMA-doorbell pattern to the
  reserved DDR buffer at `0x7000_0000` (16 MB, no-map). PS side uses
  volatile word-by-word copies only (glibc DC ZVA hazard, documented).
- Register map to be detailed at RTL scope of Layer 3; the byte layout of
  all objects is exactly the FIPS encoding (no repacking).

## 5. Verification plan (five layers, signatures, mutations)

PASS criterion at every layer: bit-identical end-of-run signature.
**Frozen rule:** signatures are SHA-256 digests over *computed data* in a
fixed order, never over cycle counts or iteration counts, because
rejection sampling makes timing non-portable between oracle and RTL.

- **L1 units**: Keccak-f[1600] against official test vectors (all four
  modes, incremental squeeze); NTT-K and NTT-D roundtrip = identity and
  equality with schoolbook negacyclic product on directed random inputs;
  each sampler against the Python oracle; modular reduction sweep.
- **L2 blocks**: NTT-based polynomial pipelines, compress/decompress,
  all ByteEncode/BitPack/HintBitPack codecs, Power2Round/Decompose/
  MakeHint/UseHint against the oracle.
- **L3 algorithms**: full KeyGen/Encaps/Decaps/Sign/Verify in RTL vs the
  Python oracle with fixed seeds, including implicit-rejection and
  invalid-signature paths.
- **L4 standards closure**: RTL runs the embedded ACVP subset
  (60 cases: 8 KEM keygen, 8 encaps, 8 decaps incl. modified-ciphertext,
  8 DSA keygen, 8 deterministic signatures, 20 verify incl. all four
  negative classes) and must reproduce
  `PQC PHASE0 ORACLE PASS cases=60 sig=1e7a55fc0681398f`
  transitively: RTL == oracle (L3) and oracle == NIST ACVP (Phase 0,
  155/155 full-set cases validated at oracle delivery time).
- **L5 silicon**: TE0950, BOOT.BIN repackaged via PetaLinux (never
  hot-load PDI), static aarch64 KAT binary on the PS driving the core
  through AXI-Lite + DMA doorbell, result on picocom console; same
  signature line as L4.

**Mutations** (4-5 per layer, all must FAIL), pre-registered candidates:
L1: drop one Keccak round pair; wrong NTT twiddle; off-by-one in a
reduction constant; CBD bit-order swap.
L2: Decompose boundary `r+ - r0 == q-1` removed; hint monotonicity check
removed; BitPack `b - x` sign flip; compress rounding floor instead of
nearest.
L3: non-constant-time Decaps compare replaced by early-exit (must be
caught by a dedicated dataflow check); skip `||z|| >= gamma1 - beta`
rejection; skip `||ct0|| >= gamma2` check; wrong domain byte in G/H.
L4: any single ACVP field perturbation must flip the signature.
L5: single-bit corruption of staged seed via debug register must change
the reported signature.

## 6. Honest claims policy (for README and paper)

In scope and claimed: FIPS 203/204 bit-exactness (ACVP-validated),
constant-time dataflow as defined in Section 3, silicon validation on
xcve2302. **Not claimed**: side-channel resistance beyond constant time
(no DPA/EMA measurements, no masking), fault-attack resistance, CAVP/CMVP
certification. The README states this exclusion explicitly.

## 7. Deliverables and conventions

Same as all HERCOSSNUX cores: VHDL-2008, GHDL 4.1.0 `--std=08`,
ASCII-only asserts, each step as one self-contained bash script
(base64 payloads, guard subshells, `mv` semantics respected, one expected
output line), validated in a clean container before delivery, canonical
path `~/vhdl_repo/IP_Cores/PQC/`, English README (12-14 sections) with a
760x560 SVG referenced as a file, MIT license.
