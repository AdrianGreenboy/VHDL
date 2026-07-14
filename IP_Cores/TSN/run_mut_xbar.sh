#!/bin/bash
# Mutaciones obligatorias del tsn_xbar: las 6 deben FALLAR
cd "$(dirname "$0")"
ok=0
for m in 1 2 3 4 5 6; do
  cp tsn_xbar.vhd mutx.vhd
  case $m in
    1) sed -i 's/if desc_mac(k)(40) = .1. then/if desc_mac(k)(41) = '"'"'1'"'"' then/' mutx.vhd; d="M1 bit I-G en 41";;
    2) sed -i 's/vd := not onehot(k);         -- miss: flooding/vd := (others => '"'"'1'"'"');  -- miss: flooding/' mutx.vhd; d="M2 flooding incluye ingreso";;
    3) sed -i 's/if (dests(i) and not onehot(o)) = "0000" then/if true then/' mutx.vhd; d="M3 multicast sin rewind";;
    4) perl -0777 -i -pe 's/if icnt\(i\) = ilen\(i\) - 1 then\n            tx_last/if icnt(i) = ilen(i) - 2 then\n            tx_last/' mutx.vhd; d="M4 tx_last adelantado";;
    5) sed -i 's/if t_vld(j) = .1. and t_mac(j) = desc_mac(k) then/if t_mac(j) = desc_mac(k) then/' mutx.vhd; d="M5 lookup ignora valid";;
    6) sed -i 's/rr(o)    <= (i + 1) mod 4;/rr(o)    <= 0;/' mutx.vhd; d="M6 rr fijo (prioridad)";;
  esac
  if diff -q tsn_xbar.vhd mutx.vhd >/dev/null; then echo "$d: SED NO APLICO - ERROR"; continue; fi
  ghdl -a --std=08 -Wno-hide tsn_pkg.vhd tsn_fifo.vhd tsn_ingress.vhd mutx.vhd tb_tsn_xbar.vhd >/dev/null 2>&1
  ghdl -e --std=08 tb_tsn_xbar >/dev/null 2>&1
  if timeout 900 ghdl -r --std=08 tb_tsn_xbar >/dev/null 2>&1; then
    echo "$d: PASO (MUTACION NO DETECTADA - TB DEBIL)"
  else
    echo "$d: FALLO como debe"; ok=$((ok+1))
  fi
done
rm -f mutx.vhd
ghdl -a --std=08 -Wno-hide tsn_pkg.vhd tsn_fifo.vhd tsn_ingress.vhd tsn_xbar.vhd tb_tsn_xbar.vhd >/dev/null 2>&1
[ $ok -eq 6 ] && echo "MUTACIONES 6/6 OK" || { echo "MUTACIONES $ok/6"; exit 1; }
