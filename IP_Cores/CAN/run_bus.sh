#!/usr/bin/env bash
set -u
(
  cd "$(dirname "$0")" || exit 1
  rm -f work-obj08.cf
  ghdl -a --std=08 can_engine.vhd tb_can_bus.vhd || exit 1
  ghdl -e --std=08 tb_can_bus || exit 1
  ghdl -r --std=08 tb_can_bus
)
