#!/bin/bash
# HERCOSSNUX NPU - sondas del esclavo AXI4 full de registros.
(
set -e
cd "$(dirname "$0")"
echo "[1/6] analizando con cache limpia..."
rm -rf build_slv && mkdir -p build_slv
ghdl -a --std=08 --workdir=build_slv \
  rtl/npu_axi_pkg.vhd rtl/npu_axi_slave.vhd tb/tb_axi_slave.vhd \
  2>&1 | grep -v "warning" || true

fail=0; n=0
for s in 1 2 3 4 5; do
  case $s in
    1) d="lectura de ID y BASE, RID y RLAST" ;;
    2) d="escritura de BASE con WSTRB parcial" ;;
    3) d="rafaga INCR de 4 palabras con ID" ;;
    4) d="direccion no mapeada, SLVERR" ;;
    5) d="rafaga FIXED, direccion no avanza" ;;
  esac
  echo "[$((s+1))/6] sonda $s: $d..."
  o=$(ghdl -r --std=08 --workdir=build_slv tb_axi_slave -gG_SONDA=$s 2>&1)
  if echo "$o" | grep -q "SONDA_SLV$s PASS"; then
    n=$((n+1))
  else
    echo "FALLO sonda $s:"; echo "$o" | tail -5; fail=1
  fi
done

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO13 OK SONDAS SLAVE AXI $n/5 PASS"
)
