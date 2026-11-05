#!/usr/bin/env bash
# Capa 2 del MAC Ethernet (TSN v1): banco MMIO vs BFM del dmem.
# Audit 2026-11: the MMIO FIFOs are the local synchronous-read eth_fifo
# (no external ~/spw_ip dependency any more). MUT=0 PASA; 1..4 fallan.
set -u
cd "$(dirname "$0")"
rm -rf work_l2
mkdir -p work_l2
ghdl -a --std=08 --workdir=work_l2 ../rtl/eth_pkg.vhd ../rtl/eth_fifo.vhd ../rtl/eth_cdc_sync.vhd ../rtl/eth_async_fifo.vhd ../rtl/eth_mii_cdc.vhd ../rtl/eth_tx_mii.vhd ../rtl/eth_rx_mii.vhd ../rtl/eth_mac.vhd ../rtl/eth_mmio.vhd ../tb/tb_eth_mmio_l2.vhd || { echo "L2: FALLO DE ANALISIS"; exit 1; }
ghdl -e --std=08 --workdir=work_l2 tb_eth_mmio_l2 || { echo "L2: FALLO DE ELABORACION"; exit 1; }
echo "--- MUT=0 (debe PASAR) ---"
ghdl -r --std=08 --workdir=work_l2 tb_eth_mmio_l2 -gG_MUT=0 || { echo "L2: MUT0 FALLO (BUG)"; exit 1; }
ok=1
for m in 1 2 3 4; do
  echo "--- MUT=$m (debe FALLAR) ---"
  if ghdl -r --std=08 --workdir=work_l2 tb_eth_mmio_l2 -gG_MUT=$m > mut$m.log 2>&1; then
    echo "L2: MUT$m NO FALLO (BUG DEL BANCO)"
    ok=0
  else
    grep -m1 "assertion failure" mut$m.log || tail -n 2 mut$m.log
    echo "L2: MUT$m fallo como se esperaba"
  fi
done
if [ "$ok" -eq 1 ]; then
  echo "L2 COMPLETA: PASS + 4 mutaciones detectadas"
else
  exit 1
fi
