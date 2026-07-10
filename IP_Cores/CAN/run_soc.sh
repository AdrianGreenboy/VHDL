#!/usr/bin/env bash
set -u
(
  cd "$(dirname "$0")" || exit 1
  RV=/home/adrian/vhdl_repo/IP_Cores/RV32i

  # ensamblar el programa (asm.py del core RV32i)
  python3 "$RV/asm.py" can_test.s can_test.mem || exit 1

  rm -f work-obj08.cf

  # paquete y dependencias del core (orden de compilacion)
  ghdl -a --std=08 \
    "$RV/riscv_pkg.vhd" \
    "$RV/alu.vhd" "$RV/regfile.vhd" "$RV/immgen.vhd" "$RV/control.vhd" \
    "$RV/csr.vhd" "$RV/muldiv.vhd" "$RV/dp_ram.vhd" \
    "$RV/cpu_pipeline.vhd" \
    "$RV/axi4_master.vhd" "$RV/dma_burst.vhd" "$RV/axi_ddr_sim.vhd" \
    "$RV/axil_soc.vhd" || exit 1

  # IP CAN + subsistema + TB
  ghdl -a --std=08 \
    byte_fifo.vhd can_engine.vhd can_mmio.vhd \
    mem_subsys_can.vhd tb_can_soc.vhd || exit 1

  ghdl -e --std=08 tb_can_soc || exit 1
  ghdl -r --std=08 tb_can_soc --stop-time=6ms
)
