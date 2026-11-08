#!/usr/bin/env python3
"""
Independent IEEE 802.3 clause-49 64B/66B reference (audit 2026-11).

Written from the standard text only (no code shared with the RTL or with the
other oracles of this core):
  * 49.2.4.3 / Fig. 49-7: each 66-bit block = 2-bit sync header + 64-bit
    payload. The header is transmitted first: data blocks "01", control
    blocks "10", listed in TRANSMISSION order (first bit first).
  * 49.2.6 / Fig. 49-8: self-synchronous scrambler G(x) = 1 + x^39 + x^58
    on the 64 payload bits only, payload bit 0 (TXD<0> / first byte LSB)
    first:  out = in ^ S[38] ^ S[57], S = previous scrambler OUTPUT bits,
    S[0] most recent. The header is not scrambled.
  * The initial scrambler state is not defined by the standard (the
    descrambler self-synchronises); this model and the RTL both start with
    all 58 bits at 1, which is the only implementation choice shared.
  * PMA boundary used by the Core 19/20 gearbox: wire bit k goes to bit
    (k mod 64) of the k//64-th 64-bit word (word bit 0 is serialised first).

Usage:
  cl49_ref.py tx  <nblk> <seed> <blocks.txt> <words.txt>  [<blk66.txt>]
      random blocks (type + 64-bit payload) and the exact TX word stream
      (and the 66-bit blocks, wire bit i = bit i of the 66-bit value)
  cl49_ref.py rx  <nblk> <seed> <offset> <words.txt> <blocks.txt> [<b0> <bn>]
      a wire stream preceded by <offset> random bits (block boundary
      unknown to the receiver), packed in 64-bit words; blocks.txt = the
      transmitted blocks (expected receiver output, in order). Optional:
      the sync headers of blocks b0 .. b0+bn-1 are corrupted ("00"/"11")
  cl49_ref.py selftest
"""
import random
import sys

MASK64 = (1 << 64) - 1


class Scrambler:
    def __init__(self):
        self.s = [1] * 58          # s[0] = most recent output bit

    def bits(self, payload):
        out = []
        for i in range(64):
            b = (payload >> i) & 1
            o = b ^ self.s[38] ^ self.s[57]
            out.append(o)
            self.s = [o] + self.s[:57]
        return out


class Descrambler:
    def __init__(self):
        self.s = [0] * 58          # arbitrary: self-synchronising

    def payload(self, bits):
        v = 0
        for i, b in enumerate(bits):
            o = b ^ self.s[38] ^ self.s[57]
            v |= o << i
            self.s = [b] + self.s[:57]
        return v


def encode(blocks):
    """blocks: list of (is_data, payload64) -> list of wire bits."""
    scr = Scrambler()
    wire = []
    for is_data, pl in blocks:
        wire += [0, 1] if is_data else [1, 0]      # Fig. 49-7, first bit first
        wire += scr.bits(pl)
    return wire


def decode(wire):
    """Reference receiver for self-test: assumes alignment at bit 0."""
    des = Descrambler()
    out = []
    for k in range(0, len(wire) - 65, 66):
        h = wire[k:k + 2]
        pl = des.payload(wire[k + 2:k + 66])
        out.append((h == [0, 1], h in ([0, 1], [1, 0]), pl))
    return out


def pack_words(wire):
    words = []
    for k in range(0, len(wire) - 63, 64):
        v = 0
        for i in range(64):
            v |= wire[k + i] << i
        words.append(v)
    return words


def rand_blocks(n, rnd):
    blks = []
    for _ in range(n):
        if rnd.random() < 0.4:
            # control block: a block type byte of Fig. 49-7 in byte 0
            bt = rnd.choice([0x1E, 0x78, 0x87, 0x99, 0xAA, 0xB4, 0xCC, 0xD2,
                             0xE1, 0xFF, 0x4B, 0x2D, 0x33, 0x66, 0x55])
            blks.append((False, (rnd.getrandbits(56) << 8) | bt))
        else:
            blks.append((True, rnd.getrandbits(64)))
    return blks


def write_blocks(path, blks):
    with open(path, "w") as f:
        for d, pl in blks:
            f.write("%s %016X\n" % ("D" if d else "C", pl))


def cmd_tx(n, seed, fblk, fwords, f66=None):
    rnd = random.Random(seed)
    blks = rand_blocks(n, rnd)
    wire = encode(blks)
    write_blocks(fblk, blks)
    with open(fwords, "w") as f:
        for w in pack_words(wire):
            f.write("%016X\n" % w)
    if f66:
        with open(f66, "w") as f:
            for k in range(0, len(wire), 66):
                v = 0
                for i in range(66):
                    v |= wire[k + i] << i
                f.write("%017X\n" % v)


def cmd_rx(n, seed, offset, fwords, fblk, b0=0, bn=0):
    rnd = random.Random(seed)
    blks = rand_blocks(n, rnd)
    enc = encode(blks)
    for b in range(b0, b0 + bn):
        v = b & 1
        enc[66 * b] = v; enc[66 * b + 1] = v          # invalid header 00/11
    wire = [rnd.getrandbits(1) for _ in range(offset)] + enc
    write_blocks(fblk, blks)
    with open(fwords, "w") as f:
        for w in pack_words(wire):
            f.write("%016X\n" % w)


def selftest():
    rnd = random.Random(1)
    blks = rand_blocks(500, rnd)
    dec = decode(encode(blks))
    # the descrambler is synchronised after the first block
    for (d, pl), (dd, ok, dpl) in list(zip(blks, dec))[1:]:
        assert ok and dd == d and dpl == pl
    # x^58 + x^39 + 1: one wire error -> 3 payload errors (self-sync)
    wire = encode(blks)
    wire[66 * 100 + 10] ^= 1
    dec2 = decode(wire)
    nerr = sum(bin(a[2] ^ b[2]).count("1") for a, b in zip(dec, dec2))
    assert nerr == 3, nerr
    # data header is "01" in transmission order
    assert encode([(True, 0)])[:2] == [0, 1]
    assert encode([(False, 0)])[:2] == [1, 0]
    print("CL49_REF_SELFTEST OK")


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a or a[0] == "selftest":
        selftest()
    elif a[0] == "tx":
        cmd_tx(int(a[1]), int(a[2]), a[3], a[4], a[5] if len(a) > 5 else None)
    elif a[0] == "rx":
        cmd_rx(int(a[1]), int(a[2]), int(a[3]), a[4], a[5],
               *(int(x) for x in a[6:8]))
    else:
        sys.exit(__doc__)
