#!/usr/bin/env python3
# =============================================================================
#  difftest_gen.py  -  Generador de programas RV32IM aleatorios + modelo de oro
#  Licencia: MIT
#
#  Uso:  python3 difftest_gen.py <seed> <n_instr> <program.mem> <expected.txt>
#
#  Genera un programa recto (sin saltos hacia atras -> termina siempre) con
#  dependencias aleatorias entre instrucciones, lo simula con un modelo de
#  referencia y escribe:
#    - program.mem  : el programa ensamblado (hex, una palabra por linea)
#    - expected.txt : el estado final de los 32 registros (hex)
#
#  x1 queda reservado como puntero base (=0) para loads/stores; nunca se escribe.
# =============================================================================
import sys, random

MASK = 0xFFFFFFFF
def s32(v): return v & MASK
def sx(v):
    v &= MASK
    return v - (1 << 32) if v & 0x80000000 else v

# ---- codificadores -----------------------------------------------------------
def enc_r(f7, rs2, rs1, f3, rd, op): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def enc_i(imm, rs1, f3, rd, op):     return ((imm&0xFFF)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def enc_s(imm, rs2, rs1, f3, op):
    imm &= 0xFFF
    return (((imm>>5)&0x7F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|op
def enc_u(imm, rd, op): return ((imm&0xFFFFF)<<12)|(rd<<7)|op

# ---- semantica de mul/div (identica a la spec RISC-V) ------------------------
def do_mul(a, b, f3):
    A, B = sx(a), sx(b); ua, ub = a & MASK, b & MASK
    if f3 == 0: return s32(A*B)          # mul
    if f3 == 1: return s32((A*B) >> 32)  # mulh
    if f3 == 2: return s32((A*ub) >> 32) # mulhsu
    return s32((ua*ub) >> 32)            # mulhu

def do_div(a, b, f3):
    A, B = sx(a), sx(b); ua, ub = a & MASK, b & MASK
    if f3 == 4:                                   # div
        if B == 0: return MASK
        if A == -(1<<31) and B == -1: return s32(-(1<<31))
        q = abs(A)//abs(B); q = -q if (A<0) != (B<0) else q
        return s32(q)
    if f3 == 5:                                   # divu
        return MASK if ub == 0 else s32(ua//ub)
    if f3 == 6:                                   # rem
        if B == 0: return s32(A)
        if A == -(1<<31) and B == -1: return 0
        q = abs(A)//abs(B); q = -q if (A<0) != (B<0) else q
        return s32(A - q*B)
    return s32(ua) if ub == 0 else s32(ua % ub)   # remu

# ---- generacion + simulacion (un solo paso, programa recto) ------------------
def gen(seed, n):
    rng = random.Random(seed)
    reg = [0]*32
    mem = {}
    words = []
    pc = 0

    def emit(w, effect=None):
        nonlocal pc
        words.append(w & MASK)
        if effect is not None:
            rd, val = effect
            if rd != 0: reg[rd] = val & MASK
        pc += 4

    # x1 = 0 (puntero base reservado)
    emit(enc_i(0, 0, 0, 1, 0x13), (1, 0))

    rd_pool  = [0] + list(range(2, 32))      # excluye x1
    reg_pool = list(range(0, 32))

    for _ in range(n):
        rd  = rng.choice(rd_pool)
        rs1 = rng.choice(reg_pool)
        rs2 = rng.choice(reg_pool)
        a, b = reg[rs1], reg[rs2]
        cat = rng.choice(["r","i","m","u","ls"])

        if cat == "r":
            name = rng.choice(["add","sub","sll","slt","sltu","xor","srl","sra","or","and"])
            sh = b & 31
            res = {
                "add": s32(a+b), "sub": s32(a-b),
                "sll": s32(a << sh), "srl": (a & MASK) >> sh,
                "sra": s32(sx(a) >> sh),
                "slt": 1 if sx(a) < sx(b) else 0,
                "sltu": 1 if (a & MASK) < (b & MASK) else 0,
                "xor": a ^ b, "or": a | b, "and": a & b,
            }[name]
            f7, f3 = {"add":(0,0),"sub":(0x20,0),"sll":(0,1),"slt":(0,2),"sltu":(0,3),
                      "xor":(0,4),"srl":(0,5),"sra":(0x20,5),"or":(0,6),"and":(0,7)}[name]
            emit(enc_r(f7, rs2, rs1, f3, rd, 0x33), (rd, res))

        elif cat == "i":
            name = rng.choice(["addi","slti","sltiu","xori","ori","andi","slli","srli","srai"])
            if name in ("slli","srli","srai"):
                sh = rng.randint(0, 31)
                res = {"slli": s32(a << sh), "srli": (a & MASK) >> sh,
                       "srai": s32(sx(a) >> sh)}[name]
                f7 = 0x20 if name == "srai" else 0
                f3 = 1 if name == "slli" else 5
                emit(enc_r(f7, sh, rs1, f3, rd, 0x13), (rd, res))
            else:
                imm = rng.randint(-2048, 2047)
                imm32 = s32(imm)
                res = {"addi": s32(a+imm),
                       "slti": 1 if sx(a) < imm else 0,
                       "sltiu": 1 if (a & MASK) < (imm32 & MASK) else 0,
                       "xori": a ^ imm32, "ori": a | imm32, "andi": a & imm32}[name]
                f3 = {"addi":0,"slti":2,"sltiu":3,"xori":4,"ori":6,"andi":7}[name]
                emit(enc_i(imm, rs1, f3, rd, 0x13), (rd, res))

        elif cat == "m":
            f3 = rng.randint(0, 7)
            res = do_mul(a, b, f3) if f3 < 4 else do_div(a, b, f3)
            emit(enc_r(0x01, rs2, rs1, f3, rd, 0x33), (rd, res))

        elif cat == "u":
            imm = rng.randint(0, 0xFFFFF)
            if rng.random() < 0.5:
                emit(enc_u(imm, rd, 0x37), (rd, s32(imm << 12)))          # lui
            else:
                emit(enc_u(imm, rd, 0x17), (rd, s32(pc + (imm << 12))))    # auipc

        else:  # ls : lw/sw con base x1 (=0) y offset alineado en [0,60]
            off = rng.randint(0, 15) * 4
            if rng.random() < 0.5:      # sw x_src, off(x1)
                src = rng.choice(reg_pool)
                mem[off] = reg[src] & MASK
                emit(enc_s(off, src, 1, 2, 0x23))
            else:                        # lw rd, off(x1)
                res = mem.get(off, 0)
                emit(enc_i(off, 1, 2, rd, 0x03), (rd, res))

    # terminador: salto a si mismo (beq x0,x0,0)
    emit(0x00000063)
    return words, reg

if __name__ == "__main__":
    seed    = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    n       = int(sys.argv[2]) if len(sys.argv) > 2 else 48
    mem_out = sys.argv[3] if len(sys.argv) > 3 else "program.mem"
    exp_out = sys.argv[4] if len(sys.argv) > 4 else "expected.txt"

    words, reg = gen(seed, n)
    with open(mem_out, "w") as f:
        for w in words:
            f.write(f"{w:08X}\n")
    with open(exp_out, "w") as f:
        for r in range(32):
            f.write(f"{reg[r]:08X}\n")
    print(f"seed={seed} n={n}: {len(words)} instrucciones -> {mem_out}, {exp_out}")
