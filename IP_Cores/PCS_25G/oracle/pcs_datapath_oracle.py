#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Core 19 - PCS 64B/66B @ 25G
Oraculo del datapath PCS completo (Layer 4): encoder + scrambler + gearbox.

Compone las piezas ya verificadas individualmente en el datapath end-to-end:

  TX:  payload64 + tipo
        -> encoder (sync header 01/10)
        -> scrambler (scramblea SOLO el payload; sync bypass)
        -> ensamblado bloque 66b [sync(2) | payload_scrambleado(64)]
        -> gearbox TX (66 -> 64)  -> palabras al PMA

  RX (inverso exacto):
        palabras del PMA
        -> gearbox RX (64 -> 66)
        -> split bloque (sync | payload_scrambleado)
        -> descrambler (descramblea SOLO el payload)
        -> decoder (interpreta sync)  -> payload64 + tipo recuperados

Orden critico (IEEE 802.3 clausula 49): el sync header se anade DESPUES de
scramblear, y hace BYPASS del scrambler. El RX descrambla el payload tras
separar el sync.

Verifica el ROUND-TRIP end-to-end: (payload,tipo) -> TX -> RX -> (payload,tipo).
Firma FNV-1a 32-bit sobre las palabras de linea emitidas por el TX.

Reutiliza los modelos de pcs_scrambler_oracle y pcs_gearbox_oracle.
Sin dependencias externas mas alla de esos dos. Python 3.
"""

import sys, os, importlib.util

_HERE = os.path.dirname(os.path.abspath(__file__))

def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, name + ".py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m

scr_mod = _load("pcs_scrambler_oracle")
gb_mod  = _load("pcs_gearbox_oracle")

FNV32_OFFSET = 0x811C9DC5
FNV32_PRIME  = 0x01000193
MASK32       = 0xFFFFFFFF
MASK64       = (1 << 64) - 1

def fnv1a_32(data_bytes, h=FNV32_OFFSET):
    for b in data_bytes:
        h ^= b; h = (h * FNV32_PRIME) & MASK32
    return h

def u64_le(x):
    x &= MASK64
    return bytes([(x >> (8*i)) & 0xFF for i in range(8)])

SYNC_DATA = 0b01
SYNC_CTRL = 0b10


class PcsTxDatapath:
    """Encoder + scrambler + ensamblado + gearbox TX."""
    def __init__(self):
        self.scr = scr_mod.Scrambler()
        self.gb  = gb_mod.TxGearbox()

    def push(self, payload64, is_data=True):
        """Procesa un (payload, tipo). Devuelve lista de palabras de 64b listas."""
        sync = SYNC_DATA if is_data else SYNC_CTRL
        scrambled = self.scr.scramble64(payload64 & MASK64)
        # ensamblar bloque 66b: sync en los 2 LSB, payload scrambleado en 64 altos
        block66 = (sync & 0b11) | ((scrambled & MASK64) << 2)
        self.gb.push_block(block66)
        words = []
        while self.gb.can_pop():
            words.append(self.gb.pop_word())
        return words


class PcsRxDatapath:
    """Gearbox RX + split + descrambler + decoder."""
    def __init__(self):
        self.gb  = gb_mod.RxGearbox()
        self.des = scr_mod.Descrambler()

    def push(self, word64):
        """Procesa una palabra de linea. Devuelve lista de (payload, is_data)."""
        self.gb.push_word(word64 & MASK64)
        out = []
        while self.gb.can_pop():
            block66 = self.gb.pop_block()
            sync = block66 & 0b11
            scrambled = (block66 >> 2) & MASK64
            payload = self.des.descramble64(scrambled)
            is_data = (sync == SYNC_DATA)
            out.append((payload, is_data))
        return out


def canonical_stream():
    """Secuencia determinista de (payload, is_data). 96 elementos (3 periodos)."""
    seq = []
    x = 0x0F1E2D3C4B5A6978
    for i in range(96):
        is_data = (i % 5 != 4)   # 1 de cada 5 es control
        x = ((x << 1) | (((x >> 63) ^ (x >> 62) ^ (x >> 60) ^ (x >> 59)) & 1)) & MASK64
        if i % 11 == 0:
            payload = 0x0000000000000000
        elif i % 11 == 5:
            payload = 0xFFFFFFFFFFFFFFFF
        else:
            payload = x
        seq.append((payload, is_data))
    return seq


def run(dump=False):
    tx = PcsTxDatapath()
    rx = PcsRxDatapath()
    h = FNV32_OFFSET
    lines = []

    stream = canonical_stream()
    recovered = []   # lista de (payload, is_data) recuperados
    nwords = 0

    for payload, is_data in stream:
        words = tx.push(payload, is_data)
        for wd in words:
            nwords += 1
            h = fnv1a_32(u64_le(wd), h)
            # alimentar RX
            for rec in rx.push(wd):
                recovered.append(rec)

    # round-trip: cada (payload,is_data) recuperado == original
    rt_ok = True
    n = len(recovered)
    for i in range(n):
        if recovered[i] != stream[i]:
            rt_ok = False
            if dump:
                lines.append("RT FAIL %d: exp (%016X,%s) got (%016X,%s)" %
                             (i, stream[i][0], stream[i][1],
                              recovered[i][0], recovered[i][1]))

    h = fnv1a_32(bytes([nwords & 0xFF]), h)
    h = fnv1a_32(bytes([1 if rt_ok else 0]), h)

    if dump:
        for i in range(min(5, n)):
            p, d = recovered[i]
            lines.append("rec %2d payload=%016X is_data=%s %s" %
                         (i, p, d, "OK" if recovered[i]==stream[i] else "FAIL"))
        print("\n".join(lines))
        print("-" * 60)
        print("stream in :", len(stream))
        print("palabras  :", nwords)
        print("recuperados:", n)
        print("round-trip OK:", rt_ok)

    return h, rt_ok, nwords, n


def main():
    dump = "--dump" in sys.argv
    sig, rt, nw, nr = run(dump=dump)
    if not rt:
        print("ADVERTENCIA: round-trip fallo", file=sys.stderr)
    print("FNV32_PCSDP=0x%08X" % sig)


if __name__ == "__main__":
    main()
