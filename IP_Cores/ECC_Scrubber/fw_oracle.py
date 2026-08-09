#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fw_oracle.py - Oraculo del firmware (Layer 4) del ECC scrubber, Core 20.

Replica EXACTAMENTE lo que hace ecc_fw.s, en lockstep con el RTL:
  - configura region (base=0, len=N)
  - inject inmediato 1-bit addr 5 (bit7)
  - inject inmediato 2-bit addr 12 (bits 3,30) -> DED
  - inject on-read 1-bit addr 20 (bit34)
  - si cfg&1: corre scrub (RCW)
  - lee CE, DED, FIRST_SYN, LAST_SYN
  - firma FNV word-wise sobre (LO,HI de cada palabra de la region) ++ CE ++ DED

Produce los valores que el firmware debe escribir en RAM local:
  CE, DED, FIRST_SYN, LAST_SYN, firma.
"""
from ecc_oracle import encode
from mmio_oracle import EccMmio

N = 32


def fnv_word(h, w):
    h ^= (w & 0xFFFFFFFF)
    h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def run_firmware(cfg, data_words):
    m = EccMmio(N)
    m.load_clean(data_words)

    # config
    m.write(0x0C, 0)     # REGION_BASE
    m.write(0x10, N)     # REGION_LEN

    # inject inmediato 1-bit addr 5 bit7
    m.write(0x30, 5); m.write(0x34, 0x80); m.write(0x38, 0); m.write(0x3C, 0x3)
    # inject inmediato 2-bit addr 12 bits 3,30
    m.write(0x30, 12); m.write(0x34, 0x40000008); m.write(0x38, 0); m.write(0x3C, 0x3)
    # inject on-read 1-bit addr 20 bit34
    m.write(0x30, 20); m.write(0x34, 0); m.write(0x38, 0x4); m.write(0x3C, 0x1)

    # scrub condicional
    if cfg & 1:
        m.write(0x08, 0x1)   # scrub_en -> corre barrido

    ce  = m.read(0x18)
    ded = m.read(0x1C)
    fsyn = m.read(0x24)
    lsyn = m.read(0x2C)

    # firma FNV word-wise sobre la region (LO,HI) ++ CE ++ DED
    h = 0x811C9DC5
    for i in range(N):
        w = m.mem[i]
        lo = w & 0xFFFFFFFF
        hi = (w >> 32) & 0x7F
        h = fnv_word(h, lo)
        h = fnv_word(h, hi)
    h = fnv_word(h, ce)
    h = fnv_word(h, ded)

    return {"ce": ce, "ded": ded, "first_syn": fsyn, "last_syn": lsyn,
            "sig": h, "mem": list(m.mem)}


if __name__ == "__main__":
    import random
    random.seed(0x1337)
    data = [random.getrandbits(32) for _ in range(N)]
    for cfg in (1, 0):
        r = run_firmware(cfg, data)
        tag = "A (scrub ON)" if cfg & 1 else "B (scrub OFF)"
        print(f"=== run {tag} ===")
        print(f"  CE={r['ce']} DED={r['ded']} FIRST_SYN={r['first_syn']:#x} "
              f"LAST_SYN={r['last_syn']:#x}")
        print(f"  firma FNV = {r['sig']:#010x}")
