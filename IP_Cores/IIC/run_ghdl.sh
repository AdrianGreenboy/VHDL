#!/usr/bin/env bash
# ============================================================================
#  run_ghdl.sh - IIC: all self-checking testbenches with GHDL (>= 4.x)
#  (audit 2026-11; the xsim scripts run_*.sh remain the reference flow).
#  Shared SoC sources from RV32I (default ../RV32i). Builds in GHDL_BUILD
#  (default ./ghdl_build; created if missing; nothing is deleted).
#  Usage: ./run_ghdl.sh [fifo|master|audit|slave|engine|mmio|soc|all]
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
IP="i2c_byte_fifo.vhd i2c_master.vhd i2c_slave.vhd i2c_mmio.vhd"

tb() { local top=$1; shift; $G "$@"; $E "$top"; (cd "$B" && ghdl -r --std=08 "$top"); echo "== $top: PASS"; }

case "${1:-all}" in
  fifo)   tb tb_i2c_byte_fifo i2c_byte_fifo.vhd tb_i2c_byte_fifo.vhd ;;
  master) tb tb_i2c_master i2c_master.vhd tb_i2c_master.vhd ;;
  audit)  tb tb_i2c_master_audit i2c_master.vhd tb_i2c_master_audit.vhd ;;
  slave)  tb tb_i2c_slave i2c_slave.vhd tb_i2c_slave.vhd ;;
  engine) tb tb_i2c_engine i2c_master.vhd i2c_slave.vhd tb_i2c_engine.vhd ;;
  mmio)   tb tb_i2c_mmio $IP tb_i2c_mmio.vhd ;;
  soc)    python3 "$RV/asm.py" i2c_test.s "$B/i2c_test.mem"
          tb tb_i2c_soc $CPU $IP mem_subsys_i2c.vhd soc_top_i2c.vhd tb_i2c_soc.vhd ;;
  all)    for t in fifo master audit slave engine mmio soc; do "$0" $t; done ;;
  *) echo "usage: $0 [fifo|master|audit|slave|engine|mmio|soc|all]"; exit 1 ;;
esac
