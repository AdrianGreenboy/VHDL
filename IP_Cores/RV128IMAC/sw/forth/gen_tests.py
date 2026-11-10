#!/usr/bin/env python3
"""gen_tests.py - self-checking Forth scripts for the compute library. Expected values are
computed here in Python and embedded as ASSERTs, so every script ends in tohost PASS/FAIL
(ISS, lockstep and board alike). Also writes <name>.expect (text the console must show).

Usage: gen_tests.py <outdir>
"""
import hashlib
import math
import os
import sys
from decimal import Decimal, getcontext

M128 = (1 << 128) - 1


def h(v):
    return f"${v & M128:X}"


def limbs(x, n):
    return [(x >> (128 * i)) & M128 for i in range(n)]


def pi_digits(nd):
    """floor(pi * 10^nd) with Machin in exact integers"""
    g = 10
    one = 10 ** (nd + g)

    def atan_inv(k):
        s, t, i, sg = 0, one // k, 1, 1
        while t:
            s += sg * (t // i)
            t //= k * k
            i += 2
            sg = -sg
        return s
    return (16 * atan_inv(5) - 4 * atan_inv(239)) // 10 ** g


def t_bignum():
    L = ["\\ t_bignum - 128-bit-limb arithmetic, factorials, pi"]
    # 100! in 5 limbs (525 bits)
    f = math.factorial(100)
    L.append("CREATE F 8 CELLS ALLOT  100 F 5 BNFACT")
    for i, v in enumerate(limbs(f, 5)):
        L.append(f"F {i} CELLS + @ {h(v)} = {10 + i} ASSERT")
    L.append("F 5 BN. CR")
    # BN* : (2^256 - 1)^2 and a mixed product
    a = (1 << 256) - 1
    b = 0x1234567890ABCDEF_FEDCBA0987654321_0F1E2D3C4B5A6978_8796A5B4C3D2E1F0
    L.append("CREATE A 2 CELLS ALLOT CREATE B 2 CELLS ALLOT CREATE R 4 CELLS ALLOT")
    for nm, x in (("A", a), ("B", b)):
        for i, v in enumerate(limbs(x, 2)):
            L.append(f"{h(v)} {nm} {i} CELLS + !")
    L.append("A B R 2 BN*")
    for i, v in enumerate(limbs(a * b, 4)):
        L.append(f"R {i} CELLS + @ {h(v)} = {20 + i} ASSERT")
    L.append("A A R 2 BN*")
    for i, v in enumerate(limbs(a * a, 4)):
        L.append(f"R {i} CELLS + @ {h(v)} = {24 + i} ASSERT")
    # BN- borrow, BN+ carry, BN/1 remainder
    L.append("B A R 2 BN- 1 = 28 ASSERT")
    for i, v in enumerate(limbs((b - a) % (1 << 256), 2)):
        L.append(f"R {i} CELLS + @ {h(v)} = {29 + i} ASSERT")
    L.append("A B R 2 BN+ 1 = 31 ASSERT")
    d = 0xFFFFFFFFFFFFFFC5                              # largest 64-bit prime
    L.append(f"B R 2 {h(d)} BN/1 {h(b % d)} = 32 ASSERT")
    for i, v in enumerate(limbs(b // d, 2)):
        L.append(f"R {i} CELLS + @ {h(v)} = {33 + i} ASSERT")
    # pi: 6 chunks of 19 digits with 4 fraction limbs
    nd = 6 * 19
    digits = str(pi_digits(nd))
    ph = 0
    for k in range(6):
        ph = (ph * 31 + int(digits[1 + 19 * k: 20 + 19 * k])) & M128
    L.append("5 PI-COMPUTE 6 PI. CR")
    L.append(f"PH @ {h(ph)} = 40 ASSERT")
    L.append("BYE")
    expect = [str(f), "3." + digits[1:]]
    return L, expect


def q(x):
    return int(round(x * 2 ** 64)) & M128


def t_fixed():
    getcontext().prec = 50
    L = ["\\ t_fixed - Q64.64 fixed point"]
    L.append("3 S>F 4 S>F F* 12 S>F = 10 ASSERT")
    L.append("1 S>F 3 S>F F/ $5555555555555555 = 11 ASSERT")
    L.append("-7 S>F 2 S>F F/ -7 S>F 2/ = 12 ASSERT")
    L.append("1 S>F $3000000000000000000000000000 F/ $55555 = 19 ASSERT")
    for i, x in enumerate((2, 3, 10, 12345)):
        ref = math.isqrt(x << 128)
        L.append(f"{x} S>F FSQRT {h(ref)} = {13 + i} ASSERT")
    L.append("2 S>F FSQRT F. CR")
    tol = 1 << 8                                        # 256 ulp = 2^-56
    n = 20
    for i, x in enumerate((0.5, 1.0, 2.5, -1.25, 3.0, 10.0)):
        fx = q(x)
        xs = fx - (1 << 128) if fx >> 127 else fx
        xd = Decimal(xs) / Decimal(2 ** 64)
        sd, cd = dsin(xd), dcos(xd)
        L.append(f"{h(fx)} FSIN {h(int(sd * 2 ** 64))} - ABS {tol} < {n + 2 * i} ASSERT")
        L.append(f"{h(fx)} FCOS {h(int(cd * 2 ** 64))} - ABS {tol} < {n + 2 * i + 1} ASSERT")
    # quaternion: rotate (0,1,0,0) by 90 degrees about z -> (0,0,1,0)
    L += ["CREATE QQ 4 CELLS ALLOT CREATE QC 4 CELLS ALLOT CREATE QV 4 CELLS ALLOT",
          "CREATE QT 4 CELLS ALLOT CREATE QR 4 CELLS ALLOT",
          "FONE 2/ FSQRT DUP QQ ! 0 QQ 16 + ! 0 QQ 32 + ! QQ 48 + !",
          "0 QV ! FONE QV 16 + ! 0 QV 32 + ! 0 QV 48 + !",
          "QQ QC QCONJ QQ QV QT Q* QT QC QR Q*",
          "QR Q. CR",
          f"QR @ ABS {tol} < 40 ASSERT",
          f"QR 16 + @ ABS {tol} < 41 ASSERT",
          f"QR 32 + @ FONE - ABS {tol} < 42 ASSERT",
          f"QR 48 + @ ABS {tol} < 43 ASSERT",
          "BYE"]
    return L, ["1.414213562373095048"]


def dsin(x):
    s, t, k = x, x, 1
    while abs(t) > Decimal(10) ** -45:
        t = -t * x * x / ((2 * k) * (2 * k + 1))
        s += t
        k += 1
    return s


def dcos(x):
    s, t, k = Decimal(1), Decimal(1), 1
    while abs(t) > Decimal(10) ** -45:
        t = -t * x * x / ((2 * k - 1) * (2 * k))
        s += t
        k += 1
    return s


def msg(n):
    return bytes((i * 7 + 3) & 255 for i in range(n))


def poly1305(m, key):
    r = int.from_bytes(key[:16], 'little') & 0x0ffffffc0ffffffc0ffffffc0fffffff
    s = int.from_bytes(key[16:], 'little')
    p = (1 << 130) - 5
    acc = 0
    for i in range(0, len(m), 16):
        blk = m[i:i + 16] + b'\x01'
        acc = (acc + int.from_bytes(blk, 'little')) * r % p
    return ((acc + s) & M128).to_bytes(16, 'little')


def cbytes(name, b):
    out = [f"CREATE {name}"]                    # lines stay well under the 255-char TIB
    for i in range(0, len(b), 16):
        out.append(" ".join(f"{x} C," for x in b[i:i + 16]))
    return out


def t_crypto():
    L = ["\\ t_crypto - SHA-512 (RV128 *D ops) and Poly1305 (128-bit arithmetic)",
         ": GENMSG ( addr n -- ) 0 DO I 7 * 3 + 255 AND OVER I + C! LOOP DROP ;",
         "CREATE MB 1024 ALLOT  CREATE DG 64 ALLOT  CREATE KEY 32 ALLOT",
         "MB 1000 GENMSG"]
    n = 10
    for ln in (0, 3, 111, 112, 128, 239, 1000):
        L += cbytes(f"E{ln}", hashlib.sha512(msg(ln)).digest())
        L.append(f"MB {ln} DG SHA512 DG E{ln} 64 MEM= {n} ASSERT")
        n += 1
    L.append("MB 3 DG SHA512 DG 64 .HEX CR")
    # RFC 8439 2.5.2 test vector
    key = bytes.fromhex("85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b")
    m = b"Cryptographic Forum Research Group"
    tag = poly1305(m, key)
    assert tag.hex() == "a8061dc1305136c6c22b8baf0c0127a9"
    L += cbytes("RK", key) + cbytes("RM", m) + cbytes("RT", tag)
    L.append(f"RM {len(m)} RK DG POLY1305 DG RT 16 MEM= 20 ASSERT")
    L.append("DG 16 .HEX CR")
    # edge keys / lengths
    key2 = bytes((0xFF - i * 5) & 255 for i in range(32))
    L += cbytes("K2", key2)
    n = 21
    for ln in (0, 1, 15, 16, 17, 64, 1000):
        L += cbytes(f"P{ln}", poly1305(msg(ln), key2))
        L.append(f"MB {ln} K2 DG POLY1305 DG P{ln} 16 MEM= {n} ASSERT")
        n += 1
    L.append("BYE")
    return L, [hashlib.sha512(msg(3)).hexdigest(), tag.hex()]


def t_conc():
    L = ["\\ t_conc - lock-free stacks shared by the main loop and the timer interrupt",
         "64 CONSTANT NN",
         "CREATE POOL NN 2 * CELLS ALLOT",
         "VARIABLE HA VARIABLE HB VARIABLE M1 VARIABLE M2 VARIABLE CNT",
         ": INIT NN 0 DO POOL I 32 * + HA LPUSH LOOP ;",
         ": MOVER HA LPOP ?DUP IF HB LPUSH 1 M1 ATOM+ DROP THEN 1 CNT ATOM+ DROP ;",
         ": BACK HB LPOP ?DUP IF HA LPUSH 1 M2 ATOM+ DROP THEN ;",
         ": RUN 0 DO BACK 1 CNT ATOM+ DROP LOOP ;",
         "INIT HA LCOUNT NN = 10 ASSERT",
         "' MOVER ISR!  400 TIMER  3000 RUN  0 TIMER",
         "TICKS @ 20 > 11 ASSERT",
         "HA LCOUNT HB LCOUNT + NN = 12 ASSERT",
         "HA LTAG NN M1 @ + M2 @ + = 13 ASSERT",
         "HB LTAG M1 @ M2 @ + = 14 ASSERT",
         "CNT @ 3000 TICKS @ + = 15 ASSERT",
         "M1 @ 0 > 16 ASSERT",
         ": REPORT .\" ticks=\" TICKS @ . .\" moves=\" M1 @ . M2 @ . CR ; REPORT",
         "BYE"]
    return L, ["ticks="]


def d_pi1000():
    nd = 53 * 19
    digits = str(pi_digits(nd))
    ph = 0
    for k in range(53):
        ph = (ph * 31 + int(digits[1 + 19 * k: 20 + 19 * k])) & M128
    L = ["\\ pi1000 - 1007 digits of pi, 29 limbs of 128 bits (Machin)",
         ": PIDEMO CYCLES 29 PI-COMPUTE 53 PI. CR CYCLES SWAP - .\" cycles: \" . CR ;",
         "PIDEMO",
         f"PH @ {h(ph)} = 1 ASSERT",
         "BYE"]
    return L, ["3." + digits[1:]]


def d_fact1000():
    f = math.factorial(1000)
    n = 68
    L = ["\\ fact1000 - 1000! (2568 digits) on 68 limbs of 128 bits",
         f"CREATE F {n} CELLS ALLOT",
         f": FDEMO CYCLES 1000 F {n} BNFACT CYCLES SWAP - F {n} BN. CR .\" cycles: \" . CR ;",
         "FDEMO"]
    for i in range(60, n):
        L.append(f"F {i} CELLS + @ {h(limbs(f, n)[i])} = {i - 59} ASSERT")
    L.append("BYE")
    return L, [str(f)[:60], str(f)[-60:]]


def d_bench():
    L = ["\\ bench - cycle counts of the compute words (CYCLES = mcycle)",
         "CREATE MB 1024 ALLOT CREATE DG 64 ALLOT CREATE KY 32 ALLOT",
         "CREATE BA 16 CELLS ALLOT CREATE BB 16 CELLS ALLOT CREATE BR 32 CELLS ALLOT",
         ": T0 CYCLES ;  : T1 ( t0 -- ) CYCLES SWAP - . CR ;",
         ": B-SHA .\" sha512 1000 B x10: \" T0 10 0 DO MB 1000 DG SHA512 LOOP T1 ;",
         ": B-POLY .\" poly1305 1000 B x10: \" T0 10 0 DO MB 1000 KY DG POLY1305 LOOP T1 ;",
         ": B-BNMUL .\" BN* 2048x2048 bit x10: \" T0 10 0 DO BA BB BR 16 BN* LOOP T1 ;",
         ": B-FDIV .\" F/ x1000: \" T0 1000 0 DO FONE 3 S>F F/ DROP LOOP T1 ;",
         ": B-FSIN .\" FSIN x100: \" T0 100 0 DO FONE FSIN DROP LOOP T1 ;",
         ": B-ATOM .\" ATOM+ x1000: \" T0 1000 0 DO 1 BR ATOM+ DROP LOOP T1 ;",
         "B-SHA B-POLY B-BNMUL B-FDIV B-FSIN B-ATOM",
         "BYE"]
    return L, ["sha512"]


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, fn in (("t_bignum", t_bignum), ("t_fixed", t_fixed), ("t_crypto", t_crypto), ("t_conc", t_conc)):
        L, exp = fn()
        open(os.path.join(out, name + ".fs"), "w").write("\n".join(L) + "\n")
        open(os.path.join(out, name + ".expect"), "w").write("\n".join(exp) + "\n")
        print("wrote", name)
    dd = os.path.join(out, "..", "demos")
    os.makedirs(dd, exist_ok=True)
    for name, fn in (("pi1000", d_pi1000), ("fact1000", d_fact1000), ("bench", d_bench)):
        L, exp = fn()
        open(os.path.join(dd, name + ".fs"), "w").write("\n".join(L) + "\n")
        open(os.path.join(dd, name + ".expect"), "w").write("\n".join(exp) + "\n")
        print("wrote demos/" + name)


if __name__ == "__main__":
    main()
