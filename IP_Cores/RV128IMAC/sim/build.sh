#!/bin/bash
# Compila RTL + testbenches del RV128IMAC con GHDL (backend LLVM o GCC).
#   IP_CORES: arbol IP_Cores del repo VHDL (para el USART real del tb_soc)
set -e
cd $(dirname $0)
pick() {
  for g in ${GHDL:-} ghdl-llvm ghdl-gcc; do
    command -v $g > /dev/null || continue
    d=$(mktemp -d); echo "entity t is end;" > $d/t.vhd
    if (cd $d && $g -a --std=08 t.vhd) > /dev/null 2>&1; then echo $g; return; fi
    echo "aviso: $g no funciona, pruebo el siguiente" >&2
  done
}
G=$(pick)
[ -n "$G" ] || { echo "no hay GHDL con backend llvm o gcc (sudo apt install ghdl-gcc)" >&2; exit 1; }
echo "GHDL: $G" >&2
IPC=${IP_CORES:-$(cd ../.. && pwd)}          # por defecto: el IP_Cores que contiene RV128IMAC
R=../rtl
$G -a --std=08 $R/rv128_pkg.vhd $R/rv128_mmu_pkg.vhd $R/rv128_tlb.vhd $R/rv128_ptw.vhd \
  $R/rv128_muldiv.vhd $R/rv128_csr.vhd $R/rv128_core.vhd ../fpga/rv128_proto_top.vhd \
  $R/sram_1rw.vhd $R/rv128_axi_master.vhd $R/rv128_dcache.vhd $R/rv128_icache.vhd $R/rv128_cpu.vhd \
  $R/rv128_bootrom_pkg.vhd $R/rv128_clint.vhd $R/rv128_plic.vhd $R/rv128_uart.vhd $R/rv128_periph.vhd \
  $R/rv128_soc.vhd
$G -a --std=08 ../tb/tb_rvc.vhd ../tb/tb_muldiv.vhd ../tb/tb_core.vhd ../tb/tb_proto.vhd \
  ../tb/tb_cpu.vhd ../tb/tb_uart.vhd
TBS="tb_rvc tb_muldiv tb_core tb_proto tb_cpu tb_uart"
if [ -d "$IPC/USART" ]; then
  # USART audit-2026-11 moved to a private FIFO (usart_byte_fifo); older trees use SPI/byte_fifo
  UFIFO=$IPC/SPI/byte_fifo.vhd
  [ -f $IPC/USART/usart_byte_fifo.vhd ] && UFIFO="$UFIFO $IPC/USART/usart_byte_fifo.vhd"
  $G -a --std=08 $UFIFO $IPC/USART/usart_engine.vhd $IPC/USART/usart_mmio.vhd \
    $IPC/USART/usart_dma.vhd $IPC/USART/usart_axi_top.vhd ../tb/tb_soc.vhd
  TBS="$TBS tb_soc"
else
  echo "aviso: sin IP_Cores en $IPC; tb_soc no se compila (IP_CORES=<ruta>)" >&2
fi
for t in $TBS; do $G -e --std=08 $t; done
