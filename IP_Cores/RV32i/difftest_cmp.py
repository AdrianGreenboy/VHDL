#!/usr/bin/env python3
# =============================================================================
#  difftest_cmp.py  -  Compara el volcado de registros del core vs el modelo
#  Licencia: MIT
#
#  Uso:  python3 difftest_cmp.py expected.txt actual.txt [seed]
#  Sale con codigo 0 si todos los registros coinciden, 1 si hay diferencias.
# =============================================================================
import sys

def load(fn):
    with open(fn) as f:
        return [int(l.strip(), 16) for l in f if l.strip()]

exp = load(sys.argv[1])
act = load(sys.argv[2])
seed = sys.argv[3] if len(sys.argv) > 3 else "?"

if len(act) < 32:
    print(f"[seed {seed}] ERROR: actual.txt tiene {len(act)} registros (esperaba 32)")
    sys.exit(1)

diffs = []
for r in range(32):
    if exp[r] != act[r]:
        diffs.append((r, exp[r], act[r]))

if diffs:
    print(f"[seed {seed}] MISMATCH en {len(diffs)} registro(s):")
    for r, e, a in diffs:
        print(f"    x{r:<2} esperado=0x{e:08X}  obtenido=0x{a:08X}")
    sys.exit(1)

sys.exit(0)
