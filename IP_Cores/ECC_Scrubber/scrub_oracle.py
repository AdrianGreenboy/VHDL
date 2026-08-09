#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scrub_oracle.py - Oraculo de barrido (Layer 2) del ECC scrubber, Core 20.

Modela la FSM de scrubbing sobre una region de N palabras de 39 bits:
  - recorre la region palabra a palabra (indice 0..N-1)
  - decodifica cada palabra
  - si error de 1 bit (corrected): reescribe la palabra corregida (RCW),
    incrementa CE_COUNT, actualiza sticky first/last
  - si error de 2 bits (double_error): NO reescribe, incrementa DED_COUNT,
    actualiza sticky first/last
  - palabras limpias quedan intactas

Produce:
  - memoria final (lista de palabras de 39 bits tras el barrido)
  - CE_COUNT, DED_COUNT
  - FIRST_ADDR/FIRST_SYN, LAST_ADDR/LAST_SYN (con flags was_ce/was_ded)
  - firma FNV de (memoria_final || contadores || sticky)
"""
from ecc_oracle import encode, decode, fnv1a_32, word39_to_bytes


def scrub_region(words):
    """words: lista de enteros de 39 bits (posiblemente corruptos).
    Devuelve dict con memoria final, contadores, sticky y firma."""
    mem = list(words)
    ce = 0
    ded = 0
    first = None   # (addr, syn, was_ce, was_ded)
    last = None

    for addr in range(len(mem)):
        data, syn, cor, de = decode(mem[addr])
        if cor == 1:
            mem[addr] = encode(data)   # writeback corregido
            ce += 1
            rec = (addr, syn, 1, 0)
            if first is None:
                first = rec
            last = rec
        elif de == 1:
            ded += 1
            rec = (addr, syn, 0, 1)
            if first is None:
                first = rec
            last = rec
        # limpia: sin cambios

    if first is None:
        first = (0, 0, 0, 0)
    if last is None:
        last = (0, 0, 0, 0)

    # firma: memoria final (8B/word LE) + CE(4B) + DED(4B) +
    #        FIRST(addr4B,syn1B,flags1B) + LAST(addr4B,syn1B,flags1B)
    stream = bytearray()
    for w in mem:
        stream.extend(word39_to_bytes(w))
    stream.extend(ce.to_bytes(4, "little"))
    stream.extend(ded.to_bytes(4, "little"))
    for (a, s, wc, wd) in (first, last):
        stream.extend(a.to_bytes(4, "little"))
        stream.append(s & 0xFF)
        stream.append((wc & 1) | ((wd & 1) << 1))

    sig = fnv1a_32(bytes(stream))
    return {
        "mem": mem, "ce": ce, "ded": ded,
        "first": first, "last": last, "sig": sig,
    }
