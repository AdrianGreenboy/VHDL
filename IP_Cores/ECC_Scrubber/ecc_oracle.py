#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ecc_oracle.py - Oraculo de referencia del Core 20 (ECC scrubber) de HERCOSSNUX.

Codigo: SECDED (39,32) = Hamming extendido.
  - 32 bits de dato
  - 6 bits de paridad Hamming (p1,p2,p4,p8,p16,p32) en posiciones potencia de 2
  - 1 bit de paridad global (overall) -> distingue 1-bit vs 2-bit
  Total: 39 bits utiles, empaquetados en 64 bits en DDR (bits 63..39 = 0).

Layout Hamming 1-indexado (posiciones 1..38):
  - Posiciones {1,2,4,8,16,32} = paridad Hamming.
  - El resto = bits de dato, en orden ascendente.
  - Bit 39 (indice bit 38 en la palabra) = paridad global sobre bits 1..38.

Empaquetado en la palabra de 39 bits (bit 0 = posicion Hamming 1):
  ecc_word[0..37]  -> posiciones Hamming 1..38
  ecc_word[38]     -> paridad global (overall)

decode() devuelve (data, syndrome, corrected, double_error):
  - syndrome == 0 y overall_ok      -> sin error
  - syndrome != 0 y overall != 0    -> error de 1 bit (corregible) en pos=syndrome
  - syndrome != 0 y overall == 0    -> error de 2 bits (DED, no corregible)
  - syndrome == 0 y overall != 0    -> error en el propio bit overall (1 bit, corregible)
"""

N_POS = 38          # posiciones Hamming 1..38
PARITY_POS = [1, 2, 4, 8, 16, 32]
DATA_POS = [p for p in range(1, N_POS + 1) if p not in PARITY_POS]  # 32 posiciones

assert len(DATA_POS) == 32, f"esperaba 32 posiciones de dato, hay {len(DATA_POS)}"


def _data_bits_to_positions(data):
    """Coloca los 32 bits de dato (data bit 0 = LSB) en sus posiciones Hamming."""
    pos = [0] * (N_POS + 1)  # pos[1..38], pos[0] sin usar
    for i, p in enumerate(DATA_POS):
        pos[p] = (data >> i) & 1
    return pos


def _positions_to_data(pos):
    data = 0
    for i, p in enumerate(DATA_POS):
        data |= (pos[p] & 1) << i
    return data


def _hamming_parity(pos, p):
    """Paridad Hamming para el bit de paridad en posicion p (potencia de 2).
    Cubre toda posicion j cuyo bit (p) este en 1 en su indice, excepto j==p."""
    acc = 0
    for j in range(1, N_POS + 1):
        if j == p:
            continue
        if j & p:
            acc ^= pos[j]
    return acc


def encode(data):
    """data: entero 0..2^32-1 -> palabra ECC de 39 bits (int)."""
    data &= 0xFFFFFFFF
    pos = _data_bits_to_positions(data)
    for p in PARITY_POS:
        pos[p] = _hamming_parity(pos, p)
    # empaquetar posiciones 1..38 en bits 0..37
    word = 0
    for j in range(1, N_POS + 1):
        word |= (pos[j] & 1) << (j - 1)
    # paridad global sobre bits 1..38 -> bit 38
    overall = 0
    for j in range(1, N_POS + 1):
        overall ^= pos[j]
    word |= (overall & 1) << 38
    return word & 0x7FFFFFFFFF  # 39 bits


def _unpack(word):
    pos = [0] * (N_POS + 1)
    for j in range(1, N_POS + 1):
        pos[j] = (word >> (j - 1)) & 1
    overall = (word >> 38) & 1
    return pos, overall


def decode(word):
    """word: palabra ECC de 39 bits (posiblemente corrupta).
    Devuelve (data, syndrome, corrected, double_error).
      corrected:   1 si se corrigio un error de 1 bit.
      double_error:1 si se detecto error de 2 bits (no corregido)."""
    word &= 0x7FFFFFFFFF
    pos, overall = _unpack(word)

    # sindrome Hamming
    syndrome = 0
    for idx, p in enumerate(PARITY_POS):
        if _hamming_parity(pos, p) ^ pos[p]:
            syndrome |= p  # el bit del sindrome ES la posicion Hamming

    # paridad global recalculada sobre bits 1..38
    calc_overall = 0
    for j in range(1, N_POS + 1):
        calc_overall ^= pos[j]
    overall_mismatch = calc_overall ^ overall

    corrected = 0
    double_error = 0

    if syndrome == 0 and overall_mismatch == 0:
        pass  # sin error
    elif overall_mismatch == 1:
        # numero impar de flips -> 1 bit (corregible)
        if syndrome != 0 and syndrome <= N_POS:
            pos[syndrome] ^= 1  # corrige el bit de dato/paridad Hamming
        # si syndrome == 0 -> el error esta en el propio bit overall; dato intacto
        corrected = 1
    else:
        # overall_mismatch == 0 y syndrome != 0 -> numero par de flips -> 2 bits
        double_error = 1

    data = _positions_to_data(pos)
    return data, syndrome, corrected, double_error


def inject(word, mask):
    """Aplica XOR de mask (hasta 39 bits) sobre la palabra ECC."""
    return (word ^ (mask & 0x7FFFFFFFFF)) & 0x7FFFFFFFFF


# ------------------------------------------------------------------ FNV-1a 32
def fnv1a_32(data_bytes):
    h = 0x811C9DC5
    for b in data_bytes:
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def word39_to_bytes(word):
    """Serializa una palabra de 39 bits a 8 bytes little-endian (formato DDR 64b)."""
    return (word & 0x7FFFFFFFFF).to_bytes(8, "little")
