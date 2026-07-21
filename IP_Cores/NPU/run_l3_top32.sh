#!/bin/bash
# HERCOSSNUX NPU - Layer 3 top level: inferencia completa de 32 imagenes.
# Tarda varios minutos. Criterio: 32/32 clases y firmas globales.
(
set -e
cd "$(dirname "$0")"
if [ ! -d build_top ]; then
  echo "FALLO: corre primero run_l3_top.sh"; exit 1
fi
echo "Simulando 32 imagenes (varios minutos, sin salida hasta el final)..."
out=$(ghdl -r --std=08 --workdir=build_top tb_npu_top 2>&1)
if echo "$out" | grep -q "TB_NPU_TOP PASS"; then
  echo "$out" | grep -o "TB_NPU_TOP PASS.*"
  echo "NPU PASO8-32 OK L3 TOP 32/32 CLASES"
else
  echo "FALLO: $out"; exit 1
fi
)
