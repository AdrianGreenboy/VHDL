#!/usr/bin/env python3
# HERCOSSNUX NPU - Layer 3, vectores del secuenciador de conv1+pool1.
#
# Emite:
#   - las 8 imagenes de entrada (int8, 16x16)
#   - los pesos y bias de conv1 en el orden que consumira el hardware
#   - la salida esperada de pool1 (8 canales, 8x8) con su firma
#
# La firma de pool1 es el criterio de PASS de la primera entrega del
# secuenciador, antes de construir conv2 y FC encima.
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
    oracle_py, wf, gf, outdir, n_img = (sys.argv[1], sys.argv[2], sys.argv[3],
                                        sys.argv[4], int(sys.argv[5]))
    O = load_oracle(oracle_py)
    T, meta = O.load_weights(wf)
    M1, SH = meta["M1"], meta["SHIFT"]

    with open(gf) as f:
        lines = [l.rstrip("\n") for l in f]
    imgs = []; i = 0
    while i < len(lines) and len(imgs) < n_img:
        if lines[i].startswith("IMG"):
            i += 1; img = []
            for r in range(16):
                img.append([O.sx8(int(h, 16)) for h in lines[i].split()]); i += 1
            imgs.append(img); continue
        i += 1

    SIGP = 0x01000193
    sig = 0x811C9DC5
    def upd(s, v): return (s * SIGP + (v & 0xFF)) & 0xFFFFFFFF

    with open(f"{outdir}/vec_l3_conv1.txt", "w") as f:
        f.write(f"# HERCOSSNUX NPU L3 conv1+pool1 N={len(imgs)}\n")
        f.write(f"# M1={M1} SHIFT={SH}\n")

        # Pesos de conv1: 8 canales de salida x 1 canal de entrada x 9
        f.write("# W1: 8 lineas de 9 (canal de salida o = 0..7)\n")
        for o in range(8):
            blk = [T["W1"][(o*1*3 + ky)*3 + kx] for ky in range(3) for kx in range(3)]
            f.write(" ".join(f"{v & 0xFF:02x}" for v in blk) + "\n")

        f.write("# B1: 8 valores int32\n")
        f.write(" ".join(f"{T['B1'][o] & 0xFFFFFFFF:08x}" for o in range(8)) + "\n")

        f.write("# imagenes y salida esperada de pool1\n")
        for n, img in enumerate(imgs):
            f.write(f"IMG {n}\n")
            for row in img:
                f.write(" ".join(f"{v & 0xFF:02x}" for v in row) + "\n")

            a1 = O.conv3x3([img], 1, 16, 16, 8, T["W1"], T["B1"], M1, SH)
            p1 = O.pool2(a1, 8, 16, 16)

            f.write("POOL1\n")
            for c in range(8):
                for y in range(8):
                    f.write(" ".join(f"{p1[c][y][x] & 0xFF:02x}" for x in range(8)) + "\n")
                    for x in range(8):
                        sig = upd(sig, p1[c][y][x])
        f.write(f"SIGNATURE {sig:08x}\n")

    print(f"L3 CONV1 vectores imgs={len(imgs)} SIG=0x{sig:08X}")

main()
