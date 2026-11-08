#!/usr/bin/env bash
# ============================================================================
#  run_mmio.sh - Capa 2: banco de registros del IP I3C contra BFM dmem
#  audit 2026-11: FIFO = private i3c_byte_fifo.vhd (no shared byte_fifo).
#  Uso: ./run_mmio.sh   (requiere ghdl >= 4.x con --std=08)
# ============================================================================
set -e
cd "$(dirname "$0")"

rm -f work-obj08.cf

FIFO=i3c_byte_fifo.vhd

ghdl -a --std=08 "$FIFO"
ghdl -a --std=08 i3c_controller.vhd
ghdl -a --std=08 i3c_target.vhd
ghdl -a --std=08 i3c_mmio.vhd
ghdl -a --std=08 tb_i3c_mmio.vhd
ghdl -e --std=08 tb_i3c_mmio
ghdl -r --std=08 tb_i3c_mmio

# audit 2026-11: FIFO equivalence test
ghdl -a --std=08 tb_i3c_byte_fifo.vhd
ghdl -e --std=08 tb_i3c_byte_fifo
ghdl -r --std=08 tb_i3c_byte_fifo

echo "run_mmio.sh: PASS"
