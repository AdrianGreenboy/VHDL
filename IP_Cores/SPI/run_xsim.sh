#!/usr/bin/env bash
# =============================================================================
#  run_xsim.sh  -  Compiles and simulates the SPI IP testbenches with xsim.
#  Shared SoC sources (CPU, DMA, DDR model...) are pulled from ../RV32i by
#  default; override with:  RV32I=/path/to/RV32i ./run_xsim.sh spi_soc
#  Usage:
#     source <Vivado>/settings64.sh
#     ./run_xsim.sh              # run everything
#     ./run_xsim.sh spi_axi      # one target
#  Targets: spi | spi_mmio | spi_axi | spi_soc | elab_top | all
# =============================================================================
set -e
RV32I="${RV32I:-../RV32i}"

CPU_SRCS="$RV32I/riscv_pkg.vhd $RV32I/alu.vhd $RV32I/regfile.vhd $RV32I/muldiv.vhd \
          $RV32I/immgen.vhd $RV32I/control.vhd $RV32I/csr.vhd $RV32I/dp_ram.vhd \
          $RV32I/cpu_pipeline.vhd"
SPI_SRCS="spi_engine.vhd byte_fifo.vhd spi_dma.vhd spi_axi_top.vhd"

run_tb () {
  local tb="$1"; shift
  echo "==================== $tb ===================="
  xvhdl -2008 $@
  xelab -debug typical "$tb" -s "${tb}_sim"
  xsim "${tb}_sim" -runall
}

case "${1:-all}" in
  spi)
    run_tb tb_spi_engine spi_engine.vhd tb_spi_engine.vhd ;;
  spi_mmio)
    run_tb tb_spi_mmio spi_engine.vhd byte_fifo.vhd spi_mmio.vhd tb_spi_mmio.vhd ;;
  spi_axi)
    run_tb tb_spi_axi $RV32I/riscv_pkg.vhd $RV32I/axi_ddr_sim.vhd $SPI_SRCS tb_spi_axi.vhd ;;
  spi_soc)
    run_tb tb_spi_soc $CPU_SRCS $RV32I/dma_burst.vhd $RV32I/axi_ddr_sim.vhd $SPI_SRCS \
                  mem_subsys_spi.vhd tb_spi_soc.vhd ;;
  elab_top)
    echo "==================== elaborating soc_top_spi ===================="
    xvhdl -2008 $CPU_SRCS $RV32I/dma_burst.vhd $RV32I/axil_soc.vhd $SPI_SRCS \
                mem_subsys_spi.vhd soc_top_spi.vhd
    xelab -debug typical soc_top_spi -s elab_check
    echo "soc_top_spi ELABORATES OK" ;;
  all)
    "$0" spi; "$0" spi_mmio; "$0" spi_axi; "$0" spi_soc ;;
  *) echo "usage: $0 [all|spi|spi_mmio|spi_axi|spi_soc|elab_top]"; exit 1 ;;
esac
