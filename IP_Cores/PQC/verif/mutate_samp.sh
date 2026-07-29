#!/usr/bin/env bash
# Layer 1 sampler mutation harness: each mutation must FAIL the testbench.
set -u
RTL="../rtl/keccak_pkg.vhd ../rtl/keccak_f1600.vhd ../rtl/keccak_sponge.vhd \
     ../rtl/ntt_tables_pkg.vhd ../rtl/sampler_ntt_k.vhd ../rtl/sampler_misc.vhd"
PASS_LINE="PQC L1 SAMPLER PASS"

run_mut () {
  name="$1"; file="$2"; from="$3"; to="$4"
  d=$(mktemp -d)
  cp $RTL tb_sampler.vhd sampler_vectors.txt "$d"/
  python3 - "$d/$file" "$from" "$to" << 'PYEOF'
import sys
p,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
s=open(p).read()
assert a in s, "mutation anchor not found: "+a
open(p,'w').write(s.replace(a,b,1))
PYEOF
  ( cd "$d" && ghdl -a --std=08 keccak_pkg.vhd keccak_f1600.vhd keccak_sponge.vhd \
       ntt_tables_pkg.vhd sampler_ntt_k.vhd sampler_misc.vhd tb_sampler.vhd >/dev/null 2>&1 \
      && ghdl -e --std=08 tb_sampler >/dev/null 2>&1 \
      && timeout 600 ghdl -r --std=08 tb_sampler --stop-time=200ms 2>&1 | tail -3 > out.txt
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
echo "Layer 1 sampler mutations (each must be killed):"

# M1: S1 accepts candidates equal to q (boundary off by one)
run_mut "M1 S1 rejection boundary" sampler_ntt_k.vhd \
  "if d1 < C_Q then" "if d1 <= C_Q then" || fails=1

# M2: S1 swaps the nibble split of the second candidate
run_mut "M2 S1 candidate nibble swap" sampler_ntt_k.vhd \
  "d2 := b2 & b1(7 downto 4);" "d2 := b2 & b1(3 downto 0);" || fails=1

# M3: S2 CBD bit-pair order swapped
run_mut "M3 S2 CBD pair swap" sampler_misc.vhd \
  "co_data <= std_logic_vector(cbd_pair(byt(1 downto 0),
                                                 byt(3 downto 2)));" \
  "co_data <= std_logic_vector(cbd_pair(byt(3 downto 2),
                                                 byt(1 downto 0)));" || fails=1

# M4: S3 forgets to mask the top bit of the third byte
run_mut "M4 S3 missing 23-bit mask" sampler_misc.vhd \
  "z := b2(6 downto 0) & b1 & b0;" \
  "z := b2(7 downto 1) & b1 & b0;" || fails=1

# M4b: S3 rejection boundary off by one (needs the directed boundary vector)
run_mut "M4b S3 rejection boundary" sampler_misc.vhd \
  "if z < to_unsigned(C_QD, 23) then" \
  "if z <= to_unsigned(C_QD, 23) then" || fails=1

# M5: S4 nibble acceptance threshold wrong
run_mut "M5 S4 nibble threshold" sampler_misc.vhd \
  "if byt(3 downto 0) < 9 then" "if byt(3 downto 0) < 10 then" || fails=1

# M6: S5 swap direction inverted (writes 1 at i instead of j)
run_mut "M6 S5 swap direction" sampler_misc.vhd \
  "co_addr <= std_logic_vector(to_unsigned(j_idx, 8));
            if signs(sbit) = '1' then" \
  "co_addr <= std_logic_vector(to_unsigned(i_idx, 8));
            if signs(sbit) = '1' then" || fails=1

# M7: S5 rejection comparison uses strict less-than
run_mut "M7 S5 draw comparison" sampler_misc.vhd \
  "if j_idx <= i_idx then" "if j_idx < i_idx then" || fails=1

# M8: S6 unpacks 19 bits instead of 20
run_mut "M8 S6 field width" sampler_misc.vhd \
  "z := C_GAMMA1 - to_integer(acc(19 downto 0));" \
  "z := C_GAMMA1 - to_integer(acc(18 downto 0));" || fails=1

# M9: S6 shifts the accumulator by the wrong amount
run_mut "M9 S6 accumulator shift" sampler_misc.vhd \
  "acc     <= shift_right(acc, 20);" "acc     <= shift_right(acc, 19);" || fails=1

if [ $fails -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
