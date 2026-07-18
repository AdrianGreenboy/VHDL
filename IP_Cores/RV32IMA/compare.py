#!/usr/bin/env python3
# Comparador de retiro: enfrenta la traza del core (core_trace.log) contra
# la traza de referencia del ISS/emulador, instruccion por instruccion.
import sys, os

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
    # lockstep guiado: si el arnes dejo una traza de eventos de interrupcion,
    # el ISS dispara en esos mismos puntos (verificando que sean legitimos) y
    # comprueba de forma independiente todo lo demas.
    ev = None
    if os.path.exists("irq_events.log"):
        # cada linea: "<pc_hex> <instrucciones_retiradas>"
        ev = []
        for l in open("irq_events.log"):
            if not l.strip(): continue
            parts = l.split()
            ev.append((int(parts[0], 16), int(parts[1])))
    mt = None
    if os.path.exists("mtime_reads.log"):
        mt = [int(l.strip(), 16) for l in open("mtime_reads.log") if l.strip()]
    trace,RAM,_uart,_ctx=iss.run(words, max_steps=60000, irq_events=ev, mtime_reads=mt)
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
    # El poweroff es un final legitimo: el arnes deja de trazar ahi, pero el
    # ISS continua con el bucle infinito posterior. Solo exigimos que el core
    # haya alcanzado el poweroff; si no, es un aborto temprano de verdad.
    POWEROFF_PC = int(os.environ.get("POWEROFF_PC", "0"), 0)
    llego_poweroff = POWEROFF_PC and any(pc == POWEROFF_PC for pc, _, _ in core)
    if compared < esperados and not llego_poweroff:
        print(f">>> FALLO: el core solo ejecuto {compared} de {esperados} pasos esperados (abortó temprano)")
    else:
        print(f">>> LOCKSTEP OK: {compared} pasos identicos core vs referencia")
else:
    print(f">>> {diffs} divergencias en {compared} pasos comparados")
