#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mmio_oracle.py - Oraculo de nivel registro (Layer 3) del ECC scrubber, Core 20.

Modela el banco MMIO + inyector + scrubbing como una maquina de estados que
responde a una secuencia de accesos dmem (write/read de 32 bits sobre offsets).
Produce la traza de VALORES DE LECTURA esperados y una firma FNV.

Mapa de registros (congelado):
  0x00 ID          RO  0x5C520020
  0x04 STATUS      RW  bit0 busy bit1 done bit2 ded_sticky bit3 ce_sticky
                       bit4 periodic armed. bit2/bit3 are W1C (write 1 clears).
  0x08 CONTROL     RW  bit0 scrub_en(pulse start) bit1 oneshot bit2 clr_cnt bit3 clr_sticky
  0x0C REGION_BASE RW
  0x10 REGION_LEN  RW
  0x14 PERIOD      RW
  0x18 CE_COUNT    RO
  0x1C DED_COUNT   RO
  0x20 FIRST_ADDR  RO
  0x24 FIRST_SYN   RO  bit6..0 syn, bit8 was_ded, bit9 was_ce
  0x28 LAST_ADDR   RO
  0x2C LAST_SYN    RO
  0x30 INJ_ADDR    RW
  0x34 INJ_MASK_LO RW
  0x38 INJ_MASK_HI RW  (bit6..0 = mask bits 38..32)
  0x3C INJ_CTRL    RW  bit0 arm  bit1 mode(0 on-read, 1 inmediato)
  0x40 SCRATCH     RW

Modelo de scrub: al escribir CONTROL con bit0=1, se corre un barrido completo
de la region [0, REGION_LEN) sobre la BRAM interna, aplicando RCW; los inject
armados en modo on-read se aplican durante el barrido en su INJ_ADDR; los inject
en modo inmediato ya se aplicaron al escribir INJ_CTRL.arm.

Audit 2026-11 (from the register spec, independent of the RTL):
  - the sweep visits (REGION_BASE + i) mod depth for i < min(REGION_LEN, depth);
    REGION_LEN = 0 sweeps nothing.
  - a CPU start clears CE/DED, FIRST/LAST and the sticky flags.
  - sticky flags are set by any CE / DED and cleared by W1C on STATUS or by
    CONTROL.clr_sticky. CONTROL.clr_cnt clears the counters only.
  - CONTROL.oneshot = 0 with PERIOD != 0 arms periodic re-sweeps (the timing of
    the re-sweeps is not modelled here; periodic() runs one explicitly and it
    accumulates into the counters). PERIOD = 0 disarms.
"""
from ecc_oracle import encode, decode, inject, fnv1a_32

# offsets
ID, STATUS, CONTROL, REGION_BASE, REGION_LEN, PERIOD = 0x00, 0x04, 0x08, 0x0C, 0x10, 0x14
CE_COUNT, DED_COUNT = 0x18, 0x1C
FIRST_ADDR, FIRST_SYN, LAST_ADDR, LAST_SYN = 0x20, 0x24, 0x28, 0x2C
INJ_ADDR, INJ_MASK_LO, INJ_MASK_HI, INJ_CTRL, SCRATCH = 0x30, 0x34, 0x38, 0x3C, 0x40

CORE_ID = 0x5C520020


class EccMmio:
    def __init__(self, depth):
        self.depth = depth
        self.mem = [0] * depth          # palabras 39b en la BRAM interna
        self.reg = {
            REGION_BASE: 0, REGION_LEN: depth, PERIOD: 0,
            INJ_ADDR: 0, INJ_MASK_LO: 0, INJ_MASK_HI: 0, INJ_CTRL: 0, SCRATCH: 0,
        }
        self.ce = 0
        self.ded = 0
        self.first = None
        self.last = None
        self.busy = 0
        self.done = 0
        self.pending_onread = None   # (addr, mask) armado en modo on-read
        self.flag_ce = 0             # sticky, W1C
        self.flag_ded = 0
        self.per_armed = 0

    def load_clean(self, data_words):
        for i, d in enumerate(data_words):
            self.mem[i] = encode(d)

    def _inj_mask(self):
        return (self.reg[INJ_MASK_LO] & 0xFFFFFFFF) | \
               ((self.reg[INJ_MASK_HI] & 0x7F) << 32)

    def _record(self, addr, syn, was_ce, was_ded):
        rec = (addr, syn, was_ce, was_ded)
        self.flag_ce |= was_ce
        self.flag_ded |= was_ded
        if self.first is None:
            self.first = rec
        self.last = rec

    def _do_scrub(self, clear=True):
        self.busy = 1
        self.done = 0
        if clear:
            self.ce = 0
            self.ded = 0
            self.first = None
            self.last = None
            self.flag_ce = 0
            self.flag_ded = 0
        base = self.reg[REGION_BASE] % self.depth
        length = min(self.reg[REGION_LEN], self.depth)
        for i in range(length):
            addr = (base + i) % self.depth
            # inject on-read: si esta armado para esta direccion, aplicar ahora
            if self.pending_onread is not None and self.pending_onread[0] == addr:
                self.mem[addr] = inject(self.mem[addr], self.pending_onread[1])
                self.pending_onread = None
                self.reg[INJ_CTRL] &= ~0x1  # auto-clear arm
            data, syn, cor, de = decode(self.mem[addr])
            if cor:
                self.mem[addr] = encode(data)
                self.ce += 1
                self._record(addr, syn, 1, 0)
            elif de:
                self.ded += 1
                self._record(addr, syn, 0, 1)
        self.busy = 0
        self.done = 1

    def write(self, off, val):
        val &= 0xFFFFFFFF
        if off in (REGION_BASE, REGION_LEN, PERIOD, INJ_ADDR,
                   INJ_MASK_LO, INJ_MASK_HI, SCRATCH):
            self.reg[off] = val
            if off == PERIOD and val == 0:
                self.per_armed = 0
        elif off == STATUS:          # W1C sticky flags
            if val & 0x4: self.flag_ded = 0
            if val & 0x8: self.flag_ce = 0
        elif off == INJ_CTRL:
            self.reg[off] = val
            if val & 0x1:  # arm
                mode = (val >> 1) & 0x1
                a = self.reg[INJ_ADDR]
                m = self._inj_mask()
                if mode == 1:
                    # inmediato: aplica XOR al vuelo y auto-clear arm
                    if 0 <= a < self.depth:
                        self.mem[a] = inject(self.mem[a], m)
                    self.reg[INJ_CTRL] &= ~0x1
                else:
                    # on-read: queda pendiente hasta el barrido
                    self.pending_onread = (a, m)
        elif off == CONTROL:
            if val & 0x4:  # clr_cnt
                self.ce = 0; self.ded = 0
            if val & 0x8:  # clr_sticky
                self.first = None; self.last = None
                self.flag_ce = 0; self.flag_ded = 0
            if val & 0x1:  # scrub_en -> corre barrido
                self.per_armed = 1 if ((val & 0x2) == 0 and self.reg[PERIOD] != 0) else 0
                self._do_scrub()

    def periodic(self):
        """One periodic re-sweep (only if armed); accumulates results."""
        if self.per_armed:
            self._do_scrub(clear=False)

    def _sticky_word(self, rec):
        if rec is None:
            return 0
        addr, syn, wc, wd = rec
        return (syn & 0x7F) | ((wd & 1) << 8) | ((wc & 1) << 9)

    def _sticky_addr(self, rec):
        return 0 if rec is None else rec[0]

    def read(self, off):
        if off == ID:
            return CORE_ID
        if off == STATUS:
            s = (self.busy & 1) | ((self.done & 1) << 1)
            s |= (self.flag_ded & 1) << 2
            s |= (self.flag_ce & 1) << 3
            s |= (self.per_armed & 1) << 4
            return s
        if off == CE_COUNT:  return self.ce & 0xFFFFFFFF
        if off == DED_COUNT: return self.ded & 0xFFFFFFFF
        if off == FIRST_ADDR: return self._sticky_addr(self.first)
        if off == FIRST_SYN:  return self._sticky_word(self.first)
        if off == LAST_ADDR:  return self._sticky_addr(self.last)
        if off == LAST_SYN:   return self._sticky_word(self.last)
        return self.reg.get(off, 0) & 0xFFFFFFFF
