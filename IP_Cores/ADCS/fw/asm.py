#!/usr/bin/env python3
# =============================================================================
#  asm.py  -  Mini-ensamblador RV32IM (subconjunto) -> program.mem
#  Licencia: MIT
#
#  Uso:  python3 asm.py program.s program.mem
#  Si no se pasan argumentos, ensambla el programa de ejemplo embebido.
#
#  Soporta: addi/add/sub/and/or/xor/sll/srl/sra/slt/sltu,
#           mul/mulh/mulhsu/mulhu/div/divu/rem/remu,
#           lw/sw, beq/bne/blt/bge/bltu/bgeu, jal, jalr, lui, auipc, y etiquetas.
# =============================================================================
import sys, re

REG = {f"x{i}": i for i in range(32)}

def reg(t): return REG[t]

def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25)|(rs2 << 20)|(rs1 << 15)|(f3 << 12)|(rd << 7)|op

def enc_i(imm, rs1, f3, rd, op):
    return ((imm & 0xFFF) << 20)|(rs1 << 15)|(f3 << 12)|(rd << 7)|op

def enc_s(imm, rs2, rs1, f3, op):
    imm &= 0xFFF
    return (((imm >> 5) & 0x7F) << 25)|(rs2 << 20)|(rs1 << 15)|(f3 << 12)|((imm & 0x1F) << 7)|op

def enc_b(imm, rs2, rs1, f3, op):
    imm &= 0x1FFF
    b12=(imm>>12)&1; b11=(imm>>11)&1; b10_5=(imm>>5)&0x3F; b4_1=(imm>>1)&0xF
    return (b12<<31)|(b10_5<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(b4_1<<8)|(b11<<7)|op

def enc_u(imm, rd, op):
    return ((imm & 0xFFFFF) << 12)|(rd << 7)|op

def enc_j(imm, rd, op):
    imm &= 0x1FFFFF
    b20=(imm>>20)&1; b19_12=(imm>>12)&0xFF; b11=(imm>>11)&1; b10_1=(imm>>1)&0x3FF
    return (b20<<31)|(b10_1<<21)|(b11<<20)|(b19_12<<12)|(rd<<7)|op

RTYPE = {  # name -> (funct7, funct3)
    "add":(0x00,0),"sub":(0x20,0),"sll":(0x00,1),"slt":(0x00,2),"sltu":(0x00,3),
    "xor":(0x00,4),"srl":(0x00,5),"sra":(0x20,5),"or":(0x00,6),"and":(0x00,7),
    "mul":(0x01,0),"mulh":(0x01,1),"mulhsu":(0x01,2),"mulhu":(0x01,3),
    "div":(0x01,4),"divu":(0x01,5),"rem":(0x01,6),"remu":(0x01,7),
}
ITYPE = {"addi":0,"slti":2,"sltiu":3,"xori":4,"ori":6,"andi":7,"slli":1,"srli":5,"srai":5}
BTYPE = {"beq":0,"bne":1,"blt":4,"bge":5,"bltu":6,"bgeu":7}
CSRR  = {"csrrw":1,"csrrs":2,"csrrc":3,"csrrwi":5,"csrrsi":6,"csrrci":7}
CSR_NAMES = {"mstatus":0x300,"mie":0x304,"mtvec":0x305,"mscratch":0x340,
             "mepc":0x341,"mcause":0x342,"mtval":0x343,"mip":0x344}

def csr_num(t): return CSR_NAMES[t] if t in CSR_NAMES else int(t, 0)

def clean(line):
    line = line.split("#")[0].strip()
    return line

def parse_mem_operand(s):  # "8(x11)" -> (8, 11)
    m = re.match(r"(-?\d+)\(x(\d+)\)", s.strip())
    return int(m.group(1)), int(m.group(2))

def assemble(src):
    lines = [clean(l) for l in src.splitlines()]
    # primera pasada: etiquetas
    labels, pc, prog = {}, 0, []
    for l in lines:
        if not l: continue
        if l.endswith(":"):
            labels[l[:-1]] = pc; continue
        m = re.match(r"(\w+):", l)
        if m and " " not in l.split(":")[0]:
            labels[m.group(1)] = pc
            l = l[m.end():].strip()
            if not l: continue
        prog.append((pc, l))
        pc += 8 if l.split()[0] == "li" else 4
    # segunda pasada: codificar
    words = []
    for pc, l in prog:
        parts = re.split(r"[ \t,]+", l)
        op = parts[0]
        a = parts[1:]
        if op in RTYPE:
            f7, f3 = RTYPE[op]
            words.append(enc_r(f7, reg(a[2]), reg(a[1]), f3, reg(a[0]), 0x33))
        elif op in ITYPE:
            f3 = ITYPE[op]
            if op in ("slli","srli","srai"):
                f7 = 0x20 if op=="srai" else 0x00
                words.append(enc_r(f7, int(a[2]) & 0x1F, reg(a[1]), f3, reg(a[0]), 0x13))
            else:
                immv = labels[a[2]] if a[2] in labels else int(a[2], 0)
                words.append(enc_i(immv, reg(a[1]), f3, reg(a[0]), 0x13))
        elif op == "lw":
            imm, rs1 = parse_mem_operand(a[1])
            words.append(enc_i(imm, rs1, 2, reg(a[0]), 0x03))
        elif op == "sw":
            imm, rs1 = parse_mem_operand(a[1])
            words.append(enc_s(imm, reg(a[0]), rs1, 2, 0x23))
        elif op in BTYPE:
            f3 = BTYPE[op]
            target = labels[a[2]] if a[2] in labels else int(a[2])
            words.append(enc_b(target - pc, reg(a[1]), reg(a[0]), f3, 0x63))
        elif op == "jal":
            target = labels[a[1]] if a[1] in labels else int(a[1])
            words.append(enc_j(target - pc, reg(a[0]), 0x6F))
        elif op == "jalr":
            imm, rs1 = parse_mem_operand(a[1])
            words.append(enc_i(imm, rs1, 0, reg(a[0]), 0x67))
        elif op == "lui":
            words.append(enc_u(int(a[1], 0), reg(a[0]), 0x37))
        elif op == "li":                         # pseudo: carga constante de 32 bits
            imm = (labels[a[1]] if a[1] in labels else int(a[1], 0)) & 0xFFFFFFFF
            lo = imm & 0xFFF
            hi = (imm >> 12) & 0xFFFFF
            if lo & 0x800:                       # el addi extiende el signo del lo
                hi = (hi + 1) & 0xFFFFF
                lo_s = lo - 0x1000
            else:
                lo_s = lo
            rd = reg(a[0])
            words.append(enc_u(hi, rd, 0x37))            # lui  rd, hi
            words.append(enc_i(lo_s, rd, 0, rd, 0x13))   # addi rd, rd, lo
        elif op == "auipc":
            words.append(enc_u(int(a[1], 0), reg(a[0]), 0x17))
        elif op in CSRR:
            f3 = CSRR[op]; rd = reg(a[0]); csr = csr_num(a[1])
            src = (int(a[2], 0) & 0x1F) if op.endswith("i") else reg(a[2])
            words.append((csr << 20)|(src << 15)|(f3 << 12)|(rd << 7)|0x73)
        elif op == "csrr":                       # pseudo: csrr rd, csr
            words.append((csr_num(a[1]) << 20)|(2 << 12)|(reg(a[0]) << 7)|0x73)
        elif op == "csrw":                       # pseudo: csrw csr, rs1
            words.append((csr_num(a[0]) << 20)|(reg(a[1]) << 15)|(1 << 12)|0x73)
        elif op == "ecall":  words.append(0x00000073)
        elif op == "ebreak": words.append(0x00100073)
        elif op == "mret":   words.append(0x30200073)
        else:
            raise ValueError(f"instruccion no soportada: {op}")
    return words

PROGRAM = """
        addi x1,  x0, 6         # x1 = 6
        addi x2,  x0, 7         # x2 = 7
        mul  x3,  x1, x2        # x3 = 42
        addi x4,  x0, 100       # x4 = 100
        divu x5,  x4, x1        # x5 = 100/6 = 16
        rem  x6,  x4, x1        # x6 = 100%6 = 4
        sub  x7,  x2, x1        # x7 = 1
        addi x10, x0, 0         # acc = 0
        addi x11, x0, 1         # i = 1
        addi x12, x0, 6         # limit = 6
loop:   add  x10, x10, x11      # acc += i
        addi x11, x11, 1        # i++
        blt  x11, x12, loop     # while i < 6  -> acc = 1+2+3+4+5 = 15
        addi x13, x0, 0         # base = 0
        sw   x3,  0(x13)        # mem[0] = 42
        lw   x14, 0(x13)        # x14 = 42
        addi x15, x14, 1        # x15 = 43   (load-use hazard: usa x14 recien cargado)
        mul  x16, x14, x2       # x16 = 42*7 = 294
        addi x17, x16, 0        # x17 = 294  (usa el resultado de mul de inmediato)
done:   beq  x0,  x0, done      # loop infinito
"""

if __name__ == "__main__":
    if len(sys.argv) >= 3:
        src = open(sys.argv[1]).read(); out = sys.argv[2]
    else:
        src = PROGRAM; out = "program.mem"
    words = assemble(src)
    with open(out, "w") as f:
        for w in words:
            f.write(f"{w & 0xFFFFFFFF:08X}\n")
    print(f"Escritas {len(words)} instrucciones en {out}")
    for i, w in enumerate(words):
        print(f"  [{i*4:3d}] 0x{w & 0xFFFFFFFF:08X}")
