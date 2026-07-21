#!/bin/bash
# HERCOSSNUX NPU - sondas de protocolo AXI4 del motor DMA.
# Se verifica el master ANTES de conectarlo a la NPU: sin esto, un fallo de
# handshake apareceria como firma incorrecta al final de la cadena.
(
set -e
cd "$(dirname "$0")"
echo "[1/5] analizando con cache limpia..."
rm -rf build_axi && mkdir -p build_axi
ghdl -a --std=08 --workdir=build_axi \
  rtl/npu_axi_pkg.vhd rtl/npu_dma.vhd \
  tb/axi_ddr_model.vhd tb/tb_axi_sondas.vhd 2>&1 | grep -v "warning" || true

fail=0; n=0
for s in 1 2 3 4; do
  case $s in
    1) d="rafaga simple 64 B" ;;
    2) d="multi-rafaga 2560 B" ;;
    3) d="backpressure RVALID" ;;
    4) d="error SLVERR" ;;
  esac
  echo "[$((s+1))/5] sonda $s: $d..."
  o=$(ghdl -r --std=08 --workdir=build_axi tb_axi_sondas -gG_SONDA=$s 2>&1)
  if echo "$o" | grep -q "SONDA_AXI$s PASS"; then
    n=$((n+1))
  else
    echo "FALLO sonda $s:"; echo "$o" | tail -5; fail=1
  fi
done

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO12 OK SONDAS AXI $n/4 PASS"
)
