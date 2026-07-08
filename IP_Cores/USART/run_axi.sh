#!/bin/bash
# run_axi.sh -- MMUSART layer 3: IP completo (mmio v1.1 + dma) vs axi_ddr_sim.
# Fuentes compartidas: riscv_pkg + axi_ddr_sim de ~/rv32i/, byte_fifo de
# ~/spi_ip/ (mismo patron de run_xsim.sh). Copias locales como fallback.
set -e

if ! command -v xvhdl >/dev/null 2>&1; then
  source ~/Xilinx/2025.2.1/Vivado/settings64.sh
fi

pick() {
  for f in "$@"; do
    [ -f "$f" ] && { echo "$f"; return 0; }
  done
  echo "ERROR: no se encontro ninguno de: $*" >&2
  exit 1
}

PKG=$(pick ~/rv32i/riscv_pkg.vhd ./riscv_pkg.vhd)
DDR=$(pick ~/rv32i/axi_ddr_sim.vhd ./axi_ddr_sim.vhd)
BF=$(pick ~/spi_ip/byte_fifo.vhd ./byte_fifo.vhd)
echo "riscv_pkg:   $PKG"
echo "axi_ddr_sim: $DDR"
echo "byte_fifo:   $BF"

xvhdl -2008 "$PKG" "$BF" "$DDR" \
      usart_engine.vhd usart_mmio.vhd usart_dma.vhd usart_axi_top.vhd \
      tb_usart_axi.vhd
xelab -debug typical tb_usart_axi -s tb_usart_axi_sim
xsim tb_usart_axi_sim -runall
