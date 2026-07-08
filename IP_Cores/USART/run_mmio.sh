#!/bin/bash
# run_mmio.sh -- MMUSART layer 2: usart_mmio (regs + FIFOs + engine, PIO).
# byte_fifo.vhd es fuente compartida del proyecto SPI: se toma de ~/spi_ip/
# si existe (mismo patron que run_xsim.sh con ~/rv32i/), o de la copia local.
set -e

if ! command -v xvhdl >/dev/null 2>&1; then
  source ~/Xilinx/2025.2.1/Vivado/settings64.sh
fi

BF=~/spi_ip/byte_fifo.vhd
[ -f "$BF" ] || BF=./byte_fifo.vhd
[ -f "$BF" ] || { echo "ERROR: byte_fifo.vhd no encontrado (ni en ~/spi_ip/ ni local)"; exit 1; }
echo "byte_fifo: $BF"

xvhdl -2008 "$BF" usart_engine.vhd usart_mmio.vhd tb_usart_mmio.vhd
xelab -debug typical tb_usart_mmio -s tb_usart_mmio_sim
xsim tb_usart_mmio_sim -runall
