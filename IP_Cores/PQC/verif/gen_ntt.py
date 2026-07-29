#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 1
# gen_ntt.py: generates the Montgomery-domain twiddle tables and the reference
# vectors for NTT-K (Kyber, q=3329) and NTT-D (Dilithium, q=8380417).
#
# Both NTTs use Cooley-Tukey forward / Gentleman-Sande inverse with signed
# Montgomery reduction. No modulo operator appears anywhere in the datapath:
# reduction is multiply + shift, and range reduction is conditional add/sub of
# 2q, which synthesises to a comparator and an adder.
# =============================================================================
import random

QK, RK, QINVK = 3329, 1 << 16, 62209
QD, RD, QINVD = 8380417, 1 << 32, 58728449


def s16(x):
    x &= 0xFFFF
    return x - (1 << 16) if x >= (1 << 15) else x


def s32(x):
    x &= 0xFFFFFFFF
    return x - (1 << 32) if x >= (1 << 31) else x


def mont_k(a):
    return (a - s16(s16(a & 0xFFFF) * QINVK) * QK) >> 16


def mont_d(a):
    return (a - s32(s32(a & 0xFFFFFFFF) * QINVD) * QD) >> 32


def rr_k(x):
    while x >= QK:
        x -= 2 * QK
    while x < -QK:
        x += 2 * QK
    return x


def rr_d(x):
    while x >= QD:
        x -= 2 * QD
    while x < -QD:
        x += 2 * QD
    return x


def brv(i, b):
    r = 0
    for k in range(b):
        r = (r << 1) | ((i >> k) & 1)
    return r


def csign(x, q):
    return x - q if x > q // 2 else x


ZK_M = [csign((pow(17, brv(i, 7), QK) * RK) % QK, QK) for i in range(128)]
GK_M = [csign((pow(17, 2 * brv(i, 7) + 1, QK) * RK) % QK, QK) for i in range(128)]
ZD_M = [csign((pow(1753, brv(i, 8), QD) * RD) % QD, QD) for i in range(256)]


def ntt_k(f):
    f = list(f)
    i = 1
    ln = 128
    while ln >= 2:
        for st in range(0, 256, 2 * ln):
            z = ZK_M[i]
            i += 1
            for j in range(st, st + ln):
                t = mont_k(z * f[j + ln])
                f[j + ln] = rr_k(f[j] - t)
                f[j] = rr_k(f[j] + t)
        ln >>= 1
    return f


def intt_k_core(f):
    f = list(f)
    i = 127
    ln = 2
    while ln <= 128:
        for st in range(0, 256, 2 * ln):
            z = ZK_M[i]
            i -= 1
            for j in range(st, st + ln):
                t = f[j]
                f[j] = rr_k(t + f[j + ln])
                f[j + ln] = mont_k(z * (f[j + ln] - t))
        ln <<= 1
    return f


def ntt_d(f):
    f = list(f)
    m = 0
    ln = 128
    while ln >= 1:
        for st in range(0, 256, 2 * ln):
            m += 1
            z = ZD_M[m]
            for j in range(st, st + ln):
                t = mont_d(z * f[j + ln])
                f[j + ln] = rr_d(f[j] - t)
                f[j] = rr_d(f[j] + t)
        ln >>= 1
    return f


def intt_d_core(f):
    f = list(f)
    m = 256
    ln = 1
    while ln < 256:
        for st in range(0, 256, 2 * ln):
            m -= 1
            z = ZD_M[m]
            for j in range(st, st + ln):
                t = f[j]
                f[j] = rr_d(t + f[j + ln])
                f[j + ln] = mont_d(z * (f[j + ln] - t))
        ln <<= 1
    return f


# Final scaling constants, derived from a delta input (documented, not magic).
SK = csign((RK * pow(intt_k_core(ntt_k([1] + [0] * 255))[0] % QK, -1, QK)) % QK, QK)
SD = csign((RD * pow(intt_d_core(ntt_d([1] + [0] * 255))[0] % QD, -1, QD)) % QD, QD)


def intt_k(f):
    return [mont_k(SK * x) for x in intt_k_core(f)]


def intt_d(f):
    return [mont_d(SD * x) for x in intt_d_core(f)]


def plain_ntt(f, q, root, layers, last_len):
    f = list(f)
    i = 1
    ln = 128
    Z = [pow(root, brv(k, layers), q) for k in range(1 << layers)]
    while ln >= last_len:
        for st in range(0, 256, 2 * ln):
            z = Z[i]
            i += 1
            for j in range(st, st + ln):
                t = (z * f[j + ln]) % q
                f[j + ln] = (f[j] - t) % q
                f[j] = (f[j] + t) % q
        ln >>= 1
    return f


def schoolbook_neg(a, b, q):
    c = [0] * 512
    for i in range(256):
        for j in range(256):
            c[i + j] = (c[i + j] + a[i] * b[j]) % q
    return [(c[i] - c[i + 256]) % q for i in range(256)]


def selftest():
    random.seed(3)
    mxk = mxd = 0
    for _ in range(50):
        a = [random.randrange(QK) for _ in range(256)]
        assert [x % QK for x in ntt_k(a)] == plain_ntt(a, QK, 17, 7, 2)
        assert [x % QK for x in intt_k(ntt_k(a))] == a
        mxk = max(mxk, max(abs(x) for x in ntt_k(a)))
    for _ in range(20):
        a = [random.randrange(QD) for _ in range(256)]
        assert [x % QD for x in ntt_d(a)] == plain_ntt(a, QD, 1753, 8, 1)
        assert [x % QD for x in intt_d(ntt_d(a))] == a
        mxd = max(mxd, max(abs(x) for x in ntt_d(a)))
    # Dilithium NTT is a full 8-layer transform: pointwise product must equal
    # the negacyclic schoolbook product.
    for _ in range(5):
        a = [random.randrange(QD) for _ in range(256)]
        b = [random.randrange(QD) for _ in range(256)]
        na, nb = ntt_d(a), ntt_d(b)
        pw = [mont_d(x * y) for x, y in zip(na, nb)]
        got = [x % QD for x in intt_d(pw)]
        exp = schoolbook_neg(a, b, QD)
        # pointwise in Montgomery domain leaves one R^-1 factor
        scale = pow(RD, -1, QD)
        assert got == [(x * scale) % QD for x in exp], "ntt_d convolution mismatch"
    print("selftest OK  SK=%d SD=%d  max|fwd_k|=%d max|fwd_d|=%d" % (SK, SD, mxk, mxd))


def emit_tables(path):
    def block(name, typ, vals, perline):
        s = "  constant %s : %s := (\n" % (name, typ)
        for i in range(0, len(vals), perline):
            s += "    " + ", ".join("%d" % v for v in vals[i:i + perline])
            s += ",\n" if i + perline < len(vals) else ");\n\n"
        return s

    with open(path, "w") as f:
        f.write("""-- =============================================================================
-- HERCOSSNUX PQC IP Core - Layer 1
-- ntt_tables_pkg: twiddle factors in Montgomery domain for both NTTs.
-- Generated by verif/gen_ntt.py. Do not edit by hand.
-- NTT-K: q = 3329,    R = 2^16, zeta = 17,   7 layers, 128 twiddles
-- NTT-D: q = 8380417, R = 2^32, zeta = 1753, 8 layers, 256 twiddles
-- VHDL-2008. ASCII-only. MIT license.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ntt_tables_pkg is

  constant C_QK    : integer := 3329;
  constant C_QINVK : integer := 62209;
  constant C_QD    : integer := 8380417;
  constant C_QINVD : integer := 58728449;

  -- Final scaling applied after the inverse transform, Montgomery domain.
  constant C_SK    : integer := %d;
  constant C_SD    : integer := %d;

  type t_zk is array (0 to 127) of integer;
  type t_zd is array (0 to 255) of integer;

""" % (SK, SD))
        f.write(block("C_ZETA_K", "t_zk", ZK_M, 8))
        f.write(block("C_GAMMA_K", "t_zk", GK_M, 8))
        f.write(block("C_ZETA_D", "t_zd", ZD_M, 6))
        f.write("end package ntt_tables_pkg;\n")


def emit_vectors(path, q, fwd, inv):
    random.seed(101)
    cases = [[0] * 256,
             [1] + [0] * 255,
             [0] * 255 + [1],
             [q - 1] * 256,
             [1] * 256]
    for _ in range(5):
        cases.append([random.randrange(q) for _ in range(256)])
    with open(path, "w") as f:
        f.write("# NTT reference vectors: input line, then forward-NTT line.\n")
        f.write("# 256 decimal coefficients per line, canonical range [0,q).\n")
        for a in cases:
            b = [x % q for x in fwd(a)]
            assert [x % q for x in inv(fwd(a))] == [x % q for x in a]
            f.write(" ".join(str(x % q) for x in a) + "\n")
            f.write(" ".join(str(x) for x in b) + "\n")
    return len(cases)


if __name__ == "__main__":
    selftest()
    emit_tables("ntt_tables_pkg.vhd")
    nk = emit_vectors("ntt_k_vectors.txt", QK, ntt_k, intt_k)
    nd = emit_vectors("ntt_d_vectors.txt", QD, ntt_d, intt_d)
    print("wrote ntt_tables_pkg.vhd, ntt_k=%d cases, ntt_d=%d cases" % (nk, nd))
