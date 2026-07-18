#!/usr/bin/env python3
# Compara el ISS contra la traza single-step de mini-rv32ima (referencia).
import sys, struct, re, importlib
import iss_ref
importlib.reload(iss_ref)

RAM_SIZE = 64*1024*1024
STATE_SZ = 48*4
img = open('kernel.img','rb').read()
dtb = open('hercossnux.dtb','rb').read()
dtb_off = RAM_SIZE - len(dtb) - STATE_SZ
RAM = {}
def load_blob(blob, base):
    for off in range(0, len(blob), 4):
        w = blob[off:off+4]
        if len(w) < 4: w = w + b'\x00'*(4-len(w))
        RAM[0x80000000 + base + off] = struct.unpack('<I', w)[0]
# fixup de mini-rv32ima: el placeholder 0x00c0ff03 en el DTB (tamano de
# RAM) se reemplaza por el limite real de RAM utilizable (= dtb_off), en
# big-endian como exige el formato DTB.
import struct as _s
if dtb[0x13c:0x140] == bytes.fromhex('03ffc000'):
    dtb = dtb[:0x13c] + _s.pack('>I', dtb_off) + dtb[0x140:]
load_blob(img, 0); load_blob(dtb, dtb_off)

# traza del emulador: generador en streaming (archivos de GB)
pat = re.compile(r'PC: ([0-9a-f]{8}) \[0x([0-9a-f]{8})\] (.*)')
def emu_stream():
    for line in open('emu_trace.txt', errors='replace'):
        m = pat.search(line)
        if not m: continue
        vals = [int(v,16) for v in re.findall(r':([0-9a-f]{8})', m.group(3))]
        yield (int(m.group(1),16), int(m.group(2),16), vals)

N = int(sys.argv[1]) if len(sys.argv)>1 else 100000
trace, R, uart, ctx = iss_ref.run([], max_steps=N,
    init_regs={10:0, 11:0x80000000+dtb_off}, init_ram=RAM)
print(f"# traza ISS: {len(trace)} pasos")


diffs = 0
skipped = 0
k = 0
gen = emu_stream()
pend = None   # linea del emulador pendiente de consumir
while k < len(trace):
    if pend is None:
        try:
            pend = next(gen)
        except StopIteration:
            break
    epc, eir, eregs = pend
    ipc, iir, iregs = trace[k]
    if (epc != ipc) or any(eregs[r] != iregs[r] for r in range(32)):
        # lineas duplicadas del emulador (pasos no ejecutados): saltarlas
        matched = False
        for _ in range(3):
            try:
                pend = next(gen)
            except StopIteration:
                pend = None; break
            skipped += 1
            e2 = pend
            if e2[0] == ipc and all(e2[2][r] == iregs[r] for r in range(32)):
                matched = True
                break
        if matched:
            epc, eir, eregs = pend
        else:
            print(f"paso {k}: PC emu={epc:08x} iss={ipc:08x} (ir emu={eir:08x})")
            for r in range(32):
                if eregs[r] != iregs[r]:
                    print(f"paso {k} PC={epc:08x}: x{r} emu={eregs[r]:08x} iss={iregs[r]:08x}")
                    if r > 6: break
            diffs += 1
            break
    pend = None
    k += 1
if diffs == 0:
    print(f">>> ISS == EMULADOR: {k} pasos identicos (desplazamientos tolerados: {skipped})")
    print(f"UART ISS: {''.join(chr(c) for c in uart)[:80]!r}")
