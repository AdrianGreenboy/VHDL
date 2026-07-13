#!/usr/bin/env python3
# ============================================================================
# dot_oracle.py — Oraculo de mpc_dot_row (IP ADCS) + generador de vectores.
#
# Contrato numerico (adcs_pkg: NACC=16):
#   acc[j mod NACC] = fma(h[j], u[j], acc[j mod NACC]),  j = 0..n_dim-1
#   acc[0] = fma(acc[k], 1.0, acc[0]),                   k = 1..NACC-1
# El orden de acumulacion ES parte de la firma (fp no asociativo).
# Usa el fma32 de fp32_oracle.py (validado bit-identico en capa 1a).
# ============================================================================
import sys
import random
from fp32_oracle import fma32, signature

NACC = 16
D = 70
ONE = 0x3F800000


def dot_oracle(h, u, n_dim):
    accs = [0x00000000] * NACC
    for j in range(n_dim):
        k = j % NACC
        accs[k] = fma32(h[j], u[j], accs[k])
    r = accs[0]
    for k in range(1, NACC):
        r = fma32(accs[k], ONE, r)
    return r


def rand_fp(rng, e_lo=100, e_hi=150, p_zero=0.0):
    if p_zero and rng.random() < p_zero:
        return rng.getrandbits(1) << 31          # +/-0
    return (rng.getrandbits(1) << 31) | (rng.randrange(e_lo, e_hi) << 23) \
           | rng.getrandbits(23)


def gen_tests():
    rng = random.Random(0xD07)
    tests = []
    ndims = [1, 2, 4, 8, 15, 16, 17, 31, 32, 63, 70]
    # barrido de n_dim con datos realistas
    for nd in ndims:
        for _ in range(4):
            h = [rand_fp(rng) for _ in range(D)]
            u = [rand_fp(rng) for _ in range(D)]
            tests.append((nd, h, u))
    # mayoria n_dim=70 (caso real del MPC), con ceros en U (controles clampeados)
    for _ in range(100):
        h = [rand_fp(rng) for _ in range(D)]
        u = [rand_fp(rng, p_zero=0.15) for _ in range(D)]
        tests.append((70, h, u))
    # exponentes dispersos (alineamientos extremos en la reduccion)
    for _ in range(16):
        h = [rand_fp(rng, 60, 190) for _ in range(D)]
        u = [rand_fp(rng, 60, 190) for _ in range(D)]
        tests.append((70, h, u))
    return tests


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "vectors_dot.txt"
    tests = gen_tests()
    res = []
    with open(out, "w") as f:
        f.write(f"{len(tests)}\n")
        for nd, h, u in tests:
            r = dot_oracle(h, u, nd)
            res.append(r)
            f.write(f"{nd} {r:08X}\n")
            f.write(" ".join(f"{x:08X}" for x in h) + "\n")
            f.write(" ".join(f"{x:08X}" for x in u) + "\n")
    print(f"T={len(tests)}")
    print(f"FIRMA_ORACULO=0x{signature(res):08X}")


if __name__ == "__main__":
    main()
