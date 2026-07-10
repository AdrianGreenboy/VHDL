#!/usr/bin/env bash
# Capa 1c del MAC Ethernet (TSN v1): MAC completo en LOOP_INT full-duplex.
# MUT=0 debe PASAR; MUT=1..4 DEBEN fallar.
set -u
cd "$(dirname "$0")"
rm -rf work_l1c
mkdir -p work_l1c
ghdl -a --std=08 --workdir=work_l1c ../rtl/eth_pkg.vhd ../rtl/eth_tx_mii.vhd ../rtl/eth_rx_mii.vhd ../rtl/eth_mac.vhd ../tb/tb_eth_mac_l1c.vhd || { echo "L1C: FALLO DE ANALISIS"; exit 1; }
ghdl -e --std=08 --workdir=work_l1c tb_eth_mac_l1c || { echo "L1C: FALLO DE ELABORACION"; exit 1; }
echo "--- MUT=0 (debe PASAR) ---"
ghdl -r --std=08 --workdir=work_l1c tb_eth_mac_l1c -gG_MUT=0 || { echo "L1C: MUT0 FALLO (BUG)"; exit 1; }
ok=1
for m in 1 2 3 4; do
  echo "--- MUT=$m (debe FALLAR) ---"
  if ghdl -r --std=08 --workdir=work_l1c tb_eth_mac_l1c -gG_MUT=$m > mut$m.log 2>&1; then
    echo "L1C: MUT$m NO FALLO (BUG DEL BANCO)"
    ok=0
  else
    grep -m1 "assertion failure" mut$m.log || tail -n 2 mut$m.log
    echo "L1C: MUT$m fallo como se esperaba"
  fi
done
if [ "$ok" -eq 1 ]; then
  echo "L1C COMPLETA: PASS + 4 mutaciones detectadas"
else
  exit 1
fi
