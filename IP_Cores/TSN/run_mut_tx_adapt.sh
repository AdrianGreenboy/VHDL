#!/bin/bash
# Mutaciones OBSERVABLES del tsn_tx_adapt: las 5 deben FALLAR.
# Criterio de FALLO = la simulacion NO imprime "TB_TSN_TX_ADAPT PASS".
# Se usa --stop-time para que una mutacion que cuelga (p.ej. mii_last=0, la
# trama nunca termina) se corte por dentro en vez de colgar el shell; en ese
# caso GHDL sale con codigo 0 pero SIN PASS, luego cuenta como detectada.
cd "$(dirname "$0")"
ok=0
for m in 1 2 3 4 5; do
  cp tsn_tx_adapt.vhd muta.vhd
  case $m in
    1) sed -i "s/hold_data <= xbar_data;/hold_data <= std_logic_vector(unsigned(xbar_data) + 1);/" muta.vhd; d="M1 corrompe dato en skid";;
    2) sed -i "s/hold_last <= xbar_last;/hold_last <= '0';/" muta.vhd; d="M2 pierde last";;
    3) sed -i "s/xbar_ready <= '1' when hold = '0' or (armed = '1' and mii_ready = '1')/xbar_ready <= '1' when hold = '0'/" muta.vhd; d="M3 ready ignora vaciado";;
    4) sed -i "s/if hold = '1' and armed = '1' and mii_ready = '1' then/if hold = '1' and armed = '1' then/" muta.vhd; d="M4 consume sin mii_ready";;
    5) sed -i "s/mii_last  <= hold_last;/mii_last  <= '0';/" muta.vhd; d="M5 mii_last atado a 0";;
  esac
  if diff -q tsn_tx_adapt.vhd muta.vhd >/dev/null; then echo "$d: SED NO APLICO - ERROR"; continue; fi
  ghdl -a --std=08 -Wno-hide eth_pkg.vhd eth_rx_mii.vhd eth_tx_mii.vhd muta.vhd tb_tsn_tx_adapt.vhd >/dev/null 2>&1
  ghdl -e --std=08 tb_tsn_tx_adapt >/dev/null 2>&1
  out=$(ghdl -r --std=08 tb_tsn_tx_adapt --stop-time=200us 2>&1)
  if echo "$out" | grep -q "TB_TSN_TX_ADAPT PASS"; then
    echo "$d: PASO (MUTACION NO DETECTADA - TB DEBIL)"
  else
    echo "$d: FALLO como debe"; ok=$((ok+1))
  fi
done
rm -f muta.vhd
ghdl -a --std=08 -Wno-hide tsn_tx_adapt.vhd tb_tsn_tx_adapt.vhd >/dev/null 2>&1
[ $ok -eq 5 ] && echo "MUTACIONES 5/5 OK" || { echo "MUTACIONES $ok/5"; exit 1; }
