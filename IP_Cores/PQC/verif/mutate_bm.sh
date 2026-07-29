#!/usr/bin/env bash
# Layer 3 basemul mutation harness: each mutation must FAIL the testbench.
set -u
SRC_T=../rtl/ntt_tables_pkg.vhd
SRC_B=../rtl/basemul_k.vhd
PASS_LINE="PQC L3 BASEMUL PASS"

run_mut () {
  name="$1"; file="$2"; from="$3"; to="$4"
  d=$(mktemp -d)
  cp "$SRC_T" "$SRC_B" tb_basemul.vhd basemul_vectors.txt "$d"/
  python3 - "$d/$file" "$from" "$to" << 'PYEOF'
import sys
p,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
s=open(p).read()
assert a in s, "mutation anchor not found: "+a
open(p,'w').write(s.replace(a,b,1))
PYEOF
  ( cd "$d" && ghdl -a --std=08 ntt_tables_pkg.vhd basemul_k.vhd tb_basemul.vhd >/dev/null 2>&1 \
      && ghdl -e --std=08 tb_basemul >/dev/null 2>&1 \
      && timeout 600 ghdl -r --std=08 tb_basemul --stop-time=100ms 2>&1 | tail -3 > out.txt
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
echo "Layer 3 basemul mutations (each must be killed):"

# M1: gamma twiddle omitted from the odd-odd product
run_mut "M1 missing gamma" basemul_k.vhd \
  "            p   := t1 * gam;
            t1  := mont16(p);" \
  "            p   := t1 * to_signed(1, 16);
            t1  := mont16(p);" || fails=1

# M2: gamma table indexed with the wrong pair
run_mut "M2 gamma index" basemul_k.vhd \
  "gam := to_signed(C_GAMMA_K(pair), 16);" \
  "gam := to_signed(C_GAMMA_K((pair + 1) mod 128), 16);" || fails=1

# M3: cross terms of the odd coefficient swapped to the same operand
run_mut "M3 cross term" basemul_k.vhd \
  "            p   := av1 * b0;
            t1  := mont16(p);
            c1  <= range_reduce(t0 + t1);" \
  "            p   := av1 * bv1;
            t1  := mont16(p);
            c1  <= range_reduce(t0 + t1);" || fails=1

# M4: odd coefficients taken from the stale registers (the bring-up bug)
run_mut "M4 stale odd operand" basemul_k.vhd \
  "            p   := av1 * bv1;
            t1  := mont16(p);" \
  "            p   := a1 * b1;
            t1  := mont16(p);" || fails=1

# M5: accumulate reads the wrong destination address
run_mut "M5 accumulate address" basemul_k.vhd \
  "          when S_ACC1 =>
            d_addr <= std_logic_vector(to_unsigned(2 * pair + 1, 8));" \
  "          when S_ACC1 =>
            d_addr <= std_logic_vector(to_unsigned(2 * pair, 8));" || fails=1

# M6: accumulate settle state removed (samples stale memory data)
run_mut "M6 accumulate settle" basemul_k.vhd \
  "          when S_ACC0D =>
            fsm <= S_ACC0W;" \
  "          when S_ACC0D =>
            c0  <= range_reduce(c0 + signed(d_rdata));
            fsm <= S_WR0;" || fails=1

# M7: Montgomery constant corrupted
run_mut "M7 montgomery constant" basemul_k.vhd \
  "t    := resize(lo * to_signed(C_QINVK, 18), 17);" \
  "t    := resize(lo * to_signed(C_QINVK + 1, 18), 17);" || fails=1

if [ $fails -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
