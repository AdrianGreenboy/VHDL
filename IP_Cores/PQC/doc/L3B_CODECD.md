# Layer 3B: ML-DSA bit packing and hint codec

Status: PASS.

    PQC L3B CODECD PASS pack=20 henc=8 hint=8 bad=6 hsum=230 sig=e8927092f025f0c3

Twenty packing cases compared byte for byte, eight hint encodes, eight hint
decodes with the decoded positions verified individually, and six malformed
inputs that must be rejected. Ten mutations killed; one documented as
unreachable with the reasoning below.

## Three gaps, all in the testbench

Every surviving mutation in this block turned out to be a verification
defect rather than an RTL defect. Worth listing because the pattern repeated.

1. **The z round-trip was never compared.** The unpacked values were fed into
   the signature but never asserted, so any unpacker defect passed silently.
   M5 survived on that alone.

2. **The hint encoder was never exercised.** The vector file had eight HEN
   lines from the start; the testbench read only the HDE ones and never ran
   mode "110". M6 survived because the encoder was not under test at all.

3. **Only the acceptance flag was checked, never the decoded polynomial.** A
   decoder that accepted a well-formed input while writing nothing would have
   passed. This was exposed by a signature that did not move when an RTL
   change was made, which is a useful signal in itself: if a change to the
   design does not move the signature, the testbench may not be observing
   the thing that changed.

The decode check now verifies WHICH positions are set, using the position
lists already in the vector file, rather than summing coefficients. That is
both faster than sweeping all 1536 and strictly stronger.

## Rule 1 is structurally unreachable

The hint decoder enforces three rules. Rule 1, that the running total is
non-decreasing and never exceeds OMEGA, cannot be exercised: each half is
masked by a different mechanism.

**count > OMEGA.** The position array has exactly OMEGA = 55 slots, indices
0 to 54. Any count above that forces the walk to read at index 55 and beyond,
which is the count region: small values following large positions, so rule 2
fires first. This was verified rather than argued. A vector was constructed
with strictly increasing positions (j*4) precisely so that rule 2 could not
fire early, the rule was removed, and the decoder was instrumented. Rule 2
still fired, at idx = 55 where the byte is count[0] = 10 against prev = 216.

**count going backwards.** The position loop guard is idx >= yi, so a
backwards count makes the row a silent no-op. Nothing is read, nothing is
written, and decoding continues to the next row.

This is the same category as the ML-DSA ct0 rejection branch: a defensive
check that no input can reach because another mechanism gets there first. The
check stays in the RTL because it states the invariant directly and costs
nothing, but claiming the test suite constrains it would be false.

Rule 2 needed two vectors, not one. A swapped pair produces a strict
decrease, which a < comparison also catches; only a REPEATED position
distinguishes <= from <. That vector is what kills the off-by-one mutation.

## A misreading of VHDL timing, corrected

Two changes were made to this file on the strength of a wrong argument, and
both have been reverted. The reasoning is recorded because the mistake is
easy to repeat.

The claim was that a signal assigned in one state is not yet visible in the
state that follows, so p_waddr had to read b_rdata rather than prev, and a
settle state was needed between S_HD_CHK and S_HD_POS. That is wrong. A
signal assigned in state X IS readable in the state after X. The genuine
deferred-assignment hazard is reading in the SAME delta as the assignment,
which is not what either of those did.

The error was compounded by a bad diagnostic step: a probe was added to
S_HD_ROW, printed nothing, and the absence of output was read as the loop
never running. In fact the probe text had not matched the source, so it was
never inserted. Reconstructing the decoder as it stood before both changes
and running it produces the identical signature, which settles the question:
neither change did anything.

The redundant settle state has been removed. The RTL is now one state
shorter than the version that first passed.

## Field widths

The signed packings store b - x in bitlen(a+b) bits. For s with eta = 4 the
field ranges over [0, 8]: nine values in four bits, exactly filled, with no
headroom. A coefficient outside [-eta, eta] would overflow into the
neighbouring field rather than raising anything. The sampler that produces s
is what guarantees the range, not this codec.
