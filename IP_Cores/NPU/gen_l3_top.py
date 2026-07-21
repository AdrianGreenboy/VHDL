#!/usr/bin/env python3
# HERCOSSNUX NPU - vectores del top level: inferencia completa de 32 imagenes.
# Criterio de PASS: SIG_CLASE y SIG_LOGITS identicas al oraculo, 32/32 clases.
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
    M1, M2, M3, SH = meta["M1"], meta["M2"], meta["M3"], meta["SHIFT"]

    with open(gf) as f:
        lines = [l.rstrip("\n") for l in f]
    imgs = []; i = 0
    while i < len(lines):
        if lines[i].startswith("IMG"):
            t = lines[i].split(); exp_cls = int(t[3]); i += 1
            img = []
            for r in range(16):
                img.append([O.sx8(int(h, 16)) for h in lines[i].split()]); i += 1
            imgs.append((exp_cls, img)); continue
        i += 1

    SIGP = 0x01000193
    def upd(s, v): return (s * SIGP + (v & 0xFF)) & 0xFFFFFFFF
    sig_cl = 0x811C9DC5
    sig_lg = 0x811C9DC5
    n_ok = 0

    with open(f"{outdir}/vec_l3_top.txt", "w") as f:
        f.write(f"# HERCOSSNUX NPU top level N={len(imgs)}\n")
        f.write("# W1: 8 lineas de 9\n")
        for o in range(8):
            blk = [T["W1"][(o*3 + ky)*3 + kx] for ky in range(3) for kx in range(3)]
            f.write(" ".join(f"{v & 0xFF:02x}" for v in blk) + "\n")
        f.write("# B1: 8 int32\n")
        f.write(" ".join(f"{T['B1'][o] & 0xFFFFFFFF:08x}" for o in range(8)) + "\n")
        f.write("# W2: 128 lineas de 9\n")
        for o in range(16):
            for c in range(8):
                blk = [T["W2"][((o*8 + c)*3 + ky)*3 + kx] for ky in range(3) for kx in range(3)]
                f.write(" ".join(f"{v & 0xFF:02x}" for v in blk) + "\n")
        f.write("# B2: 16 int32\n")
        f.write(" ".join(f"{T['B2'][o] & 0xFFFFFFFF:08x}" for o in range(16)) + "\n")
        f.write("# W3: 10 lineas de 256\n")
        for o in range(10):
            f.write(" ".join(f"{T['W3'][o*256 + i] & 0xFF:02x}" for i in range(256)) + "\n")
        f.write("# B3: 10 int32\n")
        f.write(" ".join(f"{T['B3'][o] & 0xFFFFFFFF:08x}" for o in range(10)) + "\n")
        f.write("# imagenes\n")
        for n, (exp_cls, img) in enumerate(imgs):
            a1 = O.conv3x3([img], 1, 16, 16, 8, T["W1"], T["B1"], M1, SH)
            p1 = O.pool2(a1, 8, 16, 16)
            a2 = O.conv3x3(p1, 8, 8, 8, 16, T["W2"], T["B2"], M2, SH)
            p2 = O.pool2(a2, 16, 8, 8)
            flat = [p2[c][y][x] for c in range(16) for y in range(4) for x in range(4)]
            acc = O.fc(flat, 10, 256, T["W3"], T["B3"])
            best = 0
            for k in range(10):
                if acc[k] > acc[best]: best = k
            lg = [O.requant(v, M3, SH) for v in acc]
            f.write(f"IMG {n}\n")
            for row in img:
                f.write(" ".join(f"{v & 0xFF:02x}" for v in row) + "\n")
            f.write("LOGITS " + " ".join(f"{v & 0xFF:02x}" for v in lg) + "\n")
            f.write(f"CLASE {best}\n")
            for v in lg: sig_lg = upd(sig_lg, v)
            sig_cl = upd(sig_cl, best)
            if best == exp_cls: n_ok += 1
        f.write(f"SIG_LOGITS {sig_lg:08x}\n")
        f.write(f"SIG_CLASE {sig_cl:08x}\n")

    print(f"L3 TOP imgs={len(imgs)} clases_ok={n_ok}/{len(imgs)} "
          f"SIG_LOGITS=0x{sig_lg:08X} SIG_CLASE=0x{sig_cl:08X}")

main()
