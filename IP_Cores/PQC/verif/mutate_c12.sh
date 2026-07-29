#!/usr/bin/env bash
# Layer 3A codec_12 mutation harness: each mutation must FAIL the testbench.
set -u
PASS_LINE="PQC L3A CODEC12 PASS"

run_mut () {
  name="$1"; from="$2"; to="$3"
  d=$(mktemp -d)
  cp ../rtl/ntt_tables_pkg.vhd ../rtl/byte_mem.vhd tb_codec12.vhd codec12_vectors.txt "$d"/
  python3 - "$d/byte_mem.vhd" "$from" "$to" << 'PYEOF'
import sys
p,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
s=open(p).read()
assert a in s, "mutation anchor not found: "+a
open(p,'w').write(s.replace(a,b,1))
PYEOF
  ( cd "$d" && ghdl -a --std=08 ntt_tables_pkg.vhd byte_mem.vhd tb_codec12.vhd >/dev/null 2>&1 \
      && ghdl -e --std=08 tb_codec12 >/dev/null 2>&1 \
      && timeout 600 ghdl -r --std=08 tb_codec12 --stop-time=200ms 2>&1 | tail -3 > out.txt
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
echo "Layer 3A codec_12 mutations (each must be killed):"

# M1: middle byte nibbles swapped on encode
run_mut "M1 encode middle nibbles" \
  "b_wdata <= std_logic_vector(c1(3 downto 0) & c0(11 downto 8));" \
  "b_wdata <= std_logic_vector(c0(11 downto 8) & c1(3 downto 0));" || fails=1

# M2: high byte takes the wrong slice on encode
run_mut "M2 encode high byte slice" \
  "b_wdata <= std_logic_vector(c1(11 downto 4));" \
  "b_wdata <= std_logic_vector(c1(7 downto 0));" || fails=1

# M3: byte stride wrong, pairs overlap
run_mut "M3 encode byte stride" \
  "            bidx    := to_integer(unsigned(base)) + 3 * pair;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 12));
            b_wdata <= std_logic_vector(c0(7 downto 0));" \
  "            bidx    := to_integer(unsigned(base)) + 2 * pair;
            b_addr  <= std_logic_vector(to_unsigned(bidx, 12));
            b_wdata <= std_logic_vector(c0(7 downto 0));" || fails=1

# M4: decode reconstructs the low coefficient from the wrong nibble
run_mut "M4 decode low nibble" \
  "                         resize(signed('0' & by1(3 downto 0) & by0), 16));" \
  "                         resize(signed('0' & by1(7 downto 4) & by0), 16));" || fails=1

# M5: decode reconstructs the high coefficient from the wrong nibble
run_mut "M5 decode high nibble" \
  "            c1      <= unsigned(b_rdata) & by1(7 downto 4);" \
  "            c1      <= unsigned(b_rdata) & by1(3 downto 0);" || fails=1

# M6: canonical conversion dropped, so negative values pack as huge unsigned
run_mut "M6 canonical conversion" \
  "    if v < 0 then
      v := v + C_QK;
    end if;
    return to_unsigned(v, 12);" \
  "    if false then
      v := v + C_QK;
    end if;
    return to_unsigned(v, 12);" || fails=1

# M7: encode settle state bypassed, so c0 is captured one cycle early from
# stale polynomial data. The earlier formulation of this mutation added the
# capture in S_E_RD0W without removing the one in S_E_RD1, which the later
# assignment simply overwrote: an equivalent mutation by construction. The
# version below actually skips the settle cycle.
run_mut "M7 encode settle bypass" \
  "          when S_E_RD0 =>
            p_raddr <= std_logic_vector(to_unsigned(2 * pair, 8));
            fsm     <= S_E_RD0W;" \
  "          when S_E_RD0 =>
            p_raddr <= std_logic_vector(to_unsigned(2 * pair, 8));
            fsm     <= S_E_RD1;" || fails=1

# M8: decode settle state bypassed on the first byte read
run_mut "M8 decode settle bypass" \
  "          when S_D_RD0 =>
            bidx   := to_integer(unsigned(base)) + 3 * pair;
            b_addr <= std_logic_vector(to_unsigned(bidx, 12));
            fsm    <= S_D_RD0W;" \
  "          when S_D_RD0 =>
            bidx   := to_integer(unsigned(base)) + 3 * pair;
            b_addr <= std_logic_vector(to_unsigned(bidx, 12));
            fsm    <= S_D_RD1;" || fails=1

if [ $fails -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
