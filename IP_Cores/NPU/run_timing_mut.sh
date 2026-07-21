#!/bin/bash
# HERCOSSNUX NPU - mutaciones tras los arreglos de timing.
(
set -e
cd "$(dirname "$0")"
if [ ! -d build_tim ]; then echo "FALLO: corre primero run_timing.sh"; exit 1; fi
fail=0; nm=0
for m in 1 2 3 4 5; do
  echo "mutacion $m..."
  o=$(ghdl -r --std=08 --workdir=build_tim tb_npu_seq_full -gG_MUT=$m 2>&1)
  if echo "$o" | grep -q "TB_SEQ_FULL FAIL"; then nm=$((nm+1)); else echo "FALLO: MUT $m NO fallo"; fail=1; fi
done
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO11-MUT OK MUTACIONES $nm/5 FAIL"
)
