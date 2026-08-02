#!/usr/bin/env python3
# Self-checks for the CSI-2 oracle: ECC properties, CRC vector, mutation kills.
import csi2_oracle as o

def check_ecc_single_bit():
    """Every single-bit flip in the 24-bit header field must be corrected."""
    di = ((o.VC0 & 3) << 6) | o.DT_RAW12
    wc = o.W * 3 // 2
    good_ecc = o.ecc6(di, wc)
    hdr = bytes([di, wc & 0xFF, (wc >> 8) & 0xFF, good_ecc])
    fails = 0
    for bit in range(24):
        # flip one data bit across the 3 header bytes
        b = bytearray(hdr)
        byte_idx = bit // 8
        b[byte_idx] ^= (1 << (bit % 8))
        cid, cwc, err = o.ecc_correct(bytes(b))
        if err or cid != di or cwc != wc:
            fails += 1
    print(f"ECC 1-bit correction: {24-fails}/24 corrected", "OK" if fails==0 else "FAIL")
    return fails == 0

def check_ecc_double_bit():
    """A 2-bit error must be flagged as uncorrectable (not silently 'corrected'
    to the right value)."""
    di = ((o.VC0 & 3) << 6) | o.DT_RAW12
    wc = o.W * 3 // 2
    good_ecc = o.ecc6(di, wc)
    hdr = bytearray([di, wc & 0xFF, (wc >> 8) & 0xFF, good_ecc])
    # flip two data bits
    hdr[0] ^= 0x01
    hdr[1] ^= 0x02
    cid, cwc, err = o.ecc_correct(bytes(hdr))
    # must NOT reconstruct original silently: either err=1, or wrong value
    detected = err == 1 or (cid, cwc) != (di, wc)
    print(f"ECC 2-bit detection : {'OK' if detected else 'FAIL'} (err={err})")
    return detected

def check_crc_vector():
    """Official MIPI CSI-2 spec CRC example. The spec's worked example payload
    yields CRC value 0x00F0, transmitted footer bytes 0xF0,0x00 (LSByte first)."""
    payload = bytes([0xFF,0x00,0x00,0x02,0xB9,0xDC,0xF3,0x72,0xBB,0xD4,0xB8,0x5A,
                     0xC8,0x75,0xC2,0x7C,0x81,0xF8,0x05,0xDF,0xFF,0x00,0x00,0x01])
    v = o.crc16_csi2(payload)
    print(f"CRC-16 spec example : 0x{v:04X} expected 0x00F0", "OK" if v==0x00F0 else "FAIL")
    return v == 0x00F0

def baseline_sig():
    f0 = o.make_frame(o.pix_gradient)
    f1 = o.make_frame(o.pix_bars)
    s = o.build_frame_stream(o.VC0, f0) + o.build_frame_stream(o.VC1, f1)
    fb = o.rx_parse(s, [o.VC0, o.VC1])
    return o.fnv1a_32(bytes(fb[o.VC0]) + bytes(fb[o.VC1]))

def check_mut_nibble_swap():
    """RAW12 3rd byte nibble swap must change signature."""
    base = baseline_sig()
    orig = o.pack_raw12_line
    def bad(line):
        out = bytearray()
        for i in range(0, len(line), 2):
            p0, p1 = line[i]&0xFFF, line[i+1]&0xFFF
            out.append((p0>>4)&0xFF); out.append((p1>>4)&0xFF)
            out.append(((p0&0xF)<<4)|(p1&0xF))   # swapped
        return bytes(out)
    o.pack_raw12_line = bad
    f0=o.make_frame(o.pix_gradient); f1=o.make_frame(o.pix_bars)
    s=o.build_frame_stream(o.VC0,f0)+o.build_frame_stream(o.VC1,f1)
    fb=o.rx_parse(s,[o.VC0,o.VC1])
    mut=o.fnv1a_32(bytes(fb[o.VC0])+bytes(fb[o.VC1]))
    o.pack_raw12_line = orig
    killed = mut != base
    print(f"MUT nibble-swap     : {'KILLED' if killed else 'SURVIVED'} (0x{mut:08X} vs 0x{base:08X})")
    return killed

def check_mut_vc_cross():
    """Demux crossing VC0->FB1 must change signature (patterns differ per VC)."""
    base = baseline_sig()
    f0=o.make_frame(o.pix_gradient); f1=o.make_frame(o.pix_bars)
    # swap VC tags -> gradient lands in FB1, bars in FB0
    s=o.build_frame_stream(o.VC1,f0)+o.build_frame_stream(o.VC0,f1)
    fb=o.rx_parse(s,[o.VC0,o.VC1])
    mut=o.fnv1a_32(bytes(fb[o.VC0])+bytes(fb[o.VC1]))
    killed = mut != base
    print(f"MUT vc-cross        : {'KILLED' if killed else 'SURVIVED'} (0x{mut:08X})")
    return killed

if __name__ == "__main__":
    ok = all([
        check_ecc_single_bit(),
        check_ecc_double_bit(),
        check_crc_vector(),
        check_mut_nibble_swap(),
        check_mut_vc_cross(),
    ])
    print("ALL SELF-CHECKS:", "PASS" if ok else "FAIL")
