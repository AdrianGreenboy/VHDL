#!/usr/bin/env python3
"""iss64.py - ISS de referencia RV64IMAC_Zicsr_Zifencei, M/S/U, Sv39 (Svade).

Oraculo del core RV64IMAC (SPEC_FREEZE_V1.md). Escrito antes del RTL para
que no herede sus suposiciones. Cada step() devuelve un registro de retiro
que el comparador lockstep usa contra la traza del RTL.

Decisiones de implementacion (deben coincidir con el RTL; ver spec):
  * misa fijo (RV64 ACIMSU), escrituras ignoradas.
  * PMP con 0 entradas: pmpcfg/pmpaddr leen 0, escrituras ignoradas.
  * Triggers: tselect/tdata1..3 leen 0, escrituras ignoradas.
  * Desalineados -> excepcion 4/6 antes de traducir.
  * Sv39 Svade: A=0, o D=0 en store/AMO -> page fault. Sin TLB en el ISS.
  * Reserva LR/SC con granularidad de linea de 64 B; se borra en cualquier
    SC y en cualquier trap.
  * mtval: instruccion ilegal -> sus bits; ebreak -> pc; fallos de
    memoria -> direccion virtual del byte que falla; ecall/irq -> 0.
  * wfi se ejecuta como nop (legal); el RTL para el reloj, misma arquitectura.
  * mstatus.MPP escrito con 2 (reservado) conserva el valor anterior.
  * PMA: solo la DRAM es ejecutable y admite atomicos. LR/SC/AMO fuera de
    DRAM -> access fault (5 para LR, 7 para SC/AMO), comprobado ANTES de
    mirar la reserva. Fetch fuera de DRAM -> instruction access fault.
"""
import gc
import struct
import sys

M64 = (1 << 64) - 1
M32 = (1 << 32) - 1


def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def s64(v):
    return sx(v, 64)


# Causas
EXC_IMISALIGN, EXC_IACCESS, EXC_ILLEGAL, EXC_BREAK = 0, 1, 2, 3
EXC_LMISALIGN, EXC_LACCESS, EXC_SMISALIGN, EXC_SACCESS = 4, 5, 6, 7
EXC_ECALL_U, EXC_ECALL_S, EXC_ECALL_M = 8, 9, 11
EXC_IPAGE, EXC_LPAGE, EXC_SPAGE = 12, 13, 15
IRQ_BIT = 1 << 63

PRV_U, PRV_S, PRV_M = 0, 1, 3
FETCH, LOAD, STORE = 0, 1, 2

# mstatus
MS_SIE, MS_MIE, MS_SPIE, MS_MPIE = 1 << 1, 1 << 3, 1 << 5, 1 << 7
MS_SPP = 1 << 8
MS_MPP_SH = 11
MS_MPRV, MS_SUM, MS_MXR = 1 << 17, 1 << 18, 1 << 19
MS_TVM, MS_TW, MS_TSR = 1 << 20, 1 << 21, 1 << 22
MS_UXL_SXL = (2 << 32) | (2 << 34)
MSTATUS_WMASK = (MS_SIE | MS_MIE | MS_SPIE | MS_MPIE | MS_SPP | (3 << MS_MPP_SH)
                 | MS_MPRV | MS_SUM | MS_MXR | MS_TVM | MS_TW | MS_TSR)
SSTATUS_MASK = MS_SIE | MS_SPIE | MS_SPP | MS_SUM | MS_MXR | (3 << 32)
SSTATUS_WMASK = MS_SIE | MS_SPIE | MS_SPP | MS_SUM | MS_MXR

MISA = (2 << 62) | (1 << 0) | (1 << 2) | (1 << 8) | (1 << 12) | (1 << 18) | (1 << 20)

# mip/mie
SSIP, MSIP, STIP, MTIP, SEIP, MEIP = 1 << 1, 1 << 3, 1 << 5, 1 << 7, 1 << 9, 1 << 11
S_INTS = SSIP | STIP | SEIP
ALL_INTS = S_INTS | MSIP | MTIP | MEIP
IRQ_PRIO = (11, 3, 7, 9, 1, 5)          # MEI MSI MTI SEI SSI STI
# bit 0 (fetch desalineado) solo lectura a cero: con C nunca ocurre (spec: "should")
MEDELEG_MASK = sum(1 << b for b in (1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 13, 15))

# Mapa fisico (SPEC_FREEZE_V1 sec. 7)
ROM_BASE, ROM_SIZE = 0x0000_1000, 0x1000
CLINT_BASE, CLINT_SIZE = 0x0200_0000, 0x1_0000
PLIC_BASE, PLIC_SIZE = 0x0C00_0000, 0x400_0000
UART_BASE, UART_SIZE = 0x1000_0000, 0x1000
MMIO_BASE, MMIO_SIZE = 0x1001_0000, 0x10_0000        # 16 ranuras de IP_Cores
AXIL_BASE, AXIL_SIZE = 0x2000_0000, 0x1000_0000      # ventana AXI4-Lite
# Dispositivos cuyo estado no modela el ISS: sus lecturas las dicta el RTL (lockstep)
STUB_REGIONS = ((PLIC_BASE, PLIC_SIZE, (4,)), (MMIO_BASE, MMIO_SIZE, (1, 2, 4, 8)),
                (AXIL_BASE, AXIL_SIZE, (1, 2, 4, 8)))


class Trap(Exception):
    def __init__(self, cause, tval=0):
        super().__init__(cause, tval)
        self.cause = cause
        self.tval = tval & M64


class AccessFault(Exception):
    pass


class ExitSim(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


# ---------------------------------------------------------------- memoria
class Bus:
    """Mapa fisico: RAM + CLINT + UART + hook tohost (riscv-tests)."""

    def __init__(self, ram_base=0x8000_0000, ram_size=64 << 20):
        self.ram_base = ram_base
        self.ram = bytearray(ram_size)
        self.ram_end = ram_base + ram_size
        self.rom = None                       # (base, bytes) boot ROM, Paso 7
        self.tohost = None
        self.fromhost = None
        self.console = []
        # CLINT
        self.msip = 0
        self.mtimecmp = M64
        self.mtime = 0
        # UART
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
            return self._uart_rd(pa - UART_BASE)
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

    # --- CLINT: msip 0x0, mtimecmp 0x4000, mtime 0xBFF8
    def _clint_rd(self, off, size):
        regs = {0x0: self.msip, 0x4000: self.mtimecmp, 0xBFF8: self.mtime}
        base = off & ~7
        if base in regs:
            v = regs[base]
            return (v >> (8 * (off & 7))) & ((1 << (8 * size)) - 1)
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

    def _uart_rd(self, off):
        return 0x60 if off == 5 else 0      # LSR: THR vacio

    # --- protocolo HTIF de riscv-tests
    def _tohost(self):
        v = self.load(self.tohost, 8)
        if v == 0:
            return
        if (v >> 48) == 0 and v & 1:
            raise ExitSim(v >> 1)
        if (v >> 48) == 0x0101:              # putchar
            self.console.append(v & 0xFF)
        else:                                # syscall struct (write)
            n, a0, a1, a2 = (self.load(v + 8 * i, 8) for i in range(4))
            if n == 64:
                self.console.extend(self.ram[a1 - self.ram_base:a1 - self.ram_base + a2])
            else:
                raise ExitSim(0x1000 | n)
        self.store_raw(self.tohost, 8, 0)
        if self.fromhost is not None:
            self.store_raw(self.fromhost, 8, 1)

    def store_raw(self, pa, size, val):
        o = pa - self.ram_base
        self.ram[o:o + size] = (val & ((1 << (8 * size)) - 1)).to_bytes(size, 'little')


# ---------------------------------------------------------------- ELF
def load_elf(bus, path):
    data = open(path, 'rb').read()
    assert data[:4] == b'\x7fELF' and data[4] == 2, 'ELF64 requerido'
    (entry, phoff, shoff) = struct.unpack_from('<QQQ', data, 24)
    phentsize, phnum, shentsize, shnum, shstrndx = struct.unpack_from('<HHHHH', data, 54)
    for i in range(phnum):
        p_type, _, off, vaddr, paddr, filesz, memsz, _ = struct.unpack_from(
            '<IIQQQQQQ', data, phoff + i * phentsize)
        if p_type == 1 and memsz:
            o = paddr - bus.ram_base
            bus.ram[o:o + filesz] = data[off:off + filesz]
            bus.ram[o + filesz:o + memsz] = bytes(memsz - filesz)
    syms = {}
    secs = [struct.unpack_from('<IIQQQQIIQQ', data, shoff + i * shentsize) for i in range(shnum)]
    for s in secs:
        if s[1] == 2:                         # SHT_SYMTAB
            strtab = secs[s[6]]
            for j in range(s[5] // 24):
                name, _, _, _, value, _ = struct.unpack_from('<IBBHQQ', data, s[4] + j * 24)
                st = strtab[4] + name
                nm = data[st:data.index(b'\0', st)].decode()
                if nm:
                    syms[nm] = value
    bus.tohost = syms.get('tohost')
    bus.fromhost = syms.get('fromhost')
    return entry, syms


# ---------------------------------------------------------------- decompresor
def _i(op, rd, f3, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def _s(op, f3, rs1, rs2, imm):
    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 31) << 7) | op


def _b(f3, rs1, rs2, imm):
    return ((((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15)
            | (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63)


def _j(rd, imm):
    return ((((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20)
            | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F)


def _r(op, rd, f3, rs1, rs2, f7):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def expand_c(c):
    """Expande una instruccion de 16 bit a su equivalente de 32. None = ilegal."""
    q, f3 = c & 3, (c >> 13) & 7
    rd, rs2 = (c >> 7) & 31, (c >> 2) & 31
    rdp, rs2p = 8 + ((c >> 7) & 7), 8 + ((c >> 2) & 7)
    imm6 = sx(((c >> 7) & 0x20) | ((c >> 2) & 31), 6)
    if q == 0:
        if f3 == 0:
            imm = ((c >> 7) & 0x30) | ((c >> 1) & 0x3C0) | ((c >> 4) & 4) | ((c >> 2) & 8)
            return None if imm == 0 else _i(0x13, rs2p, 0, 2, imm)
        if f3 == 2:
            imm = ((c >> 7) & 0x38) | ((c >> 4) & 4) | ((c << 1) & 0x40)
            return _i(0x03, rs2p, 2, rdp, imm)
        if f3 == 3:
            imm = ((c >> 7) & 0x38) | ((c << 1) & 0xC0)
            return _i(0x03, rs2p, 3, rdp, imm)
        if f3 == 6:
            imm = ((c >> 7) & 0x38) | ((c >> 4) & 4) | ((c << 1) & 0x40)
            return _s(0x23, 2, rdp, rs2p, imm)
        if f3 == 7:
            imm = ((c >> 7) & 0x38) | ((c << 1) & 0xC0)
            return _s(0x23, 3, rdp, rs2p, imm)
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
                imm = sx(((c >> 3) & 0x200) | ((c >> 2) & 0x10) | ((c << 1) & 0x40)
                         | ((c << 4) & 0x180) | ((c << 3) & 0x20), 10)
                return None if imm == 0 else _i(0x13, 2, 0, 2, imm)
            imm = sx(((c << 5) & 0x20000) | ((c << 10) & 0x1F000), 18)
            return None if imm == 0 else ((imm & 0xFFFFF000) | (rd << 7) | 0x37)
        if f3 == 4:
            f2 = (c >> 10) & 3
            sh = ((c >> 7) & 0x20) | ((c >> 2) & 31)
            if f2 == 0:
                return _i(0x13, rdp, 5, rdp, sh)
            if f2 == 1:
                return _i(0x13, rdp, 5, rdp, 0x400 | sh)
            if f2 == 2:
                return _i(0x13, rdp, 7, rdp, imm6)
            sub = (c >> 5) & 3
            if not (c >> 12) & 1:
                f3r, f7 = ((0, 0x20), (4, 0), (6, 0), (7, 0))[sub]
                return _r(0x33, rdp, f3r, rdp, rs2p, f7)
            if sub == 0:
                return _r(0x3B, rdp, 0, rdp, rs2p, 0x20)
            if sub == 1:
                return _r(0x3B, rdp, 0, rdp, rs2p, 0)
            return None
        if f3 == 5:
            imm = sx(((c >> 1) & 0x800) | ((c >> 7) & 0x10) | ((c >> 1) & 0x300) | ((c << 2) & 0x400)
                     | ((c >> 1) & 0x40) | ((c << 1) & 0x80) | ((c >> 2) & 0xE) | ((c << 3) & 0x20), 12)
            return _j(0, imm)
        imm = sx(((c >> 4) & 0x100) | ((c >> 7) & 0x18) | ((c << 1) & 0xC0)
                 | ((c >> 2) & 6) | ((c << 3) & 0x20), 9)
        return _b(0 if f3 == 6 else 1, rdp, 0, imm)
    if q == 2:
        if f3 == 0:
            sh = ((c >> 7) & 0x20) | ((c >> 2) & 31)
            return _i(0x13, rd, 1, rd, sh)
        if f3 == 2:
            imm = ((c >> 7) & 0x20) | ((c >> 2) & 0x1C) | ((c << 4) & 0xC0)
            return None if rd == 0 else _i(0x03, rd, 2, 2, imm)
        if f3 == 3:
            imm = ((c >> 7) & 0x20) | ((c >> 2) & 0x18) | ((c << 4) & 0x1C0)
            return None if rd == 0 else _i(0x03, rd, 3, 2, imm)
        if f3 == 4:
            if not (c >> 12) & 1:
                if rs2 == 0:
                    return None if rd == 0 else _i(0x67, 0, 0, rd, 0)
                return _r(0x33, rd, 0, 0, rs2, 0)
            if rs2 == 0:
                return 0x00100073 if rd == 0 else _i(0x67, 1, 0, rd, 0)
            return _r(0x33, rd, 0, rd, rs2, 0)
        if f3 == 6:
            imm = ((c >> 7) & 0x3C) | ((c >> 1) & 0xC0)
            return _s(0x23, 2, 2, rs2, imm)
        if f3 == 7:
            imm = ((c >> 7) & 0x38) | ((c >> 1) & 0x1C0)
            return _s(0x23, 3, 2, rs2, imm)
        return None
    return None


# ---------------------------------------------------------------- hart
class Hart:
    def __init__(self, bus, pc=0x8000_0000, time_div=1):
        self.bus = bus
        self.x = [0] * 32
        self.pc = pc
        self.priv = PRV_M
        self.time_div = time_div
        self.steps = 0
        # CSRs
        self.mstatus = MS_UXL_SXL
        self.medeleg = self.mideleg = 0
        self.mie = self.mip_sw = 0           # mip_sw: SSIP/STIP/SEIP escribibles
        self.mtvec = self.stvec = 0
        self.mscratch = self.sscratch = 0
        self.mepc = self.sepc = 0
        self.mcause = self.scause = 0
        self.mtval = self.stval = 0
        self.mcounteren = self.scounteren = 0
        self.mcountinhibit = 0
        self.menvcfg = self.senvcfg = 0
        self.satp = 0
        self.mcycle = self.minstret = 0
        self.meip = self.seip_hw = 0         # lineas externas (PLIC), Paso 7
        self.resv = None                     # linea reservada (pa >> 6)
        self.irq_forced = False              # lockstep: solo irq que dicte el RTL
        self.wlog = None                     # ultima escritura del paso: (pa, bytes, valor)
        self.mip_hw = None                   # lockstep: MTIP/MSIP/MEIP/SEIP dictados por el RTL
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

    # ------------------------------------------------ traps
    def take_trap(self, cause, tval, is_irq):
        self.resv = None
        deleg = self.mideleg if is_irq else self.medeleg
        code = cause
        cause_v = (IRQ_BIT | cause) if is_irq else cause
        if self.priv <= PRV_S and (deleg >> code) & 1:
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
        self.pc = (base + 4 * code) & M64 if (is_irq and mode) else base

    # ------------------------------------------------ traduccion Sv39
    def translate(self, va, acc, priv=None):
        if priv is None:
            priv = self.priv
            if acc != FETCH and (self.mstatus & MS_MPRV):
                priv = (self.mstatus >> MS_MPP_SH) & 3
        if priv == PRV_M or (self.satp >> 60) != 8:
            return va & M64
        pf = (EXC_IPAGE, EXC_LPAGE, EXC_SPAGE)[acc]
        af = (EXC_IACCESS, EXC_LACCESS, EXC_SACCESS)[acc]
        if sx(va, 39) & M64 != va & M64:
            raise Trap(pf, va)
        a = (self.satp & ((1 << 44) - 1)) << 12
        for lvl in (2, 1, 0):
            vpn = (va >> (12 + 9 * lvl)) & 0x1FF
            if not self.bus.in_ram(a + vpn * 8, 8):      # PMA: PTEs solo en DRAM
                raise Trap(af, va)
            pte = self.bus.load(a + vpn * 8, 8)
            v, r, w, x = pte & 1, (pte >> 1) & 1, (pte >> 2) & 1, (pte >> 3) & 1
            if not v or (not r and w) or (pte >> 54):
                raise Trap(pf, va)
            if r or x:
                break
            a = ((pte >> 10) & ((1 << 44) - 1)) << 12
        else:
            raise Trap(pf, va)
        u, a_bit, d_bit = (pte >> 4) & 1, (pte >> 6) & 1, (pte >> 7) & 1
        if acc == FETCH:
            ok = x
        elif acc == LOAD:
            ok = r or (x and (self.mstatus & MS_MXR))
        else:
            ok = w
        if priv == PRV_U and not u:
            ok = 0
        if priv == PRV_S and u and (acc == FETCH or not (self.mstatus & MS_SUM)):
            ok = 0
        ppn = (pte >> 10) & ((1 << 44) - 1)
        if lvl and ppn & ((1 << (9 * lvl)) - 1):
            ok = 0
        if not a_bit or (acc == STORE and not d_bit):
            ok = 0
        if not ok:
            raise Trap(pf, va)
        off_mask = (1 << (12 + 9 * lvl)) - 1
        return ((ppn << 12) & ~off_mask) | (va & off_mask)

    # ------------------------------------------------ acceso a memoria
    def mem_load(self, va, size, acc=LOAD):
        if va & (size - 1):
            raise Trap(EXC_LMISALIGN, va)
        pa = self.translate(va, LOAD)
        try:
            return pa, self.bus.load(pa, size)
        except AccessFault:
            raise Trap(EXC_LACCESS, va)

    def mem_store(self, va, size, val):
        if va & (size - 1):
            raise Trap(EXC_SMISALIGN, va)
        pa = self.translate(va, STORE)
        try:
            self.bus.store(pa, size, val)
        except AccessFault:
            raise Trap(EXC_SACCESS, va)
        self.wlog = (pa, size, val & ((1 << (8 * size)) - 1))
        return pa

    def fetch16(self, va):
        pa = self.translate(va, FETCH)
        if not (self.bus.in_ram(pa, 2) or self.bus.in_rom(pa, 2)):   # PMA: solo DRAM/ROM ejecutable
            raise Trap(EXC_IACCESS, va)
        try:
            return self.bus.load(pa, 2)
        except AccessFault:
            raise Trap(EXC_IACCESS, va)

    # ------------------------------------------------ CSRs
    def csr_read(self, a):
        p = self.priv
        if ((a >> 8) & 3) > p:
            raise Trap(EXC_ILLEGAL)
        if 0xC00 <= a <= 0xC1F:              # cycle/time/instret/hpmcounter
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
            return self.satp
        raise Trap(EXC_ILLEGAL)

    def csr_write(self, a, v):
        v &= M64
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
        elif a == 0x305: self.mtvec = self._tvec(self.mtvec, v)
        elif a == 0x306: self.mcounteren = v & M32
        elif a == 0x30A: self.menvcfg = self._envcfg(v)
        elif a == 0x320: self.mcountinhibit = v & 5
        elif 0x323 <= a <= 0x33F: pass
        elif a == 0x340: self.mscratch = v
        elif a == 0x341: self.mepc = v & ~1
        elif a == 0x342: self.mcause = v
        elif a == 0x343: self.mtval = v
        elif a == 0x344: self.mip_sw = (self.mip_sw & ~S_INTS) | (v & S_INTS)
        elif 0x3A0 <= a <= 0x3EF: pass       # PMP: 0 entradas (impares ya fallaron en lectura)
        elif 0x7A0 <= a <= 0x7A3: pass
        elif a == 0xB00: self.mcycle = v
        elif a == 0xB02:
            self.minstret = v
            self._instret_written = True
        elif 0xB03 <= a <= 0xB1F: pass
        elif a == 0x100:
            self.mstatus = (self.mstatus & ~SSTATUS_WMASK) | (v & SSTATUS_WMASK)
        elif a == 0x104:
            self.mie = (self.mie & ~self.mideleg) | (v & self.mideleg)
        elif a == 0x105: self.stvec = self._tvec(self.stvec, v)
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
            mode = v >> 60
            if mode in (0, 8):
                self.satp = v & ((0xF << 60) | (0xFFFF << 44) | ((1 << 44) - 1))
        else:
            raise Trap(EXC_ILLEGAL)

    @staticmethod
    def _envcfg(v):
        # FIOM(0), CBIE(5:4), CBCFE(6). CBIE=10 (reservado) -> 00, como Spike.
        v &= 0x71
        if (v >> 4) & 3 == 2:
            v &= ~0x30
        return v

    @staticmethod
    def _tvec(old, v):
        # MODE WARL: bit 0 = vectorizado, bit 1 siempre 0 (como Spike; sin estado previo)
        return (v & ~3 & M64) | (v & 1)

    # ------------------------------------------------ paso
    def step(self, force_irq=None):
        """Ejecuta un paso. Devuelve (pc, insn, rd, valor, trap) donde trap es
        None o (causa_completa, tval). rd=0 significa sin escritura."""
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
                    hi = self.fetch16((pc + 2) & M64)
                except Trap as t:
                    t.tval = (pc + 2) & M64
                    raise
                insn = lo | (hi << 16)
                ilen = 4
                ex = insn
            else:
                insn = lo
                ilen = 2
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
            self.x[rd] = val & M64
        if not (self.mcountinhibit & 4) and not self._instret_written:
            self.minstret = (self.minstret + 1) & M64
        return (pc, insn, rd, val & M64 if rd else 0, None)

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
        npc = (pc + ilen) & M64
        ill = Trap(EXC_ILLEGAL, raw)
        res = None

        if op == 0x37:                                   # LUI
            res = sx(i & 0xFFFFF000, 32)
        elif op == 0x17:                                 # AUIPC
            res = pc + sx(i & 0xFFFFF000, 32)
        elif op == 0x6F:                                 # JAL
            imm = sx(((i >> 11) & 0x100000) | (i & 0xFF000) | ((i >> 9) & 0x800) | ((i >> 20) & 0x7FE), 21)
            res, npc = pc + ilen, (pc + imm) & M64
        elif op == 0x67:                                 # JALR
            if f3:
                raise ill
            res, npc = pc + ilen, (a + sx(i >> 20, 12)) & M64 & ~1
        elif op == 0x63:                                 # BRANCH
            imm = sx(((i >> 19) & 0x1000) | ((i << 4) & 0x800) | ((i >> 20) & 0x7E0) | ((i >> 7) & 0x1E), 13)
            if f3 == 0: t = a == b
            elif f3 == 1: t = a != b
            elif f3 == 4: t = s64(a) < s64(b)
            elif f3 == 5: t = s64(a) >= s64(b)
            elif f3 == 6: t = a < b
            elif f3 == 7: t = a >= b
            else: raise ill
            if t:
                npc = (pc + imm) & M64
            rd = 0
        elif op == 0x03:                                 # LOAD
            if f3 == 7:
                raise ill
            size = 1 << (f3 & 3)
            _, v = self.mem_load((a + sx(i >> 20, 12)) & M64, size)
            res = v if f3 & 4 else sx(v, 8 * size)
        elif op == 0x23:                                 # STORE
            if f3 > 3:
                raise ill
            imm = sx(((i >> 20) & 0xFE0) | ((i >> 7) & 31), 12)
            self.mem_store((a + imm) & M64, 1 << f3, b)
            rd = 0
        elif op == 0x13:                                 # OP-IMM
            imm = sx(i >> 20, 12)
            if f3 == 0: res = a + imm
            elif f3 == 2: res = int(s64(a) < imm)
            elif f3 == 3: res = int(a < (imm & M64))
            elif f3 == 4: res = a ^ imm
            elif f3 == 6: res = a | imm
            elif f3 == 7: res = a & imm
            else:
                sh, f6 = (i >> 20) & 63, i >> 26
                if f3 == 1 and f6 == 0: res = a << sh
                elif f3 == 5 and f6 == 0: res = a >> sh
                elif f3 == 5 and f6 == 0x10: res = s64(a) >> sh
                else: raise ill
        elif op == 0x1B:                                 # OP-IMM-32
            sh = (i >> 20) & 31
            if f3 == 0: res = sx(a + sx(i >> 20, 12), 32)
            elif f3 == 1 and f7 == 0: res = sx(a << sh, 32)
            elif f3 == 5 and f7 == 0: res = sx((a & M32) >> sh, 32)
            elif f3 == 5 and f7 == 0x20: res = sx(a, 32) >> sh
            else: raise ill
        elif op == 0x33:                                 # OP
            if f7 == 0:
                res = (a + b, a << (b & 63), int(s64(a) < s64(b)), int(a < b),
                       a ^ b, a >> (b & 63), a | b, a & b)[f3]
            elif f7 == 0x20 and f3 == 0: res = a - b
            elif f7 == 0x20 and f3 == 5: res = s64(a) >> (b & 63)
            elif f7 == 1: res = self._muldiv(f3, a, b)
            else: raise ill
        elif op == 0x3B:                                 # OP-32
            if f7 == 0 and f3 == 0: res = sx(a + b, 32)
            elif f7 == 0x20 and f3 == 0: res = sx(a - b, 32)
            elif f7 == 0 and f3 == 1: res = sx(a << (b & 31), 32)
            elif f7 == 0 and f3 == 5: res = sx((a & M32) >> (b & 31), 32)
            elif f7 == 0x20 and f3 == 5: res = sx(a, 32) >> (b & 31)
            elif f7 == 1 and f3 in (0, 4, 5, 6, 7): res = self._muldivw(f3, a, b)
            else: raise ill
        elif op == 0x2F:                                 # AMO
            res = self._amo(i, f3, a, b, ill)
        elif op == 0x0F:                                 # MISC-MEM
            if f3 == 2:                                  # Zicbom: cbo.inval/clean/flush
                self._cbo(i, rd, a, ill)
            elif f3 not in (0, 1):
                raise ill
            rd = 0                                       # fence / fence.i / cbo: nop en el ISS
        elif op == 0x73:                                 # SYSTEM
            res, npc, rd = self._system(i, raw, f3, rd, rs1, a, npc, ill)
        else:
            raise ill

        self.pc = npc
        if res is None or rd == 0:
            return 0, 0
        return rd, res & M64

    def _cbo(self, i, rd, a, ill):
        """Zicbom. Sin caches en el ISS: solo comprobaciones de permiso y fallos.
        Habilitacion por menvcfg/senvcfg (CBIE para inval, CBCFE para clean/flush);
        traduccion como load, fallos convertidos a store/AMO (15/7), sin fallos de PMA."""
        op = i >> 20
        if rd != 0 or op not in (0, 1, 2):
            raise ill
        if op == 0:
            m_en, s_en = (self.menvcfg >> 4) & 3, (self.senvcfg >> 4) & 3
        else:
            m_en, s_en = (self.menvcfg >> 6) & 1, (self.senvcfg >> 6) & 1
        if (self.priv != PRV_M and m_en == 0) or (self.priv == PRV_U and s_en == 0):
            raise ill
        try:
            self.translate(a, LOAD)
        except Trap as t:
            raise Trap({EXC_LPAGE: EXC_SPAGE, EXC_LACCESS: EXC_SACCESS}.get(t.cause, t.cause), t.tval)

    def _muldiv(self, f3, a, b):
        sa, sb = s64(a), s64(b)
        if f3 == 0: return a * b
        if f3 == 1: return (sa * sb) >> 64
        if f3 == 2: return (sa * b) >> 64
        if f3 == 3: return (a * b) >> 64
        if f3 == 4:
            if b == 0: return M64
            if sa == -(1 << 63) and sb == -1: return a
            q = abs(sa) // abs(sb)
            return -q if (sa < 0) != (sb < 0) else q
        if f3 == 5: return M64 if b == 0 else a // b
        if f3 == 6:
            if b == 0: return a
            if sa == -(1 << 63) and sb == -1: return 0
            r = abs(sa) % abs(sb)
            return -r if sa < 0 else r
        return a if b == 0 else a % b

    def _muldivw(self, f3, a, b):
        sa, sb, ua, ub = sx(a, 32), sx(b, 32), a & M32, b & M32
        if f3 == 0: return sx(sa * sb, 32)
        if f3 == 4:
            if ub == 0: return -1
            if sa == -(1 << 31) and sb == -1: return sa
            q = abs(sa) // abs(sb)
            return sx(-q if (sa < 0) != (sb < 0) else q, 32)
        if f3 == 5: return -1 if ub == 0 else sx(ua // ub, 32)
        if f3 == 6:
            if ub == 0: return sa
            if sa == -(1 << 31) and sb == -1: return 0
            r = abs(sa) % abs(sb)
            return sx(-r if sa < 0 else r, 32)
        return sa if ub == 0 else sx(ua % ub, 32)

    def _amo(self, i, f3, a, b, ill):
        if f3 not in (2, 3):
            raise ill
        size = 4 if f3 == 2 else 8
        f5 = i >> 27
        if f5 == 2:                                       # LR
            if (i >> 20) & 31:
                raise ill
            if a & (size - 1):
                raise Trap(EXC_LMISALIGN, a)
            pa = self.translate(a, LOAD)
            if not self.bus.in_ram(pa, size):             # PMA: sin atomicos
                raise Trap(EXC_LACCESS, a)
            pa, v = self.mem_load(a, size)
            self.resv = pa >> 6
            return sx(v, 8 * size)
        if f5 == 3:                                       # SC
            if a & (size - 1):
                raise Trap(EXC_SMISALIGN, a)
            pa = self.translate(a, STORE)
            if not self.bus.in_ram(pa, size):             # PMA antes de la reserva
                raise Trap(EXC_SACCESS, a)
            ok = self.resv is not None and self.resv == pa >> 6
            self.resv = None
            if not ok:
                return 1
            try:
                self.bus.store(pa, size, b)
            except AccessFault:
                raise Trap(EXC_SACCESS, a)
            self.wlog = (pa, size, b & ((1 << (8 * size)) - 1))
            return 0
        if f5 not in (0, 1, 4, 8, 12, 16, 20, 24, 28):
            raise ill
        if a & (size - 1):
            raise Trap(EXC_SMISALIGN, a)
        pa = self.translate(a, STORE)
        if not self.bus.in_ram(pa, size):
            raise Trap(EXC_SACCESS, a)
        try:
            old = self.bus.load(pa, size)
        except AccessFault:
            raise Trap(EXC_SACCESS, a)
        bits = 8 * size
        so, sb = sx(old, bits), sx(b, bits)
        ub = b & ((1 << bits) - 1)
        new = {0: old + b, 1: b, 4: old ^ b, 8: old | b, 12: old & b,
               16: min(so, sb), 20: max(so, sb), 24: min(old, ub), 28: max(old, ub)}[f5]
        try:
            self.bus.store(pa, size, new)
        except AccessFault:
            raise Trap(EXC_SACCESS, a)
        self.wlog = (pa, size, new & ((1 << (8 * size)) - 1))
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
        # Ninguna lectura de CSR tiene efectos laterales: se lee siempre para
        # comprobar existencia y privilegio, incluso csrrw con rd=0.
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
def run_elf(path, max_steps=2_000_000, trace=None):
    bus = Bus()
    entry, _ = load_elf(bus, path)
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
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('elf', nargs='+')
    ap.add_argument('--trace', action='store_true')
    ap.add_argument('--max', type=int, default=2_000_000)
    args = ap.parse_args()
    tr = None
    if args.trace:
        def tr(h, r):
            pc, insn, rd, val, trap = r
            s = f'{pc:016x} ({insn:08x})'
            if rd:
                s += f' x{rd:<2}={val:016x}'
            if trap:
                s += f' TRAP cause={trap[0]:#x} tval={trap[1]:#x}'
            print(s)
    fails = 0
    for f in args.elf:
        code, h = run_elf(f, args.max, tr)
        ok = code == 0
        fails += not ok
        print(f'{"PASS" if ok else "FAIL"} {f}  code={code} pasos={h.steps}')
        if h.bus.console:
            print('  consola:', bytes(h.bus.console).decode(errors='replace').strip())
        del h
        gc.collect()
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
