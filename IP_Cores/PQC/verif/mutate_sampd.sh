#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A Encaps mutation tests.
# Each mutation must be killed by tb_sampler_d.
# =============================================================================
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 3B ML-DSA sampler mutations (each must be killed):"

run_mutation () {
  NAME="$1"; FILE="$2"; PYEXPR="$3"
  WORK=$(mktemp -d)
  for f in ntt_d_tables_pkg sampler_d; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_sampler_d.vhd dsa_samp_vectors.txt "$WORK/" 2>/dev/null
  ( cd "$WORK"
    python3 - "$FILE" "$PYEXPR" << 'PYEOF'
import sys
path, expr = sys.argv[1], sys.argv[2]
old, new = expr.split("|||")
s = open(path).read()
if old not in s:
    sys.stderr.write("MUTATION DID NOT APPLY\n")
    sys.exit(2)
open(path, "w").write(s.replace(old, new, 1))
PYEOF
    if [ $? -ne 0 ]; then echo "  ERROR: $NAME did not apply"; exit 3; fi
    rm -rf work-obj08.cf
    ghdl -a --std=08 ntt_d_tables_pkg.vhd sampler_d.vhd \
      tb_sampler_d.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_sampler_d > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 tb_sampler_d --stop-time=100ms 2>&1)
    if echo "$OUT" | grep -q "SAMPD PASS"; then
      echo "  SURVIVED: $NAME"; exit 1
    else
      echo "  killed: $NAME"; exit 0
    fi
  )
  RC=$?
  rm -rf "$WORK"
  return $RC
}


FAIL=0

# M1: RejNTTPoly must clear the TOP bit of the third byte, giving 23 bits.
# Keeping all 8 admits candidates above q that the comparison then rejects,
# shifting the whole stream.
run_mutation "M1 RejNTTPoly keeps the top bit" sampler_d.vhd \
'            z := b2(6 downto 0) & b1 & b0;|||            z := b2(7 downto 1) & b1 & b0;' || FAIL=1

# M2: accept boundary off by one, admitting z = q.
#
# This survived until a boundary case was constructed. z == q arises with
# probability 2^-23, so across the ~2048 candidates the SHAKE-derived vectors
# draw, it is expected 0.0002 times: the branch was live but unvisited,
# exactly like the Decaps early exit. The final SNTT vector is a synthetic
# stream whose first candidate is exactly q.
run_mutation "M2 RejNTTPoly accepts z equal to q" sampler_d.vhd \
'            if z < to_unsigned(C_QD, 23) then|||            if z <= to_unsigned(C_QD, 23) then' || FAIL=1

# M3: byte order of the three-byte candidate reversed.
run_mutation "M3 RejNTTPoly byte order reversed" sampler_d.vhd \
'            z := b2(6 downto 0) & b1 & b0;|||            z := b0(6 downto 0) & b1 & b2;' || FAIL=1

# M4: RejBoundedPoly nibble order swapped, high before low.
run_mutation "M4 RejBoundedPoly nibble order swapped" sampler_d.vhd \
'          when S_B_LO =>
            h := b0(3 downto 0);|||          when S_B_LO =>
            h := b0(7 downto 4);' || FAIL=1

# M5: RejBoundedPoly acceptance bound wrong.
run_mutation "M5 RejBoundedPoly bound off by one" sampler_d.vhd \
'          when S_B_LO =>
            h := b0(3 downto 0);
            if h < 9 then|||          when S_B_LO =>
            h := b0(3 downto 0);
            if h < 10 then' || FAIL=1

# M6: the ETA subtraction inverted.
run_mutation "M6 RejBoundedPoly maps nibble additively" sampler_d.vhd \
'              p_wdata <= std_logic_vector(
                           to_signed(C_ETA_D, C_CW) -
                           resize(signed('"'"'0'"'"' & h), C_CW));
              p_we    <= '"'"'1'"'"';
              if nacc = 255 then
                fsm <= S_DONE;
              else
                nacc <= nacc + 1;
                fsm  <= S_B_HI;|||              p_wdata <= std_logic_vector(
                           to_signed(C_ETA_D, C_CW) +
                           resize(signed('"'"'0'"'"' & h), C_CW));
              p_we    <= '"'"'1'"'"';
              if nacc = 255 then
                fsm <= S_DONE;
              else
                nacc <= nacc + 1;
                fsm  <= S_B_HI;' || FAIL=1

# M7: ExpandMask field mask wrong.
#
# The first version of this mutation moved the emit threshold from 20 to 19
# and SURVIVED. That was a no-op rather than a test gap: bytes arrive 8 bits
# at a time and the accumulator drops by 20 per emit, so nbit only ever takes
# the values 8, 12, 16, 20, 24 and is never exactly 19. The two thresholds are
# indistinguishable given the arrival pattern. Rewritten to corrupt the field
# MASK, which is what actually selects the coefficient bits.
run_mutation "M7 ExpandMask field mask wrong" sampler_d.vhd \
'acc(19 downto 0)|||acc(18 downto 0)' || FAIL=1

# M8: ExpandMask forgets to shift the accumulator down after emitting.
run_mutation "M8 ExpandMask accumulator not shifted" sampler_d.vhd \
'            acc     <= shift_right(acc, 20);
            nbit    <= nbit - 20;|||            nbit    <= nbit - 20;' || FAIL=1

# M9: SampleInBall sign bits read big-endian.
run_mutation "M9 SampleInBall sign bits big-endian" sampler_d.vhd \
'              sgn   <= sgn or shift_left(
                         resize(unsigned(sp_dout), 64), 8 * cnt);|||              sgn   <= sgn or shift_left(
                         resize(unsigned(sp_dout), 64), 8 * (7 - cnt));' || FAIL=1

# M10: SampleInBall rejection bound wrong, admitting j > i.
run_mutation "M10 SampleInBall index bound wrong" sampler_d.vhd \
'            if to_integer(b0) <= ii then|||            if to_integer(b0) < ii then' || FAIL=1

# M11: SampleInBall skips the copy of c[j] into c[i].
run_mutation "M11 SampleInBall omits the swap copy" sampler_d.vhd \
'          when S_C_WI =>
            p_waddr <= std_logic_vector(to_unsigned(ii, 8));
            p_wdata <= std_logic_vector(cj);
            p_we    <= '"'"'1'"'"';|||          when S_C_WI =>
            p_waddr <= std_logic_vector(to_unsigned(ii, 8));
            p_wdata <= (others => '"'"'0'"'"');
            p_we    <= '"'"'1'"'"';' || FAIL=1

# M12: read settle bypassed before the polynomial read-back.
run_mutation "M12 SampleInBall read settle bypassed" sampler_d.vhd \
'          when S_C_RD =>
            fsm <= S_C_RDW;|||          when S_C_RD =>
            fsm <= S_C_WI;' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
