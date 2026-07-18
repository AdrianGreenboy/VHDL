#!/usr/bin/env python3
# Corre el ISS por el boot completo del kernel y muestra la consola.
import sys, struct, importlib, time
import iss_ref
importlib.reload(iss_ref)
RAM_SIZE = 64*1024*1024; STATE_SZ = 48*4
img = open('kernel.img','rb').read(); dtb = open('hercossnux.dtb','rb').read()
dtb_off = RAM_SIZE - len(dtb) - STATE_SZ
if dtb[0x13c:0x140] == bytes.fromhex('03ffc000'):
    dtb = dtb[:0x13c] + struct.pack('>I', dtb_off) + dtb[0x140:]
RAM = {}
def lb(blob, base):
    for off in range(0, len(blob), 4):
        w = blob[off:off+4]
        if len(w)<4: w=w+b'\x00'*(4-len(w))
        RAM[0x80000000+base+off]=struct.unpack('<I',w)[0]
lb(img,0); lb(dtb,dtb_off)
N = int(sys.argv[1]) if len(sys.argv)>1 else 50000000
t0=time.time()
trace,R,uart,ctx = iss_ref.run([], max_steps=N,
    init_regs={10:0, 11:0x80000000+dtb_off}, init_ram=RAM,
    trace_from=N+1)   # boot largo: sin traza en memoria
t1=time.time()
out = ''.join(chr(c) for c in uart)
print(f"# {N} pasos maximos en {t1-t0:.0f}s ({len(trace)/(t1-t0):.0f}/s); UART {len(uart)} bytes")
print(out.replace('\x00',''))
