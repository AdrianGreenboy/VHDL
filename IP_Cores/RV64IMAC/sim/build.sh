#!/bin/bash
# Compila RTL + testbenches con GHDL (backend LLVM).
#   IP_CORES: arbol IP_Cores del repo VHDL (para el USART real del tb_soc)
set -e
cd $(dirname $0)
# backend: $GHDL si funciona; si no, ghdl-llvm o ghdl-gcc (mcode no genera ejecutables)
pick() {
  for g in ${GHDL:-} ghdl-llvm ghdl-gcc; do
    command -v $g > /dev/null || continue
    d=$(mktemp -d); echo "entity t is end;" > $d/t.vhd
    if (cd $d && $g -a --std=08 t.vhd) > /dev/null 2>&1; then rm -rf $d; echo $g; return; fi
    rm -rf $d; echo "aviso: $g no funciona, pruebo el siguiente" >&2
  done
}
G=$(pick)
[ -n "$G" ] || { echo "no hay GHDL con backend llvm o gcc (sudo apt install ghdl-gcc)" >&2; exit 1; }
echo "GHDL: $G" >&2
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
  rm -f tb_soc                       # nunca dejar un tb_soc de un RTL anterior
  echo "aviso: sin IP_Cores en $IPC; tb_soc no se compila (IP_CORES=<ruta>)" >&2
fi
for t in $TBS; do $G -e --std=08 $t; done
