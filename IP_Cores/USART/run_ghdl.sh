#!/usr/bin/env bash
# ============================================================================
#  run_ghdl.sh - USART: all self-checking testbenches with GHDL (>= 4.x)
#  (audit 2026-11; the xsim scripts run_*.sh remain the reference flow).
#  Shared SoC sources from RV32I (default ../RV32i). Builds in ./ghdl_build
#  (override with GHDL_BUILD=dir; created if missing; nothing is deleted).
#  Usage: ./run_ghdl.sh [fifo|engine|mmio|dma|axi|soc|all]
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"
RV="${RV32I:-../RV32i}"
B="$(realpath -m "${GHDL_BUILD:-./ghdl_build}")"
mkdir -p "$B"
G="ghdl -a --std=08 --workdir=$B"
E="ghdl -e --std=08 --workdir=$B"
R="ghdl -r --std=08 --workdir=$B"
CPU="$RV/riscv_pkg.vhd $RV/alu.vhd $RV/regfile.vhd $RV/muldiv.vhd $RV/immgen.vhd \
     $RV/control.vhd $RV/csr.vhd $RV/dp_ram.vhd $RV/cpu_pipeline.vhd \
     $RV/dma_burst.vhd $RV/axil_soc.vhd $RV/axi_ddr_sim.vhd"
IP="usart_byte_fifo.vhd usart_engine.vhd usart_mmio.vhd usart_dma.vhd usart_axi_top.vhd"

tb() { local top=$1; shift; $G "$@"; $E "$top"; (cd "$B" && ghdl -r --std=08 "$top"); echo "== $top: PASS"; }

soc_prep() {
  python3 "$RV/asm.py" usart_test.s "$B/usart_test.mem"
  python3 - "$B/usart_ddr.mem" <<'PY'
import sys
with open(sys.argv[1], 'w') as f:
    for k in range(1024):
        b = [(4*k + i) % 256 for i in range(4)]
        f.write('%02X%02X%02X%02X\n' % (b[3], b[2], b[1], b[0]))
PY
}

case "${1:-all}" in
  fifo)   tb tb_usart_byte_fifo usart_byte_fifo.vhd tb_usart_byte_fifo.vhd ;;
  engine) tb tb_usart_engine usart_engine.vhd tb_usart_engine.vhd ;;
  mmio)   tb tb_usart_mmio usart_byte_fifo.vhd usart_engine.vhd usart_mmio.vhd tb_usart_mmio.vhd ;;
  dma)    tb tb_usart_dma usart_dma.vhd tb_usart_dma.vhd ;;
  axi)    tb tb_usart_axi "$RV/riscv_pkg.vhd" "$RV/axi_ddr_sim.vhd" $IP tb_usart_axi.vhd ;;
  soc)    soc_prep; tb tb_usart_soc $CPU $IP mem_subsys_usart.vhd soc_top_usart.vhd tb_usart_soc.vhd ;;
  all)    for t in fifo engine mmio dma axi soc; do "$0" $t; done ;;
  *) echo "usage: $0 [fifo|engine|mmio|dma|axi|soc|all]"; exit 1 ;;
esac
