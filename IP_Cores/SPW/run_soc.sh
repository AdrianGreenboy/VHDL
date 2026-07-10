#!/usr/bin/env bash
set -u
(
  cd "$(dirname "$0")" || exit 1
  RV=/home/adrian/vhdl_repo/IP_Cores/RV32i

  # ensamblar el programa (asm.py del core RV32i)
  python3 "$RV/asm.py" spw_test.s spw_test.mem || exit 1

  rm -f work-obj08.cf

  # paquete y dependencias del core (orden de compilacion)
  ghdl -a --std=08 \
    "$RV/riscv_pkg.vhd" \
    "$RV/alu.vhd" "$RV/regfile.vhd" "$RV/immgen.vhd" "$RV/control.vhd" \
    "$RV/csr.vhd" "$RV/muldiv.vhd" "$RV/dp_ram.vhd" \
    "$RV/cpu_pipeline.vhd" \
    "$RV/axi4_master.vhd" "$RV/dma_burst.vhd" "$RV/axi_ddr_sim.vhd" \
    "$RV/axil_soc.vhd" || exit 1

  # IP SpaceWire + subsistema + TB
  ghdl -a --std=08 \
    spw_fifo.vhd spw_tx.vhd spw_rx.vhd spw_link.vhd spw_codec.vhd spw_mmio.vhd \
    mem_subsys_spw.vhd tb_spw_soc.vhd || exit 1

  ghdl -e --std=08 tb_spw_soc || exit 1
  ghdl -r --std=08 tb_spw_soc --stop-time=6ms
)
