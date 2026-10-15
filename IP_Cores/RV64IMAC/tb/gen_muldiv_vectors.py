#!/usr/bin/env python3
"""Capa 1: vectores de mul/div (esquinas + aleatorios) con el ISS como oraculo."""
import random, sys
sys.path.insert(0, sys.path[0] + '/..')
from iss64 import Hart, Bus, M64
h = Hart.__new__(Hart)
corner = [0, 1, 2, 3, M64, M64 - 1, 1 << 63, (1 << 63) - 1, 0xFFFFFFFF, 0x80000000, 0x7FFFFFFF,
          0xFFFFFFFF80000000, 0x00000000FFFFFFFF, 0x123456789ABCDEF0, 0xCCCCCCCD, 0xAF]
random.seed(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
with open(sys.argv[1], 'w') as f:
    n = 0
    for f3 in range(8):
        for w in (0, 1):
            if w and f3 in (1, 2, 3):
                continue
            pairs = [(a, b) for a in corner for b in corner]
            pairs += [(random.getrandbits(64), random.getrandbits(64)) for _ in range(400)]
            pairs += [(random.getrandbits(random.randint(1, 64)), random.getrandbits(random.randint(1, 64))) for _ in range(400)]
            for a, b in pairs:
                r = (h._muldivw(f3, a, b) if w else h._muldiv(f3, a, b)) & M64
                f.write(f'{f3} {w} {a:016x} {b:016x} {r:016x}\n')
                n += 1
print(n, 'vectores')
