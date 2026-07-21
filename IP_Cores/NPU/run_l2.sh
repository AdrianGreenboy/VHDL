#!/bin/bash
# HERCOSSNUX NPU - Layer 2: array sistolico 8x8 (doble estimulo)
(
set -e
cd "$(dirname "$0")"
rm -rf build_l2 && mkdir -p build_l2
ghdl -a --std=08 --workdir=build_l2 \
  rtl/npu_pkg.vhd rtl/npu_mac.vhd rtl/npu_requant.vhd rtl/npu_pool.vhd \
  rtl/npu_pe.vhd rtl/npu_array.vhd tb/tb_npu_array.vhd 2>&1 | grep -v "warning" || true

fail=0
out=$(ghdl -r --std=08 --workdir=build_l2 tb_npu_array 2>&1)
if echo "$out" | grep -q "TB_ARRAY PASS"; then
  echo "$out" | grep -o "TB_ARRAY PASS.*"
else
  echo "FALLO base array: $out"; fail=1
fi

nm=0
for m in 1 2 3 4; do
  o=$(ghdl -r --std=08 --workdir=build_l2 tb_npu_array -gG_MUT=$m 2>&1)
  if echo "$o" | grep -q "TB_ARRAY FAIL"; then
    nm=$((nm+1))
  else
    echo "FALLO: mutacion $m del array NO fallo"; fail=1
  fi
done

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO3 OK L2 ARRAY PASS MUTACIONES $nm/4 FAIL"
)
