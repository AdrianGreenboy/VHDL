#!/usr/bin/env bash
# Capa 1a del MAC Ethernet (TSN v1): TX MII vs receptor independiente.
# MUT=0 debe PASAR; MUT=1..4 DEBEN fallar (mutaciones detectadas por el modelo).
set -u
cd "$(dirname "$0")"
rm -rf work_l1a
mkdir -p work_l1a
ghdl -a --std=08 --workdir=work_l1a ../rtl/eth_pkg.vhd ../rtl/eth_tx_mii.vhd ../tb/tb_eth_tx_l1a.vhd || { echo "L1A: FALLO DE ANALISIS"; exit 1; }
ghdl -e --std=08 --workdir=work_l1a tb_eth_tx_l1a || { echo "L1A: FALLO DE ELABORACION"; exit 1; }
echo "--- MUT=0 (debe PASAR) ---"
ghdl -r --std=08 --workdir=work_l1a tb_eth_tx_l1a -gG_MUT=0 || { echo "L1A: MUT0 FALLO (BUG)"; exit 1; }
ok=1
for m in 1 2 3 4; do
  echo "--- MUT=$m (debe FALLAR) ---"
  if ghdl -r --std=08 --workdir=work_l1a tb_eth_tx_l1a -gG_MUT=$m > mut$m.log 2>&1; then
    echo "L1A: MUT$m NO FALLO (BUG DEL BANCO)"
    ok=0
  else
    grep -m1 "assertion failure" mut$m.log || tail -n 2 mut$m.log
    echo "L1A: MUT$m fallo como se esperaba"
  fi
done
if [ "$ok" -eq 1 ]; then
  echo "L1A COMPLETA: PASS + 4 mutaciones detectadas"
else
  exit 1
fi
