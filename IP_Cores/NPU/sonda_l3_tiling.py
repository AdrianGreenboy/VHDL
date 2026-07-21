#!/usr/bin/env python3
# HERCOSSNUX NPU - Layer 3, SONDA 1: tiling de canales.
#
# El array es de 8x8 (PE_DIM). La red necesita:
#   conv1:  1 -> 8   (1 tile de salida, 7 filas ociosas)
#   conv2:  8 -> 16  (2 tiles de salida)
#   fc  : 256 -> 10  (32 tiles de entrada x 2 tiles de salida)
#
# Esta sonda verifica que la particion en tiles reproduce BIT A BIT el
# resultado del oraculo. Si falla, no tiene sentido escribir RTL.
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

def requant(acc, m, shift, relu):
    if relu and acc < 0: acc = 0
    v = (acc * m + (1 << (shift - 1))) >> shift
    if v > 127: v = 127
    if v < -128: v = -128
    return v

def conv_tiled(x, C, H, W, O, wts, bias, m, shift, dim=PE_DIM):
    """Convolucion 3x3 padding-same con tiling de canales de entrada y salida.

    El acumulador int32 vive FUERA del array: cada tile de entrada aporta una
    suma parcial que se acumula antes del requantize. Esto es lo que el
    secuenciador debe hacer en hardware.
    """
    n_ti = (C + dim - 1) // dim      # tiles de entrada
    n_to = (O + dim - 1) // dim      # tiles de salida

    acc = [[[0]*W for _ in range(H)] for _ in range(O)]
    for o in range(O):
        for y in range(H):
            for xx in range(W):
                acc[o][y][xx] = bias[o]

    for to in range(n_to):
        o_base = to * dim
        for ti in range(n_ti):
            c_base = ti * dim
            # Un "pase" del array: 8 canales in x 8 canales out
            for oo in range(dim):
                o = o_base + oo
                if o >= O: continue
                for y in range(H):
                    for xx in range(W):
                        s = 0
                        for cc in range(dim):
                            c = c_base + cc
                            if c >= C: continue
                            for ky in range(3):
                                for kx in range(3):
                                    iy = y + ky - 1; ix = xx + kx - 1
                                    if 0 <= iy < H and 0 <= ix < W:
                                        s += x[c][iy][ix] * wts[((o*C + c)*3 + ky)*3 + kx]
                        acc[o][y][xx] += s

    out = [[[0]*W for _ in range(H)] for _ in range(O)]
    for o in range(O):
        for y in range(H):
            for xx in range(W):
                a = acc[o][y][xx]
                assert -(1 << 31) <= a < (1 << 31), "conv_tiled: acc fuera de int32"
                out[o][y][xx] = requant(a, m, shift, True)
    return out

def fc_tiled(flat, O, I, wts, bias, dim=PE_DIM):
    """FC con tiling: acumulador int32 fuera del array."""
    acc = [bias[o] for o in range(O)]
    n_ti = (I + dim - 1) // dim
    n_to = (O + dim - 1) // dim
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

    # Leer imagenes doradas
    with open(gf) as f:
        lines = [l.rstrip("\n") for l in f]
    imgs = []; i = 0
    while i < len(lines):
        l = lines[i]
        if l.startswith("IMG"):
            cls = int(l.split()[3]); i += 1
            img = []
            for r in range(16):
                img.append([O.sx8(int(h, 16)) for h in lines[i].split()]); i += 1
            imgs.append((cls, img))
            continue
        i += 1

    n_test = 4
    bad_c1 = bad_c2 = bad_fc = 0
    for n, (cls, img) in enumerate(imgs[:n_test]):
        # --- conv1: referencia vs tiled ---
        ref1 = O.conv3x3([img], 1, 16, 16, 8, T["W1"], T["B1"], M1, SH)
        til1 = conv_tiled([img], 1, 16, 16, 8, T["W1"], T["B1"], M1, SH)
        if ref1 != til1: bad_c1 += 1
        p1 = O.pool2(ref1, 8, 16, 16)

        # --- conv2: 8 -> 16, requiere 2 tiles de salida ---
        ref2 = O.conv3x3(p1, 8, 8, 8, 16, T["W2"], T["B2"], M2, SH)
        til2 = conv_tiled(p1, 8, 8, 8, 16, T["W2"], T["B2"], M2, SH)
        if ref2 != til2: bad_c2 += 1
        p2 = O.pool2(ref2, 16, 8, 8)

        # --- fc: 256 -> 10 ---
        flat = [v for ch in p2 for row in ch for v in row]
        ref_acc = O.fc(flat, 10, 256, T["W3"], T["B3"])
        til_acc = fc_tiled(flat, 10, 256, T["W3"], T["B3"])
        if ref_acc != til_acc: bad_fc += 1

    print(f"SONDA_TILING imgs={n_test} conv1_dif={bad_c1} conv2_dif={bad_c2} fc_dif={bad_fc}")
    if bad_c1 or bad_c2 or bad_fc:
        print("El tiling NO reproduce el oraculo: detener antes del RTL.")
        sys.exit(1)

main()
