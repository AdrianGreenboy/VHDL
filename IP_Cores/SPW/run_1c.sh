#!/bin/bash
(
  set -e
  cd "$(dirname "$0")"
  rm -f work-obj08.cf
  ghdl -a --std=08 spw_tx.vhd
  ghdl -a --std=08 spw_rx.vhd
  ghdl -a --std=08 spw_link.vhd
  ghdl -a --std=08 spw_codec.vhd
  ghdl -a --std=08 tb_spw_1c.vhd
  ghdl -e --std=08 tb_spw_1c
  ghdl -r --std=08 tb_spw_1c
)
