#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX Core 18 - MIPI CSI-2 RX 4-lane RAW12
# Python oracle: golden model for the CSI-2 packing/unpacking datapath.
# This file is the SINGLE SOURCE OF TRUTH for all downstream RTL signatures.
#
# Pipeline modeled:
#   frame(pattern) -> pixels -> RAW12 pack -> CSI-2 packets (SP/LP + ECC + CRC)
#                 -> byte stream (as delivered by the byte-clock D-PHY model)
#                 -> RX unpack -> per-VC framebuffers -> FNV-1a signature
#
# Bit-exact conventions (must match RTL byte-for-byte):
#   * Data ID   = (VC<<6) | DataType ; RAW12 DataType = 0x2C
#   * Word Count = payload byte count, little-endian (LSByte first)
#   * ECC       = MIPI D-PHY 24->6 Hamming over {DataID, WC_L, WC_H}
#   * CRC-16    = MIPI CSI-2 poly 0x1021, init 0xFFFF, LSB-first per byte
#   * RAW12 pack: two pixels P0,P1 -> 3 bytes:
#                   b0 = P0[11:4]
#                   b1 = P1[11:4]
#                   b2 = (P1[3:0]<<4) | P0[3:0]
# =============================================================================

import sys

# ----------------------------------------------------------------------------
# Frozen scope parameters
# ----------------------------------------------------------------------------
W = 128
H = 96
DT_RAW12 = 0x2C
VC0 = 0
VC1 = 1
BAR_W = 16  # vertical bar width

# ----------------------------------------------------------------------------
# Test patterns (12-bit pixels)
# ----------------------------------------------------------------------------
def pix_gradient(x, y):
    return (y * W + x) & 0xFFF

def pix_bars(x, y):
    return 0xFFF if ((x // BAR_W) & 1) == 1 else 0x000

def make_frame(pattern):
    return [[pattern(x, y) for x in range(W)] for y in range(H)]

# ----------------------------------------------------------------------------
# RAW12 packing: one line of W pixels -> (W*3//2) bytes
# ----------------------------------------------------------------------------
def pack_raw12_line(line):
    assert len(line) % 2 == 0, "RAW12 needs even pixel count per line"
    out = bytearray()
    for i in range(0, len(line), 2):
        p0 = line[i] & 0xFFF
        p1 = line[i + 1] & 0xFFF
        out.append((p0 >> 4) & 0xFF)
        out.append((p1 >> 4) & 0xFF)
        out.append(((p1 & 0xF) << 4) | (p0 & 0xF))
    return bytes(out)

def unpack_raw12_line(data, npix):
    line = []
    for i in range(0, len(data), 3):
        b0, b1, b2 = data[i], data[i + 1], data[i + 2]
        p0 = (b0 << 4) | (b2 & 0x0F)
        p1 = (b1 << 4) | ((b2 >> 4) & 0x0F)
        line.append(p0 & 0xFFF)
        line.append(p1 & 0xFFF)
    return line[:npix]

# ----------------------------------------------------------------------------
# MIPI D-PHY 24->6 Hamming ECC over the 3 header bytes (DataID, WC_L, WC_H).
# Standard CSI-2 / D-PHY parity equations. Bit index d0..d23 = LSB-first
# across the 3 bytes: d0..d7 = DataID, d8..d15 = WC_L, d16..d23 = WC_H.
# ----------------------------------------------------------------------------
# Canonical parity bit -> contributing data-bit index masks (from D-PHY spec).
_ECC_MASKS = [
    # P0
    [0,1,2,4,5,7,10,11,13,16,20,21,22,23],
    # P1
    [0,1,3,4,6,8,10,12,14,17,20,21,22,23],
    # P2
    [0,2,3,5,6,9,11,12,15,18,20,21,22],
    # P3
    [1,2,3,7,8,9,13,14,15,19,20,21,23],
    # P4
    [4,5,6,7,8,9,16,17,18,19,20,22,23],
    # P5
    [10,11,12,13,14,15,16,17,18,19,21,22,23],
]

def ecc6(data_id, wc):
    bits = []
    val = (data_id & 0xFF) | ((wc & 0xFFFF) << 8)  # 24-bit little-endian field
    for i in range(24):
        bits.append((val >> i) & 1)
    ecc = 0
    for p, mask in enumerate(_ECC_MASKS):
        parity = 0
        for idx in mask:
            parity ^= bits[idx]
        ecc |= (parity << p)
    return ecc & 0x3F

# ----------------------------------------------------------------------------
# MIPI CSI-2 CRC-16: poly 0x1021, init 0xFFFF, reflected (LSB-first) per byte.
# ----------------------------------------------------------------------------
def crc16_csi2(data):
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0x8408   # 0x1021 bit-reversed
            else:
                crc >>= 1
    return crc & 0xFFFF

# ----------------------------------------------------------------------------
# Packet builders
# ----------------------------------------------------------------------------
def short_packet(vc, dt, data16):
    """Short packet: DataID, 2 data bytes (LE), ECC. 4 bytes total."""
    data_id = ((vc & 0x3) << 6) | (dt & 0x3F)
    wc = data16 & 0xFFFF  # for SP, WC field carries the frame/line number
    e = ecc6(data_id, wc)
    return bytes([data_id, wc & 0xFF, (wc >> 8) & 0xFF, e])

def long_packet(vc, dt, payload):
    """Long packet: header(DataID,WC_L,WC_H,ECC) + payload + CRC16(LE)."""
    data_id = ((vc & 0x3) << 6) | (dt & 0x3F)
    wc = len(payload) & 0xFFFF
    e = ecc6(data_id, wc)
    hdr = bytes([data_id, wc & 0xFF, (wc >> 8) & 0xFF, e])
    crc = crc16_csi2(payload)
    ftr = bytes([crc & 0xFF, (crc >> 8) & 0xFF])
    return hdr + bytes(payload) + ftr

# Short packet data types
DT_FS = 0x00  # Frame Start
DT_FE = 0x01  # Frame End
DT_LS = 0x02  # Line Start
DT_LE = 0x03  # Line End

def build_frame_stream(vc, frame, frame_num=0, with_line_sync=False):
    """Full CSI-2 byte stream for one frame on one VC."""
    stream = bytearray()
    stream += short_packet(vc, DT_FS, frame_num)
    for y, line in enumerate(frame):
        if with_line_sync:
            stream += short_packet(vc, DT_LS, y)
        payload = pack_raw12_line(line)
        stream += long_packet(vc, DT_RAW12, payload)
        if with_line_sync:
            stream += short_packet(vc, DT_LE, y)
    stream += short_packet(vc, DT_FE, frame_num)
    return bytes(stream)

# ----------------------------------------------------------------------------
# RX: parse a byte stream back into per-VC framebuffers.
# Framebuffer layout in local RAM (and DDR): packed RAW12 bytes, line by line,
# exactly as received (the RX writes de-packetized payload, not re-expanded).
# Signature is computed over the packed framebuffer bytes.
# ----------------------------------------------------------------------------
def ecc_correct(hdr3):
    """Decode a 3-byte+ECC header. Returns (data_id, wc, err) with 1-bit
    correction. err: 0=ok/corrected, 1=uncorrectable(2-bit)."""
    data_id, wc_l, wc_h, rx_ecc = hdr3[0], hdr3[1], hdr3[2], hdr3[3]
    wc = wc_l | (wc_h << 8)
    calc = ecc6(data_id, wc)
    syn = calc ^ rx_ecc
    if syn == 0:
        return data_id, wc, 0
    # single-bit error: syndrome maps to a data or ecc bit. For the oracle we
    # recompute after flipping each of the 24 data bits; if one matches, correct.
    val = (data_id & 0xFF) | ((wc & 0xFFFF) << 8)
    for i in range(24):
        cand = val ^ (1 << i)
        cid = cand & 0xFF
        cwc = (cand >> 8) & 0xFFFF
        if ecc6(cid, cwc) == rx_ecc:
            return cid, cwc, 0
    # syndrome could also indicate a flipped ECC bit (data intact)
    for p in range(6):
        if (rx_ecc ^ (1 << p)) == calc:
            return data_id, wc, 0
    return data_id, wc, 1  # uncorrectable

class RxParseError(Exception):
    pass

def rx_parse(stream, expected_vcs):
    """Parse stream -> {vc: bytearray(framebuffer)}. Validates ECC + CRC."""
    fb = {vc: bytearray() for vc in expected_vcs}
    i = 0
    n = len(stream)
    while i + 4 <= n:
        hdr = stream[i:i+4]
        data_id, wc, err = ecc_correct(hdr)
        if err:
            raise RxParseError(f"uncorrectable header at {i}")
        vc = (data_id >> 6) & 0x3
        dt = data_id & 0x3F
        if dt in (DT_FS, DT_FE, DT_LS, DT_LE):
            i += 4  # short packet consumed
            continue
        # long packet
        payload = stream[i+4:i+4+wc]
        crc_rx = stream[i+4+wc] | (stream[i+4+wc+1] << 8)
        if crc16_csi2(payload) != crc_rx:
            raise RxParseError(f"CRC mismatch at {i}")
        if vc in fb:
            fb[vc] += payload
        i += 4 + wc + 2
    return fb

# ----------------------------------------------------------------------------
# FNV-1a 32-bit over the concatenated framebuffers (FB0 then FB1).
# ----------------------------------------------------------------------------
def fnv1a_32(data):
    h = 0x811C9DC5
    for byte in data:
        h ^= byte
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h

# ----------------------------------------------------------------------------
# Main: build both VC frames, stream, parse, sign.
# ----------------------------------------------------------------------------
def main():
    f0 = make_frame(pix_gradient)   # VC0
    f1 = make_frame(pix_bars)       # VC1

    s0 = build_frame_stream(VC0, f0, frame_num=0)
    s1 = build_frame_stream(VC1, f1, frame_num=0)
    stream = s0 + s1

    fb = rx_parse(stream, expected_vcs=[VC0, VC1])

    # sanity: framebuffer sizes
    exp_bytes = H * (W * 3 // 2)
    assert len(fb[VC0]) == exp_bytes, (len(fb[VC0]), exp_bytes)
    assert len(fb[VC1]) == exp_bytes, (len(fb[VC1]), exp_bytes)

    # round-trip check: unpack framebuffer, compare to source pixels
    for vc, src in ((VC0, f0), (VC1, f1)):
        stride = W * 3 // 2
        for y in range(H):
            row = fb[vc][y*stride:(y+1)*stride]
            got = unpack_raw12_line(row, W)
            assert got == src[y], f"roundtrip fail vc{vc} line{y}"

    concat = bytes(fb[VC0]) + bytes(fb[VC1])
    sig = fnv1a_32(concat)

    print(f"# CSI-2 RX oracle - HERCOSSNUX Core 18")
    print(f"W x H            : {W} x {H} RAW12")
    print(f"VC0 pattern      : gradient")
    print(f"VC1 pattern      : vertical bars (w={BAR_W})")
    print(f"stream bytes     : {len(stream)}")
    print(f"FB per VC bytes  : {exp_bytes}")
    print(f"FB total bytes   : {len(concat)}")
    print(f"FNV-1a signature : 0x{sig:08X}")

    # emit a few reference values useful for RTL bring-up
    di0 = ((VC0 & 3) << 6) | DT_RAW12
    di1 = ((VC1 & 3) << 6) | DT_RAW12
    wc = W * 3 // 2
    print(f"--- reference header values ---")
    print(f"VC0 LP DataID    : 0x{di0:02X}  WC={wc}  ECC=0x{ecc6(di0,wc):02X}")
    print(f"VC1 LP DataID    : 0x{di1:02X}  WC={wc}  ECC=0x{ecc6(di1,wc):02X}")
    print(f"FS VC0 DataID    : 0x{((VC0&3)<<6)|DT_FS:02X}  ECC=0x{ecc6(((VC0&3)<<6)|DT_FS,0):02X}")

    return sig

if __name__ == "__main__":
    main()
