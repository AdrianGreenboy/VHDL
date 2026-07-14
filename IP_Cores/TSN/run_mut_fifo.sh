#!/bin/bash
# Mutaciones obligatorias capa 1a tsn_fifo: las 5 deben FALLAR
cd "$(dirname "$0")"
ok=0
for m in 1 2 3 4 5; do
  cp tsn_fifo.vhd mut.vhd
  case $m in
    1) sed -i 's/wr_ptr <= cm_ptr;/wr_ptr <= cm_ptr + 1;/' mut.vhd; d="M1 rewind wr off-by-one";;
    2) sed -i 's/when spec_cnt_i = to_unsigned(DEPTH/when comm_cnt_i = to_unsigned(DEPTH/' mut.vhd; d="M2 full ignora especulativo";;
    3) sed -i 's/and comm_cnt_i \/= 0$/and spec_cnt_i \/= 0/' mut.vhd; d="M3 lectura ve especulativo";;
    4) perl -0777 -i -pe 's/if out_valid = .1. then\s*\n\s*rd_ptr <= rd_ptr - 1;\s*\n\s*fr_ptr <= rd_ptr - 1;/if out_valid = '"'"'1'"'"' then\n            fr_ptr <= rd_ptr;/' mut.vhd; d="M4 commit sin rollback prefetch";;
    5) perl -0777 -i -pe 's/elsif rd_rewind = .1. then\s*\n\s*rd_ptr    <= fr_ptr;\s*\n\s*out_valid <= .0.;/elsif rd_rewind = '"'"'1'"'"' then\n          rd_ptr    <= fr_ptr;/' mut.vhd; d="M5 rewind no limpia out_valid";;
  esac
  if diff -q tsn_fifo.vhd mut.vhd >/dev/null; then echo "$d: SED NO APLICO - ERROR"; continue; fi
  ghdl -a --std=08 -Wno-hide mut.vhd tb_tsn_fifo.vhd >/dev/null 2>&1
  ghdl -e --std=08 tb_tsn_fifo >/dev/null 2>&1
  if timeout 600 ghdl -r --std=08 tb_tsn_fifo >/dev/null 2>&1; then
    echo "$d: PASO (MUTACION NO DETECTADA - TB DEBIL)"
  else
    echo "$d: FALLO como debe"; ok=$((ok+1))
  fi
done
rm -f mut.vhd
ghdl -a --std=08 -Wno-hide tsn_fifo.vhd tb_tsn_fifo.vhd >/dev/null 2>&1
[ $ok -eq 5 ] && echo "MUTACIONES 5/5 OK" || { echo "MUTACIONES $ok/5"; exit 1; }
