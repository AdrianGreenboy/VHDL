#!/usr/bin/env python3
# =============================================================================
# rf_model.py (AUDIT 2026-11) -- cycle-accurate, bit-exact model of
# rf_datapath.vhd, written from the RTL semantics (no code shared):
#   tone NCO -> stimulus (1 sample every 8 cycles) -> CIC sinc3 interpolator
#   (R=8) -> align reg -> RX NCO -> loop mixer (up + down conversion) ->
#   CIC sinc3 decimator (R=8) -> 16-tap FIR (5-stage pipeline) -> AGC
#   (manual shift 0) -> RX FIFO.
# Every register is updated from the values of the previous cycle (the model
# computes "next" from "current" for all blocks, then commits), exactly like
# the clocked VHDL processes.
#
# Numeric contract (AUDIT 2026-11, consistent with the DSP family):
#   every Q1.15 reduction ROUNDS HALF-UP: (v + 2**(s-1)) >> s, then sat16.
#   Applies to the CIC interpolator (>>6), the CIC decimator (>>9), the FIR
#   (>>15) and the loop mixer products (>>15). The AGC power estimate (RSSI)
#   keeps its truncating >>15 (it is a statistic, not a signal path).
#   round=False reproduces the historical truncating RTL (golden 0xB74940EB)
#   and is kept only to prove the model against the silicon-validated build.
#
# Usage:
#   python3 rf_model.py                 -> prints checksums (trunc + round)
#   python3 rf_model.py --dump FILE     -> writes the per-sample oracle for
#                                          tb_datapath (several op points)
# =============================================================================
import sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
LUT = [int(l) for l in open(os.path.join(HERE, "lut_vals.txt")) if l.strip()]
assert len(LUT) == 1024

M32 = 0xFFFFFFFF


def wrap32(v):
    v &= M32
    return v - (1 << 32) if v & 0x80000000 else v


def sat16(v):
    return 32767 if v > 32767 else (-32768 if v < -32768 else v)


def red(v, s, rnd):
    """Arithmetic right shift by s; round half-up if rnd."""
    if rnd and s > 0:
        v += 1 << (s - 1)
    return v >> s


def run_datapath(ftw_rx, tone_ftw, coefs, nsamp=64, rnd=True, max_cycles=200000):
    R = 8
    SH_INT = 2 * (1 + 2)      # rf_cic_int: >> 2*(sel+2), sel=1
    SH_DEC = 3 * (1 + 2)      # rf_cic_dec: >> 3*(sel+2), sel=1
    st = dict(
        t_fase=0, t_sin=0, t_cos=0, t_v=0,
        bb_v=0, bb_i=0, bb_q=0, gap=0,
        ci1=[0, 0], ci2=[0, 0], ci3=[0, 0], cd1=[0, 0], cd2=[0, 0], cd3=[0, 0],
        run=0, itp=[0, 0], itp_v=0,
        itpd=[0, 0], itpd_v=0,
        n_fase=0, n_sin=0, n_cos=0, n_v=0,
        lm=[0, 0], lm_v=0,
        di1=[0, 0], di2=[0, 0], di3=[0, 0], dd1=[0, 0], dd2=[0, 0], dd3=[0, 0],
        cnt=0, dec=[0, 0], dec_v=0,
        hist=[[0] * 16, [0] * 16], p=[[0] * 16, [0] * 16], a8=[[0] * 8, [0] * 8],
        a4=[[0] * 4, [0] * 4], a2=[[0] * 2, [0] * 2], fir=[0, 0], vr=[0] * 5,
        agc=[0, 0], agc_v=0,
    )
    out = []
    for _ in range(max_cycles):
        s = st
        n = {k: (list(map(list, v)) if isinstance(v, list) and v and isinstance(v[0], list)
                 else (list(v) if isinstance(v, list) else v)) for k, v in s.items()}
        # ---- tone NCO (en = rx_en = 1)
        idx = (s['t_fase'] >> 22) & 0x3FF
        n['t_sin'] = LUT[idx]; n['t_cos'] = LUT[(idx + 256) % 1024]; n['t_v'] = 1
        n['t_fase'] = (s['t_fase'] + tone_ftw) & M32
        # ---- stimulus
        n['bb_v'] = 0
        if s['t_v']:
            if s['gap'] == 0:
                n['bb_i'] = s['t_cos']; n['bb_q'] = s['t_sin']; n['bb_v'] = 1; n['gap'] = R - 1
            else:
                n['gap'] = s['gap'] - 1
        # ---- CIC interpolator
        n['itp_v'] = 0
        u = [0, 0]
        if s['bb_v']:
            for c, x in enumerate((s['bb_i'], s['bb_q'])):
                c1 = x - s['cd1'][c]; c2 = c1 - s['cd2'][c]; c3 = c2 - s['cd3'][c]
                n['cd1'][c] = x; n['cd2'][c] = c1; n['cd3'][c] = c2
                u[c] = wrap32(c3)
            n['run'] = R - 1
        elif s['run'] > 0:
            n['run'] = s['run'] - 1
        if s['bb_v'] or s['run'] > 0:
            for c in range(2):
                n['itp'][c] = sat16(red(s['ci3'][c], SH_INT, rnd))
                n['ci3'][c] = wrap32(s['ci3'][c] + s['ci2'][c])
                n['ci2'][c] = wrap32(s['ci2'][c] + s['ci1'][c])
                n['ci1'][c] = wrap32(s['ci1'][c] + u[c])
            n['itp_v'] = 1
        # ---- align register
        n['itpd'] = list(s['itp']); n['itpd_v'] = s['itp_v']
        # ---- RX NCO (en = itp_v)
        n['n_v'] = 0
        if s['itp_v']:
            idx = (s['n_fase'] >> 22) & 0x3FF
            n['n_sin'] = LUT[idx]; n['n_cos'] = LUT[(idx + 256) % 1024]; n['n_v'] = 1
            n['n_fase'] = (s['n_fase'] + ftw_rx) & M32
        # ---- loop mixer (valid = itpd_v), up- then down-conversion
        n['lm_v'] = 0
        if s['itpd_v']:
            bi, bq = s['itpd']; sn, cs = s['n_sin'], s['n_cos']
            rfi = sat16(red(bi * cs - bq * sn, 15, rnd))
            rfq = sat16(red(bq * cs + bi * sn, 15, rnd))
            n['lm'] = [sat16(red(rfi * cs + rfq * sn, 15, rnd)),
                       sat16(red(rfq * cs - rfi * sn, 15, rnd))]
            n['lm_v'] = 1
        # ---- CIC decimator (valid = lm_v)
        n['dec_v'] = 0
        if s['lm_v']:
            if s['cnt'] == R - 1:
                for c in range(2):
                    v = s['di3'][c]
                    c1 = wrap32(v - s['dd1'][c]); c2 = wrap32(c1 - s['dd2'][c]); c3 = wrap32(c2 - s['dd3'][c])
                    n['dd1'][c] = v; n['dd2'][c] = c1; n['dd3'][c] = c2
                    n['dec'][c] = sat16(red(c3, SH_DEC, rnd))
                n['dec_v'] = 1; n['cnt'] = 0
            else:
                n['cnt'] = s['cnt'] + 1
            for c in range(2):
                n['di3'][c] = wrap32(s['di3'][c] + s['di2'][c])
                n['di2'][c] = wrap32(s['di2'][c] + s['di1'][c])
                n['di1'][c] = wrap32(s['di1'][c] + s['lm'][c])
        # ---- FIR (5-stage pipeline, valid chain)
        n['vr'] = [s['dec_v']] + s['vr'][:4]
        for c in range(2):
            if s['dec_v']:
                x = s['dec'][c]; h = s['hist'][c]
                n['p'][c] = [coefs[0] * x] + [coefs[k] * h[k - 1] for k in range(1, 16)]
                n['hist'][c] = [x] + h[:15]
            pp = s['p'][c]
            n['a8'][c] = [pp[2 * k] + pp[2 * k + 1] for k in range(8)]
            n['a4'][c] = [s['a8'][c][2 * k] + s['a8'][c][2 * k + 1] for k in range(4)]
            n['a2'][c] = [s['a4'][c][2 * k] + s['a4'][c][2 * k + 1] for k in range(2)]
            n['fir'][c] = sat16(red(s['a2'][c][0] + s['a2'][c][1], 15, rnd))
        fir_valid = s['vr'][4]
        # ---- AGC (agc_en=0, shift 0 -> identity with sat)
        n['agc_v'] = 0
        if fir_valid:
            n['agc'] = [sat16(s['fir'][0]), sat16(s['fir'][1])]
            n['agc_v'] = 1
        # ---- RX FIFO write (wr_en = agc valid_o)
        if s['agc_v']:
            out.append(((s['agc'][0] & 0xFFFF) << 16) | (s['agc'][1] & 0xFFFF))
            if len(out) == nsamp:
                return out
        st = n
    raise RuntimeError("model did not produce enough samples")


def checksum(words):
    chk = 0
    for w in words:
        chk = (((chk << 1) | (chk >> 31)) & M32) ^ w
    return chk


# Operating points for tb_datapath (AUDIT 2026-11). OP0 is the historical
# bring-up point (DC tone, passthrough FIR); OP1/OP2 exercise a moving tone,
# a real low-pass FIR with negative taps and different RX NCO frequencies.
PASS = [0x7FFF] + [0] * 15
LPF = [-296, -650, -480, 860, 3352, 6290, 8580, 9400,
       8580, 6290, 3352, 860, -480, -650, -296, 0]
HPFISH = [12000, -9000, 7000, -5000, 3000, -1500, 600, -100,
          0, 0, 0, 0, 0, 0, 0, 0]
OPS = [
    ("op0_dc_pass",   0x0293A800, 0x00000000, PASS),
    ("op1_tone_lpf",  0x0293A800, 0x01234567, LPF),
    ("op2_mix_hpf",   0x12345678, 0x00ABCDEF, HPFISH),
]


def main():
    nsamp = 64
    if len(sys.argv) >= 3 and sys.argv[1] == "--dump":
        with open(sys.argv[2], "w") as f:
            f.write("%d\n" % len(OPS))
            for name, ftw, tone, cf in OPS:
                w = run_datapath(ftw, tone, cf, nsamp, rnd=True)
                f.write("OP %08X %08X %d %08X\n" % (ftw, tone, nsamp, checksum(w)))
                f.write(" ".join("%04X" % (c & 0xFFFF) for c in cf) + "\n")
                for x in w:
                    f.write("%08X\n" % x)
                print("%-14s ftw=%08X tone=%08X CHK=0x%08X" % (name, ftw, tone, checksum(w)))
        return
    w_t = run_datapath(0x0293A800, 0, PASS, nsamp, rnd=False)
    w_r = run_datapath(0x0293A800, 0, PASS, nsamp, rnd=True)
    print("historical truncating RTL : CHK=0x%08X (expect 0xB74940EB)" % checksum(w_t))
    print("round-half-up (AUDIT)     : CHK=0x%08X" % checksum(w_r))
    for name, ftw, tone, cf in OPS:
        w = run_datapath(ftw, tone, cf, nsamp, rnd=True)
        print("%-14s CHK=0x%08X  first=%08X" % (name, checksum(w), w[0]))


if __name__ == "__main__":
    main()
