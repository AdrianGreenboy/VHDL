#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A
# gen_codec12.py: vectors for the streaming ByteEncode_12 / ByteDecode_12
# block, generated from the ACVP-validated Phase 0 oracle.
# =============================================================================
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "oracle"))
import mlkem768 as kem

QK = 3329

random.seed(555)
cases = [[0] * 256,
         [QK - 1] * 256,
         [i % QK for i in range(256)],
         [(QK - 1) if i % 2 == 0 else 0 for i in range(256)]]
for _ in range(4):
    cases.append([random.randrange(QK) for _ in range(256)])

with open("codec12_vectors.txt", "w") as f:
    f.write("# codec_12 vectors: 256 canonical coefficients, then 384 hex bytes\n")
    for p in cases:
        enc = kem.byte_encode(12, p)
        assert kem.byte_decode(12, enc) == p
        assert len(enc) == 384
        f.write(" ".join(str(x) for x in p) + "\n")
        f.write(enc.hex() + "\n")
print("wrote %d codec_12 vectors" % len(cases))
