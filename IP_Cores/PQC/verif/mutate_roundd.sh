#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A Encaps mutation tests.
# Each mutation must be killed by tb_round_d.
# =============================================================================
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 3B ML-DSA rounding mutations (each must be killed):"

run_mutation () {
  NAME="$1"; FILE="$2"; PYEXPR="$3"
  WORK=$(mktemp -d)
  for f in ntt_d_tables_pkg pqc_round_d_pkg; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_round_d.vhd dsa_round_vectors.txt "$WORK/" 2>/dev/null
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
      tb_round_d.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_round_d > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 tb_round_d --stop-time=50ms 2>&1)
    if echo "$OUT" | grep -q "ROUNDD PASS"; then
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

# M1: Power2Round boundary written as >= instead of >. r0 = 2^(D-1) must stay
# positive; flipping this moves a whole class of inputs.
run_mutation "M1 Power2Round boundary inclusive" pqc_round_d_pkg.vhd \
'    if lo > to_signed(2 ** (C_D_D - 1), C_D_D + 2) then|||    if lo >= to_signed(2 ** (C_D_D - 1), C_D_D + 2) then' || FAIL=1

# M2: Decompose boundary likewise.
run_mutation "M2 Decompose boundary inclusive" pqc_round_d_pkg.vhd \
'    if lo > to_signed(C_GAMMA2_DD, C_CW + 1) then
      lo := lo - to_signed(C_TWOG2, C_CW + 1);
    end if;
    -- the wraparound case|||    if lo >= to_signed(C_GAMMA2_DD, C_CW + 1) then
      lo := lo - to_signed(C_TWOG2, C_CW + 1);
    end if;
    -- the wraparound case' || FAIL=1

# M3: the wraparound at q-1 dropped from the low part.
run_mutation "M3 Decompose wraparound low part dropped" pqc_round_d_pkg.vhd \
'    if hi = to_signed(C_QD - 1, C_CW + 1) then
      lo := lo - to_signed(1, C_CW + 1);
    end if;|||    if hi = to_signed(C_QD - 1, C_CW + 1) then
      lo := lo;
    end if;' || FAIL=1

# M4: the wraparound dropped from the high part, so r1 returns 16.
run_mutation "M4 Decompose wraparound high part dropped" pqc_round_d_pkg.vhd \
'    if hi = to_signed(C_QD - 1, C_CW + 1) then
      return to_unsigned(0, C_CW);
    end if;|||    if hi = to_signed(C_QD - 1, C_CW + 1) then
      return to_unsigned(16, C_CW);
    end if;' || FAIL=1

# M5: the multiply-shift constant off by one, which is exact for small inputs
# and wrong at the top of the range.
run_mutation "M5 divide constant off by one" pqc_round_d_pkg.vhd \
'  constant C_DIVMUL   : integer := 8396809;|||  constant C_DIVMUL   : integer := 8396808;' || FAIL=1

# M6: the shift amount wrong.
run_mutation "M6 divide shift wrong" pqc_round_d_pkg.vhd \
'  constant C_DIVSH    : integer := 42;|||  constant C_DIVSH    : integer := 43;' || FAIL=1

# M7: UseHint decrements when it should increment.
run_mutation "M7 UseHint direction inverted" pqc_round_d_pkg.vhd \
'      if r0 > 0 then
        v := r1(3 downto 0) + 1;
      else
        v := r1(3 downto 0) - 1;
      end if;|||      if r0 > 0 then
        v := r1(3 downto 0) - 1;
      else
        v := r1(3 downto 0) + 1;
      end if;' || FAIL=1

# M8: UseHint tests the low part inclusively.
run_mutation "M8 UseHint low part test inclusive" pqc_round_d_pkg.vhd \
'      if r0 > 0 then
        v := r1(3 downto 0) + 1;|||      if r0 >= 0 then
        v := r1(3 downto 0) + 1;' || FAIL=1

# M9: UseHint ignores the hint entirely.
run_mutation "M9 UseHint ignores the hint" pqc_round_d_pkg.vhd \
'    if h = '"'"'1'"'"' then
      if r0 > 0 then|||    if h = '"'"'0'"'"' then
      if r0 > 0 then' || FAIL=1

# M10: Power2Round shifts by the wrong amount.
run_mutation "M10 Power2Round shift wrong" pqc_round_d_pkg.vhd \
'    return resize(unsigned(shift_right(num, C_D_D)), C_CW);|||    return resize(unsigned(shift_right(num, C_D_D - 1)), C_CW);' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
