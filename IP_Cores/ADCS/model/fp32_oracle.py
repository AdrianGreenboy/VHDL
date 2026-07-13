#!/usr/bin/env python3
# ============================================================================
# fp32_oracle.py — Oraculo independiente del FMA fp32 del IP ADCS.
#
# Contrato numerico del IP (identico al FPO de Xilinx en lo observable):
#   * IEEE-754 binary32, redondeo RNE, FMA fusionada (redondeo unico).
#   * FTZ: entradas con exponente 0 => +/-0; resultados < 2^-126 => +/-0.
#   * NaN canonico 0x7FC00000. Inf*0 => qNaN. Inf-Inf => qNaN.
#   * Cancelacion exacta (terminos no nulos) => +0.
#   * Producto cero y c cero: signo = sp si sp==sc, si no +0.
#   * add(a,b) := fma(b, +1.0, a); sub(a,b) := fma(b, -1.0, a).
#
# Implementacion via fractions.Fraction (aritmetica racional exacta):
# mecanismo INDEPENDIENTE del RTL (que usa acumulador entero de 480 bits),
# para cerrar el punto ciego de modo comun.
# ============================================================================
import sys
import random
from fractions import Fraction

QNAN = 0x7FC00000


def classify(x):
    s = (x >> 31) & 1
    e = (x >> 23) & 0xFF
    f = x & 0x7FFFFF
    if e == 255:
        return ("nan" if f else "inf"), s, None
    if e == 0:                       # FTZ: subnormales = cero
        return "zero", s, Fraction(0)
    v = Fraction(2**23 + f) * Fraction(2) ** (e - 150)
    return "num", s, (-v if s else v)


def round_rne_ftz(v):
    """Redondea Fraction exacta a binary32 RNE con FTZ de salida."""
    if v == 0:
        return 0x00000000
    sign = 1 if v < 0 else 0
    a = -v if v < 0 else v
    # E tal que 2^E <= a < 2^(E+1)
    E = a.numerator.bit_length() - a.denominator.bit_length()
    if Fraction(2) ** E > a:
        E -= 1
    elif Fraction(2) ** (E + 1) <= a:
        E += 1
    m = a / (Fraction(2) ** (E - 23))          # en [2^23, 2^24)
    mi = m.numerator // m.denominator
    rem = m - mi
    half = Fraction(1, 2)
    if rem > half or (rem == half and (mi & 1)):
        mi += 1
    if mi == 2**24:
        mi = 2**23
        E += 1
    eb = E + 127
    if eb >= 255:
        return (sign << 31) | 0x7F800000
    if eb < 1:                                  # FTZ salida
        return sign << 31
    return (sign << 31) | (eb << 23) | (mi & 0x7FFFFF)


def fma32(a, b, c):
    ka, sa, va = classify(a)
    kb, sb, vb = classify(b)
    kc, sc, vc = classify(c)
    if "nan" in (ka, kb, kc):
        return QNAN
    sp = sa ^ sb
    if ka == "inf" or kb == "inf":
        if (ka == "inf" and kb == "zero") or (kb == "inf" and ka == "zero"):
            return QNAN
        if kc == "inf" and sc != sp:
            return QNAN
        return (sp << 31) | 0x7F800000
    if kc == "inf":
        return (sc << 31) | 0x7F800000
    if ka == "zero" or kb == "zero":            # producto exactamente cero
        if kc == "zero":
            return (sp << 31) if sp == sc else 0x00000000
        return (sc << 31) | (c & 0x7FFFFFFF)    # c canonizada (ya es normal)
    v = va * vb + vc                            # EXACTO
    if v == 0:
        return 0x00000000                       # cancelacion exacta -> +0
    return round_rne_ftz(v)


def add32(a, b):  return fma32(b, 0x3F800000, a)
def sub32(a, b):  return fma32(b, 0xBF800000, a)


# ---------------------------------------------------------------------------
# Generador de vectores de capa 1a
# ---------------------------------------------------------------------------
def gen_vectors():
    vec = []
    Z, NZ = 0x00000000, 0x80000000
    ONE, MONE = 0x3F800000, 0xBF800000
    INF, NINF = 0x7F800000, 0xFF800000
    NAN = 0x7FC00001
    MAXN, MINN = 0x7F7FFFFF, 0x00800000
    # --- dirigidos: especiales ---
    for a in (Z, NZ, ONE, MONE, INF, NINF, NAN, MAXN, MINN):
        for b in (Z, ONE, NINF, NAN, 0x40490FDB):
            for c in (Z, NZ, MONE, INF, NAN):
                vec.append((a, b, c))
    # --- dirigidos: cancelacion exacta y signos de cero ---
    vec += [(ONE, ONE, MONE), (MONE, ONE, ONE), (Z, ONE, NZ), (NZ, ONE, NZ),
            (Z, NZ, Z), (Z, NZ, NZ)]
    # --- dirigidos: overflow / frontera FTZ ---
    vec += [(MAXN, 0x40000000, Z), (MAXN, MAXN, NINF),
            (MINN, 0x3F000000, Z),                      # 2^-126 * 0.5 -> FTZ
            (MINN, ONE, 0x80800000),                    # cancelacion en el minimo
            (0x00FFFFFF, 0x3F7FFFFF, Z)]
    # --- dirigidos: empates RNE (c = media ULP de b) ---
    rng0 = random.Random(0x1E5)
    for _ in range(40):
        eb = rng0.randrange(60, 190)
        b = (eb << 23) | rng0.getrandbits(23)
        c = ((eb - 24) << 23)                            # 1.0 * 2^(eb-151+... )
        for sb in (0, 1 << 31):
            for scv in (0, 1 << 31):
                vec.append((ONE, b | sb, c | scv))
    # --- dirigidos: sticky decisivo (guard=1, sticky=1) ---
    for _ in range(40):
        eb = rng0.randrange(80, 170)
        b = (eb << 23) | rng0.getrandbits(23) | 1
        c = ((eb - 25) << 23) | rng0.getrandbits(23) | 1
        vec.append((ONE, b, c))
    # --- aleatorios: patrones completos ---
    rng = random.Random(0xADC5)
    for _ in range(8000):
        vec.append((rng.getrandbits(32), rng.getrandbits(32), rng.getrandbits(32)))
    # --- aleatorios: exponentes agrupados (interaccion de alineamiento) ---
    def clust(rng, base, spread):
        s = rng.getrandbits(1) << 31
        e = min(254, max(1, base + rng.randrange(-spread, spread + 1)))
        return s | (e << 23) | rng.getrandbits(23)
    for _ in range(12000):
        base = rng.randrange(30, 225)
        vec.append((clust(rng, base, 2), clust(rng, base, 2),
                    clust(rng, base + rng.randrange(-30, 31), 6)))
    return vec


def signature(results):
    sig = 0
    for r in results:
        sig = ((sig << 1) | (sig >> 31)) & 0xFFFFFFFF
        sig ^= r
    return sig


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "vectors_fma.txt"
    vec = gen_vectors()
    res = [fma32(a, b, c) for (a, b, c) in vec]
    with open(out, "w") as f:
        f.write(f"{len(vec)}\n")
        for (a, b, c), r in zip(vec, res):
            f.write(f"{a:08X} {b:08X} {c:08X} {r:08X}\n")
    print(f"N={len(vec)}")
    print(f"FIRMA_ORACULO=0x{signature(res):08X}")


if __name__ == "__main__":
    main()
