#!/usr/bin/env bash
# ============================================================================
#  run_controller.sh - Capa 1a: motor controller I3C contra modelo de target
#  Uso: ./run_controller.sh   (requiere ghdl >= 4.x con --std=08)
# ============================================================================
set -e
cd "$(dirname "$0")"

rm -f work-obj08.cf

ghdl -a --std=08 i3c_controller.vhd
ghdl -a --std=08 tb_i3c_controller.vhd
ghdl -e --std=08 tb_i3c_controller
ghdl -r --std=08 tb_i3c_controller

echo "run_controller.sh: PASS"
