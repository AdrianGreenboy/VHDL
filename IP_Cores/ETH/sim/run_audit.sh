#!/usr/bin/env bash
# Audit 2026-11 regression for the ETH MAC (GHDL 4.1, --std=08).
#   tb_eth_rx_ring  : RX max-length doom + back-to-back drain (ring buffer)
#   tb_eth_mii_cdc  : external MII with asynchronous PHY clocks (2 ppm configs)
#   tb_eth_mmio_ovf : whole-frame RX overflow drop, W1C stickies, LEVEL, flush
# Each TB is self-checking (assert severity failure) and prints "<TB> PASS".
set -u
cd "$(dirname "$0")"
W=work_audit
rm -rf $W; mkdir -p $W
O="--std=08 --workdir=$W"
ghdl -a $O ../rtl/eth_pkg.vhd ../rtl/eth_fifo.vhd ../rtl/eth_cdc_sync.vhd \
  ../rtl/eth_async_fifo.vhd ../rtl/eth_mii_cdc.vhd ../rtl/eth_tx_mii.vhd \
  ../rtl/eth_rx_mii.vhd ../rtl/eth_mac.vhd ../rtl/eth_mmio.vhd \
  ../tb/tb_eth_rx_ring.vhd ../tb/tb_eth_mii_cdc.vhd ../tb/tb_eth_mmio_ovf.vhd \
  || { echo "AUDIT: FALLO DE ANALISIS"; exit 1; }
fail=0
run () {   # $1 label, $2 tb, $3.. generics
  local lbl=$1 tb=$2; shift 2
  ghdl -e $O $tb || { echo "  FAIL $lbl (elab)"; fail=1; return; }
  if ghdl -r $O $tb "$@" > $W/$lbl.log 2>&1 && grep -q "PASS" $W/$lbl.log; then
    echo "  PASS $lbl"; grep "TS \(TX\|RX\)" $W/$lbl.log | sed 's/^.*note): /        /'
  else
    echo "  FAIL $lbl"; grep -m3 "assertion\|error" $W/$lbl.log; fail=1
  fi
}
run rx_ring  tb_eth_rx_ring
run cdc_a    tb_eth_mii_cdc -gG_TXCLK_PS=40004 -gG_RXCLK_PS=39996
run cdc_b    tb_eth_mii_cdc -gG_TXCLK_PS=39996 -gG_RXCLK_PS=40004
run cdc_c    tb_eth_mii_cdc -gG_TXCLK_PS=40000 -gG_RXCLK_PS=40001 -gG_NTX=24 -gG_NRX=24
run mmio_ovf tb_eth_mmio_ovf
if [ $fail -eq 0 ]; then echo "ETH AUDIT COMPLETA: PASS"; else echo "ETH AUDIT: FALLOS"; exit 1; fi
