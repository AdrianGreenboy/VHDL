#!/usr/bin/env bash
set -u
(
  cd "$(dirname "$0")" || exit 1
  rm -f work-obj08.cf
  ghdl -a --std=08 byte_fifo.vhd can_engine.vhd can_mmio.vhd tb_can_mmio.vhd || exit 1
  ghdl -e --std=08 tb_can_mmio || exit 1
  ghdl -r --std=08 tb_can_mmio
)
