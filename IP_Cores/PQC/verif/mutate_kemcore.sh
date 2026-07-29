#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 4 ML-KEM core integration mutation tests.
# Each mutation must be killed by tb_kem_core.
#
# These target the INTEGRATION, not the algorithms. The three sequencers now
# share one datapath and one polynomial memory, and their slot maps overlap
# heavily: the three operations share one polynomial memory and one sponge. That is safe only
# because operations are strictly sequential and every sequencer writes each
# slot before it reads it. The chained self-test exercises that ordering, and
# these mutations are what show it can SEE a violation rather than merely not
# tripping over one.
#
# Every mutation runs the full chain. There are no checkpoint stages here by
# design: the property under test is end-to-end.
# =============================================================================
set -u
RTL_DIR="../rtl"
[ -d "$RTL_DIR" ] || RTL_DIR="."

echo "Layer 4 ML-KEM core integration mutations (each must be killed):"

run_mutation () {
  NAME="$1"; STAGE="$2"; FILE="$3"; PYEXPR="$4"
  WORK=$(mktemp -d)
  cp "$RTL_DIR"/kem_st_vectors.txt . 2>/dev/null; cp kem_st_vectors.txt . 2>/dev/null; for f in keccak_pkg keccak_f1600 keccak_sponge ntt_d_tables_pkg pqc_round_d_pkg poly_mem_d byte_mem_d ntt_d_unit sampler_d codec_d keccak_f1600 keccak_sponge sampler_ntt_k sampler_misc ntt_unit basemul_k byte_mem codec_ct kem_keygen kem_encaps kem_decaps kem_core; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_kem_core.vhd kem_st_vectors.txt "$WORK/" 2>/dev/null
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
    ghdl -a --std=08 keccak_pkg.vhd ntt_tables_pkg.vhd pqc_codec_pkg.vhd \
      pqc_round_pkg.vhd poly_mem.vhd keccak_f1600.vhd keccak_sponge.vhd \
      sampler_ntt_k.vhd sampler_misc.vhd ntt_unit.vhd basemul_k.vhd \
      byte_mem.vhd codec_ct.vhd kem_keygen.vhd kem_encaps.vhd \
      kem_decaps.vhd kem_core.vhd tb_kem_core.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_kem_core > /dev/null 2>&1
    if [ "$STAGE" = "full" ]; then
      OUT=$(ghdl -r --std=08 tb_kem_core --stop-time=400000ms 2>&1)
      PAT="L4 KEMCORE PASS"
    else
      OUT=$(ghdl -r --std=08 tb_kem_core --stop-time=400000ms 2>&1)
      PAT="L4 KEMCORE PASS"
    fi
    if echo "$OUT" | grep -q "$PAT"; then
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

FAIL=0

# M1: the operation mux ignores op and always selects KeyGen.
run_mutation "M1 operation mux stuck on KeyGen" full kem_core.vhd \
'  sel   <= to_integer(unsigned(op));|||  sel   <= 0;' || FAIL=1

# M2: start broadcast to all three sequencers, so they run concurrently on
# the one datapath the mux exists to serialize.
run_mutation "M2 start broadcast to all sequencers" full kem_core.vhd \
'  st_en <= start when op = "01" else '"'"'0'"'"';|||  st_en <= start;' || FAIL=1

# M3: the second codec (cct) forced off even for Encaps and Decaps, which
# both need it for the compressed ciphertext.
run_mutation "M3 ciphertext codec disabled" full kem_core.vhd \
'  cct_start <= g_cctstart(sel) when sel /= 0 else '"'"'0'"'"';|||  cct_start <= '"'"'0'"'"';' || FAIL=1

# M4: done reported from the wrong sequencer, advancing the driver early.
run_mutation "M4 done from the wrong sequencer" full kem_core.vhd \
'  done      <= kg_done when sel = 0 else en_done when sel = 1 else de_done;|||  done      <= kg_done;' || FAIL=1

# M5: the byte memory write enable ignores the selected sequencer.
run_mutation "M5 byte write enable stuck low" full kem_core.vhd \
'  by_we     <= g_bywe(sel);|||  by_we     <= '"'"'0'"'"';' || FAIL=1

# M6: the grant mux frozen on KeyGen's grant, so Encaps and Decaps cannot
# drive the polynomial memory.
run_mutation "M6 grant frozen on KeyGen" full kem_core.vhd \
'  grant     <= g_grant(sel);|||  grant     <= g_grant(0);' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
