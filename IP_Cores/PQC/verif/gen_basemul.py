#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3 support
# gen_basemul.py: reference vectors for basemul_k (FIPS 203 Alg 11, 12).
#
# Montgomery domain bookkeeping, established here once and relied on by the
# Layer 3 FSM: BaseCaseMultiply in Montgomery form returns a*b*R^-1 relative
# to the plain-domain product. The compensation is to lift one operand by R^2
# before the multiply, which the FSM does when it loads s_hat and t_hat.
# Verified below against the ACVP-validated oracle.
# =============================================================================
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "oracle"))
sys.path.insert(0, os.path.join(HERE, "..", "ntt"))
import mlkem768 as kem
from gen_ntt import mont_k, GK_M, ntt_k, intt_k, QK, csign

RK = 1 << 16
R2 = csign((RK * RK) % QK, QK)


def basemul_rtl(x, y):
    c = [0] * 256
    for i in range(128):
        a0, a1, b0, b1 = x[2 * i], x[2 * i + 1], y[2 * i], y[2 * i + 1]
        t1 = mont_k(mont_k(a1 * b1) * GK_M[i])
        c[2 * i] = mont_k(a0 * b0) + t1
        c[2 * i + 1] = mont_k(a0 * b1) + mont_k(a1 * b0)
    return c


def selftest():
    random.seed(7)
    for _ in range(20):
        a = [random.randrange(QK) for _ in range(256)]
        s = [random.randrange(QK) for _ in range(256)]
        lifted = [mont_k(v * R2) for v in ntt_k(s)]
        rtl = intt_k(basemul_rtl(ntt_k(a), lifted))
        orc = kem.intt(kem.ntt_mul(kem.ntt(a), kem.ntt(s)))
        assert [x % QK for x in rtl] == orc, "basemul chain mismatch"
    print("basemul chain verified against oracle (20 random pairs), R2 =", R2)


def emit():
    random.seed(2026)
    cases = [([0] * 256, [0] * 256),
             ([1] + [0] * 255, [1] + [0] * 255),
             ([QK - 1] * 256, [QK - 1] * 256),
             ([0] * 255 + [1], [0] * 255 + [1])]
    for _ in range(6):
        cases.append(([random.randrange(QK) for _ in range(256)],
                      [random.randrange(QK) for _ in range(256)]))
    with open("basemul_vectors.txt", "w") as f:
        f.write("# basemul_k vectors: a line, b line, product line.\n")
        f.write("# All three in Montgomery-domain NTT representation, "
                "canonical [0,q).\n")
        for a, b in cases:
            na = ntt_k(a)
            nb = ntt_k(b)
            c = basemul_rtl(na, nb)
            f.write(" ".join(str(x % QK) for x in na) + "\n")
            f.write(" ".join(str(x % QK) for x in nb) + "\n")
            f.write(" ".join(str(x % QK) for x in c) + "\n")
    return len(cases)


if __name__ == "__main__":
    selftest()
    n = emit()
    print("wrote basemul_vectors.txt with %d cases" % n)
