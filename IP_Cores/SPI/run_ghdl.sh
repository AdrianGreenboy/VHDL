#!/usr/bin/env bash
# ============================================================================
#  run_ghdl.sh - SPI: all self-checking testbenches with GHDL (>= 4.x)
#  (audit 2026-11; run_xsim.sh remains the reference xsim flow).
#  Shared SoC sources from RV32I (default ../RV32i). Builds in GHDL_BUILD
#  (default ./ghdl_build; created if missing; nothing is deleted).
#  Usage: ./run_ghdl.sh [fifo|engine|mmio|axi|soc|elab_top|all]
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"
RV="$(realpath "${RV32I:-../RV32i}")"
B="$(realpath -m "${GHDL_BUILD:-./ghdl_build}")"
mkdir -p "$B"
G="ghdl -a --std=08 --workdir=$B"
E="ghdl -e --std=08 --workdir=$B"
CPU="$RV/riscv_pkg.vhd $RV/alu.vhd $RV/regfile.vhd $RV/muldiv.vhd $RV/immgen.vhd \
     $RV/control.vhd $RV/csr.vhd $RV/dp_ram.vhd $RV/cpu_pipeline.vhd \
     $RV/dma_burst.vhd $RV/axil_soc.vhd $RV/axi_ddr_sim.vhd"
IP="spi_engine.vhd spi_byte_fifo.vhd spi_dma.vhd spi_axi_top.vhd"

tb() { local top=$1; shift; $G "$@"; $E "$top"; (cd "$B" && ghdl -r --std=08 "$top"); echo "== $top: PASS"; }
mems() { cp -f spi_ddr.mem ddr_cpu.mem "$B/"; python3 "$RV/asm.py" spi_test.s "$B/spi_test.mem"; }

case "${1:-all}" in
  fifo)   tb tb_spi_byte_fifo spi_byte_fifo.vhd tb_spi_byte_fifo.vhd ;;
  engine) tb tb_spi_engine spi_engine.vhd tb_spi_engine.vhd ;;
  mmio)   tb tb_spi_mmio spi_engine.vhd spi_byte_fifo.vhd spi_mmio.vhd tb_spi_mmio.vhd ;;
  axi)    mems; tb tb_spi_axi "$RV/riscv_pkg.vhd" "$RV/axi_ddr_sim.vhd" $IP tb_spi_axi.vhd ;;
  soc)    mems; tb tb_spi_soc $CPU $IP mem_subsys_spi.vhd tb_spi_soc.vhd ;;
  elab_top) $G $CPU $IP mem_subsys_spi.vhd soc_top_spi.vhd; $E soc_top_spi; echo "== soc_top_spi ELABORATES" ;;
  all)    for t in fifo engine mmio axi soc elab_top; do "$0" $t; done ;;
  *) echo "usage: $0 [fifo|engine|mmio|axi|soc|elab_top|all]"; exit 1 ;;
esac
