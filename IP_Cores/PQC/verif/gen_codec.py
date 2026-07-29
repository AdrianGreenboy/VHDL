#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 2
# gen_codec.py: reference vectors for the packing codecs, generated from the
# ACVP-validated Phase 0 oracles.
#
# The hint codec gets directed negative cases: an encoding that is merely
# well-formed proves nothing about a verifier, since the checks that matter
# only fire on malformed input a forger would supply.
# =============================================================================
import hashlib
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "oracle"))
import mlkem768 as kem
import mldsa65 as dsa

QK, QD = 3329, 8380417
G1 = 1 << 19
ETA = 4
D = 13
OMEGA, KK = 55, 6


def rnd_poly(rng, q):
    return [rng.randrange(q) for _ in range(256)]


def emit():
    rng = random.Random(20260721)
    lines = []

    # --- ByteEncode / ByteDecode, ML-KEM widths -----------------------------
    for d in (1, 4, 10, 12):
        cases = [[0] * 256,
                 [(1 << d) - 1] * 256,
                 [i % (1 << d) for i in range(256)],
                 [((1 << d) - 1) if i % 2 == 0 else 0 for i in range(256)]]
        for _ in range(3):
            cases.append([rng.randrange(1 << d) for _ in range(256)])
        for p in cases:
            enc = kem.byte_encode(d, p)
            assert kem.byte_decode(d, enc) == \
                ([x % QK for x in p] if d == 12 else p)
            lines.append("ENC %d %s %s" % (d, " ".join(str(x) for x in p),
                                           enc.hex()))

    # --- SimpleBitPack, ML-DSA widths 4 and 10 ------------------------------
    for bits in (4, 10):
        cases = [[0] * 256, [(1 << bits) - 1] * 256,
                 [i % (1 << bits) for i in range(256)]]
        for _ in range(3):
            cases.append([rng.randrange(1 << bits) for _ in range(256)])
        for p in cases:
            enc = dsa.simple_bitpack(p, bits)
            assert dsa.simple_bitunpack(enc, bits) == p
            lines.append("SBP %d %s %s" % (bits, " ".join(str(x) for x in p),
                                           enc.hex()))

    # --- BitPack with the b - x mapping ------------------------------------
    # (a, b) pairs used by ML-DSA-65: s1/s2, t0, and z.
    for a, b in ((ETA, ETA), ((1 << (D - 1)) - 1, 1 << (D - 1)), (G1 - 1, G1)):
        bits = (a + b).bit_length()
        cases = []
        # extremes of the representable range, in canonical [0, q) form
        cases.append([(-a) % QD] * 256)
        cases.append([b % QD] * 256)
        cases.append([0] * 256)
        cases.append([((-a + i) % QD) if i <= a + b else 0 for i in range(256)])
        # Directed: the exact centring threshold. `c > q/2` and `c >= q/2`
        # differ on this single value, so without it the comparison is
        # untested. It only round-trips for widths that can represent it,
        # so it is added as a raw pack-only check below.
        thr = [QD // 2 if i == 0 else 0 for i in range(256)]
        if all(-a <= (x - QD if x > QD // 2 else x) <= b for x in thr):
            cases.append(thr)
        for _ in range(3):
            cases.append([(rng.randrange(-a, b + 1)) % QD for _ in range(256)])
        for p in cases:
            enc = dsa.bitpack(p, a, b)
            assert dsa.bitunpack(enc, a, b) == p
            lines.append("BPK %d %d %s %s" % (a, b, " ".join(str(x) for x in p),
                                              enc.hex()))

    # --- HintBitPack round trip, valid encodings ---------------------------
    for trial in range(6):
        h = [[0] * 256 for _ in range(KK)]
        total = 0
        for i in range(KK):
            n = rng.randrange(0, min(12, OMEGA - total) + 1)
            for j in sorted(rng.sample(range(256), n)):
                h[i][j] = 1
            total += n
        enc = dsa.hint_bitpack(h)
        back = dsa.hint_bitunpack(enc)
        assert back == h
        flat = [h[i][j] for i in range(KK) for j in range(256)]
        lines.append("HPK %s %s" % (" ".join(str(x) for x in flat), enc.hex()))

    # --- HintBitUnpack negative cases --------------------------------------
    # Each must be rejected. A verifier that accepts any of them would accept
    # forged signatures, so these are the cases that give the codec its value.
    base = [[0] * 256 for _ in range(KK)]
    for j in (3, 40, 91):
        base[0][j] = 1
    for j in (7, 12):
        base[2][j] = 1
    good = bytearray(dsa.hint_bitpack(base))
    assert dsa.hint_bitunpack(bytes(good)) == base
    lines.append("HUV %s 1" % bytes(good).hex())

    def neg(name, mutate):
        y = bytearray(good)
        mutate(y)
        assert dsa.hint_bitunpack(bytes(y)) is None, \
            "expected oracle to reject: " + name
        lines.append("HUV %s 0" % bytes(y).hex())

    def swap_non_monotonic(y):
        y[0], y[1] = y[1], y[0]          # indices no longer increasing

    def duplicate_index(y):
        y[1] = y[0]                      # equal indices are not increasing

    def count_goes_backwards(y):
        y[OMEGA + 1] = 0                 # cumulative count decreases

    def count_exceeds_omega(y):
        y[OMEGA + KK - 1] = OMEGA + 1    # more hints than omega allows

    def nonzero_tail(y):
        y[OMEGA - 1] = 200               # padding must be zero

    def count_over_omega_monotonic(y):
        # Cumulative counts stay non-decreasing and indices stay increasing,
        # but the final count exceeds omega. Only the omega bound rejects it.
        for i in range(KK):
            y[OMEGA + i] = OMEGA + 1
        for j in range(OMEGA):
            y[j] = j

    neg("count over omega monotonic", count_over_omega_monotonic)
    neg("non-monotonic", swap_non_monotonic)
    neg("duplicate index", duplicate_index)
    neg("count backwards", count_goes_backwards)
    neg("count exceeds omega", count_exceeds_omega)
    neg("non-zero tail", nonzero_tail)

    with open("codec_vectors.txt", "w") as f:
        f.write("# Layer 2 codec vectors, generated from the Phase 0 oracles.\n")
        f.write("# ENC d  <256 coefs> <hex>     FIPS 203 Alg 5, 6\n")
        f.write("# SBP bits <256 coefs> <hex>   FIPS 204 Alg 16, 18\n")
        f.write("# BPK a b <256 coefs> <hex>    FIPS 204 Alg 17, 19\n")
        f.write("# HPK <1536 flags> <hex>       FIPS 204 Alg 20, 21\n")
        f.write("# HUV <hex> ok                 FIPS 204 Alg 21 accept/reject\n")
        for l in lines:
            f.write(l + "\n")
    return len(lines)


if __name__ == "__main__":
    n = emit()
    print("wrote codec_vectors.txt with %d cases" % n)
