#!/usr/bin/env python3
"""run_bench.py - runs bench128 (RV128 mode) and bench64 (RV64 mode) on the RTL, checks
each run in lockstep against its ISS (iss128 / iss64) and prints the cycles per kernel.
  run_bench.py [--tb cpu|soc ...] [--maxlat N]
Cycles come from rdcycle in the program (real RTL cycles: caches, AXI latency, iterative
M unit); the ISS only proves both programs ran right."""
import argparse, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, ROOT)
import compare128      # noqa: E402
import compare64       # noqa: E402

KERNELS = ['add4096', 'memcpy 64K', 'search 128b', 'atomic 128b', 'mul128 LCG']

def cycles(out):
    return {int(m.group(1)): int(m.group(2), 16) for m in re.finditer(r'K(\d) ([0-9a-f]{16})', out)}

ap = argparse.ArgumentParser()
ap.add_argument('--tb', nargs='+', default=['cpu', 'soc'])
ap.add_argument('--maxlat', type=int, default=1)
a = ap.parse_args()
p128 = os.path.join(HERE, 'out', 'bench128')
p64 = os.path.join(HERE, 'out', 'bench64')
ok = True
for tb in a.tb:
    o128, tr, _ = compare128.run_rtl(p128, a.maxlat, 1, f'bench128_{tb}', 4, 20000000, tb)
    n128, e128 = compare128.lockstep(p128, tr, tb == 'soc')
    o64, tr, _ = compare64.run_rtl(p64, a.maxlat, 1, f'bench64_{tb}', 4, 20000000, tb)
    n64, e64 = compare64.c64.lockstep(p64, tr, tb == 'soc')
    v128 = 'PASS' if 'TOHOST PASS' in o128 and not e128 else 'FAIL'
    v64 = 'PASS' if 'TOHOST PASS' in o64 and not e64 else 'FAIL'
    ok &= v128 == v64 == 'PASS'
    print(f'\n== tb_{tb} maxlat={a.maxlat}: RV128 {v128} ({n128} retiros)  RV64 {v64} ({n64} retiros)')
    for e in (e128, e64):
        if e:
            print('  ', e)
    c128, c64_ = cycles(o128), cycles(o64)
    print(f'  {"kernel":<14}{"RV64 ciclos":>14}{"RV128 ciclos":>14}{"RV64/RV128":>12}')
    for k, name in enumerate(KERNELS, 1):
        x, y = c64_.get(k), c128.get(k)
        r = f'{x / y:.2f}x' if x and y else '-'
        print(f'  {name:<14}{x if x else "-":>14}{y if y else "-":>14}{r:>12}')
sys.exit(0 if ok else 1)
