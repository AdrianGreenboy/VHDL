#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX Core 18 - MIPI CSI-2 RX
# Generates all simulation test vectors from the oracle (single source of truth).
# Produces: l1_packed.hex, ecc_vec.txt, l2_stream.hex, l3_stream.hex, l4_stream.hex
# Run from the verif/ directory (imports csi2_oracle).
# =============================================================================
import csi2_oracle as o

# ---------------- L1: RAW12 unpack vectors ----------------
def gen_l1():
    W = o.W
    f_grad = o.make_frame(o.pix_gradient)
    f_bars = o.make_frame(o.pix_bars)
    lines = [
        ('grad_y0',  f_grad[0]),
        ('grad_y31', f_grad[31]),
        ('bars_y0',  f_bars[0]),
        ('allmax',   [0xFFF]*W),
        ('allzero',  [0x000]*W),
        ('ramp12',   [(x*32)&0xFFF for x in range(W)]),
    ]
    packed = bytearray()
    for _, line in lines:
        packed += o.pack_raw12_line(line)
    with open('l1_packed.hex','w') as fp:
        for b in packed:
            fp.write('%02X\n' % b)
    print('l1_packed.hex :', len(packed), 'bytes  (expect L1 sig 0xEC935F45)')

# ---------------- L2: ECC vectors + packet stream ----------------
def gen_ecc():
    di = ((o.VC0&3)<<6)|o.DT_RAW12
    wc = 12
    val = (di & 0xFF) | ((wc & 0xFFFF)<<8)
    ecc = o.ecc6(di, wc)
    lines = ['%06X %02X %06X 0'%(val,ecc,val)]
    for i in range(24):
        v=val^(1<<i); lines.append('%06X %02X %06X 0'%(v,ecc,val))
    for p in range(6):
        e=ecc^(1<<p); lines.append('%06X %02X %06X 0'%(val,e,val))
    for (a,b) in [(0,1),(3,7),(10,20),(5,23)]:
        v=val^(1<<a)^(1<<b); lines.append('%06X %02X %06X 1'%(v,ecc,val))
    open('ecc_vec.txt','w').write('\n'.join(lines)+'\n')
    print('ecc_vec.txt   :', len(lines), 'vectors')

def gen_l2():
    pl_a = bytes([(i*7+3) & 0xFF for i in range(12)])
    pl_b = bytes([(i*13+1) & 0xFF for i in range(9)])
    pl_c = bytes([(0xA0 ^ i) & 0xFF for i in range(6)])
    stream = bytearray()
    stream += o.short_packet(o.VC0, o.DT_FS, 0)
    stream += o.long_packet(o.VC0, o.DT_RAW12, pl_a)
    p3 = bytearray(o.long_packet(o.VC1, o.DT_RAW12, pl_b))
    p3[1] ^= 0x04                      # inject 1-bit header error (ECC corrects)
    stream += p3
    stream += o.long_packet(o.VC0, o.DT_RAW12, pl_c)
    stream += o.short_packet(o.VC0, o.DT_FE, 0)
    with open('l2_stream.hex','w') as fp:
        for b in stream: fp.write('%02X\n' % b)
    print('l2_stream.hex :', len(stream), 'bytes  (expect L2 sig 0xADBF2613)')

# ---------------- L3: single-VC full frame ----------------
def gen_l3():
    f0 = o.make_frame(o.pix_gradient)
    stream = o.build_frame_stream(o.VC0, f0, 0)
    with open('l3_stream.hex','w') as fp:
        for b in stream: fp.write('%02X\n' % b)
    print('l3_stream.hex :', len(stream), 'bytes  (expect L3 sig 0x0C4F29C5)')

# ---------------- L4: dual-VC ----------------
def gen_l4():
    f0 = o.make_frame(o.pix_gradient)
    f1 = o.make_frame(o.pix_bars)
    stream = o.build_frame_stream(o.VC0, f0, 0) + o.build_frame_stream(o.VC1, f1, 0)
    with open('l4_stream.hex','w') as fp:
        for b in stream: fp.write('%02X\n' % b)
    print('l4_stream.hex :', len(stream), 'bytes  (expect L4 sig 0xE6898DC5)')

# ---------------- L6 (AUDIT 2026-11): PPI / lane layer, burst level --------
# One CSI-2 packet per HS burst (as a D-PHY sensor sends them). VC0 and VC1
# frames are interleaved line by line and carry deliberate faults:
#   VC0 line 5 : 2-bit header error   -> aborted (pkt_err)
#   VC0 line 9 : payload bit flip     -> CRC drop
#   VC1 line 13: burst truncated      -> aborted (pkt_err)
#   VC1 line 20: 1-bit header error   -> corrected, stored
#   VC0 3 extra lines after line H-1  -> FB0 exactly full, 3rd -> fb_ovf
# then a second, 3-line frame on VC1 (FS must rewind FB1).
# Files: l6_bursts.hex (one burst per line, hex bytes), l6_fb0.hex,
#        l6_fb1.hex (expected framebuffer bytes), l6_expect.txt (counters).
L6_FB_DEPTH = 18432
def l6_bursts():
    f0 = o.make_frame(o.pix_gradient)
    f1 = o.make_frame(o.pix_bars)
    b = []
    b.append(o.short_packet(o.VC0, o.DT_FS, 0))
    b.append(o.short_packet(o.VC1, o.DT_FS, 0))
    for y in range(o.H):
        p0 = bytearray(o.long_packet(o.VC0, o.DT_RAW12, o.pack_raw12_line(f0[y])))
        p1 = bytearray(o.long_packet(o.VC1, o.DT_RAW12, o.pack_raw12_line(f1[y])))
        if y == 5:  p0[0] ^= 0x01; p0[2] ^= 0x10      # 2-bit header error
        if y == 9:  p0[40] ^= 0x08                     # CRC error
        if y == 13: p1 = p1[:4 + 60]                   # truncated burst
        if y == 20: p1[1] ^= 0x20                      # 1-bit header error
        b.append(bytes(p0)); b.append(bytes(p1))
    # 94 VC0 lines survived the faults: 2 extra lines fill FB0 exactly
    # (18432 bytes), the 3rd one does not fit -> fb_ovf, dropped.
    for e in range(3):
        extra = [((x * 7 + 3 + e) & 0xFFF) for x in range(o.W)]
        b.append(o.long_packet(o.VC0, o.DT_RAW12, o.pack_raw12_line(extra)))
    b.append(o.short_packet(o.VC0, o.DT_FE, 0))
    b.append(o.short_packet(o.VC1, o.DT_FE, 0))
    # second (short) frame on VC1
    b.append(o.short_packet(o.VC1, o.DT_FS, 1))
    for y in range(3):
        line = [((x + 100 * y) * 13) & 0xFFF for x in range(o.W)]
        b.append(o.long_packet(o.VC1, o.DT_RAW12, o.pack_raw12_line(line)))
    b.append(o.short_packet(o.VC1, o.DT_FE, 1))
    return b

def gen_l6():
    bursts = l6_bursts()
    fb, cnt = o.rx_parse_bursts(bursts, L6_FB_DEPTH, multi_pkt=False)
    with open('l6_bursts.hex', 'w') as fp:
        fp.write('%d\n' % len(bursts))
        for bu in bursts:
            fp.write('%d %s\n' % (len(bu), ' '.join('%02X' % x for x in bu)))
    for vc in (0, 1):
        with open('l6_fb%d.hex' % vc, 'w') as fp:
            fp.write('%d\n' % len(fb[vc]))
            for x in fb[vc]:
                fp.write('%02X\n' % x)
    with open('l6_expect.txt', 'w') as fp:
        fp.write('%d %d %d\n' % (cnt['pkt_err'], cnt['fb_ovf'], cnt['frame']))
    print('l6_bursts.hex :', len(bursts), 'bursts, FB0=%d FB1=%d bytes, %s'
          % (len(fb[0]), len(fb[1]), cnt))

if __name__ == '__main__':
    gen_l1(); gen_ecc(); gen_l2(); gen_l3(); gen_l4(); gen_l6()
    print('all vectors generated.')
