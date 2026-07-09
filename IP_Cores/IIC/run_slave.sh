#!/usr/bin/env bash
# ============================================================================
# run_slave.sh — Capa 1b del IP IIC: motor esclavo en aislamiento
# Uso: ./run_slave.sh   (requiere xvhdl/xelab/xsim de Vivado en el PATH)
# Éxito esperado: "== TODOS LOS TESTS PASARON (T1-T8) ==" y fin ~581 us.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

xvhdl --2008 i2c_slave.vhd
xvhdl --2008 tb_i2c_slave.vhd
xelab --debug typical tb_i2c_slave -s i2c_slave_sim
xsim i2c_slave_sim --runall
