#!/usr/bin/env python3
# HERCOSSNUX NPU - Layer 3, vectores para la SONDA 2 (protocolo de tile).
#
# Extrae del oraculo, para UNA imagen real:
#   - la entrada de conv2 (8 canales, 8x8) = salida de conv1 tras pooling
#   - los pesos del tile de salida 0 (canales 0..7 de conv2)
#   - la suma parcial ESPERADA por pixel y canal, SIN bias y SIN requantize
#
# Verificar la suma parcial cruda es mas estricto que verificar la salida
# final: el requantize podria enmascarar errores de acumulacion.
import sys, importlib.util

def load_oracle(path):
    spec = importlib.util.spec_from_file_location("oracle_npu", path)
    mod = importlib.util.module_from_spec(spec)
    saved = sys.argv; sys.argv = ["oracle_npu"]
    try: spec.loader.exec_module(mod)
    except (SystemExit, IndexError): pass
    finally: sys.argv = saved
    return mod

def main():
    oracle_py, wf, gf, outdir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
    O = load_oracle(oracle_py)
    T, meta = O.load_weights(wf)
    M1, M2, SH = meta["M1"], meta["M2"], meta["SHIFT"]

    with open(gf) as f:
        lines = [l.rstrip("\n") for l in f]
    i = 0; img = None
    while i < len(lines):
        if lines[i].startswith("IMG"):
            i += 1; img = []
            for r in range(16):
                img.append([O.sx8(int(h, 16)) for h in lines[i].split()]); i += 1
            break
        i += 1

    # Entrada de conv2 = conv1 + pool
    a1 = O.conv3x3([img], 1, 16, 16, 8, T["W1"], T["B1"], M1, SH)
    p1 = O.pool2(a1, 8, 16, 16)      # 8 canales, 8x8

    C = 8; H = W = 8
    # Suma parcial cruda del tile de salida 0 (canales 0..7), sin bias
    psum = [[[0]*W for _ in range(H)] for _ in range(8)]
    for o in range(8):
        for y in range(H):
            for xx in range(W):
                s = 0
                for c in range(C):
                    for ky in range(3):
                        for kx in range(3):
                            iy = y + ky - 1; ix = xx + kx - 1
                            if 0 <= iy < H and 0 <= ix < W:
                                s += p1[c][iy][ix] * T["W2"][((o*C + c)*3 + ky)*3 + kx]
                assert -(1 << 31) <= s < (1 << 31), "psum fuera de int32"
                psum[o][y][xx] = s

    SIGP = 0x01000193
    sig = 0x811C9DC5
    def upd(s, v): return (s * SIGP + (v & 0xFF)) & 0xFFFFFFFF

    with open(f"{outdir}/vec_l3_tile.txt", "w") as f:
        f.write("# HERCOSSNUX NPU L3 sonda de tile: conv2 tile de salida 0\n")
        f.write("# entrada: 8 canales 8x8 int8\n")
        for c in range(C):
            for y in range(H):
                f.write(" ".join(f"{p1[c][y][x] & 0xFF:02x}" for x in range(W)) + "\n")
        f.write("# pesos: 64 pares (o,c) x 9, en lineas de 9\n")
        for o in range(8):
            for c in range(C):
                blk = [T["W2"][((o*C + c)*3 + ky)*3 + kx] for ky in range(3) for kx in range(3)]
                f.write(" ".join(f"{v & 0xFF:02x}" for v in blk) + "\n")
        f.write("# psum esperado: 8 canales 8x8 int32, orden y-x-o\n")
        for y in range(H):
            for x in range(W):
                f.write(" ".join(f"{psum[o][y][x] & 0xFFFFFFFF:08x}" for o in range(8)) + "\n")
                for o in range(8):
                    v = psum[o][y][x]
                    for b in range(4):
                        sig = upd(sig, (v >> (8*b)) & 0xFF)
        f.write(f"SIGNATURE {sig:08x}\n")

    mn = min(psum[o][y][x] for o in range(8) for y in range(H) for x in range(W))
    mx = max(psum[o][y][x] for o in range(8) for y in range(H) for x in range(W))
    print(f"L3 SONDA_TILE psum_rango=[{mn},{mx}] SIG=0x{sig:08X}")

main()
