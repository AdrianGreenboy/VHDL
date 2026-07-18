#!/usr/bin/env python3
# Genera boot_ram.hex (formato disperso: "indice_palabra valorhex" por linea)
# con la imagen del kernel en 0x80000000, el DTB (con fixup) al final de la
# RAM y el stub de arranque en 0x83F00000.
import struct
RAM_SIZE = 64*1024*1024
STATE_SZ = 48*4
img = open('kernel.img','rb').read()
dtb = open('hercossnux.dtb','rb').read()
dtb_off = RAM_SIZE - len(dtb) - STATE_SZ
if dtb[0x13c:0x140] == bytes.fromhex('03ffc000'):
    dtb = dtb[:0x13c] + struct.pack('>I', dtb_off) + dtb[0x140:]
stub = [int(l.strip(),16) for l in open('stub.mem') if l.strip()]
STUB_OFF = 0x03F00000
out = []
def emit(blob, base):
    for off in range(0, len(blob), 4):
        w = blob[off:off+4]
        if len(w) < 4: w = w + b'\x00'*(4-len(w))
        v = struct.unpack('<I', w)[0]
        if v: out.append((base//4 + off//4, v))
emit(img, 0)
emit(dtb, dtb_off)
for i, w in enumerate(stub):
    out.append((STUB_OFF//4 + i, w))
with open('boot_ram.hex','w') as f:
    for idx, v in out:
        f.write(f"{idx} {v:08X}\n")
print(f"boot_ram.hex: {len(out)} palabras pobladas; dtb en 0x{0x80000000+dtb_off:08x}; stub en 0x{0x80000000+STUB_OFF:08x}")
