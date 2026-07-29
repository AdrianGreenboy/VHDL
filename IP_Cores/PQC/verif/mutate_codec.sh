#!/usr/bin/env bash
# Layer 2 codec mutation harness: each mutation must FAIL the testbench.
set -u
SRC_P=../rtl/pqc_codec_pkg.vhd
SRC_TB=tb_codec.vhd
PASS_LINE="PQC L2 CODEC PASS"

run_mut () {
  name="$1"; file="$2"; from="$3"; to="$4"
  d=$(mktemp -d)
  cp "$SRC_P" "$SRC_TB" codec_vectors.txt "$d"/
  python3 - "$d/$file" "$from" "$to" << 'PYEOF'
import sys
p,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
s=open(p).read()
assert a in s, "mutation anchor not found: "+a
open(p,'w').write(s.replace(a,b,1))
PYEOF
  ( cd "$d" && ghdl -a --std=08 pqc_codec_pkg.vhd tb_codec.vhd >/dev/null 2>&1 \
      && ghdl -e --std=08 tb_codec >/dev/null 2>&1 \
      && timeout 300 ghdl -r --std=08 tb_codec --stop-time=10ms 2>&1 | tail -3 > out.txt
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
echo "Layer 2 codec mutations (each must be killed):"

# M1 (pre-registered): BitPack b - x sign flip
run_mut "M1 bitpack sign flip" pqc_codec_pkg.vhd \
  "      t(i) := bb - c;" "      t(i) := bb + c;" || fails=1

# M2: BitPack centring removed entirely.
# Note: perturbing the threshold itself (c > q/2 vs c >= q/2) is an EQUIVALENT
# mutation on the real domain: the two differ only when a coefficient equals
# exactly q/2 = 4190208, which lies outside every (a, b) range BitPack is
# called with (eta=4, 2^12, gamma1). Removing the centring is the mutation
# that genuinely changes the function.
run_mut "M2 bitpack centring removed" pqc_codec_pkg.vhd \
  "      if c > q / 2 then
        c := c - q;
      end if;" \
  "      if false then
        c := c - q;
      end if;" || fails=1

# M3: packing emits fields most significant bit first
run_mut "M3 pack bit order" pqc_codec_pkg.vhd \
  "      acc  := acc or shift_left(to_unsigned(p(i), 64), navl);" \
  "      acc  := shift_left(acc, bits) or to_unsigned(p(i), 64);" || fails=1

# M4: unpack mask one bit too narrow
run_mut "M4 unpack mask width" pqc_codec_pkg.vhd \
  "    mask := shift_right(unsigned'(x\"FFFFFFFFFFFFFFFF\"), 64 - bits);" \
  "    mask := shift_right(unsigned'(x\"FFFFFFFFFFFFFFFF\"), 65 - bits);" || fails=1

# M5 (pre-registered): hint monotonicity check removed
run_mut "M5 hint monotonicity" pqc_codec_pkg.vhd \
  "            if y(idx) <= y(idx - 1) then
              good := false;
            end if;" \
  "            if false then
              good := false;
            end if;" || fails=1

# M6: hint omega bound removed
run_mut "M6 hint omega bound" pqc_codec_pkg.vhd \
  "      if yi < idx or yi > C_OMEGA then" \
  "      if yi < idx then" || fails=1

# M7: hint backwards-count check removed
run_mut "M7 hint count backwards" pqc_codec_pkg.vhd \
  "      if yi < idx or yi > C_OMEGA then
        good := false;
      end if;" \
  "      if yi > C_OMEGA then
        good := false;
      end if;" || fails=1

# M8: hint zero-padding check removed
run_mut "M8 hint tail padding" pqc_codec_pkg.vhd \
  "          if y(j) /= 0 then
            good := false;
          end if;" \
  "          if false then
            good := false;
          end if;" || fails=1

# M9: hint_pack writes the cumulative count before the indices
run_mut "M9 hint count position" pqc_codec_pkg.vhd \
  "      y(C_OMEGA + i) := idx;" "      y(C_OMEGA + i) := idx + 1;" || fails=1

# M10: unpack consumes bytes in the wrong order
run_mut "M10 unpack byte order" pqc_codec_pkg.vhd \
  "        acc  := acc or shift_left(to_unsigned(b(idx), 64), navl);" \
  "        acc  := acc or shift_left(to_unsigned(b(idx), 64), navl + 8);" || fails=1

if [ $fails -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
