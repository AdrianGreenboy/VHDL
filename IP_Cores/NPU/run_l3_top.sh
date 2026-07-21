#!/bin/bash
# HERCOSSNUX NPU - Layer 3 top level: verificacion rapida (8 imagenes).
# Comprueba la cadena completa imagen -> clase y que las 2 mutaciones fallan.
# Para la verificacion de las 32 imagenes con firma global, correr despues:
#   bash run_l3_top32.sh
(
set -e
cd "$(dirname "$0")"
python3 gen_l3_top.py oracle/oracle_npu.py model/npu_weights.hex model/npu_golden.txt vec
rm -rf build_top && mkdir -p build_top
echo "[1/4] analizando..."
ghdl -a --std=08 --workdir=build_top \
  rtl/npu_pkg.vhd rtl/npu_array.vhd rtl/npu_seq_conv1.vhd \
  rtl/npu_seq_full.vhd rtl/npu_top.vhd tb/tb_npu_top.vhd 2>&1 | grep -v "warning" || true

fail=0
echo "[2/4] base con 8 imagenes (~1-2 min)..."
out=$(ghdl -r --std=08 --workdir=build_top tb_npu_top -gG_NIMG=8 2>&1)
if echo "$out" | grep -q "TB_NPU_TOP PASS"; then
  echo "$out" | grep -o "TB_NPU_TOP PASS.*"
else
  echo "FALLO base: $out"; fail=1
fi

nm=0
echo "[3/4] mutacion 1..."
o=$(ghdl -r --std=08 --workdir=build_top tb_npu_top -gG_MUT=1 -gG_NIMG=8 2>&1)
if echo "$o" | grep -q "TB_NPU_TOP FAIL"; then nm=$((nm+1)); else echo "FALLO: mutacion 1 NO fallo"; fail=1; fi

echo "[4/4] mutacion 2..."
o=$(ghdl -r --std=08 --workdir=build_top tb_npu_top -gG_MUT=2 -gG_NIMG=8 2>&1)
if echo "$o" | grep -q "TB_NPU_TOP FAIL"; then nm=$((nm+1)); else echo "FALLO: mutacion 2 NO fallo"; fail=1; fi

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO8 OK L3 TOP PASS MUTACIONES $nm/2 FAIL"
echo "Para las 32 imagenes con firma global: bash run_l3_top32.sh"
)
