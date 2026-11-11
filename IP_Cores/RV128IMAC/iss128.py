#!/usr/bin/env python3
"""iss128.py - ISS de referencia RV128IMAC_Zicsr_Zifencei, M/S/U (experimental).

Oraculo del core RV128IMAC. Derivado de iss64.py (verificado contra Spike) con
la misma API (Bus, Hart.step, wlog, mip_hw, irq_forced) para que compare128.py
funcione igual que compare.py. Codificaciones: doc/RV128IMAC_ISA.md.

Modo RV128 del core dual (el modo RV64 se verifica contra iss64.py sin cambios).
Privilegios y CSRs con la misma semantica que iss64.py (Priv. 1.12), ensanchados:
Decisiones de implementacion (deben coincidir con el RTL):
  * M/S/U con medeleg/mideleg, MPRV/SUM/MXR, TVM/TW/TSR, mcounteren/scounteren.
  * misa fijo (MXL=3, A C I M S U), escrituras ignoradas. SXL = UXL = 3.
  * Paginacion: no existe esquema RV128 -> satp lee 0 y las escrituras se ignoran (Bare).
  * Sin Zicbom: MISC-MEM f3=010 es LQ en RV128.
  * PMP con 0 entradas y triggers a 0, como iss64.py. Causa de irq en el bit 127.
  * mcycle/minstret/time de 64 bit, extendidos con ceros al leer.
  * Desalineados -> excepcion 4/6 (LR: 4; SC/AMO: 6).
  * Reserva LR/SC con granulo de 64 B; se borra en cualquier SC y en cualquier trap.
  * mtval: ilegal -> bits de la instruccion; ebreak -> pc; fallos de memoria ->
    direccion; ecall/irq -> 0.
  * wfi se ejecuta como nop (el RTL espera a (mip & mie) /= 0; misma arquitectura).
  * PMA: solo la DRAM es ejecutable y admite atomicos. LR/SC/AMO fuera de DRAM ->
    access fault (5 para LR, 7 para SC/AMO), comprobado ANTES de mirar la reserva.
    Fetch fuera de DRAM/ROM -> instruction access fault. Direcciones con bits
    por encima de 2^32 a 1 quedan fuera del mapa (access fault).
"""
import sys

XLEN = 128
MX = (1 << XLEN) - 1
M64 = (1 << 64) - 1
M32 = (1 << 32) - 1


def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def s128(v):
    return sx(v, 128)


EXC_IACCESS, EXC_ILLEGAL, EXC_BREAK = 1, 2, 3
EXC_LMISALIGN, EXC_LACCESS, EXC_SMISALIGN, EXC_SACCESS = 4, 5, 6, 7
EXC_ECALL_U, EXC_ECALL_S, EXC_ECALL_M = 8, 9, 11
IRQ_BIT = 1 << 127
PRV_U, PRV_S, PRV_M = 0, 1, 3

MS_SIE, MS_MIE, MS_SPIE, MS_MPIE = 1 << 1, 1 << 3, 1 << 5, 1 << 7
MS_SPP = 1 << 8
MS_MPP_SH = 11
MS_MPRV, MS_SUM, MS_MXR = 1 << 17, 1 << 18, 1 << 19
MS_TVM, MS_TW, MS_TSR = 1 << 20, 1 << 21, 1 << 22
MS_UXL_SXL = (3 << 32) | (3 << 34)
MSTATUS_WMASK = (MS_SIE | MS_MIE | MS_SPIE | MS_MPIE | MS_SPP | (3 << MS_MPP_SH)
                 | MS_MPRV | MS_SUM | MS_MXR | MS_TVM | MS_TW | MS_TSR)
SSTATUS_MASK = MS_SIE | MS_SPIE | MS_SPP | MS_SUM | MS_MXR | (3 << 32)
SSTATUS_WMASK = MS_SIE | MS_SPIE | MS_SPP | MS_SUM | MS_MXR
MISA = (3 << 126) | (1 << 0) | (1 << 2) | (1 << 8) | (1 << 12) | (1 << 18) | (1 << 20)

SSIP, MSIP, STIP, MTIP, SEIP, MEIP = 1 << 1, 1 << 3, 1 << 5, 1 << 7, 1 << 9, 1 << 11
S_INTS = SSIP | STIP | SEIP
ALL_INTS = S_INTS | MSIP | MTIP | MEIP
IRQ_PRIO = (11, 3, 7, 9, 1, 5)          # MEI MSI MTI SEI SSI STI
MEDELEG_MASK = sum(1 << b for b in (1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 13, 15))

ROM_BASE, ROM_SIZE = 0x0000_1000, 0x1000
CLINT_BASE, CLINT_SIZE = 0x0200_0000, 0x1_0000
PLIC_BASE, PLIC_SIZE = 0x0C00_0000, 0x400_0000
UART_BASE, UART_SIZE = 0x1000_0000, 0x1000
MMIO_BASE, MMIO_SIZE = 0x1001_0000, 0x10_0000
AXIL_BASE, AXIL_SIZE = 0x2000_0000, 0x1000_0000
STUB_REGIONS = ((PLIC_BASE, PLIC_SIZE, (4,)), (MMIO_BASE, MMIO_SIZE, (1, 2, 4, 8)),
                (AXIL_BASE, AXIL_SIZE, (1, 2, 4, 8)))


class Trap(Exception):
    def __init__(self, cause, tval=0):
        super().__init__(cause, tval)
        self.cause = cause
        self.tval = tval & MX


class AccessFault(Exception):
    pass


class ExitSim(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


# ---------------------------------------------------------------- memoria
class Bus:
    """Mapa fisico: RAM + CLINT + UART + hook tohost (HTIF de riscv-tests)."""

    def __init__(self, ram_base=0x8000_0000, ram_size=8 << 20):
        self.ram_base = ram_base
        self.ram = bytearray(ram_size)
        self.ram_end = ram_base + ram_size
        self.rom = None
        self.tohost = None
        self.console = []
        self.msip = 0
        self.mtimecmp = M64
        self.mtime = 0
        self.uart_out = []

    def in_ram(self, pa, size):
        return self.ram_base <= pa and pa + size <= self.ram_end

    def in_rom(self, pa, size):
        return self.rom is not None and ROM_BASE <= pa and pa + size <= ROM_BASE + ROM_SIZE

    @staticmethod
    def stub(pa, size):
        return any(b <= pa < b + n and size in sz for b, n, sz in STUB_REGIONS)

    def load(self, pa, size):
        if self.in_ram(pa, size):
            o = pa - self.ram_base
            return int.from_bytes(self.ram[o:o + size], 'little')
        if self.in_rom(pa, size):
            o = pa - ROM_BASE
            return int.from_bytes(self.rom[o:o + size], 'little')
        if CLINT_BASE <= pa < CLINT_BASE + CLINT_SIZE and size in (4, 8):
            return self._clint_rd(pa - CLINT_BASE, size)
        if UART_BASE <= pa < UART_BASE + UART_SIZE and size == 1:
            return 0x60 if pa - UART_BASE == 5 else 0
        if self.stub(pa, size):
            return 0
        raise AccessFault()

    def store(self, pa, size, val):
        val &= (1 << (8 * size)) - 1
        if self.in_ram(pa, size):
            o = pa - self.ram_base
            self.ram[o:o + size] = val.to_bytes(size, 'little')
            if self.tohost is not None and pa <= self.tohost < pa + size:
                self._tohost()
            return
        if CLINT_BASE <= pa < CLINT_BASE + CLINT_SIZE and size in (4, 8):
            return self._clint_wr(pa - CLINT_BASE, size, val)
        if UART_BASE <= pa < UART_BASE + UART_SIZE and size == 1:
            if pa - UART_BASE == 0:
                self.uart_out.append(val)
            return
        if self.stub(pa, size):
            return
        raise AccessFault()

    def _clint_rd(self, off, size):
        regs = {0x0: self.msip, 0x4000: self.mtimecmp, 0xBFF8: self.mtime}
        base = off & ~7
        if base in regs:
            return (regs[base] >> (8 * (off & 7))) & ((1 << (8 * size)) - 1)
        return 0

    def _clint_wr(self, off, size, val):
        base, sh = off & ~7, 8 * (off & 7)
        msk = ((1 << (8 * size)) - 1) << sh

        def merge(old):
            return (old & ~msk) | ((val << sh) & msk)
        if base == 0x0:
            self.msip = merge(self.msip) & 1
        elif base == 0x4000:
            self.mtimecmp = merge(self.mtimecmp) & M64
        elif base == 0xBFF8:
            self.mtime = merge(self.mtime) & M64

    def _tohost(self):
        v = self.load(self.tohost, 8)
        if v == 0:
            return
        if (v >> 48) == 0 and v & 1:
            raise ExitSim(v >> 1)
        if (v >> 48) == 0x0101:
            self.console.append(v & 0xFF)
        else:
            raise ExitSim(0x1000)
        o = self.tohost - self.ram_base
        self.ram[o:o + 8] = bytes(8)


def load_flat(bus, binpath, sympath=None, base=0x8000_0000):
    """Carga un binario plano de rv128asm.py en base; devuelve (entry, simbolos)."""
    data = open(binpath, 'rb').read()
    o = base - bus.ram_base
    bus.ram[o:o + len(data)] = data
    syms = {}
    if sympath:
        for line in open(sympath):
            a, n = line.split()
            syms[n] = int(a, 16)
    if 'tohost' in syms:
        bus.tohost = syms['tohost']
    return base, syms


# ---------------------------------------------------------------- RVC (RV128C)
def _i(op, rd, f3, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def _s(op, f3, rs1, rs2, imm):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 31) << 7) | op


def _b(f3, rs1, rs2, imm):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
        (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63


def _j(rd, imm):
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | \
        (((imm >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F


def _r(op, rd, f3, rs1, rs2, f7):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def expand_c(c):
    """Expande una media palabra RV128C a 32 bit. None si es reservada/ilegal."""
    def b(hi, lo):
        return (c >> lo) & ((1 << (hi - lo + 1)) - 1)
    q, f3 = c & 3, b(15, 13)
    rd, rs2 = b(11, 7), b(6, 2)
    rdp, rs2p = 8 + b(9, 7), 8 + b(4, 2)
    imm6 = sx((b(12, 12) << 5) | b(6, 2), 6)
    f = (b(12, 12) << 5) | b(6, 2)
    shl = 64 if f == 0 else f
    shr = 64 if f == 0 else (sx(f, 6) & 127)
    if c == 0:
        return None
    if q == 0:
        if f3 == 0:
            u = (b(10, 7) << 6) | (b(12, 11) << 4) | (b(5, 5) << 3) | (b(6, 6) << 2)
            return None if u == 0 else _i(0x13, rs2p, 0, 2, u)
        if f3 in (1, 5):                                     # c.lq / c.sq
            u = (b(10, 10) << 8) | (b(6, 5) << 6) | (b(12, 11) << 4)
            return _i(0x0F, rs2p, 2, rdp, u) if f3 == 1 else _s(0x23, 4, rdp, rs2p, u)
        if f3 in (2, 6):
            u = (b(5, 5) << 6) | (b(12, 10) << 3) | (b(6, 6) << 2)
            return _i(0x03, rs2p, 2, rdp, u) if f3 == 2 else _s(0x23, 2, rdp, rs2p, u)
        if f3 in (3, 7):
            u = (b(6, 5) << 6) | (b(12, 10) << 3)
            return _i(0x03, rs2p, 3, rdp, u) if f3 == 3 else _s(0x23, 3, rdp, rs2p, u)
        return None
    if q == 1:
        if f3 == 0:
            return _i(0x13, rd, 0, rd, imm6)
        if f3 == 1:
            return None if rd == 0 else _i(0x1B, rd, 0, rd, imm6)
        if f3 == 2:
            return _i(0x13, rd, 0, 0, imm6)
        if f3 == 3:
            if rd == 2:
                u = sx((b(12, 12) << 9) | (b(4, 3) << 7) | (b(5, 5) << 6) | (b(2, 2) << 5) | (b(6, 6) << 4), 10)
                return None if u == 0 else _i(0x13, 2, 0, 2, u)
            if f == 0:
                return None
            return ((imm6 & 0xFFFFF) << 12) | (rd << 7) | 0x37
        if f3 == 4:
            f2 = b(11, 10)
            if f2 == 0:
                return (shr << 20) | (rdp << 15) | (5 << 12) | (rdp << 7) | 0x13
            if f2 == 1:
                return (0x08 << 27) | (shr << 20) | (rdp << 15) | (5 << 12) | (rdp << 7) | 0x13
            if f2 == 2:
                return _i(0x13, rdp, 7, rdp, imm6)
            g = b(6, 5)
            if b(12, 12) == 0:
                f3_, f7 = ((0, 0x20), (4, 0), (6, 0), (7, 0))[g]
                return _r(0x33, rdp, f3_, rdp, rs2p, f7)
            if g == 0:
                return _r(0x3B, rdp, 0, rdp, rs2p, 0x20)
            if g == 1:
                return _r(0x3B, rdp, 0, rdp, rs2p, 0)
            return None
        if f3 == 5:
            off = sx((b(12, 12) << 11) | (b(8, 8) << 10) | (b(10, 9) << 8) | (b(6, 6) << 7) | (b(7, 7) << 6) |
                     (b(2, 2) << 5) | (b(11, 11) << 4) | (b(5, 3) << 1), 12)
            return _j(0, off)
        off = sx((b(12, 12) << 8) | (b(6, 5) << 6) | (b(2, 2) << 5) | (b(11, 10) << 3) | (b(4, 3) << 1), 9)
        return _b(0 if f3 == 6 else 1, rdp, 0, off)
    if q == 2:
        if f3 == 0:
            return (shl << 20) | (rd << 15) | (1 << 12) | (rd << 7) | 0x13
        if f3 == 1:                                          # c.lqsp
            u = (b(5, 2) << 6) | (b(12, 12) << 5) | (b(6, 6) << 4)
            return None if rd == 0 else _i(0x0F, rd, 2, 2, u)
        if f3 == 2:
            u = (b(3, 2) << 6) | (b(12, 12) << 5) | (b(6, 4) << 2)
            return None if rd == 0 else _i(0x03, rd, 2, 2, u)
        if f3 == 3:
            u = (b(4, 2) << 6) | (b(12, 12) << 5) | (b(6, 5) << 3)
            return None if rd == 0 else _i(0x03, rd, 3, 2, u)
        if f3 == 4:
            if b(12, 12) == 0:
                if rs2 == 0:
                    return None if rd == 0 else _i(0x67, 0, 0, rd, 0)
                return _r(0x33, rd, 0, 0, rs2, 0)
            if rs2 == 0:
                return 0x00100073 if rd == 0 else _i(0x67, 1, 0, rd, 0)
            return _r(0x33, rd, 0, rd, rs2, 0)
        if f3 == 5:                                          # c.sqsp
            u = (b(10, 7) << 6) | (b(12, 11) << 4)
            return _s(0x23, 4, 2, rs2, u)
        if f3 == 6:
            u = (b(8, 7) << 6) | (b(12, 9) << 2)
            return _s(0x23, 2, 2, rs2, u)
        u = (b(9, 7) << 6) | (b(12, 10) << 3)
        return _s(0x23, 3, 2, rs2, u)
    return None


# ---------------------------------------------------------------- M
def rotr(a, n, w):
    """rotacion a la derecha de los w bits bajos de a"""
    m = (1 << w) - 1
    a &= m
    n %= w
    return ((a >> n) | (a << (w - n))) & m


def clmul(a, b):
    """producto sin acarreo de 128 x 128 -> 256 bits"""
    r = 0
    a &= MX
    b &= MX
    while b:
        lo = b & -b
        r ^= a << (lo.bit_length() - 1)
        b ^= lo
    return r


def muldiv(f3, a, b, w):
    """Unidad M a anchura w (128, 64, 32). Resultado extendido en signo a 128."""
    m = (1 << w) - 1
    if f3 == 0:
        return sx(a * b, w)
    if f3 in (1, 2, 3):                                     # solo w == 128
        sa, sb = s128(a), s128(b)
        if f3 == 1: return (sa * sb) >> 128
        if f3 == 2: return (sa * b) >> 128
        return (a * b) >> 128
    signed = f3 in (4, 6)
    if signed:
        x, y = sx(a, w), sx(b, w)
    else:
        x, y = a & m, b & m
    if f3 in (4, 5):
        if y == 0:
            return -1
        if signed and x == -(1 << (w - 1)) and y == -1:
            return x
        q = abs(x) // abs(y)
        return sx(-q if (x < 0) != (y < 0) else q, w)
    if y == 0:
        return sx(x, w)
    if signed and x == -(1 << (w - 1)) and y == -1:
        return 0
    r = abs(x) % abs(y)
    return sx(-r if x < 0 else r, w)


class Hart:
    def __init__(self, bus, pc=0x8000_0000, time_div=1):
        self.bus = bus
        self.x = [0] * 32
        self.pc = pc
        self.priv = PRV_M
        self.zb = True                                   # Zbb + Zbc (extension RV128 de este core)
        self.time_div = time_div
        self.steps = 0
        self.mstatus = MS_UXL_SXL
        self.medeleg = self.mideleg = 0
        self.mie = self.mip_sw = 0
        self.mtvec = self.stvec = 0
        self.mscratch = self.sscratch = 0
        self.mepc = self.sepc = 0
        self.mcause = self.scause = 0
        self.mtval = self.stval = 0
        self.mcounteren = self.scounteren = 0
        self.mcountinhibit = 0
        self.menvcfg = self.senvcfg = 0
        self.mcycle = self.minstret = 0
        self.meip = self.seip_hw = 0
        self.resv = None                     # linea reservada (pa >> 6)
        self.irq_forced = False              # lockstep: solo irq que dicte el RTL
        self.wlog = None                     # ultima escritura del paso: (pa, bytes, valor)
        self.mip_hw = None                   # lockstep: lineas dictadas por el RTL
        self._instret_written = False

    # ------------------------------------------------ interrupciones
    def mip(self):
        if self.mip_hw is not None:
            return (self.mip_sw & S_INTS) | (self.mip_hw & (MSIP | MTIP | MEIP | SEIP))
        v = self.mip_sw & S_INTS
        if self.seip_hw:
            v |= SEIP
        if self.bus.msip:
            v |= MSIP
        if self.bus.mtime >= self.bus.mtimecmp:
            v |= MTIP
        if self.meip:
            v |= MEIP
        return v

    def pending_irq(self):
        pend = self.mip() & self.mie
        if not pend:
            return None
        m_en = self.priv < PRV_M or (self.mstatus & MS_MIE)
        s_en = self.priv < PRV_S or (self.priv == PRV_S and (self.mstatus & MS_SIE))
        m_pend = pend & ~self.mideleg
        s_pend = pend & self.mideleg
        for cause in IRQ_PRIO:
            if m_en and (m_pend >> cause) & 1:
                return cause
        for cause in IRQ_PRIO:
            if s_en and (s_pend >> cause) & 1 and self.priv <= PRV_S:
                return cause
        return None

    def take_trap(self, cause, tval, is_irq):
        self.resv = None
        deleg = self.mideleg if is_irq else self.medeleg
        cause_v = (IRQ_BIT | cause) if is_irq else cause
        tval &= MX
        if self.priv <= PRV_S and (deleg >> cause) & 1:
            self.sepc, self.scause, self.stval = self.pc, cause_v, tval
            ms = self.mstatus
            ms = (ms & ~MS_SPIE) | (MS_SPIE if ms & MS_SIE else 0)
            ms = (ms & ~MS_SPP) | (MS_SPP if self.priv == PRV_S else 0)
            self.mstatus = ms & ~MS_SIE
            self.priv = PRV_S
            base, mode = self.stvec & ~3, self.stvec & 1
        else:
            self.mepc, self.mcause, self.mtval = self.pc, cause_v, tval
            ms = self.mstatus
            ms = (ms & ~MS_MPIE) | (MS_MPIE if ms & MS_MIE else 0)
            ms = (ms & ~(3 << MS_MPP_SH)) | (self.priv << MS_MPP_SH)
            self.mstatus = ms & ~MS_MIE
            self.priv = PRV_M
            base, mode = self.mtvec & ~3, self.mtvec & 1
        self.pc = (base + 4 * cause) & MX if (is_irq and mode) else base & MX

    # ------------------------------------------------ memoria (paginacion Bare)
    def mem_load(self, a, size):
        if a & (size - 1):
            raise Trap(EXC_LMISALIGN, a)
        try:
            return self.bus.load(a, size)
        except AccessFault:
            raise Trap(EXC_LACCESS, a)

    def mem_store(self, a, size, val):
        if a & (size - 1):
            raise Trap(EXC_SMISALIGN, a)
        try:
            self.bus.store(a, size, val)
        except AccessFault:
            raise Trap(EXC_SACCESS, a)
        self.wlog = (a, size, val & ((1 << (8 * size)) - 1))

    def fetch16(self, a):
        if not (self.bus.in_ram(a, 2) or self.bus.in_rom(a, 2)):
            raise Trap(EXC_IACCESS, a)
        return self.bus.load(a, 2)

    # ------------------------------------------------ CSRs (como iss64.py)
    def csr_read(self, a):
        p = self.priv
        if ((a >> 8) & 3) > p:
            raise Trap(EXC_ILLEGAL)
        if 0xC00 <= a <= 0xC1F:
            bit = 1 << (a & 31)
            if (p < PRV_M and not self.mcounteren & bit) or (p == PRV_U and not self.scounteren & bit):
                raise Trap(EXC_ILLEGAL)
            return (self.mcycle, self.bus.mtime, self.minstret)[a & 31] if (a & 31) < 3 else 0
        if a == 0x300: return self.mstatus
        if a == 0x301: return MISA
        if a == 0x302: return self.medeleg
        if a == 0x303: return self.mideleg
        if a == 0x304: return self.mie
        if a == 0x305: return self.mtvec
        if a == 0x306: return self.mcounteren
        if a == 0x30A: return self.menvcfg
        if a == 0x320: return self.mcountinhibit
        if 0x323 <= a <= 0x33F: return 0
        if a == 0x340: return self.mscratch
        if a == 0x341: return self.mepc
        if a == 0x342: return self.mcause
        if a == 0x343: return self.mtval
        if a == 0x344: return self.mip()
        if 0x3A0 <= a <= 0x3AF:
            if a & 1:
                raise Trap(EXC_ILLEGAL)
            return 0
        if 0x3B0 <= a <= 0x3EF: return 0
        if 0x7A0 <= a <= 0x7A3: return 0
        if a == 0xB00: return self.mcycle
        if a == 0xB02: return self.minstret
        if 0xB03 <= a <= 0xB1F: return 0
        if a in (0xF11, 0xF12, 0xF13, 0xF14, 0xF15): return 0
        if a == 0x100: return self.mstatus & SSTATUS_MASK
        if a == 0x104: return self.mie & self.mideleg
        if a == 0x105: return self.stvec
        if a == 0x106: return self.scounteren
        if a == 0x10A: return self.senvcfg
        if a == 0x140: return self.sscratch
        if a == 0x141: return self.sepc
        if a == 0x142: return self.scause
        if a == 0x143: return self.stval
        if a == 0x144: return self.mip() & self.mideleg
        if a == 0x180:
            if p == PRV_S and self.mstatus & MS_TVM:
                raise Trap(EXC_ILLEGAL)
            return 0                                      # RV128: solo Bare
        raise Trap(EXC_ILLEGAL)

    def csr_write(self, a, v):
        v &= MX
        if (a >> 10) == 3:
            raise Trap(EXC_ILLEGAL)
        if a == 0x300:
            old_mpp = (self.mstatus >> MS_MPP_SH) & 3
            ms = (self.mstatus & ~MSTATUS_WMASK) | (v & MSTATUS_WMASK)
            if ((ms >> MS_MPP_SH) & 3) == 2:
                ms = (ms & ~(3 << MS_MPP_SH)) | (old_mpp << MS_MPP_SH)
            self.mstatus = ms
        elif a == 0x301: pass
        elif a == 0x302: self.medeleg = v & MEDELEG_MASK
        elif a == 0x303: self.mideleg = v & S_INTS
        elif a == 0x304: self.mie = v & ALL_INTS
        elif a == 0x305: self.mtvec = self._tvec(v)
        elif a == 0x306: self.mcounteren = v & M32
        elif a == 0x30A: self.menvcfg = self._envcfg(v)
        elif a == 0x320: self.mcountinhibit = v & 5
        elif 0x323 <= a <= 0x33F: pass
        elif a == 0x340: self.mscratch = v
        elif a == 0x341: self.mepc = v & ~1
        elif a == 0x342: self.mcause = v
        elif a == 0x343: self.mtval = v
        elif a == 0x344: self.mip_sw = (self.mip_sw & ~S_INTS) | (v & S_INTS)
        elif 0x3A0 <= a <= 0x3EF: pass
        elif 0x7A0 <= a <= 0x7A3: pass
        elif a == 0xB00: self.mcycle = v & M64
        elif a == 0xB02:
            self.minstret = v & M64
            self._instret_written = True
        elif 0xB03 <= a <= 0xB1F: pass
        elif a == 0x100:
            self.mstatus = (self.mstatus & ~SSTATUS_WMASK) | (v & SSTATUS_WMASK)
        elif a == 0x104:
            self.mie = (self.mie & ~self.mideleg) | (v & self.mideleg)
        elif a == 0x105: self.stvec = self._tvec(v)
        elif a == 0x106: self.scounteren = v & M32
        elif a == 0x10A: self.senvcfg = self._envcfg(v)
        elif a == 0x140: self.sscratch = v
        elif a == 0x141: self.sepc = v & ~1
        elif a == 0x142: self.scause = v
        elif a == 0x143: self.stval = v
        elif a == 0x144:
            m = self.mideleg & SSIP
            self.mip_sw = (self.mip_sw & ~m) | (v & m)
        elif a == 0x180:
            pass                                          # RV128: satp fijo a 0 (Bare)
        else:
            raise Trap(EXC_ILLEGAL)

    @staticmethod
    def _envcfg(v):
        v &= 0x71
        if (v >> 4) & 3 == 2:
            v &= ~0x30
        return v

    @staticmethod
    def _tvec(v):
        return (v & ~3 & MX) | (v & 1)

    # ------------------------------------------------ paso
    def step(self, force_irq=None):
        """Ejecuta un paso. Devuelve (pc, insn, rd, valor, trap) con trap None o
        (causa_completa, tval). rd=0 significa sin escritura."""
        self.steps += 1
        if self.steps % self.time_div == 0:
            self.bus.mtime = (self.bus.mtime + 1) & M64
        if not self.mcountinhibit & 1:
            self.mcycle = (self.mcycle + 1) & M64
        irq = force_irq if self.irq_forced else self.pending_irq()
        pc = self.pc
        if irq is not None:
            self.wlog = None
            self.take_trap(irq, 0, True)
            return (pc, 0, 0, 0, (IRQ_BIT | irq, 0))
        insn = 0
        try:
            lo = self.fetch16(pc)
            if lo & 3 == 3:
                try:
                    hi = self.fetch16((pc + 2) & MX)
                except Trap as t:
                    t.tval = (pc + 2) & MX
                    raise
                insn = lo | (hi << 16)
                ilen, ex = 4, insn
            else:
                insn, ilen = lo, 2
                ex = expand_c(lo)
                if ex is None:
                    raise Trap(EXC_ILLEGAL, lo)
            self._instret_written = False
            self.wlog = None
            rd, val = self.execute(ex, insn, ilen)
        except Trap as t:
            self.pc = pc
            self.wlog = None
            self.take_trap(t.cause, t.tval, False)
            return (pc, insn, 0, 0, (t.cause, t.tval))
        if rd:
            self.x[rd] = val & MX
        if not (self.mcountinhibit & 4) and not self._instret_written:
            self.minstret = (self.minstret + 1) & M64
        return (pc, insn, rd, val & MX if rd else 0, None)

    # ------------------------------------------------ ejecucion
    def execute(self, i, raw, ilen):
        x = self.x
        op = i & 0x7F
        rd = (i >> 7) & 31
        f3 = (i >> 12) & 7
        rs1 = (i >> 15) & 31
        rs2 = (i >> 20) & 31
        f7 = i >> 25
        a, b = x[rs1], x[rs2]
        pc = self.pc
        npc = (pc + ilen) & MX
        ill = Trap(EXC_ILLEGAL, raw)
        res = None
        imm = sx(i >> 20, 12)

        if op == 0x37:                                   # LUI
            res = sx(i & 0xFFFFF000, 32)
        elif op == 0x17:                                 # AUIPC
            res = pc + sx(i & 0xFFFFF000, 32)
        elif op == 0x6F:                                 # JAL
            j = sx(((i >> 11) & 0x100000) | (i & 0xFF000) | ((i >> 9) & 0x800) | ((i >> 20) & 0x7FE), 21)
            res, npc = pc + ilen, (pc + j) & MX
        elif op == 0x67:                                 # JALR
            if f3:
                raise ill
            res, npc = pc + ilen, (a + imm) & MX & ~1
        elif op == 0x63:                                 # BRANCH
            bo = sx(((i >> 19) & 0x1000) | ((i << 4) & 0x800) | ((i >> 20) & 0x7E0) | ((i >> 7) & 0x1E), 13)
            if f3 == 0: t = a == b
            elif f3 == 1: t = a != b
            elif f3 == 4: t = s128(a) < s128(b)
            elif f3 == 5: t = s128(a) >= s128(b)
            elif f3 == 6: t = a < b
            elif f3 == 7: t = a >= b
            else: raise ill
            if t:
                npc = (pc + bo) & MX
            rd = 0
        elif op == 0x03:                                 # LOAD (f3=7: LDU)
            size = 1 << (f3 & 3)
            v = self.mem_load((a + imm) & MX, size)
            res = v if f3 & 4 else sx(v, 8 * size)
        elif op == 0x23:                                 # STORE (f3=4: SQ)
            if f3 > 4:
                raise ill
            simm = sx(((i >> 20) & 0xFE0) | ((i >> 7) & 31), 12)
            self.mem_store((a + simm) & MX, 1 << f3, b)
            rd = 0
        elif op in (0x13, 0x1B, 0x5B):                   # OP-IMM / -32 / -64
            w = {0x13: 128, 0x1B: 32, 0x5B: 64}[op]
            shb = {128: 7, 32: 5, 64: 6}[w]
            sh, hi = (i >> 20) & ((1 << shb) - 1), i >> (20 + shb)
            sra_hi = 0x20 >> (shb - 5)                   # bit 30 en el campo alto
            i12 = i >> 20
            ror_hi = 0x30 >> (shb - 5)                   # rori/roriw/rorid: 0110000 / 011000 / 01100
            if f3 == 0:
                res = sx(a + imm, w)
            elif f3 == 1:
                if hi == 0:
                    res = sx(a << sh, w)
                elif self.zb and i12 in (0x600, 0x601, 0x602):          # clz / ctz / cpop (W, D)
                    v = a & ((1 << w) - 1)
                    if i12 == 0x600: res = w - v.bit_length()
                    elif i12 == 0x601: res = (v & -v).bit_length() - 1 if v else w
                    else: res = bin(v).count('1')
                elif self.zb and w == 128 and i12 == 0x604: res = sx(a, 8)   # sext.b
                elif self.zb and w == 128 and i12 == 0x605: res = sx(a, 16)  # sext.h
                else: raise ill
            elif f3 == 5:
                if hi == 0: res = sx((a & ((1 << w) - 1)) >> sh, w)
                elif hi == sra_hi: res = sx(a, w) >> sh
                elif self.zb and hi == ror_hi: res = sx(rotr(a, sh, w), w)  # rori / roriw / rorid
                elif self.zb and w == 128 and i12 == 0x6F8:                 # rev8 (16 bytes)
                    res = int.from_bytes((a & MX).to_bytes(16, 'little'), 'big')
                elif self.zb and w == 128 and i12 == 0x287:                 # orc.b
                    res = sum(0xFF << (8 * k) for k in range(16) if (a >> (8 * k)) & 0xFF)
                else: raise ill
            elif w != 128:
                raise ill
            elif f3 == 2: res = int(s128(a) < imm)
            elif f3 == 3: res = int(a < (imm & MX))
            elif f3 == 4: res = a ^ imm
            elif f3 == 6: res = a | imm
            else: res = a & imm
        elif op in (0x33, 0x3B, 0x7B):                   # OP / OP-32 / OP-64
            w = {0x33: 128, 0x3B: 32, 0x7B: 64}[op]
            m = (1 << w) - 1
            shm = w - 1
            if f7 == 1:
                if w != 128 and f3 in (1, 2, 3):
                    raise ill
                res = muldiv(f3, a, b, w)
            elif f7 == 0 and f3 == 0: res = sx(a + b, w)
            elif f7 == 0x20 and f3 == 0: res = sx(a - b, w)
            elif f7 == 0 and f3 == 1: res = sx(a << (b & shm), w)
            elif f7 == 0 and f3 == 5: res = sx((a & m) >> (b & shm), w)
            elif f7 == 0x20 and f3 == 5: res = sx(a, w) >> (b & shm)
            elif f7 == 0 and w == 128:
                res = {2: int(s128(a) < s128(b)), 3: int(a < b), 4: a ^ b, 6: a | b, 7: a & b}[f3]
            elif self.zb and f7 == 0x20 and w == 128 and f3 in (4, 6, 7):     # xnor / orn / andn
                res = {4: ~(a ^ b), 6: a | ~b, 7: a & ~b}[f3]
            elif self.zb and f7 == 0x30 and f3 in (1, 5):                    # rol / ror (W, D)
                r = (b & shm)
                res = sx(rotr(a, (w - r) % w, w) if f3 == 1 else rotr(a, r, w), w)
            elif self.zb and f7 == 0x05 and w == 128 and f3 >= 4:           # min / minu / max / maxu
                res = {4: min(s128(a), s128(b)), 5: min(a, b), 6: max(s128(a), s128(b)), 7: max(a, b)}[f3]
            elif self.zb and f7 == 0x05 and w == 128 and f3 in (1, 2, 3):   # clmul / clmulr / clmulh
                p = clmul(a, b)
                res = {1: p, 2: p >> 127, 3: p >> 128}[f3]
            elif self.zb and f7 == 0x04 and w == 64 and f3 == 4 and rs2 == 0:   # zext.h (RV128: OP-64)
                res = a & 0xFFFF
            else:
                raise ill
        elif op == 0x2F:                                 # AMO
            res = self._amo(i, f3, a, b, ill)
        elif op == 0x0F:                                 # MISC-MEM
            if f3 == 2:                                  # LQ
                res = self.mem_load((a + imm) & MX, 16)
            elif f3 in (0, 1):
                rd = 0                                   # fence / fence.i
            else:
                raise ill
        elif op == 0x73:                                 # SYSTEM
            res, npc, rd = self._system(i, raw, f3, rd, rs1, a, npc, ill)
        else:
            raise ill

        self.pc = npc
        if res is None or rd == 0:
            return 0, 0
        return rd, res & MX

    def _amo(self, i, f3, a, b, ill):
        if f3 not in (2, 3, 4):
            raise ill
        size = 1 << f3
        bits = 8 * size
        f5 = i >> 27
        if f5 == 2:                                       # LR
            if (i >> 20) & 31:
                raise ill
            if a & (size - 1):
                raise Trap(EXC_LMISALIGN, a)
            if not self.bus.in_ram(a, size):
                raise Trap(EXC_LACCESS, a)
            v = self.mem_load(a, size)
            self.resv = a >> 6
            return sx(v, bits)
        if f5 == 3:                                       # SC
            if a & (size - 1):
                raise Trap(EXC_SMISALIGN, a)
            if not self.bus.in_ram(a, size):
                raise Trap(EXC_SACCESS, a)
            ok = self.resv is not None and self.resv == a >> 6
            self.resv = None
            if not ok:
                return 1
            self.mem_store(a, size, b)
            return 0
        if f5 not in (0, 1, 4, 8, 12, 16, 20, 24, 28):
            raise ill
        if a & (size - 1):
            raise Trap(EXC_SMISALIGN, a)
        if not self.bus.in_ram(a, size):
            raise Trap(EXC_SACCESS, a)
        old = self.bus.load(a, size)
        so, sb = sx(old, bits), sx(b, bits)
        ub = b & ((1 << bits) - 1)
        new = {0: old + b, 1: b, 4: old ^ b, 8: old | b, 12: old & b,
               16: min(so, sb), 20: max(so, sb), 24: min(old, ub), 28: max(old, ub)}[f5]
        self.mem_store(a, size, new)
        return so

    def _system(self, i, raw, f3, rd, rs1, a, npc, ill):
        p = self.priv
        if f3 == 0:
            if rd != 0:
                raise ill
            f7 = i >> 25
            if i == 0x00000073:
                raise Trap((EXC_ECALL_U, EXC_ECALL_S, None, EXC_ECALL_M)[p])
            if i == 0x00100073:
                raise Trap(EXC_BREAK, self.pc)
            if i == 0x30200073:                             # MRET
                if p != PRV_M:
                    raise ill
                ms = self.mstatus
                mpp = (ms >> MS_MPP_SH) & 3
                ms = (ms & ~MS_MIE) | (MS_MIE if ms & MS_MPIE else 0)
                ms = (ms | MS_MPIE) & ~(3 << MS_MPP_SH)
                if mpp != PRV_M:
                    ms &= ~MS_MPRV
                self.mstatus, self.priv = ms, mpp
                return None, self.mepc, 0
            if i == 0x10200073:                             # SRET
                if p == PRV_U or (p == PRV_S and self.mstatus & MS_TSR):
                    raise ill
                ms = self.mstatus
                spp = PRV_S if ms & MS_SPP else PRV_U
                ms = (ms & ~MS_SIE) | (MS_SIE if ms & MS_SPIE else 0)
                ms = (ms | MS_SPIE) & ~MS_SPP & ~MS_MPRV
                self.mstatus, self.priv = ms, spp
                return None, self.sepc, 0
            if i == 0x10500073:                             # WFI
                if p == PRV_U or (p == PRV_S and self.mstatus & MS_TW):
                    raise ill
                return None, npc, 0
            if f7 == 0x09:                                  # SFENCE.VMA
                if p == PRV_U or (p == PRV_S and self.mstatus & MS_TVM):
                    raise ill
                return None, npc, 0
            raise ill
        if f3 == 4:
            raise ill
        csr = i >> 20
        src = rs1 if f3 & 4 else a
        op = f3 & 3
        writes = op == 1 or rs1 != 0
        if (csr >> 10) == 3 and writes:
            raise ill
        try:
            old = self.csr_read(csr)
        except Trap:
            raise ill
        if op == 1:
            new = src
        elif op == 2:
            new = old | src
        else:
            new = old & ~src
        if writes:
            try:
                self.csr_write(csr, new)
            except Trap:
                raise ill
        return old, npc, rd


# ---------------------------------------------------------------- CLI
def run_flat(binpath, sympath, max_steps=5_000_000, trace=None):
    bus = Bus()
    entry, _ = load_flat(bus, binpath, sympath)
    h = Hart(bus, pc=entry)
    try:
        for _ in range(max_steps):
            r = h.step()
            if trace:
                trace(h, r)
    except ExitSim as e:
        return e.code, h
    return None, h


def main():
    import argparse
    ap = argparse.ArgumentParser(description='ISS RV128IMAC: ejecuta programas de rv128asm.py')
    ap.add_argument('prog', nargs='+', help='prefijo: se usan <prog>.bin y <prog>.sym')
    ap.add_argument('--trace', action='store_true')
    ap.add_argument('--max', type=int, default=5_000_000)
    a = ap.parse_args()
    fails = 0

    def tr(h, r):
        pc, insn, rd, val, trap = r
        t = f' T {trap[0]:x} {trap[1]:x}' if trap else ''
        print(f'{pc:032x} {insn:08x} {rd:2d} {val:032x}{t}')
    for p in a.prog:
        code, h = run_flat(p + '.bin', p + '.sym', a.max, tr if a.trace else None)
        out = bytes(h.bus.uart_out + h.bus.console).decode(errors='replace')
        if out:
            sys.stdout.write(out)
        verdict = 'PASS' if code == 0 else ('TIMEOUT' if code is None else f'FAIL({code})')
        if code != 0:
            fails += 1
        print(f'{verdict:8} {p}  retiros={h.minstret}')
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
