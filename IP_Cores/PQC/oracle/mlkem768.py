#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC - Phase 0 oracle
# ML-KEM-768 reference implementation, bit-exact per FIPS 203 (final, Aug 2024)
# Pure Python 3 stdlib. Hashes via hashlib (SHA3/SHAKE validated by CPython).
# This oracle is the golden model for RTL Layers 2-4.
# =============================================================================
import hashlib

# ---- Parameters: ML-KEM-768 (FIPS 203 Table 2) ----
N = 256
Q = 3329
K = 3
ETA1 = 2
ETA2 = 2
DU = 10
DV = 4

# ---- Hash wrappers (FIPS 203 Section 4.1) ----
def H(b):  return hashlib.sha3_256(b).digest()
def G(b):  return hashlib.sha3_512(b).digest()
def J(b):  return hashlib.shake_256(b).digest(32)
def PRF(eta, s, b): return hashlib.shake_256(s + bytes([b])).digest(64 * eta)

# ---- Precomputed zetas (FIPS 203 Appendix A) ----
def _bitrev7(i):
    r = 0
    for b in range(7):
        r = (r << 1) | ((i >> b) & 1)
    return r

ZETAS = [pow(17, _bitrev7(i), Q) for i in range(128)]          # NTT twiddles
GAMMAS = [pow(17, 2 * _bitrev7(i) + 1, Q) for i in range(128)] # BaseCaseMultiply

# ---- NTT / INTT (FIPS 203 Algorithms 9, 10) ----
def ntt(f):
    f = list(f)
    i = 1
    ln = 128
    while ln >= 2:
        for start in range(0, 256, 2 * ln):
            z = ZETAS[i]; i += 1
            for j in range(start, start + ln):
                t = (z * f[j + ln]) % Q
                f[j + ln] = (f[j] - t) % Q
                f[j] = (f[j] + t) % Q
        ln >>= 1
    return f

def intt(f):
    f = list(f)
    i = 127
    ln = 2
    while ln <= 128:
        for start in range(0, 256, 2 * ln):
            z = ZETAS[i]; i -= 1
            for j in range(start, start + ln):
                t = f[j]
                f[j] = (t + f[j + ln]) % Q
                f[j + ln] = (z * (f[j + ln] - t)) % Q
        ln <<= 1
    return [(x * 3303) % Q for x in f]  # 3303 = 128^-1 mod q

# ---- BaseCaseMultiply / MultiplyNTTs (FIPS 203 Algorithms 11, 12) ----
def ntt_mul(a, b):
    c = [0] * 256
    for i in range(128):
        a0, a1 = a[2 * i], a[2 * i + 1]
        b0, b1 = b[2 * i], b[2 * i + 1]
        c[2 * i] = (a0 * b0 + a1 * b1 * GAMMAS[i]) % Q
        c[2 * i + 1] = (a0 * b1 + a1 * b0) % Q
    return c

def poly_add(a, b): return [(x + y) % Q for x, y in zip(a, b)]
def poly_sub(a, b): return [(x - y) % Q for x, y in zip(a, b)]

# ---- Sampling (FIPS 203 Algorithms 7, 8) ----
def sample_ntt(seed34):
    # Incremental SHAKE128 squeeze: 3 bytes -> up to 2 coefficients
    coeffs = []
    length = 504  # 168*3, one Keccak block batch; extend if needed
    while True:
        stream = hashlib.shake_128(seed34).digest(length)
        coeffs = []
        pos = 0
        while len(coeffs) < 256 and pos + 3 <= length:
            b0, b1, b2 = stream[pos], stream[pos + 1], stream[pos + 2]
            pos += 3
            d1 = b0 + 256 * (b1 % 16)
            d2 = (b1 // 16) + 16 * b2
            if d1 < Q:
                coeffs.append(d1)
            if d2 < Q and len(coeffs) < 256:
                coeffs.append(d2)
        if len(coeffs) == 256:
            return coeffs
        length += 168

def sample_cbd(eta, data):
    # FIPS 203 Algorithm 8 (SamplePolyCBD)
    bits = []
    for byte in data:
        for i in range(8):
            bits.append((byte >> i) & 1)
    f = []
    for i in range(256):
        x = sum(bits[2 * i * eta + j] for j in range(eta))
        y = sum(bits[2 * i * eta + eta + j] for j in range(eta))
        f.append((x - y) % Q)
    return f

# ---- Compression / byte encoding (FIPS 203 Section 4.2.1, Algorithms 5, 6) ----
def compress(d, x):   return ((x << d) + Q // 2) // Q % (1 << d)
def decompress(d, y): return (y * Q + (1 << (d - 1))) >> d

def byte_encode(d, f):
    out = bytearray()
    acc = 0
    accbits = 0
    for x in f:
        acc |= x << accbits
        accbits += d
        while accbits >= 8:
            out.append(acc & 0xFF)
            acc >>= 8
            accbits -= 8
    return bytes(out)

def byte_decode(d, b):
    f = []
    acc = 0
    accbits = 0
    mask = (1 << d) - 1
    for byte in b:
        acc |= byte << accbits
        accbits += 8
        while accbits >= d and len(f) < 256:
            f.append(acc & mask)
            acc >>= d
            accbits -= d
    if d == 12:
        f = [x % Q for x in f]
    return f

# ---- K-PKE (FIPS 203 Algorithms 13, 14, 15) ----
def _expand_a(rho):
    return [[sample_ntt(rho + bytes([j, i])) for j in range(K)] for i in range(K)]

def kpke_keygen(d):
    g = G(d + bytes([K]))
    rho, sigma = g[:32], g[32:]
    a_hat = _expand_a(rho)
    n = 0
    s = []
    for _ in range(K):
        s.append(sample_cbd(ETA1, PRF(ETA1, sigma, n))); n += 1
    e = []
    for _ in range(K):
        e.append(sample_cbd(ETA1, PRF(ETA1, sigma, n))); n += 1
    s_hat = [ntt(p) for p in s]
    e_hat = [ntt(p) for p in e]
    t_hat = []
    for i in range(K):
        acc = [0] * 256
        for j in range(K):
            acc = poly_add(acc, ntt_mul(a_hat[i][j], s_hat[j]))
        t_hat.append(poly_add(acc, e_hat[i]))
    ek = b"".join(byte_encode(12, t) for t in t_hat) + rho
    dk = b"".join(byte_encode(12, s) for s in s_hat)
    return ek, dk

def kpke_encrypt(ek, m, r):
    t_hat = [byte_decode(12, ek[384 * i:384 * (i + 1)]) for i in range(K)]
    rho = ek[384 * K:]
    a_hat = _expand_a(rho)
    n = 0
    y = []
    for _ in range(K):
        y.append(sample_cbd(ETA1, PRF(ETA1, r, n))); n += 1
    e1 = []
    for _ in range(K):
        e1.append(sample_cbd(ETA2, PRF(ETA2, r, n))); n += 1
    e2 = sample_cbd(ETA2, PRF(ETA2, r, n))
    y_hat = [ntt(p) for p in y]
    u = []
    for i in range(K):
        acc = [0] * 256
        for j in range(K):
            acc = poly_add(acc, ntt_mul(a_hat[j][i], y_hat[j]))  # A^T
        u.append(poly_add(intt(acc), e1[i]))
    mu = [decompress(1, b) for b in byte_decode(1, m)]
    acc = [0] * 256
    for j in range(K):
        acc = poly_add(acc, ntt_mul(t_hat[j], y_hat[j]))
    v = poly_add(poly_add(intt(acc), e2), mu)
    c1 = b"".join(byte_encode(DU, [compress(DU, x) for x in ui]) for ui in u)
    c2 = byte_encode(DV, [compress(DV, x) for x in v])
    return c1 + c2

def kpke_decrypt(dk, c):
    c1 = c[:32 * DU * K]
    c2 = c[32 * DU * K:]
    u = [[decompress(DU, y) for y in byte_decode(DU, c1[32 * DU * i:32 * DU * (i + 1)])]
         for i in range(K)]
    v = [decompress(DV, y) for y in byte_decode(DV, c2)]
    s_hat = [byte_decode(12, dk[384 * i:384 * (i + 1)]) for i in range(K)]
    acc = [0] * 256
    for j in range(K):
        acc = poly_add(acc, ntt_mul(s_hat[j], ntt(u[j])))
    w = poly_sub(v, intt(acc))
    return byte_encode(1, [compress(1, x) for x in w])

# ---- ML-KEM (FIPS 203 Algorithms 16, 17, 18) ----
def mlkem_keygen_internal(d, z):
    ek_pke, dk_pke = kpke_keygen(d)
    ek = ek_pke
    dk = dk_pke + ek + H(ek) + z
    return ek, dk

def mlkem_encaps_internal(ek, m):
    g = G(m + H(ek))
    key, r = g[:32], g[32:]
    c = kpke_encrypt(ek, m, r)
    return key, c

def mlkem_decaps_internal(dk, c):
    dk_pke = dk[:384 * K]
    ek_pke = dk[384 * K:768 * K + 32]
    h = dk[768 * K + 32:768 * K + 64]
    z = dk[768 * K + 64:768 * K + 96]
    m2 = kpke_decrypt(dk_pke, c)
    g = G(m2 + h)
    key2, r2 = g[:32], g[32:]
    kbar = J(z + c)
    c2 = kpke_encrypt(ek_pke, m2, r2)
    if c != c2:
        key2 = kbar
    return key2
