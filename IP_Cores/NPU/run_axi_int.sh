#!/bin/bash
# HERCOSSNUX NPU - integracion AXI completa (doorbell + DMA + registros).
# Criterio: SIG_CLASE identica a la firma congelada 0x6084FD2A, con pesos e
# imagenes llegando desde DDR por AXI en lugar de por puertos.
(
set -e
cd "$(dirname "$0")"
echo "[1/3] generando imagen de DDR..."
python3 gen_ddr_image.py oracle/oracle_npu.py model/npu_weights.hex \
        model/npu_golden.txt vec/ddr_image.txt 8 > /dev/null

echo "[2/3] analizando con cache limpia..."
rm -rf build_int && mkdir -p build_int
ghdl -a --std=08 --workdir=build_int \
  rtl/npu_pkg.vhd rtl/npu_axi_pkg.vhd rtl/npu_array.vhd \
  rtl/npu_seq_conv1.vhd rtl/npu_seq_full.vhd rtl/npu_top.vhd \
  rtl/npu_dma.vhd rtl/npu_axi_slave.vhd rtl/npu_axi_top.vhd \
  tb/axi_ddr_model.vhd tb/tb_npu_axi.vhd 2>&1 | grep -v "warning" || true

echo "[3/3] inferencia de 8 imagenes por AXI (varios minutos)..."
out=$(ghdl -r --std=08 --workdir=build_int tb_npu_axi -gG_NIMG=8 2>&1)
if echo "$out" | grep -q "errores=0" && echo "$out" | grep -q "SIG_CLASE=0x6084FD2A"; then
  echo "$out" | grep -o "TB_NPU_AXI.*"
  echo "NPU PASO14 OK INTEGRACION AXI SIG_CLASE=0x6084FD2A"
else
  echo "FALLO:"; echo "$out" | tail -8
  exit 1
fi
)
