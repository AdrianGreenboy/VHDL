#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A KeyGen mutation tests.
#
# Each mutation injects one defect that the KeyGen testbench must catch. A
# mutation that survives means the test does not actually constrain that
# behaviour. The mutations target the specific failure modes found during
# bring-up, so the test keeps proving those bugs stay fixed.
# =============================================================================
set -u

SRC_FSM="../rtl/kem_keygen.vhd"
SRC_TOP="../rtl/kem_keygen_top.vhd"
[ -f "$SRC_FSM" ] || SRC_FSM="kem_keygen.vhd"
[ -f "$SRC_TOP" ] || SRC_TOP="kem_keygen_top.vhd"

RTL="keccak_pkg.vhd keccak_f1600.vhd keccak_sponge.vhd ntt_tables_pkg.vhd \
ntt_unit.vhd sampler_ntt_k.vhd sampler_misc.vhd basemul_k.vhd poly_mem.vhd \
byte_mem.vhd"
for f in $RTL; do
  [ -f "$f" ] || RTL=$(echo "$RTL" | sed "s|$f|../rtl/$f|")
done

echo "Layer 3A KeyGen mutations (each must be killed):"

run_mutation () {
  NAME="$1"; FILE="$2"; PYEXPR="$3"
  WORK=$(mktemp -d)
  cp $RTL "$SRC_FSM" "$SRC_TOP" tb_keygen.vhd l3a_vectors.txt "$WORK/" 2>/dev/null
  ( cd "$WORK"
    python3 - "$(basename "$FILE")" "$PYEXPR" << 'PYEOF'
import sys
path, expr = sys.argv[1], sys.argv[2]
s = open(path).read()
old, new = expr.split("|||")
if old not in s:
    sys.stderr.write("MUTATION DID NOT APPLY\n")
    sys.exit(2)
open(path, "w").write(s.replace(old, new, 1))
PYEOF
    if [ $? -ne 0 ]; then echo "  ERROR: $NAME did not apply"; exit 3; fi
    rm -rf work-obj08.cf
    ghdl -a --std=08 keccak_pkg.vhd keccak_f1600.vhd keccak_sponge.vhd \
      ntt_tables_pkg.vhd ntt_unit.vhd sampler_ntt_k.vhd sampler_misc.vhd \
      basemul_k.vhd poly_mem.vhd byte_mem.vhd kem_keygen.vhd \
      kem_keygen_top.vhd tb_keygen.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_keygen > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 tb_keygen --stop-time=4000ms 2>&1)
    if echo "$OUT" | grep -q "KEYGEN PASS"; then
      echo "  SURVIVED: $NAME"
      exit 1
    else
      echo "  killed: $NAME"
      exit 0
    fi
  )
  RC=$?
  rm -rf "$WORK"
  return $RC
}

FAIL=0

# M1: lift s_hat in place instead of into the scratch slot. This produces a
# correct ek and a silently wrong dk, which is the exact trap documented in
# DOMAIN_RULES.md.
run_mutation "M1 lift written back over s_hat" "$SRC_FSM" \
'            slot_wr   <= C_SLOT_Y + ii;      -- y slots reused as lifted s_hat|||            slot_wr   <= C_SLOT_S + ii;' || FAIL=1

# M2: use the unlifted s_hat as the basemul operand, dropping the R^2 lift.
run_mutation "M2 basemul without the R2 lift" "$SRC_FSM" \
'              slot_rd2 <= C_SLOT_Y + jj;   -- lifted s_hat|||              slot_rd2 <= C_SLOT_S + jj;' || FAIL=1

# M3: swap the matrix seed byte order, so A[i][j] is built from (i,j) rather
# than (j,i). This transposes the matrix.
run_mutation "M3 matrix seed bytes transposed" "$SRC_FSM" \
'              sp_din <= std_logic_vector(to_unsigned(jj, 8));|||              sp_din <= std_logic_vector(to_unsigned(ii, 8));' || FAIL=1

# M4: remove a settle state from the sigma absorb loop, reintroducing the
# one-cycle-early sample of the synchronous byte memory.
run_mutation "M4 sigma absorb settle bypass" "$SRC_FSM" \
'              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SIG, 13));
              fsm     <= S_SE_WAIT;|||              by_addr <= std_logic_vector(to_unsigned(G_ADDR_SIG, 13));
              fsm     <= S_SE_ABS;' || FAIL=1

# M5: collapse an init pulse back into a single conditional state, which is
# the root-cause bug: the assert and the clear merge and the pulse never
# reaches the sponge.
run_mutation "M5 collapsed sponge init pulse" "$SRC_FSM" \
'          when S_SE_INIT =>
            -- Unconditional single-cycle pulse. Asserting and clearing in one
            -- state would collapse to the clear, and the sponge would never
            -- see the init.
            sp_init <= '"'"'1'"'"';
            fsm     <= S_SE_INIT_P;|||          when S_SE_INIT =>
            sp_init <= '"'"'1'"'"';
            if sp_ready = '"'"'1'"'"' then
              sp_init <= '"'"'0'"'"';
            end if;
            fsm     <= S_SE_INIT_P;' || FAIL=1

# M6: drop the settle cycle in the rho-to-ek byte copy, the bug that survived
# all the way to byte 1152 of ek.
run_mutation "M6 rho copy settle bypass" "$SRC_FSM" \
'            by_addr <= std_logic_vector(to_unsigned(G_ADDR_RHO + cnt, 13));
            fsm     <= S_EK_RHOS;|||            by_addr <= std_logic_vector(to_unsigned(G_ADDR_RHO + cnt, 13));
            fsm     <= S_EK_RHOW;' || FAIL=1

# M7: let the sequencer keep driving the squeeze port while a sampler runs,
# restoring the multiple-driver condition on sp_re.
run_mutation "M7 sampler squeeze mux bypassed" "$SRC_TOP" \
'  sp_re <= s1_re when (samp_run = '"'"'1'"'"' and samp_sel = '"'"'0'"'"') else
           s2_re when (samp_run = '"'"'1'"'"' and samp_sel = '"'"'1'"'"') else
           seq_re;|||  sp_re <= s1_re when samp_sel = '"'"'0'"'"' else s2_re;' || FAIL=1

# M8: encode dk from the lifted slot, so ek is right and dk is wrong.
run_mutation "M8 dk encoded from lifted s_hat" "$SRC_FSM" \
'            slot_rd   <= C_SLOT_S + ii;
            cd_decode <= '"'"'0'"'"';
            cd_base   <= std_logic_vector(
                           to_unsigned(G_ADDR_DK + 384 * ii, 13));|||            slot_rd   <= C_SLOT_Y + ii;
            cd_decode <= '"'"'0'"'"';
            cd_base   <= std_logic_vector(
                           to_unsigned(G_ADDR_DK + 384 * ii, 13));' || FAIL=1

# M9: skip adding the error polynomial, so t_hat is just the matrix product.
run_mutation "M9 error polynomial not added" "$SRC_FSM" \
'            fsm_wdata <= std_logic_vector(
                           range_reduce(acc_val + signed(fsm_rdata)));|||            fsm_wdata <= std_logic_vector(range_reduce(acc_val));' || FAIL=1

# M10: use the wrong PRF nonce for the error polynomials, so e reuses the s
# nonces.
run_mutation "M10 error polynomial nonce reused" "$SRC_FSM" \
'            if sp_ready = '"'"'1'"'"' then
              sp_din <= std_logic_vector(to_unsigned(nonce, 8));|||            if sp_ready = '"'"'1'"'"' then
              sp_din <= std_logic_vector(to_unsigned(nonce mod G_K, 8));' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"
  exit 1
fi
