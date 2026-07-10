#!/usr/bin/env bash
# Capa 4 del MAC Ethernet (TSN v1): SoC con decode real + eth_mmio + DMA.
# Requiere fuentes de ~/rv32i (riscv_pkg, dp_ram, dma_burst) y ~/spw_ip (spw_fifo).
# Genera primero la firma del ISS y luego la compara en el testbench.
set -u
cd "$(dirname "$0")"

RV="$HOME/rv32i"
FIFO="$HOME/spw_ip/spw_fifo.vhd"
[ -f "$FIFO" ] || FIFO="../rtl/spw_fifo.vhd"

# 1) firma de referencia del ISS
python3 iss_eth.py || { echo "L4: fallo el ISS"; exit 1; }

# 2) compilar y simular
rm -rf work_l4
mkdir -p work_l4

ORDER="$RV/riscv_pkg.vhd $RV/dp_ram.vhd $RV/dma_burst.vhd \
  $FIFO ../rtl/eth_pkg.vhd ../rtl/eth_tx_mii.vhd ../rtl/eth_rx_mii.vhd \
  ../rtl/eth_mac.vhd ../rtl/eth_mmio.vhd ../rtl/mem_subsys_eth.vhd ../tb/tb_eth_l4.vhd"

ghdl -a --std=08 --workdir=work_l4 $ORDER || { echo "L4: FALLO DE ANALISIS"; exit 1; }
ghdl -e --std=08 --workdir=work_l4 tb_eth_l4 || { echo "L4: FALLO DE ELABORACION"; exit 1; }
ghdl -r --std=08 --workdir=work_l4 tb_eth_l4 || { echo "L4: FALLO EN SIMULACION"; exit 1; }
echo "L4 COMPLETA"
