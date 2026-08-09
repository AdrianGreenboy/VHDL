#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Genera vectores de Layer 1 (unidad encode/decode SECDED) para el TB de GHDL.

Formato de linea (ASCII, campos hex separados por espacio), un caso por linea:
  <op> <data32> <inword39> <injmask39> <exp_data32> <exp_syndrome> <exp_cor> <exp_de>

  op: E = probar encode(data32) -> exp_inword (en exp_data lo ignoramos)
      D = probar decode(inword ^ injmask) -> exp_data/syndrome/cor/de

Para op E:  campo exp_data32 lleva la palabra ECC esperada (39b).
Para op D:  data32 lleva el dato original; inword la palabra limpia; injmask el XOR.

Se emite tambien la firma FNV acumulada de todas las salidas esperadas, que el
TB debe reproducir bit-identica.
"""
import random
from ecc_oracle import encode, decode, inject, fnv1a_32

random.seed(0x1EED)
lines = []
sig_stream = bytearray()


def emit(op, data, inword, mask, ed, es, ec, edbl):
    lines.append(f"{op} {data:08X} {inword:010X} {mask:010X} "
                 f"{ed:08X} {es:02X} {ec:01X} {edbl:01X}")
    # stream para la firma: 8B dato-esperado + 1B syndrome + 1B flags
    sig_stream.extend(ed.to_bytes(8, "little"))
    sig_stream.append(es & 0xFF)
    sig_stream.append(((ec & 1) | ((edbl & 1) << 1)))


# --- bloque encode: 64 datos representativos ---
enc_data = [0x00000000, 0xFFFFFFFF, 0xAAAAAAAA, 0x55555555,
            0x00000001, 0x80000000, 0xDEADBEEF, 0xCAFEBABE]
enc_data += [random.getrandbits(32) for _ in range(56)]
for d in enc_data:
    w = encode(d)
    emit("E", d, 0, 0, w, 0, 0, 0)

# --- bloque decode limpio ---
for _ in range(64):
    d = random.getrandbits(32)
    w = encode(d)
    dd, syn, cor, de = decode(w)
    emit("D", d, w, 0, dd, syn, cor, de)

# --- bloque decode con 1-bit en cada posicion (muestreo) ---
for _ in range(32):
    d = random.getrandbits(32)
    w = encode(d)
    for bit in range(39):
        mask = 1 << bit
        dd, syn, cor, de = decode(inject(w, mask))
        emit("D", d, w, mask, dd, syn, cor, de)

# --- bloque decode con 2-bit (deteccion) ---
for _ in range(128):
    d = random.getrandbits(32)
    w = encode(d)
    a = random.randrange(39); b = random.randrange(39)
    while b == a:
        b = random.randrange(39)
    mask = (1 << a) | (1 << b)
    dd, syn, cor, de = decode(inject(w, mask))
    emit("D", d, w, mask, dd, syn, cor, de)

sig = fnv1a_32(bytes(sig_stream))

with open("layer1_vectors.txt", "w") as f:
    f.write(f"# SECDED(39,32) Layer1 vectors  count={len(lines)}  fnv={sig:#010x}\n")
    f.write("# op data32 inword39 injmask39 exp_data32 exp_syn exp_cor exp_de\n")
    for ln in lines:
        f.write(ln + "\n")

print(f"vectores generados : {len(lines)}")
print(f"firma FNV esperada : {sig:#010x}")
