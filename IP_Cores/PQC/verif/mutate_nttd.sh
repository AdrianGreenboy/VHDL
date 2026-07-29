#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A Encaps mutation tests.
# Each mutation must be killed by tb_ntt_d.
# =============================================================================
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 3B NTT-D datapath mutations (each must be killed):"

run_mutation () {
  NAME="$1"; FILE="$2"; PYEXPR="$3"
  WORK=$(mktemp -d)
  for f in ntt_d_tables_pkg poly_mem_d ntt_d_unit; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_ntt_d.vhd ntt_d_vectors.txt "$WORK/" 2>/dev/null
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
    ghdl -a --std=08 ntt_d_tables_pkg.vhd poly_mem_d.vhd ntt_d_unit.vhd \
      tb_ntt_d.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_ntt_d > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 tb_ntt_d --stop-time=300ms 2>&1)
    if echo "$OUT" | grep -q "NTTD PASS"; then
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

# M1: the sign of the Montgomery constant. 4236238847 is -q^-1 mod 2^32 and
# belongs to the additive convention; with the subtractive reduction used here
# it produces plausible-looking but wrong products.
run_mutation "M1 Montgomery constant sign flipped" ntt_d_tables_pkg.vhd \
'  constant C_QINVD : integer := 58728449;|||  constant C_QINVD : integer := -58728449;' || FAIL=1

# M2: midx frozen at a len boundary, reusing the previous root for the first
# block of each new layer. This was a real bring-up bug, not a hypothetical.
run_mutation "M2 root index frozen at len boundary" ntt_d_unit.vhd \
'            if jj = st + len - 1 then
              midx <= midx + 1;
              if st + 2 * len >= 256 then
                if len = 1 then|||            if jj = st + len - 1 then
              if st + 2 * len >= 256 then
                midx <= midx + 1;
                if len = 1 then' || FAIL=1

# M3: forward butterfly halves swapped.
run_mutation "M3 forward butterfly halves swapped" ntt_d_unit.vhd \
'            a_wdata <= std_logic_vector(opa + mont_d(pr));
            a_we    <= '"'"'1'"'"';
            opa     <= opa - mont_d(pr);|||            a_wdata <= std_logic_vector(opa - mont_d(pr));
            a_we    <= '"'"'1'"'"';
            opa     <= opa + mont_d(pr);' || FAIL=1

# M4: the inverse final scale dropped, leaving every coefficient 256x too big.
run_mutation "M4 inverse final scale dropped" ntt_d_unit.vhd \
'            pr      := resize(signed(a_rdata) * to_signed(C_SD, 24), 56);
            a_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            a_wdata <= std_logic_vector(mont_d(pr));|||            pr      := resize(signed(a_rdata) * to_signed(C_SD, 24), 56);
            a_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            a_wdata <= a_rdata;' || FAIL=1

# M5: inverse butterfly subtracts in the wrong order.
run_mutation "M5 inverse butterfly operand order" ntt_d_unit.vhd \
'            pr      := resize(zeta * (signed(a_rdata) - opa), 56);|||            pr      := resize(zeta * (opa - signed(a_rdata)), 56);' || FAIL=1

# M6: the pointwise product reduces the wrong operand pair, dropping the
# Montgomery reduction so the R factor survives into the result.
run_mutation "M6 pointwise product not reduced" ntt_d_unit.vhd \
'            pr      := resize(opa * signed(b_rdata), 56);
            a_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            a_wdata <= std_logic_vector(mont_d(pr));|||            pr      := resize(opa * signed(b_rdata), 56);
            a_waddr <= std_logic_vector(to_unsigned(cnt, 8));
            a_wdata <= std_logic_vector(resize(pr, C_CW));' || FAIL=1

# M7: settle state removed before sampling the second operand, the recurring
# synchronous-memory defect from the ML-KEM bring-up.
run_mutation "M7 read settle bypassed" ntt_d_unit.vhd \
'          when S_F_RD2W =>
            fsm <= S_F_WR1;|||          when S_F_RD2W =>
            fsm <= S_F_WR1;
          when S_F_RD1W =>
            fsm <= S_F_WR1;' || FAIL=1

# M8: the zeta table read off by one.
run_mutation "M8 zeta index off by one" ntt_d_unit.vhd \
'            zeta    <= C_ZETAS_D(midx + 1);|||            zeta    <= C_ZETAS_D(midx + 2);' || FAIL=1

# M9: Montgomery shift by the wrong amount.
run_mutation "M9 Montgomery shift width wrong" ntt_d_unit.vhd \
'    return resize(shift_right(num, 32), C_CW);|||    return resize(shift_right(num, 31), C_CW);' || FAIL=1

# M10: the inverse walks the root table upwards instead of downwards.
run_mutation "M10 inverse root direction reversed" ntt_d_unit.vhd \
'              midx <= midx - 1;
              if st + 2 * len >= 256 then
                if len = 128 then|||              midx <= midx + 1;
              if st + 2 * len >= 256 then
                if len = 128 then' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
