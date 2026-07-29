#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A
# fsm_model.py: cycle-agnostic model of the ML-KEM-768 FSM.
#
# This mirrors the operation sequence the RTL will execute, using only the
# primitives the hardware has: the sponge, NTT-K/INTT-K in Montgomery domain,
# basemul with accumulate, the samplers, and the codecs. It is deliberately
# written against those primitives rather than against the clean oracle, so
# that domain and ordering mistakes surface here instead of in VHDL.
#
# Checked against the ACVP-validated Phase 0 oracle at the bottom.
# =============================================================================
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "oracle"))
sys.path.insert(0, os.path.join(HERE, "..", "ntt"))
import mlkem768 as kem
from gen_ntt import mont_k, GK_M, ntt_k, intt_k, QK, csign

K, N = 3, 256
RK = 1 << 16
R2 = csign((RK * RK) % QK, QK)          # 1353: lifts an operand into Mont domain
ETA1 = ETA2 = 2
DU, DV = 10, 4


# ---- hardware primitives -------------------------------------------------
def sponge(mode, msg, olen):
    if mode == "shake128":
        return hashlib.shake_128(msg).digest(olen)
    if mode == "shake256":
        return hashlib.shake_256(msg).digest(olen)
    if mode == "sha3_256":
        return hashlib.sha3_256(msg).digest()
    return hashlib.sha3_512(msg).digest()


def basemul(a, b):
    """Exactly what basemul_k computes, Montgomery domain."""
    c = [0] * N
    for i in range(N // 2):
        a0, a1, b0, b1 = a[2 * i], a[2 * i + 1], b[2 * i], b[2 * i + 1]
        t1 = mont_k(mont_k(a1 * b1) * GK_M[i])
        c[2 * i] = mont_k(a0 * b0) + t1
        c[2 * i + 1] = mont_k(a0 * b1) + mont_k(a1 * b0)
    return c


def poly_add(a, b):
    return [x + y for x, y in zip(a, b)]


def poly_sub(a, b):
    return [x - y for x, y in zip(a, b)]


def lift(p):
    """Move a polynomial into Montgomery domain (multiply by R)."""
    return [mont_k(x * R2) for x in p]


def canon(p):
    return [x % QK for x in p]


def sample_a(rho, i, j):
    """SampleNTT returns A[i][j] already in NTT domain.

    The name is load-bearing: applying a forward NTT to this output would
    transform it a second time. The FSM must feed it straight to basemul.
    """
    return kem.sample_ntt(rho + bytes([j, i]))


def sample_cbd(eta, seed, nonce):
    blk = sponge("shake256", seed + bytes([nonce]), 64 * eta)
    return kem.sample_cbd(eta, blk)


# ---- K-PKE ---------------------------------------------------------------
def kpke_keygen(d):
    g = sponge("sha3_512", d + bytes([K]), 64)
    rho, sigma = g[:32], g[32:]
    s = [sample_cbd(ETA1, sigma, n) for n in range(K)]
    e = [sample_cbd(ETA1, sigma, K + n) for n in range(K)]
    # NTT, then lift into Montgomery domain so the basemul product lands in
    # plain domain (the R^-1 of the multiply cancels the R of the lift).
    s_hat = [lift(ntt_k(p)) for p in s]
    e_hat = [ntt_k(p) for p in e]
    t_hat = []
    for i in range(K):
        acc = [0] * N
        for j in range(K):
            acc = poly_add(acc, basemul(sample_a(rho, i, j), s_hat[j]))
        t_hat.append(poly_add(acc, e_hat[i]))
    ek = b"".join(kem.byte_encode(12, canon(t)) for t in t_hat) + rho
    dk = b"".join(kem.byte_encode(12, canon(s)) for s in
                  [ntt_k(p) for p in s])
    return ek, dk


def kpke_encrypt(ek, m, r):
    # t_hat arrives from ByteDecode in plain NTT domain. It must NOT be
    # lifted: y_hat already carries the R factor, so lifting both operands
    # would leave one R too many in the product.
    t_hat = [kem.byte_decode(12, ek[384 * i:384 * (i + 1)]) for i in range(K)]
    rho = ek[384 * K:]
    y = [sample_cbd(ETA1, r, n) for n in range(K)]
    e1 = [sample_cbd(ETA2, r, K + n) for n in range(K)]
    e2 = sample_cbd(ETA2, r, 2 * K)
    y_hat = [lift(ntt_k(p)) for p in y]
    u = []
    for i in range(K):
        acc = [0] * N
        for j in range(K):
            acc = poly_add(acc, basemul(sample_a(rho, j, i), y_hat[j]))
        u.append(poly_add(intt_k(acc), e1[i]))
    mu = [kem.decompress(1, b) for b in kem.byte_decode(1, m)]
    acc = [0] * N
    for j in range(K):
        acc = poly_add(acc, basemul(t_hat[j], y_hat[j]))
    v = poly_add(poly_add(intt_k(acc), e2), mu)
    c1 = b"".join(kem.byte_encode(DU, [kem.compress(DU, x) for x in canon(p)])
                  for p in u)
    c2 = kem.byte_encode(DV, [kem.compress(DV, x) for x in canon(v)])
    return c1 + c2


def kpke_decrypt(dk, c):
    c1, c2 = c[:32 * DU * K], c[32 * DU * K:]
    u = [[kem.decompress(DU, y) for y in
          kem.byte_decode(DU, c1[32 * DU * i:32 * DU * (i + 1)])]
         for i in range(K)]
    v = [kem.decompress(DV, y) for y in kem.byte_decode(DV, c2)]
    s_hat = [lift(kem.byte_decode(12, dk[384 * i:384 * (i + 1)]))
             for i in range(K)]
    acc = [0] * N
    for j in range(K):
        acc = poly_add(acc, basemul(s_hat[j], ntt_k(u[j])))
    w = poly_sub(v, intt_k(acc))
    return kem.byte_encode(1, [kem.compress(1, x) for x in canon(w)])


# ---- ML-KEM --------------------------------------------------------------
def keygen(d, z):
    ek, dk_pke = kpke_keygen(d)
    return ek, dk_pke + ek + sponge("sha3_256", ek, 32) + z


def encaps(ek, m):
    g = sponge("sha3_512", m + sponge("sha3_256", ek, 32), 64)
    key, r = g[:32], g[32:]
    return key, kpke_encrypt(ek, m, r)


def decaps(dk, c):
    dk_pke = dk[:384 * K]
    ek_pke = dk[384 * K:768 * K + 32]
    h = dk[768 * K + 32:768 * K + 64]
    z = dk[768 * K + 64:768 * K + 96]
    m2 = kpke_decrypt(dk_pke, c)
    g = sponge("sha3_512", m2 + h, 64)
    key2, r2 = g[:32], g[32:]
    kbar = sponge("shake256", z + c, 32)
    c2 = kpke_encrypt(ek_pke, m2, r2)
    # constant-time compare: accumulate differences, never branch early
    diff = 0
    for x, y in zip(c, c2):
        diff |= x ^ y
    return kbar if diff else key2


if __name__ == "__main__":
    import json
    vec = json.load(open(os.path.join(HERE, "..", "verif", "vectors",
                                      "acvp_subset.json")))
    n = 0
    for t in vec["kem_keygen"]:
        ek, dk = keygen(bytes.fromhex(t["d"]), bytes.fromhex(t["z"]))
        assert ek.hex() == t["ek"].lower(), "FSM keygen ek mismatch"
        assert dk.hex() == t["dk"].lower(), "FSM keygen dk mismatch"
        n += 1
    for t in vec["kem_encaps"]:
        k, c = encaps(bytes.fromhex(t["ek"]), bytes.fromhex(t["m"]))
        assert k.hex() == t["k"].lower() and c.hex() == t["c"].lower(), \
            "FSM encaps mismatch"
        n += 1
    for t in vec["kem_decaps"]:
        k = decaps(bytes.fromhex(t["dk"]), bytes.fromhex(t["c"]))
        assert k.hex() == t["k"].lower(), "FSM decaps mismatch"
        n += 1
    print("FSM model matches ACVP through hardware primitives: %d cases" % n)
