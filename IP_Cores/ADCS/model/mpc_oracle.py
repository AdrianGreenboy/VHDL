#!/usr/bin/env python3
# ============================================================================
# mpc_oracle.py — Oraculo del mpc_engine (IP ADCS) + generador de vectores.
#
# Replica bit-exacto el solver PGD del RTL:
#   U = 0
#   repeat maxiter:
#     snap = U                                   (Jacobi: snapshot de inicio)
#     HU[i] = dot_oracle(H[i,:], snap, n)        (NACC=16 por fila)
#     t1    = fma(g[i], 1.0, HU[i])              (= HU+g)
#     t2    = fma(-step, t1, U[i])
#     U[i]  = clamp_sm(t2, umax)                 (entero signo-magnitud)
# -step = step con bit de signo invertido (exacto).
# ============================================================================
import sys
import struct
import random
from fp32_oracle import fma32, signature
from dot_oracle import dot_oracle

ONE = 0x3F800000


def f2b(x):
    return struct.unpack("<I", struct.pack("<f", x))[0]


def clamp_sm(x, umax):
    if (x & 0x7FFFFFFF) > (umax & 0x7FFFFFFF):
        return (x & 0x80000000) | (umax & 0x7FFFFFFF)
    return x


def solve_mpc(H, g, n, maxiter, step, umax):
    neg_step = step ^ 0x80000000
    U = [0x00000000] * n
    for _ in range(maxiter):
        snap = list(U)
        HU = [dot_oracle(H[i], snap + [0] * (len(H[i]) - n), n) for i in range(n)]
        for i in range(n):
            t1 = fma32(g[i], ONE, HU[i])
            t2 = fma32(neg_step, t1, U[i])
            U[i] = clamp_sm(t2, umax)
    return U


def rand_fp(rng, e_lo, e_hi):
    return (rng.getrandbits(1) << 31) | (rng.randrange(e_lo, e_hi) << 23) \
           | rng.getrandbits(23)


def gen_tests(small=False):
    rng = random.Random(0x39C)
    step_t = f2b(0.881230)      # parametros de tesis
    umax_t = f2b(0.05)
    tests = []
    if small:
        # subconjunto rapido para capa 3 (top integrado): solo casos chicos
        cfg = [(4, 1), (4, 2), (8, 2), (12, 3)]
        for n, mi in cfg:
            H = [[rand_fp(rng, 118, 130) for _ in range(n)] for _ in range(n)]
            g = [rand_fp(rng, 118, 130) for _ in range(n)]
            tests.append((n, mi, step_t, umax_t, H, g))
        return tests
    # (n, maxiter, step, umax): pequenos de diagnostico + caso real D=70
    cfg = [(4, 1), (4, 5), (8, 3), (12, 4), (16, 2), (70, 1), (70, 2), (70, 30)]
    for n, mi in cfg:
        H = [[rand_fp(rng, 118, 130) for _ in range(n)] for _ in range(n)]
        g = [rand_fp(rng, 118, 130) for _ in range(n)]
        tests.append((n, mi, step_t, umax_t, H, g))
    # umax grande (poca saturacion) y step pequeno
    for n, mi in [(12, 6), (70, 3)]:
        H = [[rand_fp(rng, 115, 125) for _ in range(n)] for _ in range(n)]
        g = [rand_fp(rng, 115, 125) for _ in range(n)]
        tests.append((n, mi, f2b(0.01), f2b(100.0), H, g))
    return tests


def main():
    args = [a for a in sys.argv[1:] if a != "--small"]
    small = "--small" in sys.argv
    out = args[0] if args else "vectors_mpc.txt"
    tests = gen_tests(small=small)
    allres = []
    sat_pos = sat_neg = 0
    with open(out, "w") as f:
        f.write(f"{len(tests)}\n")
        for n, mi, step, umax, H, g in tests:
            U = solve_mpc(H, g, n, mi, step, umax)
            for u in U:
                if (u & 0x7FFFFFFF) == (umax & 0x7FFFFFFF):
                    if u >> 31: sat_neg += 1
                    else:       sat_pos += 1
            allres.extend(U)
            f.write(f"{n} {mi} {step:08X} {umax:08X}\n")
            for i in range(n):
                f.write(" ".join(f"{x:08X}" for x in H[i]) + "\n")
            f.write(" ".join(f"{x:08X}" for x in g) + "\n")
            f.write(" ".join(f"{x:08X}" for x in U) + "\n")
    if not small:
        assert sat_pos > 0 and sat_neg > 0, "vectores sin saturacion en ambos signos"
    print(f"T={len(tests)} SAT+={sat_pos} SAT-={sat_neg}")
    print(f"FIRMA_ORACULO=0x{signature(allres):08X}")


if __name__ == "__main__":
    main()
