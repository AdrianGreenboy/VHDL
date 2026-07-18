#!/usr/bin/env python3
# Convierte un .mem (una palabra hex de 32 bits por linea, MSB primero en texto)
# a un binario plano little-endian, como lo carga mini-rv32ima en 0x80000000.
import sys
if len(sys.argv) < 3:
    print("uso: mem2bin.py entrada.mem salida.bin"); sys.exit(1)
with open(sys.argv[1]) as f:
    words = [int(l.strip(), 16) for l in f if l.strip()]
with open(sys.argv[2], "wb") as f:
    for w in words:
        f.write((w & 0xFFFFFFFF).to_bytes(4, "little"))
print(f"Escritas {len(words)} palabras ({len(words)*4} bytes) en {sys.argv[2]}")
