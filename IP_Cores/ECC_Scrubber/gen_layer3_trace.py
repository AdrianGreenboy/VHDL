#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_layer3_trace.py - Genera la traza de accesos dmem para el TB de Layer 3.

Escenario:
  1. carga region limpia (N palabras) en la BRAM interna del modelo
  2. arma inject INMEDIATO de 1 bit en addr A1 (se aplica al escribir INJ_CTRL)
  3. arma inject INMEDIATO de 2 bits en addr A2 (DED)
  4. arma inject ON-READ de 1 bit en addr A3 (se aplica durante el barrido)
  5. corre scrub (CONTROL.scrub_en)
  6. lee ID, STATUS, CE_COUNT, DED_COUNT, FIRST_*, LAST_*

Emite layer3_trace.txt con lineas:
  W <off_hex> <val_hex>            (escritura; sin lectura esperada)
  R <off_hex> <exp_val_hex>        (lectura; exp_val es lo que debe devolver)
  L <hex>                          (carga inicial de BRAM, una palabra 39b)
Header con N y la firma FNV de la concatenacion de todas las lecturas esperadas.
"""
import random
from ecc_oracle import encode, fnv1a_32
from mmio_oracle import (
    EccMmio, ID, STATUS, CONTROL, REGION_BASE, REGION_LEN,
    CE_COUNT, DED_COUNT, FIRST_ADDR, FIRST_SYN, LAST_ADDR, LAST_SYN,
    INJ_ADDR, INJ_MASK_LO, INJ_MASK_HI, INJ_CTRL,
)

random.seed(0x1337)
N = 32
data = [random.getrandbits(32) for _ in range(N)]

m = EccMmio(N)
m.load_clean(data)
init_words = list(m.mem)   # para que el TB cargue la misma BRAM

A1, A2, A3 = 5, 12, 20      # direcciones de inyeccion
trace = []                  # lista de (op, off, val)
reads = []                  # (off, expected) en orden, para la firma


def W(off, val):
    m.write(off, val)
    trace.append(("W", off, val))


def R(off):
    v = m.read(off)
    trace.append(("R", off, v))
    reads.append((off, v))
    return v


# 1. config region
W(REGION_BASE, 0)
W(REGION_LEN, N)

# 2. inject inmediato 1-bit en A1
W(INJ_ADDR, A1)
W(INJ_MASK_LO, 1 << 7)      # bit 7
W(INJ_MASK_HI, 0)
W(INJ_CTRL, 0x1 | 0x2)      # arm + mode=inmediato

# 3. inject inmediato 2-bit en A2 (DED)
W(INJ_ADDR, A2)
W(INJ_MASK_LO, (1 << 3) | (1 << 30))
W(INJ_MASK_HI, 0)
W(INJ_CTRL, 0x1 | 0x2)

# 4. inject on-read 1-bit en A3 (mask toca bit 34 -> usa MASK_HI)
W(INJ_ADDR, A3)
W(INJ_MASK_LO, 0)
W(INJ_MASK_HI, 1 << (34 - 32))   # bit 34
W(INJ_CTRL, 0x1)                  # arm + mode=on-read (bit1=0)

# 5. correr scrub
W(CONTROL, 0x1)

# 6. lecturas de verificacion
R(ID)
R(STATUS)
R(CE_COUNT)
R(DED_COUNT)
R(FIRST_ADDR)
R(FIRST_SYN)
R(LAST_ADDR)
R(LAST_SYN)

# firma: concatenar cada lectura esperada como 4 bytes LE
stream = bytearray()
for off, val in reads:
    stream.extend(val.to_bytes(4, "little"))
sig = fnv1a_32(bytes(stream))

with open("layer3_trace.txt", "w") as f:
    f.write(f"# N={N} reads={len(reads)} SIG={sig:#010x}\n")
    for w in init_words:
        f.write(f"L {w:010X}\n")
    for op, off, val in trace:
        f.write(f"{op} {off:02X} {val:08X}\n")

# BRAM inicial (limpia) que carga el regbank
with open("layer3_init.txt", "w") as f:
    for w in init_words:
        f.write(f"{w:010X}\n")

print(f"N={N}  accesos={len(trace)}  lecturas={len(reads)}")
print(f"CE={m.ce} DED={m.ded} first={m.first} last={m.last}")
print(f"firma FNV lecturas: {sig:#010x}")
