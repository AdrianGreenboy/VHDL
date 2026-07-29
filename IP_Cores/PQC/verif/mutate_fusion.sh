#!/usr/bin/env bash
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."
echo "Layer 4 PQC fusion mutations (each must be killed):"

run_mutation () {
  NAME="$1"; FILE="$2"; PYEXPR="$3"
  WORK=$(mktemp -d)
  cp "$RTL_DIR"/*.vhd *.vhd *_st_vectors.txt "$WORK"/ 2>/dev/null
  cd "$WORK"
  python3 - "$FILE" "$PYEXPR" << 'PYEOF'
import sys
path, expr = sys.argv[1], sys.argv[2]
old, new = expr.split("|||")
s = open(path).read()
if old not in s:
    sys.stderr.write("ANCHOR MISSING in %s\n" % path); sys.exit(2)
open(path, "w").write(s.replace(old, new, 1))
PYEOF
  if [ $? -ne 0 ]; then echo "  ERROR: $NAME did not apply"; cd - >/dev/null; rm -rf "$WORK"; return 1; fi
  rm -rf work-obj08.cf
  ghdl -a --std=08 keccak_pkg.vhd keccak_f1600.vhd keccak_sponge.vhd \
    ntt_tables_pkg.vhd pqc_codec_pkg.vhd pqc_round_pkg.vhd poly_mem.vhd \
    ntt_d_tables_pkg.vhd pqc_round_d_pkg.vhd poly_mem_d.vhd \
    sampler_ntt_k.vhd sampler_misc.vhd ntt_unit.vhd basemul_k.vhd byte_mem.vhd codec_ct.vhd \
    byte_mem_d.vhd ntt_d_unit.vhd sampler_d.vhd codec_d.vhd \
    kem_keygen.vhd kem_encaps.vhd kem_decaps.vhd kem_core_sx.vhd \
    dsa_keygen.vhd dsa_sign.vhd dsa_verify.vhd dsa_core_sx.vhd \
    pqc_core.vhd tb_pqc_core.vhd > /dev/null 2>&1
  ghdl -e --std=08 tb_pqc_core > /dev/null 2>&1
  OUT=$(ghdl -r --std=08 tb_pqc_core --stop-time=800000ms 2>&1)
  cd - >/dev/null; rm -rf "$WORK"
  if echo "$OUT" | grep -q "L4 FUSION PASS"; then
    echo "  SURVIVED: $NAME"; return 1
  else
    echo "  killed: $NAME"; return 0
  fi
}

FAIL=0

# M1: the sponge mux frozen on the KEM core. The DSA chain then drives a
# sponge it does not own, and its signature must move. THIS is the mutation
# that proves the sponge is genuinely shared: if it survived, there would be
# a second sponge hiding somewhere.
run_mutation "M1 sponge mux frozen on KEM" pqc_core.vhd \
'  sp_mode  <= d_mode  when alg = '"'"'1'"'"' else k_mode;|||  sp_mode  <= k_mode;' || FAIL=1

# M2: the sponge input data mux frozen on KEM, a subtler version: control
# follows alg but the absorbed bytes always come from the KEM core.
run_mutation "M2 sponge din frozen on KEM" pqc_core.vhd \
'  sp_din   <= d_din   when alg = '"'"'1'"'"' else k_din;|||  sp_din   <= k_din;' || FAIL=1

# M3: alg inverted, so each algorithm drives the sponge while the other is
# selected. Both chains break.
run_mutation "M3 alg select inverted" pqc_core.vhd \
'  sp_we    <= d_we    when alg = '"'"'1'"'"' else k_we;|||  sp_we    <= d_we    when alg = '"'"'0'"'"' else k_we;' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
