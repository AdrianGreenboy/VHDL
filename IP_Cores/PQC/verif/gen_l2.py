#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 2
# gen_l2.py: reference vectors for the rounding, compression and packing
# blocks, plus exhaustive verification of the multiply-and-shift constants
# that replace division in the RTL datapath.
# =============================================================================
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "oracle"))
import mlkem768 as kem
import mldsa65 as dsa

QK, QD = 3329, 8380417
G2 = (QD - 1) // 32
D = 13

CMUL = {1: (24, 5040), 4: (26, 20159), 10: (33, 2580335), 12: (33, 2580335)}
DMUL, DSHF = 8396809, 42


def verify_constants():
    for d, (s, m) in CMUL.items():
        for x in range(QK):
            n = (x << d) + QK // 2
            assert ((n * m) >> s) % (1 << d) == (n // QK) % (1 << d), \
                "compress constant wrong at d=%d x=%d" % (d, x)
    for r in range(QD):
        assert ((r * DMUL) >> DSHF) == r // (2 * G2), \
            "decompose constant wrong at r=%d" % r
    print("constants verified exhaustively: %d compress inputs per width, "
          "%d decompose inputs" % (QK, QD))


def directed_compress_cases():
    """Inputs where a one-off error in the multiply-and-shift constant shows.

    The multiplier is only wrong for a handful of inputs, so uniform sampling
    misses it: for d=1 a single input in 3329 distinguishes 5040 from 5039.
    These cases are computed, not guessed.
    """
    out = {}
    for d, (sh, m) in CMUL.items():
        xs = set()
        for delta in (-1, 1):
            for x in range(QK):
                n = (x << d) + QK // 2
                if ((n * (m + delta)) >> sh) % (1 << d) != \
                   ((n * m) >> sh) % (1 << d):
                    xs.add(x)
        out[d] = sorted(xs)
    return out


def directed_decompose_cases():
    """Residues where a one-off error in the decompose multiplier shows.

    Only the exact multiples of 2*gamma2 distinguish the correct constant from
    its neighbours: 16 residues out of 8380417.
    """
    xs = set()
    for delta in (-1, 1):
        for r in range(0, QD, 2 * G2):
            for off in (0, 1, 2 * G2 - 1):
                v = r + off
                if v < QD and ((v * (DMUL + delta)) >> DSHF) != \
                              ((v * DMUL) >> DSHF):
                    xs.add(v)
    return sorted(xs)


def directed_usehint_cases():
    """Residues that force UseHint to wrap at both ends of the range.

    r1 = 15 with r0 > 0 exercises the wrap to 0; r1 = 0 with r0 <= 0 exercises
    the wrap to 15. Neither occurs often enough to appear by sampling.
    """
    hi, lo = None, None
    for r in range(QD):
        r1, r0 = dsa.decompose(r)
        if hi is None and r1 == 15 and r0 > 0:
            hi = r
        if lo is None and r1 == 0 and r0 <= 0:
            lo = r
        if hi is not None and lo is not None:
            break
    return [x for x in (hi, lo) if x is not None]


def emit():
    lines = []

    # --- Compress / Decompress, all widths, full domain sampled + boundaries
    dcc = directed_compress_cases()
    for d in (1, 4, 10, 12):
        xs = list(range(0, QK, max(1, QK // 40)))
        xs += [0, 1, QK // 2 - 1, QK // 2, QK // 2 + 1, QK - 2, QK - 1]
        xs += dcc[d]                      # constant-sensitive inputs
        for x in sorted(set(xs)):
            c = kem.compress(d, x)
            lines.append("CMP %d %d %d" % (d, x, c))
        ys = list(range(1 << d)) if d <= 4 else \
             sorted(set(list(range(0, 1 << d, max(1, (1 << d) // 40))) +
                        [0, 1, (1 << d) - 2, (1 << d) - 1]))
        for y in ys:
            lines.append("DCP %d %d %d" % (d, y, kem.decompress(d, y)))

    # --- Power2Round, sampled plus every boundary of the 2^13 window
    rs = sorted(set(list(range(0, QD, QD // 60)) +
                    [0, 1, QD - 1, (1 << (D - 1)), (1 << (D - 1)) + 1,
                     (1 << D) - 1, (1 << D), (1 << D) + 1]))
    for r in rs:
        hi, lo = dsa.power2round(r)
        lines.append("P2R %d %d %d" % (r, hi, lo))

    # --- Decompose, sampled plus the exact boundaries that matter
    bnd = [0, 1, G2 - 1, G2, G2 + 1, 2 * G2 - 1, 2 * G2, 2 * G2 + 1,
           QD - 2 * G2, QD - G2 - 1, QD - G2, QD - G2 + 1, QD - 2, QD - 1]
    # every multiple of 2*gamma2 and its neighbours
    k = 0
    while k * 2 * G2 < QD:
        for off in (-1, 0, 1):
            v = k * 2 * G2 + off
            if 0 <= v < QD:
                bnd.append(v)
        k += 1
    bnd += directed_decompose_cases()  # multiplier-sensitive residues
    rs = sorted(set(bnd + list(range(0, QD, QD // 60))))
    for r in rs:
        hi, lo = dsa.decompose(r)
        lines.append("DEC %d %d %d" % (r, hi, lo))

    # --- MakeHint / UseHint over a directed grid
    zs = [-2 * G2, -G2 - 1, -G2, -1, 0, 1, G2, G2 + 1, 2 * G2]
    rs2 = sorted(set([0, 1, G2, G2 + 1, 2 * G2, QD - 1, QD - G2] +
                     list(range(0, QD, QD // 12))))
    for r in rs2:
        for z in zs:
            h = dsa.make_hint(z, r)
            lines.append("MKH %d %d %d" % (z, r, h))
    rs2 = sorted(set(rs2 + directed_usehint_cases()))  # force both wraps
    for r in rs2:
        for h in (0, 1):
            lines.append("USH %d %d %d" % (h, r, dsa.use_hint(h, r)))

    with open("l2_vectors.txt", "w") as f:
        f.write("# Layer 2 reference vectors, generated from the Phase 0 "
                "oracles.\n")
        f.write("# CMP d x compress(d,x)      FIPS 203 sec 4.2.1\n")
        f.write("# DCP d y decompress(d,y)    FIPS 203 sec 4.2.1\n")
        f.write("# P2R r r1 r0                FIPS 204 Alg 35\n")
        f.write("# DEC r r1 r0                FIPS 204 Alg 36\n")
        f.write("# MKH z r hint               FIPS 204 Alg 39\n")
        f.write("# USH h r result             FIPS 204 Alg 40\n")
        for l in lines:
            f.write(l + "\n")
    return len(lines)


if __name__ == "__main__":
    verify_constants()
    n = emit()
    print("wrote l2_vectors.txt with %d cases" % n)
