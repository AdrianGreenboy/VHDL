#!/bin/bash
# HERCOSSNUX NPU - lanzador de la sintesis exploratoria OOC.
# Comprueba el entorno antes de invocar Vivado, que tarda varios minutos.
(
set -e
cd "$(dirname "$0")/.."
NPU_DIR="$(pwd)"

if ! command -v vivado > /dev/null 2>&1; then
  echo "FALLO: vivado no esta en el PATH."
  echo "  Carga el entorno primero, por ejemplo:"
  echo "  source /tools/Xilinx/Vivado/2025.2/settings64.sh"
  exit 1
fi

echo "Vivado: $(vivado -version 2>/dev/null | head -1)"
echo "Directorio NPU: $NPU_DIR"

for f in rtl/npu_pkg.vhd rtl/npu_array.vhd rtl/npu_seq_conv1.vhd \
         rtl/npu_seq_full.vhd rtl/npu_top.vhd; do
  if [ ! -f "$f" ]; then
    echo "FALLO: falta $f"; exit 1
  fi
done
echo "Fuentes RTL localizadas."

echo ""
echo "Lanzando sintesis out-of-context (varios minutos)..."
vivado -mode batch -source syn/npu_synth_ooc.tcl -nojournal -log syn/vivado.log

echo ""
echo "Reportes generados en syn/reportes/:"
ls -la syn/reportes/ 2>/dev/null || echo "  (ninguno: revisa syn/vivado.log)"
)
