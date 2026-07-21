#!/bin/bash
# HERCOSSNUX NPU - mutaciones tras la reestructuracion para BRAM.
(
set -e
cd "$(dirname "$0")"
if [ ! -d build_bram ]; then
  echo "FALLO: corre primero run_bram.sh"; exit 1
fi
fail=0; nm=0
echo "conv1: 5 mutaciones..."
for m in 1 2 3 4 5; do
  o=$(ghdl -r --std=08 --workdir=build_bram tb_npu_seq_conv1 -gG_MUT=$m 2>&1)
  if echo "$o" | grep -q "TB_SEQ_CONV1 FAIL"; then nm=$((nm+1)); else echo "FALLO: conv1 MUT $m NO fallo"; fail=1; fi
done
echo "conv2: 5 mutaciones..."
for m in 1 2 3 4 5; do
  o=$(ghdl -r --std=08 --workdir=build_bram tb_npu_seq_full -gG_MUT=$m 2>&1)
  if echo "$o" | grep -q "TB_SEQ_FULL FAIL"; then nm=$((nm+1)); else echo "FALLO: conv2 MUT $m NO fallo"; fail=1; fi
done
echo "top: 2 mutaciones..."
for m in 1 2; do
  o=$(ghdl -r --std=08 --workdir=build_bram tb_npu_top -gG_MUT=$m -gG_NIMG=8 2>&1)
  if echo "$o" | grep -q "TB_NPU_TOP FAIL"; then nm=$((nm+1)); else echo "FALLO: top MUT $m NO fallo"; fail=1; fi
done
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO9-MUT OK MUTACIONES $nm/12 FAIL"
)
