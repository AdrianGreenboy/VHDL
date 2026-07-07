#!/usr/bin/env bash
# =============================================================================
#  run_xsim.sh  -  Compila y simula los testbenches con el xsim de Vivado.
#  (Version para carpeta PLANA: todos los .vhd y .mem en el directorio actual.)
#  Uso:
#     source ~/Xilinx/2025.2.1/Vivado/settings64.sh
#     ./run_xsim.sh                 # corre todos
#     ./run_xsim.sh cpu             # uno solo
#     targets: alu muldiv decode cpu pipeline trap irq trap_pipe irq_pipe
# =============================================================================
set -e

CORE="riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd control.vhd \
      csr.vhd clint.vhd imem.vhd dmem.vhd"

run_tb () {
  local tb="$1"; shift
  echo "==================== $tb ===================="
  xvhdl -2008 "$@"
  xelab -debug typical "$tb" -s "${tb}_sim"
  xsim "${tb}_sim" -runall
}

case "${1:-all}" in
  alu)       run_tb tb_alu    riscv_pkg.vhd alu.vhd tb_alu.vhd ;;
  muldiv)    run_tb tb_muldiv riscv_pkg.vhd muldiv.vhd tb_muldiv.vhd ;;
  decode)    run_tb tb_decode riscv_pkg.vhd control.vhd immgen.vhd tb_decode.vhd ;;
  cpu)       run_tb tb_cpu           $CORE cpu.vhd          tb_cpu.vhd ;;
  pipeline)  run_tb tb_cpu_pipeline  $CORE cpu_pipeline.vhd tb_cpu_pipeline.vhd ;;
  trap)      run_tb tb_trap          $CORE cpu.vhd          tb_trap.vhd ;;
  irq)       run_tb tb_irq           $CORE cpu.vhd          tb_irq.vhd ;;
  trap_pipe) run_tb tb_trap_pipeline $CORE cpu_pipeline.vhd tb_trap_pipeline.vhd ;;
  irq_pipe)  run_tb tb_irq_pipeline  $CORE cpu_pipeline.vhd tb_irq_pipeline.vhd ;;
  soc)
    run_tb tb_soc riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd \
                  control.vhd csr.vhd dp_ram.vhd cpu.vhd axil_soc.vhd soc_top.vhd tb_soc.vhd ;;
  accel)
    run_tb tb_accel riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd \
                  control.vhd csr.vhd dp_ram.vhd cpu.vhd axil_soc.vhd soc_top.vhd tb_accel.vhd ;;
  accel_pipe)
    run_tb tb_accel_pipe riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd \
                  control.vhd csr.vhd dp_ram.vhd cpu_pipeline.vhd axil_soc.vhd soc_top_pipe.vhd tb_accel_pipe.vhd ;;
  master)
    run_tb tb_master riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd \
                  control.vhd csr.vhd dp_ram.vhd cpu_pipeline.vhd axi4_master.vhd \
                  mem_subsys.vhd axi_ddr_sim.vhd tb_master.vhd ;;
  dma)
    run_tb tb_dma riscv_pkg.vhd dp_ram.vhd dma_burst.vhd axi_ddr_sim.vhd tb_dma.vhd ;;
  gemv_dma)
    run_tb tb_gemv_dma riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd \
                  control.vhd csr.vhd dp_ram.vhd cpu_pipeline.vhd dma_burst.vhd \
                  mem_subsys_dma.vhd axi_ddr_sim.vhd tb_gemv_dma.vhd ;;
  gemv_big)
    run_tb tb_gemv_big riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd \
                  control.vhd csr.vhd dp_ram.vhd cpu_pipeline.vhd dma_burst.vhd \
                  mem_subsys_dma.vhd axi_ddr_sim.vhd tb_gemv_big.vhd ;;
  soc_master)
    run_tb tb_soc_master riscv_pkg.vhd alu.vhd regfile.vhd muldiv.vhd immgen.vhd \
                  control.vhd csr.vhd dp_ram.vhd cpu_pipeline.vhd dma_burst.vhd \
                  mem_subsys_dma.vhd axil_soc.vhd soc_top_master.vhd axi_ddr_sim.vhd tb_soc_master.vhd ;;
  all)
    run_tb tb_alu    riscv_pkg.vhd alu.vhd tb_alu.vhd
    run_tb tb_muldiv riscv_pkg.vhd muldiv.vhd tb_muldiv.vhd
    run_tb tb_decode riscv_pkg.vhd control.vhd immgen.vhd tb_decode.vhd
    run_tb tb_cpu           $CORE cpu.vhd          tb_cpu.vhd
    run_tb tb_cpu_pipeline  $CORE cpu_pipeline.vhd tb_cpu_pipeline.vhd
    run_tb tb_trap          $CORE cpu.vhd          tb_trap.vhd
    run_tb tb_irq           $CORE cpu.vhd          tb_irq.vhd
    run_tb tb_trap_pipeline $CORE cpu_pipeline.vhd tb_trap_pipeline.vhd
    run_tb tb_irq_pipeline  $CORE cpu_pipeline.vhd tb_irq_pipeline.vhd ;;
  *) echo "uso: $0 [all|alu|muldiv|decode|cpu|pipeline|trap|irq|trap_pipe|irq_pipe|soc|accel|accel_pipe|master|dma|gemv_dma|soc_master]"; exit 1 ;;
esac
