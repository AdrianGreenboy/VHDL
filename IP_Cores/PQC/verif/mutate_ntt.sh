#!/usr/bin/env bash
# Layer 1 NTT mutation harness: each mutation must FAIL the testbench.
set -u
SRC_T=../rtl/ntt_tables_pkg.vhd
SRC_U=../rtl/ntt_unit.vhd
SRC_TB=tb_ntt.vhd
PASS_LINE="PQC L1 NTT PASS"

run_mut () {
  name="$1"; file="$2"; from="$3"; to="$4"
  d=$(mktemp -d)
  cp "$SRC_T" "$SRC_U" "$SRC_TB" ntt_k_vectors.txt ntt_d_vectors.txt "$d"/
  python3 - "$d/$file" "$from" "$to" << 'PYEOF'
import sys
p,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
s=open(p).read()
assert a in s, "mutation anchor not found: "+a
open(p,'w').write(s.replace(a,b,1))
PYEOF
  ( cd "$d" && ghdl -a --std=08 ntt_tables_pkg.vhd ntt_unit.vhd tb_ntt.vhd >/dev/null 2>&1 \
      && ghdl -e --std=08 tb_ntt >/dev/null 2>&1 \
      && timeout 600 ghdl -r --std=08 tb_ntt --stop-time=500ms 2>&1 | tail -3 > out.txt
    if grep -q "$PASS_LINE" out.txt 2>/dev/null; then
      echo "MUTATION NOT CAUGHT: $name"
      exit 1
    fi )
  rc=$?
  rm -rf "$d"
  if [ $rc -ne 0 ]; then echo "FAIL $name"; return 1; fi
  echo "  killed: $name"
  return 0
}

fails=0
echo "Layer 1 NTT mutations (each must be killed):"

# M1: wrong Montgomery constant for Kyber
run_mut "M1 wrong QINVK" ntt_tables_pkg.vhd \
  "constant C_QINVK : integer := 62209;" \
  "constant C_QINVK : integer := 62208;" || fails=1

# M2: wrong Montgomery constant for Dilithium
run_mut "M2 wrong QINVD" ntt_tables_pkg.vhd \
  "constant C_QINVD : integer := 58728449;" \
  "constant C_QINVD : integer := 58728451;" || fails=1

# M3: corrupt a single Kyber twiddle
run_mut "M3 corrupt zeta_K" ntt_tables_pkg.vhd \
  "C_ZETA_K : t_zk := (" "C_ZETA_K : t_zk := (1 + " || fails=1

# M4: wrong final INTT scaling for Kyber
run_mut "M4 wrong SK" ntt_tables_pkg.vhd \
  "constant C_SK    : integer := 512;" \
  "constant C_SK    : integer := 256;" || fails=1

# M5: wrong final INTT scaling for Dilithium
run_mut "M5 wrong SD" ntt_tables_pkg.vhd \
  "constant C_SD    : integer := 16382;" \
  "constant C_SD    : integer := 16383;" || fails=1

# M6: butterfly sign flip in the forward transform
run_mut "M6 forward butterfly sign" ntt_unit.vhd \
  "res_a <= range_reduce(a_val + tval);
              res_b <= range_reduce(a_val - tval);" \
  "res_a <= range_reduce(a_val - tval);
              res_b <= range_reduce(a_val + tval);" || fails=1

# M7: twiddle index bumped again at layer boundary (the bug found in bring-up)
run_mut "M7 double twiddle bump" ntt_unit.vhd \
  "                    ln     <= ln / 2;
                    tw_idx <= tw_idx + 1;" \
  "                    ln     <= ln / 2;
                    tw_idx <= tw_idx + 2;" || fails=1

# M8: range reduction removed (silent overflow path)
run_mut "M8 no range reduction" ntt_unit.vhd \
  "    if v >= to_signed(G_Q, G_WIDTH) then" \
  "    if false and v >= to_signed(G_Q, G_WIDTH) then" || fails=1

# M9: Dilithium inverse starts at the wrong twiddle (the bug found in bring-up)
run_mut "M9 wrong inverse start idx" ntt_unit.vhd \
  "                  ln     <= 1;
                  tw_idx <= 255;" \
  "                  ln     <= 1;
                  tw_idx <= 254;" || fails=1

if [ $fails -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"
  exit 1
fi
