#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Core 19 - PCS 64B/66B @ 25G
Oraculo de referencia del subsistema de estadisticas + CDC (Layer 2).

Extiende la frontera de Layer 1: ahora el data plane EXISTE. Modela
  * contadores en el dominio DP (390.625 MHz) que incrementan por eventos de
    bloque 66b (tx_block, rx_block, rx_err) y por el checker PRBS (ber)
  * el snapshot atomico: STATS_SNAP congela un registro shadow desde live
  * la CDC de estado: block_lock, scr_sync, prbs_lock, hi_ber cruzan a AXI
  * los efectos de comandos WO/SC sobre el data plane:
      - CNT_CLEAR  -> live counters a 0
      - SOFT_RESET -> baja lock/sync/prbs, resetea el estado del block-sync
      - RESYNC     -> baja block_lock
      - PRBS_RESET -> resetea el LFSR del checker y BER
  * la generacion de eventos sticky por transiciones (lock gained/lost, etc.)

Modelo de tiempo: en Layer 2 razonamos por CICLOS del dominio DP. Cada tick
del data plane procesa como mucho un evento de bloque. La lectura por AXI de
un contador devuelve SIEMPRE el shadow (nunca live), reproduciendo el contrato
de CDC. La firma FNV-1a 32-bit cubre la traza de operaciones AXI + el estado
del data plane muestreado en puntos deterministas.

El RTL de Layer 2 (data plane + CDC + banco) debe reproducir esta firma.
Sin dependencias externas. Python 3.
"""

import sys

# --- FNV-1a 32-bit ----------------------------------------------------------
FNV32_OFFSET = 0x811C9DC5
FNV32_PRIME  = 0x01000193
MASK32       = 0xFFFFFFFF

def fnv1a_32(data_bytes, h=FNV32_OFFSET):
    for b in data_bytes:
        h ^= b
        h = (h * FNV32_PRIME) & MASK32
    return h

def u32_le(x):
    x &= MASK32
    return bytes([x & 0xFF, (x >> 8) & 0xFF, (x >> 16) & 0xFF, (x >> 24) & 0xFF])

# --- Bits (reutilizados de Layer 1) -----------------------------------------
ST_BLOCK_LOCK = 1 << 0
ST_HI_BER     = 1 << 1
ST_SCR_SYNC   = 1 << 2
ST_PRBS_LOCK  = 1 << 3
ST_TX_ACTIVE  = 1 << 5
ST_RX_ACTIVE  = 1 << 6

EV_LOCK_GAINED = 1 << 0
EV_LOCK_LOST   = 1 << 1
EV_HI_BER      = 1 << 2
EV_RX_ERR      = 1 << 3
EV_PRBS_ERR    = 1 << 4
EV_DMA_DONE    = 1 << 5
IRQ_MASK       = 0x3F

# Umbral de block-lock: 64 sync-headers validos consecutivos (64B/66B real,
# IEEE 802.3 clausula 49). Opcion B: mismo valor en RTL, oraculo y silicio.
LOCK_THRESHOLD = 64
# Umbral hi_ber: sync-header errors dentro de una ventana (16 en el estandar).
HIBER_THRESHOLD = 16


class DataPlane:
    """
    Modela el data plane del PCS en el dominio de 390.625 MHz.
    Los contadores 'live' viven aqui. El shadow es el snapshot congelado.
    """
    def __init__(self):
        # contadores en vuelo
        self.tx_blk = 0
        self.rx_blk = 0
        self.rx_err = 0
        self.ber    = 0
        self.lock_time = 0

        # shadow (lo que lee AXI)
        self.sh_tx = 0
        self.sh_rx = 0
        self.sh_rxerr = 0
        self.sh_ber = 0
        self.sh_lockt = 0

        # estado del block-sync
        self.consec_good = 0     # headers validos consecutivos
        self.block_lock = 0
        self.scr_sync = 0
        self.prbs_lock = 0
        self.hi_ber = 0
        self.tx_active = 0
        self.rx_active = 0
        self.hiber_window_err = 0

        self.cycle = 0           # ticks del dominio DP
        self._prev_lock = 0

        # stickies acumulados (dominio AXI, ya cruzados)
        self.sticky = 0

    # -- procesar un tick con un evento opcional de bloque --
    def tick(self, block=None):
        """
        block puede ser:
          None      -> tick idle
          'tx'      -> se transmite un bloque 66b valido
          'rx_ok'   -> se recibe un bloque con sync-header valido
          'rx_bad'  -> se recibe un bloque con sync-header invalido
          'prbs_bad'-> el checker PRBS detecta un bit error
        """
        self.cycle += 1

        if block == 'tx':
            self.tx_blk = (self.tx_blk + 1) & MASK32
            self.tx_active = 1

        elif block == 'rx_ok':
            self.rx_blk = (self.rx_blk + 1) & MASK32
            self.rx_active = 1
            self.consec_good += 1
            if self.consec_good >= LOCK_THRESHOLD and self.block_lock == 0:
                self.block_lock = 1
                self.scr_sync = 1  # sync del descrambler acompana al lock
                self.lock_time = self.cycle

        elif block == 'rx_bad':
            self.rx_blk = (self.rx_blk + 1) & MASK32
            self.rx_active = 1
            self.rx_err = (self.rx_err + 1) & MASK32
            self.consec_good = 0
            self.hiber_window_err += 1
            if self.hiber_window_err >= HIBER_THRESHOLD:
                self.hi_ber = 1
            # perder lock si estaba enganchado
            if self.block_lock == 1:
                self.block_lock = 0
                self.scr_sync = 0

        elif block == 'prbs_bad':
            self.ber = (self.ber + 1) & MASK32

        # deteccion de PRBS lock: tras suficientes rx_ok con checker activo.
        # Aqui lo ligamos a block_lock por simplicidad del modelo L2.
        if self.block_lock == 1:
            self.prbs_lock = 1

        # generar stickies por transiciones
        if self._prev_lock == 0 and self.block_lock == 1:
            self.sticky |= EV_LOCK_GAINED
        if self._prev_lock == 1 and self.block_lock == 0:
            self.sticky |= EV_LOCK_LOST
        self._prev_lock = self.block_lock

        if block == 'rx_bad':
            self.sticky |= EV_RX_ERR
            if self.hi_ber:
                self.sticky |= EV_HI_BER
        if block == 'prbs_bad':
            self.sticky |= EV_PRBS_ERR

    # -- comandos WO/SC del banco --
    def cmd_cnt_clear(self):
        self.tx_blk = 0; self.rx_blk = 0; self.rx_err = 0; self.ber = 0

    def cmd_soft_reset(self):
        self.block_lock = 0; self.scr_sync = 0; self.prbs_lock = 0
        self.consec_good = 0; self.hi_ber = 0; self.hiber_window_err = 0
        self._prev_lock = 0

    def cmd_resync(self):
        self.block_lock = 0; self.consec_good = 0; self._prev_lock = 0

    def cmd_prbs_reset(self):
        self.ber = 0; self.prbs_lock = 0

    def cmd_dma_done(self):
        self.sticky |= EV_DMA_DONE

    # -- snapshot atomico --
    def snapshot(self):
        self.sh_tx    = self.tx_blk
        self.sh_rx    = self.rx_blk
        self.sh_rxerr = self.rx_err
        self.sh_ber   = self.ber
        self.sh_lockt = self.lock_time

    # -- clear RW1C de stickies (desde AXI) --
    def clear_sticky(self, mask):
        self.sticky &= (~mask) & IRQ_MASK

    def status_word(self):
        w = 0
        if self.block_lock: w |= ST_BLOCK_LOCK
        if self.hi_ber:     w |= ST_HI_BER
        if self.scr_sync:   w |= ST_SCR_SYNC
        if self.prbs_lock:  w |= ST_PRBS_LOCK
        if self.tx_active:  w |= ST_TX_ACTIVE
        if self.rx_active:  w |= ST_RX_ACTIVE
        return w


# ---------------------------------------------------------------------------
# Traza canonica de Layer 2. Mezcla:
#   ('run', pattern, n)  -> el data plane procesa n ticks con un patron
#   ('cmd', name)        -> comando WO/SC
#   ('snap',)            -> STATS_SNAP
#   ('rd_cnt',)          -> lectura AXI de los 5 contadores shadow
#   ('rd_status',)       -> lectura AXI de STATUS
#   ('rd_irq',)          -> lectura AXI de IRQ_STATUS
#   ('clr_irq', mask)    -> escritura RW1C de IRQ_STATUS
# ---------------------------------------------------------------------------
def canonical_trace():
    ops = []
    # arranque: correr idle un poco
    ops.append(('run', 'idle', 5))
    # transmitir 50 bloques
    ops.append(('run', 'tx', 50))
    ops.append(('rd_status',))
    # recibir 70 bloques buenos -> supera LOCK_THRESHOLD (64) -> lock
    ops.append(('run', 'rx_ok', 70))
    ops.append(('rd_status',))          # block_lock, scr_sync, prbs_lock = 1
    ops.append(('rd_irq',))             # EV_LOCK_GAINED sticky
    # snapshot y lectura de contadores
    ops.append(('snap',))
    ops.append(('run', 'tx', 10))       # cambia live, no shadow
    ops.append(('rd_cnt',))
    # inyectar 3 bloques malos -> rx_err, pierde lock
    ops.append(('run', 'rx_bad', 3))
    ops.append(('rd_status',))          # block_lock = 0
    ops.append(('rd_irq',))             # EV_LOCK_LOST + EV_RX_ERR
    # recuperar lock
    ops.append(('run', 'rx_ok', 70))
    ops.append(('rd_status',))
    # inyectar errores PRBS
    ops.append(('run', 'prbs_bad', 5))
    ops.append(('rd_irq',))             # EV_PRBS_ERR
    # forzar hi_ber: 16 bloques malos (supera HIBER_THRESHOLD)
    ops.append(('run', 'rx_bad', 16))
    ops.append(('rd_status',))          # hi_ber = 1
    ops.append(('rd_irq',))
    # limpiar algunos stickies
    ops.append(('clr_irq', EV_RX_ERR | EV_PRBS_ERR))
    ops.append(('rd_irq',))
    # snapshot de nuevo y leer contadores acumulados
    ops.append(('snap',))
    ops.append(('rd_cnt',))
    # comando CNT_CLEAR, snapshot, leer -> 0
    ops.append(('cmd', 'cnt_clear'))
    ops.append(('snap',))
    ops.append(('rd_cnt',))
    # SOFT_RESET -> baja lock, leer status
    ops.append(('cmd', 'soft_reset'))
    ops.append(('rd_status',))

    # --- cobertura de borde del umbral de lock ---
    # exactamente 63 rx_ok: NO debe lockear (borde inferior)
    ops.append(('run', 'rx_ok', 63))
    ops.append(('rd_status',))          # block_lock debe seguir 0
    # 1 rx_ok mas (total 64): DEBE lockear justo en el umbral
    ops.append(('run', 'rx_ok', 1))
    ops.append(('rd_status',))          # block_lock = 1
    # --- soft_reset CON lock activo: debe bajarlo ---
    ops.append(('cmd', 'soft_reset'))
    ops.append(('rd_status',))          # block_lock = 0 (verifica que soft_reset baja lock activo)

    # dma_done sticky
    ops.append(('cmd', 'dma_done'))
    ops.append(('rd_irq',))
    return ops


def run(trace, dump=False):
    dp = DataPlane()
    h = FNV32_OFFSET
    lines = []

    def acc_tag(tag, val):
        nonlocal h
        h = fnv1a_32(bytes([tag]), h)
        h = fnv1a_32(u32_le(val), h)

    pat_map = {'idle': None, 'tx': 'tx', 'rx_ok': 'rx_ok',
               'rx_bad': 'rx_bad', 'prbs_bad': 'prbs_bad'}

    for op in trace:
        kind = op[0]
        if kind == 'run':
            _, pattern, n = op
            blk = pat_map[pattern]
            for _ in range(n):
                dp.tick(blk)
            # acumular firma del patron: tag 0 + (hash del patron ^ n)
            enc = (fnv1a_32(pattern.encode('ascii')) ^ (n & MASK32)) & MASK32
            acc_tag(0, enc)
            if dump: lines.append("run %-8s n=%d  live tx=%d rx=%d err=%d ber=%d lock=%d" %
                                  (pattern, n, dp.tx_blk, dp.rx_blk, dp.rx_err, dp.ber, dp.block_lock))
        elif kind == 'cmd':
            name = op[1]
            getattr(dp, 'cmd_' + name)()
            acc_tag(1, fnv1a_32(name.encode('ascii')))
            if dump: lines.append("cmd %s" % name)
        elif kind == 'snap':
            dp.snapshot()
            acc_tag(2, 0)
            if dump: lines.append("snap -> sh tx=%d rx=%d err=%d ber=%d lockt=%d" %
                                  (dp.sh_tx, dp.sh_rx, dp.sh_rxerr, dp.sh_ber, dp.sh_lockt))
        elif kind == 'rd_cnt':
            # lock_time (sh_lockt) se EXCLUYE de la firma: es un timestamp
            # absoluto de ciclo, sensible al timing de arranque del testbench,
            # no un invariante funcional. Se observa por AXI pero no se firma.
            for v in (dp.sh_tx, dp.sh_rx, dp.sh_rxerr, dp.sh_ber):
                acc_tag(3, v)
            if dump: lines.append("rd_cnt sh=(%d,%d,%d,%d) [lockt=%d no-firmado]" %
                                  (dp.sh_tx, dp.sh_rx, dp.sh_rxerr, dp.sh_ber, dp.sh_lockt))
        elif kind == 'rd_status':
            acc_tag(4, dp.status_word())
            if dump: lines.append("rd_status = 0x%02X" % dp.status_word())
        elif kind == 'rd_irq':
            acc_tag(5, dp.sticky & IRQ_MASK)
            if dump: lines.append("rd_irq = 0x%02X" % (dp.sticky & IRQ_MASK))
        elif kind == 'clr_irq':
            dp.clear_sticky(op[1])
            acc_tag(6, op[1] & IRQ_MASK)
            if dump: lines.append("clr_irq mask=0x%02X -> 0x%02X" % (op[1], dp.sticky & IRQ_MASK))
        else:
            raise ValueError(kind)

    # cierre: estado final del data plane (lock_time excluido, ver rd_cnt)
    for v in (dp.sh_tx, dp.sh_rx, dp.sh_rxerr, dp.sh_ber):
        h = fnv1a_32(u32_le(v), h)
    h = fnv1a_32(bytes([dp.status_word() & 0xFF]), h)
    h = fnv1a_32(bytes([dp.sticky & 0xFF]), h)

    if dump:
        print("\n".join(lines))
        print("-" * 52)
        print("final status=0x%02X sticky=0x%02X" % (dp.status_word(), dp.sticky))

    return h


def main():
    dump = "--dump" in sys.argv
    sig = run(canonical_trace(), dump=dump)
    print("FNV32_STATS=0x%08X" % sig)


if __name__ == "__main__":
    main()
