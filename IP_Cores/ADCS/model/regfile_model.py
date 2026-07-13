#!/usr/bin/env python3
# ============================================================================
# regfile_model.py — Oraculo del contrato MMIO del reg file ADCS (capa 2).
# Genera regseq.txt: una secuencia de W/R + inyecciones de estado, con el
# rdata esperado calculado por un modelo del banco identico al RTL.
# ============================================================================
import sys

# offsets (deben coincidir con adcs_pkg.vhd)
REG = dict(CTRL=0x00, STATUS=0x04, MODE=0x08, NDIM=0x0C, MAXITER=0x10,
           STEP=0x14, UMAX=0x18, HBASE=0x1C, GBASE=0x20, UBASE=0x24,
           ITERCNT=0x28, VERSION=0x2C, DEBUG=0x44, DBGTAG=0x48)
IP_VERSION = 0x02000001
DBG_TAG = 0xADC50101
DBG_IN = 0x1234ABCD
CTRL_START = 0
CTRL_SRESET = 1
CTRL_IRQEN = 2


class Model:
    def __init__(self):
        self.r = dict(CTRL=0, MODE=0, NDIM=70, MAXITER=30, STEP=0, UMAX=0,
                      HBASE=0, GBASE=0, UBASE=0)
        self.st_done = 0
        self.st_err = 0
        self.busy = 0
        self.iter_cnt = 0

    def write(self, off, data):
        name = {v: k for k, v in REG.items()}.get(off)
        start = 0
        if name == 'CTRL':
            self.r['CTRL'] = data & 0xFF
            if data & (1 << CTRL_START):
                start = 1
        elif name in ('MODE', 'NDIM', 'MAXITER', 'STEP', 'UMAX',
                      'HBASE', 'GBASE', 'UBASE'):
            self.r[name] = data & 0xFFFFFFFF
        # sticky clear por soft_reset o start
        if (self.r['CTRL'] >> CTRL_SRESET) & 1 or start:
            self.st_done = 0
            self.st_err = 0
        # START auto-clear (pulso): el bit no persiste
        if start:
            self.r['CTRL'] &= ~(1 << CTRL_START)
        return start

    def set_done(self):
        if not ((self.r['CTRL'] >> CTRL_SRESET) & 1):
            self.st_done = 1

    def set_err(self):
        if not ((self.r['CTRL'] >> CTRL_SRESET) & 1):
            self.st_err = 1

    def read(self, off):
        name = {v: k for k, v in REG.items()}.get(off)
        if name == 'STATUS':
            return (self.st_err << 2) | (self.busy << 1) | self.st_done
        if name == 'ITERCNT':
            return self.iter_cnt & 0xFFFF
        if name == 'VERSION':
            return IP_VERSION
        if name == 'DEBUG':
            return DBG_IN
        if name == 'DBGTAG':
            return DBG_TAG
        if name in self.r:
            return self.r[name]
        return 0xDEADBEEF


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "regseq.txt"
    m = Model()
    lines = []

    def W(off, data):
        m.write(off, data)
        lines.append(f"W {off:02X} {data & 0xFFFFFFFF:08X}")

    def R(off):
        lines.append(f"R {off:02X} {m.read(off):08X}")

    # 1) identidad y defaults
    R(REG['VERSION']); R(REG['DBGTAG']); R(REG['DEBUG'])
    R(REG['NDIM']); R(REG['MAXITER']); R(REG['STATUS'])
    R(0x30); R(0x40)                        # reservados -> DEADBEEF

    # 2) programar todos los registros y releer (round-trip)
    W(REG['MODE'], 0x2); R(REG['MODE'])
    W(REG['NDIM'], 12);  R(REG['NDIM'])
    W(REG['MAXITER'], 5); R(REG['MAXITER'])
    W(REG['STEP'], 0x3F619999); R(REG['STEP'])
    W(REG['UMAX'], 0x3D4CCCCD); R(REG['UMAX'])
    W(REG['HBASE'], 0x70000000); R(REG['HBASE'])
    W(REG['GBASE'], 0x70010000); R(REG['GBASE'])
    W(REG['UBASE'], 0x70020000); R(REG['UBASE'])

    # 3) busy visible en STATUS
    lines.append("SET_BUSY 1"); m.busy = 1; R(REG['STATUS'])
    lines.append("SET_BUSY 0"); m.busy = 0; R(REG['STATUS'])

    # 4) sticky DONE/ERR: set, leer varias veces (NO clear-on-read)
    lines.append("PULSE_DONE"); m.set_done(); R(REG['STATUS']); R(REG['STATUS'])
    lines.append("PULSE_ERR");  m.set_err();  R(REG['STATUS']); R(REG['STATUS'])

    # 5) START limpia sticky y auto-clear del bit
    W(REG['CTRL'], (1 << CTRL_START)); R(REG['STATUS']); R(REG['CTRL'])

    # 6) set de nuevo y limpiar por soft_reset
    lines.append("PULSE_DONE"); m.set_done(); R(REG['STATUS'])
    W(REG['CTRL'], (1 << CTRL_SRESET)); R(REG['STATUS'])
    W(REG['CTRL'], 0)                     # quitar soft_reset

    with open(out, "w") as f:
        f.write("\n".join(lines) + "\n")

    # firma: fold sobre los rdata esperados (mismo esquema que el tb)
    sig = 0
    for ln in lines:
        if ln.startswith("R "):
            r = int(ln.split()[2], 16)
            sig = ((sig << 1) | (sig >> 31)) & 0xFFFFFFFF
            sig ^= r
    print(f"NREAD={sum(1 for x in lines if x.startswith('R '))}")
    print(f"FIRMA_ORACULO=0x{sig:08X}")


if __name__ == "__main__":
    main()
