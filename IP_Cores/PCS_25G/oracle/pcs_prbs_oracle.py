#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Core 19 - PCS 64B/66B @ 25G
Oraculo de referencia del PRBS31 (Layer 4): generador + checker.

IEEE 802.3 clausula 49 (Fig 49-9 generador, Fig 49-11 checker):
  * Polinomio G(x) = 1 + x^28 + x^31 (ecuacion 49-2).
  * El patron es la version INVERTIDA del bit stream del polinomio.
  * El valor inicial del generador no debe ser todo ceros.
  * GENERADOR: LFSR con feedback. Sin entrada externa; el patron esta
    completamente definido por el polinomio + estado inicial.
  * CHECKER: feed-forward (sin feedback). Recibe el stream, reconstruye la
    prediccion y compara; cuenta bit errors. Self-synchronizing.

Implementacion PARALELA de 64 bits: procesa 64 bits de patron por ciclo.

Recurrencia serie del generador (LFSR de 31 bits, taps 31 y 28):
  bit_out = state[30] XOR state[27]    (correspondiente a x^31 + x^28)
  state = (state << 1) | bit_out
El patron transmitido es la version invertida: tx_bit = NOT bit_out.

Checker (feed-forward): recibe rx_bit. Reconstruye la prediccion a partir de
los bits recibidos previos (mismo shift register alimentado por rx):
  predicted = rx_state[30] XOR rx_state[27]
  error = rx_bit XOR (NOT predicted)   (cuenta si difiere)
  rx_state = (rx_state << 1) | (NOT rx_bit)   (realimenta el bit recibido)

Firma FNV-1a 32-bit sobre las palabras de patron generadas + conteo de errores.
Sin dependencias externas. Python 3.
"""

import sys

FNV32_OFFSET = 0x811C9DC5
FNV32_PRIME  = 0x01000193
MASK32       = 0xFFFFFFFF
MASK64       = (1 << 64) - 1
MASK31       = (1 << 31) - 1

def fnv1a_32(data_bytes, h=FNV32_OFFSET):
    for b in data_bytes:
        h ^= b; h = (h * FNV32_PRIME) & MASK32
    return h

def u64_le(x):
    x &= MASK64
    return bytes([(x >> (8*i)) & 0xFF for i in range(8)])


class Prbs31Gen:
    """
    Generador PRBS31 paralelo. Polinomio x^31 + x^28 + 1, salida invertida.
    Estado de 31 bits (no todo ceros).
    """
    def __init__(self, seed=None):
        # seed canonico: all-ones de 31 bits (no todo ceros)
        self.state = MASK31 if seed is None else (seed & MASK31)
        if self.state == 0:
            self.state = MASK31

    def gen64(self):
        """Genera 64 bits de patron (LSB primero). Devuelve entero de 64 bits."""
        s = self.state
        out = 0
        for i in range(64):
            fb = ((s >> 30) & 1) ^ ((s >> 27) & 1)  # x^31 + x^28
            tx_bit = fb ^ 1                          # version invertida
            out |= (tx_bit << i)
            s = ((s << 1) | fb) & MASK31             # el LFSR realimenta fb
        self.state = s
        return out & MASK64


class Prbs31Chk:
    """
    Checker PRBS31 paralelo con RE-LOCK automatico, GRANULARIDAD DE PALABRA
    (microarquitectura amigable a hardware):

      * el estado del LFSR se alimenta feed-forward BIT a BIT (necesario para
        la self-synchronization), pero el control (sync, ventana, conteo) opera
        por PALABRA:
        - UNLOCKED: cada palabra consume 64 bits de sync; locked cuando
          synced_bits >= 31 (la verificacion empieza en la palabra SIGUIENTE).
        - LOCKED: err_vec por bit (comparacion superficial) -> popcount -> el
          contador BER suma el popcount de la palabra (arbol, no cadena de 64
          incrementos en serie).
        - ventana de re-lock evaluada por palabra: win_bits += 64,
          win_errs += popcount; si al cierre de ventana win_errs > THRESHOLD,
          se descarta el estado de sync (re-engancha a la fase actual).

    err_count solo acumula en LOCKED, como un instrumento real.
    """
    WINDOW = 512       # bits de ventana para evaluar la tasa de error
    THRESHOLD = 64     # errores en la ventana que disparan re-lock

    def __init__(self):
        self.state = 0
        self.synced_bits = 0
        self.locked = False
        self.win_bits = 0
        self.win_errs = 0
        self.err_count = 0

    def check64(self, rx_word):
        s = self.state
        was_locked = self.locked
        nerr = 0
        for i in range(64):
            rx_bit = (rx_word >> i) & 1
            data_bit = rx_bit ^ 1
            if was_locked:
                predicted = ((s >> 30) & 1) ^ ((s >> 27) & 1)
                if data_bit != predicted:
                    nerr += 1
            s = ((s << 1) | data_bit) & MASK31
        self.state = s

        if not was_locked:
            # palabra completa consumida para sync
            self.synced_bits += 64
            if self.synced_bits >= 31:
                self.locked = True
                self.win_bits = 0
                self.win_errs = 0
            return 0
        else:
            self.err_count += nerr
            self.win_errs += nerr
            self.win_bits += 64
            if self.win_bits >= self.WINDOW:
                if self.win_errs > self.THRESHOLD:
                    self.locked = False
                    self.synced_bits = 0
                self.win_bits = 0
                self.win_errs = 0
            return nerr


def run(dump=False):
    gen = Prbs31Gen()
    chk = Prbs31Chk()
    h = FNV32_OFFSET
    lines = []

    NWORDS = 40
    total_errors = 0
    words = []

    # fase 1: gen -> check limpio, BER debe ser 0 (tras sincronizacion)
    for i in range(NWORDS):
        wd = gen.gen64()
        words.append(wd)
        err = chk.check64(wd)
        total_errors += err
        h = fnv1a_32(u64_le(wd), h)
        if dump and i < 5:
            lines.append("word %2d = %016X  err=%d" % (i, wd, err))

    clean_errors = total_errors

    # fase 2: inyectar errores conocidos y verificar que el checker los cuenta.
    # Esto es una PROPIEDAD (detected >= injected), NO entra en la firma
    # bit-identica, porque la multiplicacion de errores del checker
    # self-synchronous depende del patron y no es el objeto de la firma.
    gen2 = Prbs31Gen(seed=0x5A5A5A5)
    chk2 = Prbs31Chk()
    inj_total = 0
    detected = 0
    for _ in range(2):
        chk2.check64(gen2.gen64())
    for i in range(10):
        wd = gen2.gen64()
        corrupted = wd ^ (1 << (i % 64))
        inj_total += 1
        err = chk2.check64(corrupted)
        detected += err

    # la firma cubre: palabras de fase 1 + clean_errors + flag de deteccion
    h = fnv1a_32(bytes([clean_errors & 0xFF]), h)
    h = fnv1a_32(bytes([1 if detected >= inj_total else 0]), h)

    if dump:
        print("\n".join(lines))
        print("-" * 50)
        print("fase 1 (limpio): errores =", clean_errors, "(esperado 0)")
        print("fase 2 (inyeccion):", inj_total, "errores inyectados,", detected, "detectados")
        print("checker detecta inyecciones:", detected >= inj_total)

    return h, clean_errors, inj_total, detected


def main():
    dump = "--dump" in sys.argv
    sig, clean, inj, det = run(dump=dump)
    if clean != 0:
        print("ADVERTENCIA: BER no cero en fase limpia (%d)" % clean, file=sys.stderr)
    if det < inj:
        print("ADVERTENCIA: checker no detecto todas las inyecciones", file=sys.stderr)
    print("FNV32_PRBS=0x%08X" % sig)


if __name__ == "__main__":
    main()
