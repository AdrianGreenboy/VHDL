#!/bin/bash
# HERCOSSNUX NPU - verificacion funcional tras los arreglos de timing.
# Criterio: las firmas congeladas NO cambian.
(
set -e
cd "$(dirname "$0")"
echo "[1/3] analizando con cache limpia..."
rm -rf build_tim && mkdir -p build_tim
ghdl -a --std=08 --workdir=build_tim \
  rtl/npu_pkg.vhd rtl/npu_array.vhd rtl/npu_seq_conv1.vhd \
  rtl/npu_seq_full.vhd rtl/npu_top.vhd \
  tb/tb_npu_seq_full.vhd tb/tb_npu_top.vhd 2>&1 | grep -v "warning" || true

fail=0
echo "[2/3] conv2+pool2+FC+argmax..."
out=$(ghdl -r --std=08 --workdir=build_tim tb_npu_seq_full 2>&1)
if echo "$out" | grep -q "SIG_POOL2=0xA87E298C"; then
  echo "$out" | grep -o "TB_SEQ_FULL PASS.*"
else
  echo "FALLO: $out" | tail -5; fail=1
fi

echo "[3/3] top level..."
out=$(ghdl -r --std=08 --workdir=build_tim tb_npu_top -gG_NIMG=8 2>&1)
if echo "$out" | grep -q "TB_NPU_TOP PASS"; then
  echo "$out" | grep -o "TB_NPU_TOP PASS.*"
else
  echo "FALLO: $out" | tail -5; fail=1
fi

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO11 OK TIMING FIRMAS INVARIANTES"
echo ""
echo "Mutaciones:  bash run_timing_mut.sh"
echo "Resintetiza: bash syn/run_synth.sh"
)
