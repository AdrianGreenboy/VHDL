#!/bin/bash
# HERCOSSNUX NPU - Layer 3 entrega 2: conv2 + pool2 + FC + argmax
(
set -e
cd "$(dirname "$0")"
python3 gen_l3_full.py oracle/oracle_npu.py model/npu_weights.hex model/npu_golden.txt vec 8
rm -rf build_full && mkdir -p build_full
ghdl -a --std=08 --workdir=build_full \
  rtl/npu_pkg.vhd rtl/npu_array.vhd rtl/npu_seq_full.vhd \
  tb/tb_npu_seq_full.vhd 2>&1 | grep -v "warning" || true

fail=0
out=$(ghdl -r --std=08 --workdir=build_full tb_npu_seq_full 2>&1)
if echo "$out" | grep -q "TB_SEQ_FULL PASS"; then
  echo "$out" | grep -o "TB_SEQ_FULL PASS.*"
else
  echo "FALLO base: $out"; fail=1
fi

nm=0
for m in 1 2 3 4 5; do
  o=$(ghdl -r --std=08 --workdir=build_full tb_npu_seq_full -gG_MUT=$m 2>&1)
  if echo "$o" | grep -q "TB_SEQ_FULL FAIL"; then
    nm=$((nm+1))
  else
    echo "FALLO: mutacion $m NO fallo"; fail=1
  fi
done

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO7 OK L3 SEQ_FULL PASS MUTACIONES $nm/5 FAIL"
)
