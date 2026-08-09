#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_layer4.py - Genera artefactos de Layer 4 (SoC + firmware).

Emite:
  layer4_init.txt  - BRAM inicial del scrubber (32 palabras 39b limpias)
  layer4_exp.txt   - valores esperados de run A y run B:
       # RUN_A ce ded first_syn last_syn sig
       # RUN_B ce ded first_syn last_syn sig
"""
import random
from ecc_oracle import encode
from fw_oracle import run_firmware, N

random.seed(0x1337)
data = [random.getrandbits(32) for _ in range(N)]
clean = [encode(d) for d in data]

with open("layer4_init.txt", "w") as f:
    for w in clean:
        f.write(f"{w:010X}\n")

rA = run_firmware(1, data)
rB = run_firmware(0, data)

with open("layer4_exp.txt", "w") as f:
    f.write(f"# RUN_A {rA['ce']} {rA['ded']} {rA['first_syn']} {rA['last_syn']} {rA['sig']:08x}\n")
    f.write(f"# RUN_B {rB['ce']} {rB['ded']} {rB['first_syn']} {rB['last_syn']} {rB['sig']:08x}\n")

print(f"N={N}")
print(f"RUN A (scrub ON) : CE={rA['ce']} DED={rA['ded']} sig={rA['sig']:#010x}")
print(f"RUN B (scrub OFF): CE={rB['ce']} DED={rB['ded']} sig={rB['sig']:#010x}")
print(f"contraste: firma A {'!=' if rA['sig']!=rB['sig'] else '=='} firma B  (protegido vs no)")
