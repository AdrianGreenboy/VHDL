#!/usr/bin/env bash
# Capa 1b del MAC Ethernet (TSN v1): RX MII vs transmisor bit-bang.
# MUT=0 debe PASAR; MUT=1..4 DEBEN fallar.
set -u
cd "$(dirname "$0")"
rm -rf work_l1b
mkdir -p work_l1b
ghdl -a --std=08 --workdir=work_l1b ../rtl/eth_pkg.vhd ../rtl/eth_rx_mii.vhd ../tb/tb_eth_rx_l1b.vhd || { echo "L1B: FALLO DE ANALISIS"; exit 1; }
ghdl -e --std=08 --workdir=work_l1b tb_eth_rx_l1b || { echo "L1B: FALLO DE ELABORACION"; exit 1; }
echo "--- MUT=0 (debe PASAR) ---"
ghdl -r --std=08 --workdir=work_l1b tb_eth_rx_l1b -gG_MUT=0 || { echo "L1B: MUT0 FALLO (BUG)"; exit 1; }
ok=1
for m in 1 2 3 4; do
  echo "--- MUT=$m (debe FALLAR) ---"
  if ghdl -r --std=08 --workdir=work_l1b tb_eth_rx_l1b -gG_MUT=$m > mut$m.log 2>&1; then
    echo "L1B: MUT$m NO FALLO (BUG DEL BANCO)"
    ok=0
  else
    grep -m1 "assertion failure" mut$m.log || tail -n 2 mut$m.log
    echo "L1B: MUT$m fallo como se esperaba"
  fi
done
if [ "$ok" -eq 1 ]; then
  echo "L1B COMPLETA: PASS + 4 mutaciones detectadas"
else
  exit 1
fi
