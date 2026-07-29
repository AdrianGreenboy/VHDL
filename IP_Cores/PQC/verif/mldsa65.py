#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC - Phase 0 oracle
# ML-DSA-65 reference implementation, bit-exact per FIPS 204 (final, Aug 2024)
# Pure Python 3 stdlib. Supports hedged and deterministic signing (rnd input).
# This oracle is the golden model for RTL Layers 2-4.
# =============================================================================
import hashlib

# ---- Parameters: ML-DSA-65 (FIPS 204 Table 1) ----
Q = 8380417
N = 256
D = 13
TAU = 49
LAMBDA = 192
GAMMA1 = 1 << 19
GAMMA2 = (Q - 1) // 32          # 261888
KK = 6                          # rows (k)
LL = 5                          # cols (l)
ETA = 4
BETA = TAU * ETA                # 196
OMEGA = 55

def shake256(b, n): return hashlib.shake_256(b).digest(n)
def shake128(b, n): return hashlib.shake_128(b).digest(n)

# ---- NTT (FIPS 204 Algorithms 41, 42) ----
def _bitrev8(i):
    r = 0
    for b in range(8):
        r = (r << 1) | ((i >> b) & 1)
    return r

ZETAS = [pow(1753, _bitrev8(i), Q) for i in range(256)]

def ntt(w):
    w = list(w)
    m = 0
    ln = 128
    while ln >= 1:
        for start in range(0, 256, 2 * ln):
            m += 1
            z = ZETAS[m]
            for j in range(start, start + ln):
                t = (z * w[j + ln]) % Q
                w[j + ln] = (w[j] - t) % Q
                w[j] = (w[j] + t) % Q
        ln >>= 1
    return w

def intt(w):
    w = list(w)
    m = 256
    ln = 1
    while ln < 256:
        for start in range(0, 256, 2 * ln):
            m -= 1
            z = ZETAS[m]
            for j in range(start, start + ln):
                t = w[j]
                w[j] = (t + w[j + ln]) % Q
                w[j + ln] = (z * (w[j + ln] - t)) % Q
        ln <<= 1
    return [(x * 8347681) % Q for x in w]  # 8347681 = 256^-1 mod q

def poly_add(a, b): return [(x + y) % Q for x, y in zip(a, b)]
def poly_sub(a, b): return [(x - y) % Q for x, y in zip(a, b)]
def ntt_mul(a, b):  return [(x * y) % Q for x, y in zip(a, b)]

def centered(x):
    # mod+- q on a representative in [0, q)
    return x - Q if x > Q // 2 else x

def infnorm(p):
    return max(abs(centered(x % Q)) for x in p)

# ---- Rounding (FIPS 204 Algorithms 35-40) ----
def power2round(r):
    rp = r % Q
    r0 = rp % (1 << D)
    if r0 > (1 << (D - 1)):
        r0 -= (1 << D)
    return (rp - r0) >> D, r0          # (r1, r0)

def decompose(r):
    rp = r % Q
    r0 = rp % (2 * GAMMA2)
    if r0 > GAMMA2:
        r0 -= 2 * GAMMA2
    if rp - r0 == Q - 1:
        return 0, r0 - 1
    return (rp - r0) // (2 * GAMMA2), r0  # (r1, r0)

def highbits(r): return decompose(r)[0]
def lowbits(r):  return decompose(r)[1]

def make_hint(z, r):
    return 1 if highbits(r) != highbits(r + z) else 0

def use_hint(h, r):
    m = (Q - 1) // (2 * GAMMA2)  # 16
    r1, r0 = decompose(r)
    if h == 1:
        return (r1 + 1) % m if r0 > 0 else (r1 - 1) % m
    return r1

# ---- Bit packing (FIPS 204 Algorithms 16-19) ----
def simple_bitpack(p, bits):
    out = bytearray()
    acc = 0
    nb = 0
    for x in p:
        acc |= x << nb
        nb += bits
        while nb >= 8:
            out.append(acc & 0xFF)
            acc >>= 8
            nb -= 8
    return bytes(out)

def simple_bitunpack(b, bits):
    p = []
    acc = 0
    nb = 0
    mask = (1 << bits) - 1
    for byte in b:
        acc |= byte << nb
        nb += 8
        while nb >= bits and len(p) < 256:
            p.append(acc & mask)
            acc >>= bits
            nb -= bits
    return p

def bitpack(p, a, b):
    # store b - x in bitlen(a+b) bits
    bits = (a + b).bit_length()
    return simple_bitpack([b - centered(x % Q) for x in p], bits)

def bitunpack(v, a, b):
    bits = (a + b).bit_length()
    return [(b - z) % Q for z in simple_bitunpack(v, bits)]

def hint_bitpack(h):
    y = bytearray(OMEGA + KK)
    idx = 0
    for i in range(KK):
        for j in range(256):
            if h[i][j]:
                y[idx] = j
                idx += 1
        y[OMEGA + i] = idx
    return bytes(y)

def hint_bitunpack(y):
    h = [[0] * 256 for _ in range(KK)]
    idx = 0
    for i in range(KK):
        yi = y[OMEGA + i]
        if yi < idx or yi > OMEGA:
            return None
        first = idx
        while idx < yi:
            if idx > first and y[idx] <= y[idx - 1]:
                return None
            h[i][y[idx]] = 1
            idx += 1
    for j in range(idx, OMEGA):
        if y[j] != 0:
            return None
    return h

# ---- Sampling (FIPS 204 Algorithms 29-34) ----
def rej_ntt_poly(seed):
    length = 504
    while True:
        s = shake128(seed, length)
        p = []
        pos = 0
        while len(p) < 256 and pos + 3 <= length:
            z = s[pos] + 256 * s[pos + 1] + 65536 * (s[pos + 2] & 0x7F)
            pos += 3
            if z < Q:
                p.append(z)
        if len(p) == 256:
            return p
        length += 168

def rej_bounded_poly(seed):
    length = 272
    while True:
        s = shake256(seed, length)
        p = []
        pos = 0
        while len(p) < 256 and pos < length:
            for half in (s[pos] & 0xF, s[pos] >> 4):
                if half < 9 and len(p) < 256:
                    p.append((ETA - half) % Q)
            pos += 1
        if len(p) == 256:
            return p
        length += 136

def expand_a(rho):
    return [[rej_ntt_poly(rho + bytes([s, r])) for s in range(LL)] for r in range(KK)]

def expand_s(rhop):
    s1 = [rej_bounded_poly(rhop + bytes([r, 0])) for r in range(LL)]
    s2 = [rej_bounded_poly(rhop + bytes([LL + r, 0])) for r in range(KK)]
    return s1, s2

def expand_mask(rhop2, mu):
    c = 1 + (GAMMA1 - 1).bit_length()  # 20
    y = []
    for r in range(LL):
        n = mu + r
        v = shake256(rhop2 + bytes([n & 0xFF, n >> 8]), 32 * c)
        y.append(bitunpack(v, GAMMA1 - 1, GAMMA1))
    return y

def sample_in_ball(seed):
    c = [0] * 256
    s = shake256(seed, 8 + 256)  # ample squeeze
    hbits = int.from_bytes(s[:8], "little")
    pos = 8
    for i in range(256 - TAU, 256):
        while True:
            j = s[pos]
            pos += 1
            if j <= i:
                break
        c[i] = c[j]
        c[j] = (Q - 1) if (hbits >> (i + TAU - 256)) & 1 else 1
    return c

# ---- Encodings (FIPS 204 Algorithms 22-28) ----
def w1_encode(w1):
    bits = ((Q - 1) // (2 * GAMMA2) - 1).bit_length()  # 4
    return b"".join(simple_bitpack(p, bits) for p in w1)

def pk_encode(rho, t1):
    return rho + b"".join(simple_bitpack(p, 10) for p in t1)

def pk_decode(pk):
    rho = pk[:32]
    t1 = [simple_bitunpack(pk[32 + 320 * i:32 + 320 * (i + 1)], 10) for i in range(KK)]
    return rho, t1

def sk_encode(rho, key, tr, s1, s2, t0):
    out = rho + key + tr
    out += b"".join(bitpack(p, ETA, ETA) for p in s1)
    out += b"".join(bitpack(p, ETA, ETA) for p in s2)
    out += b"".join(bitpack(p, (1 << (D - 1)) - 1, 1 << (D - 1)) for p in t0)
    return out

def sk_decode(sk):
    rho, key, tr = sk[:32], sk[32:64], sk[64:128]
    off = 128
    s1 = [bitunpack(sk[off + 128 * i:off + 128 * (i + 1)], ETA, ETA) for i in range(LL)]
    off += 128 * LL
    s2 = [bitunpack(sk[off + 128 * i:off + 128 * (i + 1)], ETA, ETA) for i in range(KK)]
    off += 128 * KK
    t0 = [bitunpack(sk[off + 416 * i:off + 416 * (i + 1)],
                    (1 << (D - 1)) - 1, 1 << (D - 1)) for i in range(KK)]
    return rho, key, tr, s1, s2, t0

def sig_encode(c_tilde, z, h):
    return c_tilde + b"".join(bitpack(p, GAMMA1 - 1, GAMMA1) for p in z) + hint_bitpack(h)

def sig_decode(sig):
    c_tilde = sig[:LAMBDA // 4]
    off = LAMBDA // 4
    z = [bitunpack(sig[off + 640 * i:off + 640 * (i + 1)], GAMMA1 - 1, GAMMA1)
         for i in range(LL)]
    h = hint_bitunpack(sig[off + 640 * LL:])
    return c_tilde, z, h

# ---- ML-DSA internal (FIPS 204 Algorithms 6, 7, 8) ----
def keygen_internal(xi):
    seed = shake256(xi + bytes([KK, LL]), 128)
    rho, rhop, key = seed[:32], seed[32:96], seed[96:]
    s1, s2 = expand_s(rhop)
    a_hat = expand_a(rho)
    s1_hat = [ntt(p) for p in s1]
    t = []
    for r in range(KK):
        acc = [0] * 256
        for s in range(LL):
            acc = poly_add(acc, ntt_mul(a_hat[r][s], s1_hat[s]))
        t.append(poly_add(intt(acc), s2[r]))
    t1 = [[power2round(x)[0] for x in p] for p in t]
    t0 = [[power2round(x)[1] for x in p] for p in t]
    pk = pk_encode(rho, t1)
    tr = shake256(pk, 64)
    sk = sk_encode(rho, key, tr, s1, s2, t0)
    return pk, sk

def sign_internal(sk, mprime, rnd):
    rho, key, tr, s1, s2, t0 = sk_decode(sk)
    s1_hat = [ntt(p) for p in s1]
    s2_hat = [ntt(p) for p in s2]
    t0_hat = [ntt(p) for p in t0]
    a_hat = expand_a(rho)
    mu = shake256(tr + mprime, 64)
    rhop2 = shake256(key + rnd + mu, 64)
    kappa = 0
    while True:
        y = expand_mask(rhop2, kappa)
        kappa += LL
        y_hat = [ntt(p) for p in y]
        w = []
        for r in range(KK):
            acc = [0] * 256
            for s in range(LL):
                acc = poly_add(acc, ntt_mul(a_hat[r][s], y_hat[s]))
            w.append(intt(acc))
        w1 = [[highbits(x) for x in p] for p in w]
        c_tilde = shake256(mu + w1_encode(w1), LAMBDA // 4)
        c_hat = ntt(sample_in_ball(c_tilde))
        z = [poly_add(y[s], intt(ntt_mul(c_hat, s1_hat[s]))) for s in range(LL)]
        if max(infnorm(p) for p in z) >= GAMMA1 - BETA:
            continue
        wcs2 = [poly_sub(w[r], intt(ntt_mul(c_hat, s2_hat[r]))) for r in range(KK)]
        if max(infnorm([lowbits(x) for x in p]) for p in wcs2) >= GAMMA2 - BETA:
            continue
        ct0 = [intt(ntt_mul(c_hat, t0_hat[r])) for r in range(KK)]
        if max(infnorm(p) for p in ct0) >= GAMMA2:
            continue
        h = [[make_hint(-centered(ct0[r][j] % Q), centered(wcs2[r][j] % Q)
                        + centered(ct0[r][j] % Q))
              for j in range(256)] for r in range(KK)]
        if sum(sum(p) for p in h) > OMEGA:
            continue
        return sig_encode(c_tilde, z, h)

def verify_internal(pk, mprime, sig):
    if len(sig) != LAMBDA // 4 + 640 * LL + OMEGA + KK:
        return False
    rho, t1 = pk_decode(pk)
    c_tilde, z, h = sig_decode(sig)
    if h is None:
        return False
    if max(infnorm(p) for p in z) >= GAMMA1 - BETA:
        return False
    a_hat = expand_a(rho)
    tr = shake256(pk, 64)
    mu = shake256(tr + mprime, 64)
    c_hat = ntt(sample_in_ball(c_tilde))
    z_hat = [ntt(p) for p in z]
    t1_hat = [ntt([(x << D) % Q for x in p]) for p in t1]
    w1p = []
    for r in range(KK):
        acc = [0] * 256
        for s in range(LL):
            acc = poly_add(acc, ntt_mul(a_hat[r][s], z_hat[s]))
        acc = poly_sub(acc, ntt_mul(c_hat, t1_hat[r]))
        wr = intt(acc)
        w1p.append([use_hint(h[r][j], wr[j]) for j in range(256)])
    return c_tilde == shake256(mu + w1_encode(w1p), LAMBDA // 4)

# ---- ML-DSA external, pure variant (FIPS 204 Algorithms 2, 3) ----
def sign(sk, msg, ctx=b"", rnd=bytes(32)):
    # rnd = 32 zero bytes -> deterministic variant; fresh random -> hedged
    assert len(ctx) <= 255
    mprime = bytes([0, len(ctx)]) + ctx + msg
    return sign_internal(sk, mprime, rnd)

def verify(pk, msg, sig, ctx=b""):
    if len(ctx) > 255:
        return False
    mprime = bytes([0, len(ctx)]) + ctx + msg
    return verify_internal(pk, mprime, sig)
