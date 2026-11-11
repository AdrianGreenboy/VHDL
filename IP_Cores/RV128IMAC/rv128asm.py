#!/usr/bin/env python3
"""rv128asm.py - minimal two-pass assembler for RV128IMAC (experimental).

No RV128 support exists in GNU as / LLVM, so this assembler is the toolchain
for the core's regression. Encodings follow doc/RV128IMAC_ISA.md.

Compressed instructions are only emitted when written explicitly (c.xxx),
so tests control exactly which encodings are exercised.

Usage: rv128asm.py prog.S -o prog.bin [--hex prog.hex] [--base 0x80000000]
  --hex writes one 128-bit little-endian word per line (32 hex digits).
"""
import argparse
import re
import sys

XLEN = 128
MASK = (1 << XLEN) - 1

ABI = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1",
       "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7",
       "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11",
       "t3", "t4", "t5", "t6"]
REGS = {f"x{i}": i for i in range(32)}
REGS.update({n: i for i, n in enumerate(ABI)})
REGS["fp"] = 8

CSRS = {
    "mvendorid": 0xF11, "marchid": 0xF12, "mimpid": 0xF13, "mhartid": 0xF14,
    "mstatus": 0x300, "misa": 0x301, "mie": 0x304, "mtvec": 0x305,
    "mscratch": 0x340, "mepc": 0x341, "mcause": 0x342, "mtval": 0x343,
    "mip": 0x344, "mcycle": 0xB00, "minstret": 0xB02,
    "cycle": 0xC00, "time": 0xC01, "instret": 0xC02, "mconfigptr": 0xF15,
    "medeleg": 0x302, "mideleg": 0x303, "mcounteren": 0x306, "menvcfg": 0x30A,
    "mcountinhibit": 0x320,
    "sstatus": 0x100, "sie": 0x104, "stvec": 0x105, "scounteren": 0x106, "senvcfg": 0x10A,
    "sscratch": 0x140, "sepc": 0x141, "scause": 0x142, "stval": 0x143, "sip": 0x144,
    "satp": 0x180,
}

OP_LOAD, OP_MISC, OP_IMM, OP_AUIPC, OP_IMM32 = 0x03, 0x0F, 0x13, 0x17, 0x1B
OP_STORE, OP_AMO, OP_OP, OP_LUI, OP_OP32 = 0x23, 0x2F, 0x33, 0x37, 0x3B
OP_IMM64, OP_BRANCH, OP_JALR, OP_JAL, OP_SYSTEM, OP_OP64 = 0x5B, 0x63, 0x67, 0x6F, 0x73, 0x7B


class AsmError(Exception):
    pass


def sext(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def fits_s(v, bits):
    return -(1 << (bits - 1)) <= v < (1 << (bits - 1))


def fits_u(v, bits):
    return 0 <= v < (1 << bits)


# ---------------------------------------------------------------- encoders
def enc_r(op, f3, f7, rd, rs1, rs2):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(op, f3, rd, rs1, imm):
    if not fits_s(imm, 12):
        raise AsmError(f"I-immediate out of range: {imm}")
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(op, f3, rs1, rs2, imm):
    if not fits_s(imm, 12):
        raise AsmError(f"S-immediate out of range: {imm}")
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op


def enc_b(f3, rs1, rs2, off):
    if off & 1 or not fits_s(off, 13):
        raise AsmError(f"branch offset invalid: {off}")
    o = off & 0x1FFF
    return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
        (f3 << 12) | (((o >> 1) & 0xF) << 8) | (((o >> 11) & 1) << 7) | OP_BRANCH


def enc_u(op, rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(rd, off):
    if off & 1 or not fits_s(off, 21):
        raise AsmError(f"jal offset invalid: {off}")
    o = off & 0x1FFFFF
    return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | (((o >> 11) & 1) << 20) | \
        (((o >> 12) & 0xFF) << 12) | (rd << 7) | OP_JAL


def bits(v, hi, lo):
    return (v >> lo) & ((1 << (hi - lo + 1)) - 1)


def creg(r):
    if not 8 <= r <= 15:
        raise AsmError(f"compressed register must be x8..x15, got x{r}")
    return r - 8


# ------------------------------------------------------------- instruction tables
R_OPS = {  # name: (opcode, f3, f7)
    "add": (OP_OP, 0, 0), "sub": (OP_OP, 0, 0x20), "sll": (OP_OP, 1, 0), "slt": (OP_OP, 2, 0),
    "sltu": (OP_OP, 3, 0), "xor": (OP_OP, 4, 0), "srl": (OP_OP, 5, 0), "sra": (OP_OP, 5, 0x20),
    "or": (OP_OP, 6, 0), "and": (OP_OP, 7, 0),
    "mul": (OP_OP, 0, 1), "mulh": (OP_OP, 1, 1), "mulhsu": (OP_OP, 2, 1), "mulhu": (OP_OP, 3, 1),
    "div": (OP_OP, 4, 1), "divu": (OP_OP, 5, 1), "rem": (OP_OP, 6, 1), "remu": (OP_OP, 7, 1),
    "addw": (OP_OP32, 0, 0), "subw": (OP_OP32, 0, 0x20), "sllw": (OP_OP32, 1, 0),
    "srlw": (OP_OP32, 5, 0), "sraw": (OP_OP32, 5, 0x20),
    "mulw": (OP_OP32, 0, 1), "divw": (OP_OP32, 4, 1), "divuw": (OP_OP32, 5, 1),
    "remw": (OP_OP32, 6, 1), "remuw": (OP_OP32, 7, 1),
    "addd": (OP_OP64, 0, 0), "subd": (OP_OP64, 0, 0x20), "slld": (OP_OP64, 1, 0),
    "srld": (OP_OP64, 5, 0), "srad": (OP_OP64, 5, 0x20),
    "muld": (OP_OP64, 0, 1), "divd": (OP_OP64, 4, 1), "divud": (OP_OP64, 5, 1),
    "remd": (OP_OP64, 6, 1), "remud": (OP_OP64, 7, 1),
}
# Zbb + Zbc (RV128: XLEN = 128; las variantes W y D operan sobre 32 y 64 bit)
R_OPS.update({
    "andn": (OP_OP, 7, 0x20), "orn": (OP_OP, 6, 0x20), "xnor": (OP_OP, 4, 0x20),
    "min": (OP_OP, 4, 0x05), "minu": (OP_OP, 5, 0x05), "max": (OP_OP, 6, 0x05), "maxu": (OP_OP, 7, 0x05),
    "clmul": (OP_OP, 1, 0x05), "clmulr": (OP_OP, 2, 0x05), "clmulh": (OP_OP, 3, 0x05),
    "rol": (OP_OP, 1, 0x30), "ror": (OP_OP, 5, 0x30),
    "rolw": (OP_OP32, 1, 0x30), "rorw": (OP_OP32, 5, 0x30),
    "rold": (OP_OP64, 1, 0x30), "rord": (OP_OP64, 5, 0x30),
})
UNARY = {  # name: (opcode, f3, imm12)  rd, rs1
    "clz": (OP_IMM, 1, 0x600), "ctz": (OP_IMM, 1, 0x601), "cpop": (OP_IMM, 1, 0x602),
    "clzw": (OP_IMM32, 1, 0x600), "ctzw": (OP_IMM32, 1, 0x601), "cpopw": (OP_IMM32, 1, 0x602),
    "clzd": (OP_IMM64, 1, 0x600), "ctzd": (OP_IMM64, 1, 0x601), "cpopd": (OP_IMM64, 1, 0x602),
    "sext.b": (OP_IMM, 1, 0x604), "sext.h": (OP_IMM, 1, 0x605),
    "rev8": (OP_IMM, 5, 0x6F8), "orc.b": (OP_IMM, 5, 0x287),
    "zext.h": (OP_OP64, 4, 0x080),
}
I_OPS = {
    "addi": (OP_IMM, 0), "slti": (OP_IMM, 2), "sltiu": (OP_IMM, 3), "xori": (OP_IMM, 4),
    "ori": (OP_IMM, 6), "andi": (OP_IMM, 7), "addiw": (OP_IMM32, 0), "addid": (OP_IMM64, 0),
}
SHIFT_I = {  # name: (opcode, f3, high-bits value, shamt bits)
    "slli": (OP_IMM, 1, 0x00, 7), "srli": (OP_IMM, 5, 0x00, 7), "srai": (OP_IMM, 5, 0x08, 7),
    "slliw": (OP_IMM32, 1, 0x00, 5), "srliw": (OP_IMM32, 5, 0x00, 5), "sraiw": (OP_IMM32, 5, 0x20, 5),
    "sllid": (OP_IMM64, 1, 0x00, 6), "srlid": (OP_IMM64, 5, 0x00, 6), "sraid": (OP_IMM64, 5, 0x10, 6),
    "rori": (OP_IMM, 5, 0x0C, 7), "roriw": (OP_IMM32, 5, 0x30, 5), "rorid": (OP_IMM64, 5, 0x18, 6),
}
LOADS = {"lb": (OP_LOAD, 0), "lh": (OP_LOAD, 1), "lw": (OP_LOAD, 2), "ld": (OP_LOAD, 3),
         "lbu": (OP_LOAD, 4), "lhu": (OP_LOAD, 5), "lwu": (OP_LOAD, 6), "ldu": (OP_LOAD, 7),
         "lq": (OP_MISC, 2)}
STORES = {"sb": 0, "sh": 1, "sw": 2, "sd": 3, "sq": 4}
BRANCHES = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}
AMO_F5 = {"lr": 0x02, "sc": 0x03, "amoswap": 0x01, "amoadd": 0x00, "amoxor": 0x04, "amoand": 0x0C,
          "amoor": 0x08, "amomin": 0x10, "amomax": 0x14, "amominu": 0x18, "amomaxu": 0x1C}
AMO_W = {"w": 2, "d": 3, "q": 4}


class Assembler:
    def __init__(self, base):
        self.base = base
        self.labels = {}
        self.equs = {}

    # ---------------------------------------------------------- expressions
    def value(self, s, pc=None, need=True):
        s = s.strip()
        env = {}
        env.update(self.equs)
        env.update(self.labels)
        if pc is not None:
            env["."] = pc

        def repl(m):
            tok = m.group(0)
            if tok in env:
                return str(env[tok])
            if need:
                raise AsmError(f"undefined symbol '{tok}'")
            return "0"
        expr = re.sub(r"(?<![0-9A-Za-z_.])(?:\.(?![0-9A-Za-z_])|[A-Za-z_][A-Za-z_0-9.]*)", repl, s)
        if not re.fullmatch(r"[0-9a-fA-FxXbBoO_+\-*/()<>|&~^% ]+", expr):
            raise AsmError(f"bad expression '{s}'")
        try:
            return int(eval(expr.replace("/", "//"), {"__builtins__": {}}, {}))
        except Exception as e:
            raise AsmError(f"cannot evaluate '{s}': {e}")

    @staticmethod
    def reg(s):
        s = s.strip()
        if s not in REGS:
            raise AsmError(f"bad register '{s}'")
        return REGS[s]

    def mem(self, s, pc, need):
        m = re.fullmatch(r"\s*(.*)\(\s*([A-Za-z0-9]+)\s*\)\s*", s)
        if not m:
            raise AsmError(f"bad memory operand '{s}'")
        off = self.value(m.group(1), pc, need) if m.group(1).strip() else 0
        return off, self.reg(m.group(2))

    def csr(self, s):
        s = s.strip()
        if s in CSRS:
            return CSRS[s]
        return self.value(s)

    # ---------------------------------------------------------- li expansion
    def li_seq(self, rd, v):
        """Return list of 32-bit words materialising 128-bit constant v."""
        v = sext(v & MASK, XLEN)
        if fits_s(v, 12):
            return [enc_i(OP_IMM, 0, rd, 0, v)]
        if fits_s(v, 32):
            lo = sext(v, 12)
            hi = ((v - lo) >> 12) & 0xFFFFF
            seq = [enc_u(OP_LUI, rd, hi)]
            if lo:
                seq.append(enc_i(OP_IMM32, 0, rd, rd, lo))
            return seq
        lo = sext(v, 12)
        rest = (v - lo) >> 12
        sh = 12
        while rest and not (rest & 1):
            rest >>= 1
            sh += 1
        seq = self.li_seq(rd, rest)
        seq.append(enc_r(OP_IMM, 1, 0, rd, rd, 0) | ((sh & 0x7F) << 20))
        if lo:
            seq.append(enc_i(OP_IMM, 0, rd, rd, lo))
        return seq

    # ---------------------------------------------------------- one instruction
    def assemble_insn(self, mn, ops, pc, need):
        """Return bytes for one instruction (or pseudo)."""
        w32 = lambda *ws: b"".join(w.to_bytes(4, "little") for w in ws)
        w16 = lambda w: (w & 0xFFFF).to_bytes(2, "little")
        R, V = self.reg, (lambda s: self.value(s, pc, need))
        n = len(ops)

        def rel(s):
            return (V(s) - pc) if need else 0

        if mn in R_OPS:
            op, f3, f7 = R_OPS[mn]
            return w32(enc_r(op, f3, f7, R(ops[0]), R(ops[1]), R(ops[2])))
        if mn in UNARY:
            op, f3, i12 = UNARY[mn]
            return w32((i12 << 20) | (R(ops[1]) << 15) | (f3 << 12) | (R(ops[0]) << 7) | op)
        if mn in I_OPS:
            op, f3 = I_OPS[mn]
            return w32(enc_i(op, f3, R(ops[0]), R(ops[1]), V(ops[2])))
        if mn in SHIFT_I:
            op, f3, hib, sb = SHIFT_I[mn]
            sh = V(ops[2])
            if not 0 <= sh < (1 << sb):
                raise AsmError(f"shift amount out of range for {mn}: {sh}")
            return w32((hib << (20 + sb)) | (sh << 20) | (R(ops[1]) << 15) | (f3 << 12) | (R(ops[0]) << 7) | op)
        if mn in LOADS:
            op, f3 = LOADS[mn]
            off, rs1 = self.mem(ops[1], pc, need)
            return w32(enc_i(op, f3, R(ops[0]), rs1, off))
        if mn in STORES:
            off, rs1 = self.mem(ops[1], pc, need)
            return w32(enc_s(OP_STORE, STORES[mn], rs1, R(ops[0]), off))
        if mn in BRANCHES:
            return w32(enc_b(BRANCHES[mn], R(ops[0]), R(ops[1]), rel(ops[2])))
        if mn in ("lui", "auipc"):
            imm = V(ops[1])
            if not (fits_u(imm, 20) or fits_s(imm, 20)):
                raise AsmError(f"{mn} immediate out of range")
            return w32(enc_u(OP_LUI if mn == "lui" else OP_AUIPC, R(ops[0]), imm))
        if mn == "jal":
            if n == 1:
                return w32(enc_j(1, rel(ops[0])))
            return w32(enc_j(R(ops[0]), rel(ops[1])))
        if mn == "jalr":
            if n == 1:
                return w32(enc_i(OP_JALR, 0, 1, R(ops[0]), 0))
            if n == 2 and "(" in ops[1]:
                off, rs1 = self.mem(ops[1], pc, need)
                return w32(enc_i(OP_JALR, 0, R(ops[0]), rs1, off))
            return w32(enc_i(OP_JALR, 0, R(ops[0]), R(ops[1]), V(ops[2]) if n > 2 else 0))
        # ---- atomics: lr.q / sc.d / amoadd.w(.aq)(.rl)
        m = re.fullmatch(r"(lr|sc|amo[a-z]+)\.([wdq])((?:\.aq)?(?:\.rl)?|\.aqrl)", mn)
        if m and m.group(1) in AMO_F5:
            f5, f3 = AMO_F5[m.group(1)], AMO_W[m.group(2)]
            aq = 1 if "aq" in m.group(3) else 0
            rl = 1 if "rl" in m.group(3) else 0
            rd = R(ops[0])
            if m.group(1) == "lr":
                rs2, addr = 0, ops[1]
            else:
                rs2, addr = R(ops[1]), ops[2]
            off, rs1 = self.mem(addr, pc, need)
            if off:
                raise AsmError("AMO address must be (rs1) with zero offset")
            return w32((f5 << 27) | (aq << 26) | (rl << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | OP_AMO)
        # ---- system
        if mn == "ecall":
            return w32(0x00000073)
        if mn == "ebreak":
            return w32(0x00100073)
        if mn == "mret":
            return w32(0x30200073)
        if mn == "sret":
            return w32(0x10200073)
        if mn == "sfence.vma":
            rs1 = R(ops[0]) if n > 0 else 0
            rs2 = R(ops[1]) if n > 1 else 0
            return w32((0x09 << 25) | (rs2 << 20) | (rs1 << 15) | OP_SYSTEM)
        if mn == "wfi":
            return w32(0x10500073)
        if mn == "fence":
            return w32(0x0FF0000F)
        if mn == "fence.i":
            return w32(0x0000100F)
        csr_map = {"csrrw": 1, "csrrs": 2, "csrrc": 3, "csrrwi": 5, "csrrsi": 6, "csrrci": 7}
        if mn in csr_map:
            f3 = csr_map[mn]
            src = V(ops[2]) if f3 >= 5 else R(ops[2])
            return w32((self.csr(ops[1]) << 20) | (src << 15) | (f3 << 12) | (R(ops[0]) << 7) | OP_SYSTEM)
        if mn == "csrr":
            return w32((self.csr(ops[1]) << 20) | (2 << 12) | (R(ops[0]) << 7) | OP_SYSTEM)
        if mn in ("csrw", "csrs", "csrc"):
            f3 = {"csrw": 1, "csrs": 2, "csrc": 3}[mn]
            return w32((self.csr(ops[0]) << 20) | (R(ops[1]) << 15) | (f3 << 12) | OP_SYSTEM)
        if mn in ("csrwi", "csrsi", "csrci"):
            f3 = {"csrwi": 5, "csrsi": 6, "csrci": 7}[mn]
            return w32((self.csr(ops[0]) << 20) | (V(ops[1]) << 15) | (f3 << 12) | OP_SYSTEM)
        # ---- pseudos
        if mn == "nop":
            return w32(enc_i(OP_IMM, 0, 0, 0, 0))
        if mn == "li":
            seq = self.li_seq(R(ops[0]), V(ops[1]))
            return w32(*seq)
        if mn == "la":  # fixed 2-word form so pass sizes match
            off = rel(ops[1])
            lo = sext(off, 12)
            hi = ((off - lo) >> 12) & 0xFFFFF
            rd = R(ops[0])
            return w32(enc_u(OP_AUIPC, rd, hi), enc_i(OP_IMM, 0, rd, rd, lo))
        if mn == "mv":
            return w32(enc_i(OP_IMM, 0, R(ops[0]), R(ops[1]), 0))
        if mn == "not":
            return w32(enc_i(OP_IMM, 4, R(ops[0]), R(ops[1]), -1))
        if mn == "neg":
            return w32(enc_r(OP_OP, 0, 0x20, R(ops[0]), 0, R(ops[1])))
        if mn == "seqz":
            return w32(enc_i(OP_IMM, 3, R(ops[0]), R(ops[1]), 1))
        if mn == "snez":
            return w32(enc_r(OP_OP, 3, 0, R(ops[0]), 0, R(ops[1])))
        if mn == "sext.w":
            return w32(enc_i(OP_IMM32, 0, R(ops[0]), R(ops[1]), 0))
        if mn == "sext.d":
            return w32(enc_i(OP_IMM64, 0, R(ops[0]), R(ops[1]), 0))
        if mn == "j":
            return w32(enc_j(0, rel(ops[0])))
        if mn == "call":
            return w32(enc_j(1, rel(ops[0])))
        if mn == "jr":
            return w32(enc_i(OP_JALR, 0, 0, R(ops[0]), 0))
        if mn == "ret":
            return w32(enc_i(OP_JALR, 0, 0, 1, 0))
        if mn in ("beqz", "bnez", "bltz", "bgez"):
            f3 = {"beqz": 0, "bnez": 1, "bltz": 4, "bgez": 5}[mn]
            return w32(enc_b(f3, R(ops[0]), 0, rel(ops[1])))
        if mn in ("blez", "bgtz"):
            f3 = {"blez": 5, "bgtz": 4}[mn]
            return w32(enc_b(f3, 0, R(ops[0]), rel(ops[1])))
        if mn in ("bgt", "ble", "bgtu", "bleu"):
            f3 = {"bgt": 4, "ble": 5, "bgtu": 6, "bleu": 7}[mn]
            return w32(enc_b(f3, R(ops[1]), R(ops[0]), rel(ops[2])))
        if mn.startswith("c."):
            return w16(self.assemble_c(mn[2:], ops, pc, need))
        raise AsmError(f"unknown mnemonic '{mn}'")

    # ---------------------------------------------------------- RV128C
    def assemble_c(self, mn, ops, pc, need):
        R, V = self.reg, (lambda s: self.value(s, pc, need))

        def rel(s):
            return (V(s) - pc) if need else 0

        def chk(v, ok, what):
            if not ok:
                raise AsmError(f"c.{mn}: {what} out of range ({v})")

        if mn == "nop":
            return 0x0001
        if mn == "ebreak":
            return 0x9002
        if mn == "addi4spn":
            rd, imm = R(ops[0]), V(ops[2])
            if R(ops[1]) != 2:
                raise AsmError("c.addi4spn requires sp")
            chk(imm, imm % 4 == 0 and 0 < imm < 1024, "nzuimm")
            return (0 << 13) | (bits(imm, 5, 4) << 11) | (bits(imm, 9, 6) << 7) | (bits(imm, 2, 2) << 6) | \
                (bits(imm, 3, 3) << 5) | (creg(rd) << 2) | 0
        if mn in ("lw", "ld", "lq", "sw", "sd", "sq"):
            r = creg(R(ops[0]))
            off, base = self.mem(ops[1], pc, need)
            b = creg(base)
            if mn in ("lw", "sw"):
                chk(off, off % 4 == 0 and 0 <= off < 128, "offset")
                imm = (bits(off, 5, 3) << 10) | (bits(off, 2, 2) << 6) | (bits(off, 6, 6) << 5)
                f3 = 2 if mn == "lw" else 6
            elif mn in ("ld", "sd"):
                chk(off, off % 8 == 0 and 0 <= off < 256, "offset")
                imm = (bits(off, 5, 3) << 10) | (bits(off, 7, 6) << 5)
                f3 = 3 if mn == "ld" else 7
            else:
                chk(off, off % 16 == 0 and 0 <= off < 512, "offset")
                imm = (bits(off, 5, 4) << 11) | (bits(off, 8, 8) << 10) | (bits(off, 7, 6) << 5)
                f3 = 1 if mn == "lq" else 5
            return (f3 << 13) | imm | (b << 7) | (r << 2) | 0
        if mn in ("addi", "addiw", "li"):
            rd, imm = R(ops[0]), V(ops[1])
            chk(imm, fits_s(imm, 6), "imm")
            f3 = {"addi": 0, "addiw": 1, "li": 2}[mn]
            return (f3 << 13) | (bits(imm, 5, 5) << 12) | (rd << 7) | (bits(imm, 4, 0) << 2) | 1
        if mn == "addi16sp":
            imm = V(ops[-1])
            chk(imm, imm % 16 == 0 and imm != 0 and fits_s(imm, 10), "nzimm")
            return (3 << 13) | (bits(imm, 9, 9) << 12) | (2 << 7) | (bits(imm, 4, 4) << 6) | \
                (bits(imm, 6, 6) << 5) | (bits(imm, 8, 7) << 3) | (bits(imm, 5, 5) << 2) | 1
        if mn == "lui":  # operand is the 6-bit nzimm[17:12] value (signed)
            rd, imm = R(ops[0]), V(ops[1])
            chk(imm, imm != 0 and fits_s(imm, 6), "nzimm")
            return (3 << 13) | (bits(imm, 5, 5) << 12) | (rd << 7) | (bits(imm, 4, 0) << 2) | 1
        if mn in ("srli", "srai"):
            rd, sh = creg(R(ops[0])), V(ops[1])
            if sh == 64:
                f = 0
            elif 1 <= sh <= 31:
                f = sh
            elif 96 <= sh <= 127:
                f = sh - 64
            else:
                raise AsmError(f"c.{mn}: RV128C shamt must be 1-31, 64 or 96-127")
            sub = 0 if mn == "srli" else 1
            return (4 << 13) | (bits(f, 5, 5) << 12) | (sub << 10) | (rd << 7) | (bits(f, 4, 0) << 2) | 1
        if mn == "andi":
            rd, imm = creg(R(ops[0])), V(ops[1])
            chk(imm, fits_s(imm, 6), "imm")
            return (4 << 13) | (bits(imm, 5, 5) << 12) | (2 << 10) | (rd << 7) | (bits(imm, 4, 0) << 2) | 1
        if mn in ("sub", "xor", "or", "and", "subw", "addw"):
            rd, rs2 = creg(R(ops[0])), creg(R(ops[1]))
            b12 = 1 if mn in ("subw", "addw") else 0
            f2 = {"sub": 0, "xor": 1, "or": 2, "and": 3, "subw": 0, "addw": 1}[mn]
            return (4 << 13) | (b12 << 12) | (3 << 10) | (rd << 7) | (f2 << 5) | (rs2 << 2) | 1
        if mn == "j":
            off = rel(ops[0])
            chk(off, off % 2 == 0 and fits_s(off, 12), "offset")
            o = off
            enc = (bits(o, 11, 11) << 12) | (bits(o, 4, 4) << 11) | (bits(o, 9, 8) << 9) | (bits(o, 10, 10) << 8) | \
                (bits(o, 6, 6) << 7) | (bits(o, 7, 7) << 6) | (bits(o, 3, 1) << 3) | (bits(o, 5, 5) << 2)
            return (5 << 13) | enc | 1
        if mn in ("beqz", "bnez"):
            rs1, off = creg(R(ops[0])), rel(ops[1])
            chk(off, off % 2 == 0 and fits_s(off, 9), "offset")
            o = off
            enc = (bits(o, 8, 8) << 12) | (bits(o, 4, 3) << 10) | (bits(o, 7, 6) << 5) | (bits(o, 2, 1) << 3) | \
                (bits(o, 5, 5) << 2)
            return ((6 if mn == "beqz" else 7) << 13) | enc | (rs1 << 7) | 1
        if mn == "slli":
            rd, sh = R(ops[0]), V(ops[1])
            chk(sh, 1 <= sh <= 64, "shamt")
            f = 0 if sh == 64 else sh
            return (0 << 13) | (bits(f, 5, 5) << 12) | (rd << 7) | (bits(f, 4, 0) << 2) | 2
        if mn in ("lwsp", "ldsp", "lqsp"):
            rd = R(ops[0])
            off, base = self.mem(ops[1], pc, need)
            if base != 2 or rd == 0:
                raise AsmError(f"c.{mn} needs sp base and rd!=0")
            if mn == "lwsp":
                chk(off, off % 4 == 0 and 0 <= off < 256, "offset")
                imm = (bits(off, 5, 5) << 12) | (bits(off, 4, 2) << 4) | (bits(off, 7, 6) << 2)
                f3 = 2
            elif mn == "ldsp":
                chk(off, off % 8 == 0 and 0 <= off < 512, "offset")
                imm = (bits(off, 5, 5) << 12) | (bits(off, 4, 3) << 5) | (bits(off, 8, 6) << 2)
                f3 = 3
            else:
                chk(off, off % 16 == 0 and 0 <= off < 1024, "offset")
                imm = (bits(off, 5, 5) << 12) | (bits(off, 4, 4) << 6) | (bits(off, 9, 6) << 2)
                f3 = 1
            return (f3 << 13) | imm | (rd << 7) | 2
        if mn in ("swsp", "sdsp", "sqsp"):
            rs2 = R(ops[0])
            off, base = self.mem(ops[1], pc, need)
            if base != 2:
                raise AsmError(f"c.{mn} needs sp base")
            if mn == "swsp":
                chk(off, off % 4 == 0 and 0 <= off < 256, "offset")
                imm = (bits(off, 5, 2) << 9) | (bits(off, 7, 6) << 7)
                f3 = 6
            elif mn == "sdsp":
                chk(off, off % 8 == 0 and 0 <= off < 512, "offset")
                imm = (bits(off, 5, 3) << 10) | (bits(off, 8, 6) << 7)
                f3 = 7
            else:
                chk(off, off % 16 == 0 and 0 <= off < 1024, "offset")
                imm = (bits(off, 5, 4) << 11) | (bits(off, 9, 6) << 7)
                f3 = 5
            return (f3 << 13) | imm | (rs2 << 2) | 2
        if mn in ("jr", "jalr"):
            rs1 = R(ops[0])
            if rs1 == 0:
                raise AsmError(f"c.{mn} rs1 must be non-zero")
            return (4 << 13) | ((1 if mn == "jalr" else 0) << 12) | (rs1 << 7) | 2
        if mn in ("mv", "add"):
            rd, rs2 = R(ops[0]), R(ops[1])
            if rs2 == 0:
                raise AsmError(f"c.{mn} rs2 must be non-zero")
            return (4 << 13) | ((1 if mn == "add" else 0) << 12) | (rd << 7) | (rs2 << 2) | 2
        raise AsmError(f"unknown compressed mnemonic 'c.{mn}'")

    # ---------------------------------------------------------- driver
    @staticmethod
    def split_ops(s):
        out, depth, cur = [], 0, ""
        for ch in s:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            if ch == "," and depth == 0:
                out.append(cur.strip())
                cur = ""
            else:
                cur += ch
        if cur.strip():
            out.append(cur.strip())
        return out

    def run_pass(self, lines, final):
        pc = self.base
        out = bytearray()

        def emit(b):
            nonlocal pc
            out.extend(b)
            pc += len(b)

        for lineno, raw in lines:
            line = raw.split("#")[0].split("//")[0].strip()
            while True:
                m = re.match(r"^([A-Za-z_.][A-Za-z_0-9.]*)\s*:(.*)$", line)
                if not m:
                    break
                name = m.group(1)
                if not final:
                    if name in self.labels:
                        raise AsmError(f"line {lineno}: duplicate label {name}")
                    self.labels[name] = pc
                line = m.group(2).strip()
            if not line:
                continue
            parts = line.split(None, 1)
            mn = parts[0].lower()
            ops = self.split_ops(parts[1]) if len(parts) > 1 else []
            try:
                if mn in (".equ", ".set"):
                    self.equs[ops[0]] = self.value(ops[1], pc, True)
                elif mn == ".org":
                    tgt = self.value(ops[0], pc, True)
                    if tgt < pc:
                        raise AsmError(".org moves backwards")
                    emit(bytes(tgt - pc))
                elif mn in (".align", ".p2align"):
                    # relleno con NOPs como GNU as en codigo: 0x0000 es una instruccion ilegal
                    a = 1 << self.value(ops[0], pc, True)
                    pad = (-pc) % a
                    if pad % 2:
                        emit(bytes(pad))
                    else:
                        if pad % 4:
                            emit((0x0001).to_bytes(2, "little"))
                        emit((0x00000013).to_bytes(4, "little") * (pad // 4))
                elif mn in (".byte", ".half", ".word", ".dword", ".octa"):
                    size = {".byte": 1, ".half": 2, ".word": 4, ".dword": 8, ".octa": 16}[mn]
                    for o in ops:
                        v = self.value(o, pc, final)
                        emit((v & ((1 << (8 * size)) - 1)).to_bytes(size, "little"))
                elif mn in (".zero", ".space"):
                    emit(bytes(self.value(ops[0], pc, True)))
                elif mn in (".text", ".data", ".globl", ".global", ".section", ".option"):
                    pass
                else:
                    emit(self.assemble_insn(mn, ops, pc, final))
            except AsmError as e:
                raise AsmError(f"line {lineno}: {raw.strip()}: {e}")
        return bytes(out)

    def assemble(self, text):
        lines = list(enumerate(text.splitlines(), 1))
        first = self.run_pass(lines, False)
        second = self.run_pass(lines, True)
        if len(first) != len(second):
            raise AsmError("pass size mismatch (li of a forward symbol?)")
        return second


def write_hex128(data, path):
    data = data + bytes((-len(data)) % 16)
    with open(path, "w") as f:
        for i in range(0, len(data), 16):
            f.write(int.from_bytes(data[i:i + 16], "little").to_bytes(16, "big").hex() + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--hex")
    ap.add_argument("--base", default="0x80000000")
    ap.add_argument("--sym")
    a = ap.parse_args()
    asm = Assembler(int(a.base, 0))
    try:
        data = asm.assemble(open(a.src).read())
    except AsmError as e:
        print(f"{a.src}: {e}", file=sys.stderr)
        sys.exit(1)
    open(a.out, "wb").write(data)
    if a.hex:
        write_hex128(data, a.hex)
    if a.sym:
        with open(a.sym, "w") as f:
            for k, v in sorted(asm.labels.items(), key=lambda kv: kv[1]):
                f.write(f"{v:x} {k}\n")


if __name__ == "__main__":
    main()
