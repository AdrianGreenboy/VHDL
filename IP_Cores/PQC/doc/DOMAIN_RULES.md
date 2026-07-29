# ML-KEM-768 Montgomery domain rules (normative for the Layer 3A RTL)

Established and verified by `fsm_model.py` against the ACVP-validated oracle,
24/24 cases, before any RTL was written. Every rule below caused a real
failure in the model when violated.

## The invariant

`basemul` in Montgomery domain returns `a*b*R^-1` relative to the plain-domain
product. Therefore **exactly one operand of every basemul must be lifted** by
`R^2 = 1353 mod q`. The R of the lift cancels the R^-1 of the multiply, and
the result lands in plain domain.

| Product | Operand A | Operand B | Lifted |
|---|---|---|---|
| KeyGen `A o s` | A from SampleNTT | `s_hat` | **s_hat** |
| Encaps `A^T o y` | A from SampleNTT | `y_hat` | **y_hat** |
| Encaps `t o y` | `t_hat` from ByteDecode | `y_hat` | **y_hat only** |
| Decaps `s o u` | `s_hat` from ByteDecode | `NTT(u)` | **s_hat** |

Lifting both operands of the `t o y` product leaves one extra R and corrupts
only `v`, not `u`. That asymmetry is what makes the bug hard to spot: the
ciphertext is half correct.

## SampleNTT is already transformed

`SampleNTT` (FIPS 203 Alg 7) returns `A[i][j]` **in NTT domain**. Applying a
forward NTT to its output transforms it a second time. The FSM feeds it
straight to basemul with no transform.

## Matrix transpose in Encaps

KeyGen uses `A[i][j]` with seed bytes `(j, i)`. Encaps uses `A^T`, which means
the same seed byte order but the loop indices swapped: `sample_a(rho, j, i)`.
Getting this wrong produces a valid-looking ciphertext that never decapsulates.

## Domains at rest

- `s_hat`, `e_hat`, `t_hat` stored in **plain NTT domain** (that is what
  ByteEncode/ByteDecode carry, so this is forced by the wire format).
- Lifting happens on load into the multiplier, never in storage.
- `u`, `v` are plain coefficient domain after INTT.
