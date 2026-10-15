#!/bin/bash
# Compila RTL + testbenches con GHDL (backend LLVM).
#   IP_CORES: arbol IP_Cores del repo VHDL (para el USART real del tb_soc)
set -e
cd $(dirname $0)
G="${GHDL:-ghdl-llvm}"
command -v $G > /dev/null || { echo "falta $G (sudo apt install ghdl-llvm)" >&2; exit 1; }
IPC=${IP_CORES:-$(cd ../.. && pwd)}          # por defecto: el IP_Cores que contiene RV64IMAC
R=../rtl
$G -a --std=08 $R/rv64_pkg.vhd $R/rv64_mmu_pkg.vhd $R/rv64_tlb.vhd $R/rv64_ptw.vhd \
  $R/rv64_muldiv.vhd $R/rv64_csr.vhd $R/rv64_core.vhd \
  $R/sram_1rw.vhd $R/rv64_axi_master.vhd $R/rv64_dcache.vhd $R/rv64_icache.vhd $R/rv64_cpu.vhd \
  $R/rv64_bootrom_pkg.vhd $R/rv64_clint.vhd $R/rv64_plic.vhd $R/rv64_uart.vhd $R/rv64_periph.vhd \
  $R/rv64_soc.vhd
$G -a --std=08 ../tb/tb_rvc.vhd ../tb/tb_muldiv.vhd ../tb/tb_core.vhd ../tb/tb_cpu.vhd
TBS="tb_rvc tb_muldiv tb_core tb_cpu"
if [ -d "$IPC/USART" ]; then
  $G -a --std=08 $IPC/SPI/byte_fifo.vhd $IPC/USART/usart_engine.vhd $IPC/USART/usart_mmio.vhd \
    $IPC/USART/usart_dma.vhd $IPC/USART/usart_axi_top.vhd ../tb/tb_soc.vhd
  TBS="$TBS tb_soc"
else
  echo "aviso: sin IP_Cores en $IPC; tb_soc no se compila" >&2
fi
for t in $TBS; do $G -e --std=08 $t; done
