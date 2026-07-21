#!/usr/bin/env python3
# HERCOSSNUX NPU - Layer 3, SONDA 4: secuencia completa de la red.
#
# Emula el ORDEN EXACTO de operaciones que ejecutara el secuenciador en
# hardware, incluyendo el orden de aplanado (flatten) que alimenta la FC.
# Un error de orden en el flatten es invisible en las capas convolucionales
# y solo aparece al final: por eso se verifica aqui, antes del RTL.
#
# Criterio: clase predicha y firma identicas al oraculo en las 32 imagenes.
import sys, importlib.util

PE_DIM = 8

def load_oracle(path):
    spec = importlib.util.spec_from_file_location("oracle_npu", path)
    mod = importlib.util.module_from_spec(spec)
    saved = sys.argv; sys.argv = ["oracle_npu"]
    try: spec.loader.exec_module(mod)
    except (SystemExit, IndexError): pass
    finally: sys.argv = saved
    return mod

def requant(acc, m, shift, relu=True):
    if relu and acc < 0: acc = 0
    v = (acc * m + (1 << (shift - 1))) >> shift
    if v > 127: v = 127
    if v < -128: v = -128
    return v

def conv_seq(x, C, H, W, O, wts, bias, m, shift, dim=PE_DIM):
    """Convolucion por tiles, en el orden en que la ejecutara el secuenciador:
       para cada tile de salida -> para cada pixel -> 9 pasos de kernel."""
    n_to = (O + dim - 1) // dim
    n_ti = (C + dim - 1) // dim
    out = [[[0]*W for _ in range(H)] for _ in range(O)]

    for to in range(n_to):
        for y in range(H):
            for xx in range(W):
                # acumulador int32 por canal de salida del tile
                acc = [0]*dim
                for oo in range(dim):
                    o = to*dim + oo
                    if o < O:
                        acc[oo] = bias[o]
                for ti in range(n_ti):
                    for ky in range(3):
                        for kx in range(3):
                            iy = y + ky - 1; ix = xx + kx - 1
                            for oo in range(dim):
                                o = to*dim + oo
                                if o >= O: continue
                                s = 0
                                for cc in range(dim):
                                    c = ti*dim + cc
                                    if c >= C: continue
                                    if 0 <= iy < H and 0 <= ix < W:
                                        s += x[c][iy][ix] * wts[((o*C + c)*3 + ky)*3 + kx]
                                acc[oo] += s
                for oo in range(dim):
                    o = to*dim + oo
                    if o >= O: continue
                    a = acc[oo]
                    assert -(1 << 31) <= a < (1 << 31), "conv_seq: acc fuera de int32"
                    out[o][y][xx] = requant(a, m, shift, True)
    return out

def pool_seq(x, C, H, W):
    out = [[[0]*(W//2) for _ in range(H//2)] for _ in range(C)]
    for c in range(C):
        for y in range(H//2):
            for xx in range(W//2):
                out[c][y][xx] = max(x[c][2*y][2*xx],   x[c][2*y][2*xx+1],
                                    x[c][2*y+1][2*xx], x[c][2*y+1][2*xx+1])
    return out

def flatten_seq(x, C, H, W):
    """Orden de aplanado: canal -> fila -> columna (C-major).
    Debe coincidir con el orden que el oraculo usa para indexar W3."""
    return [x[c][y][xx] for c in range(C) for y in range(H) for xx in range(W)]

def fc_seq(flat, O, I, wts, bias, dim=PE_DIM):
    n_ti = (I + dim - 1) // dim
    n_to = (O + dim - 1) // dim
    acc = [0]*O
    for o in range(O):
        acc[o] = bias[o]
    for to in range(n_to):
        for oo in range(dim):
            o = to*dim + oo
            if o >= O: continue
            for ti in range(n_ti):
                s = 0
                for cc in range(dim):
                    i = ti*dim + cc
                    if i >= I: continue
                    s += flat[i] * wts[o*I + i]
                acc[o] += s
    return acc

def main():
    oracle_py, wf, gf = sys.argv[1], sys.argv[2], sys.argv[3]
    O = load_oracle(oracle_py)
    T, meta = O.load_weights(wf)
    M1, M2, M3, SH = meta["M1"], meta["M2"], meta["M3"], meta["SHIFT"]

    with open(gf) as f:
        lines = [l.rstrip("\n") for l in f]
    imgs = []; i = 0; golden_sig = None
    while i < len(lines):
        l = lines[i]
        if l.startswith("SIGNATURE"):
            golden_sig = int(l.split()[1], 16); i += 1; continue
        if l.startswith("IMG"):
            t = l.split(); exp_cls = int(t[3]); i += 1
            img = []
            for r in range(16):
                img.append([O.sx8(int(h, 16)) for h in lines[i].split()]); i += 1
            imgs.append((exp_cls, img))
            continue
        i += 1

    SIGP = 0x01000193
    sig = 0x811C9DC5
    def upd(s, v): return (s * SIGP + (v & 0xFF)) & 0xFFFFFFFF

    n_ok = 0
    for n, (exp_cls, img) in enumerate(imgs):
        a1 = conv_seq([img], 1, 16, 16, 8, T["W1"], T["B1"], M1, SH)
        p1 = pool_seq(a1, 8, 16, 16)
        sig_layer = p1
        for ch in sig_layer:
            for row in ch:
                for v in row: sig = upd(sig, v)

        a2 = conv_seq(p1, 8, 8, 8, 16, T["W2"], T["B2"], M2, SH)
        p2 = pool_seq(a2, 16, 8, 8)
        for ch in p2:
            for row in ch:
                for v in row: sig = upd(sig, v)

        flat = flatten_seq(p2, 16, 4, 4)
        acc = fc_seq(flat, 10, 256, T["W3"], T["B3"])
        best = 0
        for k in range(10):
            if acc[k] > acc[best]: best = k
        lg = [requant(v, M3, SH, False) for v in acc]
        for v in lg: sig = upd(sig, v)

        if best == exp_cls: n_ok += 1

    status = "OK" if (sig == golden_sig and n_ok == len(imgs)) else "FAIL"
    print(f"SONDA_SECUENCIA {status} imgs={len(imgs)} clases={n_ok}/{len(imgs)} "
          f"SIG=0x{sig:08X} GOLDEN=0x{golden_sig:08X}")
    if status != "OK":
        sys.exit(1)

main()
