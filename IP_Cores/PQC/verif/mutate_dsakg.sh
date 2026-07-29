#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3B ML-DSA KeyGen mutation tests.
# Each mutation must be killed by tb_dsa_keygen.
# =============================================================================
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 3B ML-DSA KeyGen mutations (each must be killed):"

run_mutation () {
  NAME="$1"; STAGE="$2"; FILE="$3"; PYEXPR="$4"
  WORK=$(mktemp -d)
  for f in keccak_pkg keccak_f1600 keccak_sponge ntt_d_tables_pkg pqc_round_d_pkg poly_mem_d byte_mem_d ntt_d_unit sampler_d codec_d dsa_keygen dsa_keygen_top; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_dsa_keygen.vhd dsa_kg_vectors.txt "$WORK/" 2>/dev/null
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
      dsa_keygen.vhd dsa_keygen_top.vhd tb_dsa_keygen.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_dsa_keygen > /dev/null 2>&1
    if [ "$STAGE" = "full" ]; then
      OUT=$(ghdl -r --std=08 tb_dsa_keygen -gG_STAGE=0 --stop-time=400000ms 2>&1)
      PAT="DSAKG PASS"
    else
      OUT=$(ghdl -r --std=08 tb_dsa_keygen -gG_STAGE=$STAGE --stop-time=8000ms 2>&1)
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

# M1: the seed split. rho, rhop and key are consecutive slices of one
# 128-byte squeeze, and swapping the first two changes everything downstream.
run_mutation "M1 seed split rho/rhop swapped" 1 dsa_keygen.vhd \
'              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SD + 32, 14));
              fsm     <= S_ES_WAIT;|||              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SD, 14));
              fsm     <= S_ES_WAIT;' || FAIL=1

# M2: the lift dropped from s1_hat. Exactly one operand of A o s1_hat carries
# R^2 and A comes straight from SampleNTT, so it has to be s1.
run_mutation "M2 s1_hat lift dropped" 2 dsa_keygen.vhd \
'            p       := resize(signed(p_rdata) * to_signed(C_RD2, 24), 64);
            slot_a  <= SL_S1H + jj;|||            p       := resize(signed(p_rdata) * to_signed(1, 24), 64);
            slot_a  <= SL_S1H + jj;' || FAIL=1

# M3: s2 subtracted instead of added when forming t.
run_mutation "M3 s2 subtracted not added" 2 dsa_keygen.vhd \
'            slot_a  <= SL_T;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(signed(p_rdata) + signed(p_brdata));|||            slot_a  <= SL_T;
            p_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            p_wdata <= std_logic_vector(signed(p_rdata) - signed(p_brdata));' || FAIL=1

# M4: t1 and t0 swapped out of Power2Round.
run_mutation "M4 t1 and t0 swapped" 3 dsa_keygen.vhd \
'            p_wdata <= std_logic_vector(
                         resize(signed('"'"'0'"'"' & p2r_hi(canon_d(acc_v))), C_CW));|||            p_wdata <= std_logic_vector(p2r_lo(canon_d(acc_v)));' || FAIL=1

# M5: the settle state before the Power2Round capture removed. This was a
# real bring-up defect: the address assigned takes effect the next cycle and
# the memory presents data the cycle after that, so the capture read the
# PREVIOUS coefficient. Sign has the same structure written correctly, and
# comparing against it is what located this.
run_mutation "M5 Power2Round capture one cycle early" 3 dsa_keygen.vhd \
'            fsm     <= S_P2_RDS;|||            fsm     <= S_P2_RDW;' || FAIL=1

# M6: s2 sampled from a restarted index space instead of continuing s1's.
# ExpandS uses ONE counter across both vectors, so s2[r] is drawn with index
# L+r, not r. Validated against the model: pk comes out BIT-IDENTICAL and
# only sk changes, so this is killed by the secret key comparison and by
# nothing else.
#
# The first attempt at this mutation inserted a redundant statement after the
# slot selection and survived, because it changed nothing: the index that
# matters is the one absorbed into the sponge, not the slot the result lands
# in. Fifth no-op mutation in this core, and the reason the harness is run
# rather than trusted.
run_mutation "M6 s2 index space restarted" full dsa_keygen.vhd \
'              sp_din <= std_logic_vector(to_unsigned(ii mod 256, 8));|||              sp_din <= std_logic_vector(
                          to_unsigned((ii mod G_L) mod 256, 8));' || FAIL=1

# M7: cnt not reset before the s1 copy. Another real defect: cnt is left at
# 63 by the ExpandS absorb loop, so the copy starts at coefficient 63 and the
# first quarter of s1_hat is never written. The result matches no transform
# of s1 at all, which is the signature of wrong INPUT rather than a wrong
# operation.
run_mutation "M7 cnt not reset before the copy" 2 dsa_keygen.vhd \
'                cnt <= 0;
                if G_STOP_AT = 1 then|||                if G_STOP_AT = 1 then' || FAIL=1

# M8: s1 transformed in place, destroying the plain copy sk carries. Third
# instance of this defect in the core after Sign's y and the c_hat product.
run_mutation "M8 s1 transformed in place" full dsa_keygen.vhd \
'          when S_SL_RD =>
            slot_a  <= SL_S1H + jj;|||          when S_SL_RD =>
            slot_a  <= SL_S1 + jj;' || FAIL=1

# M9: pk packs t0 rather than t1.
run_mutation "M9 pk packs t0 not t1" 4 dsa_keygen.vhd \
'            slot_a    <= SL_T1 + ii;
            cod_mode  <= "0000";|||            slot_a    <= SL_T0 + ii;
            cod_mode  <= "0000";' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
