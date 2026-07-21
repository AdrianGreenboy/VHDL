#!/bin/bash
# HERCOSSNUX NPU - verificacion de la reestructuracion para BRAM.
# Criterio: las firmas congeladas NO cambian tras eliminar las lecturas
# simultaneas de las memorias de pesos.
(
set -e
cd "$(dirname "$0")"

echo "[1/5] regenerando vectores..."
python3 gen_l3_conv1.py oracle/oracle_npu.py model/npu_weights.hex model/npu_golden.txt vec 8 > /dev/null
python3 gen_l3_full.py  oracle/oracle_npu.py model/npu_weights.hex model/npu_golden.txt vec 8 > /dev/null

rm -rf build_bram && mkdir -p build_bram
echo "[2/5] analizando..."
ghdl -a --std=08 --workdir=build_bram \
  rtl/npu_pkg.vhd rtl/npu_array.vhd rtl/npu_seq_conv1.vhd \
  rtl/npu_seq_full.vhd rtl/npu_top.vhd \
  tb/tb_npu_seq_conv1.vhd tb/tb_npu_seq_full.vhd tb/tb_npu_top.vhd 2>&1 | grep -v "warning" || true

fail=0

echo "[3/5] conv1+pool1 (firma 0xE4C64381)..."
out=$(ghdl -r --std=08 --workdir=build_bram tb_npu_seq_conv1 2>&1)
if echo "$out" | grep -q "SIG=0xE4C64381"; then
  echo "$out" | grep -o "TB_SEQ_CONV1 PASS.*"
else
  echo "FALLO conv1: $out"; fail=1
fi

echo "[4/5] conv2+pool2+FC+argmax (firmas del Paso 7)..."
out=$(ghdl -r --std=08 --workdir=build_bram tb_npu_seq_full 2>&1)
if echo "$out" | grep -q "SIG_POOL2=0xA87E298C"; then
  echo "$out" | grep -o "TB_SEQ_FULL PASS.*"
else
  echo "FALLO conv2: $out"; fail=1
fi

echo "[5/5] top level 8 imagenes..."
out=$(ghdl -r --std=08 --workdir=build_bram tb_npu_top -gG_NIMG=8 2>&1)
if echo "$out" | grep -q "TB_NPU_TOP PASS"; then
  echo "$out" | grep -o "TB_NPU_TOP PASS.*"
else
  echo "FALLO top: $out"; fail=1
fi

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "NPU PASO9 OK BRAM FIRMAS INVARIANTES"
echo "Mutaciones:      bash run_bram_mut.sh   (varios minutos)"
echo "32 imagenes:     bash run_l3_top32.sh   (~5 min)"
)
