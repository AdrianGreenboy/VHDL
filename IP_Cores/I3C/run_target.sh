#!/usr/bin/env bash
# ============================================================================
#  run_target.sh - Capa 1b: motor target I3C contra modelo de controller
#  Uso: ./run_target.sh   (requiere ghdl >= 4.x con --std=08)
# ============================================================================
set -e
cd "$(dirname "$0")"

rm -f work-obj08.cf

ghdl -a --std=08 i3c_target.vhd
ghdl -a --std=08 tb_i3c_target.vhd
ghdl -e --std=08 tb_i3c_target
ghdl -r --std=08 tb_i3c_target

echo "run_target.sh: PASS"
