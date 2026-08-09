#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_layer2_vectors.py - Genera un escenario de barrido para el TB de Layer 2.

Emite dos archivos:
  layer2_init.txt  - region inicial (corrupta): una palabra de 39b hex por linea
  layer2_exp.txt   - resultado esperado del oraculo:
       linea 1: # N=<n> CE=<ce> DED=<ded> SIG=<fnv>
       linea 2: # FIRST addr syn flags   (flags: bit0=ce bit1=ded)
       linea 3: # LAST  addr syn flags
       lineas siguientes: memoria final, una palabra 39b hex por linea

El TB carga layer2_init en la BRAM, corre la FSM, y compara memoria final +
contadores + sticky. PASS si todo coincide (equivalente a firma bit-identica).
"""
import random
from ecc_oracle import encode, decode, inject
from scrub_oracle import scrub_region

random.seed(0x5C2B)
N = 64  # palabras en la region de prueba

# datos base y palabras limpias
base = [random.getrandbits(32) for _ in range(N)]
clean = [encode(d) for d in base]

# corromper: mezcla de 1-bit (corregibles) y 2-bit (detectables) en posiciones fijas
corrupt = list(clean)
rng = random.Random(0xA5)

# 20 palabras con 1-bit
for idx in rng.sample(range(N), 20):
    corrupt[idx] = inject(corrupt[idx], 1 << rng.randrange(39))

# forzar 1-bit en la ULTIMA palabra (indice N-1) si quedo limpia, para que
# truncar el recorrido sea detectable por Layer 2 (mutacion de region)
if corrupt[N-1] == clean[N-1]:
    corrupt[N-1] = inject(corrupt[N-1], 1 << 3)

# 8 palabras (de las restantes) con 2-bit
remaining = [i for i in range(N) if corrupt[i] == clean[i]]
for idx in rng.sample(remaining, 8):
    a = rng.randrange(39); b = rng.randrange(39)
    while b == a:
        b = rng.randrange(39)
    corrupt[idx] = inject(corrupt[idx], (1 << a) | (1 << b))

res = scrub_region(corrupt)

with open("layer2_init.txt", "w") as f:
    for w in corrupt:
        f.write(f"{w:010X}\n")

with open("layer2_exp.txt", "w") as f:
    f.write(f"# N={N} CE={res['ce']} DED={res['ded']} SIG={res['sig']:#010x}\n")
    fa, fs, fc, fd = res["first"]
    la, ls, lc, ld = res["last"]
    f.write(f"# FIRST {fa} {fs} {(fc)|(fd<<1)}\n")
    f.write(f"# LAST {la} {ls} {(lc)|(ld<<1)}\n")
    for w in res["mem"]:
        f.write(f"{w:010X}\n")

print(f"region N={N}")
print(f"CE_COUNT (1-bit corregidos)  : {res['ce']}")
print(f"DED_COUNT (2-bit detectados) : {res['ded']}")
print(f"FIRST addr/syn/flags : {res['first']}")
print(f"LAST  addr/syn/flags : {res['last']}")
print(f"firma FNV barrido    : {res['sig']:#010x}")
