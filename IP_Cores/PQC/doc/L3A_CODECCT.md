# Layer 3A: ciphertext compression codec (codec_ct)

Status: PASS.

    PQC L3A CODECCT PASS enc=8 dec=8 sig=2bc73d7b136a2e84

Streams Compress_d then ByteEncode_d, and the inverse, for the two widths the
ML-KEM-768 ciphertext uses: d = 10 for the u vector (320 bytes per polynomial,
c1) and d = 4 for v (128 bytes, c2).

Verified standalone before being wired into Encaps, so that a bit-packing
error cannot present later as "the ciphertext is wrong" after the entire
datapath has run.

## Structure

Both widths pack whole coefficients into bytes without a remainder over a
short group, so the encoder walks one group at a time:

    d = 10   4 coefficients (40 bits) -> 5 bytes    64 groups
    d =  4   2 coefficients  (8 bits) -> 1 byte    128 groups

The compression constants themselves come from pqc_round_pkg and were verified
exhaustively over the full coefficient range at Layer 2. This block is
responsible only for streaming and bit packing.

## Bugs found

1. **Decode d=10 read its own bytes out of order.** The first version handled
   four bytes in the group loop and folded the fifth into a separate branch,
   which overlapped the loop's own reads. Restructured so all five bytes are
   read in a straight line with sub = 0..4, and the coefficient writeback is a
   separate pass. Folding an odd element into a special case is what created
   the overlap; making the loop uniform removed it.

2. **Testbench hex parse was off by one nibble.** After `read(ln, d)` the
   separating space is still in the line. Integer reads skip leading
   whitespace, but character-by-character hex reads do not, so the space was
   consumed as the first nibble and every byte shifted. The encode vectors did
   not show this because their hex field is preceded by an integer list, whose
   read consumed the space. Worth remembering: mixing integer reads and raw
   character reads on one line needs an explicit separator consume.

3. **Testbench memory loads were off by one cycle.** The load address and
   value are signals, so they take effect on the edge after assignment; a
   one-cycle loop wrote each value against the previous address. Fixed by
   setting the pair, letting it settle, then pulsing the enable.

## Note on mutation M6 and vector coverage

M6 removes the canonical lift that maps a negative representative into
0 .. q-1 before compressing. It initially SURVIVED, and that was a real
coverage gap rather than a badly formulated mutation: the first vector set
contained only non-negative coefficients, so the `v < 0` branch was never
executed.

This matters for Encaps specifically. Both u and v arrive from the inverse
NTT as signed representatives, so the lift is on the live path there even
though nothing in the original vectors exercised it. The vectors were
regenerated with signed representatives spanning -(q-1)/2 .. (q-1)/2, giving
1016 negative coefficients across the encode cases, and M6 is now killed.

Mutation M10 was a separate case: as first written it added a latch that the
following state overwrote, so it injected no defect at all. It was rewritten
to remove the settle cycle outright. A surviving mutation is a hypothesis, not
a conclusion; each one has to be inspected to see whether it is a test gap or
a mutation that does nothing.
