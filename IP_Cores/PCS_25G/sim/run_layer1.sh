#!/usr/bin/env bash
#==============================================================================
# Core 19 - Layer 1 (banco de registros AXI-Lite)
# Regenera el testbench desde el oraculo, analiza y ejecuta en GHDL.
#
# Regla dura aplicada: cache GHDL limpio en cada corrida (work-obj08.cf viejo
# deja entidades rancias en la libreria).
#
# Debe imprimir: LAYER1_PASS FNV32=0xD49A4DB4
#==============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CORE="$(cd "${HERE}/.." && pwd)"
RTL="${CORE}/rtl"
ORACLE="${CORE}/oracle"
WORK="${HERE}/work"

echo "== Core 19 Layer 1 =="

# 1. Firma golden del oraculo
GOLDEN=$(cd "${ORACLE}" && python3 pcs_regbank_oracle.py | grep -oE "0x[0-9A-F]+")
echo "[oraculo] firma golden = ${GOLDEN}"

# 2. Regenerar testbench desde el oraculo (fuente unica de verdad)
(cd "${ORACLE}" && python3 gen_tb.py > "${RTL}/tb_pcs_regbank.vhd")
echo "[gen_tb] testbench regenerado"

# 3. Cache limpio + analisis en un solo comando
rm -rf "${WORK}" && mkdir -p "${WORK}"
ghdl -a --std=08 --workdir="${WORK}" "${RTL}/pcs_regbank.vhd" "${RTL}/tb_pcs_regbank.vhd"
echo "[ghdl] analisis OK"

# 4. Ejecutar (mcode backend: ghdl -r, sin -e)
echo "[ghdl] simulando..."
RESULT=$(ghdl -r --std=08 --workdir="${WORK}" tb_pcs_regbank --stop-time=5ms 2>&1 \
         | grep -E "LAYER1_PASS|LAYER1_FAIL" || true)
echo "${RESULT}"

if echo "${RESULT}" | grep -q "LAYER1_PASS"; then
  echo "RESULTADO: PASS"
  exit 0
else
  echo "RESULTADO: FAIL"
  exit 1
fi
