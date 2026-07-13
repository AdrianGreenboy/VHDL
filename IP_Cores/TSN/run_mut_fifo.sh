#!/bin/bash
# Mutaciones obligatorias capa 1a tsn_fifo: las 3 deben FALLAR
cd "$(dirname "$0")"
ok=0
for m in 1 2 3; do
  cp tsn_fifo.vhd mut.vhd
  case $m in
    1) sed -i 's/wr_ptr <= cm_ptr;/wr_ptr <= cm_ptr + 1;/' mut.vhd; d="M1 rewind off-by-one";;
    2) sed -i 's/when spec_cnt_i = to_unsigned(DEPTH/when comm_cnt_i = to_unsigned(DEPTH/' mut.vhd; d="M2 full ignora especulativo";;
    3) sed -i 's/and comm_cnt_i \/= 0/and spec_cnt_i \/= 0/' mut.vhd; d="M3 lectura ve especulativo";;
  esac
  if diff -q tsn_fifo.vhd mut.vhd >/dev/null; then echo "$d: SED NO APLICO - ERROR"; continue; fi
  ghdl -a --std=08 -Wno-hide mut.vhd tb_tsn_fifo.vhd >/dev/null 2>&1
  ghdl -e --std=08 tb_tsn_fifo >/dev/null 2>&1
  if ghdl -r --std=08 tb_tsn_fifo >/dev/null 2>&1; then
    echo "$d: PASO (MUTACION NO DETECTADA - TB DEBIL)"
  else
    echo "$d: FALLO como debe"; ok=$((ok+1))
  fi
done
rm -f mut.vhd
# restaurar analisis limpio
ghdl -a --std=08 -Wno-hide tsn_fifo.vhd tb_tsn_fifo.vhd >/dev/null 2>&1
[ $ok -eq 3 ] && echo "MUTACIONES 3/3 OK" || { echo "MUTACIONES $ok/3 - NO COMMITEAR"; exit 1; }
