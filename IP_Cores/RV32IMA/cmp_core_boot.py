#!/usr/bin/env python3
# Lockstep del CORE contra el ISS en modo boot (imagen real del kernel).
# La traza del core empieza en el stub (0x83F00000, pone a0/a1); se alinea
# en el primer PC=0x80000000, donde el estado coincide con el inicial del ISS.
import sys, os, struct, importlib
import iss_ref
importlib.reload(iss_ref)

RAM_SIZE = 64*1024*1024
STATE_SZ = 48*4
img = open('kernel.img','rb').read()
dtb = open('hercossnux.dtb','rb').read()
dtb_off = RAM_SIZE - len(dtb) - STATE_SZ
if dtb[0x13c:0x140] == bytes.fromhex('03ffc000'):
    dtb = dtb[:0x13c] + struct.pack('>I', dtb_off) + dtb[0x140:]
RAM = {}
def load_blob(blob, base):
    for off in range(0, len(blob), 4):
        w = blob[off:off+4]
        if len(w) < 4: w = w + b'\x00'*(4-len(w))
        RAM[0x80000000 + base + off] = struct.unpack('<I', w)[0]
load_blob(img, 0); load_blob(dtb, dtb_off)

core = []
for line in open('core_trace.log'):
    line = line.strip()
    if not line.startswith('PC='): continue
    p = line.split()
    regs = [int(x,16) for x in p[2][2:].split(',')] if len(p) > 2 else None
    core.append((int(p[0][3:],16), int(p[1][6:],16), regs))

# saltar el stub: alinear en el primer PC=0x80000000
k0 = next((k for k,(pc,_,_) in enumerate(core) if pc == 0x80000000), None)
if k0 is None:
    print(">>> FALLO: la traza del core nunca llega a 0x80000000"); sys.exit(1)
core = core[k0:]
print(f"# core: {len(core)} pasos (stub saltado: {k0})")

ev = None
if os.path.exists("irq_events.log"):
    evs = [l.strip() for l in open("irq_events.log") if l.strip()]
    if evs:
        # eventos por (pc, ocurrencia) requieren el formato de dos campos;
        # el tb_boot emite solo el PC: contar ocurrencias aqui
        seen = {}
        ev = []
        for e in evs:
            pc = int(e.split()[0],16)
            ev.append((pc, seen.get(pc,0)))
            seen[pc] = seen.get(pc,0)+1
mt = None
if os.path.exists("mtime_reads.log"):
    mtl = [l.strip() for l in open("mtime_reads.log") if l.strip()]
    if mtl: mt = [int(x,16) for x in mtl]

steps = len(core) + 8
# x5 = residuo del stub de arranque (li x5,0x80000000; jalr x0,0(x5));
# el ISS arranca con el mismo residuo para el lockstep exacto. (t0 es
# caller-saved: el kernel lo escribe antes de leerlo.)
trace, R, uart, ctx = iss_ref.run([], max_steps=steps,
    init_regs={5:0x80000000, 10:0, 11:0x80000000+dtb_off}, init_ram=RAM,
    irq_events=ev, mtime_reads=mt)
print(f"# ref: {len(trace)} pasos")

diffs = 0
n = min(len(core), len(trace))
for k in range(n):
    pc, ir, regs = core[k]
    rpc, rir, rregs = trace[k]
    if pc != rpc:
        print(f"paso {k}: PC core={pc:08x} ref={rpc:08x}"); diffs += 1; break
    if ir != rir:
        print(f"paso {k} PC={pc:08x}: INSTR core={ir:08x} ref={rir:08x}"); diffs += 1; break
    if regs is not None:
        bad = [r for r in range(1,32) if regs[r] != rregs[r]]
        if bad:
            for r in bad[:4]:
                print(f"paso {k} PC={pc:08x}: x{r} core={regs[r]:08x} ref={rregs[r]:08x}")
            diffs += 1; break
MIN_STEPS = int(os.environ.get("MIN_STEPS", "0"))
if diffs == 0 and n < MIN_STEPS:
    print(f">>> FALLO: solo {n} pasos comparados (esperados >= {MIN_STEPS}); el core aborto temprano")
elif diffs == 0:
    print(f">>> CORE == ISS (kernel real): {n} pasos identicos")
    print(f"# UART ISS: {''.join(chr(c) for c in uart)[:60]!r}")
else:
    print(f">>> {diffs} divergencias")
