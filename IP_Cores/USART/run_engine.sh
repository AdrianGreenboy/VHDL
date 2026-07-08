#!/bin/bash
# run_engine.sh -- MMUSART layer 1: usart_engine standalone simulation.
# Same flow as ~/spi_ip/run_xsim.sh; merge as target "usart_engine" if preferred:
#
#   usart_engine)
#     xvhdl -2008 usart_engine.vhd tb_usart_engine.vhd
#     xelab -debug typical tb_usart_engine -s tb_usart_engine_sim
#     xsim tb_usart_engine_sim -runall
#     ;;
set -e

if ! command -v xvhdl >/dev/null 2>&1; then
  source ~/Xilinx/2025.2.1/Vivado/settings64.sh
fi

xvhdl -2008 usart_engine.vhd tb_usart_engine.vhd
xelab -debug typical tb_usart_engine -s tb_usart_engine_sim
xsim tb_usart_engine_sim -runall
