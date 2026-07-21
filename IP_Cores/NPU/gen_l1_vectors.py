#!/usr/bin/env python3
# HERCOSSNUX NPU - genera vectores L1 para MAC, requantize y pool.
# Los valores de referencia salen de la MISMA aritmetica del oraculo L4
# (funciones reimplementadas identicas), mas casos de borde dirigidos.
import sys, random

SHIFT = 31

def sx8(v):  return v - 256 if v >= 128 else v

def load_meta(path):
    with open(path) as f:
        for l in f:
            if l.startswith("# M1"):
                t = l.split()
                return int(t[2]), int(t[4]), int(t[6]), int(t[8])
    raise SystemExit("meta no encontrada")

def load_tensors(path):
    T = {}; cur = None
    with open(path) as f:
        for l in f:
            l = l.strip()
            if not l or l.startswith("#"): continue
            if l.startswith("@"):
                cur = l[1:].split()[0]; T[cur] = []; continue
            v = int(l, 16)
            T[cur].append(sx8(v) if len(l) == 2 else (v - (1 << 32) if v >= (1 << 31) else v))
    return T

def requant(acc, m, shift, relu):
    if relu and acc < 0: acc = 0
    v = (acc * m + (1 << (shift - 1))) >> shift
    if v > 127: v = 127
    if v < -128: v = -128
    return v

def main():
    wf = sys.argv[1]; outdir = sys.argv[2]
    M1, M2, M3, SH = load_meta(wf)
    assert SH == SHIFT
    T = load_tensors(wf)
    rnd = random.Random(0xBEEF)

    # ---------- MAC: cadenas de 9 productos (kernel 3x3) ----------
    # Estimulos: pesos reales de W1/W2 y activaciones int8 aleatorias + bordes.
    mac_cases = []
    W1 = T["W1"]; B1 = T["B1"]; W2 = T["W2"]; B2 = T["B2"]
    for n in range(40):
        if n < 20:
            base = (n * 9) % (len(W1) - 9)
            ws = W1[base:base+9]; bias = B1[n % len(B1)]
        else:
            base = (n * 9) % (len(W2) - 9)
            ws = W2[base:base+9]; bias = B2[n % len(B2)]
        if n % 7 == 0:
            acts = [127]*9          # borde superior
        elif n % 7 == 1:
            acts = [-128]*9         # borde inferior
        elif n % 7 == 2:
            acts = [0]*9
        else:
            acts = [rnd.randint(-128, 127) for _ in range(9)]
        acc = bias
        for a, w in zip(acts, ws):
            acc += a * w
        assert -(1 << 31) <= acc < (1 << 31), "vector MAC fuera de int32"
        mac_cases.append((bias, acts, ws, acc))

    with open(f"{outdir}/vec_mac.txt", "w") as f:
        f.write(f"# MAC vectors N={len(mac_cases)} (bias, 9x act, 9x w, acc_esperado)\n")
        for bias, acts, ws, acc in mac_cases:
            f.write(f"{bias & 0xFFFFFFFF:08x}\n")
            f.write(" ".join(f"{a & 0xFF:02x}" for a in acts) + "\n")
            f.write(" ".join(f"{w & 0xFF:02x}" for w in ws) + "\n")
            f.write(f"{acc & 0xFFFFFFFF:08x}\n")

    # ---------- REQUANT: barrido con M reales + bordes de saturacion ----------
    rq_cases = []
    for m in (M1, M2, M3):
        # Umbral exacto donde el resultado cruza +127 / -128
        thr_hi = ((127 * (1 << SHIFT)) + (1 << (SHIFT-1))) // m
        thr_lo = ((-128 * (1 << SHIFT)) - (1 << (SHIFT-1))) // m
        interesting = [0, 1, -1, thr_hi - 1, thr_hi, thr_hi + 1,
                       thr_lo - 1, thr_lo, thr_lo + 1,
                       (1 << 30), -(1 << 30), (1 << 31) - 1, -(1 << 31)]
        for acc in interesting:
            if not (-(1 << 31) <= acc < (1 << 31)): continue
            for relu in (0, 1):
                rq_cases.append((acc, m, relu, requant(acc, m, SHIFT, relu == 1)))
        for _ in range(30):
            acc = rnd.randint(-(1 << 26), (1 << 26))
            relu = rnd.randint(0, 1)
            rq_cases.append((acc, m, relu, requant(acc, m, SHIFT, relu == 1)))

    with open(f"{outdir}/vec_requant.txt", "w") as f:
        f.write(f"# REQUANT vectors N={len(rq_cases)} (acc, mult, relu, esperado)\n")
        for acc, m, relu, exp in rq_cases:
            f.write(f"{acc & 0xFFFFFFFF:08x} {m & 0xFFFFFFFF:08x} {relu} {exp & 0xFF:02x}\n")

    # ---------- POOL: ventanas 2x2 con bordes de signo ----------
    pool_cases = []
    fixed = [(-128,-128,-128,-128), (127,127,127,127), (-128,127,-128,127),
             (0,-1,-2,-3), (-1,-1,-1,0), (127,-128,0,1), (5,5,5,5),
             (-128,-127,-126,-125), (100,-100,50,-50), (0,0,0,0)]
    for w in fixed:
        pool_cases.append((w, max(w)))
    for _ in range(40):
        w = tuple(rnd.randint(-128, 127) for _ in range(4))
        pool_cases.append((w, max(w)))

    with open(f"{outdir}/vec_pool.txt", "w") as f:
        f.write(f"# POOL vectors N={len(pool_cases)} (d00 d01 d10 d11 esperado)\n")
        for w, exp in pool_cases:
            f.write(" ".join(f"{v & 0xFF:02x}" for v in w) + f" {exp & 0xFF:02x}\n")

    print(f"L1 VECTORES mac={len(mac_cases)} requant={len(rq_cases)} pool={len(pool_cases)}")

main()
