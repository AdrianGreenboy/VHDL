#!/usr/bin/env python3
# HERCOSSNUX NPU - genera vectores L2 (feature maps completos de conv1/conv2).
# Reusa el oraculo L4 como unica fuente de verdad: se importa como modulo,
# no se reimplementa la aritmetica.
import sys, os, importlib.util

def load_oracle(path):
    # El oraculo llama main() al final; se neutraliza sys.argv para importarlo.
    spec = importlib.util.spec_from_file_location("oracle_npu", path)
    mod = importlib.util.module_from_spec(spec)
    saved = sys.argv
    sys.argv = ["oracle_npu"]
    try:
        spec.loader.exec_module(mod)
    except SystemExit:
        pass
    except IndexError:
        pass
    finally:
        sys.argv = saved
    return mod

def main():
    oracle_py, wf, gf, outdir, n_img = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
    O = load_oracle(oracle_py)

    T, meta = O.load_tensors(wf) if hasattr(O, "load_tensors") else O.load_weights(wf)
    M1, M2, M3, SH = meta["M1"], meta["M2"], meta["M3"], meta["SHIFT"]

    # Leer imagenes del archivo dorado
    with open(gf) as f:
        lines = [l.rstrip("\n") for l in f]
    imgs = []
    i = 0
    while i < len(lines) and len(imgs) < n_img:
        l = lines[i]
        if l.startswith("IMG"):
            cls = int(l.split()[3]); i += 1
            img = []
            for r in range(16):
                img.append([O.sx8(int(h, 16)) for h in lines[i].split()]); i += 1
            imgs.append((cls, img))
            continue
        i += 1

    fh_in  = open(f"{outdir}/vec_conv1_in.txt", "w")
    fh_out = open(f"{outdir}/vec_conv1_out.txt", "w")
    fh_in.write(f"# conv1 entradas N={len(imgs)} formato: 1 canal 16x16 int8\n")
    fh_out.write(f"# conv1 salidas N={len(imgs)} formato: 8 canales 16x16 int8 post-requantize\n")
    fh_out.write(f"# M1={M1} SHIFT={SH}\n")

    SIGP = 0x01000193
    sig = 0x811C9DC5
    def upd(s, v):
        return (s * SIGP + (v & 0xFF)) & 0xFFFFFFFF

    n_sat = 0
    for n, (cls, img) in enumerate(imgs):
        fh_in.write(f"IMG {n}\n")
        for row in img:
            fh_in.write(" ".join(f"{v & 0xFF:02x}" for v in row) + "\n")

        # conv1 completa via el oraculo (misma funcion, misma aritmetica)
        a = O.conv3x3([img], 1, 16, 16, 8, T["W1"], T["B1"], M1, SH)

        fh_out.write(f"IMG {n}\n")
        for ch in range(8):
            for y in range(16):
                fh_out.write(" ".join(f"{a[ch][y][x] & 0xFF:02x}" for x in range(16)) + "\n")
                for x in range(16):
                    sig = upd(sig, a[ch][y][x])
                    if a[ch][y][x] in (127, -128):
                        n_sat += 1

    fh_out.write(f"SIGNATURE {sig:08x}\n")
    fh_in.close(); fh_out.close()

    # Rango real del acumulador antes del requantize: define si el assert
    # de overflow del MAC puede dispararse con orden de acumulacion distinto.
    acc_min, acc_max = 0, 0
    part_min, part_max = 0, 0
    for cls, img in imgs:
        x = [img]
        for o in range(8):
            for y in range(16):
                for xx in range(16):
                    acc = T["B1"][o]
                    for ky in range(3):
                        for kx in range(3):
                            iy = y + ky - 1; ix = xx + kx - 1
                            if 0 <= iy < 16 and 0 <= ix < 16:
                                acc += x[0][iy][ix] * T["W1"][((o*1 + 0)*3 + ky)*3 + kx]
                                part_min = min(part_min, acc); part_max = max(part_max, acc)
                    acc_min = min(acc_min, acc); acc_max = max(acc_max, acc)

    with open(f"{outdir}/conv1_range.txt", "w") as f:
        f.write(f"ACC_FINAL_MIN {acc_min}\nACC_FINAL_MAX {acc_max}\n")
        f.write(f"ACC_PARTIAL_MIN {part_min}\nACC_PARTIAL_MAX {part_max}\n")

    print(f"L2 VECTORES imgs={len(imgs)} SIG=0x{sig:08X} saturados={n_sat} "
          f"acc_final=[{acc_min},{acc_max}] acc_parcial=[{part_min},{part_max}]")

main()
