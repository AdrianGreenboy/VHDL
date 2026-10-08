#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX Core 20 - MAC 25G (IEEE 802.3 cl.46/49 sobre el PCS del Core 19)
# Oraculo de referencia: es la especificacion ejecutable del core.
#
# Modela, con la misma granularidad que la RTL:
#   * CRC-32 Ethernet (reflejado, 0xEDB88320, init/xorout 0xFFFFFFFF),
#     anclado a zlib.crc32
#   * generador de tramas (cabecera + patron xorshift64 sembrado por seq)
#   * MAC TX: padding a 60 B, FCS, codificacion 64B/66B cl.49 en ranuras
#     (S, D, T0..T7, I, E) con la regla de huecos fija de la RTL (2 ranuras)
#   * MAC RX: decodificador de bloques, framer, CRC residuo, runt/oversize,
#     filtro MAC, strip de FCS, contadores
#   * checker de tramas (contenido, longitud, continuidad de secuencia)
#
# Convenciones de bits (iguales a la RTL y al Core 19):
#   payload de bloque = entero de 64 bits, byte i en bits [8i+7:8i], bit 0 se
#   transmite primero. is_data=1 -> bloque de datos, 0 -> bloque de control
#   (el Core 19 codifica el sync header; este core solo ve is_data).
#
# MIT License.
# =============================================================================
import zlib

MASK64 = (1 << 64) - 1
CRC_POLY_R = 0xEDB88320
CRC_INIT = 0xFFFFFFFF
CRC_RESIDUE = 0xDEBB20E3          # estado tras datos+FCS (sin xorout)

# tipos de bloque cl.49 (Figura 49-7)
BT_IDLE = 0x1E
BT_START0 = 0x78
BT_START4 = 0x33
BT_OS_START4 = 0x66
BT_OS0 = 0x4B
BT_OS_OS = 0x55
BT_OS4 = 0x2D
BT_TERM = [0x87, 0x99, 0xAA, 0xB4, 0xCC, 0xD2, 0xE1, 0xFF]   # T0..T7
CC_IDLE = 0x00
CC_ERROR = 0x1E

START_BLOCK = 0xD555555555555578  # 0x78, D1..D6=0x55, D7=0xD5 (SFD)
IDLE_BLOCK = BT_IDLE              # 8 caracteres /I/ = 0
# bloque de error: tipo 0x1E y los 8 caracteres de control a /E/ (7 bits c/u)
ERROR_BLOCK = BT_IDLE | sum(CC_ERROR << (8 + 7 * i) for i in range(8))

ETHERTYPE = 0x88B5                # experimental local (IEEE 802)
MIN_FRAME = 64                    # incl. FCS
MAX_FRAME = 1522                  # incl. FCS (admite VLAN)
GEN_MIN_LEN = 20                  # la cabecera del generador ocupa 20 bytes


# ----------------------------------------------------------------------------
# utilidades
# ----------------------------------------------------------------------------
def fnv1a32(words, nbytes=4, h=2166136261):
    """FNV-1a sobre enteros, little-endian, nbytes por palabra."""
    for w in words:
        for b in range(nbytes):
            h ^= (w >> (8 * b)) & 0xFF
            h = (h * 16777619) & 0xFFFFFFFF
    return h


def crc_bits(state, data, nbits):
    """Recurrencia serie, bit 0 primero (identica a la funcion VHDL)."""
    for i in range(nbits):
        fb = (state ^ (data >> i)) & 1
        state >>= 1
        if fb:
            state ^= CRC_POLY_R
    return state


def crc_bytes(state, bs):
    for b in bs:
        state = crc_bits(state, b, 8)
    return state


def fcs_of(bs):
    return crc_bytes(CRC_INIT, bs) ^ 0xFFFFFFFF


def xorshift64(x):
    x ^= (x << 13) & MASK64
    x ^= x >> 7
    x ^= (x << 17) & MASK64
    return x & MASK64


def seed_of(seq):
    return (seq & 0xFFFFFFFF) ^ 0x9E3779B97F4A7C15


def word_bytes(w, n=8):
    return [(w >> (8 * i)) & 0xFF for i in range(n)]


def bytes_word(bs):
    w = 0
    for i, b in enumerate(bs):
        w |= (b & 0xFF) << (8 * i)
    return w


def mac_bytes(lo, hi):
    """Registro MAC_LO/MAC_HI -> lista de 6 bytes (byte 0 en lo[7:0])."""
    return word_bytes(lo, 4) + word_bytes(hi, 2)


# ----------------------------------------------------------------------------
# generador de tramas
# ----------------------------------------------------------------------------
class GenCfg:
    def __init__(self, dst=(0x43414D02, 0x2032), src=(0x45474E02, 0x204E),
                 len_min=20, len_max=1514, len_step=37, count=64):
        self.dst_lo, self.dst_hi = dst
        self.src_lo, self.src_hi = src
        self.len_min, self.len_max = len_min, len_max
        self.len_step, self.count = len_step, count

    def eff_min(self):
        return max(self.len_min, GEN_MIN_LEN)

    def eff_max(self):
        return max(self.len_max, self.eff_min())


def gen_words(cfg, seq, ln):
    """Palabras de 64 bits que el generador entrega por AXIS (sin enmascarar).
    La ultima palabra lleva bytes basura mas alla de 'ln': la RTL entrega
    tambien el patron completo; el MAC enmascara con tkeep."""
    dst = mac_bytes(cfg.dst_lo, cfg.dst_hi)
    src = mac_bytes(cfg.src_lo, cfg.src_hi)
    w0 = bytes_word(dst + src[0:2])
    w1 = bytes_word(src[2:6] + [ETHERTYPE >> 8, ETHERTYPE & 0xFF,
                                ln & 0xFF, (ln >> 8) & 0xFF])
    w2 = (seq & 0xFFFFFFFF) | ((~seq & 0xFFFFFFFF) << 32)
    nw = (ln + 7) // 8
    out = [w0, w1, w2]
    p = seed_of(seq)
    while len(out) < nw:
        out.append(p)
        p = xorshift64(p)
    return out[:nw]


def gen_frame_bytes(cfg, seq, ln):
    ws = gen_words(cfg, seq, ln)
    bs = []
    for w in ws:
        bs += word_bytes(w)
    return bs[:ln]


def gen_lengths(cfg, n):
    lmin, lmax = cfg.eff_min(), cfg.eff_max()
    ln = lmin
    out = []
    for _ in range(n):
        out.append(ln)
        nxt = ln + cfg.len_step
        ln = lmin if nxt > lmax else nxt
    return out


# ----------------------------------------------------------------------------
# MAC TX: trama -> ranuras de bloque
# ----------------------------------------------------------------------------
def tx_frame_blocks(l2bytes, inject=False):
    """Bloques (is_data, payload) que emite el MAC por una trama, incluyendo
    las 2 ranuras de hueco posteriores. Total = 3 + ceil(P/8) ranuras."""
    padded = list(l2bytes) + [0] * max(0, 60 - len(l2bytes))
    p = len(padded)
    fcs = fcs_of(padded)
    stream = padded + word_bytes(fcs, 4)
    f = len(stream)
    blocks = [(0, START_BLOCK)]
    nfull = f // 8
    for i in range(nfull):
        w = bytes_word(stream[8 * i:8 * i + 8])
        if inject and i == 1:
            w ^= 1                      # bit 0 del bloque de datos indice 1
        blocks.append((1, w))
    r = f - 8 * nfull
    tail = bytes_word(stream[8 * nfull:])
    blocks.append((0, BT_TERM[r] | ((tail << 8) & MASK64)))
    total = 3 + (p + 7) // 8
    while len(blocks) < total:
        blocks.append((0, IDLE_BLOCK))
    return blocks, f


def tx_burst_blocks(cfg, nframes, inject_first=False):
    blocks, wire = [], []
    for seq, ln in enumerate(gen_lengths(cfg, nframes)):
        b, f = tx_frame_blocks(gen_frame_bytes(cfg, seq, ln),
                               inject=(inject_first and seq == 0))
        blocks += b
        wire.append(f)
    return blocks, wire


def ipg_lanes_ok(blocks):
    """Comprueba IPG >= 12 caracteres entre FCS y el /S/ siguiente."""
    gap, in_gap, seen = 0, False, False
    for is_data, pl in blocks:
        bt = pl & 0xFF
        if not is_data and bt in BT_TERM:
            r = BT_TERM.index(bt)
            gap, in_gap, seen = 8 - r, True, True
        elif not is_data and bt == BT_IDLE and in_gap:
            gap += 8
        elif not is_data and bt == BT_START0:
            if seen and gap < 12:
                return False
            in_gap = False
    return True


# ----------------------------------------------------------------------------
# MAC RX: modelo ciclo-a-bloque de la RTL
# ----------------------------------------------------------------------------
RX_COUNTERS = ["rx_ok", "rx_bytes", "rx_crc_err", "rx_runt", "rx_oversize",
               "rx_abort", "rx_filtered", "rx_proto"]


class MacRx:
    def __init__(self, own_lo, own_hi, promisc=False):
        self.own = mac_bytes(own_lo, own_hi)
        self.promisc = promisc
        self.c = {k: 0 for k in RX_COUNTERS}
        self.out = []            # tramas entregadas: (bytes sin FCS, err)
        self.in_frame = False
        self.fr = []             # bytes de la trama actual (incl. FCS)

    # --- clasificacion de bloque (R1) ---
    @staticmethod
    def classify(is_data, pl):
        if is_data:
            return ("D", word_bytes(pl), 8)
        bt = pl & 0xFF
        if bt == BT_IDLE:
            chars = pl >> 8
            return ("I", None, 0) if chars == 0 else ("E", None, 0)
        if bt == BT_START0:
            return ("S", None, 0) if pl == START_BLOCK else ("SBAD", None, 0)
        if bt in BT_TERM:
            r = BT_TERM.index(bt)
            return ("T", word_bytes(pl >> 8, 7)[:r], r)
        if bt in (BT_START4, BT_OS_START4, BT_OS0, BT_OS_OS, BT_OS4):
            return ("U", None, 0)
        return ("E", None, 0)

    def _end(self, aborted):
        bs = self.fr
        self.fr = []
        self.in_frame = False
        f = len(bs)
        if f == 0:
            # trama sin palabras: no hay decision de filtro posible
            self.c["rx_abort" if aborted else "rx_runt"] += 1
            return
        dst = (bs + [0] * 6)[:6]
        accept = (self.promisc or dst == self.own or dst == [0xFF] * 6)
        if not accept:
            self.c["rx_filtered"] += 1
            return
        if aborted:
            err, key = True, "rx_abort"
        elif f < MIN_FRAME:
            err, key = True, "rx_runt"
        elif f > MAX_FRAME:
            err, key = True, "rx_oversize"
        elif crc_bytes(CRC_INIT, bs) != CRC_RESIDUE:
            err, key = True, "rx_crc_err"
        else:
            err, key = False, "rx_ok"
        self.c[key] += 1
        if not err:
            self.c["rx_bytes"] += f
        # strip de FCS con la misma regla que la RTL (stage R5)
        if aborted:
            data = bs                         # sin strip: aborto
        elif f > 4:
            data = bs[:f - 4]
        else:
            data = bs[:1]                     # caso degenerado (n_out=1)
        self.out.append((data, err))

    def block(self, is_data, pl):
        kind, bs, n = self.classify(is_data, pl)
        if kind in ("U", "SBAD") or (kind == "E" and not self.in_frame):
            self.c["rx_proto"] += 1
        if not self.in_frame:
            if kind == "S":
                self.in_frame = True
                self.fr = []
            elif kind in ("D", "T"):
                self.c["rx_proto"] += 1
            return
        # dentro de trama
        if kind == "D":
            self.fr += bs
        elif kind == "T":
            self.fr += bs
            self._end(aborted=False)
        else:
            self._end(aborted=True)
            if kind == "S":
                self.in_frame = True
                self.fr = []


# ----------------------------------------------------------------------------
# checker de tramas
# ----------------------------------------------------------------------------
CHK_COUNTERS = ["chk_ok", "chk_bad", "chk_seq_err", "chk_rxerr"]


class Checker:
    def __init__(self, cfg):
        self.cfg = cfg
        self.c = {k: 0 for k in CHK_COUNTERS}
        self.have = False
        self.exp = 0

    def frame(self, data, err):
        if err:
            self.c["chk_rxerr"] += 1
            if self.have:
                self.exp = (self.exp + 1) & 0xFFFFFFFF
            return
        bs = list(data) + [0] * max(0, 24 - len(data))
        ln = bs[14] | (bs[15] << 8)
        seq = bytes_word(bs[16:20])
        exp_bytes = gen_frame_bytes(self.cfg, seq, ln)
        exp_bytes = exp_bytes + [0] * max(0, 60 - ln)
        ok = (len(data) == max(ln, 60)) and list(data) == exp_bytes
        # cabecera fija (dst/src/ethertype) aunque ln venga corrupto
        self.c["chk_ok" if ok else "chk_bad"] += 1
        if self.have and seq != self.exp:
            self.c["chk_seq_err"] += 1
        self.exp = (seq + 1) & 0xFFFFFFFF
        self.have = True


# ----------------------------------------------------------------------------
# escenario completo de silicio (L3/L4/L5): rafaga de N tramas en loopback
# ----------------------------------------------------------------------------
def run_burst(cfg, nframes, inject=False, promisc=False):
    blocks, wire = tx_burst_blocks(cfg, nframes, inject_first=inject)
    rx = MacRx(cfg.dst_lo, cfg.dst_hi, promisc)
    for b in blocks:
        rx.block(*b)
    chk = Checker(cfg)
    for d, e in rx.out:
        chk.frame(d, e)
    res = {"tx_frames": nframes, "tx_bytes": sum(wire), "tx_underrun": 0}
    res.update(rx.c)
    res.update(chk.c)
    res["slots"] = len(blocks)
    return res, blocks


def expected_counters(cfg, nframes, inject=False):
    """Version rapida (sin bloques) para N grande: valida contra run_burst."""
    lens = gen_lengths(cfg, nframes)
    wire = [max(l, 60) + 4 for l in lens]
    res = {"tx_frames": nframes, "tx_bytes": sum(wire), "tx_underrun": 0,
           "rx_ok": nframes - (1 if inject else 0),
           "rx_bytes": sum(wire) - (wire[0] if inject else 0),
           "rx_crc_err": 1 if inject else 0, "rx_runt": 0, "rx_oversize": 0,
           "rx_abort": 0, "rx_filtered": 0, "rx_proto": 0,
           "chk_ok": nframes - (1 if inject else 0), "chk_bad": 0,
           "chk_seq_err": 0, "chk_rxerr": 1 if inject else 0,
           "slots": sum(3 + (max(l, 60) + 7) // 8 for l in lens)}
    # el oraculo rapido solo vale si todas las tramas son de tamano legal
    assert all(f <= MAX_FRAME for f in wire), "len_max produce oversize"
    return res


if __name__ == "__main__":
    # autocomprobaciones del propio oraculo
    assert fcs_of(list(b"123456789")) == 0xCBF43926 == zlib.crc32(b"123456789")
    for n in (1, 7, 60, 1514):
        bs = [(i * 37 + 11) & 0xFF for i in range(n)]
        f = fcs_of(bs)
        assert f == zlib.crc32(bytes(bs))
        assert crc_bytes(CRC_INIT, bs + word_bytes(f, 4)) == CRC_RESIDUE
    cfg = GenCfg()
    for inj in (False, True):
        r, blocks = run_burst(cfg, 64, inject=inj)
        q = expected_counters(cfg, 64, inject=inj)
        for k in q:
            assert r[k] == q[k], (k, r[k], q[k], inj)
        assert ipg_lanes_ok(blocks)
    print("oraculo autoconsistente: CRC==zlib, residuo 0x%08X, IPG>=12, "
          "modelo rapido == modelo de bloques" % CRC_RESIDUE)
    r, blocks = run_burst(cfg, 64)
    print("rafaga 64 tramas: slots=%d tx_bytes=%d FNV(bloques)=0x%08X" %
          (r["slots"], r["tx_bytes"],
           fnv1a32([(d << 64) | p for d, p in blocks], nbytes=9)))
