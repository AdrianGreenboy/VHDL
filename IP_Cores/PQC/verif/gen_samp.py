#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 1
# gen_samp.py: reference vectors for the six samplers.
# Derived from the Phase 0 oracles, which are ACVP-validated against
# FIPS 203 / FIPS 204. Seeds are fixed so the vectors are reproducible.
# =============================================================================
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "oracle"))
import mlkem768 as kem
import mldsa65 as dsa

QK, QD = 3329, 8380417


def seeds(n, tag):
    return [hashlib.shake_256(tag + bytes([i])).digest(34) for i in range(n)]


out = []

# ---- S1 SampleNTT (FIPS 203 Alg 7): 34-byte seed -> 256 coefficients ----
for s in seeds(6, b"S1"):
    p = kem.sample_ntt(s)
    assert len(p) == 256 and all(0 <= x < QK for x in p)
    out.append(("S1", s.hex(), p))


def find_boundary_k(which):
    # Directed vectors: seeds whose SHAKE128 stream contains a candidate equal
    # to q exactly, one for each of the two candidates extracted per byte
    # triple. Without both, a `< q` to `<= q` mutation on the untested
    # candidate survives, since the exact value never occurs on random data.
    for i in range(1 << 24):
        sd = hashlib.shake_256(b"bd_" + which.encode() + i.to_bytes(4, "little")).digest(34)
        st = hashlib.shake_128(sd).digest(1008)
        pos = 0
        n = 0
        while pos + 3 <= len(st) and n < 256:
            b0, b1, b2 = st[pos], st[pos + 1], st[pos + 2]
            pos += 3
            d1 = b0 + 256 * (b1 % 16)
            d2 = (b1 // 16) + 16 * b2
            if which == "d1" and d1 == QK:
                return sd
            if which == "d2" and d2 == QK:
                return sd
            if d1 < QK and n < 256:
                n += 1
            if d2 < QK and n < 256:
                n += 1
    raise AssertionError("no boundary seed found for SampleNTT " + which)


for which in ("d1", "d2"):
    sd = find_boundary_k(which)
    out.append(("S1", sd.hex(), kem.sample_ntt(sd)))

# ---- S2 SamplePolyCBD eta=2 (FIPS 203 Alg 8) ----
# The seed field is the PRF input (32-byte s, one counter byte), so the sponge
# derives the 128-byte block itself exactly as PRF(eta, s, b) does in ML-KEM.
for i in range(6):
    sd = hashlib.shake_256(b"S2seed" + bytes([i])).digest(32) + bytes([i])
    blk = hashlib.shake_256(sd).digest(64 * 2)
    p = kem.sample_cbd(2, blk)
    assert len(p) == 256
    out.append(("S2", sd.hex(), p))

# ---- S3 RejNTTPoly (FIPS 204 Alg 30): 34-byte seed -> 256 coefficients ----
for s in seeds(6, b"S3"):
    p = dsa.rej_ntt_poly(s)
    assert len(p) == 256 and all(0 <= x < QD for x in p)
    out.append(("S3", s.hex(), p))


def find_boundary_d():
    # Same idea for the 23-bit rejection: a candidate equal to q exactly.
    for i in range(1 << 24):
        sd = hashlib.shake_256(b"bndd" + i.to_bytes(4, "little")).digest(34)
        st = hashlib.shake_128(sd).digest(840)
        pos = 0
        while pos + 3 <= len(st):
            z = st[pos] + 256 * st[pos + 1] + 65536 * (st[pos + 2] & 0x7F)
            pos += 3
            if z == QD:
                return sd
    raise AssertionError("no boundary seed found for RejNTTPoly")


sd = find_boundary_d()
out.append(("S3", sd.hex(), dsa.rej_ntt_poly(sd)))

# ---- S4 RejBoundedPoly (FIPS 204 Alg 31): 66-byte seed, eta=4 ----
for i in range(6):
    s = hashlib.shake_256(b"S4" + bytes([i])).digest(66)
    p = dsa.rej_bounded_poly(s)
    assert len(p) == 256
    # coefficients are in {q-4..q-1, 0, 1..4} centred on 0
    assert all(x <= 4 or x >= QD - 4 for x in p)
    out.append(("S4", s.hex(), p))

# ---- S5 SampleInBall tau=49 (FIPS 204 Alg 29): 48-byte c_tilde ----
for i in range(6):
    s = hashlib.shake_256(b"S5" + bytes([i])).digest(48)
    p = dsa.sample_in_ball(s)
    nz = sum(1 for x in p if x != 0)
    assert nz == 49, nz
    assert all(x in (0, 1, QD - 1) for x in p)
    out.append(("S5", s.hex(), p))

# ---- S6 ExpandMask (FIPS 204 Alg 34) ----
# The absorbed message is rho'' followed by the 16-bit counter, little endian.
for i in range(6):
    rhop = hashlib.shake_256(b"S6" + bytes([i])).digest(64)
    p = dsa.expand_mask(rhop, i)[0]   # counter = i, first polynomial
    assert len(p) == 256
    msg = rhop + bytes([i & 0xFF, i >> 8])
    out.append(("S6", msg.hex(), p))

with open("sampler_vectors.txt", "w") as f:
    f.write("# sampler_id seed_hex : 256 decimal coefficients\n")
    f.write("# S1 SampleNTT       FIPS 203 Alg 7   q=3329\n")
    f.write("# S2 SamplePolyCBD   FIPS 203 Alg 8   eta=2, seed is s||counter (PRF input)\n")
    f.write("# S3 RejNTTPoly      FIPS 204 Alg 30  q=8380417\n")
    f.write("# S4 RejBoundedPoly  FIPS 204 Alg 31  eta=4\n")
    f.write("# S5 SampleInBall    FIPS 204 Alg 29  tau=49\n")
    f.write("# S6 ExpandMask      FIPS 204 Alg 34  gamma1=2^19, seed is rhop||counter16\n")
    for sid, sd, p in out:
        f.write("%s %s %s\n" % (sid, sd, " ".join(str(x) for x in p)))

print("wrote %d sampler vectors (%d per sampler)" % (len(out), len(out) // 6))

# Rejection statistics: documents why signatures must hash data, not counts.
import collections
stats = collections.Counter()
for s in seeds(200, b"stat1"):
    n = 0
    length = 504
    while True:
        st = hashlib.shake_128(s).digest(length)
        c = []
        pos = 0
        while len(c) < 256 and pos + 3 <= length:
            b0, b1, b2 = st[pos], st[pos + 1], st[pos + 2]
            pos += 3
            d1 = b0 + 256 * (b1 % 16)
            d2 = (b1 // 16) + 16 * b2
            if d1 < QK:
                c.append(d1)
            if d2 < QK and len(c) < 256:
                c.append(d2)
        if len(c) == 256:
            n = pos
            break
        length += 168
    stats[n // 168] += 1
print("SampleNTT byte consumption spread (in 168-byte blocks):", dict(sorted(stats.items())))
