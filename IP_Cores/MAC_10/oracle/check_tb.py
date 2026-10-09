#!/usr/bin/env python3
"""HERCOSSNUX Core 21 - comprobaciones de las salidas de los testbenches.

  check_tb.py gen  <archivo> LMIN LMAX LSTEP N
      tramas volcadas por tb_eth21_gen == oraculo (byte a byte)
  check_tb.py wire <archivo> LMIN LMAX LSTEP N [GT_REV GT_SWAP]
      bloques de cable volcados por el modelo de GT -> decodificador IEEE
      independiente -> N tramas validas del generador, FCS correcto, sin
      errores de protocolo
  check_tb.py mkchk <archivo>
      vectores para tb_eth21_chk (tramas buenas y mutadas) + esperado
  check_tb.py mkwire <archivo> LMIN LMAX LSTEP N SEED [GT_REV GT_SWAP]
      flujo de cable IEEE (del oraculo) para inyectar en el RX
Imprime FNV32 de las tramas para cruzar con las firmas del VHDL.
"""
import random
import sys

import eth21_oracle as o

CFG = dict(peer_mac=0x665544332211, own_mac=0x204E47454E02, own_ip=0xC0A81502,
           peer_ip=0xC0A81501, sport=0x5210, dport=0x5211)


def cfg(lmin, lmax, lstep, n, own_ip=None, peer_ip=None):
    c = dict(CFG)
    if own_ip is not None:
        c["own_ip"], c["peer_ip"] = own_ip, peer_ip
    return o.Cfg(lmin=lmin, lmax=lmax, lstep=lstep, count=n, **c)


def read_frames(path):
    with open(path) as f:
        return [bytes.fromhex(l.strip()) for l in f if l.strip()]


def cmd_gen(path, lmin, lmax, lstep, n, own_ip=None, peer_ip=None):
    c = cfg(lmin, lmax, lstep, n, own_ip, peer_ip)
    got = read_frames(path)
    exp = o.burst(c, n)
    if len(got) != len(exp):
        print("GEN FAIL: %d tramas, esperadas %d" % (len(got), len(exp)))
        return 1
    for i, (g, e) in enumerate(zip(got, exp)):
        if g != e:
            k = next(j for j in range(min(len(g), len(e))) if g[j] != e[j]) if len(g) == len(e) else -1
            print("GEN FAIL trama %d (len %d/%d, primer byte distinto %d)" % (i, len(g), len(e), k))
            return 1
        o.check_frame(c, g, i)
    print("GEN OK %d tramas FNV32=0x%08X bytes=%d" % (len(got), o.frames_signature(got),
                                                     o.wire_bytes(got)))
    return 0


def gt_to_wire(h, d, gt_rev, gt_swap):
    """palabra del GT (cabecera 2 bits, datos 64) -> 66 bits de cable con la
    hipotesis de orden del GT dada (igual que el modelo VHDL)."""
    h0, h1 = h & 1, (h >> 1) & 1
    w = [h1, h0] if gt_swap else [h0, h1]
    if gt_rev:
        w += [(d >> (63 - i)) & 1 for i in range(64)]
    else:
        w += [(d >> i) & 1 for i in range(64)]
    return w


def read_wire(path):
    bits = []
    with open(path) as f:
        for l in f:
            l = l.strip()
            if l:
                bits += [int(ch) for ch in l]
    return bits


def cmd_wire(path, lmin, lmax, lstep, n):
    c = cfg(lmin, lmax, lstep, n)
    bits = read_wire(path)
    res = o.decode_stream(bits)
    fr = res["frames"]
    exp = o.burst(c, n)
    ok = (fr == exp and res["bad_fcs"] == 0 and res["proto"] == 0)
    for i, f in enumerate(fr):
        try:
            o.check_frame(c, f, i)
        except ValueError as e:
            print("WIRE trama %d invalida: %s" % (i, e))
            ok = False
    print("WIRE %s tramas=%d esperadas=%d bad_fcs=%d proto=%d idles=%d FNV32=0x%08X" %
          ("OK" if ok else "FAIL", len(fr), len(exp), res["bad_fcs"], res["proto"],
           res["idles"], o.frames_signature(fr)))
    return 0 if ok else 1


def cmd_mkchk(path):
    """Tramas para el checker: buenas, mutadas en varios campos, con tuser, y
    un salto de secuencia. Linea: '<tuser> <hex>'. Devuelve esperado."""
    c = cfg(18, 300, 41, 30)
    fr = o.burst(c, 30)
    rnd = random.Random(2121)
    lines, ok, bad, seq, rxe = [], 0, 0, 0, 0
    exp_next = None
    skip_done = False
    for i, f in enumerate(fr):
        if i == 20 and not skip_done:
            skip_done = True          # salto de secuencia: se omite la 20
            continue
        g = bytearray(f)
        kind = "ok"
        if i in (3, 7, 11, 15, 22, 26):
            pos = {3: 1, 7: 13, 11: 25, 15: 39, 22: 44, 26: len(g) - 1}[i]
            g[pos] ^= 1 << rnd.randrange(8)
            kind = "bad"
        elif i == 9:
            g = g[:-1]               # un byte menos que tot_len
            kind = "bad"
        elif i == 13:
            # id IPv4 distinto de seq[15:0] con el checksum IPv4 CORRECTO:
            # solo la comprobacion id == seq lo detecta
            g[18] ^= 0x40
            g[24:26] = b"\x00\x00"
            g[24:26] = o.ip_checksum(bytes(g[14:34])).to_bytes(2, "big")
            kind = "bad"
        elif i == 17:
            kind = "rxe"
        tuser = 1 if kind == "rxe" else 0
        lines.append("%d %s" % (tuser, bytes(g).hex()))
        # semantica del checker: la secuencia esperada sale del seq RECIBIDO
        # (bytes 42..45) de toda trama no marcada con tuser, buena o mala; una
        # trama con tuser solo avanza la esperada en 1
        if kind == "rxe":
            rxe += 1
            if exp_next is not None:
                exp_next += 1
        else:
            if kind == "ok":
                ok += 1
            else:
                bad += 1
            rseq = int.from_bytes(bytes(g[42:46]), "little")
            if exp_next is not None and rseq != exp_next:
                seq += 1
            exp_next = (rseq + 1) & 0xFFFFFFFF
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("CHK_EXPECT ok=%d bad=%d seq=%d rxerr=%d" % (ok, bad, seq, rxe))
    return 0


def cmd_mkwire(path, lmin, lmax, lstep, n, seed, gt_rev, gt_swap):
    """Flujo IEEE del oraculo, troceado en palabras de 66 bits de cable. El
    modelo de GT lo lee tal cual; gt_rev/gt_swap no cambian el cable (son
    propiedades del GT), solo se registran para el informe."""
    c = cfg(lmin, lmax, lstep, n)
    rnd = random.Random(seed)
    fr = o.burst(c, n)
    bits = o.encode_stream([o.with_fcs(f) for f in fr], idles_between=1 + seed % 3,
                           idles_pre=8000, idles_post=400, seed=rnd.getrandbits(58))
    sh = rnd.randrange(1, 66)
    bits = [rnd.getrandbits(1) for _ in range(sh)] + bits
    bits += [0] * ((-len(bits)) % 66)
    with open(path, "w") as f:
        for i in range(0, len(bits), 66):
            f.write("".join(str(b) for b in bits[i:i + 66]) + "\n")
    print("MKWIRE tramas=%d desplazamiento=%d bloques=%d FNV32=0x%08X" %
          (len(fr), sh, len(bits) // 66, o.frames_signature(fr)))
    return 0


def cmd_pathexp(lmin, lmax, lstep, n, inj, rxonly):
    """Linea de contadores esperada de tb_eth21_path (mismo formato)."""
    c = cfg(lmin, lmax, lstep, n)
    fr = o.burst(c, n)
    wb = [len(f) + 4 for f in fr]
    txf, txb = (0, 0) if rxonly else (n, sum(wb))
    if inj:
        rxok, rxb, crc, cok, crxe = n - 1, sum(wb[1:]), 1, n - 1, 1
    else:
        rxok, rxb, crc, cok, crxe = n, sum(wb), 0, n, 0
    print("txf=%d txb=%d rxok=%d rxb=%d crc=%d runt=0 over=0 abort=0 filt=0 proto=0 "
          "cok=%d cbad=0 cseq=0 crxe=%d badsh=0 lock='1'" % (txf, txb, rxok, rxb, crc, cok, crxe))
    return 0


def cmd_mkfault(path, n_idle, n_lf, n_rf):
    """Flujo de cable: idles, luego Local Fault, luego Remote Fault, con los
    tres formatos de bloque de ordered set de cl.49: 0x4B (OS en la mitad
    baja: D1..D3 = 00 00 0x, O0 = 0), 0x2D (OS en la mitad alta: D5..D7, O4)
    y 0x55 (OS en ambas mitades)."""
    def os_blocks(code, n):
        lo = 0x4B | (code << 8 + 16)
        hi = 0x2D | (code << 40 + 16)
        both = 0x55 | (code << 8 + 16) | (code << 40 + 16)
        kinds = [lo, both, hi]
        return [(False, kinds[i % 3]) for i in range(n)]
    blocks = ([(False, o.IDLE)] * n_idle + os_blocks(0x01, n_lf) + os_blocks(0x02, n_rf) +
              [(False, o.IDLE)] * 500)
    bits, _ = o.scramble_blocks(blocks, 0x123456789AB)
    bits = [1, 0, 1] + bits
    bits += [0] * ((-len(bits)) % 66)
    with open(path, "w") as f:
        for i in range(0, len(bits), 66):
            f.write("".join(str(b) for b in bits[i:i + 66]) + "\n")
    return 0


def main(a):
    c = a[0]
    if c == "mkfault":
        return cmd_mkfault(a[1], *map(int, a[2:5]))
    if c == "pathexp":
        return cmd_pathexp(*map(int, a[1:7]))
    if c == "gen":
        ips = [int(x, 0) for x in a[6:8]] if len(a) >= 8 else []
        return cmd_gen(a[1], *map(int, a[2:6]), *ips)
    if c == "wire":
        return cmd_wire(a[1], *map(int, a[2:6]))
    if c == "mkchk":
        return cmd_mkchk(a[1])
    if c == "mkwire":
        extra = list(map(int, a[7:9])) if len(a) > 7 else [0, 0]
        return cmd_mkwire(a[1], *map(int, a[2:7]), *extra)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
