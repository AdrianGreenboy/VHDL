#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A Encaps mutation tests.
# Each mutation must be killed by tb_encaps.
# =============================================================================
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 3A Encaps mutations (each must be killed):"

run_mutation () {
  NAME="$1"; FILE="$2"; PYEXPR="$3"
  WORK=$(mktemp -d)
  for f in keccak_pkg keccak_f1600 keccak_sponge ntt_tables_pkg pqc_round_pkg \
           pqc_codec_pkg ntt_unit sampler_ntt_k sampler_misc basemul_k \
           poly_mem byte_mem codec_ct kem_encaps kem_encaps_top; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_encaps.vhd l3a_vectors.txt "$WORK/" 2>/dev/null
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
      byte_mem.vhd codec_ct.vhd kem_encaps.vhd kem_encaps_top.vhd \
      tb_encaps.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_encaps > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 tb_encaps --stop-time=6000ms 2>&1)
    if echo "$OUT" | grep -q "ENCAPS PASS"; then
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

# M1: the headline trap. Lifting t_hat as well as y_hat leaves u correct and
# corrupts only v, so only the last 128 ciphertext bytes differ.
run_mutation "M1 t_hat lifted as well as y_hat" kem_encaps.vhd \
'            slot_rd  <= C_SLOT_T + jj;      -- plain domain, no lift|||            slot_rd  <= C_SLOT_YH + jj;' || FAIL=1

# M2: drop the lift entirely, so neither operand carries R^2.
run_mutation "M2 y_hat not lifted for u" kem_encaps.vhd \
'                slot_rd2 <= C_SLOT_YH + jj;   -- lifted y_hat|||                slot_rd2 <= C_SLOT_Y + jj;' || FAIL=1

# M3: use the unlifted y_hat in the v product only.
run_mutation "M3 y_hat not lifted for v" kem_encaps.vhd \
'            slot_rd2 <= C_SLOT_YH + jj;     -- lifted|||            slot_rd2 <= C_SLOT_Y + jj;' || FAIL=1

# M4: untranspose the matrix seed bytes, giving KeyGen order instead.
run_mutation "M4 matrix seed not transposed" kem_encaps.vhd \
'              sp_din <= std_logic_vector(to_unsigned(ii, 8));
              sp_we  <= '"'"'1'"'"';
              fsm    <= S_U_AIDX2;|||              sp_din <= std_logic_vector(to_unsigned(jj, 8));
              sp_we  <= '"'"'1'"'"';
              fsm    <= S_U_AIDX2;' || FAIL=1

# M5: skip the message contribution, so v carries only the noisy product.
run_mutation "M5 message not added into v" kem_encaps.vhd \
'                           range_reduce(acc_val + signed(fsm_rdata) +
                             to_signed(decompress_k(1, bitv), 16)));|||                           range_reduce(acc_val + signed(fsm_rdata)));' || FAIL=1

# M6: wrong nonce base for e1, reusing the y nonces.
run_mutation "M6 e1 nonce base wrong" kem_encaps.vhd \
'                slot_wr <= C_SLOT_E1 + (nonce - G_K);|||                slot_wr <= C_SLOT_E1 + (nonce - G_K - 1);' || FAIL=1

# M7: forward transform instead of inverse when forming u.
run_mutation "M7 u uses forward NTT" kem_encaps.vhd \
'            slot_rd   <= C_SLOT_TMP;
            slot_wr   <= C_SLOT_TMP;
            ntt_inv   <= '"'"'1'"'"';
            ntt_start <= '"'"'1'"'"';
            fsm       <= S_U_INTTW;|||            slot_rd   <= C_SLOT_TMP;
            slot_wr   <= C_SLOT_TMP;
            ntt_inv   <= '"'"'0'"'"';
            ntt_start <= '"'"'1'"'"';
            fsm       <= S_U_INTTW;' || FAIL=1

# M8: swap the compression widths of the two ciphertext halves.
run_mutation "M8 ciphertext widths swapped" kem_encaps.vhd \
'            cct_dsel   <= '"'"'0'"'"';               -- d = 10|||            cct_dsel   <= '"'"'1'"'"';' || FAIL=1

# M9: absorb H(ek) before m, reversing the G input order.
run_mutation "M9 G absorbs H before m" kem_encaps.vhd \
'              by_addr <= std_logic_vector(to_unsigned(G_ADDR_M, 13));
              fsm     <= S_G_MWAIT;|||              by_addr <= std_logic_vector(to_unsigned(G_ADDR_H, 13));
              fsm     <= S_G_MWAIT;' || FAIL=1

# M10: settle bypass in the ek absorb loop feeding H.
run_mutation "M10 ek absorb settle bypass" kem_encaps.vhd \
'              by_addr <= std_logic_vector(to_unsigned(G_ADDR_EK, 13));
              fsm     <= S_H_WAIT;|||              by_addr <= std_logic_vector(to_unsigned(G_ADDR_EK, 13));
              fsm     <= S_H_ABS;' || FAIL=1

# M11: collapse an init pulse, the KeyGen root-cause bug.
run_mutation "M11 collapsed sponge init pulse" kem_encaps.vhd \
'          when S_Y_INIT =>
            sp_init <= '"'"'1'"'"';
            fsm     <= S_Y_INIT_P;|||          when S_Y_INIT =>
            sp_init <= '"'"'1'"'"';
            if sp_ready = '"'"'1'"'"' then
              sp_init <= '"'"'0'"'"';
            end if;
            fsm     <= S_Y_INIT_P;' || FAIL=1

# M12: multiple drivers on the squeeze port.
run_mutation "M12 sampler squeeze mux bypassed" kem_encaps_top.vhd \
'  sp_re <= s1_re when (samp_run = '"'"'1'"'"' and samp_sel = '"'"'0'"'"') else
           s2_re when (samp_run = '"'"'1'"'"' and samp_sel = '"'"'1'"'"') else
           seq_re;|||  sp_re <= s1_re when samp_sel = '"'"'0'"'"' else s2_re;' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
