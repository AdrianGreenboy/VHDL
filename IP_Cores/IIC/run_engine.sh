#!/usr/bin/env bash
# ============================================================================
# run_engine.sh — Capa 1c del IP IIC: maestro RTL <-> esclavo RTL (wired-AND)
# Pre-validación del self-test loop_int (capa 2/5).
# Uso: ./run_engine.sh   (requiere xvhdl/xelab/xsim de Vivado en el PATH)
# Éxito esperado: "== TODOS LOS TESTS PASARON (T1-T8) ==" y fin ~738 us.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

xvhdl --2008 i2c_master.vhd
xvhdl --2008 i2c_slave.vhd
xvhdl --2008 tb_i2c_engine.vhd
xelab --debug typical tb_i2c_engine -s i2c_engine_sim
xsim i2c_engine_sim --runall
