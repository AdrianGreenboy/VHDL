#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Core 19 - PCS 64B/66B @ 25G
Oraculo de referencia del PCS: encoder 64B/66B + scrambler/descrambler (Layer 4).

Implementa la codificacion de linea de 10GBASE-R / 25GBASE-R (IEEE 802.3
clausula 49):

  * ENCODER TX: toma 64 bits de payload + tipo (data/control) -> bloque de 66
    bits [sync_header(2) | payload(64)]. sync = "01" (data) o "10" (control).
  * SCRAMBLER: self-synchronizing, polinomio G(x) = 1 + x^39 + x^58.
    Version PARALELA de 64 bits (procesa las 64 bits de payload de golpe por
    ciclo). El estado del LFSR (58 bits) se propaga entre bloques. Los 2 bits
    de sync header hacen BYPASS (no se scramblean).
  * DESCRAMBLER RX: misma estructura, la entrada es el dato scrambleado
    recibido. Self-synchronizing: recupera el dato sin seed compartido.
  * ROUND-TRIP: descramble(scramble(x)) == x tras la sincronizacion.

Referencia de bit-order (IEEE 802.3-2008 Fig 49-8): el scrambler procesa los
bits del payload en orden de transmision. Aqui usamos la convencion LSB-first
del payload dentro del LFSR, consistente con la implementacion paralela
estandar. El RTL debe reproducir bit a bit la salida.

Firma FNV-1a 32-bit sobre la traza de bloques scrambleados + el round-trip.
Sin dependencias externas. Python 3.
"""

import sys

FNV32_OFFSET = 0x811C9DC5
FNV32_PRIME  = 0x01000193
MASK32       = 0xFFFFFFFF
MASK58       = (1 << 58) - 1
MASK64       = (1 << 64) - 1

def fnv1a_32(data_bytes, h=FNV32_OFFSET):
    for b in data_bytes:
        h ^= b
        h = (h * FNV32_PRIME) & MASK32
    return h

def u64_le(x):
    x &= MASK64
    return bytes([(x >> (8*i)) & 0xFF for i in range(8)])


class Scrambler:
    """
    Scrambler self-synchronizing 64b/66b, polinomio 1 + x^39 + x^58.
    Implementacion paralela: procesa 64 bits de payload por llamada.

    Modelo serie de referencia (por bit, LSB primero del payload):
       scrambled_bit = data_bit XOR state[38] XOR state[57]
       nuevo_state = (state << 1) | scrambled_bit   (mantener 58 bits)
    El scrambled_bit realimenta el shift register (self-synchronizing).

    La version paralela aplica esta recurrencia 64 veces, actualizando el
    estado, y devuelve los 64 bits scrambleados de una vez.
    """
    def __init__(self, state=None):
        # sin requisito de seed; el estandar no lo exige. Usamos all-ones como
        # valor inicial canonico (coincide con muchas implementaciones).
        self.state = MASK58 if state is None else (state & MASK58)

    def scramble64(self, payload):
        """payload: entero de 64 bits. Devuelve 64 bits scrambleados."""
        s = self.state
        out = 0
        for i in range(64):
            din = (payload >> i) & 1
            fb = ((s >> 38) & 1) ^ ((s >> 57) & 1)
            sbit = din ^ fb
            out |= (sbit << i)
            s = ((s << 1) | sbit) & MASK58
        self.state = s
        return out & MASK64


class Descrambler:
    """
    Descrambler self-synchronizing, mismo polinomio.
    Modelo serie de referencia (por bit):
       data_bit = scrambled_bit XOR state[38] XOR state[57]
       nuevo_state = (state << 1) | scrambled_bit   (la ENTRADA es el scrambled)
    Se sincroniza solo: tras 58 bits el estado replica al del scrambler.
    """
    def __init__(self, state=None):
        self.state = MASK58 if state is None else (state & MASK58)

    def descramble64(self, scrambled):
        s = self.state
        out = 0
        for i in range(64):
            sin = (scrambled >> i) & 1
            fb = ((s >> 38) & 1) ^ ((s >> 57) & 1)
            dout = sin ^ fb
            out |= (dout << i)
            s = ((s << 1) | sin) & MASK58   # realimenta el bit RECIBIDO
        self.state = s
        return out & MASK64


# --- Encoder 64B/66B ---------------------------------------------------------
SYNC_DATA = 0b01   # payload es datos
SYNC_CTRL = 0b10   # payload contiene control

def encode_block(payload64, is_data=True):
    """Devuelve (sync_header, payload_scrambled) — el scrambling lo hace el caller."""
    sync = SYNC_DATA if is_data else SYNC_CTRL
    return sync, payload64 & MASK64


# --- Traza canonica ----------------------------------------------------------
def canonical_payloads():
    """Secuencia determinista de (payload64, is_data) para la traza."""
    seq = []
    # patrones representativos: ceros, unos, alternados, incrementales, aleatorio-det
    seq.append((0x0000000000000000, True))
    seq.append((0xFFFFFFFFFFFFFFFF, True))
    seq.append((0xAAAAAAAAAAAAAAAA, True))
    seq.append((0x5555555555555555, True))
    seq.append((0x0123456789ABCDEF, True))
    seq.append((0xFEDCBA9876543210, True))
    seq.append((0xDEADBEEFCAFEBABE, True))
    seq.append((0x8000000000000000, True))
    seq.append((0x0000000000000001, True))
    seq.append((0xC0FFEE00C0FFEE00, False))  # control
    # LFSR determinista para 20 bloques mas
    x = 0x1234567890ABCDEF
    for _ in range(20):
        x = ((x << 1) | (((x >> 63) ^ (x >> 60) ^ (x >> 59) ^ (x >> 58)) & 1)) & MASK64
        seq.append((x, True))
    return seq


def run(dump=False):
    scr = Scrambler()
    des = Descrambler()
    h = FNV32_OFFSET
    lines = []

    payloads = canonical_payloads()
    roundtrip_ok = True

    for idx, (payload, is_data) in enumerate(payloads):
        sync, p = encode_block(payload, is_data)
        scrambled = scr.scramble64(p)
        # descramble en el receptor
        recovered = des.descramble64(scrambled)

        # round-trip: tras el primer bloque (58 bits << 64) ya esta sincronizado
        if idx >= 1 and recovered != payload:
            roundtrip_ok = False
            if dump:
                lines.append("BLOQUE %d ROUND-TRIP FAIL: exp %016X got %016X" %
                             (idx, payload, recovered))

        # acumular firma: sync header + scrambled (el artefacto de linea)
        h = fnv1a_32(bytes([sync]), h)
        h = fnv1a_32(u64_le(scrambled), h)

        if dump:
            lines.append("blk %2d sync=%s payload=%016X scrambled=%016X recovered=%016X %s" %
                         (idx, format(sync, '02b'), payload, scrambled, recovered,
                          "OK" if (idx < 1 or recovered == payload) else "FAIL"))

    # el estado final del scrambler entra en la firma (verifica propagacion)
    h = fnv1a_32(u64_le(scr.state & MASK64), h)
    h = fnv1a_32(bytes([1 if roundtrip_ok else 0]), h)

    if dump:
        print("\n".join(lines))
        print("-" * 60)
        print("scrambler state final = 0x%015X" % scr.state)
        print("round-trip OK =", roundtrip_ok)

    return h, roundtrip_ok


def main():
    dump = "--dump" in sys.argv
    sig, rt = run(dump=dump)
    if not rt:
        print("ADVERTENCIA: round-trip fallo", file=sys.stderr)
    print("FNV32_PCS=0x%08X" % sig)


if __name__ == "__main__":
    main()
