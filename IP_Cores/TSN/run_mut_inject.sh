#!/bin/bash
# Mutaciones capa 1a tsn_inject: las 5 deben FALLAR (criterio: no imprime PASS)
cd "$(dirname "$0")"
ok=0
for m in 1 2 3 4 5; do
  cp tsn_inject.vhd mutj.vhd
  case $m in
    1) sed -i 's/if pre_cnt = 14 then/if pre_cnt = 13 then/' mutj.vhd; d="M1 preambulo corto";;
    2) sed -i 's/rxd_r <= cur(3 downto 0); dv_r/rxd_r <= cur(7 downto 4); dv_r/' mutj.vhd; d="M2 nibbles intercambiados";;
    3) sed -i 's/if byte_i = len_r - 1 then/if byte_i = len_r then/' mutj.vhd; d="M3 un byte de mas";;
    4) sed -i 's/xor x"EDB88320"/xor x"04C11DB7"/' mutj.vhd; d="M4 poly CRC mal";;
    5) sed -i 's/if fcs_nib = 7 then/if fcs_nib = 6 then/' mutj.vhd; d="M5 FCS de 7 nibbles";;
  esac
  if diff -q tsn_inject.vhd mutj.vhd >/dev/null; then echo "$d: SED NO APLICO - ERROR"; continue; fi
  ghdl -a --std=08 -Wno-hide eth_pkg.vhd eth_rx_mii.vhd mutj.vhd tb_tsn_inject.vhd >/dev/null 2>&1
  ghdl -e --std=08 tb_tsn_inject >/dev/null 2>&1
  out=$(ghdl -r --std=08 tb_tsn_inject --stop-time=1ms 2>&1)
  if echo "$out" | grep -q "TB_TSN_INJECT PASS"; then
    echo "$d: PASO (MUTACION NO DETECTADA - TB DEBIL)"
  else
    echo "$d: FALLO como debe"; ok=$((ok+1))
  fi
done
rm -f mutj.vhd
ghdl -a --std=08 -Wno-hide tsn_inject.vhd tb_tsn_inject.vhd >/dev/null 2>&1
[ $ok -eq 5 ] && echo "MUTACIONES 5/5 OK" || { echo "MUTACIONES $ok/5"; exit 1; }
