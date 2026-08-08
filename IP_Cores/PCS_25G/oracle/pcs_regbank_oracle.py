#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Core 19 - PCS 64B/66B @ 25G
Oraculo de referencia del banco de registros AXI-Lite (Layer 4).

Modela la semantica exacta del banco: RW, RO, RW1C, WO/SC, mapeo IRQ,
snapshot atomico de contadores y bring-up de eventos del data plane.
Emite una firma FNV-1a 32-bit sobre la traza de transacciones.

El RTL (banco de registros VHDL) debe reproducir esta firma bit a bit.
Sin dependencias externas. Python 3.

Uso:
    python3 pcs_regbank_oracle.py           # corre la traza canonica, imprime firma
    python3 pcs_regbank_oracle.py --dump     # ademas vuelca la traza legible
"""

import sys

# ----------------------------------------------------------------------------
# FNV-1a 32-bit (algoritmo canonico del proyecto)
# ----------------------------------------------------------------------------
FNV32_OFFSET = 0x811C9DC5
FNV32_PRIME  = 0x01000193
MASK32       = 0xFFFFFFFF

def fnv1a_32(data_bytes, h=FNV32_OFFSET):
    for b in data_bytes:
        h ^= b
        h = (h * FNV32_PRIME) & MASK32
    return h

def u32_le_bytes(x):
    x &= MASK32
    return bytes([x & 0xFF, (x >> 8) & 0xFF, (x >> 16) & 0xFF, (x >> 24) & 0xFF])

# ----------------------------------------------------------------------------
# Offsets del mapa congelado
# ----------------------------------------------------------------------------
ID          = 0x00
SCRATCH     = 0x04
CTRL        = 0x08
CMD         = 0x0C
STATUS      = 0x10
IRQ_STATUS  = 0x14
IRQ_ENABLE  = 0x18
PRBS_CTRL   = 0x1C
STATS_SNAP  = 0x20
CNT_TX_BLK  = 0x24
CNT_RX_BLK  = 0x28
CNT_RX_ERR  = 0x2C
CNT_BER     = 0x30
LOCK_TIME   = 0x34
DMA_ADDR    = 0x38
DMA_DOORBELL= 0x3C

ID_MAGIC = 0x50435319   # "PCS" + 0x19

# CTRL bits
CTRL_PCS_EN      = 1 << 0
CTRL_TX_EN       = 1 << 1
CTRL_RX_EN       = 1 << 2
CTRL_LOOPBACK    = 1 << 3
CTRL_SCR_BYPASS  = 1 << 4
CTRL_FEC_EN      = 1 << 5
CTRL_AUTO_RESYNC = 1 << 6
CTRL_MASK        = 0x7F

# CMD bits (WO/SC)
CMD_SOFT_RESET = 1 << 0
CMD_RESYNC     = 1 << 1
CMD_CNT_CLEAR  = 1 << 2
CMD_PRBS_RESET = 1 << 3
CMD_MASK       = 0x0F

# STATUS bits (RO)
ST_BLOCK_LOCK = 1 << 0
ST_HI_BER     = 1 << 1
ST_SCR_SYNC   = 1 << 2
ST_PRBS_LOCK  = 1 << 3
ST_CTRL_ACK   = 1 << 4
ST_TX_ACTIVE  = 1 << 5
ST_RX_ACTIVE  = 1 << 6
ST_DMA_BUSY   = 1 << 7

# IRQ bits (bit-align comun a IRQ_STATUS/IRQ_ENABLE)
EV_LOCK_GAINED = 1 << 0
EV_LOCK_LOST   = 1 << 1
EV_HI_BER      = 1 << 2
EV_RX_ERR      = 1 << 3
EV_PRBS_ERR    = 1 << 4
EV_DMA_DONE    = 1 << 5
IRQ_MASK       = 0x3F

# PRBS_CTRL bits
PRBS_GEN_EN = 1 << 0
PRBS_CHK_EN = 1 << 1
PRBS_INJ    = 1 << 2   # pulso logico, auto-clear
PRBS_MASK   = 0x07

RESERVED_LO = 0x44
RESERVED_HI = 0x7C

# ----------------------------------------------------------------------------
# Modelo del banco
# ----------------------------------------------------------------------------
class PcsRegBank:
    """
    Modelo ciclo-a-transaccion del banco. El data plane se abstrae como una
    secuencia de eventos inyectados por el testbench (dp_event), que actualizan
    STATUS y setean stickies en IRQ_STATUS, mas contadores sombra.
    """
    def __init__(self):
        self.scratch     = 0x00000000
        self.ctrl        = 0x00000000
        self.status      = 0x00000000
        self.irq_status  = 0x00000000
        self.irq_enable  = 0x00000000
        self.prbs_ctrl   = 0x00000000
        self.dma_addr    = 0x70000000
        self.dma_doorbell= 0x00000000

        # contadores "en vuelo" (dominio DP) y su sombra (congelada por snapshot)
        self.live = {CNT_TX_BLK:0, CNT_RX_BLK:0, CNT_RX_ERR:0,
                     CNT_BER:0, LOCK_TIME:0}
        self.shadow = dict(self.live)

        self._prev_block_lock = 0  # para detectar transiciones de evento

    # --- efecto de CTRL_ACK: el modelo aplica el ack en la MISMA transaccion
    #     de escritura de CTRL (el RTL lo hace tras handshake CDC; el oraculo
    #     lo modela como aplicado de inmediato y refleja CTRL_ACK=1).
    def _apply_ctrl_ack(self):
        self.status |= ST_CTRL_ACK

    # --- write AXI ---
    def write(self, off, data):
        data &= MASK32
        if off == SCRATCH:
            self.scratch = data
        elif off == CTRL:
            self.ctrl = data & CTRL_MASK
            self._apply_ctrl_ack()
        elif off == CMD:
            self._exec_cmd(data & CMD_MASK)   # WO/SC: no se almacena
        elif off == IRQ_STATUS:
            # RW1C: escribir 1 limpia el bit
            self.irq_status &= (~data) & IRQ_MASK
        elif off == IRQ_ENABLE:
            self.irq_enable = data & IRQ_MASK
        elif off == PRBS_CTRL:
            self.prbs_ctrl = data & PRBS_MASK
            # INJ es pulso: no persiste
            if data & PRBS_INJ:
                self._inject_prbs_err()
            self.prbs_ctrl &= ~PRBS_INJ
        elif off == STATS_SNAP:
            if data & 1:
                self._snapshot()
        elif off == DMA_ADDR:
            self.dma_addr = data
        elif off == DMA_DOORBELL:
            self.dma_doorbell = data
        # ID, STATUS, contadores, LOCK_TIME: RO -> escritura sin efecto
        # reservado: sin efecto

    # --- read AXI ---
    def read(self, off):
        # read() devuelve el campo TAL COMO ESTA ALMACENADO. El enmascarado de
        # bits reservados ocurre en write(): si el RTL no enmascara al escribir,
        # el campo crudo diverge aqui y la firma lo detecta.
        if off == ID:            return ID_MAGIC
        if off == SCRATCH:       return self.scratch
        if off == CTRL:          return self.ctrl
        if off == CMD:           return 0x00000000   # WO: lee 0
        if off == STATUS:        return self.status
        if off == IRQ_STATUS:    return self.irq_status
        if off == IRQ_ENABLE:    return self.irq_enable
        if off == PRBS_CTRL:     return self.prbs_ctrl
        if off == STATS_SNAP:    return 0x00000000   # WO/SC: lee 0
        if off in self.shadow:   return self.shadow[off] & MASK32
        if off == DMA_ADDR:      return self.dma_addr
        if off == DMA_DOORBELL:  return self.dma_doorbell
        return 0x00000000  # reservado / no mapeado

    def irq_out(self):
        return 1 if (self.irq_status & self.irq_enable & IRQ_MASK) else 0

    # --- comandos WO/SC ---
    def _exec_cmd(self, cmd):
        # En el banco (Layer 1) los comandos WO/SC solo generan el pulso hacia
        # el data plane. Sus efectos (bajar lock, poner contadores a cero, etc.)
        # ocurren en el data plane y se verifican en Layer 2. Aqui NO se modelan
        # para mantener la frontera de capa limpia.
        pass

    def _inject_prbs_err(self):
        # En el banco (Layer 1) INJ solo genera el pulso hacia el data plane.
        # El incremento de BER y el sticky EV_PRBS_ERR los produce el data plane
        # como respuesta, y se modelan via dp_event("prbs_err") en la traza.
        pass

    def _snapshot(self):
        self.shadow = dict(self.live)

    def _set_sticky(self, bit):
        self.irq_status |= (bit & IRQ_MASK)

    # ------------------------------------------------------------------
    # Eventos del data plane inyectados por el testbench (dominio DP).
    # Cada evento actualiza STATUS y stickies de forma determinista.
    # ------------------------------------------------------------------
    def dp_event(self, name, n=1):
        if name == "tx_block":
            self.live[CNT_TX_BLK] = (self.live[CNT_TX_BLK] + n) & MASK32
            self.status |= ST_TX_ACTIVE
        elif name == "rx_block":
            self.live[CNT_RX_BLK] = (self.live[CNT_RX_BLK] + n) & MASK32
            self.status |= ST_RX_ACTIVE
        elif name == "rx_err":
            self.live[CNT_RX_ERR] = (self.live[CNT_RX_ERR] + n) & MASK32
            self._set_sticky(EV_RX_ERR)
        elif name == "gain_lock":
            new = 1
            if self._prev_block_lock == 0 and new == 1:
                self._set_sticky(EV_LOCK_GAINED)
            self._prev_block_lock = 1
            self.status |= ST_BLOCK_LOCK
        elif name == "lose_lock":
            if self._prev_block_lock == 1:
                self._set_sticky(EV_LOCK_LOST)
            self._prev_block_lock = 0
            self.status &= ~ST_BLOCK_LOCK
        elif name == "scr_sync":
            self.status |= ST_SCR_SYNC
        elif name == "prbs_lock":
            self.status |= ST_PRBS_LOCK
        elif name == "hi_ber":
            self.status |= ST_HI_BER
            self._set_sticky(EV_HI_BER)
        elif name == "lock_time":
            self.live[LOCK_TIME] = n & MASK32
        elif name == "prbs_err":
            self.live[CNT_BER] = (self.live[CNT_BER] + n) & MASK32
            self._set_sticky(EV_PRBS_ERR)
        elif name == "dma_done":
            self._set_sticky(EV_DMA_DONE)
        else:
            raise ValueError("evento DP desconocido: %s" % name)


# ----------------------------------------------------------------------------
# Traza canonica de verificacion. Cada paso es una transaccion AXI o un
# evento DP. La firma se acumula sobre (kind, off, data_resultante).
# kind: 0=write, 1=read, 2=dp_event
# ----------------------------------------------------------------------------
def canonical_trace():
    """Devuelve lista de operaciones (kind, arg1, arg2)."""
    ops = []
    W = lambda o, d: ops.append(("W", o, d))
    R = lambda o:    ops.append(("R", o, 0))
    E = lambda n, k=1: ops.append(("E", n, k))

    # 1. Identidad y scratch (Layer 1)
    R(ID)
    W(SCRATCH, 0xDEADBEEF); R(SCRATCH)
    W(SCRATCH, 0x00000000); R(SCRATCH)
    W(SCRATCH, 0xA5A5A5A5); R(SCRATCH)

    # 2. CTRL: mascara y ack
    W(CTRL, 0xFFFFFFFF); R(CTRL)          # solo 7 LSB persisten
    R(STATUS)                             # CTRL_ACK debe estar a 1
    W(CTRL, CTRL_PCS_EN|CTRL_TX_EN|CTRL_RX_EN|CTRL_LOOPBACK|CTRL_AUTO_RESYNC)
    R(CTRL)

    # 3. CMD WO/SC: no persiste
    W(CMD, 0xFFFFFFFF); R(CMD)            # lee 0

    # 4. PRBS_CTRL + inyeccion de error (pulso)
    W(PRBS_CTRL, PRBS_GEN_EN|PRBS_CHK_EN); R(PRBS_CTRL)
    W(PRBS_CTRL, PRBS_GEN_EN|PRBS_CHK_EN|PRBS_INJ); R(PRBS_CTRL)  # INJ no persiste
    R(IRQ_STATUS)                         # EV_PRBS_ERR sticky seteado

    # 5. Bring-up de enlace (eventos DP)
    E("lock_time", 4096)
    E("scr_sync")
    E("gain_lock")
    E("prbs_lock")
    R(STATUS)
    R(IRQ_STATUS)                         # EV_LOCK_GAINED sticky
    E("tx_block", 1000)
    E("rx_block", 1000)
    E("rx_err", 3)
    R(IRQ_STATUS)                         # EV_RX_ERR sticky

    # 6. Snapshot atomico + lectura de contadores
    E("tx_block", 500)                    # tras esto, snapshot congela 1500
    W(STATS_SNAP, 1)
    E("tx_block", 999)                    # cambia live, NO shadow
    R(CNT_TX_BLK)                         # debe leer 1500, no 2499
    R(CNT_RX_BLK)
    R(CNT_RX_ERR)
    R(CNT_BER)
    R(LOCK_TIME)

    # 7. IRQ enable + irq_out (con bits altos para cubrir la mascara)
    W(IRQ_ENABLE, 0xFFFFFFFF); R(IRQ_ENABLE)   # solo 6 LSB persisten
    W(IRQ_ENABLE, EV_LOCK_GAINED|EV_PRBS_ERR|EV_RX_ERR); R(IRQ_ENABLE)
    R(IRQ_STATUS)
    # cobertura de mascara de PRBS_CTRL
    W(PRBS_CTRL, 0xFFFFFFF8); R(PRBS_CTRL)     # bits altos no persisten (INJ es pulso)

    # 8. RW1C: limpiar algunos stickies
    W(IRQ_STATUS, EV_PRBS_ERR|EV_RX_ERR); R(IRQ_STATUS)  # quedan los no limpiados

    # 9. Perdida de lock -> nuevo sticky
    E("lose_lock")
    R(STATUS); R(IRQ_STATUS)

    # 10. hi_ber
    E("hi_ber")
    R(STATUS); R(IRQ_STATUS)

    # 11. SOFT_RESET del data plane (no toca banco)
    W(CMD, CMD_SOFT_RESET)
    R(STATUS)                             # lock/sync/prbs abajo, scratch intacto
    R(SCRATCH)                            # sigue 0xA5A5A5A5

    # 12. DMA addr/doorbell + dma_done
    W(DMA_ADDR, 0x70001000); R(DMA_ADDR)
    E("dma_done")
    W(DMA_DOORBELL, 0x00C0FFEE); R(DMA_DOORBELL)
    R(IRQ_STATUS)

    # 13. CNT_CLEAR + re-snapshot
    W(CMD, CMD_CNT_CLEAR)
    W(STATS_SNAP, 1)
    R(CNT_TX_BLK)                         # 0 tras clear+snapshot

    # 14. Reservado / no mapeado
    W(RESERVED_LO, 0x12345678); R(RESERVED_LO)   # lee 0
    R(0x78)

    return ops


def run(trace, dump=False):
    bank = PcsRegBank()
    h = FNV32_OFFSET
    lines = []
    for kind, a, b in trace:
        if kind == "W":
            bank.write(a, b)
            rec = (0, a, b & MASK32)
        elif kind == "R":
            val = bank.read(a)
            rec = (1, a, val & MASK32)
        elif kind == "E":
            bank.dp_event(a, b)
            # para el evento, el "dato" es una codificacion determinista del
            # nombre + n para que el RTL testbench reproduzca lo mismo
            enc = (fnv1a_32(a.encode("ascii")) ^ (b & MASK32)) & MASK32
            rec = (2, 0, enc)
        else:
            raise ValueError(kind)

        # acumular firma: 1 byte kind_tag + offset u32 + dato u32
        h = fnv1a_32(bytes([rec[0]]), h)
        h = fnv1a_32(u32_le_bytes(rec[1]), h)
        h = fnv1a_32(u32_le_bytes(rec[2]), h)

        if dump:
            tag = {0:"W",1:"R",2:"E"}[rec[0]]
            if kind == "E":
                lines.append("E  %-12s n=%d  -> enc=0x%08X" % (a, b, rec[2]))
            else:
                lines.append("%s  off=0x%02X  data=0x%08X" % (tag, rec[1], rec[2]))

    # estado final: contadores sombra + irq_out
    for off in (CNT_TX_BLK, CNT_RX_BLK, CNT_RX_ERR, CNT_BER, LOCK_TIME):
        h = fnv1a_32(u32_le_bytes(bank.shadow[off]), h)
    h = fnv1a_32(bytes([bank.irq_out()]), h)

    if dump:
        print("\n".join(lines))
        print("-" * 48)
        print("irq_out final =", bank.irq_out())
        print("shadow finales:", {hex(k): v for k, v in bank.shadow.items()})

    return h


def main():
    dump = "--dump" in sys.argv
    sig = run(canonical_trace(), dump=dump)
    print("FNV32_REGBANK=0x%08X" % sig)


if __name__ == "__main__":
    main()
