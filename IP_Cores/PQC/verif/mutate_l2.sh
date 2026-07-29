#!/usr/bin/env bash
# Layer 2 mutation harness: each mutation must FAIL the testbench.
set -u
SRC_P=../rtl/pqc_round_pkg.vhd
SRC_TB=tb_round.vhd
PASS_LINE="PQC L2 ROUND PASS"

run_mut () {
  name="$1"; file="$2"; from="$3"; to="$4"
  d=$(mktemp -d)
  cp "$SRC_P" "$SRC_TB" l2_vectors.txt "$d"/
  python3 - "$d/$file" "$from" "$to" << 'PYEOF'
import sys
p,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
s=open(p).read()
assert a in s, "mutation anchor not found: "+a
open(p,'w').write(s.replace(a,b,1))
PYEOF
  ( cd "$d" && ghdl -a --std=08 pqc_round_pkg.vhd tb_round.vhd >/dev/null 2>&1 \
      && ghdl -e --std=08 tb_round >/dev/null 2>&1 \
      && timeout 300 ghdl -r --std=08 tb_round --stop-time=10ms 2>&1 | tail -3 > out.txt
    if grep -q "$PASS_LINE" out.txt 2>/dev/null; then
      echo "MUTATION NOT CAUGHT: $name"; exit 1
    fi )
  rc=$?
  rm -rf "$d"
  if [ $rc -ne 0 ]; then echo "FAIL $name"; return 1; fi
  echo "  killed: $name"
  return 0
}

fails=0
echo "Layer 2 mutations (each must be killed):"

# M1 (pre-registered): compress rounds down instead of to nearest
run_mut "M1 compress floor not nearest" pqc_round_pkg.vhd \
  "n := shift_left(to_signed(x, 48), d) + to_signed(1664, 48);" \
  "n := shift_left(to_signed(x, 48), d);" || fails=1

# M2 (pre-registered): Decompose q-1 boundary removed from the low part
run_mut "M2 decompose boundary lo" pqc_round_pkg.vhd \
  "    if rp - r0 = C_QD - 1 then
      r0 := r0 - 1;
    end if;" \
  "    if false and rp - r0 = C_QD - 1 then
      r0 := r0 - 1;
    end if;" || fails=1

# M3 (pre-registered): Decompose q-1 boundary removed from the high part
run_mut "M3 decompose boundary hi" pqc_round_pkg.vhd \
  "    if rp - r0 = C_QD - 1 then
      return 0;
    end if;
    return q;" \
  "    return q;" || fails=1

# M4: decompose centring comparison off by one
run_mut "M4 decompose centring" pqc_round_pkg.vhd \
  "    r0 := rp - q * (2 * C_GAMMA2);
    if r0 > C_GAMMA2 then" \
  "    r0 := rp - q * (2 * C_GAMMA2);
    if r0 >= C_GAMMA2 then" || fails=1

# M5: power2round centring boundary off by one
run_mut "M5 power2round centring" pqc_round_pkg.vhd \
  "    if r0 > (2 ** (C_D - 1)) then" \
  "    if r0 >= (2 ** (C_D - 1)) then" || fails=1

# M6: UseHint direction inverted
run_mut "M6 use_hint direction" pqc_round_pkg.vhd \
  "      if r0 > 0 then
        if r1 + 1 = M then" \
  "      if r0 <= 0 then
        if r1 + 1 = M then" || fails=1

# M7: UseHint wrap at the top of the range removed
run_mut "M7 use_hint wrap high" pqc_round_pkg.vhd \
  "        if r1 + 1 = M then
          return 0;
        end if;" \
  "        if false then
          return 0;
        end if;" || fails=1

# M8: UseHint wrap at the bottom of the range removed
run_mut "M8 use_hint wrap low" pqc_round_pkg.vhd \
  "        if r1 = 0 then
          return M - 1;
        end if;" \
  "        if false then
          return M - 1;
        end if;" || fails=1

# M9: MakeHint compares low parts instead of high parts
run_mut "M9 make_hint compares low" pqc_round_pkg.vhd \
  "    if decompose_hi(r) /= decompose_hi(rz) then" \
  "    if decompose_lo(r) /= decompose_lo(rz) then" || fails=1

# M10: compress multiplier corrupted for one width
run_mut "M10 compress multiplier" pqc_round_pkg.vhd \
  "0, 5040, 0, 0, 20159, 0, 0, 0, 0, 0, 2580335, 0, 2580335);" \
  "0, 5040, 0, 0, 20158, 0, 0, 0, 0, 0, 2580335, 0, 2580335);" || fails=1

# M11: decompose shift amount wrong.
# Note: perturbing C_DMUL by +/-1 is an EQUIVALENT mutation, verified over all
# 8380417 residues: the centring correction (q := q + 1) absorbs a one-off
# quotient error, so both constants compute the same function. The shift is
# the constant that genuinely cannot be perturbed.
run_mut "M11 decompose shift" pqc_round_pkg.vhd \
  "constant C_DSHF : integer := 42;" \
  "constant C_DSHF : integer := 41;" || fails=1

# M12: decompress rounding term dropped
run_mut "M12 decompress rounding" pqc_round_pkg.vhd \
  "             to_signed(y * C_QK + to_integer(
               shift_left(to_signed(1, 32), d - 1)), 64), d));" \
  "             to_signed(y * C_QK, 64), d));" || fails=1

if [ $fails -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
