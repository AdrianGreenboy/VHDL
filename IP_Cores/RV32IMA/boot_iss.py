#!/usr/bin/env python3
# Corre el ISS sobre la imagen real del kernel + DTB, replicando el estado
# inicial de mini-rv32ima: pc=0x80000000, a0=hartid=0, a1=pa del DTB.
import sys, struct, importlib
import iss_ref
importlib.reload(iss_ref)

RAM_MB   = 64
RAM_SIZE = RAM_MB * 1024 * 1024
STATE_SZ = 48 * 4          # sizeof(struct MiniRV32IMAState) en mini-rv32ima.h

img = open('kernel.img','rb').read()
dtb = open('hercossnux.dtb','rb').read()
dtb_off = RAM_SIZE - len(dtb) - STATE_SZ

mem = bytearray(b'\x00') * 0  # no usar bytearray gigante; poblar dict de palabras
RAM = {}
def load_blob(blob, base):
    n = len(blob)
    for off in range(0, n, 4):
        w = blob[off:off+4]
        if len(w) < 4: w = w + b'\x00'*(4-len(w))
        RAM[0x80000000 + base + off] = struct.unpack('<I', w)[0]
if dtb[0x13c:0x140] == bytes.fromhex('03ffc000'):
    dtb = dtb[:0x13c] + struct.pack('>I', dtb_off) + dtb[0x140:]
load_blob(img, 0)
load_blob(dtb, dtb_off)
print(f"# imagen {len(img)} bytes, dtb {len(dtb)} bytes en 0x{0x80000000+dtb_off:08x}")

steps = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
trace, R, uart, ctx = iss_ref.run([], max_steps=steps,
    init_regs={10: 0, 11: 0x80000000 + dtb_off}, init_ram=RAM)
out = ''.join(chr(c) for c in uart)
print(f"# {len(trace)} pasos; UART ({len(uart)} bytes):")
print(out)
