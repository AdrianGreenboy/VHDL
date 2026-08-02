#!/usr/bin/env python3
# =============================================================================
# HERCOSSNUX Core 18 - MIPI CSI-2 RX
# bin2mem: convert a flat RV32 .bin into the .mem format GHDL reads with hread.
# Output: one 32-bit little-endian word per line, 8 hex digits, no address.
# Matches the load() function in dp_ram.vhd / axi_ddr_sim.vhd.
#
# Usage: python3 bin2mem.py fw_rv32.bin fw_rv32.mem [depth_words]
# =============================================================================
import sys

def main():
    if len(sys.argv) < 3:
        print("usage: bin2mem.py <in.bin> <out.mem> [depth_words]")
        sys.exit(1)
    inp, outp = sys.argv[1], sys.argv[2]
    depth = int(sys.argv[3]) if len(sys.argv) > 3 else None

    data = open(inp, 'rb').read()
    # pad to a multiple of 4 bytes
    if len(data) % 4:
        data += b'\x00' * (4 - (len(data) % 4))
    nwords = len(data) // 4

    with open(outp, 'w') as f:
        for i in range(nwords):
            w = data[i*4] | (data[i*4+1] << 8) | (data[i*4+2] << 16) | (data[i*4+3] << 24)
            f.write('%08X\n' % w)
        # pad with zeros up to depth if requested (fills the rest of the RAM)
        if depth:
            for _ in range(nwords, depth):
                f.write('00000000\n')

    print('%s : %d words%s' % (outp, nwords, (' (padded to %d)' % depth) if depth else ''))

if __name__ == '__main__':
    main()
