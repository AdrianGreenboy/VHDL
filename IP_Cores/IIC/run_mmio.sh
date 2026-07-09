#!/usr/bin/env bash
# ============================================================================
# run_mmio.sh — Capa 2 del IP IIC: regfile MMIO con BFM dmem
# Fuente compartida: usa ~/spi_ip/byte_fifo.vhd si existe (origen),
# con fallback al byte_fifo.vhd local (misma entidad).
# Uso: ./run_mmio.sh   (requiere xvhdl/xelab/xsim de Vivado en el PATH)
# Éxito esperado: "== TODOS LOS TESTS PASARON (M1-M10) ==" y fin ~369 us.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

FIFO_SRC="$HOME/spi_ip/byte_fifo.vhd"
if [ ! -f "$FIFO_SRC" ]; then
  FIFO_SRC="./byte_fifo.vhd"
  echo "AVISO: usando fallback local $FIFO_SRC"
else
  echo "Usando fuente compartida $FIFO_SRC"
fi

xvhdl --2008 "$FIFO_SRC"
xvhdl --2008 i2c_master.vhd
xvhdl --2008 i2c_slave.vhd
xvhdl --2008 i2c_mmio.vhd
xvhdl --2008 tb_i2c_mmio.vhd
xelab --debug typical tb_i2c_mmio -s i2c_mmio_sim
xsim i2c_mmio_sim --runall
