#!/usr/bin/env python3
# ============================================================================
# pcie_iss.py -- PCIE IP v1, oraculo ISS de la Layer 4 (SoC + firmware)
#
# Modela funcionalmente el banco MMIO del periferico PCIe (pcie_mmio.vhd) mas
# el par de nodos RC/EP en LOOP_INT, al nivel de comportamiento observable por
# el firmware RV32 a traves del bus dmem. NO simula ciclo a ciclo: reproduce la
# SEMANTICA de cada acceso MMIO que el firmware realiza, de modo que la
# secuencia de bring-up produce una FIRMA determinista identica a la que el
# hardware vuelca por DMA a DDR (0x70000000).
#
# Este oraculo se escribe ANTES que el TB (metodologia Layer 4): el firmware se
# valida primero contra este modelo, luego el RTL se compara contra la misma
# firma.
#
# Mapa MMIO (de pcie_mmio_pkg.vhd):
#   0x00 CONTROL   bit0=start bit1=hotrst bit2=msi bit3=en
#   0x04 STATUS    bit0=link_up bit7:4=ltssm
#   0x08 IRQ_STAT  (W1C)  bit0=cpl_rx bit1=msi_tx
#   0x0C IRQ_EN
#   0x10 TX_DATA   (wo) byte[7:0]; bit8=last
#   0x14 TX_CTRL
#   0x18 RX_DATA   (ro) byte[7:0] del FIFO RX; auto-avanza al leer
#   0x1C RX_CTRL   bit0=rx_empty  bits[15:...]=level
#   0x20 BAR0_LAST (ro) ultimo DW escrito en BAR0 del EP
#   0x24 MWR_CNT   (ro)
#   0x28 MRD_CNT   (ro)
#   0x2C GOOD_RX   (ro)
#   0x30 MSI_ADDR
#   0x34 MSI_DATA
#   0x44 DBG_STATE (ro)
# ============================================================================

VENDOR_DEVICE = 0x50431AF4   # Device<<16 | Vendor (del TL EP)

class PcieModel:
    """Modelo funcional del periferico completo (MMIO + RC + EP en loopback)."""
    def __init__(self):
        self.bar0 = [0]*256      # memoria BAR0 del EP (DW)
        self.bar0_last = 0
        self.mwr_cnt = 0
        self.mrd_cnt = 0
        self.good_rx = 0
        self.link_up = 0
        self.ltssm = 0
        self.irq_stat = 0
        self.irq_en = 0
        self.msi_addr = 0
        self.msi_data = 0
        # FIFOs
        self.tx_fifo = []        # bytes con marca last: (byte, last)
        self.rx_fifo = []        # bytes de respuesta capturados en el RC
        self.dbg_state = 0

    # ---- procesamiento de un TLP completo empujado por el firmware ----
    def _consume_tx_tlp(self):
        """Cuando hay un TLP completo en tx_fifo (marca last), lo procesa el EP."""
        # localizar el primer TLP completo
        if not any(l for (_, l) in self.tx_fifo):
            return
        # extraer hasta el primer last
        tlp = []
        while self.tx_fifo:
            b, l = self.tx_fifo.pop(0)
            tlp.append(b)
            if l:
                break
        # parsear header 3DW (12 bytes) big-endian
        b0 = tlp[0]
        length = ((tlp[2] & 0x03) << 8) | tlp[3]
        addr = (tlp[8] << 24) | (tlp[9] << 16) | (tlp[10] << 8) | tlp[11]
        idx = addr >> 2
        if b0 == 0x40:            # MWr3
            for d in range(length):
                off = 12 + d*4
                dw = (tlp[off] << 24) | (tlp[off+1] << 16) | (tlp[off+2] << 8) | tlp[off+3]
                if idx + d < 256:
                    self.bar0[idx+d] = dw
                    self.bar0_last = dw
                    self.mwr_cnt += 1
        elif b0 == 0x00:          # MRd3 -> genera CplD que llega al RC (rx_fifo)
            self.mrd_cnt += 1
            dw = self.bar0[idx] if idx < 256 else 0
            # CplD: header 12 bytes + 4 de dato
            cpld = [0x4A, 0x00, 0x00, 0x01,
                    0x01, 0x00, 0x04, 0x00,
                    tlp[4], tlp[5], tlp[6], 0x00,
                    (dw>>24)&0xFF, (dw>>16)&0xFF, (dw>>8)&0xFF, dw&0xFF]
            self.rx_fifo.extend(cpld)
            self.good_rx += 1
            self.irq_stat |= 0x01     # cpl_rx
        elif b0 == 0x44:          # CfgWr0
            off = 12
            dw = (tlp[off] << 24) | (tlp[off+1] << 16) | (tlp[off+2] << 8) | tlp[off+3]
            reg = (addr >> 2) & 0x3F
            if reg == 20:   self.msi_addr = dw
            elif reg == 21: self.msi_data = dw
        elif b0 == 0x04:          # CfgRd0 -> CplD con el dato de config
            self.mrd_cnt += 1
            reg = (addr >> 2) & 0x3F
            if reg == 0:  dw = VENDOR_DEVICE
            else:         dw = 0
            cpld = [0x4A, 0x00, 0x00, 0x01,
                    0x01, 0x00, 0x04, 0x00,
                    tlp[4], tlp[5], tlp[6], 0x00,
                    (dw>>24)&0xFF, (dw>>16)&0xFF, (dw>>8)&0xFF, dw&0xFF]
            self.rx_fifo.extend(cpld)
            self.good_rx += 1
            self.irq_stat |= 0x01

    # ---- interfaz MMIO (lo que el firmware ve) ----
    def write(self, off, val):
        if off == 0x00:          # CONTROL
            if val & 0x1:        # start -> entrena y sube link
                self.link_up = 1
                self.ltssm = 0x4      # L0
            if val & 0x4:        # msi trigger -> el EP emite MWr3 al RC
                # el MSI aparece en rx_fifo como un MWr3 a msi_addr con msi_data
                a = self.msi_addr
                d = self.msi_data
                msi = [0x40, 0x00, 0x00, 0x01,
                       0x01, 0x00, 0x00, 0x0F,
                       (a>>24)&0xFF, (a>>16)&0xFF, (a>>8)&0xFF, a&0xFF,
                       (d>>24)&0xFF, (d>>16)&0xFF, (d>>8)&0xFF, d&0xFF]
                self.rx_fifo.extend(msi)
                self.irq_stat |= 0x02   # msi_tx
        elif off == 0x0C:        # IRQ_EN
            self.irq_en = val & 0xFFFFFFFF
        elif off == 0x10:        # TX_DATA
            self.tx_fifo.append((val & 0xFF, (val >> 8) & 0x1))
            self._consume_tx_tlp()
        elif off == 0x08:        # IRQ_STAT W1C
            self.irq_stat &= ~(val & 0xF)
        elif off == 0x30:        # MSI_ADDR (espejo local, informativo)
            self.msi_addr = val
        elif off == 0x34:
            self.msi_data = val

    def read(self, off):
        if off == 0x04:          # STATUS
            return (self.link_up & 0x1) | ((self.ltssm & 0xF) << 4)
        elif off == 0x08:
            return self.irq_stat
        elif off == 0x18:        # RX_DATA (auto-avanza)
            if self.rx_fifo:
                return self.rx_fifo.pop(0)
            return 0
        elif off == 0x1C:        # RX_CTRL
            empty = 0 if self.rx_fifo else 1
            return empty | (len(self.rx_fifo) << 16)
        elif off == 0x20:        # BAR0_LAST
            return self.bar0_last
        elif off == 0x24:
            return self.mwr_cnt
        elif off == 0x28:
            return self.mrd_cnt
        elif off == 0x2C:
            return self.good_rx
        elif off == 0x00:
            return 0
        return 0


def bring_up_sequence():
    """
    Ejecuta la MISMA secuencia que el firmware .s y devuelve la lista de
    palabras de FIRMA (32 bits) que se volcaran por DMA a DDR. El firmware y
    este oraculo deben producir exactamente esta lista.
    """
    BASE = 0x80000000
    m = PcieModel()
    sig = []

    def W(off, val): m.write(off, val)
    def R(off):      return m.read(off)

    # 1) habilitar y entrenar el enlace
    W(0x00, 0x1 | 0x8)                 # start + en
    # esperar link_up (en el modelo es inmediato; el firmware sondea STATUS)
    st = R(0x04)
    sig.append(st & 0x1)               # firma[0] = link_up (esperado 1)

    # 2) MWr3 de 4 DW a BAR0 (addr 0), datos 0x11.., 0x22.., 0x33.., 0x44..
    hdr = [0x40,0x00,0x00,0x04, 0x00,0x00,0x04,0x00, 0x00,0x00,0x00,0x00]
    pay = [0x11,0x11,0x11,0x11, 0x22,0x22,0x22,0x22,
           0x33,0x33,0x33,0x33, 0x44,0x44,0x44,0x44]
    body = hdr + pay
    for i, b in enumerate(body):
        last = 0x100 if i == len(body)-1 else 0
        W(0x10, b | last)
    sig.append(R(0x24))                # firma[1] = mwr_cnt (esperado 4)
    sig.append(R(0x20))                # firma[2] = bar0_last (esperado 0x44444444)

    # 3) MRd3 de la addr 8 (DW indice 2) -> CplD con 0x33333333
    hdr = [0x00,0x00,0x00,0x01, 0x00,0x00,0x05,0x00, 0x00,0x00,0x00,0x08]
    for i, b in enumerate(hdr):
        last = 0x100 if i == len(hdr)-1 else 0
        W(0x10, b | last)
    # drenar el CplD (16 bytes) del FIFO RX; el dato son los ultimos 4
    buf = [R(0x18) for _ in range(16)]
    dw = (buf[12]<<24)|(buf[13]<<16)|(buf[14]<<8)|buf[15]
    sig.append(buf[0])                 # firma[3] = b0 del CplD (esperado 0x4A)
    sig.append(dw)                     # firma[4] = dato leido (esperado 0x33333333)

    # 4) programar MSI y dispararlo
    # CfgWr0 a 0x50 (msi addr)
    for src in (
        [0x44,0x00,0x00,0x01, 0x00,0x00,0x06,0x00, 0x00,0x00,0x00,0x50,
         0xFE,0xED,0x00,0x00],
        [0x44,0x00,0x00,0x01, 0x00,0x00,0x07,0x00, 0x00,0x00,0x00,0x54,
         0x00,0x00,0xCA,0xFE],
    ):
        for i, b in enumerate(src):
            last = 0x100 if i == len(src)-1 else 0
            W(0x10, b | last)
    W(0x00, 0x4)                        # msi trigger
    buf = [R(0x18) for _ in range(16)]
    a = (buf[8]<<24)|(buf[9]<<16)|(buf[10]<<8)|buf[11]
    d = (buf[12]<<24)|(buf[13]<<16)|(buf[14]<<8)|buf[15]
    sig.append(a)                      # firma[5] = dir MSI (esperado 0xFEED0000)
    sig.append(d)                      # firma[6] = dato MSI (esperado 0x0000CAFE)

    # 5) leer IRQ_STAT (deben estar cpl_rx y msi_tx) y limpiarlo con W1C
    istat = R(0x08)
    sig.append(istat & 0x3)            # firma[7] = irq bits (esperado 0x3)
    W(0x08, 0x3)                        # W1C
    sig.append(R(0x08) & 0x3)          # firma[8] = irq tras limpiar (esperado 0)

    return sig


if __name__ == "__main__":
    sig = bring_up_sequence()
    names = ["link_up", "mwr_cnt", "bar0_last", "cpld_b0", "mrd_data",
             "msi_addr", "msi_data", "irq_bits", "irq_cleared"]
    print("=== FIRMA ESPERADA (oraculo ISS) ===")
    for i, (n, v) in enumerate(zip(names, sig)):
        print(f"  sig[{i}] {n:12s} = 0x{v:08X}")
    # firma agregada: XOR acumulado (checksum simple para comparacion rapida)
    acc = 0
    for v in sig:
        acc = (acc ^ v) & 0xFFFFFFFF
    print(f"=== CHECKSUM XOR = 0x{acc:08X} ===")
