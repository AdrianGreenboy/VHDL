#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A
# gen_l3a.py: ML-KEM-768 vectors for the algorithm-level testbench.
#
# Emits both end-to-end results and intermediate checkpoints. The checkpoints
# exist so an RTL failure identifies which stage diverged instead of only
# reporting a wrong output 40 million cycles in.
# =============================================================================
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "oracle"))
sys.path.insert(0, os.path.join(HERE, "..", "ntt"))
import fsm_model as F
import mlkem768 as kem
from gen_ntt import QK

K = 3


def emit():
    vec = json.load(open(os.path.join(HERE, "..", "verif", "vectors",
                                      "acvp_subset.json")))
    lines = []
    nkg = nen = nde = 0

    # Intermediate polynomial checkpoints for the first KeyGen vector only.
    # Each isolates one stage of the pipeline, in execution order, so an RTL
    # failure names the stage instead of only the final byte stream.
    t0 = vec["kem_keygen"][0]
    d0 = bytes.fromhex(t0["d"])
    g0 = F.sponge("sha3_512", d0 + bytes([K]), 64)
    rho0, sigma0 = g0[:32], g0[32:]

    s0 = F.sample_cbd(2, sigma0, 0)
    lines.append("CP1 %s" % " ".join(str(x % 3329) for x in s0))

    from gen_ntt import ntt_k
    sh0 = ntt_k(s0)
    lines.append("CP2 %s" % " ".join(str(x % 3329) for x in sh0))

    lift0 = F.lift(sh0)
    lines.append("CP3 %s" % " ".join(str(x % 3329) for x in lift0))

    a00 = F.sample_a(rho0, 0, 0)
    lines.append("CP4 %s" % " ".join(str(x % 3329) for x in a00))

    acc = [0] * 256
    for j in range(K):
        sj = F.sample_cbd(2, sigma0, j)
        lj = F.lift(ntt_k(sj))
        acc = F.poly_add(acc, F.basemul(F.sample_a(rho0, 0, j), lj))
    lines.append("CP5 %s" % " ".join(str(x % 3329) for x in acc))

    # Encaps checkpoints, first vector only, in execution order. EP4 and EP5
    # are the pair that matters: lifting both basemul operands leaves u
    # correct and corrupts only v, so a checkpoint on u alone would pass while
    # the ciphertext is wrong.
    e0 = vec["kem_encaps"][0]
    ek0 = bytes.fromhex(e0["ek"])
    m0 = bytes.fromhex(e0["m"])
    h0 = F.sponge("sha3_256", ek0, 32)
    g0 = F.sponge("sha3_512", m0 + h0, 64)
    kbar0, r0 = g0[:32], g0[32:]
    lines.append("EP1 %s" % r0.hex())

    from gen_ntt import ntt_k as _ntt
    y0 = [F.sample_cbd(2, r0, n) for n in range(K)]
    yh0 = [F.lift(_ntt(p)) for p in y0]
    lines.append("EP2 %s" % " ".join(str(x % 3329) for x in yh0[0]))

    rho0 = ek0[384 * K:]
    at00 = F.sample_a(rho0, 0, 0)
    lines.append("EP3 %s" % " ".join(str(x % 3329) for x in at00))

    e1_0 = [F.sample_cbd(2, r0, K + n) for n in range(K)]
    acc0 = [0] * 256
    for j in range(K):
        acc0 = F.poly_add(acc0, F.basemul(F.sample_a(rho0, j, 0), yh0[j]))
    u0 = F.poly_add(F.intt_k(acc0), e1_0[0])
    lines.append("EP4 %s" % " ".join(str(x % 3329) for x in u0))

    th0 = [kem.byte_decode(12, ek0[384 * i:384 * (i + 1)]) for i in range(K)]
    e2_0 = F.sample_cbd(2, r0, 2 * K)
    accv0 = [0] * 256
    for j in range(K):
        accv0 = F.poly_add(accv0, F.basemul(th0[j], yh0[j]))
    mu0 = [kem.decompress(1, b) for b in kem.byte_decode(1, m0)]
    v0 = F.poly_add(F.poly_add(F.intt_k(accv0), e2_0), mu0)
    lines.append("EP5 %s" % " ".join(str(x % 3329) for x in v0))

    # Decaps checkpoints, first vector only. The split that matters is DP3
    # against DP4: a decrypt failure and a compare failure look identical from
    # outside, since both end in a 32-byte shared secret that does not match.
    d0 = vec["kem_decaps"][0]
    dk0 = bytes.fromhex(d0["dk"])
    ct0 = bytes.fromhex(d0["c"])
    dkp = dk0[:384 * K]
    c1_0 = ct0[:32 * 10 * K]
    c2_0 = ct0[32 * 10 * K:]

    u_dec = [[kem.decompress(10, y) for y in
              kem.byte_decode(10, c1_0[32 * 10 * i:32 * 10 * (i + 1)])]
             for i in range(K)]
    lines.append("DP1 %s" % " ".join(str(x % 3329) for x in u_dec[0]))

    v_dec = [kem.decompress(4, y) for y in kem.byte_decode(4, c2_0)]
    lines.append("DP2 %s" % " ".join(str(x % 3329) for x in v_dec))

    sh_d = [kem.byte_decode(12, dkp[384 * i:384 * (i + 1)]) for i in range(K)]
    acc_d = [0] * 256
    for j in range(K):
        acc_d = F.poly_add(acc_d,
                           F.basemul(F.lift(sh_d[j]), F.ntt_k(u_dec[j])))
    w0 = [a - b for a, b in zip(v_dec, F.intt_k(acc_d))]
    lines.append("DP3 %s" % " ".join(str(x % 3329) for x in w0))

    m2_0 = F.kpke_decrypt(dkp, ct0)
    lines.append("DP4 %s" % m2_0.hex())

    # Additional rejection cases whose ciphertext differs at byte 0. Every
    # ACVP rejection vector in this subset corrupts the LAST byte, so an early
    # exit in the constant-time comparison would save no cycles and no timing
    # test could detect it. These cases make an early exit measurable.
    for src in (0, 2):
        td = vec["kem_decaps"][src]
        dkx = bytes.fromhex(td["dk"])
        cx = bytearray(bytes.fromhex(td["c"]))
        cx[0] = cx[0] ^ 255
        cx = bytes(cx)
        kx = F.decaps(dkx, cx)
        lines.append("DEC %s %s %s 1" % (dkx.hex(), cx.hex(), kx.hex()))

    # KeyGen: seeds in, ek/dk out, plus rho and the first t_hat as checkpoints
    for t in vec["kem_keygen"][:4]:
        d = bytes.fromhex(t["d"])
        z = bytes.fromhex(t["z"])
        ek, dk = F.keygen(d, z)
        assert ek.hex() == t["ek"].lower() and dk.hex() == t["dk"].lower()
        g = F.sponge("sha3_512", d + bytes([K]), 64)
        lines.append("KGN %s %s %s %s" % (d.hex(), z.hex(), ek.hex(), dk.hex()))
        lines.append("KGC %s %s" % (g[:32].hex(), g[32:].hex()))
        nkg += 1

    # Encaps: ek and m in, shared key and ciphertext out
    for t in vec["kem_encaps"][:4]:
        ek = bytes.fromhex(t["ek"])
        m = bytes.fromhex(t["m"])
        k, c = F.encaps(ek, m)
        assert k.hex() == t["k"].lower() and c.hex() == t["c"].lower()
        lines.append("ENC %s %s %s %s" % (ek.hex(), m.hex(), k.hex(), c.hex()))
        nen += 1

    # Decaps: both the valid path and the implicit-rejection path.
    # The rejection path is what a chosen-ciphertext attacker exercises, so a
    # vector set without it proves nothing about the FO transform.
    for t in vec["kem_decaps"]:
        dk = bytes.fromhex(t["dk"])
        c = bytes.fromhex(t["c"])
        k = F.decaps(dk, c)
        assert k.hex() == t["k"].lower()
        rej = 0 if "valid" in t["reason"] else 1
        lines.append("DEC %s %s %s %d" % (dk.hex(), c.hex(), k.hex(), rej))
        nde += 1

    with open("l3a_vectors.txt", "w") as f:
        f.write("# ML-KEM-768 Layer 3A vectors, from the FSM model, which is\n")
        f.write("# itself ACVP-validated through hardware primitives.\n")
        f.write("# KGN d z ek dk\n")
        f.write("# KGC rho sigma          (KeyGen checkpoint after G)\n")
        f.write("# ENC ek m k c\n")
        f.write("# DEC dk c k rejected    (rejected=1 on implicit rejection)\n")
        f.write("# CP1 s[0] after CBD, before NTT      (sampler path)\n")
        f.write("# CP2 s_hat[0] after forward NTT      (NTT through arbiter)\n")
        f.write("# CP3 s_hat[0] lifted by R^2          (Montgomery lift)\n")
        f.write("# CP4 A[0][0] from SampleNTT          (matrix expansion, seed order)\n")
        f.write("# CP5 accumulator after all K basemuls (accumulation path)\n")
        f.write("# EP1 r = G(m||H(ek)) second half   (encaps hash chain)\n")
        f.write("# EP2 y_hat[0] after NTT and lift   (lift bookkeeping)\n")
        f.write("# EP3 A^T[0][0] from SampleNTT      (transposed seed order)\n")
        f.write("# EP4 u[0] before compression       (matrix product path)\n")
        f.write("# EP5 v before compression          (t o y path, lift trap)\n")
        f.write("# DP1 u[0] after Decompress10       (ciphertext decode path)\n")
        f.write("# DP2 v after Decompress4           (ciphertext decode path)\n")
        f.write("# DP3 w = v - INTT(s o u)           (decrypt arithmetic)\n")
        f.write("# DP4 m2 recovered message, hex     (decrypt result)\n")
        for l in lines:
            f.write(l + "\n")
    return nkg, nen, nde


if __name__ == "__main__":
    a, b, c = emit()
    print("wrote l3a_vectors.txt: keygen=%d encaps=%d decaps=%d" % (a, b, c))
