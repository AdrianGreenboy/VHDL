#!/usr/bin/env bash
# ============================================================================
#  run_engine.sh - Capa 1c: controller RTL <-> target RTL en bus resuelto
#  Uso: ./run_engine.sh   (requiere ghdl >= 4.x con --std=08)
# ============================================================================
set -e
cd "$(dirname "$0")"

rm -f work-obj08.cf

ghdl -a --std=08 i3c_controller.vhd
ghdl -a --std=08 i3c_target.vhd
ghdl -a --std=08 tb_i3c_engine.vhd
ghdl -e --std=08 tb_i3c_engine
ghdl -r --std=08 tb_i3c_engine

echo "run_engine.sh: PASS"
