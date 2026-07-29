#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3B
# dsa_fsm_model.py: step-by-step reference for the ML-DSA-65 Sign sequencer.
#
# This is the oracle the RTL is written against, in the same role fsm_model.py
# played for ML-KEM. It differs from mldsa65.py in that it exposes the
# intermediate quantities the sequencer must produce, including the ones from
# REJECTED iterations, and it carries the Montgomery-domain bookkeeping
# explicitly rather than reducing modulo q at every step.
#
# The five frozen checkpoints (doc DSA_SCOPE.md):
#   SP1  y of the first iteration, straight out of ExpandMask
#   SP2  w1 after Decompose, first iteration
#   SP3  c_tilde, the challenge
#   SP4  candidate z of the first iteration, EVEN IF REJECTED
#   SP5  final kappa and the complete signature
# =============================================================================
import sys
import os

# The oracle and the vector file live beside this script in the delivered
# tree (verif/), and one directory up in the development tree. Try both so
# the same file runs in either layout.
_HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (_HERE, os.path.join(_HERE, "..", "oracle"),
           os.path.join(_HERE, "vectors")):
    if os.path.isdir(_p):
        sys.path.insert(0, _p)


def _find(name):
    for d in (_HERE, os.path.join(_HERE, "vectors"),
              os.path.join(_HERE, "..", "l3kem")):
        c = os.path.join(d, name)
        if os.path.isfile(c):
            return c
    raise IOError("cannot locate " + name)

import mldsa65 as D
from mldsa65 import (
    ntt, intt, poly_add, poly_sub, ntt_mul, infnorm, centered,
    highbits, lowbits, make_hint, expand_a, expand_mask, sample_in_ball,
    w1_encode, sk_decode, sig_encode, shake256,
    Q, KK, LL, GAMMA1, GAMMA2, BETA, OMEGA, LAMBDA,
)

# -----------------------------------------------------------------------------
# Montgomery constants for the NTT-D datapath.
#
# R = 2^32. The RTL uses the subtractive convention
#
#     t = (a * QINV) truncated to signed 32 bits
#     r = (a - t * q) >> 32
#
# which yields a * R^-1 mod q. That convention requires QINV = 58728449.
# Note that 4236238847 is the same value taken as -q^-1 mod 2^32; it belongs to
# the ADDITIVE convention (a + t*q) and is wrong here. Both appear in the
# literature, so the sign is stated rather than assumed.
# -----------------------------------------------------------------------------
C_QD = Q
C_QINVD = 58728449
C_RD2 = (1 << 64) % Q          # R^2 mod q, the lift constant


def mont_d(a):
    """Montgomery reduction in the NTT-D domain: returns a * R^-1 mod q."""
    t = (a * C_QINVD) & 0xFFFFFFFF
    if t >= 1 << 31:
        t -= 1 << 32
    return (a - t * C_QD) >> 32


def lift_d(p):
    """Multiply a polynomial by R^2 so a following basemul yields a plain
    product. Exactly one operand of every basemul carries this."""
    return [mont_d(c * C_RD2) % Q for c in p]


# -----------------------------------------------------------------------------
# Sign with full intermediate exposure.
# -----------------------------------------------------------------------------
def sign_traced(sk, mprime, rnd=bytes(32)):
    """Run Sign and return (signature, trace).

    trace is a dict holding the five frozen checkpoints plus per-iteration
    detail. Every iteration is recorded, including rejected ones, because the
    RTL must reproduce the rejected candidates too: a sequencer that rejects
    for the wrong reason can still terminate on a valid signature.
    """
    rho, key, tr, s1, s2, t0 = sk_decode(sk)
    s1_hat = [ntt(p) for p in s1]
    s2_hat = [ntt(p) for p in s2]
    t0_hat = [ntt(p) for p in t0]
    a_hat = expand_a(rho)

    mu = shake256(tr + mprime, 64)
    rhop2 = shake256(key + rnd + mu, 64)

    trace = {"mu": mu, "rhop2": rhop2, "iters": []}
    kappa = 0

    while True:
        rec = {"kappa_in": kappa}

        y = expand_mask(rhop2, kappa)
        kappa += LL
        rec["y"] = [list(p) for p in y]

        y_hat = [ntt(p) for p in y]
        w = []
        for r in range(KK):
            acc = [0] * 256
            for s in range(LL):
                acc = poly_add(acc, ntt_mul(a_hat[r][s], y_hat[s]))
            w.append(intt(acc))
        rec["w"] = [list(p) for p in w]

        w1 = [[highbits(x) for x in p] for p in w]
        rec["w1"] = [list(p) for p in w1]

        c_tilde = shake256(mu + w1_encode(w1), LAMBDA // 4)
        rec["c_tilde"] = c_tilde

        c_hat = ntt(sample_in_ball(c_tilde))
        z = [poly_add(y[s], intt(ntt_mul(c_hat, s1_hat[s]))) for s in range(LL)]
        rec["z"] = [list(p) for p in z]

        # Rejection 1: the response must not leak s1.
        if max(infnorm(p) for p in z) >= GAMMA1 - BETA:
            rec["reject"] = "z"
            trace["iters"].append(rec)
            continue

        wcs2 = [poly_sub(w[r], intt(ntt_mul(c_hat, s2_hat[r])))
                for r in range(KK)]
        # Rejection 2: the low bits must not carry information about s2.
        if max(infnorm([lowbits(x) for x in p]) for p in wcs2) >= GAMMA2 - BETA:
            rec["reject"] = "r0"
            trace["iters"].append(rec)
            continue

        ct0 = [intt(ntt_mul(c_hat, t0_hat[r])) for r in range(KK)]
        # Rejection 3: NEVER TAKEN by any ACVP vector in the current subset.
        if max(infnorm(p) for p in ct0) >= GAMMA2:
            rec["reject"] = "ct0"
            trace["iters"].append(rec)
            continue

        h = [[make_hint(-centered(ct0[r][j] % Q),
                        centered(wcs2[r][j] % Q) + centered(ct0[r][j] % Q))
              for j in range(256)] for r in range(KK)]
        # Rejection 4: NEVER TAKEN by any ACVP vector in the current subset.
        if sum(sum(p) for p in h) > OMEGA:
            rec["reject"] = "h"
            trace["iters"].append(rec)
            continue

        rec["reject"] = None
        rec["h"] = [list(p) for p in h]
        trace["iters"].append(rec)

        sig = sig_encode(c_tilde, z, h)
        trace["kappa_final"] = kappa
        trace["n_iters"] = len(trace["iters"])
        trace["signature"] = sig

        # The five frozen checkpoints, taken from the FIRST iteration except
        # SP5. SP4 is the first iteration's candidate z whether or not that
        # iteration was accepted, which is the whole point of separating it
        # from SP5.
        first = trace["iters"][0]
        trace["SP1"] = first["y"]
        trace["SP2"] = first["w1"]
        trace["SP3"] = first["c_tilde"]
        trace["SP4"] = first["z"]
        trace["SP5"] = (kappa, sig)
        return sig, trace


def sign_internal_traced(sk, mprime, rnd=bytes(32)):
    return sign_traced(sk, mprime, rnd)


def sign_external_traced(sk, msg, ctx=b"", rnd=bytes(32)):
    assert len(ctx) <= 255
    mprime = bytes([0, len(ctx)]) + ctx + msg
    return sign_traced(sk, mprime, rnd)


def mprime_for(vector):
    """Build the message representative for an ACVP siggen vector.

    The internal interface signs the message directly; the external interface
    prepends the domain separator and context. Routing every vector through
    the external path silently produces wrong signatures for the internal
    ones, which is exactly how this was first mis-measured.
    """
    msg = bytes.fromhex(vector["message"])
    if vector.get("iface") == "internal":
        return msg
    ctx = bytes.fromhex(vector.get("context", ""))
    return bytes([0, len(ctx)]) + ctx + msg


# -----------------------------------------------------------------------------
# Self-check
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    import json

    vec = json.load(open(_find("acvp_subset.json")))

    # Montgomery arithmetic, the foundation the whole datapath rests on.
    import random
    random.seed(7)
    for _ in range(5000):
        x = random.randrange(-Q, Q)
        y = random.randrange(-Q, Q)
        assert (mont_d(x * y) - x * y * pow(1 << 32, -1, Q)) % Q == 0
    for _ in range(5000):
        x = random.randrange(Q)
        y = random.randrange(Q)
        assert mont_d(lift_d([x])[0] * y) % Q == (x * y) % Q
    print("mont_d and lift_d verified over 10000 cases")

    ok = 0
    reasons = {"z": 0, "r0": 0, "ct0": 0, "h": 0}
    for t in vec["dsa_siggen_det_pure"]:
        sk = bytes.fromhex(t["sk"])
        sig, tr = sign_traced(sk, mprime_for(t), bytes(32))
        assert sig.hex() == t["signature"].lower()
        ok += 1
        for it in tr["iters"]:
            if it["reject"]:
                reasons[it["reject"]] += 1

    print("sign_traced matches ACVP: %d/%d"
          % (ok, len(vec["dsa_siggen_det_pure"])))
    print("rejection branches exercised:",
          ", ".join("%s=%d" % kv for kv in reasons.items()))
    # The constructed case that reaches the hint-weight branch.
    t6 = vec["dsa_siggen_det_pure"][6]
    sig, tr = sign_traced(bytes.fromhex(t6["sk"]), b"hintprobe-000008",
                          bytes(32))
    hrs = [it["reject"] for it in tr["iters"]]
    assert "h" in hrs, "constructed h vector no longer reaches the branch"
    reasons["h"] += hrs.count("h")
    print("constructed h vector: %d iterations, kappa=%d, h reached"
          % (tr["n_iters"], tr["kappa_final"]))
    print("rejection branches after construction:",
          ", ".join("%s=%d" % kv for kv in reasons.items()))

    # ct0 is unreachable by construction, not merely unvisited:
    #   ||c*t0||inf <= TAU * 2^(D-1) = 49 * 4096 = 200704 < GAMMA2 = 261888
    from mldsa65 import TAU, D as DDD, GAMMA2 as G2
    assert TAU * (1 << (DDD - 1)) < G2
    print("ct0 unreachable by construction: TAU*2^(D-1) = %d < GAMMA2 = %d"
          % (TAU * (1 << (DDD - 1)), G2))
