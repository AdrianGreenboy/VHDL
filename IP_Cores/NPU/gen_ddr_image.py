#!/usr/bin/env python3
# HERCOSSNUX NPU - imagen del buffer DDR para el testbench de integracion.
# Escribe un fichero de bytes en hex con el layout congelado:
#   W1 +0x0, B1 +0x100, W2 +0x1000, B2 +0x1800, W3 +0x2000, B3 +0x2C00,
#   imagen +0x10000
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
    oracle_py, wf, gf, out, nimg = (sys.argv[1], sys.argv[2], sys.argv[3],
                                    sys.argv[4], int(sys.argv[5]))
    O = load_oracle(oracle_py)
    T, meta = O.load_weights(wf)

    SIZE = 0x30000
    mem = [0]*SIZE

    def put_bytes(off, vals):
        for i, v in enumerate(vals):
            mem[off+i] = v & 0xFF

    def put_int32(off, vals):
        for i, v in enumerate(vals):
            u = v & 0xFFFFFFFF
            mem[off+4*i+0] = u & 0xFF
            mem[off+4*i+1] = (u >> 8) & 0xFF
            mem[off+4*i+2] = (u >> 16) & 0xFF
            mem[off+4*i+3] = (u >> 24) & 0xFF

    put_bytes(0x0000, T["W1"])
    put_int32(0x0100, T["B1"])
    put_bytes(0x1000, T["W2"])
    put_int32(0x1800, T["B2"])
    put_bytes(0x2000, T["W3"])
    put_int32(0x2C00, T["B3"])

    # imagenes: se escriben todas seguidas a partir de 0x10000, 256 B cada una
    with open(gf) as f:
        lines = [l.rstrip("\n") for l in f]
    imgs = []; i = 0
    while i < len(lines) and len(imgs) < nimg:
        if lines[i].startswith("IMG"):
            t = lines[i].split(); exp = int(t[3]); i += 1
            flat = []
            for r in range(16):
                flat += [int(h, 16) for h in lines[i].split()]; i += 1
            imgs.append((exp, flat)); continue
        i += 1

    with open(out, "w") as f:
        f.write(f"# HERCOSSNUX NPU imagen DDR, {len(imgs)} imagenes\n")
        f.write(f"SIZE {SIZE}\n")
        # volcado disperso: solo las regiones no nulas
        def dump(off, n, etiqueta):
            f.write(f"{etiqueta} {off:08x} {n}\n")
            for k in range(0, n, 32):
                trozo = mem[off+k : off+min(k+32, n)]
                f.write(" ".join(f"{b:02x}" for b in trozo) + "\n")
        dump(0x0000, 72, "BLOQUE")
        dump(0x0100, 32, "BLOQUE")
        dump(0x1000, 1152, "BLOQUE")
        dump(0x1800, 64, "BLOQUE")
        dump(0x2000, 2560, "BLOQUE")
        dump(0x2C00, 40, "BLOQUE")
        for n, (exp, flat) in enumerate(imgs):
            f.write(f"IMAGEN {n} CLASE {exp}\n")
            for k in range(0, 256, 32):
                f.write(" ".join(f"{b:02x}" for b in flat[k:k+32]) + "\n")

    print(f"imagen DDR generada: {len(imgs)} imagenes, {SIZE} bytes de espacio")

main()
