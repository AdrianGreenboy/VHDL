#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A Encaps mutation tests.
# Each mutation must be killed by tb_decaps.
# =============================================================================
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 3A Decaps mutations (each must be killed):"

run_mutation () {
  NAME="$1"; FILE="$2"; PYEXPR="$3"
  WORK=$(mktemp -d)
  for f in keccak_pkg keccak_f1600 keccak_sponge ntt_tables_pkg pqc_round_pkg \
           pqc_codec_pkg ntt_unit sampler_ntt_k sampler_misc basemul_k \
           poly_mem byte_mem codec_ct kem_decaps kem_decaps_top; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_decaps.vhd l3a_vectors.txt "$WORK/" 2>/dev/null
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
      ntt_tables_pkg.vhd pqc_round_pkg.vhd pqc_codec_pkg.vhd ntt_unit.vhd \
      sampler_ntt_k.vhd sampler_misc.vhd basemul_k.vhd poly_mem.vhd \
      byte_mem.vhd codec_ct.vhd kem_decaps.vhd kem_decaps_top.vhd \
      tb_decaps.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_decaps > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 tb_decaps --stop-time=30000ms 2>&1)
    if echo "$OUT" | grep -q "DECAPS PASS"; then
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

# M1: early exit in the constant-time comparison. Detected by the timing
# spread assertion, which only works because the vector set includes
# rejection cases that differ at byte 0 as well as at the last byte.
run_mutation "M1 comparison early exit" kem_decaps.vhd \
'            diff_acc <= diff_acc or (tmp_b xor unsigned(by_dout));
            if cnt = 320 * G_K + 128 - 1 then|||            diff_acc <= diff_acc or (tmp_b xor unsigned(by_dout));
            if (tmp_b /= unsigned(by_dout)) or cnt = 320 * G_K + 128 - 1 then' || FAIL=1

# M2: invert the selection, returning the implicit secret on success.
run_mutation "M2 selection mask inverted" kem_decaps.vhd \
'            if diff_acc = 0 then
              keep_msk <= (others => '"'"'1'"'"');|||            if diff_acc /= 0 then
              keep_msk <= (others => '"'"'1'"'"');' || FAIL=1

# M3: accumulate with AND, so only an all-differing ciphertext registers.
run_mutation "M3 difference accumulated with and" kem_decaps.vhd \
'            diff_acc <= diff_acc or (tmp_b xor unsigned(by_dout));|||            diff_acc <= diff_acc and (tmp_b xor unsigned(by_dout));' || FAIL=1

# M4: compare only c1, leaving c2 unchecked.
run_mutation "M4 comparison covers only c1" kem_decaps.vhd \
'            if cnt = 320 * G_K + 128 - 1 then
              cnt <= 0;
              fsm <= S_SEL_RD;|||            if cnt = 320 * G_K - 1 then
              cnt <= 0;
              fsm <= S_SEL_RD;' || FAIL=1

# M5: drop the lift, so neither basemul operand carries R^2.
run_mutation "M5 s_hat not lifted for decrypt" kem_decaps.vhd \
'            slot_rd  <= C_SLOT_YH + jj;    -- lifted s_hat|||            slot_rd  <= C_SLOT_S + jj;' || FAIL=1

# M6: w = v + INTT(acc) instead of minus.
run_mutation "M6 decrypt uses addition" kem_decaps.vhd \
'                           range_reduce(acc_val - signed(fsm_rdata)));|||                           range_reduce(acc_val + signed(fsm_rdata)));' || FAIL=1

# M7: Kbar absorbs c before z, reversing the J input order.
run_mutation "M7 Kbar absorbs c before z" kem_decaps.vhd \
'              by_addr <= std_logic_vector(
                           to_unsigned(G_ADDR_DK + 768 * G_K + 64, 13));
              fsm     <= S_KB_ZWAIT;|||              by_addr <= std_logic_vector(to_unsigned(G_ADDR_C, 13));
              fsm     <= S_KB_ZWAIT;' || FAIL=1

# M8: forward transform where the decrypt needs the inverse.
run_mutation "M8 decrypt uses forward NTT" kem_decaps.vhd \
'          when S_AINTT =>
            grant     <= C_CLI_NTT;
            slot_rd   <= C_SLOT_TMP;
            slot_wr   <= C_SLOT_TMP;
            ntt_inv   <= '"'"'1'"'"';|||          when S_AINTT =>
            grant     <= C_CLI_NTT;
            slot_rd   <= C_SLOT_TMP;
            slot_wr   <= C_SLOT_TMP;
            ntt_inv   <= '"'"'0'"'"';' || FAIL=1

# M9: wrong compression width when recovering the message.
run_mutation "M9 m2 compressed at the wrong width" kem_decaps.vhd \
'            cct_dsel   <= "10";              -- d = 1|||            cct_dsel   <= "01";' || FAIL=1

# M10: collapsed init pulse, the KeyGen root-cause bug.
run_mutation "M10 collapsed sponge init pulse" kem_decaps.vhd \
'          when S_KB_INIT =>
            sp_init <= '"'"'1'"'"';
            fsm     <= S_KB_INIT_P;|||          when S_KB_INIT =>
            sp_init <= '"'"'1'"'"';
            if sp_ready = '"'"'1'"'"' then
              sp_init <= '"'"'0'"'"';
            end if;
            fsm     <= S_KB_INIT_P;' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
