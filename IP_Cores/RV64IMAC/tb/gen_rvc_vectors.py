#!/usr/bin/env python3
"""Capa 1: vectores exhaustivos del decompresor RVC desde el ISS."""
import sys
sys.path.insert(0, sys.path[0] + '/..')
from iss64 import expand_c
with open(sys.argv[1], 'w') as f:
    for c in range(1 << 16):
        if c & 3 == 3:
            continue
        r = expand_c(c)
        f.write(f'{c:04x} {1 if r is None else 0} {0 if r is None else r:08x}\n')
