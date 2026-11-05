#!/bin/bash
# Layer 3 (audit 2026-11): recovered-clock RX (spw_rx_dsr) vs an independent
# Data-Strobe transmitter model at up to 400 Mbit/s with jitter and D/S skew.
(
  set -e
  cd "$(dirname "$0")"
  rm -f work-obj08.cf
  ghdl -a --std=08 spw_rx_dsr.vhd
  ghdl -a --std=08 tb_spw_3.vhd
  ghdl -e --std=08 tb_spw_3
  ghdl -r --std=08 tb_spw_3
)
