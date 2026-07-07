#!/usr/bin/env python3
# =============================================================================
#  mem2coe.py  -  Convierte un .mem (hex, una palabra por linea) a .coe de Vivado
#  Licencia: MIT
#  Uso:  python3 mem2coe.py program.mem program.coe
#  (Solo hace falta si usas el Block Memory Generator con IP; la RAM inferida
#   del SoC se precarga directo con el .mem via INIT_FILE.)
# =============================================================================
import sys

src = sys.argv[1] if len(sys.argv) > 1 else "program.mem"
out = sys.argv[2] if len(sys.argv) > 2 else "program.coe"

words = [l.strip() for l in open(src) if l.strip()]

with open(out, "w") as f:
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    f.write(",\n".join(f"{w.upper()}" for w in words))
    f.write(";\n")

print(f"{len(words)} palabras -> {out}")
