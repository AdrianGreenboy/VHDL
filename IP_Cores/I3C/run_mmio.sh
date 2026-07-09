#!/usr/bin/env bash
# ============================================================================
#  run_mmio.sh - Capa 2: banco de registros del IP I3C contra BFM dmem
#  Prioriza el byte_fifo original de ~/spi_ip; usa el fallback local si no.
#  Uso: ./run_mmio.sh   (requiere ghdl >= 4.x con --std=08)
# ============================================================================
set -e
cd "$(dirname "$0")"

rm -f work-obj08.cf

FIFO=byte_fifo.vhd
if [ -f "$HOME/spi_ip/byte_fifo.vhd" ]; then
  FIFO="$HOME/spi_ip/byte_fifo.vhd"
fi
echo "usando FIFO: $FIFO"

ghdl -a --std=08 "$FIFO"
ghdl -a --std=08 i3c_controller.vhd
ghdl -a --std=08 i3c_target.vhd
ghdl -a --std=08 i3c_mmio.vhd
ghdl -a --std=08 tb_i3c_mmio.vhd
ghdl -e --std=08 tb_i3c_mmio
ghdl -r --std=08 tb_i3c_mmio

echo "run_mmio.sh: PASS"
