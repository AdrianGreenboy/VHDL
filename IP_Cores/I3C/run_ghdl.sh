#!/usr/bin/env bash
# ============================================================================
#  run_ghdl.sh - I3C: all self-checking testbenches with GHDL (>= 4.x),
#  including the asynchronous controller/target test (audit 2026-11).
#  Unlike run_*.sh it never deletes anything: it builds in GHDL_BUILD
#  (default ./ghdl_build, created if missing). Shared SoC sources from
#  RV32I (default ../RV32i).
#  Usage: ./run_ghdl.sh [fifo|controller|target|engine|async|mmio|soc|all]
#  async accepts generics, e.g.  ./run_ghdl.sh async -gTT_PS=12500 -gDRIFT_PM=80
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
IP="i3c_byte_fifo.vhd i3c_controller.vhd i3c_target.vhd i3c_mmio.vhd"

tb() { local top=$1; shift; local files=(); local gens=();
       for a in "$@"; do case $a in -g*) gens+=("$a");; *) files+=("$a");; esac; done
       $G "${files[@]}"; $E "$top"; (cd "$B" && ghdl -r --std=08 "$top" "${gens[@]}"); echo "== $top: PASS"; }

t=${1:-all}; shift || true
case "$t" in
  fifo)       tb tb_i3c_byte_fifo i3c_byte_fifo.vhd tb_i3c_byte_fifo.vhd ;;
  controller) tb tb_i3c_controller i3c_controller.vhd tb_i3c_controller.vhd ;;
  target)     tb tb_i3c_target i3c_target.vhd tb_i3c_target.vhd ;;
  engine)     tb tb_i3c_engine i3c_controller.vhd i3c_target.vhd tb_i3c_engine.vhd ;;
  async)      tb tb_i3c_async i3c_controller.vhd i3c_target.vhd tb_i3c_async.vhd "$@" ;;
  mmio)       tb tb_i3c_mmio $IP tb_i3c_mmio.vhd ;;
  soc)        python3 "$RV/asm.py" i3c_test.s "$B/i3c_test.mem"
              tb tb_i3c_soc $CPU $IP mem_subsys_i3c.vhd soc_top_i3c.vhd tb_i3c_soc.vhd ;;
  all)        for x in fifo controller target engine async mmio soc; do "$0" $x; done ;;
  *) echo "usage: $0 [fifo|controller|target|engine|async|mmio|soc|all]"; exit 1 ;;
esac
