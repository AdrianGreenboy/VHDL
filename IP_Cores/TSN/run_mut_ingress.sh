#!/bin/bash
# Mutaciones obligatorias capa 1a tsn_ingress: las 4 deben FALLAR
cd "$(dirname "$0")"
ok=0
for m in 1 2 3 4; do
  cp tsn_ingress.vhd muti.vhd
  case $m in
    1) sed -i 's/if bytecnt = 12 and/if bytecnt = 11 and/' muti.vhd; d="M1 tagged offset 11";;
    2) sed -i 's/if bytecnt < 6 then/if bytecnt < 5 then/' muti.vhd; d="M2 mac 5 bytes";;
    3) sed -i 's/fin_len   <= bytecnt + 1;/fin_len   <= bytecnt;/' muti.vhd; d="M3 len off-by-one";;
    4) sed -i 's/do_commit <= not (doomed or full);/do_commit <= not doomed;/;s/do_rewind <= doomed or full;/do_rewind <= doomed;/' muti.vhd; d="M4 full en ultimo byte";;
  esac
  if diff -q tsn_ingress.vhd muti.vhd >/dev/null; then echo "$d: SED NO APLICO - ERROR"; continue; fi
  ghdl -a --std=08 -Wno-hide tsn_fifo.vhd muti.vhd tb_tsn_ingress.vhd >/dev/null 2>&1
  ghdl -e --std=08 tb_tsn_ingress >/dev/null 2>&1
  if timeout 600 ghdl -r --std=08 tb_tsn_ingress >/dev/null 2>&1; then
    echo "$d: PASO (MUTACION NO DETECTADA - TB DEBIL)"
  else
    echo "$d: FALLO como debe"; ok=$((ok+1))
  fi
done
rm -f muti.vhd
ghdl -a --std=08 -Wno-hide tsn_fifo.vhd tsn_ingress.vhd tb_tsn_ingress.vhd >/dev/null 2>&1
[ $ok -eq 4 ] && echo "MUTACIONES 4/4 OK" || { echo "MUTACIONES $ok/4"; exit 1; }
