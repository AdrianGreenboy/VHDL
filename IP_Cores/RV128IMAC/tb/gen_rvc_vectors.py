#!/usr/bin/env python3
"""Capa 1: vectores exhaustivos del decompresor RVC (49152 casos).
  gen_rvc_vectors.py <salida>           RV128C, oraculo iss128.expand_c
  gen_rvc_vectors.py <salida> --rv64    RV64C, oraculo iss64.expand_c (../RV64IMAC)"""
import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'RV64IMAC'))
if '--rv64' in sys.argv:
    from iss64 import expand_c
else:
    from iss128 import expand_c
with open(sys.argv[1], 'w') as f:
    for c in range(1 << 16):
        if c & 3 == 3:
            continue
        r = expand_c(c)
        f.write(f'{c:04x} {1 if r is None else 0} {0 if r is None else r:08x}\n')
