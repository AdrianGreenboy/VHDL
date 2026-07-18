#!/usr/bin/env python3
# Parsea la traza -s de mini-rv32ima a registros canonicos.
# Formato por linea:
#  PC: 80000000 [0x00000000] Z:00000000 ra:... sp:... ... t6:...
# El estado impreso es el de ENTRADA a cada instruccion (antes de ejecutar).
# Mapeo ABI -> indice numerico x0..x31:
import sys, re
ABI = ["Z","ra","sp","gp","tp","t0","t1","t2","s0","s1","a0","a1","a2","a3",
       "a4","a5","a6","a7","s2","s3","s4","s5","s6","s7","s8","s9","s10","s11",
       "t3","t4","t5","t6"]  # indices 0..31 en orden
assert len(ABI) == 32

def parse_line(line):
    m = re.match(r"PC:\s*([0-9A-Fa-f]+)\s*\[0x([0-9A-Fa-f]+)\]\s*(.*)", line)
    if not m: return None
    pc = int(m.group(1), 16)
    instr = int(m.group(2), 16)
    regs = [0]*32
    for i, name in enumerate(ABI):
        rm = re.search(rf"\b{name}:([0-9A-Fa-f]{{8}})", m.group(3))
        if rm: regs[i] = int(rm.group(1), 16)
    return (pc, instr, regs)

def parse_file(path):
    out = []
    for line in open(path):
        line = line.strip()
        if line.startswith("PC:"):
            r = parse_line(line)
            if r: out.append(r)
    return out

if __name__ == "__main__":
    trace = parse_file(sys.argv[1])
    print(f"# {len(trace)} pasos parseados de {sys.argv[1]}")
    for pc, instr, regs in trace[:5]:
        print(f"PC={pc:08x} INSTR={instr:08x} x1={regs[1]:08x} x2={regs[2]:08x} x11={regs[11]:08x}")
