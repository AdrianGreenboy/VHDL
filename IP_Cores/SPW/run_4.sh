#!/bin/bash
# Layer 4 (audit 2026-11): codec A <-> codec B at 400 Mbit/s, TX on tx_clk
# (spw_tx_cdc), recovered-clock RX, four asynchronous clocks.
(
  set -e
  cd "$(dirname "$0")"
  rm -f work-obj08.cf
  ghdl -a --std=08 spw_tx.vhd spw_tx_cdc.vhd spw_rx.vhd spw_rx_dsr.vhd
  ghdl -a --std=08 spw_link.vhd spw_codec.vhd tb_spw_4.vhd
  ghdl -e --std=08 tb_spw_4
  ghdl -r --std=08 tb_spw_4
)
