#!/bin/bash
# HERCOSSNUX NPU - Layer 3: sondas de protocolo (previas al secuenciador)
(
set -e
cd "$(dirname "$0")"
rm -rf build_l3 && mkdir -p build_l3

# Sonda 1: el tiling de canales reproduce el oraculo (Python)
python3 sonda_l3_tiling.py oracle/oracle_npu.py model/npu_weights.hex model/npu_golden.txt

# Sonda 4: la secuencia completa reproduce clases y firma del oraculo
python3 sonda_l3_secuencia.py oracle/oracle_npu.py model/npu_weights.hex model/npu_golden.txt

# Vectores de la sonda de tile
python3 gen_l3_sonda.py oracle/oracle_npu.py model/npu_weights.hex model/npu_golden.txt vec

ghdl -a --std=08 --workdir=build_l3 \
  rtl/npu_pkg.vhd rtl/npu_requant.vhd rtl/npu_array.vhd \
  tb/tb_l3_sonda.vhd tb/tb_l3_ocio.vhd 2>&1 | grep -v "warning" || true

fail=0

# Sonda 2: sumas parciales crudas de un tile real de conv2
out=$(ghdl -r --std=08 --workdir=build_l3 tb_l3_sonda 2>&1)
if echo "$out" | grep -q "TB_L3_SONDA PASS"; then
  echo "$out" | grep -o "TB_L3_SONDA PASS.*"
else
  echo "FALLO sonda de tile: $out"; fail=1
fi

# Sonda 3: filas ociosas sin residuo entre capas
out=$(ghdl -r --std=08 --workdir=build_l3 tb_l3_ocio 2>&1)
if echo "$out" | grep -q "SONDA_OCIO PASS"; then
  echo "$out" | grep -o "SONDA_OCIO PASS.*"
else
  echo "FALLO sonda de filas ociosas: $out"; fail=1
fi

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO5 OK L3 SONDAS 4/4 PASS"
)
