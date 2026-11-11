#!/usr/bin/env python3
"""Capa 1: vectores de mul/div RV128 (esquinas + aleatorios) con el ISS como oraculo.
Formato: f3 w a b r   (w: 0 = 128 bit, 1 = *W, 2 = *D / modo RV64; valores de 128 bit).
Con w = 2, f3 = 1..3 son MULH/MULHSU/MULHU de 64 bit (modo RV64): referencia propia."""
import random
import sys
sys.path.insert(0, sys.path[0] + '/..')
from iss128 import muldiv, MX
M64, M32 = (1 << 64) - 1, (1 << 32) - 1


def sx64(v):
    v &= M64
    return v - (1 << 64) if v >> 63 else v
corner = [0, 1, 2, 3, MX, MX - 1, 1 << 127, (1 << 127) - 1, M64, 1 << 63, (1 << 63) - 1,
          (MX ^ M64) | (1 << 63), M32, 0x80000000, 0x7FFFFFFF, (MX ^ M32) | 0x80000000,
          0x0123456789ABCDEF_FEDCBA9876543210, 0xCCCCCCCCCCCCCCCD, 0xAF]
random.seed(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
WIDTH = {0: 128, 1: 32, 2: 64}
with open(sys.argv[1], 'w') as f:
    n = 0
    for f3 in range(8):
        for w in (0, 1, 2):
            if w == 1 and f3 in (1, 2, 3):
                continue
            pairs = [(a, b) for a in corner for b in corner]
            pairs += [(random.getrandbits(128), random.getrandbits(128)) for _ in range(300)]
            pairs += [(random.getrandbits(random.randint(1, 128)), random.getrandbits(random.randint(1, 128)))
                      for _ in range(300)]
            for a, b in pairs:
                if w == 2 and f3 in (1, 2, 3):
                    sa, sb = sx64(a), sx64(b)
                    ua, ub = a & M64, b & M64
                    hi = {1: sa * sb, 2: sa * ub, 3: ua * ub}[f3] >> 64
                    r = sx64(hi) & MX
                else:
                    r = muldiv(f3, a, b, WIDTH[w]) & MX
                f.write(f'{f3} {w} {a:032x} {b:032x} {r:032x}\n')
                n += 1
    # w = 3: Zbc (f3 1 clmul, 2 clmulr, 3 clmulh) sobre 128 bit
    from iss128 import clmul
    for f3 in (1, 2, 3):
        pairs = [(a, b) for a in corner for b in corner]
        pairs += [(random.getrandbits(128), random.getrandbits(128)) for _ in range(300)]
        for a, b in pairs:
            pr = clmul(a, b)
            r = {1: pr, 2: pr >> 127, 3: pr >> 128}[f3] & MX
            f.write(f'{f3} 3 {a:032x} {b:032x} {r:032x}\n')
            n += 1
print(n, 'vectores')
