#!/usr/bin/env python3
# Comparador de retiro: enfrenta la traza del core (core_trace.log) contra
# la traza de referencia del ISS/emulador, instruccion por instruccion.
import sys

def load_core(path):
    out=[]
    for line in open(path):
        line=line.strip()
        if not line.startswith("PC="): continue
        parts=line.split()
        pc=int(parts[0][3:],16)
        instr=int(parts[1][6:],16)
        regs=[int(x,16) for x in parts[2][2:].split(",")]
        out.append((pc,instr,regs))
    return out

def load_ref_iss(mem_path):
    # usa el ISS como oraculo
    import importlib.util
    spec=importlib.util.spec_from_file_location("iss","iss_ref.py")
    iss=importlib.util.module_from_spec(spec); spec.loader.exec_module(iss)
    words=[int(l.strip(),16) for l in open(mem_path) if l.strip()]
    trace,RAM=iss.run(words)
    return trace

core=load_core("core_trace.log")
ref=load_ref_iss("lockstep.mem")

# alinear por PC de entrada. El core puede empezar en el paso 2 (pierde el
# paso inicial por deteccion de flanco); alineamos por coincidencia de PC.
ref_by_idx={i:(pc,instr,regs) for i,(pc,instr,regs) in enumerate(ref)}

# encontrar el offset: el primer PC del core en la traza ref
first_core_pc=core[0][0]
offset=None
for i,(pc,instr,regs) in enumerate(ref):
    if pc==first_core_pc:
        offset=i; break
if offset is None:
    print(f"ERROR: primer PC del core {first_core_pc:08x} no esta en la referencia")
    sys.exit(1)

print(f"# core: {len(core)} pasos, ref: {len(ref)} pasos, offset={offset}")
diffs=0
compared=0
for k,(pc,instr,cregs) in enumerate(core):
    ri=offset+k
    if ri>=len(ref):
        print(f"paso {k}: core continua mas alla de la referencia (PC={pc:08x})")
        diffs+=1; break
    rpc,rinstr,rregs=ref[ri]
    compared+=1
    if pc!=rpc:
        print(f"paso {k}: PC DIVERGE core={pc:08x} ref={rpc:08x}")
        diffs+=1; break  # desincronizado, no seguir
    if instr!=rinstr:
        print(f"paso {k} PC={pc:08x}: INSTR core={instr:08x} ref={rinstr:08x}")
        diffs+=1
    for i in range(1,32):
        if cregs[i]!=rregs[i]:
            print(f"paso {k} PC={pc:08x}: x{i} core={cregs[i]:08x} ref={rregs[i]:08x}")
            diffs+=1
if diffs==0:
    # exigir que el core haya ejecutado hasta el final (no abortar temprano).
    # el core pierde el paso inicial (offset), asi que espera len(ref)-offset pasos.
    esperados = len(ref) - offset
    if compared < esperados:
        print(f">>> FALLO: el core solo ejecuto {compared} de {esperados} pasos esperados (abortó temprano)")
    else:
        print(f">>> LOCKSTEP OK: {compared} pasos identicos core vs referencia")
else:
    print(f">>> {diffs} divergencias en {compared} pasos comparados")
