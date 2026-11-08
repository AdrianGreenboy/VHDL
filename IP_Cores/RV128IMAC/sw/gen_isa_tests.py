#!/usr/bin/env python3
"""gen_isa_tests.py - pruebas dirigidas autoverificables del RV128IMAC (estilo riscv-tests).

No hay toolchain RV128 (ni GNU as ni LLVM): este generador escribe .S para
rv128asm.py. Cada caso compara contra un valor esperado calculado aqui con un
modelo de referencia propio (independiente de iss128.py). Al terminar:
  PASS: tohost <- 1,            sifive_test(0x100000) <- 0x5555
  FAIL: tohost <- (caso<<1)|1,  sifive_test <- (caso<<16)|0x3333
asi el mismo binario vale para el lockstep (tohost) y para QEMU x-rv128 (sifive_test).

Grupos (QEMU = tambien sirve para validar el ISS contra QEMU):
  rv128ui_alu  rv128ui_w  rv128ui_d  rv128ui_mem  rv128ui_ctrl  rv128um  rv128uc  rv128ua   (QEMU)
  rv128ua_q    AMO/LR/SC .Q (codificacion propia, QEMU no la tiene)
  rv128mi_csr  rv128mi_trap  rv128mi_irq   (dependientes de la implementacion)

Uso: gen_isa_tests.py <dir_salida> [semilla]
"""
import os
import random
import sys

M = (1 << 128) - 1
M64, M32 = (1 << 64) - 1, (1 << 32) - 1
QEMU_OK = {'rv128ui_alu', 'rv128ui_w', 'rv128ui_d', 'rv128ui_mem', 'rv128ui_ctrl', 'rv128um', 'rv128uc', 'rv128ua'}


def sx(v, b):
    v &= (1 << b) - 1
    return v - (1 << b) if v >> (b - 1) else v


def u(v):
    return v & M


# ------------------------------------------------------------- modelo de referencia
def tdiv(x, y):
    """division truncada hacia cero (enteros con signo de Python)."""
    q = abs(x) // abs(y)
    return -q if (x < 0) != (y < 0) else q


def ref_div(a, b, w, signed, rem):
    if signed:
        x, y = sx(a, w), sx(b, w)
    else:
        x, y = a & ((1 << w) - 1), b & ((1 << w) - 1)
    if y == 0:
        r = x if rem else -1
    elif signed and x == -(1 << (w - 1)) and y == -1:
        r = 0 if rem else x
    else:
        q = tdiv(x, y)
        r = x - q * y if rem else q
    return u(sx(r, w))


RR = {
    'add':  lambda a, b: u(a + b),
    'sub':  lambda a, b: u(a - b),
    'sll':  lambda a, b: u(a << (b & 127)),
    'slt':  lambda a, b: int(sx(a, 128) < sx(b, 128)),
    'sltu': lambda a, b: int(a < b),
    'xor':  lambda a, b: a ^ b,
    'srl':  lambda a, b: a >> (b & 127),
    'sra':  lambda a, b: u(sx(a, 128) >> (b & 127)),
    'or':   lambda a, b: a | b,
    'and':  lambda a, b: a & b,
}
RRW = {
    'addw': lambda a, b: u(sx(a + b, 32)),
    'subw': lambda a, b: u(sx(a - b, 32)),
    'sllw': lambda a, b: u(sx(a << (b & 31), 32)),
    'srlw': lambda a, b: u(sx((a & M32) >> (b & 31), 32)),
    'sraw': lambda a, b: u(sx(a, 32) >> (b & 31)),
}
RRD = {
    'addd': lambda a, b: u(sx(a + b, 64)),
    'subd': lambda a, b: u(sx(a - b, 64)),
    'slld': lambda a, b: u(sx(a << (b & 63), 64)),
    'srld': lambda a, b: u(sx((a & M64) >> (b & 63), 64)),
    'srad': lambda a, b: u(sx(a, 64) >> (b & 63)),
}
MUL = {
    'mul':    lambda a, b: u(a * b),
    'mulh':   lambda a, b: u((sx(a, 128) * sx(b, 128)) >> 128),
    'mulhsu': lambda a, b: u((sx(a, 128) * b) >> 128),
    'mulhu':  lambda a, b: u((a * b) >> 128),
    'div':    lambda a, b: ref_div(a, b, 128, True, False),
    'divu':   lambda a, b: ref_div(a, b, 128, False, False),
    'rem':    lambda a, b: ref_div(a, b, 128, True, True),
    'remu':   lambda a, b: ref_div(a, b, 128, False, True),
    'mulw':   lambda a, b: u(sx(a * b, 32)),
    'divw':   lambda a, b: ref_div(a, b, 32, True, False),
    'divuw':  lambda a, b: ref_div(a, b, 32, False, False),
    'remw':   lambda a, b: ref_div(a, b, 32, True, True),
    'remuw':  lambda a, b: ref_div(a, b, 32, False, True),
    'muld':   lambda a, b: u(sx(a * b, 64)),
    'divd':   lambda a, b: ref_div(a, b, 64, True, False),
    'divud':  lambda a, b: ref_div(a, b, 64, False, False),
    'remd':   lambda a, b: ref_div(a, b, 64, True, True),
    'remud':  lambda a, b: ref_div(a, b, 64, False, True),
}
RI = {
    'addi':  lambda a, i: u(a + i),
    'slti':  lambda a, i: int(sx(a, 128) < i),
    'sltiu': lambda a, i: int(a < u(i)),
    'xori':  lambda a, i: a ^ u(i),
    'ori':   lambda a, i: a | u(i),
    'andi':  lambda a, i: a & u(i),
    'addiw': lambda a, i: u(sx(a + i, 32)),
    'addid': lambda a, i: u(sx(a + i, 64)),
}
SHI = {  # nombre: (funcion, shamt maximo)
    'slli':  (lambda a, s: u(a << s), 127),
    'srli':  (lambda a, s: a >> s, 127),
    'srai':  (lambda a, s: u(sx(a, 128) >> s), 127),
    'slliw': (lambda a, s: u(sx(a << s, 32)), 31),
    'srliw': (lambda a, s: u(sx((a & M32) >> s, 32)), 31),
    'sraiw': (lambda a, s: u(sx(a, 32) >> s), 31),
    'sllid': (lambda a, s: u(sx(a << s, 64)), 63),
    'srlid': (lambda a, s: u(sx((a & M64) >> s, 64)), 63),
    'sraid': (lambda a, s: u(sx(a, 64) >> s), 63),
}

CORNER = [0, 1, 2, M, M - 1, 1 << 127, (1 << 127) - 1, 1 << 64, M64, 1 << 63, (1 << 63) - 1,
          u(-(1 << 63)), 1 << 32, M32, 0x80000000, 0x7FFFFFFF, u(-(1 << 31)),
          0x0123456789ABCDEF_FEDCBA9876543210, 0xF0F0F0F0F0F0F0F0_0F0F0F0F0F0F0F0F]


class T:
    """Constructor de un programa de prueba."""

    def __init__(self, name, rnd):
        self.name = name
        self.rnd = rnd
        self.lines = []
        self.data = []            # tabla de operandos (.octa)
        self.n = 0                # numero de caso (gp)
        self.lbl = 0

    def L(self, s):
        self.lines.append(s)

    def label(self, p='l'):
        self.lbl += 1
        return f'{p}{self.lbl}'

    def case(self):
        self.n += 1
        self.L(f'    li gp, {self.n}')

    def oct(self, v):
        """anade un valor a la tabla; devuelve su desplazamiento."""
        self.data.append(u(v))
        return 16 * (len(self.data) - 1)

    def ld_tab(self, reg, v):
        """carga un valor de 128 bit desde la tabla (s0 = base, avanza por bloques)."""
        off = self.oct(v)
        self.L(f'    la t6, tab')
        self.L(f'    li t5, {off}')
        self.L(f'    add t6, t6, t5')
        self.L(f'    lq {reg}, 0(t6)')

    def check(self, reg, exp, tmp='t4'):
        ok = self.label('ok')
        self.ld_tab(tmp, exp)
        self.L(f'    beq {reg}, {tmp}, {ok}')
        self.L('    j fail')
        self.L(f'{ok}:')

    def check_imm(self, reg, exp, tmp='t4'):
        ok = self.label('ok')
        self.L(f'    li {tmp}, {sx(exp, 128)}')
        self.L(f'    beq {reg}, {tmp}, {ok}')
        self.L('    j fail')
        self.L(f'{ok}:')

    def vals(self, k):
        r = self.rnd
        out = list(CORNER)
        for _ in range(k):
            out.append(r.getrandbits(r.choice((8, 32, 63, 64, 65, 96, 127, 128))))
        return out

    # ---------------------------------------------------- salida
    def render(self):
        hdr = [
            f'# {self.name}.S - generado por gen_isa_tests.py (no editar)',
            '_start:',
            '    la t0, trap_vec',
            '    csrw mtvec, t0',
            '    li s8, 0',
        ]
        tail = [
            'pass:',
            '    li a0, 1',
            '    la t1, tohost',
            '    sd a0, 0(t1)',
            '    lui t1, 0x100',
            '    li a0, 0x5555',
            '    sw a0, 0(t1)',
            'pass_spin:',
            '    j pass_spin',
            'fail:',
            '    slli a0, gp, 1',
            '    ori a0, a0, 1',
            '    la t1, tohost',
            '    sd a0, 0(t1)',
            '    lui t1, 0x100',
            '    slli a0, gp, 16',
            '    li t2, 0x3333',
            '    or a0, a0, t2',
            '    sw a0, 0(t1)',
            'fail_spin:',
            '    j fail_spin',
            '',
            '# trap: s8=1 excepcion esperada (s10 causa, s11 tval, s7 mepc, s9 longitud)',
            '#       s8=2 interrupcion esperada (s10 causa completa); s6 cuenta interrupciones',
            '.align 2',
            'trap_vec:',
            '    li t5, 1',
            '    beq s8, t5, trap_exc',
            '    li t5, 2',
            '    beq s8, t5, trap_irq',
            '    j fail',
            'trap_exc:',
            '    csrr t5, mcause',
            '    bne t5, s10, trap_bad',
            '    csrr t5, mtval',
            '    bne t5, s11, trap_bad',
            '    csrr t5, mepc',
            '    bne t5, s7, trap_bad',
            '    add t5, t5, s9',
            '    csrw mepc, t5',
            '    li s8, 0',
            '    mret',
            'trap_irq:',
            '    csrr t5, mcause',
            '    bne t5, s10, trap_bad',
            '    addi s6, s6, 1',
            '    lui t5, 0x2000',          # CLINT: msip = 0, mtimecmp = -1
            '    sw zero, 0(t5)',
            '    li t3, -1',
            '    li t4, 0x2004000',
            '    sd t3, 0(t4)',
            '    li s8, 0',
            '    mret',
            'trap_bad:',
            '    j fail',
            '',
            '.align 6',
            'tohost:',
            '    .dword 0, 0',
            '.align 4',
            'tab:',
        ]
        tab = [f'    .octa {v:#x}' for v in self.data]
        extra = ['.align 4', 'buf:', '    .zero 512', '.align 4', 'buf_end:']
        return '\n'.join(hdr + self.lines + ['    j pass'] + tail + tab + extra) + '\n'


# ------------------------------------------------------------- grupos
def g_alu(t):
    vals = t.vals(6)
    for op, f in RR.items():
        pairs = [(t.rnd.choice(vals), t.rnd.choice(vals)) for _ in range(28)]
        if op in ('sll', 'srl', 'sra'):
            pairs += [(t.rnd.choice(vals), s) for s in (0, 1, 31, 32, 63, 64, 65, 96, 127, 128, 255)]
        for a, b in pairs:
            t.case()
            t.ld_tab('a1', a)
            t.ld_tab('a2', b)
            t.L(f'    {op} a3, a1, a2')
            t.check('a3', f(a, b))
    for op, f in RI.items():
        if op in ('addiw', 'addid'):
            continue
        for _ in range(16):
            a = t.rnd.choice(vals)
            i = t.rnd.choice((0, 1, -1, 2047, -2048, t.rnd.randint(-2048, 2047)))
            t.case()
            t.ld_tab('a1', a)
            t.L(f'    {op} a3, a1, {i}')
            t.check('a3', f(a, i))
    for op in ('slli', 'srli', 'srai'):
        f, mx = SHI[op]
        for s in (0, 1, 7, 31, 32, 63, 64, 65, 95, 96, 100, 126, 127):
            a = t.rnd.choice(vals)
            t.case()
            t.ld_tab('a1', a)
            t.L(f'    {op} a3, a1, {s}')
            t.check('a3', f(a, s))
    # x0 como destino y fuente
    t.case()
    t.ld_tab('a1', M)
    t.L('    add zero, a1, a1')
    t.L('    add a3, zero, zero')
    t.check_imm('a3', 0)


def g_w(t):
    vals = t.vals(6)
    for op, f in RRW.items():
        for _ in range(24):
            a, b = t.rnd.choice(vals), t.rnd.choice(vals)
            t.case(); t.ld_tab('a1', a); t.ld_tab('a2', b)
            t.L(f'    {op} a3, a1, a2'); t.check('a3', f(a, b))
    for _ in range(24):
        a, i = t.rnd.choice(vals), t.rnd.randint(-2048, 2047)
        t.case(); t.ld_tab('a1', a)
        t.L(f'    addiw a3, a1, {i}'); t.check('a3', RI['addiw'](a, i))
    for op in ('slliw', 'srliw', 'sraiw'):
        f, mx = SHI[op]
        for s in (0, 1, 15, 16, 30, 31):
            a = t.rnd.choice(vals)
            t.case(); t.ld_tab('a1', a)
            t.L(f'    {op} a3, a1, {s}'); t.check('a3', f(a, s))


def g_d(t):
    vals = t.vals(6)
    for op, f in RRD.items():
        for _ in range(24):
            a, b = t.rnd.choice(vals), t.rnd.choice(vals)
            t.case(); t.ld_tab('a1', a); t.ld_tab('a2', b)
            t.L(f'    {op} a3, a1, a2'); t.check('a3', f(a, b))
    for _ in range(24):
        a, i = t.rnd.choice(vals), t.rnd.randint(-2048, 2047)
        t.case(); t.ld_tab('a1', a)
        t.L(f'    addid a3, a1, {i}'); t.check('a3', RI['addid'](a, i))
    for op in ('sllid', 'srlid', 'sraid'):
        f, mx = SHI[op]
        for s in (0, 1, 31, 32, 33, 62, 63):
            a = t.rnd.choice(vals)
            t.case(); t.ld_tab('a1', a)
            t.L(f'    {op} a3, a1, {s}'); t.check('a3', f(a, s))
    v = 0xDEAD_0000_0000_0000_8000_0000_0000_0001
    t.case(); t.ld_tab('a1', v)
    t.L('    sext.d a3, a1'); t.check('a3', u(sx(v, 64)))


def g_mem(t):
    """stores de cada anchura en cada carril + loads con extension; LQ/SQ/LDU/LWU."""
    mem = bytearray(64)
    t.L('    la s1, buf')
    # 1) SQ/LQ con li (no depende de la tabla)
    pats = [0x0123456789ABCDEF_FEDCBA9876543210, M, 1 << 127, 0x8000_0000_0000_0000_7FFF_FFFF_FFFF_FFFF]
    for k, p in enumerate(pats):
        t.case()
        t.L(f'    li a1, {sx(p, 128)}')
        t.L(f'    sq a1, {16 * k}(s1)')
        t.L(f'    lq a2, {16 * k}(s1)')
        t.check_imm('a2', p, 'a3')
        mem[16 * k:16 * k + 16] = p.to_bytes(16, 'little')
    # 2) stores parciales en todos los carriles y relectura completa
    for size, mn in ((1, 'sb'), (2, 'sh'), (4, 'sw'), (8, 'sd')):
        for lane in range(0, 16, size):
            v = t.rnd.getrandbits(128)
            t.case()
            t.ld_tab('a1', v)
            t.L(f'    {mn} a1, {16 + lane}(s1)')
            mem[16 + lane:16 + lane + size] = (v & ((1 << (8 * size)) - 1)).to_bytes(size, 'little')
            t.L('    lq a2, 16(s1)')
            t.check('a2', int.from_bytes(mem[16:32], 'little'))
    # 3) loads de cada anchura en cada carril con extension de signo/cero
    line = int.from_bytes(mem[0:64], 'little')
    loads = [('lb', 1, True), ('lbu', 1, False), ('lh', 2, True), ('lhu', 2, False),
             ('lw', 4, True), ('lwu', 4, False), ('ld', 8, True), ('ldu', 8, False), ('lq', 16, False)]
    for mn, size, sgn in loads:
        for off in range(0, 64, size if size >= 4 else 3 * size):
            if off % size:
                continue
            raw = int.from_bytes(mem[off:off + size], 'little')
            exp = u(sx(raw, 8 * size)) if sgn else raw
            t.case()
            t.L(f'    {mn} a2, {off}(s1)')
            t.check('a2', exp)
    # 4) desplazamientos negativos y base desalineada respecto a 16 (offset la corrige)
    t.case()
    t.L('    addi s2, s1, 48')
    t.L('    lq a2, -48(s2)')
    t.check('a2', int.from_bytes(mem[0:16], 'little'))
    del line


def g_ctrl(t):
    vals = [0, 1, M, 1 << 64, 1 << 127, (1 << 127) - 1, M64, 1 << 63, u(-(1 << 63)), 5, u(-5)]
    br = {'beq': lambda a, b: a == b, 'bne': lambda a, b: a != b,
          'blt': lambda a, b: sx(a, 128) < sx(b, 128), 'bge': lambda a, b: sx(a, 128) >= sx(b, 128),
          'bltu': lambda a, b: a < b, 'bgeu': lambda a, b: a >= b}
    for op, f in br.items():
        for a in vals:
            for b in (0, 1 << 64, 1 << 127, M, a):
                tk, jn = t.label('tk'), t.label('jn')
                t.case(); t.ld_tab('a1', a); t.ld_tab('a2', b)
                t.L(f'    {op} a1, a2, {tk}')
                t.L('    li a3, 0')
                t.L(f'    j {jn}')
                t.L(f'{tk}:')
                t.L('    li a3, 1')
                t.L(f'{jn}:')
                t.check_imm('a3', int(f(a, b)), 'a4')
    # lui / auipc con signo: la direccion absoluta va en la tabla (.octa etiqueta)
    for imm in (0x80000, 0x7FFFF, 0xFFFFF, 0x12345):
        t.case()
        t.L(f'    lui a3, {imm:#x}')
        t.check('a3', u(sx(imm << 12, 32)))
    t.case()
    lb = t.label('ap')
    t.L(f'{lb}:')
    t.L('    auipc a3, 0')
    t.data.append(lb)                      # resuelto por el ensamblador
    off = 16 * (len(t.data) - 1)
    t.L(f'    la t6, tab'); t.L(f'    li t5, {off}'); t.L('    add t6, t6, t5'); t.L('    lq a4, 0(t6)')
    ok = t.label('ok')
    t.L(f'    beq a3, a4, {ok}'); t.L('    j fail'); t.L(f'{ok}:')
    # jal / jalr: enlace y bit 0 del destino
    t.case()
    tg, after = t.label('jt'), t.label('ja')
    t.L(f'    jal a5, {tg}')
    t.L(f'{after}:')
    t.L('    j fail')
    t.L(f'{tg}:')
    t.data.append(after)
    off = 16 * (len(t.data) - 1)
    t.L(f'    la t6, tab'); t.L(f'    li t5, {off}'); t.L('    add t6, t6, t5'); t.L('    lq a4, 0(t6)')
    ok = t.label('ok')
    t.L(f'    beq a5, a4, {ok}'); t.L('    j fail'); t.L(f'{ok}:')
    t.case()
    tg = t.label('jr')
    t.L(f'    la a1, {tg}')
    t.L('    jalr a5, a1, 1')                # bit 0 del destino se descarta
    t.L('    j fail')
    t.L(f'{tg}:')
    t.L('    nop')


def g_m(t):
    vals = t.vals(4)
    for op, f in MUL.items():
        pairs = [(t.rnd.choice(vals), t.rnd.choice(vals)) for _ in range(16)]
        pairs += [(t.rnd.choice(vals), 0), (1 << 127, M), (u(-(1 << 63)), M), (u(-(1 << 31)), M),
                  (M, M), (t.rnd.getrandbits(128), 1)]
        for a, b in pairs:
            t.case(); t.ld_tab('a1', a); t.ld_tab('a2', b)
            t.L(f'    {op} a3, a1, a2'); t.check('a3', f(a, b))
    # dependencias encadenadas con la unidad iterativa
    t.case()
    t.ld_tab('a1', 0x1_0000_0000_0000_0003)
    t.L('    mul a2, a1, a1'); t.L('    mulhu a3, a2, a1'); t.L('    add a4, a2, a3')
    a = 0x1_0000_0000_0000_0003
    p = u(a * a)
    t.check('a4', u(p + u((p * a) >> 128)))


def g_c(t):
    """RV128C: cada forma, con enfasis en C.LQ/C.SQ/C.LQSP/C.SQSP y desplazamientos."""
    t.L('    la sp, buf')
    t.L('    la s1, buf')
    v = 0x1122334455667788_99AABBCCDDEEFF00
    t.case(); t.ld_tab('a1', v)
    t.L('    c.sq a1, 32(s1)'); t.L('    c.lq a2, 32(s1)'); t.check('a2', v)
    t.case(); t.L('    c.sqsp a1, 64(sp)'); t.L('    c.lqsp a3, 64(sp)'); t.check('a3', v)
    t.case(); t.L('    c.sq a1, 496(s1)'); t.L('    lq a2, 496(s1)'); t.check('a2', v)
    t.case(); t.L('    c.sd a1, 8(s1)'); t.L('    c.ld a2, 8(s1)'); t.check('a2', u(sx(v, 64)))
    t.case(); t.L('    c.sw a1, 4(s1)'); t.L('    c.lw a2, 4(s1)'); t.check('a2', u(sx(v, 32)))
    t.case(); t.L('    c.sdsp a1, 24(sp)'); t.L('    c.ldsp a2, 24(sp)'); t.check('a2', u(sx(v, 64)))
    t.case(); t.L('    c.swsp a1, 12(sp)'); t.L('    c.lwsp a2, 12(sp)'); t.check('a2', u(sx(v, 32)))
    a = 0x8000_0000_0000_0000_0000_0000_0000_0001 | (0xF0 << 64)
    for s in (1, 31, 64, 96, 100, 127):
        t.case(); t.ld_tab('a2', a)
        t.L(f'    c.srli a2, {s}'); t.check('a2', a >> s)
        t.case(); t.ld_tab('a2', a)
        t.L(f'    c.srai a2, {s}'); t.check('a2', u(sx(a, 128) >> s))
    for s in (1, 5, 31, 63, 64):
        t.case(); t.ld_tab('a2', a)
        t.L(f'    c.slli a2, {s}'); t.check('a2', u(a << s))
    t.case(); t.ld_tab('a2', a); t.L('    c.andi a2, -3'); t.check('a2', a & u(-3))
    t.case(); t.L('    c.li a2, -7'); t.L('    c.addi a2, 12'); t.check_imm('a2', 5)
    t.case(); t.ld_tab('a2', M64); t.L('    c.addiw a2, 1'); t.check_imm('a2', 0)
    t.case(); t.L('    c.lui a2, -1'); t.check('a2', u(sx(0xFFFFF000, 32)))
    t.case(); t.L('    mv a4, sp'); t.L('    c.addi16sp sp, -64'); t.L('    c.addi16sp sp, 64')
    ok = t.label('ok'); t.L(f'    beq a4, sp, {ok}'); t.L('    j fail'); t.L(f'{ok}:')
    t.case(); t.L('    c.addi4spn a2, sp, 32'); t.L('    addi a4, sp, 32')
    ok = t.label('ok'); t.L(f'    beq a4, a2, {ok}'); t.L('    j fail'); t.L(f'{ok}:')
    x, y = 0xFFFF_0000_1234_5678_0000_0001_8000_0000, 0x0000_0001_0000_0000_7FFF_FFFF_8000_0001
    for op, f in (('sub', RR['sub']), ('xor', RR['xor']), ('or', RR['or']), ('and', RR['and']),
                  ('subw', RRW['subw']), ('addw', RRW['addw'])):
        t.case(); t.ld_tab('a2', x); t.ld_tab('a3', y)
        t.L(f'    c.{op} a2, a3'); t.check('a2', f(x, y))
    t.case(); t.ld_tab('a3', x); t.L('    c.mv a2, a3'); t.L('    c.add a2, a3'); t.check('a2', u(2 * x))
    # c.j / c.beqz / c.bnez / c.jr / c.jalr
    t.case(); tg = t.label('cj'); t.L(f'    c.j {tg}'); t.L('    j fail'); t.L(f'{tg}:')
    t.case(); tg = t.label('cb'); t.L('    li a2, 0'); t.L(f'    c.beqz a2, {tg}'); t.L('    j fail'); t.L(f'{tg}:')
    t.case(); tg = t.label('cb'); t.ld_tab('a2', 1 << 100); t.L(f'    c.bnez a2, {tg}'); t.L('    j fail'); t.L(f'{tg}:')
    t.case(); tg = t.label('cr'); t.L(f'    la a5, {tg}'); t.L('    c.jr a5'); t.L('    j fail'); t.L(f'{tg}:')
    t.case(); tg, af = t.label('cl'), t.label('ca')
    t.L(f'    la a5, {tg}'); t.L('    c.jalr a5'); t.L(f'{af}:'); t.L('    j fail'); t.L(f'{tg}:')
    t.data.append(af)
    off = 16 * (len(t.data) - 1)
    t.L('    la t6, tab'); t.L(f'    li t5, {off}'); t.L('    add t6, t6, t5'); t.L('    lq a4, 0(t6)')
    ok = t.label('ok'); t.L(f'    beq ra, a4, {ok}'); t.L('    j fail'); t.L(f'{ok}:')
    # instruccion de 32 bit que cruza una palabra de 4 bytes (pc = 4k+2)
    t.case(); t.L('    .align 2'); t.L('    c.nop'); t.L('    li a2, 77'); t.check_imm('a2', 77)


def g_amo(t, widths):
    t.L('    la s1, buf')
    ops = {'amoswap': lambda m, s, w: s, 'amoadd': lambda m, s, w: m + s, 'amoxor': lambda m, s, w: m ^ s,
           'amoand': lambda m, s, w: m & s, 'amoor': lambda m, s, w: m | s,
           'amomin': lambda m, s, w: m if sx(m, w) < sx(s, w) else s,
           'amomax': lambda m, s, w: m if sx(m, w) > sx(s, w) else s,
           'amominu': lambda m, s, w: min(m, s), 'amomaxu': lambda m, s, w: max(m, s)}
    for wn in widths:
        size = {'w': 4, 'd': 8, 'q': 16}[wn]
        bits = 8 * size
        mk = (1 << bits) - 1
        for op, f in ops.items():
            for lane in range(0, 16, size):
                line = t.rnd.getrandbits(128)
                src = t.rnd.choice((t.rnd.getrandbits(128), M, 1 << (bits - 1), 0))
                old = (line >> (8 * lane)) & mk
                new = f(old, src & mk, bits) & mk
                nline = (line & ~(mk << (8 * lane)) & M) | (new << (8 * lane))
                t.case()
                t.ld_tab('a1', line); t.L('    sq a1, 0(s1)')
                t.ld_tab('a2', src)
                t.L(f'    addi s2, s1, {lane}')
                t.L(f'    {op}.{wn} a3, a2, (s2)')
                t.check('a3', u(sx(old, bits)))
                t.L('    lq a4, 0(s1)')
                t.check('a4', nline)
        # LR/SC: exito, fallo sin reserva, fallo tras un SC
        for lane in (0, 16 - size):
            line = t.rnd.getrandbits(128)
            nv = t.rnd.getrandbits(128)
            old = (line >> (8 * lane)) & mk
            nline = (line & ~(mk << (8 * lane)) & M) | ((nv & mk) << (8 * lane))
            t.case()
            t.ld_tab('a1', line); t.L('    sq a1, 0(s1)'); t.ld_tab('a2', nv)
            t.L(f'    addi s2, s1, {lane}')
            t.L(f'    lr.{wn} a3, (s2)')
            t.check('a3', u(sx(old, bits)))
            t.L(f'    sc.{wn} a5, a2, (s2)')
            t.check_imm('a5', 0)
            t.L('    lq a4, 0(s1)'); t.check('a4', nline)
            t.case()
            t.L(f'    sc.{wn} a5, a1, (s2)')                 # sin reserva: falla
            t.check_imm('a5', 1)
            t.L('    lq a4, 0(s1)'); t.check('a4', nline)


def g_csr(t):
    t.case(); t.L('    csrr a1, misa')
    t.check('a1', (3 << 126) | (1 << 0) | (1 << 2) | (1 << 8) | (1 << 12))
    for v in (M, 0x0123456789ABCDEF_FEDCBA9876543210, 0):
        t.case(); t.ld_tab('a1', v); t.L('    csrw mscratch, a1'); t.L('    csrr a2, mscratch'); t.check('a2', v)
    t.case(); t.ld_tab('a1', M); t.L('    csrrw a2, mtval, a1'); t.L('    csrr a2, mtval'); t.check('a2', M)
    t.case(); t.ld_tab('a1', M); t.L('    csrw mepc, a1'); t.L('    csrr a2, mepc'); t.check('a2', M - 1)
    t.case(); t.ld_tab('a1', M); t.L('    csrw mtvec, a1'); t.L('    csrr a2, mtvec'); t.check('a2', M - 2)
    t.L('    la t0, trap_vec'); t.L('    csrw mtvec, t0')
    t.case(); t.L('    li a1, -1'); t.L('    csrw mie, a1'); t.L('    csrr a2, mie'); t.check_imm('a2', 0x888)
    t.L('    csrw mie, zero')
    t.case(); t.L('    li a1, -9'); t.L('    csrw mstatus, a1'); t.L('    csrr a2, mstatus')
    t.check_imm('a2', 0x1880)                                  # MIE no (bit 3 a 0), MPIE, MPP=11
    t.L('    csrw mstatus, zero')
    t.case(); t.L('    csrr a2, mstatus'); t.check_imm('a2', 0x1800)
    t.case(); t.L('    csrsi mscratch, 5'); t.L('    csrci mscratch, 1'); t.L('    csrr a2, mscratch')
    t.check_imm('a2', 4)
    t.case(); t.L('    csrr a2, mhartid'); t.check_imm('a2', 0)
    # minstret: dos lecturas seguidas difieren en 1; escritura sin incremento propio
    t.case(); t.L('    csrr a1, minstret'); t.L('    csrr a2, minstret'); t.L('    sub a3, a2, a1')
    t.check_imm('a3', 1)
    t.case(); t.L('    li a1, 1000'); t.L('    csrw minstret, a1'); t.L('    csrr a2, minstret')
    t.check_imm('a2', 1000)
    t.case(); t.L('    csrr a1, mcycle'); t.L('    csrr a2, mcycle'); t.L('    sltu a3, a1, a2')
    t.check_imm('a3', 1)
    # accesos ilegales: CSR inexistente, escritura a solo lectura, S-mode inexistente
    for enc, what in ((0x7C0025F3, 'csrr a1, 0x7c0'), (0xF1101073, 'csrw mvendorid, zero'),
                      (0x180025F3, 'csrr a1, satp'), (0x100025F3, 'csrr a1, sstatus'),
                      (0xC0101073, 'csrw time, zero')):
        trap_case(t, 2, enc, f'.word {enc:#010x}', 4)


def trap_case(t, cause, tval, insn_line, ilen, setup=(), tval_line=None):
    t.case()
    lb = t.label('tr')
    for s in setup:
        t.L(s)
    t.L(f'    li s10, {cause}')
    t.L(tval_line or f'    li s11, {sx(tval, 128)}')
    t.L(f'    la s7, {lb}')
    t.L(f'    li s9, {ilen}')
    t.L('    li s8, 1')
    t.L(f'{lb}:')
    t.L(insn_line)
    ok = t.label('ok')
    t.L(f'    beqz s8, {ok}')
    t.L('    j fail')
    t.L(f'{ok}:')


def g_trap(t):
    t.L('    la s1, buf')
    trap_case(t, 11, 0, '    ecall', 4)
    t.case()
    lb = t.label('tr')
    t.L('    li s10, 3'); t.L(f'    la s11, {lb}'); t.L(f'    la s7, {lb}'); t.L('    li s9, 4'); t.L('    li s8, 1')
    t.L(f'{lb}:'); t.L('    ebreak')
    ok = t.label('ok'); t.L(f'    beqz s8, {ok}'); t.L('    j fail'); t.L(f'{ok}:')
    t.case()
    lb = t.label('tr')
    t.L('    li s10, 3'); t.L(f'    la s11, {lb}'); t.L(f'    la s7, {lb}'); t.L('    li s9, 2'); t.L('    li s8, 1')
    t.L(f'{lb}:'); t.L('    c.ebreak')
    ok = t.label('ok'); t.L(f'    beqz s8, {ok}'); t.L('    j fail'); t.L(f'{ok}:')
    # ilegales: opcode reservado, SRET/SFENCE (no hay S), RV64 cbo.clean (MISC-MEM f3=010 es LQ
    # aqui: con rd=0 es un LQ legal, asi que se usa f3=011), f3 reservados, RVC reservados
    for enc in (0x0000007F, 0x000000F3, 0x10200073, 0x12000073, 0x00004073, 0x0000300F, 0x0000500F,
                0x00007023, 0x00005023, 0x0000502F, 0xC0001033, 0x0200203B, 0x0000203B, 0x0000207B,
                0x0400105B, 0x0000205B, 0x40001013):
        trap_case(t, 2, enc, f'    .word {enc:#010x}', 4)
    # RV128C reservados: todo ceros, addi4spn imm=0, q0 f3=100, addiw rd=0, addi16sp 0,
    # lui 0, CA reservado, lqsp/lwsp/ldsp rd=0, jr x0
    for h in (0x0000, 0x0004, 0x8000, 0x2001, 0x6101, 0x6181, 0x9C41, 0x2002, 0x4002, 0x6002, 0x8002):
        trap_case(t, 2, h, f'    .half {h:#06x}', 2)
    # desalineados (load 4, store/AMO 6) con tval = direccion
    for mn, size, cause in (('lh', 2, 4), ('lw', 4, 4), ('ld', 8, 4), ('ldu', 8, 4), ('lq', 16, 4),
                            ('sh', 2, 6), ('sw', 4, 6), ('sd', 8, 6), ('sq', 16, 6)):
        for off in (1, size // 2) if size > 2 else (1,):
            trap_case(t, cause, 0, f'    {mn} a2, {off}(s1)', 4, tval_line=f'    addi s11, s1, {off}')
    for wn, size in (('w', 4), ('d', 8), ('q', 16)):
        for f, cause in (('lr', 4), ('sc', 6), ('amoadd', 6)):
            line = f'    {f}.{wn} a2, (s2)' if f == 'lr' else f'    {f}.{wn} a2, a3, (s2)'
            trap_case(t, cause, 0, line, 4, setup=(f'    addi s2, s1, {size // 2}',),
                      tval_line=f'    addi s11, s1, {size // 2}')
    # fallos de acceso: fuera del mapa, bits altos de 128 a 1, atomicos fuera de DRAM
    for addr, line, cause in ((0x0, '    ld a2, 0(s2)', 5), (0x0, '    sd a2, 0(s2)', 7),
                              ((1 << 64) | 0x8000_0000, '    lq a2, 0(s2)', 5),
                              ((1 << 100) | 0x8000_0000, '    sq a2, 0(s2)', 7),
                              (0x1000_0000, '    lr.w a2, (s2)', 5),
                              (0x1000_0000, '    amoswap.w a2, a3, (s2)', 7),
                              (0x1000_0000, '    lq a2, 0(s2)', 5)):
        t.data.append(addr)
        off = 16 * (len(t.data) - 1)
        trap_case(t, cause, addr, line, 4,
                  setup=('    la t6, tab', f'    li t5, {off}', '    add t6, t6, t5', '    lq s2, 0(t6)'))
    # fallo de fetch: salto a 0x0 (tval = destino, mepc = destino); el manejador vuelve a ra
    t.case()
    back = t.label('fb')
    t.L('    li s10, 1'); t.L('    li s11, 0'); t.L('    li s7, 0'); t.L('    li s8, 1')
    t.L(f'    la s9, {back}')                       # mepc(0) + s9 = direccion de vuelta
    t.L('    jalr zero, zero, 0')
    t.L(f'{back}:')
    ok = t.label('ok'); t.L(f'    beqz s8, {ok}'); t.L('    j fail'); t.L(f'{ok}:')


def g_irq(t):
    t.L('    li s6, 0')
    t.L('    lui t0, 0x2000')
    t.L('    li t1, -1'); t.L('    li t2, 0x2004000'); t.L('    sd t1, 0(t2)')     # mtimecmp = -1
    # software (MSIP), directo
    t.case()
    t.L(f'    li s10, {sx((1 << 127) | 3, 128)}'); t.L('    li s8, 2')
    t.L('    li t1, 8'); t.L('    csrw mie, t1'); t.L('    csrsi mstatus, 8')
    t.L('    li t1, 1'); t.L('    sw t1, 0(t0)')                              # msip = 1
    for _ in range(4):
        t.L('    nop')
    t.L('    csrci mstatus, 8')
    t.check_imm('s6', 1, 't1')
    # temporizador con WFI y mtvec vectorizado
    t.case()
    t.L('    la t1, vec_tab'); t.L('    ori t1, t1, 1'); t.L('    csrw mtvec, t1')
    t.L(f'    li s10, {sx((1 << 127) | 7, 128)}'); t.L('    li s8, 2')
    t.L('    li t1, 0x80'); t.L('    csrw mie, t1')
    t.L('    li t2, 0x200bff8'); t.L('    ld t3, 0(t2)'); t.L('    addi t3, t3, 40')
    t.L('    li t2, 0x2004000'); t.L('    sd t3, 0(t2)')
    t.L('    csrsi mstatus, 8')
    w = t.label('wf')
    t.L(f'{w}:'); t.L('    wfi'); t.L(f'    li t1, 2'); t.L(f'    bne s6, t1, {w}')
    t.L('    csrci mstatus, 8'); t.L('    csrw mie, zero')
    t.L('    la t1, trap_vec'); t.L('    csrw mtvec, t1')
    t.check_imm('s6', 2, 't1')
    # interrupcion pendiente pero deshabilitada: no se toma; mip la refleja
    t.case()
    t.L('    li t1, 8'); t.L('    csrw mie, t1')
    t.L('    li t1, 1'); t.L('    sw t1, 0(t0)')
    t.L('    nop'); t.L('    nop')
    t.L('    csrr t2, mip'); t.L('    andi t2, t2, 8')
    t.check_imm('t2', 8, 't1')
    t.L('    sw zero, 0(t0)'); t.L('    csrw mie, zero')
    t.check_imm('s6', 2, 't1')
    # tabla vectorizada: entrada 7 -> trap_vec; el resto -> fail
    t.lines.append('    j pass')
    t.lines.append('.align 6')
    t.lines.append('vec_tab:')
    for k in range(16):
        t.lines.append('    j trap_vec' if k == 7 else '    j fail')


GROUPS = {
    'rv128ui_alu': g_alu, 'rv128ui_w': g_w, 'rv128ui_d': g_d, 'rv128ui_mem': g_mem,
    'rv128ui_ctrl': g_ctrl, 'rv128um': g_m, 'rv128uc': g_c,
    'rv128ua': lambda t: g_amo(t, ('w',)), 'rv128ua_d': lambda t: g_amo(t, ('d',)), 'rv128ua_q': lambda t: g_amo(t, ('q',)),
    'rv128mi_csr': g_csr, 'rv128mi_trap': g_trap, 'rv128mi_irq': g_irq,
}


def main():
    out = sys.argv[1]
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    os.makedirs(out, exist_ok=True)
    for name, g in GROUPS.items():
        t = T(name, random.Random(f'{seed}-{name}'))
        g(t)
        data = t.data
        t.data = [d if isinstance(d, int) else 0 for d in data]
        lines = t.render().split('\n')
        # entradas de la tabla que son etiquetas: .octa <etiqueta> (las resuelve el ensamblador)
        ti = lines.index('tab:')
        for k, d in enumerate(data):
            if not isinstance(d, int):
                lines[ti + 1 + k] = f'    .octa {d}'
        with open(os.path.join(out, name + '.S'), 'w') as f:
            f.write('\n'.join(lines))
    with open(os.path.join(out, 'QEMU_LIST'), 'w') as f:
        f.write('\n'.join(sorted(QEMU_OK)) + '\n')
    print(f'{len(GROUPS)} pruebas en {out}')


if __name__ == '__main__':
    main()
