#!/usr/bin/env bash
# run_regression.sh - full GHDL regression of the TSN switch (audit 2026-11).
# The shared MII sources are taken from ../ETH/rtl (never copied here):
#   eth_pkg, eth_cdc_sync, eth_async_fifo, eth_mii_cdc, eth_rx_mii, eth_tx_mii
# Each TB is self-checking (assert severity failure) and prints "<TB> PASS".
# Usage: ./run_regression.sh            (from any directory)
set -u
cd "$(dirname "$0")"
E=../ETH/rtl
W=work_reg
rm -rf $W; mkdir -p $W
O="--std=08 -Wno-hide --workdir=$W"
RTL="tsn_pkg.vhd $E/eth_pkg.vhd $E/eth_cdc_sync.vhd $E/eth_async_fifo.vhd \
  $E/eth_mii_cdc.vhd $E/eth_rx_mii.vhd $E/eth_tx_mii.vhd tsn_fifo.vhd \
  tsn_ingress.vhd tsn_xbar.vhd tsn_tx_adapt.vhd tsn_inject.vhd tsn_regs.vhd \
  tsn_top.vhd tsn_soc.vhd"
ghdl -a $O $RTL || { echo "TSN: FALLO DE ANALISIS"; exit 1; }
fail=0
for tb in tb_tsn_fifo tb_tsn_ingress tb_tsn_xbar tb_tsn_tx_adapt tb_tsn_inject \
          tb_tsn_regs tb_mii_bridge tb_tsn_top_l1c tb_tsn_soc \
          tb_tsn_ext tb_tsn_inject_err; do
  if ! { ghdl -a $O $tb.vhd && ghdl -e $O $tb; } > $W/$tb.build.log 2>&1; then
    echo "  FAIL $tb (build)"; tail -3 $W/$tb.build.log; fail=1; continue
  fi
  timeout 1800 ghdl -r $O $tb --stop-time=20ms > $W/$tb.log 2>&1
  if grep -q "PASS" $W/$tb.log && ! grep -q "assertion failure\|(assertion error)" $W/$tb.log; then
    echo "  PASS $tb"
  else
    echo "  FAIL $tb"; grep -m3 "assertion\|error" $W/$tb.log; fail=1
  fi
done
# SoC glue (needs the RV32 sources, read-only from ../RV32i): analysis + TB
RV=../RV32i
if [ -f $RV/riscv_pkg.vhd ]; then
  if ghdl -a $O $RV/riscv_pkg.vhd $RV/dp_ram.vhd $RV/dma_burst.vhd mem_subsys_dma.vhd \
       tb_mem_subsys_dma.vhd > $W/msd.log 2>&1 && ghdl -e $O tb_mem_subsys_dma >> $W/msd.log 2>&1 \
     && ghdl -r $O tb_mem_subsys_dma --stop-time=1ms > $W/msd_run.log 2>&1 \
     && grep -q "PASS" $W/msd_run.log; then
    echo "  PASS tb_mem_subsys_dma"
  else
    echo "  FAIL tb_mem_subsys_dma"; grep -m3 "assertion\|error" $W/msd.log $W/msd_run.log; fail=1
  fi
else
  echo "  OMITIDO tb_mem_subsys_dma (../RV32i no disponible)"
fi
if [ $fail -eq 0 ]; then echo "TSN REGRESION: TODAS PASAN"; else echo "TSN REGRESION: FALLOS"; exit 1; fi
