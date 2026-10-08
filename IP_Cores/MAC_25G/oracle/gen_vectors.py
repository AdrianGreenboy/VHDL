#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX Core 20 - MAC 25G
# Genera los ficheros de vectores (textio) que leen los testbenches GHDL, y
# imprime las firmas FNV-1a esperadas de cada capa.
#
#   python3 gen_vectors.py <dir_salida>
# =============================================================================
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mac25g_oracle as o   # noqa: E402

# configuraciones de TX (nombre, len_min, len_max, step, n_tramas, inject)
TX_CFGS = [
    ("txa", 20, 1514, 37, 64, False),   # barrido amplio, todos los n
    ("txb", 20, 90, 1, 71, False),      # barrido fino: padding y n=1..8
    ("txc", 20, 1514, 37, 16, True),    # inyeccion de 1 bit en la trama 0
]


def hx(v, w=16):
    return ("%0" + str(w) + "X") % v


def blocks_fnv(blocks):
    return o.fnv1a32([(d << 64) | p for d, p in blocks], nbytes=9)


def write_tx(outdir):
    sigs = {}
    for name, lmin, lmax, step, n, inj in TX_CFGS:
        cfg = o.GenCfg(len_min=lmin, len_max=lmax, len_step=step, count=n)
        blocks, _ = o.tx_burst_blocks(cfg, n, inject_first=inj)
        assert o.ipg_lanes_ok(blocks)
        with open(os.path.join(outdir, "tx_%s.txt" % name), "w") as f:
            f.write("%d\n" % len(blocks))
            for d, p in blocks:
                f.write("%d %s\n" % (d, hx(p)))
        sigs[name] = blocks_fnv(blocks)
    return sigs


# ---------------------------------------------------------------------------
# RX: flujo de bloques con casos de error + gaps de valid
# ---------------------------------------------------------------------------
def rx_stream():
    rnd = random.Random(20)
    cfg = o.GenCfg()
    own = (cfg.dst_lo, cfg.dst_hi)
    blocks = []

    def frame(bs, **kw):
        b, _ = o.tx_frame_blocks(bs, **kw)
        return b

    def idle(k=1):
        return [(0, o.IDLE_BLOCK)] * k

    seq = 0
    # 1) tramas buenas de todas las longitudes finales (n = 1..8 en T)
    for ln in list(range(20, 90)) + [500, 1513, 1514, 1518]:
        blocks += frame(o.gen_frame_bytes(cfg, seq, ln))
        seq += 1
    # 2) broadcast (debe pasar el filtro) y destino ajeno (filtrada)
    bc = [0xFF] * 6 + o.gen_frame_bytes(cfg, seq, 100)[6:]
    blocks += frame(bc)
    other = [0x02, 0x11, 0x22, 0x33, 0x44, 0x55] + o.gen_frame_bytes(cfg, seq, 100)[6:]
    blocks += frame(other)
    # 3) CRC erroneo (bit invertido en un byte de payload)
    bad = o.gen_frame_bytes(cfg, seq, 300)
    b = frame(bad)
    i = 7
    b[i] = (b[i][0], b[i][1] ^ (1 << 40))
    blocks += b
    # 4) runt: trama completa de 40 bytes (sin padding) con FCS correcto
    runt = o.gen_frame_bytes(cfg, seq, 36)
    stream = runt + o.word_bytes(o.fcs_of(runt), 4)
    blocks += [(0, o.START_BLOCK)]
    for k in range(len(stream) // 8):
        blocks.append((1, o.bytes_word(stream[8 * k:8 * k + 8])))
    r = len(stream) % 8
    blocks.append((0, o.BT_TERM[r] | (o.bytes_word(stream[len(stream) - r:]) << 8)))
    blocks += idle(2)
    # 5) oversize: 1530 bytes L2 (1534 con FCS)
    blocks += frame(o.gen_frame_bytes(cfg, seq, 1530))
    # 6) aborto: bloque /E/ a mitad de trama
    ab = frame(o.gen_frame_bytes(cfg, seq, 200))
    ab[10] = (0, o.ERROR_BLOCK)
    blocks += ab[:11] + idle(3)
    # 7) aborto por /S/ a mitad de trama (la nueva trama es buena)
    ab2 = frame(o.gen_frame_bytes(cfg, seq, 200))
    blocks += ab2[:6] + frame(o.gen_frame_bytes(cfg, seq + 1, 77))
    seq += 2
    # 8) preambulo erroneo (SFD 0xD4): se cuenta proto y se descarta
    bp = frame(o.gen_frame_bytes(cfg, seq, 120))
    bp[0] = (0, (o.START_BLOCK & ~(0xFF << 56)) | (0xD4 << 56))
    blocks += bp
    # 9) bloques no soportados / ordered sets / datos fuera de trama
    blocks += [(0, 0x33), (0, 0x4B | (0x01 << 32)), (1, 0x1234), (0, o.ERROR_BLOCK)]
    blocks += idle(2)
    # 10) trama de 0 palabras (S + T0) y de 1 palabra (S + T6)
    blocks += [(0, o.START_BLOCK), (0, o.BT_TERM[0])] + idle(2)
    blocks += [(0, o.START_BLOCK), (0, o.BT_TERM[6] | (0x112233445566 << 8))] + idle(2)
    # 11) mas tramas buenas tras los errores (el RX se recupera)
    for ln in (60, 61, 64, 65, 1000):
        blocks += frame(o.gen_frame_bytes(cfg, seq, ln))
        seq += 1
    blocks += idle(4)

    # huecos de valid aleatorios (como el gearbox 32/33 y peor)
    gaps = [rnd.random() < 0.15 for _ in blocks]
    rx = o.MacRx(*own)
    for blk in blocks:
        rx.block(*blk)
    return blocks, gaps, rx


def write_rx(outdir):
    blocks, gaps, rx = rx_stream()
    with open(os.path.join(outdir, "rx_in.txt"), "w") as f:
        f.write("%d\n" % len(blocks))
        for (d, p), g in zip(blocks, gaps):
            f.write("%d %d %s\n" % (int(g), d, hx(p)))
    words = []
    with open(os.path.join(outdir, "rx_out.txt"), "w") as f:
        nw = sum((len(d) + 7) // 8 for d, _ in rx.out)
        f.write("%d\n" % nw)
        for data, err in rx.out:
            k = (len(data) + 7) // 8
            for i in range(k):
                chunk = data[8 * i:8 * i + 8]
                n = len(chunk)
                last = int(i == k - 1)
                user = int(err) if last else 0
                w = o.bytes_word(chunk)
                keep = (1 << n) - 1
                f.write("%s %02X %d %d\n" % (hx(w), keep, last, user))
                words.append((w, keep, last, user))
    with open(os.path.join(outdir, "rx_cnt.txt"), "w") as f:
        for k in o.RX_COUNTERS:
            f.write("%d\n" % rx.c[k])
    sig = o.fnv1a32([w for w, _, _, _ in words], nbytes=8)
    sig = o.fnv1a32([(kp | (l << 8) | (u << 9)) for _, kp, l, u in words],
                    nbytes=2, h=sig)
    return sig, rx.c


# ---------------------------------------------------------------------------
# L3: datapath completo (gen -> MAC TX -> PCS -> loopback -> PCS -> MAC RX ->
# checker). Contadores en el orden de los registros 0x40..0x7C.
# ---------------------------------------------------------------------------
L3_ORDER = ["tx_frames", "tx_bytes", "rx_ok", "rx_bytes", "rx_crc_err",
            "rx_runt", "rx_oversize", "rx_abort", "rx_filtered", "rx_proto",
            "chk_ok", "chk_bad", "chk_seq_err", "chk_rxerr", "slots",
            "tx_underrun"]

L3_CFGS = [
    ("l3a", 20, 1514, 37, 64, False),
    ("l3b", 20, 1514, 37, 64, True),
    ("l3c", 20, 90, 1, 71, False),
    ("l3d", 1400, 1700, 23, 24, False),   # incluye tramas oversize
]


def write_l3(outdir):
    sigs = {}
    for name, lmin, lmax, step, n, inj in L3_CFGS:
        cfg = o.GenCfg(len_min=lmin, len_max=lmax, len_step=step, count=n)
        r, _ = o.run_burst(cfg, n, inject=inj)
        vals = [r[k] for k in L3_ORDER]
        with open(os.path.join(outdir, "l3_%s.txt" % name), "w") as f:
            for v in vals:
                f.write("%d\n" % v)
        sig_vals = [v for k, v in zip(L3_ORDER, vals) if k != "slots"]
        sigs[name] = (o.fnv1a32(sig_vals), r)
    return sigs


# ---------------------------------------------------------------------------
# L2C: checker con tramas fabricadas (AXIS directo)
# ---------------------------------------------------------------------------
def write_chk(outdir):
    cfg = o.GenCfg()
    rnd = random.Random(5)
    frames = []      # (bytes entregados sin FCS, tuser)

    def good(seq, ln):
        return o.gen_frame_bytes(cfg, seq, ln) + [0] * max(0, 60 - ln)

    seq = 0
    for ln in (20, 23, 24, 59, 60, 61, 67, 200, 1514):
        frames.append((good(seq, ln), False)); seq += 1
    f = good(seq, 300); f[150] ^= 0x10                      # payload alterado
    frames.append((f, False)); seq += 1
    frames.append((good(seq, 300)[:-8], False)); seq += 1   # truncada 1 palabra
    frames.append((good(seq, 300) + [0] * 8, False)); seq += 1   # alargada (ceros)
    frames.append((good(seq, 40) + [0] * 3, False)); seq += 1    # pad de mas
    f = good(seq, 100); f[1] ^= 1                           # destino alterado
    frames.append((f, False)); seq += 1
    frames.append((good(seq, 80), True)); seq += 1           # tuser (mala en MAC)
    seq += 3                                                 # hueco de secuencia
    frames.append((good(seq, 90), False)); seq += 1
    f = good(seq, 30); f[40] = 0x5A                          # byte de pad no nulo
    frames.append((f, False)); seq += 1
    for ln in (61, 62, 63):
        frames.append((good(seq, ln), False)); seq += 1

    chk = o.Checker(cfg)
    lines = []
    for data, err in frames:
        chk.frame(data, err)
        k = (len(data) + 7) // 8
        for i in range(k):
            chunk = data[8 * i:8 * i + 8]
            last = int(i == k - 1)
            lines.append("%s %02X %d %d %d" % (
                hx(o.bytes_word(chunk)), (1 << len(chunk)) - 1, last,
                int(err) if last else 0, int(rnd.random() < 0.2)))
    with open(os.path.join(outdir, "chk_in.txt"), "w") as fo:
        fo.write("%d\n" % len(lines))
        fo.write("\n".join(lines) + "\n")
    vals = [chk.c[k] for k in o.CHK_COUNTERS]
    with open(os.path.join(outdir, "chk_cnt.txt"), "w") as fo:
        fo.write("\n".join(str(v) for v in vals) + "\n")
    return o.fnv1a32(vals), chk.c


# ---------------------------------------------------------------------------
# L1: paquete (CRC por n bytes, xorshift64, seed_of, constantes de bloque)
# ---------------------------------------------------------------------------
def write_l1(outdir):
    rnd = random.Random(1)
    lines, outs = [], []
    for i in range(400):
        st = rnd.getrandbits(32) if i % 4 else o.CRC_INIT
        d = rnd.getrandbits(64)
        n = 1 + (i % 8)
        c = o.crc_bits(st, d, 8 * n)
        x = o.xorshift64(d) if d else 1
        s = o.seed_of(st)
        lines.append("%08X %s %d %08X %s %s" % (st, hx(d), n, c, hx(x), hx(s)))
        outs += [c, x & 0xFFFFFFFF, x >> 32]
    with open(os.path.join(outdir, "l1_pkg.txt"), "w") as f:
        f.write("%d\n" % len(lines))
        f.write("\n".join(lines) + "\n")
    consts = [o.START_BLOCK, o.IDLE_BLOCK, o.ERROR_BLOCK] + o.BT_TERM
    with open(os.path.join(outdir, "l1_const.txt"), "w") as f:
        for c in consts:
            f.write(hx(c) + "\n")
    return o.fnv1a32(outs)


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(outdir, exist_ok=True)
    print("FNV32_L1=0x%08X" % write_l1(outdir))
    s, c = write_chk(outdir)
    print("FNV32_CHK=0x%08X  %s" % (s, " ".join("%s=%d" % kv for kv in c.items())))
    for k, (s, r) in write_l3(outdir).items():
        print("FNV32_%s=0x%08X  %s" % (k.upper(), s, " ".join(
            "%s=%d" % (n, r[n]) for n in L3_ORDER if r[n])))
    sigs = write_tx(outdir)
    for k, v in sigs.items():
        print("FNV32_%s=0x%08X" % (k.upper(), v))
    sig, c = write_rx(outdir)
    print("FNV32_RX=0x%08X" % sig)
    print("RX counters: " + " ".join("%s=%d" % (k, c[k]) for k in o.RX_COUNTERS))


if __name__ == "__main__":
    main()
