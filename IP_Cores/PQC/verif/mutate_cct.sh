#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 3A codec_ct mutation tests.
# Each mutation must be killed by tb_codec_ct.
# =============================================================================
set -u
SRC="../rtl/codec_ct.vhd"
[ -f "$SRC" ] || SRC="codec_ct.vhd"
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 3A codec_ct mutations (each must be killed):"

run_mutation () {
  NAME="$1"; PYEXPR="$2"
  WORK=$(mktemp -d)
  for f in keccak_pkg keccak_f1600 keccak_sponge ntt_tables_pkg pqc_round_pkg \
           pqc_codec_pkg ntt_unit sampler_ntt_k sampler_misc basemul_k \
           poly_mem byte_mem codec_ct; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_codec_ct.vhd codec_ct_vectors.txt "$WORK/" 2>/dev/null
  ( cd "$WORK"
    python3 - "$PYEXPR" << 'PYEOF'
import sys
old, new = sys.argv[1].split("|||")
s = open("codec_ct.vhd").read()
if old not in s:
    sys.stderr.write("MUTATION DID NOT APPLY\n")
    sys.exit(2)
open("codec_ct.vhd", "w").write(s.replace(old, new, 1))
PYEOF
    if [ $? -ne 0 ]; then echo "  ERROR: $NAME did not apply"; exit 3; fi
    rm -rf work-obj08.cf
    ghdl -a --std=08 keccak_pkg.vhd keccak_f1600.vhd keccak_sponge.vhd \
      ntt_tables_pkg.vhd pqc_round_pkg.vhd pqc_codec_pkg.vhd ntt_unit.vhd \
      sampler_ntt_k.vhd sampler_misc.vhd basemul_k.vhd poly_mem.vhd \
      byte_mem.vhd codec_ct.vhd tb_codec_ct.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_codec_ct > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 tb_codec_ct --stop-time=500ms 2>&1)
    if echo "$OUT" | grep -q "CODECCT PASS"; then
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

run_mutation "M1 encode d=10 byte1 field split" \
'            b_wdata <= std_logic_vector(c(1)(5 downto 0)) &
                       std_logic_vector(c(0)(9 downto 8));|||            b_wdata <= std_logic_vector(c(1)(5 downto 0)) &
                       std_logic_vector(c(0)(8 downto 7));' || FAIL=1

run_mutation "M2 encode d=10 byte3 field split" \
'            b_wdata <= std_logic_vector(c(3)(1 downto 0)) &
                       std_logic_vector(c(2)(9 downto 4));|||            b_wdata <= std_logic_vector(c(3)(1 downto 0)) &
                       std_logic_vector(c(2)(8 downto 3));' || FAIL=1

run_mutation "M3 encode d=10 group stride" \
'            bidx    := to_integer(unsigned(base)) + 5 * grp;|||            bidx    := to_integer(unsigned(base)) + 4 * grp;' || FAIL=1

run_mutation "M4 encode d=4 nibble order" \
'            b_wdata <= std_logic_vector(c(1)(3 downto 0)) &
                       std_logic_vector(c(0)(3 downto 0));|||            b_wdata <= std_logic_vector(c(0)(3 downto 0)) &
                       std_logic_vector(c(1)(3 downto 0));' || FAIL=1

run_mutation "M5 compress width d=10 to d=11" \
'            c(sub) <= to_unsigned(compress_k(10, canon(signed(p_rdata))), 10);|||            c(sub) <= to_unsigned(compress_k(11, canon(signed(p_rdata))), 10);' || FAIL=1

run_mutation "M6 canonical lift dropped before compress" \
'    if v < 0 then
      v := v + work.ntt_tables_pkg.C_QK;
    end if;|||    if v < 0 then
      v := v;
    end if;' || FAIL=1

run_mutation "M7 decode d=10 byte2 field split" \
'              when 2 => c(1)(9 downto 6) <= unsigned(b_rdata(3 downto 0));
                        c(2)(3 downto 0) <= unsigned(b_rdata(7 downto 4));|||              when 2 => c(1)(9 downto 6) <= unsigned(b_rdata(4 downto 1));
                        c(2)(3 downto 0) <= unsigned(b_rdata(7 downto 4));' || FAIL=1

run_mutation "M8 decode d=4 high nibble" \
'            c(1) <= resize(unsigned(b_rdata(7 downto 4)), 10);|||            c(1) <= resize(unsigned(b_rdata(6 downto 3)), 10);' || FAIL=1

run_mutation "M9 decode decompress width" \
'                         decompress_k(4, to_integer(c(0))), 16));|||                         decompress_k(5, to_integer(c(0))), 16));' || FAIL=1

run_mutation "M10 encode d=10 settle bypass" \
'            p_raddr <= std_logic_vector(to_unsigned(4 * grp + sub, 8));
            fsm     <= S_E10_RDW;|||            p_raddr <= std_logic_vector(to_unsigned(4 * grp + sub, 8));
            fsm     <= S_E10_LAT;' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
