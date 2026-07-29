#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3B ML-DSA Sign mutation tests.
# Each mutation must be killed by tb_dsa_sign.
# =============================================================================
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 3B ML-DSA Sign sequencer mutations (each must be killed):"

run_mutation () {
  NAME="$1"; STAGE="$2"; FILE="$3"; PYEXPR="$4"
  WORK=$(mktemp -d)
  for f in keccak_pkg keccak_f1600 keccak_sponge ntt_d_tables_pkg pqc_round_d_pkg poly_mem_d byte_mem_d ntt_d_unit sampler_d codec_d dsa_sign dsa_sign_top; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_dsa_sign.vhd dsa_sign_vectors.txt "$WORK/" 2>/dev/null
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
      dsa_sign.vhd dsa_sign_top.vhd tb_dsa_sign.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_dsa_sign > /dev/null 2>&1
    if [ "$STAGE" = "full" ]; then
      OUT=$(ghdl -r --std=08 tb_dsa_sign -gG_STAGE=0 --stop-time=400000ms 2>&1)
      PAT="DSASIGN PASS"
    else
      OUT=$(ghdl -r --std=08 tb_dsa_sign -gG_STAGE=$STAGE --stop-time=8000ms 2>&1)
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

# Every mutation below was validated against the Python model BEFORE being
# written here, or reproduces a defect that actually occurred during bring-up.
# Four earlier blocks lost time to mutations that injected nothing; the model
# check costs seconds and settles the question.

# M1: kappa advances by L-1. Validated against the model: changes the output.
run_mutation "M1 kappa step L-1 instead of L" full dsa_sign.vhd \
'            kappa  <= kappa + G_L;
            iter   <= iter + 1;|||            kappa  <= kappa + G_L - 1;
            iter   <= iter + 1;' || FAIL=1

# M2: kappa not advanced on the accepting iteration. This was a real defect:
# the model consumes the base then adds L on every iteration, so reporting
# (n-1)*L instead of n*L fails the frozen vectors. Killed by kappa being in
# the signature, which is the whole reason it is there.
run_mutation "M2 kappa not advanced on accept" full dsa_sign.vhd \
'              kappa <= kappa + G_L;
              cnt   <= 0;
              fsm   <= S_SG_CT;|||              cnt   <= 0;
              fsm   <= S_SG_CT;' || FAIL=1

# M3: c_tilde absorbs w1 before mu. Validated against the model.
run_mutation "M3 c_tilde absorbs w1 before mu" 3 dsa_sign.vhd \
'              by_addr <= std_logic_vector(to_unsigned(G_ADDR_MU, 14));
              fsm     <= S_C_MWAIT;|||              by_addr <= std_logic_vector(to_unsigned(G_ADDR_W1, 14));
              fsm     <= S_C_MWAIT;' || FAIL=1

# M4: the r0 rejection removed. Validated against the model on vector 0.
run_mutation "M4 r0 rejection removed" full dsa_sign.vhd \
'            if absv(cv) >= to_signed(C_GAMMA2_DD - 196, C_CW) then
              fsm <= S_REJECT;|||            if false then
              fsm <= S_REJECT;' || FAIL=1

# M5: y transformed in place, destroying the plain copy that z needs. This
# was the real SP4 failure: invisible to SP1 (stops before the NTT) and to
# SP2 and SP3 (which consume only the transformed domain).
run_mutation "M5 y transformed in place" 4 dsa_sign.vhd \
'          when S_YC_WR =>
            slot_a  <= SL_YH + jj;|||          when S_YC_WR =>
            slot_a  <= SL_Y + jj;' || FAIL=1

# M6: the lift dropped from the c_hat copy. Exactly one operand of every
# pointwise product must carry R^2; s1_hat, s2_hat and t0_hat come from
# ByteDecode in the plain domain, so c_hat is the operand that carries it.
run_mutation "M6 lift dropped from c_hat copy" 4 dsa_sign.vhd \
'            p       := resize(signed(p_rdata) * to_signed(C_RD2, 24), 64);
            slot_a  <= SL_TMP;|||            p       := resize(signed(p_rdata) * to_signed(1, 24), 64);
            slot_a  <= SL_TMP;' || FAIL=1

# M7: the settle state removed from the signature c_tilde copy. The byte
# memory registers its output, so reading a cycle early copies the previous
# address. Another defect that actually occurred.
run_mutation "M7 byte memory settle removed" full dsa_sign.vhd \
'            fsm     <= S_SG_CTS;|||            fsm     <= S_SG_CTW;' || FAIL=1

# M8: the inverse transform issued only in the state that observes the
# product done, with NO re-issue afterward. ntt_done is still asserted when
# the wait state is entered, so the wait falls through and the transform never
# runs. This is the defect that actually occurred on all three
# product-then-INTT paths.
#
# The first attempt at this mutation LEFT the re-issue in S_Z_INTT in place,
# which swallowed the early start and made the whole thing a no-op: the NTT
# ran anyway from the later pulse. That is the same failure mode as the no-op
# mutations in earlier blocks, caught here because the mutation was run rather
# than trusted. This version removes the re-issue so only the broken early
# start remains.
run_mutation "M8 INTT start not separated from wait" 4 dsa_sign.vhd \
'          when S_Z_MULW =>
            -- Observe done here and START THE INVERSE IN THE NEXT STATE.|||          when S_Z_MULW =>
            -- MUTANT: issue start here and drop the re-issue below.
            if ntt_done = '"'"'1'"'"' then
              slot_a    <= SL_TMP;
              ntt_op    <= "01";
              ntt_start <= '"'"'1'"'"';
              fsm       <= S_Z_INTTW;
            end if;
          when S_Z_MULW_DEAD =>
            -- Observe done here and START THE INVERSE IN THE NEXT STATE.' || FAIL=1

# M9: A indexed row-first instead of column-first. A[r][s] uses seed bytes
# (s, r), and transposing changes which polynomial each product sees.
run_mutation "M9 A seed bytes transposed" 2 dsa_sign.vhd \
'              sp_din <= std_logic_vector(to_unsigned(jj, 8));
              sp_we  <= '"'"'1'"'"';
              fsm    <= S_W_AIDX2;|||              sp_din <= std_logic_vector(to_unsigned(ii, 8));
              sp_we  <= '"'"'1'"'"';
              fsm    <= S_W_AIDX2;' || FAIL=1

# M10: hint weight compared inclusively, admitting one hint above OMEGA.
run_mutation "M10 hint weight bound inclusive" full dsa_sign.vhd \
'            if hw_cnt > C_OMEGA_D then|||            if hw_cnt > C_OMEGA_D + 1 then' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
