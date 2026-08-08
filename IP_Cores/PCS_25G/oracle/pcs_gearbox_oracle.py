#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Core 19 - PCS 64B/66B @ 25G
Oraculo de referencia del gearbox 66<->64 (Layer 4).

El gearbox adapta entre bloques de 66 bits (PCS) y palabras de 64 bits (PMA):

  * TX GEARBOX (66 -> 64): recibe bloques de 66 bits, empaqueta sus bits sin
    huecos en un buffer, y emite palabras de 64 bits. La relacion es 32:33 ->
    cada 32 bloques de entrada (32*66 = 2112 bits) salen exactamente 33 palabras
    de 64 bits (33*64 = 2112). El estado se repite con periodo 32/33.

  * RX GEARBOX (64 -> 66): operacion inversa. Recibe palabras de 64 bits, las
    acumula, y extrae bloques de 66 bits. En un enlace real, ademas hace el
    block-sync (buscar la alineacion), pero eso lo maneja el data plane; aqui el
    gearbox RX asume alineacion conocida (sincronizado).

Convencion de bits: los bits se empaquetan LSB-first. El bit 0 del primer bloque
va al bit 0 de la primera palabra de salida. El buffer es una cola FIFO de bits.

ROUND-TRIP: rx_gearbox(tx_gearbox(bloques)) == bloques (tras el fill inicial).

Firma FNV-1a 32-bit sobre las palabras de 64 bits emitidas por el TX gearbox.
Sin dependencias externas. Python 3.
"""

import sys

FNV32_OFFSET = 0x811C9DC5
FNV32_PRIME  = 0x01000193
MASK32       = 0xFFFFFFFF
MASK64       = (1 << 64) - 1

def fnv1a_32(data_bytes, h=FNV32_OFFSET):
    for b in data_bytes:
        h ^= b
        h = (h * FNV32_PRIME) & MASK32
    return h

def u64_le(x):
    x &= MASK64
    return bytes([(x >> (8*i)) & 0xFF for i in range(8)])


class TxGearbox:
    """
    66 -> 64. Buffer de bits FIFO (lista de bits, LSB primero).
    push_block: mete 66 bits. pop_word: saca 64 bits si hay >= 64.
    """
    def __init__(self):
        self.buf = []  # lista de bits, buf[0] = mas antiguo (sale primero)

    def push_block(self, block66):
        """block66: entero de 66 bits. Se empaqueta LSB primero."""
        for i in range(66):
            self.buf.append((block66 >> i) & 1)

    def can_pop(self):
        return len(self.buf) >= 64

    def pop_word(self):
        """Extrae 64 bits del frente del buffer -> palabra de 64 bits."""
        assert len(self.buf) >= 64
        word = 0
        for i in range(64):
            word |= (self.buf[i] << i)
        self.buf = self.buf[64:]
        return word & MASK64


class RxGearbox:
    """
    64 -> 66. Inverso: acumula palabras de 64, extrae bloques de 66.
    """
    def __init__(self):
        self.buf = []

    def push_word(self, word64):
        for i in range(64):
            self.buf.append((word64 >> i) & 1)

    def can_pop(self):
        return len(self.buf) >= 66

    def pop_block(self):
        assert len(self.buf) >= 66
        block = 0
        for i in range(66):
            block |= (self.buf[i] << i)
        self.buf = self.buf[66:]
        return block


def make_block66(sync2, payload64):
    """Ensambla un bloque de 66 bits: sync en los 2 LSB, payload en los 64 altos.
    Convencion: bit0-1 = sync header, bit2-65 = payload."""
    return (sync2 & 0b11) | ((payload64 & MASK64) << 2)

def split_block66(block66):
    sync2 = block66 & 0b11
    payload64 = (block66 >> 2) & MASK64
    return sync2, payload64


def canonical_blocks():
    """Genera 96 bloques de 66 bits deterministas (3 periodos de 32).
    Patrones variados para ejercitar distintos estados de fill del gearbox."""
    blocks = []
    x = 0xABCDEF0123456789
    for i in range(96):
        # sync alterna data/control de forma determinista
        sync = 0b01 if (i % 4 != 3) else 0b10
        x = ((x << 1) | (((x >> 63) ^ (x >> 60) ^ (x >> 59) ^ (x >> 58)) & 1)) & MASK64
        # inyectar patrones extremos periodicamente para cubrir bordes
        if i % 7 == 0:
            payload = 0x0000000000000000
        elif i % 7 == 3:
            payload = 0xFFFFFFFFFFFFFFFF
        else:
            payload = x
        blocks.append(make_block66(sync, payload))
    return blocks


def run(dump=False):
    tx = TxGearbox()
    rx = RxGearbox()
    h = FNV32_OFFSET
    lines = []

    blocks = canonical_blocks()
    words_out = []

    # TX: empujar bloques y sacar palabras a medida que se puede
    recovered = []
    for bidx, blk in enumerate(blocks):
        tx.push_block(blk)
        while tx.can_pop():
            word = tx.pop_word()
            words_out.append(word)
            h = fnv1a_32(u64_le(word), h)
            # alimentar el RX inmediatamente
            rx.push_word(word)
            while rx.can_pop():
                recovered.append(rx.pop_block())

    # verificar round-trip: los bloques recuperados deben coincidir con los
    # originales (los que se hayan podido extraer; el ultimo puede quedar en buffer)
    rt_ok = True
    n_check = len(recovered)
    for i in range(n_check):
        if recovered[i] != blocks[i]:
            rt_ok = False
            if dump:
                lines.append("RT FAIL blk %d: exp %017X got %017X" %
                             (i, blocks[i], recovered[i]))

    # verificar la relacion 32:33 -> N bloques de 66 bits dan N*66/64 palabras
    expected_words = (len(blocks) * 66) // 64
    ratio_ok = (len(words_out) == expected_words)

    h = fnv1a_32(bytes([len(words_out) & 0xFF]), h)
    h = fnv1a_32(bytes([1 if rt_ok else 0]), h)

    if dump:
        for i, w in enumerate(words_out[:8]):
            lines.append("word %2d = %016X" % (i, w))
        lines.append("...")
        print("\n".join(lines))
        print("-" * 60)
        print("bloques entrada:", len(blocks))
        print("palabras salida:", len(words_out), "(esperado 66 para 64 bloques)")
        print("bloques recuperados:", n_check)
        print("round-trip OK:", rt_ok)
        print("ratio 32:33 OK:", ratio_ok)

    return h, rt_ok, ratio_ok, len(words_out)


def main():
    dump = "--dump" in sys.argv
    sig, rt, ratio, nwords = run(dump=dump)
    if not rt:
        print("ADVERTENCIA: round-trip fallo", file=sys.stderr)
    if not ratio:
        print("ADVERTENCIA: ratio 32:33 incorrecto (%d palabras)" % nwords, file=sys.stderr)
    print("FNV32_GEARBOX=0x%08X" % sig)


if __name__ == "__main__":
    main()
