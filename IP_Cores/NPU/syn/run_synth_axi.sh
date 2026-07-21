#!/bin/bash
# HERCOSSNUX NPU - lanzador de la sintesis OOC de npu_axi_top.
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

for f in rtl/npu_pkg.vhd rtl/npu_axi_pkg.vhd rtl/npu_array.vhd \
         rtl/npu_seq_conv1.vhd rtl/npu_seq_full.vhd rtl/npu_top.vhd \
         rtl/npu_dma.vhd rtl/npu_axi_slave.vhd rtl/npu_axi_top.vhd; do
  if [ ! -f "$f" ]; then
    echo "FALLO: falta $f"; exit 1
  fi
done
echo "Fuentes RTL localizadas."

echo ""
echo "Lanzando sintesis OOC de npu_axi_top (varios minutos)..."
vivado -mode batch -source syn/npu_synth_axi.tcl -nojournal -log syn/vivado_axi.log

echo ""
echo "Reportes en syn/reportes_axi/:"
ls -la syn/reportes_axi/ 2>/dev/null || echo "  (ninguno: revisa syn/vivado_axi.log)"
)
