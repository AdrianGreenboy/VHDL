#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Autotests del oraculo ECC SECDED (39,32). Todos deben pasar antes de tocar RTL."""

import random
from ecc_oracle import (
    encode, decode, inject, N_POS, PARITY_POS, DATA_POS,
    fnv1a_32, word39_to_bytes,
)

random.seed(0xECC20)
FAIL = 0


def check(cond, msg):
    global FAIL
    if not cond:
        print(f"  FAIL: {msg}")
        FAIL += 1


# 1) Round-trip sin error: decode(encode(d)) == d, sin flags
print("[1] round-trip limpio")
for _ in range(2000):
    d = random.getrandbits(32)
    w = encode(d)
    data, syn, cor, de = decode(w)
    check(data == d, f"data {data:#x} != {d:#x}")
    check(syn == 0 and cor == 0 and de == 0, f"flags no-cero d={d:#x} syn={syn} cor={cor} de={de}")

# 2) Correccion de 1 bit exhaustiva: flip en CADA una de las 39 posiciones
print("[2] correccion 1-bit exhaustiva (39 posiciones x muestras)")
for _ in range(500):
    d = random.getrandbits(32)
    w = encode(d)
    for bit in range(39):
        wc = inject(w, 1 << bit)
        data, syn, cor, de = decode(wc)
        check(cor == 1, f"bit {bit}: no marco corrected (d={d:#x})")
        check(de == 0, f"bit {bit}: marco double_error espurio (d={d:#x})")
        check(data == d, f"bit {bit}: dato mal corregido {data:#x} != {d:#x}")

# 3) Deteccion de 2 bits: flip en 2 posiciones distintas -> double_error, sin corregir
print("[3] deteccion 2-bit (pares aleatorios)")
for _ in range(3000):
    d = random.getrandbits(32)
    w = encode(d)
    a = random.randrange(39)
    b = random.randrange(39)
    while b == a:
        b = random.randrange(39)
    wc = inject(w, (1 << a) | (1 << b))
    data, syn, cor, de = decode(wc)
    check(de == 1, f"pareja ({a},{b}): no detecto DED (d={d:#x})")
    check(cor == 0, f"pareja ({a},{b}): corrigio un DED (d={d:#x})")

# 4) syndrome apunta a la posicion correcta en errores de dato/paridad Hamming
print("[4] syndrome == posicion Hamming del bit errado (pos 1..38)")
for _ in range(500):
    d = random.getrandbits(32)
    w = encode(d)
    for bit in range(38):        # bits 0..37 -> posiciones Hamming 1..38
        wc = inject(w, 1 << bit)
        _, syn, cor, de = decode(wc)
        check(syn == bit + 1, f"bit {bit}: syndrome {syn} != {bit+1}")

# 5) Flip en el bit overall (bit 38): syndrome==0, corrected==1, dato intacto
print("[5] flip en overall bit (38)")
for _ in range(500):
    d = random.getrandbits(32)
    w = encode(d)
    wc = inject(w, 1 << 38)
    data, syn, cor, de = decode(wc)
    check(syn == 0, f"overall flip: syndrome {syn} != 0")
    check(cor == 1 and de == 0, f"overall flip: flags cor={cor} de={de}")
    check(data == d, f"overall flip: dato {data:#x} != {d:#x}")

# 6) Firma FNV de una region: contraste protegido vs no-protegido (el gancho del paper)
print("[6] firma FNV: contraste scrubber ON/OFF")
REGION = [random.getrandbits(32) for _ in range(256)]
clean_words = [encode(d) for d in REGION]
# firma de referencia (region intacta)
ref_sig = fnv1a_32(b"".join(word39_to_bytes(w) for w in clean_words))

# inyectar 1 bit en 40 palabras distintas
corrupt = list(clean_words)
rng = random.Random(0x51)
for idx in rng.sample(range(256), 40):
    corrupt[idx] = inject(corrupt[idx], 1 << rng.randrange(39))

# SIN scrubber: firmar los datos decodificados en crudo -> difieren
raw_data_no_scrub = [decode(w)[0] for w in corrupt]
sig_no_scrub = fnv1a_32(b"".join(d.to_bytes(4, "little") for d in raw_data_no_scrub))
# CON scrubber: read-correct-writeback -> palabras re-encodeadas == limpias
scrubbed = [encode(decode(w)[0]) for w in corrupt]
sig_scrub = fnv1a_32(b"".join(word39_to_bytes(w) for w in scrubbed))

ref_data_sig = fnv1a_32(b"".join(d.to_bytes(4, "little") for d in REGION))
check(sig_scrub == ref_sig, f"scrubber ON: firma {sig_scrub:#x} != ref {ref_sig:#x}")
check(sig_no_scrub == ref_data_sig,
      f"correccion 1-bit deberia recuperar el dato: {sig_no_scrub:#x} != {ref_data_sig:#x}")

print()
if FAIL == 0:
    print("=== TODOS LOS TESTS PASARON ===")
    print(f"firma region limpia (39b words) : {ref_sig:#010x}")
    print(f"firma region datos (32b)        : {ref_data_sig:#010x}")
else:
    print(f"=== {FAIL} FALLOS ===")
    raise SystemExit(1)
