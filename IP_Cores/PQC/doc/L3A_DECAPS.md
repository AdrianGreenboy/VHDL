# Layer 3A: ML-KEM-768 Decaps sequencer

Status: PASS.

    PQC L3A DECAPS PASS vectors=10 rejected=6 sig=0fd9be3d1fda7c7f

Ten vectors: eight traceable to ACVP plus two constructed rejection cases
described below. Six take the implicit rejection path. The testbench asserts
the taken path against what the model predicted, not only the resulting
shared secret, because a secret can match for the wrong reason if the
comparison is inverted and the vector happens to expect the other branch.

## The constant-time finding

This is the part of the block worth reading.

The functional test passed with the comparison written correctly. To check
that it was also constant time, the testbench measures each vector's runtime.
The first attempt asserted that accepting and rejecting vectors take the same
number of cycles. That assertion FAILED on correct RTL, and the failure was
the assertion's fault, not the design's:

    accept = 1566940 ns    reject = 1566410 ns

Total runtime is not constant in ML-KEM. SampleNTT uses rejection sampling, so
matrix expansion consumes a data-dependent number of squeeze bytes, and during
re-encryption that seed derives from m2. Measuring every vector showed the
variation sits WITHIN each group, not between them: accepting spanned
1566090 to 1568710, rejecting 1566410 to 1568160, ranges that overlap.

The second attempt asserted that the two ranges overlap. That passed on
correct RTL, so it was checked against an injected early exit in the
comparison, and the early exit SURVIVED.

The reason is a vector coverage gap, and it is specific: every ACVP rejection
vector in this subset corrupts the LAST ciphertext byte. The first differing
byte is at index 1087 of 1088 in all four cases. An early exit therefore
saves nothing, and no timing measurement can detect it.

Two rejection vectors were added whose ciphertext differs at byte 0. With
those present the early exit finishes about 53 us sooner, far outside the
2.6 us rejection-sampling noise, and the assertion became a bound on the
total spread across all vectors:

    assert all_max - all_min < 10 us

Mutation M1 injects exactly that early exit and is now killed. Without the
byte-0 vectors it survives.

The general point: a timing test is only as good as the inputs that make the
leak observable. Vectors chosen to exercise functional correctness will not
automatically exercise a side channel, and here the ACVP set happened to
corrupt the one byte position that hides an early exit completely.

## Structure

Decaps is decrypt, re-encrypt, then a branchless select:

  A  m2 = KPKE.Decrypt(dk_pke, c)
  B  (K2, r2) = G(m2 || h), c2 = KPKE.Encrypt(ek_pke, m2, r2)
  C  Kbar = J(z || c); output K2 if c2 = c else Kbar

Phase B is the Encaps datapath again, with ek_pke, rho and h all read from
inside dk rather than from separate inputs.

Two constant-time properties are enforced in the RTL:

  1. The comparison visits all 1088 byte pairs and OR-accumulates the
     differences, with no early exit.
  2. The selection is a bitwise mask. Both candidate secrets are computed
     unconditionally and one is masked out, so neither path is shorter.

The `rejected` output is observability only. It is asserted by the testbench
and is not on any control path that would change timing.

## Lift rule

Exactly one basemul operand carries R^2, and here it is s_hat, matching
KeyGen. Unlike Encaps, where only y_hat is admissible because t_hat arrives
in the plain domain, the decrypt product accepts the lift on either operand;
the choice follows the existing convention rather than a constraint.

## Bugs found

One, at integration: the `rejected` port was declared on the top level but
the sed that generated it did not match the instance line, so it was left
unconnected and read as 'U'. Caught immediately by the path assertion. The
sequencer itself passed on the first run, as Encaps did, because the four
KeyGen sequencing patterns were applied from the start.
