#!/bin/bash
# run_axi.sh -- MMUSART layer 3: IP completo (mmio v1.1 + dma) vs axi_ddr_sim.
# Fuentes compartidas: riscv_pkg + axi_ddr_sim de ~/rv32i/ (copias locales
# como fallback). audit 2026-11: FIFO = private usart_byte_fifo.vhd.
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
BF=./usart_byte_fifo.vhd
echo "riscv_pkg:   $PKG"
echo "axi_ddr_sim: $DDR"
echo "fifo:        $BF"

xvhdl -2008 "$PKG" "$BF" "$DDR" \
      usart_engine.vhd usart_mmio.vhd usart_dma.vhd usart_axi_top.vhd \
      tb_usart_axi.vhd
xelab -debug typical tb_usart_axi -s tb_usart_axi_sim
xsim tb_usart_axi_sim -runall

# audit 2026-11: unit test of the DMA fixes (abort latch, 32-bit offsets,
# RLAST check) and FIFO equivalence test
xvhdl -2008 usart_dma.vhd tb_usart_dma.vhd
xelab -debug typical tb_usart_dma -s tb_usart_dma_sim
xsim tb_usart_dma_sim -runall
xvhdl -2008 usart_byte_fifo.vhd tb_usart_byte_fifo.vhd
xelab -debug typical tb_usart_byte_fifo -s tb_usart_byte_fifo_sim
xsim tb_usart_byte_fifo_sim -runall
