#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A Encaps mutation tests.
# Each mutation must be killed by tb_codec_d.
# =============================================================================
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 3B ML-DSA codec mutations (each must be killed):"

run_mutation () {
  NAME="$1"; FILE="$2"; PYEXPR="$3"
  WORK=$(mktemp -d)
  for f in ntt_d_tables_pkg pqc_round_d_pkg codec_d; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_codec_d.vhd dsa_round_vectors.txt dsa_hint_vectors.txt "$WORK/" 2>/dev/null
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
    ghdl -a --std=08 ntt_d_tables_pkg.vhd pqc_round_d_pkg.vhd \
      codec_d.vhd tb_codec_d.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_codec_d > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 tb_codec_d --stop-time=250ms 2>&1)
    if echo "$OUT" | grep -q "CODECD PASS"; then
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

# M1: the s packing stores x instead of eta - x.
run_mutation "M1 s packing sign not inverted" codec_d.vhd \
'                fld := resize(unsigned(
                         to_signed(C_ETA_DD, C_CW) - xv), 20);|||                fld := resize(unsigned(xv), 20);' || FAIL=1

# M2: t0 packing uses the wrong offset.
run_mutation "M2 t0 packing offset off by one" codec_d.vhd \
'                         to_signed(2 ** (C_D_D - 1), C_CW) - xv), 20);|||                         to_signed(2 ** (C_D_D - 1) - 1, C_CW) - xv), 20);' || FAIL=1

# M3: z packing offset wrong.
run_mutation "M3 z packing offset wrong" codec_d.vhd \
'                         to_signed(C_GAMMA1_DD, C_CW) - xv), 20);|||                         to_signed(C_GAMMA1_DD - 1, C_CW) - xv), 20);' || FAIL=1

# M4: the packer emits before the accumulator holds a whole byte.
run_mutation "M4 packer emits on partial byte" codec_d.vhd \
'          when S_P_EMIT =>
            if nbit >= 8 then|||          when S_P_EMIT =>
            if nbit >= 4 then' || FAIL=1

# M5: the unpacker shifts by the wrong width.
#
# This survived until the z round-trip was actually COMPARED. The testbench
# had been feeding the unpacked values into the signature without asserting
# them, so any unpacker defect passed silently.
run_mutation "M5 unpacker shift width wrong" codec_d.vhd \
'              acc     <= shift_right(acc, 20);
              nbit    <= nbit - fw;|||              acc     <= shift_right(acc, 16);
              nbit    <= nbit - fw;' || FAIL=1

# M6: hint encode writes the count to the wrong slot.
#
# The first version of this mutation wrote idx - first instead of idx, and
# SURVIVED. That was a no-op: `first` is only ever assigned on the DECODE
# path, so on the encode path it stays zero and idx - first == idx. Rewritten
# to corrupt the slot the running total lands in, which is what the decoder
# actually reads back.
run_mutation "M6 hint encode count slot wrong" codec_d.vhd \
'                         to_unsigned(C_OMEGA_D + row, 13));
            b_wdata <= std_logic_vector(to_unsigned(idx, 8));|||                         to_unsigned(C_OMEGA_D + row + 1, 13));
            b_wdata <= std_logic_vector(to_unsigned(idx, 8));' || FAIL=1

# M7: RULE 1 is STRUCTURALLY SHADOWED and cannot be killed. Recorded here
# with the reasoning rather than written as a mutation that quietly survives.
#
# Rule 1 has two halves and each is masked by a different mechanism:
#
#   count > OMEGA: the position array has exactly OMEGA = 55 slots, indices
#     0 to 54. Any count above that forces the walk to read at index 55 and
#     beyond, which is the count region: small values after large positions,
#     so RULE 2 fires first. Verified by instrumenting the decoder with the
#     rule removed, on a vector whose positions are strictly increasing
#     (j*4) precisely so rule 2 could not fire early. It still fired, at
#     idx = 55 where the byte is count[0] = 10 against prev = 216.
#
#   count going backwards: the position loop guard is idx >= yi, so a
#     backwards count makes the row a silent no-op rather than an error.
#     Nothing is read, nothing is written, and the decode continues.
#
# This is the same category as the ML-DSA ct0 rejection branch: a defensive
# check that no input can exercise, because another mechanism reaches the
# same outcome first. The check stays in the RTL because it states the
# invariant directly and costs nothing, but claiming the test suite
# constrains it would be false.
#
# What IS constrained: rule 2 and rule 3, both killed below, and the two
# constructed rule-1 vectors remain in the vector file because they exercise
# the decoder along paths the well-formed cases do not reach.

# M8: RULE 2 dropped. Positions within a row need not increase.
# Killed only because a malformed vector swaps two positions.
run_mutation "M8 hint decode rule 2 dropped" codec_d.vhd \
'            if idx > first and to_integer(unsigned(b_rdata)) <= prev then
              fsm <= S_FAIL;|||            if false then
              fsm <= S_FAIL;' || FAIL=1

# M9: RULE 3 dropped. The tail beyond the last index is not checked.
# Killed only because a malformed vector plants a nonzero tail byte.
run_mutation "M9 hint decode rule 3 dropped" codec_d.vhd \
'            if unsigned(b_rdata) /= 0 then
              fsm <= S_FAIL;|||            if false then
              fsm <= S_FAIL;' || FAIL=1

# M10: the row walk exits one position early, dropping the last hint of
# every row. Killed by the position checks in the testbench, which verify
# WHICH positions are set rather than only how many.
#
# Two earlier attempts at this slot were no-ops and are recorded because the
# pattern is worth recognising:
#
#   - swapping p_waddr from b_rdata to prev in S_HD_SET. prev is assigned in
#     S_HD_MONO, which runs on the PREVIOUS cycle, so it already holds the
#     current position. Both forms are equivalent.
#   - removing a settle state between S_HD_CHK and S_HD_POS. yi is likewise
#     visible in the following state, so the settle was never needed.
#
# Both came from the same mistake in reading VHDL timing: confusing the cycle
# in which a signal is ASSIGNED with the cycle in which it becomes readable.
# A signal assigned in state X is readable in the state that follows X. The
# genuine deferred-assignment hazard is reading in the SAME delta, which is
# not what either of these did. The redundant settle state has since been
# removed from the RTL.
run_mutation "M10 row walk exits one position early" codec_d.vhd \
'          when S_HD_POS =>
            if idx >= yi then|||          when S_HD_POS =>
            if idx + 1 >= yi then' || FAIL=1

# M11: monotonicity compared strictly, admitting a repeated position.
run_mutation "M11 hint decode allows repeated position" codec_d.vhd \
'            if idx > first and to_integer(unsigned(b_rdata)) <= prev then|||            if idx > first and to_integer(unsigned(b_rdata)) < prev then' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
