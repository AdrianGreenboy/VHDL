#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tiles_oracle.py - Oraculo del firmware de tiles (Layer 5), Core 20 HERCOSSNUX.

Modela el barrido por tiles que hace ecc_fw_tiles.s sobre una region ECC en DDR:
  - la region son n_words palabras ECC de 64b (LO=32b, HI=7b) en DDR
  - si cfg&1 (scrub ON): por cada palabra, decode -> si CE corrige y cuenta,
    si DED cuenta; reescribe la palabra corregida
  - si cfg&1 == 0 (scrub OFF): pasa la region sin corregir (contadores 0)

Produce: region final (post-scrub), CE, DED, y una firma FNV word-wise sobre
la region final (LO,HI por palabra) para que el PS-side la compare.
"""
from ecc_oracle import encode, decode, fnv1a_32


def scrub_tiles(cfg, words39, tile=128):
    """words39: lista de palabras ECC de 39b en DDR (posiblemente corruptas).
    Devuelve region corregida, CE, DED, firma."""
    mem = list(words39)
    ce = 0
    ded = 0
    n = len(mem)

    if cfg & 1:
        # procesar por tiles (el resultado es identico a procesar de corrido,
        # pero replicamos la estructura para fidelidad con el firmware)
        i = 0
        while i < n:
            end = min(i + tile, n)
            for a in range(i, end):
                data, syn, cor, de = decode(mem[a])
                if cor:
                    mem[a] = encode(data)
                    ce += 1
                elif de:
                    ded += 1
            i = end

    # firma FNV word-wise: LO,HI por palabra
    h = 0x811C9DC5
    for w in mem:
        lo = w & 0xFFFFFFFF
        hi = (w >> 32) & 0x7F
        h ^= lo; h = (h * 0x01000193) & 0xFFFFFFFF
        h ^= hi; h = (h * 0x01000193) & 0xFFFFFFFF

    return {"mem": mem, "ce": ce, "ded": ded, "sig": h}


if __name__ == "__main__":
    import random
    random.seed(0xDDDD)
    N = 300  # mas de 2 tiles (128*2=256)
    data = [random.getrandbits(32) for _ in range(N)]
    clean = [encode(d) for d in data]

    # corromper: 1-bit en algunas, 2-bit en otras
    from ecc_oracle import inject
    corrupt = list(clean)
    rng = random.Random(0x99)
    for idx in rng.sample(range(N), 40):
        corrupt[idx] = inject(corrupt[idx], 1 << rng.randrange(39))
    remaining = [i for i in range(N) if corrupt[i] == clean[i]]
    for idx in rng.sample(remaining, 12):
        a = rng.randrange(39); b = rng.randrange(39)
        while b == a:
            b = rng.randrange(39)
        corrupt[idx] = inject(corrupt[idx], (1 << a) | (1 << b))

    rA = scrub_tiles(1, corrupt)
    rB = scrub_tiles(0, corrupt)
    clean_sig = scrub_tiles(1, clean)["sig"]

    print(f"N={N} (tiles de 128)")
    print(f"RUN A (scrub ON) : CE={rA['ce']} DED={rA['ded']} sig={rA['sig']:#010x}")
    print(f"RUN B (scrub OFF): CE={rB['ce']} DED={rB['ded']} sig={rB['sig']:#010x}")
    print(f"firma region limpia          : {clean_sig:#010x}")
    print(f"A corrige a limpia? {'SI' if rA['sig']==clean_sig else 'NO (quedan DED sin corregir)'}")
    print(f"contraste A vs B: {'DISTINTAS (protegido != no)' if rA['sig']!=rB['sig'] else 'IGUALES'}")
