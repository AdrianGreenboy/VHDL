#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3B ML-DSA Verify mutation tests.
# Each mutation must be killed by tb_dsa_verify.
# =============================================================================
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 3B ML-DSA Verify mutations (each must be killed):"

run_mutation () {
  NAME="$1"; STAGE="$2"; FILE="$3"; PYEXPR="$4"
  WORK=$(mktemp -d)
  for f in keccak_pkg keccak_f1600 keccak_sponge ntt_d_tables_pkg pqc_round_d_pkg poly_mem_d byte_mem_d ntt_d_unit sampler_d codec_d dsa_verify dsa_verify_top; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_dsa_verify.vhd dsa_ver_vectors.txt "$WORK/" 2>/dev/null
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
    ghdl -a --std=08 keccak_pkg.vhd keccak_f1600.vhd keccak_sponge.vhd \
      ntt_d_tables_pkg.vhd pqc_round_d_pkg.vhd poly_mem_d.vhd \
      byte_mem_d.vhd ntt_d_unit.vhd sampler_d.vhd codec_d.vhd \
      dsa_verify.vhd dsa_verify_top.vhd tb_dsa_verify.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_dsa_verify > /dev/null 2>&1
    if [ "$STAGE" = "full" ]; then
      OUT=$(ghdl -r --std=08 tb_dsa_verify -gG_STAGE=0 --stop-time=400000ms 2>&1)
      PAT="DSAVER PASS"
    else
      OUT=$(ghdl -r --std=08 tb_dsa_verify -gG_STAGE=$STAGE --stop-time=8000ms 2>&1)
      PAT="CHECKPOINT PASS stage=$STAGE"
    fi
    if echo "$OUT" | grep -q "$PAT"; then
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

FAIL=0

# M1: hint decode acceptance ignored. Validated: differs on 5 ACVP cases.
run_mutation "M1 hint decode result ignored" full dsa_verify.vhd \
'              if cod_valid = '"'"'0'"'"' then
                reason_r <= "010";
                fsm      <= S_REJECT;|||              if false then
                reason_r <= "010";
                fsm      <= S_REJECT;' || FAIL=1

# M2: the z bound check removed. Observable ONLY on the constructed case.
run_mutation "M2 z bound check removed" full dsa_verify.vhd \
'            if absv(cv) >= to_signed(C_GAMMA1_DD - 196, C_CW) then
              reason_r <= "011";|||            if false then
              reason_r <= "011";' || FAIL=1

# M3: z bound off by one. The constructed case sits exactly on the bound,
# which is the only value at which >= and > differ.
run_mutation "M3 z bound off by one" full dsa_verify.vhd \
'            if absv(cv) >= to_signed(C_GAMMA1_DD - 196, C_CW) then|||            if absv(cv) > to_signed(C_GAMMA1_DD - 196, C_CW) then' || FAIL=1

# M4: the length check removed. Observable only on the short signature.
run_mutation "M4 length check removed" full dsa_verify.vhd \
'            if unsigned(siglen) /= to_unsigned(G_SIGLEN, 16) then|||            if false then' || FAIL=1

# M5: t1 scaled by 2^(D-1). Validated: differs on 4 ACVP cases.
run_mutation "M5 t1 scaled by wrong power" 2 dsa_verify.vhd \
'                         shift_left(signed(p_rdata), C_D_SHIFT));|||                         shift_left(signed(p_rdata), C_D_SHIFT - 1));' || FAIL=1

# M6: the c_hat term added instead of subtracted. Differs on 4 ACVP cases.
run_mutation "M6 c_hat term added not subtracted" 2 dsa_verify.vhd \
'            p_wdata <= std_logic_vector(signed(p_rdata) - signed(p_brdata));
            p_we    <= '"'"'1'"'"';
            fsm     <= S_CT_SUB_NEXT;|||            p_wdata <= std_logic_vector(signed(p_rdata) + signed(p_brdata));
            p_we    <= '"'"'1'"'"';
            fsm     <= S_CT_SUB_NEXT;' || FAIL=1

# M7: the hint ignored in UseHint. Differs on 4 ACVP cases.
run_mutation "M7 hint ignored in UseHint" 3 dsa_verify.vhd \
'            if signed(p_brdata) /= 0 then|||            if false then' || FAIL=1

# M8: the z_hat lift dropped. This was the real bring-up defect: two distinct
# products need one lifted operand each, c_hat carries it for the second and
# z_hat for the first, and omitting the latter is invisible at VP1.
run_mutation "M8 z_hat lift dropped" 2 dsa_verify.vhd \
'            p       := resize(signed(p_rdata) * to_signed(C_RD2, 24), 64);
            slot_a  <= SL_Z + jj;|||            p       := resize(signed(p_rdata) * to_signed(1, 24), 64);
            slot_a  <= SL_Z + jj;' || FAIL=1

# M9: the reason code for a c_tilde mismatch reported as a hint failure.
# The verdict is unchanged, so only the reason code in the signature kills
# this: without it every rejection branch is interchangeable.
run_mutation "M9 mismatch reported as hint failure" full dsa_verify.vhd \
'            if ctb /= unsigned(by_dout) then
              reason_r <= "100";|||            if ctb /= unsigned(by_dout) then
              reason_r <= "010";' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
