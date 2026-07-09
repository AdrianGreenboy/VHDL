#!/usr/bin/env bash
# ============================================================================
# run_master.sh — Capa 1a del IP IIC: motor maestro en aislamiento
# Uso: ./run_master.sh   (requiere xvhdl/xelab/xsim de Vivado en el PATH)
# Éxito esperado: "== TODOS LOS TESTS PASARON (T1-T8) ==" y fin ~907 us.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

xvhdl --2008 i2c_master.vhd
xvhdl --2008 tb_i2c_master.vhd
xelab --debug typical tb_i2c_master -s i2c_master_sim
xsim i2c_master_sim --runall
