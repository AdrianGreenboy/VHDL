#!/bin/bash
# run_mmio.sh -- MMUSART layer 2: usart_mmio (regs + FIFOs + engine, PIO).
# audit 2026-11: the FIFO is the private usart_byte_fifo.vhd of this core
# (no shared byte_fifo from ~/spi_ip anymore).
set -e

if ! command -v xvhdl >/dev/null 2>&1; then
  source ~/Xilinx/2025.2.1/Vivado/settings64.sh
fi

BF=./usart_byte_fifo.vhd

xvhdl -2008 "$BF" usart_engine.vhd usart_mmio.vhd tb_usart_mmio.vhd
xelab -debug typical tb_usart_mmio -s tb_usart_mmio_sim
xsim tb_usart_mmio_sim -runall
