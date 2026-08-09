#!/usr/bin/env python3
"""Genera ecc_fw_on.s y ecc_fw_off.s desde ecc_fw_tiles.s con params fijos.
   cfg, n_words, ddr_off pasan de lw (RAM local) a li (constantes por build)."""
import sys

N_WORDS = int(sys.argv[1]) if len(sys.argv) > 1 else 1024
DDR_OFF = 0   # region empieza en la base del buffer DDR reservado (0x70000000)

base = open("ecc_fw_tiles.s").read()

def make_variant(cfg):
    s = base
    # reemplazar los tres lw de config por li con constantes
    s = s.replace("        lw   x28, 0(x30)           # cfg",
                  f"        li   x28, {cfg}             # cfg (fijo por build)")
    s = s.replace("        lw   x27, 4(x30)           # n_words (palabras ECC 64b)",
                  f"        li   x27, {N_WORDS}          # n_words (fijo por build)")
    s = s.replace("        lw   x26, 8(x30)           # ddr_off",
                  f"        li   x26, {DDR_OFF}             # ddr_off (fijo por build)")
    return s

open("ecc_fw_on.s", "w").write(make_variant(1))
open("ecc_fw_off.s", "w").write(make_variant(0))
print(f"generados ecc_fw_on.s (cfg=1) y ecc_fw_off.s (cfg=0), n_words={N_WORDS}, ddr_off={DDR_OFF}")
