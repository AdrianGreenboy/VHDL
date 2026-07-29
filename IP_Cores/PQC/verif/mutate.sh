#!/usr/bin/env bash
# Layer 1 mutation harness: each mutation must FAIL the testbench.
set -u
SRC_PKG=../rtl/keccak_pkg.vhd
SRC_F=../rtl/keccak_f1600.vhd
SRC_S=../rtl/keccak_sponge.vhd
SRC_TB=tb_keccak.vhd
PASS_LINE="PQC L1 KECCAK PASS"

run_mut () {
  name="$1"; file="$2"; from="$3"; to="$4"
  d=$(mktemp -d)
  cp "$SRC_PKG" "$SRC_F" "$SRC_S" "$SRC_TB" keccak_vectors.txt sponge_vectors.txt "$d"/
  python3 - "$d/$file" "$from" "$to" << 'PYEOF'
import sys
p,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
s=open(p).read()
assert a in s, "mutation anchor not found: "+a
open(p,'w').write(s.replace(a,b,1))
PYEOF
  ( cd "$d" && ghdl -a --std=08 keccak_pkg.vhd keccak_f1600.vhd keccak_sponge.vhd tb_keccak.vhd >/dev/null 2>&1 \
      && ghdl -e --std=08 tb_keccak >/dev/null 2>&1 \
      && timeout 300 ghdl -r --std=08 tb_keccak --stop-time=50ms 2>&1 | tail -3 > out.txt
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
echo "Layer 1 mutations (each must be killed):"

# M1: drop one Keccak round pair (23 instead of 24 rounds)
run_mut "M1 drop round pair" keccak_f1600.vhd "if i = 22 then" "if i = 20 then" || fails=1

# M2: wrong rotation offset in rho (single lane)
run_mut "M2 wrong rho offset" keccak_pkg.vhd "(1, 44, 10, 45,  2)," "(1, 44, 10, 45,  3)," || fails=1

# M3: off-by-one in a round constant
run_mut "M3 corrupt round constant" keccak_pkg.vhd 'x"8000000080008000"' 'x"8000000080008001"' || fails=1

# M4: chi uses wrong lane offset (x+1/x+2 swapped)
run_mut "M4 chi lane swap" keccak_pkg.vhd \
  "((not b(((x + 1) mod 5) + 5 * y)) and
                         b(((x + 2) mod 5) + 5 * y));" \
  "((not b(((x + 2) mod 5) + 5 * y)) and
                         b(((x + 1) mod 5) + 5 * y));" || fails=1

# M5: theta uses wrong neighbour column
run_mut "M5 theta neighbour" keccak_pkg.vhd \
  "d(x) := c((x + 4) mod 5) xor rotl(c((x + 1) mod 5), 1);" \
  "d(x) := c((x + 4) mod 5) xor rotl(c((x + 2) mod 5), 1);" || fails=1

# M6: wrong domain separator for SHA3 (0x06 -> 0x1F)
run_mut "M6 wrong domain separator" keccak_sponge.vhd \
  'when "10" => rate <= 136; ds <= x"06";  -- SHA3-256' \
  'when "10" => rate <= 136; ds <= x"1F";  -- SHA3-256' || fails=1

# M7: missing final pad bit 0x80
run_mut "M7 missing pad bit" keccak_sponge.vhd \
  's_tmp   := xor_byte(s_tmp, rate - 1, x"80");' \
  's_tmp   := xor_byte(s_tmp, rate - 1, x"00");' || fails=1

# M8: SHAKE128 rate wrong (168 -> 136)
run_mut "M8 wrong SHAKE128 rate" keccak_sponge.vhd \
  'when "00" => rate <= 168; ds <= x"1F";  -- SHAKE128' \
  'when "00" => rate <= 136; ds <= x"1F";  -- SHAKE128' || fails=1

if [ $fails -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"
  exit 1
fi
