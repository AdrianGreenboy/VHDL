# Layer 3B Sign: mutation candidates, validated against the model first

Four of the earlier blocks lost time to mutations that turned out to inject
nothing. The cause was always the same: text was substituted into the RTL
without first checking that the change alters observable behaviour. For Sign
every candidate was run against the Python model BEFORE being written into
the mutation script.

Seven candidates were tested on ACVP vector 0. Three were observable, four
were not, and the four split into two different kinds.

## Observable, keep

    M1 kappa step L-1 instead of L      changes the signature
    M3 c_tilde absorbs w1 before mu     changes the signature
    M7 r0 rejection removed             changes the signature

Plus, observable on vectors 1, 3 and 5 but NOT on vector 0:

    z rejection removed

That one is worth keeping precisely because it needs a vector that rejects on
z, which vector 0 does not. It is a coverage requirement, not a defect.

## Genuine no-op, drop

    M2 A row order reversed

The accumulator is a sum over s and addition is commutative, so reordering
cannot change the result. No input can distinguish it. This is not a coverage
gap and no vector will fix it.

## Structurally masked, document rather than write

    z bound off by one
    r0 bound off by one

An off-by-one in a rejection bound only changes behaviour when a candidate
lands EXACTLY on the boundary. That was pursued rather than assumed:

  - Over 300 random messages the closest approach from below was 524091
    against a bound of 524092, a gap of one, so the boundary is reachable.
  - A search found message "zb-00082" whose iteration 3 gives
    ||z||inf == 524092 exactly.
  - With the relaxed bound that iteration passes the z check, and the
    signature STILL does not change, because the same iteration then fails
    the r0 check: 261782 against a bound of 261692.

So the boundary case exists and was constructed, and the mutation is masked
anyway by the next rejection in the chain. Making it observable would need a
candidate that sits exactly on the z bound AND passes r0, ct0 and the hint
weight, which is a far narrower search than it is worth.

This is the fourth instance of the same pattern in this core:

    ct0 rejection            unreachable by construction (TAU*2^(D-1) < GAMMA2)
    hint decode rule 1       masked by rule 2 and by the loop guard
    Decaps comparison exit   masked until byte-0 vectors were built
    sampler z == q           masked until a synthetic stream was built

The first two are structural and stay documented. The last two were coverage
gaps and were closed. Telling them apart is the whole point of investigating
a survivor rather than rewriting it.
