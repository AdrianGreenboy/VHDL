#!/usr/bin/env python3
# HERCOSSNUX NPU - Layer 3, vectores de la entrega 2 (conv2 + pool2 + FC + argmax).
#
# Emite firmas SEPARADAS por etapa, de modo que un fallo localice la etapa:
#   SIG_POOL2  : salida de pool2 (16 canales 4x4)
#   SIG_LOGITS : logits int8 tras requantize M3
#   SIG_CLASE  : clases predichas (argmax sobre el acumulador int32)
#
# Ademas emite los pesos de conv2 y FC en el orden que consumira el hardware.
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
    M1, M2, M3, SH = meta["M1"], meta["M2"], meta["M3"], meta["SHIFT"]

    with open(gf) as f:
        lines = [l.rstrip("\n") for l in f]
    imgs = []; i = 0
    while i < len(lines) and len(imgs) < n_img:
        if lines[i].startswith("IMG"):
            t = lines[i].split(); exp_cls = int(t[3]); i += 1
            img = []
            for r in range(16):
                img.append([O.sx8(int(h, 16)) for h in lines[i].split()]); i += 1
            imgs.append((exp_cls, img)); continue
        i += 1

    SIGP = 0x01000193
    def upd(s, v): return (s * SIGP + (v & 0xFF)) & 0xFFFFFFFF

    sig_p2 = 0x811C9DC5
    sig_lg = 0x811C9DC5
    sig_cl = 0x811C9DC5
    n_ok = 0

    with open(f"{outdir}/vec_l3_full.txt", "w") as f:
        f.write(f"# HERCOSSNUX NPU L3 entrega 2 N={len(imgs)}\n")
        f.write(f"# M1={M1} M2={M2} M3={M3} SHIFT={SH}\n")

        # W2: 16 canales de salida x 8 de entrada x 9 -> lineas de 9
        f.write("# W2: 128 lineas de 9 (orden o=0..15, c=0..7)\n")
        for o in range(16):
            for c in range(8):
                blk = [T["W2"][((o*8 + c)*3 + ky)*3 + kx]
                       for ky in range(3) for kx in range(3)]
                f.write(" ".join(f"{v & 0xFF:02x}" for v in blk) + "\n")

        f.write("# B2: 16 valores int32\n")
        f.write(" ".join(f"{T['B2'][o] & 0xFFFFFFFF:08x}" for o in range(16)) + "\n")

        # W3: 10 x 256 -> 10 lineas de 256
        f.write("# W3: 10 lineas de 256\n")
        for o in range(10):
            f.write(" ".join(f"{T['W3'][o*256 + i] & 0xFF:02x}" for i in range(256)) + "\n")

        f.write("# B3: 10 valores int32\n")
        f.write(" ".join(f"{T['B3'][o] & 0xFFFFFFFF:08x}" for o in range(10)) + "\n")

        f.write("# por imagen: POOL1 de entrada, POOL2, LOGITS, CLASE\n")
        for n, (exp_cls, img) in enumerate(imgs):
            a1 = O.conv3x3([img], 1, 16, 16, 8, T["W1"], T["B1"], M1, SH)
            p1 = O.pool2(a1, 8, 16, 16)          # entrada de esta entrega
            a2 = O.conv3x3(p1, 8, 8, 8, 16, T["W2"], T["B2"], M2, SH)
            p2 = O.pool2(a2, 16, 8, 8)
            flat = [p2[c][y][x] for c in range(16) for y in range(4) for x in range(4)]
            acc = O.fc(flat, 10, 256, T["W3"], T["B3"])
            best = 0
            for k in range(10):
                if acc[k] > acc[best]: best = k
            lg = [O.requant(v, M3, SH) if hasattr(O, "requant") else
                  max(-128, min(127, ((max(v,0)*M3 + (1 << (SH-1))) >> SH)))
                  for v in acc]

            f.write(f"IMG {n} CLASE {best} EXPECT {exp_cls}\n")
            f.write("POOL1IN\n")
            for c in range(8):
                for y in range(8):
                    f.write(" ".join(f"{p1[c][y][x] & 0xFF:02x}" for x in range(8)) + "\n")
            f.write("POOL2\n")
            for c in range(16):
                for y in range(4):
                    f.write(" ".join(f"{p2[c][y][x] & 0xFF:02x}" for x in range(4)) + "\n")
                    for x in range(4):
                        sig_p2 = upd(sig_p2, p2[c][y][x])
            f.write("LOGITS " + " ".join(f"{v & 0xFF:02x}" for v in lg) + "\n")
            for v in lg: sig_lg = upd(sig_lg, v)
            sig_cl = upd(sig_cl, best)
            if best == exp_cls: n_ok += 1

        f.write(f"SIG_POOL2 {sig_p2:08x}\n")
        f.write(f"SIG_LOGITS {sig_lg:08x}\n")
        f.write(f"SIG_CLASE {sig_cl:08x}\n")

    print(f"L3 FULL imgs={len(imgs)} clases_ok={n_ok}/{len(imgs)} "
          f"SIG_POOL2=0x{sig_p2:08X} SIG_LOGITS=0x{sig_lg:08X} SIG_CLASE=0x{sig_cl:08X}")

main()
