#!/usr/bin/env bash
# =============================================================================
# HERCOSSNUX PQC IP Core - Layer 4 core integration mutation tests.
# Each mutation must be killed by tb_dsa_core.
#
# These target the INTEGRATION, not the algorithms. The three sequencers now
# share one datapath and one polynomial memory, and their slot maps overlap
# heavily: KeyGen's SL_S1H sits where Sign keeps hint data. That is safe only
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

echo "Layer 4 ML-DSA core integration mutations (each must be killed):"

run_mutation () {
  NAME="$1"; STAGE="$2"; FILE="$3"; PYEXPR="$4"
  WORK=$(mktemp -d)
  for f in keccak_pkg keccak_f1600 keccak_sponge ntt_d_tables_pkg pqc_round_d_pkg poly_mem_d byte_mem_d ntt_d_unit sampler_d codec_d dsa_keygen dsa_sign dsa_verify dsa_core; do
    cp "$RTL_DIR/$f.vhd" "$WORK/" 2>/dev/null
  done
  cp tb_dsa_core.vhd dsa_st_vectors.txt "$WORK/" 2>/dev/null
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
    ghdl -a --std=08 keccak_pkg.vhd keccak_f1600.vhd keccak_sponge.vhd \
      ntt_d_tables_pkg.vhd pqc_round_d_pkg.vhd poly_mem_d.vhd \
      byte_mem_d.vhd ntt_d_unit.vhd sampler_d.vhd codec_d.vhd \
      dsa_keygen.vhd dsa_sign.vhd dsa_verify.vhd dsa_core.vhd tb_dsa_core.vhd > /dev/null 2>&1
    ghdl -e --std=08 tb_dsa_core > /dev/null 2>&1
    if [ "$STAGE" = "full" ]; then
      OUT=$(ghdl -r --std=08 tb_dsa_core -gG_STAGE=0 --stop-time=400000ms 2>&1)
      PAT="L4 DSACORE PASS"
    else
      OUT=$(ghdl -r --std=08 tb_dsa_core -gG_STAGE=$STAGE --stop-time=8000ms 2>&1)
      PAT="L4 DSACORE PASS"
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

# M1: the operation mux ignores the op register and always selects KeyGen.
# The most basic integration failure, and one no per-operation testbench
# could have seen because each had its own top level.
run_mutation "M1 operation mux stuck on KeyGen" full dsa_core.vhd \
'  sel <= to_integer(unsigned(op));|||  sel <= 0;' || FAIL=1

# M2: start reaches every sequencer instead of only the selected one, so all
# three run concurrently on one datapath. That is exactly the concurrency the
# mux exists to rule out.
run_mutation "M2 start broadcast to all sequencers" full dsa_core.vhd \
'  st_sg <= start when op = "01" else '"'"'0'"'"';|||  st_sg <= start;' || FAIL=1

# M3: the shared sponge read strobe loses its sampler arbitration. Two
# drivers on that line resolve to X and stall the sponge silently, which cost
# most of a day during the ML-KEM KeyGen bring-up.
run_mutation "M3 sponge read strobe arbitration dropped" full dsa_core.vhd \
'  sp_re <= s_spre when smp_busy = '"'"'1'"'"' else q_spre_sel;|||  sp_re <= q_spre_sel;' || FAIL=1

# M4: the polynomial memory write enable ignores the codec, so codec writes
# are lost.
run_mutation "M4 codec write enable dropped from the mux" full dsa_core.vhd \
'              c_we     when cod_busy = '"'"'1'"'"' else
              q_we(sel);|||              q_we(sel);' || FAIL=1

# M5: the hint codec row offset dropped from the slot select. The codec walks
# six rows internally and the core adds that to the slot the sequencer chose;
# without it every row lands on the same slot.
run_mutation "M5 codec row offset dropped" full dsa_core.vhd \
'  m_aslot <= q_slot_a(sel) + cod_row when cod_busy = '"'"'1'"'"' else q_slot_a(sel);|||  m_aslot <= q_slot_a(sel);' || FAIL=1

# M6: the byte memory address ignores the codec, which is the shared resource
# the three operations contend for most.
run_mutation "M6 codec byte address dropped" full dsa_core.vhd \
'            c_baddr when cod_busy = '"'"'1'"'"' else
            q_byaddr(sel);|||            q_byaddr(sel);' || FAIL=1

# M7: done reported from the wrong sequencer, so the driver advances before
# the operation finished and reads a partially written result.
run_mutation "M7 done taken from the wrong sequencer" full dsa_core.vhd \
'  done <= q_done(sel);|||  done <= q_done(0);' || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "ALL MUTATIONS KILLED"
else
  echo "SOME MUTATIONS SURVIVED"; exit 1
fi
