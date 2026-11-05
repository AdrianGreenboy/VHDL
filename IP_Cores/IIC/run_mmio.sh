#!/usr/bin/env bash
# ============================================================================
# run_mmio.sh — Capa 2 del IP IIC: regfile MMIO con BFM dmem
# audit 2026-11: FIFO = private i2c_byte_fifo.vhd (no shared byte_fifo).
# Uso: ./run_mmio.sh   (requiere xvhdl/xelab/xsim de Vivado en el PATH)
# Éxito esperado: "== TODOS LOS TESTS PASARON (M1-M10) ==" y fin ~369 us.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

FIFO_SRC="./i2c_byte_fifo.vhd"

xvhdl --2008 "$FIFO_SRC"
xvhdl --2008 i2c_master.vhd
xvhdl --2008 i2c_slave.vhd
xvhdl --2008 i2c_mmio.vhd
xvhdl --2008 tb_i2c_mmio.vhd
xelab --debug typical tb_i2c_mmio -s i2c_mmio_sim
xsim i2c_mmio_sim --runall

# audit 2026-11: FIFO equivalence test
xvhdl --2008 i2c_byte_fifo.vhd tb_i2c_byte_fifo.vhd
xelab --debug typical tb_i2c_byte_fifo -s i2c_fifo_sim
xsim i2c_fifo_sim --runall
