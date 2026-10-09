#!/usr/bin/env python3
"""HERCOSSNUX Core 21 - ETH GT: oraculo independiente.

Escrito desde IEEE 802.3 (cl. 49) y RFC 791/768, sin reutilizar el RTL ni el
oraculo del Core 20 (salvo la definicion del patron xorshift64/seed, que es
parte del formato de trama):

  * frame_bytes()      trama IPv4/UDP del generador (sin FCS)
  * lengths()          barrido de longitudes del generador
  * encode_stream()    tramas -> bloques 64B/66B -> scrambler -> bits de cable
  * decode_stream()    bits de cable -> block lock -> descrambler -> tramas
                       (con comprobacion de FCS via zlib.crc32)
  * check_frame()      valida una trama del generador campo a campo
  * autotest()         pruebas internas del propio oraculo

Convenciones:
  - MAC de 48 bits: byte 0 del cable en bits 7:0 (como los registros).
  - IP en valor numerico (0xC0A81502 = 192.168.21.2), big endian en cable.
  - Bits de cable: lista de 0/1, el primero transmitido en el indice 0.
"""
import random
import struct
import sys
import zlib

PAY_MIN, PAY_MAX = 18, 1472
HDR = 42


# --------------------------------------------------------------------------
# formato de trama
# --------------------------------------------------------------------------
def mac_bytes(v48):
    return bytes((v48 >> (8 * i)) & 0xFF for i in range(6))


def xorshift64(x):
    m = (1 << 64) - 1
    x ^= (x << 13) & m
    x ^= x >> 7
    x ^= (x << 17) & m
    return x & m


def seed_of(seq):
    return 0x9E3779B97F4A7C15 ^ (seq & 0xFFFFFFFF)


def ip_checksum(hdr):
    s = 0
    for i in range(0, len(hdr), 2):
        s += (hdr[i] << 8) | hdr[i + 1]
    while s >> 16:
        s = (s & 0xFFFF) + (s >> 16)
    return (~s) & 0xFFFF


def payload(seq, ln):
    seq &= 0xFFFFFFFF
    words = [seq | ((~seq & 0xFFFFFFFF) << 32)]
    p = seed_of(seq)
    while len(words) * 8 < ln:
        words.append(p)
        p = xorshift64(p)
    raw = b"".join(struct.pack("<Q", w) for w in words)
    return raw[:ln]


class Cfg:
    def __init__(self, peer_mac=0x0123456789AB & 0xFFFFFFFFFFFF, own_mac=0x204E47454E02,
                 own_ip=0xC0A81502, peer_ip=0xC0A81501, sport=0x5210, dport=0x5211,
                 lmin=18, lmax=1472, lstep=0, count=1):
        self.peer_mac, self.own_mac = peer_mac, own_mac
        self.own_ip, self.peer_ip = own_ip, peer_ip
        self.sport, self.dport = sport, dport
        self.lmin, self.lmax, self.lstep, self.count = lmin, lmax, lstep, count


def frame_bytes(cfg, seq, ln):
    tl = 20 + 8 + ln
    ip = bytearray(struct.pack(">BBHHHBBH4s4s", 0x45, 0x00, tl, seq & 0xFFFF, 0x4000,
                               64, 17, 0, struct.pack(">I", cfg.own_ip),
                               struct.pack(">I", cfg.peer_ip)))
    ck = ip_checksum(ip)
    ip[10:12] = struct.pack(">H", ck)
    udp = struct.pack(">HHHH", cfg.sport, cfg.dport, 8 + ln, 0)
    return (mac_bytes(cfg.peer_mac) + mac_bytes(cfg.own_mac) + b"\x08\x00" +
            bytes(ip) + udp + payload(seq, ln))


def clamp(cfg):
    lo = min(max(cfg.lmin, PAY_MIN), PAY_MAX)
    hi = min(max(cfg.lmax, lo), PAY_MAX)
    return lo, hi


def lengths(cfg, n):
    lo, hi = clamp(cfg)
    out, cur = [], lo
    for _ in range(n):
        out.append(cur)
        if cfg.lstep:
            cur = lo if cur + cfg.lstep > hi else cur + cfg.lstep
    return out


def burst(cfg, n=None):
    n = cfg.count if n is None else n
    return [frame_bytes(cfg, s, ln) for s, ln in enumerate(lengths(cfg, n))]


def with_fcs(fb):
    return fb + struct.pack("<I", zlib.crc32(fb) & 0xFFFFFFFF)


def check_frame(cfg, fb, exp_seq=None):
    """Devuelve (seq, L) si la trama (sin FCS) es una trama valida del
    generador; lanza ValueError con el motivo si no."""
    if len(fb) < HDR + PAY_MIN:
        raise ValueError("corta: %d" % len(fb))
    if fb[0:6] != mac_bytes(cfg.peer_mac) or fb[6:12] != mac_bytes(cfg.own_mac):
        raise ValueError("MAC")
    if fb[12:14] != b"\x08\x00":
        raise ValueError("ethertype")
    ip = fb[14:34]
    if ip_checksum(ip) != 0:
        raise ValueError("checksum IPv4")
    v, tos, tl, ident, ff, ttl, pr, _, sip, dip = struct.unpack(">BBHHHBBH4s4s", ip)
    if (v, tos, ff, ttl, pr) != (0x45, 0, 0x4000, 64, 17):
        raise ValueError("campos IPv4")
    if sip != struct.pack(">I", cfg.own_ip) or dip != struct.pack(">I", cfg.peer_ip):
        raise ValueError("IP")
    if tl + 14 != len(fb):
        raise ValueError("tot_len %d vs %d" % (tl, len(fb) - 14))
    sp, dp, ul, uck = struct.unpack(">HHHH", fb[34:42])
    if (sp, dp, ul, uck) != (cfg.sport, cfg.dport, tl - 20, 0):
        raise ValueError("UDP")
    ln = tl - 28
    seq = struct.unpack("<I", fb[42:46])[0]
    if ident != seq & 0xFFFF:
        raise ValueError("id")
    if fb[42:] != payload(seq, ln):
        raise ValueError("payload")
    if exp_seq is not None and seq != exp_seq:
        raise ValueError("seq %d esperado %d" % (seq, exp_seq))
    return seq, ln


# --------------------------------------------------------------------------
# 64B/66B (cl. 49) + scrambler
# --------------------------------------------------------------------------
T_TYPES = [0x87, 0x99, 0xAA, 0xB4, 0xCC, 0xD2, 0xE1, 0xFF]
S0 = 0x78
IDLE = 0x1E
PREAMBLE = bytes([0x55] * 6 + [0xD5])


def frame_blocks(fb_fcs):
    """Bloques (es_dato, payload64) de una trama con FCS (sin preambulo)."""
    blks = [(False, S0 | int.from_bytes(PREAMBLE, "little") << 8)]
    i = 0
    n = len(fb_fcs)
    while n - i >= 8:
        blks.append((True, int.from_bytes(fb_fcs[i:i + 8], "little")))
        i += 8
    r = n - i
    tail = fb_fcs[i:]
    blks.append((False, T_TYPES[r] | (int.from_bytes(tail, "little") << 8 if r else 0)))
    return blks


def scramble_blocks(blocks, state=(1 << 58) - 1):
    """Devuelve (bits de cable, estado). Cabecera: datos 0,1 ; control 1,0."""
    bits = []
    s = state
    for isd, pl in blocks:
        bits += [0, 1] if isd else [1, 0]
        for i in range(64):
            b = (pl >> i) & 1
            o = b ^ ((s >> 38) & 1) ^ ((s >> 57) & 1)
            s = ((s << 1) | o) & ((1 << 58) - 1)
            bits.append(o)
    return bits, s


def encode_stream(frames_fcs, idles_between=2, idles_pre=40, idles_post=40, seed=None):
    blocks = [(False, IDLE)] * idles_pre
    for fb in frames_fcs:
        blocks += frame_blocks(fb)
        blocks += [(False, IDLE)] * idles_between
    blocks += [(False, IDLE)] * idles_post
    st = (1 << 58) - 1 if seed is None else seed
    bits, _ = scramble_blocks(blocks, st)
    return bits


def descramble(bits_pl, s):
    out = 0
    for i, b in enumerate(bits_pl):
        o = b ^ ((s >> 38) & 1) ^ ((s >> 57) & 1)
        s = ((s << 1) | b) & ((1 << 58) - 1)
        out |= o << i
    return out, s


def decode_stream(bits, need=64):
    """Busca el block lock, descramblea y extrae tramas.
    Devuelve dict: frames (sin FCS, solo las de FCS correcto), bad_fcs,
    proto (bloques de tipo invalido), offset, idles."""
    # primer tramo de 'need' cabeceras validas seguidas (en cualquier
    # desplazamiento de bit y a partir de cualquier bloque: el inicio del
    # volcado puede ser basura del reset)
    off = None
    best = None
    for o in range(66):
        run, k = 0, 0
        while o + 66 * k + 1 < len(bits):
            p = o + 66 * k
            run = run + 1 if bits[p] != bits[p + 1] else 0
            k += 1
            if run == need:
                start = p - 66 * (need - 1)
                if best is None or start < best:
                    best = start
                break
    if best is None:
        raise ValueError("sin block lock")
    off = best
    s = 0
    res = {"frames": [], "bad_fcs": 0, "proto": 0, "offset": off, "idles": 0}
    cur = None
    p = off
    nblk = 0
    while p + 66 <= len(bits):
        h0, h1 = bits[p], bits[p + 1]
        pl, s = descramble(bits[p + 2:p + 66], s)
        p += 66
        nblk += 1
        if nblk <= 1:          # el descrambler se sincroniza en 58 bits
            continue
        if h0 == h1:
            res["proto"] += 1
            cur = None
            continue
        isd = (h0, h1) == (0, 1)
        if isd:
            if cur is not None:
                cur += pl.to_bytes(8, "little")
            continue
        t = pl & 0xFF
        if t == S0:
            if (pl >> 8).to_bytes(7, "little") != PREAMBLE:
                res["proto"] += 1
            cur = b""
        elif t in T_TYPES:
            r = T_TYPES.index(t)
            if cur is not None:
                cur += (pl >> 8).to_bytes(7, "little")[:r]
                fb, fcs = cur[:-4], cur[-4:]
                if len(cur) >= 4 and zlib.crc32(fb) & 0xFFFFFFFF == struct.unpack("<I", fcs)[0]:
                    res["frames"].append(fb)
                else:
                    res["bad_fcs"] += 1
            cur = None
        elif t == IDLE:
            res["idles"] += 1
            if cur is not None:
                res["proto"] += 1
                cur = None
        else:
            res["proto"] += 1
            cur = None
    return res


# --------------------------------------------------------------------------
# firmas
# --------------------------------------------------------------------------
def fnv1a32_bytes(bs, h=2166136261):
    for b in bs:
        h ^= b
        h = (h * 16777619) & 0xFFFFFFFF
    return h


def frames_signature(frames):
    h = 2166136261
    for fb in frames:
        h = fnv1a32_bytes(fb, h)
    return h


def wire_bytes(frames):
    """Bytes en el cable por trama: trama + FCS (lo que cuenta TX_BYTES)."""
    return sum(len(f) + 4 for f in frames)


# --------------------------------------------------------------------------
# autotest
# --------------------------------------------------------------------------
def autotest():
    # checksum IPv4 de referencia (RFC 1071, ejemplo clasico)
    h = bytes.fromhex("450000730000400040110000c0a80001c0a800c7")
    assert ip_checksum(h) == 0xB861, hex(ip_checksum(h))
    # crc32 de Ethernet: residuo del FCS correcto
    fb = b"123456789"
    assert zlib.crc32(fb) == 0xCBF43926
    cfg = Cfg(lmin=18, lmax=200, lstep=37, count=12)
    fr = burst(cfg)
    for s, f in enumerate(fr):
        assert check_frame(cfg, f, s)[0] == s
        assert len(f) >= 60
    # extremos
    assert len(frame_bytes(cfg, 0, PAY_MAX)) == 1514
    assert len(frame_bytes(cfg, 0, PAY_MIN)) == 60
    # codificar y decodificar (con desplazamiento de bits arbitrario)
    rnd = random.Random(21)
    for trial in range(3):
        bits = encode_stream([with_fcs(f) for f in fr], seed=rnd.getrandbits(58))
        sh = rnd.randrange(66)
        bits = [rnd.getrandbits(1) for _ in range(sh)] + bits
        res = decode_stream(bits)
        assert res["frames"] == fr, (trial, len(res["frames"]))
        assert res["bad_fcs"] == 0 and res["proto"] == 0
    # un bit cambiado en un bloque de datos -> FCS malo (el descrambler
    # multiplica el error por 3, pero sigue dentro de la misma trama)
    bits = encode_stream([with_fcs(f) for f in fr[:3]])
    k = 66 * (40 + 3) + 2 + 5
    bits[k] ^= 1
    res = decode_stream(bits)
    assert res["bad_fcs"] == 1 and len(res["frames"]) == 2
    # mutaciones del formato: cada una debe ser detectada
    f = bytearray(fr[0])
    for pos in (0, 7, 12, 14, 16, 18, 22, 24, 26, 30, 34, 38, 40, 42, 46, 50, 59):
        g = bytearray(f)
        g[pos] ^= 0x01
        try:
            check_frame(cfg, bytes(g))
            raise AssertionError("mutacion no detectada en byte %d" % pos)
        except ValueError:
            pass
    print("eth21_oracle autotest OK")


if __name__ == "__main__":
    autotest()
    sys.exit(0)
