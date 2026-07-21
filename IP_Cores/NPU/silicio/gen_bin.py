#!/usr/bin/env python3
# HERCOSSNUX NPU - genera los binarios de pesos e imagenes para el silicio.
# Usa exactamente los mismos datos que la simulacion, para que la firma
# 0x6084FD2A sea comparable.
import sys, struct, importlib.util

def load_oracle(path):
    spec = importlib.util.spec_from_file_location("oracle_npu", path)
    mod = importlib.util.module_from_spec(spec)
    saved = sys.argv; sys.argv = ["oracle_npu"]
    try: spec.loader.exec_module(mod)
    except (SystemExit, IndexError): pass
    finally: sys.argv = saved
    return mod

def main():
    oracle_py, wf, gf, out_w, out_i, nimg = (
        sys.argv[1], sys.argv[2], sys.argv[3],
        sys.argv[4], sys.argv[5], int(sys.argv[6]))
    O = load_oracle(oracle_py)
    T, meta = O.load_weights(wf)

    # pesos: bytes con signo, bias int32 little endian, en el orden que
    # espera npu_run.c
    with open(out_w, "wb") as f:
        f.write(bytes((v & 0xFF) for v in T["W1"]))
        f.write(b"".join(struct.pack("<i", v) for v in T["B1"]))
        f.write(bytes((v & 0xFF) for v in T["W2"]))
        f.write(b"".join(struct.pack("<i", v) for v in T["B2"]))
        f.write(bytes((v & 0xFF) for v in T["W3"]))
        f.write(b"".join(struct.pack("<i", v) for v in T["B3"]))

    # imagenes: 256 bytes cada una, seguidas
    with open(gf) as f:
        lineas = [l.rstrip("\n") for l in f]
    imgs = []; i = 0
    while i < len(lineas) and len(imgs) < nimg:
        if lineas[i].startswith("IMG"):
            exp = int(lineas[i].split()[3]); i += 1
            flat = []
            for r in range(16):
                flat += [int(h, 16) for h in lineas[i].split()]; i += 1
            imgs.append((exp, flat)); continue
        i += 1

    with open(out_i, "wb") as f:
        for exp, flat in imgs:
            f.write(bytes((v & 0xFF) for v in flat))

    # firma de referencia de las clases esperadas
    sig = 0x811C9DC5
    for exp, _ in imgs:
        sig = (sig * 0x01000193 + (exp & 0xFF)) & 0xFFFFFFFF

    print(f"pesos:    {out_w}")
    print(f"imagenes: {out_i}  ({len(imgs)} imagenes)")
    print(f"clases esperadas: {[e for e,_ in imgs]}")
    print(f"SIG_CLASE de referencia: 0x{sig:08X}")

main()
