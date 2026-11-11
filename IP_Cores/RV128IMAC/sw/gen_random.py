#!/usr/bin/env python3
"""gen_random.py - programas aleatorios para el RV128IMAC (lockstep y QEMU).

Flujo recto con saltos solo hacia delante, operandos de 128 bit aleatorios con
sesgo a las fronteras 32/64/128, todas las familias Q/W/D, unidad M, loads y
stores alineados sobre un buffer, AMO/LR/SC y formas RV128C. Al final vuelca
x1..x31 y el buffer por la UART en hexadecimal (32 digitos por linea), de modo
que la salida del ISS y la de QEMU x-rv128 se pueden comparar texto a texto.
No debe producirse ningun trap: cualquiera salta a 'fail'.

  --qemu    excluye lo que QEMU no implementa (AMO/LR/SC .Q)
  --zb      anade Zbb + Zbc (extension RV128 de este core; QEMU no la tiene)
Uso: gen_random.py <salida.S> --seed S [--n N] [--qemu] [--zb]
"""
import argparse
import random

M = (1 << 128) - 1
REGS = [r for r in range(32) if r not in (0, 2)]          # x2 (sp) = base del buffer, fija
CREGS = list(range(8, 16))
BUF = 2048                                                 # bytes de datos de trabajo

RR = ['add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and',
      'addw', 'subw', 'sllw', 'srlw', 'sraw', 'addd', 'subd', 'slld', 'srld', 'srad']
MD = ['mul', 'mulh', 'mulhsu', 'mulhu', 'div', 'divu', 'rem', 'remu',
      'mulw', 'divw', 'divuw', 'remw', 'remuw', 'muld', 'divd', 'divud', 'remd', 'remud']
RI = ['addi', 'slti', 'sltiu', 'xori', 'ori', 'andi', 'addiw', 'addid']
SH = {'slli': 127, 'srli': 127, 'srai': 127, 'slliw': 31, 'srliw': 31, 'sraiw': 31,
      'sllid': 63, 'srlid': 63, 'sraid': 63}
LD = {'lb': 1, 'lbu': 1, 'lh': 2, 'lhu': 2, 'lw': 4, 'lwu': 4, 'ld': 8, 'ldu': 8, 'lq': 16}
ST = {'sb': 1, 'sh': 2, 'sw': 4, 'sd': 8, 'sq': 16}
AMO = ['amoswap', 'amoadd', 'amoxor', 'amoand', 'amoor', 'amomin', 'amomax', 'amominu', 'amomaxu']
BR = ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu']
ZB_RR = ['andn', 'orn', 'xnor', 'min', 'minu', 'max', 'maxu', 'clmul', 'clmulr', 'clmulh',
         'rol', 'ror', 'rolw', 'rorw', 'rold', 'rord']
ZB_UN = ['clz', 'ctz', 'cpop', 'clzw', 'ctzw', 'cpopw', 'clzd', 'ctzd', 'cpopd',
         'sext.b', 'sext.h', 'zext.h', 'rev8', 'orc.b']
ZB_SH = {'rori': 127, 'roriw': 31, 'rorid': 63}


def rval(r):
    k = r.random()
    if k < 0.15:
        return r.choice([0, 1, M, 1 << 127, (1 << 127) - 1, 1 << 63, (1 << 64) - 1, 1 << 64,
                         (1 << 32) - 1, 1 << 31, M ^ ((1 << 63) - 1), M ^ ((1 << 31) - 1)])
    if k < 0.35:
        v = r.getrandbits(32)
        return v | (M ^ ((1 << 32) - 1)) if v >> 31 else v
    if k < 0.55:
        v = r.getrandbits(64)
        return v | (M ^ ((1 << 64) - 1)) if v >> 63 else v
    if k < 0.65:
        return r.getrandbits(12)
    return r.getrandbits(128)


class Gen:
    def __init__(self, seed, qemu, zb=False):
        self.r = random.Random(seed)
        self.qemu = qemu
        self.zb = zb
        self.out = []
        self.pending = []                 # [restantes, etiqueta] de saltos hacia delante
        self.nl = 0

    def emit(self, s):
        self.out.append('    ' + s)
        done = []
        for p in self.pending:
            p[0] -= 1
            if p[0] == 0:
                done.append(p)
        for p in done:
            self.pending.remove(p)
            self.out.append(f'{p[1]}:')

    def lab(self):
        self.nl += 1
        return f'f{self.nl}'

    def rd(self):
        return f'x{self.r.choice(REGS)}'

    def rs(self):
        return f'x{self.r.choice([0] + REGS)}'

    def one(self):
        r = self.r
        if self.zb and r.random() < 0.25:
            k = r.random()
            if k < 0.5:
                self.emit(f'{r.choice(ZB_RR)} {self.rd()}, {self.rs()}, {self.rs()}')
            elif k < 0.8:
                self.emit(f'{r.choice(ZB_UN)} {self.rd()}, {self.rs()}')
            else:
                op = r.choice(list(ZB_SH))
                self.emit(f'{op} {self.rd()}, {self.rs()}, {r.randint(0, ZB_SH[op])}')
            return
        k = r.random()
        if k < 0.30:
            self.emit(f'{r.choice(RR)} {self.rd()}, {self.rs()}, {self.rs()}')
        elif k < 0.40:
            self.emit(f'{r.choice(RI)} {self.rd()}, {self.rs()}, {r.randint(-2048, 2047)}')
        elif k < 0.48:
            op = r.choice(list(SH))
            self.emit(f'{op} {self.rd()}, {self.rs()}, {r.randint(0, SH[op])}')
        elif k < 0.54:
            self.emit(f'{r.choice(MD)} {self.rd()}, {self.rs()}, {self.rs()}')
        elif k < 0.57:
            self.emit(f'{r.choice(("lui", "auipc"))} {self.rd()}, {r.getrandbits(20):#x}')
        elif k < 0.66:
            op = r.choice(list(LD))
            sz = LD[op]
            self.emit(f'{op} {self.rd()}, {sz * r.randrange(BUF // sz)}(sp)')
        elif k < 0.74:
            op = r.choice(list(ST))
            sz = ST[op]
            self.emit(f'{op} {self.rs()}, {sz * r.randrange(BUF // sz)}(sp)')
        elif k < 0.78:
            w = r.choice(('w',) if self.qemu else ('w', 'd', 'q'))
            sz = {'w': 4, 'd': 8, 'q': 16}[w]
            # el grupo se emite como una sola unidad: un salto hacia delante nunca aterriza
            # dentro de el (si no, el SC/AMO usaria un x31 sin inicializar)
            grp = f'addi x31, sp, {sz * r.randrange(BUF // sz)}'
            if r.random() < 0.3:
                d = f'x{r.choice([x for x in REGS if x != 31])}'
                grp += f'\n    lr.{w} {d}, (x31)'
                if r.random() < 0.8:
                    grp += f'\n    sc.{w} {self.rd()}, {self.rs()}, (x31)'
            else:
                grp += f'\n    {r.choice(AMO)}.{w} {self.rd()}, {self.rs()}, (x31)'
            self.emit(grp)
        elif k < 0.85:
            lb = self.lab()
            if r.random() < 0.2:
                self.emit(f'jal {self.rd()}, {lb}')
            elif r.random() < 0.2:
                self.emit(f'c.{r.choice(("beqz", "bnez"))} x{r.choice(CREGS)}, {lb}')
            else:
                self.emit(f'{r.choice(BR)} {self.rs()}, {self.rs()}, {lb}')
            self.pending.append([r.randint(1, 3), lb])
        else:
            self.compressed()

    def compressed(self):
        r = self.r
        c = lambda: f'x{r.choice(CREGS)}'
        k = r.randrange(16)
        rd = self.rd()
        if k == 0:
            self.emit(f'c.addi {rd}, {r.randint(-32, 31)}')
        elif k == 1:
            self.emit(f'c.addiw {rd}, {r.randint(-32, 31)}')
        elif k == 2:
            self.emit(f'c.li {rd}, {r.randint(-32, 31)}')
        elif k == 3:
            d = r.choice([x for x in REGS if x != 2])
            self.emit(f'c.lui x{d}, {r.choice([v for v in range(-32, 32) if v])}')
        elif k == 4:
            self.emit(f'c.{r.choice(("srli", "srai"))} {c()}, {r.choice(list(range(1, 32)) + [64] + list(range(96, 128)))}')
        elif k == 5:
            self.emit(f'c.andi {c()}, {r.randint(-32, 31)}')
        elif k == 6:
            self.emit(f'c.{r.choice(("sub", "xor", "or", "and", "subw", "addw"))} {c()}, {c()}')
        elif k == 7:
            self.emit(f'c.slli {rd}, {r.randint(1, 64)}')
        elif k == 8:
            self.emit(f'c.mv {rd}, x{r.choice(REGS)}')
        elif k == 9:
            self.emit(f'c.add {rd}, x{r.choice(REGS)}')
        elif k == 10:
            self.emit(f'c.lwsp {rd}, {4 * r.randrange(64)}(sp)')
        elif k == 11:
            self.emit(f'c.ldsp {rd}, {8 * r.randrange(64)}(sp)')
        elif k == 12:
            self.emit(f'c.lqsp {rd}, {16 * r.randrange(64)}(sp)')
        elif k == 13:
            self.emit(f'c.swsp x{r.choice(REGS)}, {4 * r.randrange(64)}(sp)')
        elif k == 14:
            self.emit(f'c.sdsp x{r.choice(REGS)}, {8 * r.randrange(64)}(sp)')
        else:
            self.emit(f'c.sqsp x{r.choice(REGS)}, {16 * r.randrange(64)}(sp)')

    def program(self, n):
        r = self.r
        init = [rval(r) for _ in range(32)]
        bufinit = [r.getrandbits(128) for _ in range(BUF // 16)]
        L = ['# generado por gen_random.py (no editar)',
             '_start:',
             '    la t0, trap_vec',
             '    csrw mtvec, t0',
             '    la sp, buf',
             '    la x31, init']
        for k in REGS:
            if k != 31:
                L.append(f'    lq x{k}, {16 * k}(x31)')
        L.append(f'    lq x31, {16 * 31}(x31)')
        self.out = L
        for _ in range(n):
            self.one()
        while self.pending:
            self.emit('nop')
        # volcado: x1..x31 al area dump (justo antes de buf), luego por la UART; despues el buffer
        for k in range(1, 32):
            if k != 2:
                self.out.append(f'    sq x{k}, {16 * k - 512}(sp)')
        self.out += [
            '    li s0, 1',
            'dump_regs:',
            '    li t1, 2',
            '    beq s0, t1, dump_next',
            '    slli t0, s0, 4',
            '    add t0, t0, sp',
            '    lq a0, -512(t0)',
            '    jal ra, print_hex',
            'dump_next:',
            '    addi s0, s0, 1',
            '    li t1, 32',
            '    bne s0, t1, dump_regs',
            '    li s0, 0',
            'dump_buf:',
            '    slli t0, s0, 4',
            '    add t0, t0, sp',
            '    lq a0, 0(t0)',
            '    jal ra, print_hex',
            '    addi s0, s0, 1',
            f'    li t1, {BUF // 16}',
            '    bne s0, t1, dump_buf',
            '    li a0, 1',
            '    la t1, tohost',
            '    sd a0, 0(t1)',
            '    lui t1, 0x100',
            '    li a0, 0x5555',
            '    sw a0, 0(t1)',
            'spin:',
            '    j spin',
            '# imprime a0 (128 bit) en hex + salto de linea; usa t0-t3',
            'print_hex:',
            '    lui t0, 0x10000',
            '    li t1, 32',
            'ph_loop:',
            '    srli t2, a0, 124',
            '    addi t3, t2, -10',
            '    bltz t3, ph_dig',
            '    addi t2, t2, 87',
            '    j ph_out',
            'ph_dig:',
            '    addi t2, t2, 48',
            'ph_out:',
            '    sb t2, 0(t0)',
            '    slli a0, a0, 4',
            '    addi t1, t1, -1',
            '    bnez t1, ph_loop',
            '    li t2, 10',
            '    sb t2, 0(t0)',
            '    ret',
            '.align 2',
            'trap_vec:',
            '    li a0, 3',
            '    la t1, tohost',
            '    sd a0, 0(t1)',
            '    lui t1, 0x100',
            '    li a0, 0x13333',
            '    sw a0, 0(t1)',
            'tspin:',
            '    j tspin',
            '.align 6',
            'tohost:',
            '    .dword 0, 0',
            '.align 4',
            'init:']
        self.out += [f'    .octa {v:#x}' for v in init]
        self.out += ['.align 4', 'dump:', f'    .zero {16 * 32}', 'buf:'] + [f'    .octa {v:#x}' for v in bufinit]
        return '\n'.join(self.out) + '\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--n', type=int, default=3000)
    ap.add_argument('--qemu', action='store_true')
    ap.add_argument('--zb', action='store_true')
    a = ap.parse_args()
    open(a.out, 'w').write(Gen(a.seed, a.qemu, a.zb).program(a.n))


if __name__ == '__main__':
    main()
