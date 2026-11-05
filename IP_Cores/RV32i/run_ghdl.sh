#!/usr/bin/env bash
# =============================================================================
#  run_ghdl.sh  -  GHDL (VHDL-2008) regression for the RV32i core family.
#  Same targets as run_xsim.sh, plus the lw-hazard regression, the random
#  difftest and the audit-2026-11 directed tests.
#
#  Usage:
#     ./run_ghdl.sh                 # all targets
#     ./run_ghdl.sh cpu difftest    # selected targets
#  Env:
#     GHDL=ghdl        simulator binary (mcode is fine)
#     WORK=<dir>       scratch dir (default: mktemp); .mem files are copied there
#     DT_ITERS=30      random difftest programs per memory mode
#     DT_INSTRS=64     instructions per random program
#
#  Pass criterion per target: simulator exit 0, no FAIL / FALLARON / failure
#  line, and for directed tests the explicit "<tb>_PASS" marker in the log.
# =============================================================================
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
GHDL=${GHDL:-ghdl}
WORK=${WORK:-$(mktemp -d /tmp/rv32i_ghdl.XXXXXX)}
DT_ITERS=${DT_ITERS:-30}
DT_INSTRS=${DT_INSTRS:-64}
mkdir -p "$WORK"
cp "$HERE"/*.mem "$WORK"/ 2>/dev/null
cd "$WORK" || exit 2

S="$HERE"
CORE="$S/riscv_pkg.vhd $S/alu.vhd $S/regfile.vhd $S/muldiv.vhd $S/immgen.vhd \
      $S/control.vhd $S/csr.vhd $S/clint.vhd $S/imem.vhd $S/dmem.vhd"
SOCBASE="$S/riscv_pkg.vhd $S/alu.vhd $S/regfile.vhd $S/muldiv.vhd $S/immgen.vhd \
      $S/control.vhd $S/csr.vhd $S/dp_ram.vhd"

fail=0
summary=""

# sim <tb> <marker-or-empty> <generics...> -- <files...>
sim() {
  local tb=$1 marker=$2; shift 2
  local gens=()
  while [ "$1" != "--" ]; do gens+=("$1"); shift; done; shift
  local lib="$WORK/lib_${tb}"
  mkdir -p "$lib"
  local files=(); for f in "$@"; do [ -f "$f" ] && files+=("$f"); done   # tolerate optional sources
  set -- "${files[@]}"
  local log="$WORK/${tb}${gens[*]:+_$(echo "${gens[*]}" | tr ' =' '__')}.log"
  if ! $GHDL -a --std=08 --workdir="$lib" "$@" > "$log" 2>&1; then
    echo "  [FAIL] $tb (analysis, see $log)"; fail=1; summary+="FAIL $tb ${gens[*]}\n"; return 1
  fi
  $GHDL --elab-run --std=08 --workdir="$lib" "${gens[@]}" "$tb" --stop-time=5ms >> "$log" 2>&1
  local rc=$?
  local bad=0
  [ $rc -ne 0 ] && bad=1
  grep -qE "FAIL|FALLARON|\(assertion failure\)|\(report failure\)|bound check failure|stopped by --stop-time" "$log" && bad=1
  if [ -n "$marker" ] && ! grep -q "$marker" "$log"; then bad=1; fi
  if [ $bad -eq 0 ]; then
    echo "  [PASS] $tb ${gens[*]}  ($(grep -c 'PASS' "$log") PASS lines)"
    summary+="PASS $tb ${gens[*]}\n"
  else
    echo "  [FAIL] $tb ${gens[*]}  (rc=$rc, see $log)"; grep -E "FAIL|error|failure" "$log" | head -5 | sed 's/^/        /'
    summary+="FAIL $tb ${gens[*]}\n"; fail=1
  fi
}

difftest() {
  # random straight-line programs, golden model vs cpu_pipeline (both memory modes)
  local lib="$WORK/lib_tb_difftest"; mkdir -p "$lib"
  local files=(); for f in $CORE $S/cpu_pipeline.vhd $S/tb_difftest.vhd; do [ -f "$f" ] && files+=("$f"); done
  $GHDL -a --std=08 --workdir="$lib" "${files[@]}" \
     > "$WORK/difftest_build.log" 2>&1 || { echo "  [FAIL] difftest build"; fail=1; return; }
  for mode in ${DT_MODES:-false true}; do
    local pass=0
    for seed in $(seq 1 "$DT_ITERS"); do
      python3 "$S/difftest_gen.py" "$seed" "$DT_INSTRS" program_dt.mem expected.txt > /dev/null
      local g="-gSYNC_MEM=$mode"; [ "$mode" = none ] && g=""
      $GHDL --elab-run --std=08 --workdir="$lib" $g tb_difftest > "$WORK/dt_run.log" 2>&1
      if python3 "$S/difftest_cmp.py" expected.txt actual.txt "$seed" > "$WORK/dt_cmp.log" 2>&1; then
        pass=$((pass+1))
      else
        echo "  [FAIL] difftest SYNC_MEM=$mode seed=$seed"; cat "$WORK/dt_cmp.log" | head -8; fail=1
        summary+="FAIL difftest SYNC_MEM=$mode seed=$seed\n"; return
      fi
    done
    echo "  [PASS] difftest SYNC_MEM=$mode  $pass/$DT_ITERS random programs"
    summary+="PASS difftest SYNC_MEM=$mode $pass/$DT_ITERS\n"
  done
}

run_target() {
  case "$1" in
    alu)        sim tb_alu "" -- $S/riscv_pkg.vhd $S/alu.vhd $S/tb_alu.vhd ;;
    muldiv)     sim tb_muldiv "" -- $S/riscv_pkg.vhd $S/muldiv.vhd $S/tb_muldiv.vhd ;;
    decode)     sim tb_decode "" -- $S/riscv_pkg.vhd $S/control.vhd $S/immgen.vhd $S/tb_decode.vhd ;;
    cpu)        sim tb_cpu "" -- $CORE $S/cpu.vhd $S/tb_cpu.vhd ;;
    pipeline)   for m in ${SYNC_MODES:-false true}; do sim tb_cpu_pipeline "" -gSYNC_MEM=$m -- $CORE $S/cpu_pipeline.vhd $S/tb_cpu_pipeline.vhd; done ;;
    trap)       sim tb_trap "" -- $CORE $S/cpu.vhd $S/tb_trap.vhd ;;
    irq)        sim tb_irq "" -- $CORE $S/cpu.vhd $S/tb_irq.vhd ;;
    trap_pipe)  for m in ${SYNC_MODES:-false true}; do sim tb_trap_pipeline "" -gSYNC_MEM=$m -- $CORE $S/cpu_pipeline.vhd $S/tb_trap_pipeline.vhd; done ;;
    irq_pipe)   for m in ${SYNC_MODES:-false true}; do sim tb_irq_pipeline "" -gSYNC_MEM=$m -- $CORE $S/cpu_pipeline.vhd $S/tb_irq_pipeline.vhd; done ;;
    lw_hazard)  for m in ${SYNC_MODES:-false true}; do for g in 0 1 2 3 4; do
                  sim tb_lw_hazard "GAP_OK" -gGAP=$g -gSYNC_MEM=$m -- $CORE $S/cpu_pipeline.vhd $S/tb_lw_hazard.vhd
                done; done ;;
    lw_hazard_reg)
                for m in ${SYNC_MODES:-false true}; do sim tb_lw_hazard_reg "TB_LW_HAZARD_REG_PASS" -gSYNC_MEM=$m -- $CORE $S/cpu_pipeline.vhd $S/tb_lw_hazard_reg.vhd; done ;;
    soc)        sim tb_soc "" -- $SOCBASE $S/cpu.vhd $S/axil_soc.vhd $S/soc_top.vhd $S/tb_soc.vhd ;;
    accel)      sim tb_accel "" -- $SOCBASE $S/cpu.vhd $S/axil_soc.vhd $S/soc_top.vhd $S/tb_accel.vhd ;;
    accel_pipe) for m in ${SYNC_MODES:-false true}; do sim tb_accel_pipe "" -gSYNC_MEM=$m -- $SOCBASE $S/cpu_pipeline.vhd $S/axil_soc.vhd $S/rv32_bootrom_pkg.vhd $S/boot_loader.vhd $S/soc_top_pipe.vhd $S/tb_accel_pipe.vhd; done ;;
    master)     for m in ${SYNC_MODES:-false true}; do sim tb_master "" -gSYNC_MEM=$m -- $SOCBASE $S/cpu_pipeline.vhd $S/axi4_master.vhd \
                  $S/mem_subsys.vhd $S/axi_ddr_sim.vhd $S/tb_master.vhd; done ;;
    dma)        for g in "-gSYNC=false -gW_STALL=false" "-gSYNC=true -gW_STALL=false" \
                         "-gSYNC=false -gW_STALL=true" "-gSYNC=true -gW_STALL=true"; do
                  sim tb_dma "MOTOR DMA CON BURSTS AXI4: OK" $g -- $S/riscv_pkg.vhd $S/dp_ram.vhd $S/dma_burst.vhd $S/axi_ddr_sim.vhd $S/tb_dma.vhd
                done ;;
    gemv_dma)   for m in ${SYNC_MODES:-false true}; do sim tb_gemv_dma "" -gSYNC_MEM=$m -- $SOCBASE $S/cpu_pipeline.vhd $S/dma_burst.vhd \
                  $S/mem_subsys_dma.vhd $S/axi_ddr_sim.vhd $S/tb_gemv_dma.vhd; done ;;
    gemv_big)   for m in ${SYNC_MODES:-false true}; do sim tb_gemv_big "" -gSYNC_MEM=$m -- $SOCBASE $S/cpu_pipeline.vhd $S/dma_burst.vhd \
                  $S/mem_subsys_dma.vhd $S/axi_ddr_sim.vhd $S/tb_gemv_big.vhd; done ;;
    soc_master) for m in ${SYNC_MODES:-false true}; do sim tb_soc_master "" -gSYNC_MEM=$m -- $SOCBASE $S/cpu_pipeline.vhd $S/dma_burst.vhd \
                  $S/mem_subsys_dma.vhd $S/axil_soc.vhd $S/rv32_bootrom_pkg.vhd $S/boot_loader.vhd $S/soc_top_master.vhd $S/axi_ddr_sim.vhd $S/tb_soc_master.vhd; done ;;
    exc)        for g in "-gUSE_PIPE=true -gSYNC_MEM=false" "-gUSE_PIPE=true -gSYNC_MEM=true" "-gUSE_PIPE=false"; do
                  sim tb_exc "TB_EXC_PASS" $g -- $CORE $S/cpu.vhd $S/cpu_pipeline.vhd $S/tb_exc.vhd
                done ;;
    bus_err)    for m in ${SYNC_MODES:-false true}; do sim tb_bus_err "TB_BUS_ERR_PASS" -gSYNC_MEM=$m -- $SOCBASE $S/cpu_pipeline.vhd \
                  $S/axi4_master.vhd $S/mem_subsys.vhd $S/axi_ddr_sim.vhd $S/tb_bus_err.vhd; done ;;
    boot_rom)   # boot ROM package generated from boot_test.mem; IMEM pre-filled with garbage
                python3 "$S/gen_bootrom_pkg.py" "$WORK/boot_test.mem" "$WORK/rv32_bootrom_pkg_test.vhd" > /dev/null
                python3 -c "import random; r=random.Random(7); print('\n'.join('%08X' % r.getrandbits(32) for _ in range(256)))" > "$WORK/garbage.mem"
                for m in ${SYNC_MODES:-false true}; do
                  sim tb_boot_rom "TB_BOOT_ROM_PASS" -gSYNC_MEM=$m -- $SOCBASE $S/cpu_pipeline.vhd $S/axil_soc.vhd \
                    "$WORK/rv32_bootrom_pkg_test.vhd" $S/boot_loader.vhd $S/soc_top_pipe.vhd $S/tb_boot_rom.vhd
                done ;;
    lu_stall)   for m in ${SYNC_MODES:-false true}; do sim tb_lu_stall "TB_LU_STALL_PASS" -gSYNC_MEM=$m -- $CORE $S/cpu_pipeline.vhd $S/tb_lu_stall.vhd; done ;;
    difftest)   difftest ;;
    *) echo "unknown target $1"; fail=1 ;;
  esac
}

TARGETS=${*:-alu muldiv decode cpu pipeline trap irq trap_pipe irq_pipe lw_hazard lw_hazard_reg \
  soc accel accel_pipe master dma gemv_dma gemv_big soc_master \
  exc bus_err boot_rom lu_stall difftest}
for t in $TARGETS; do run_target "$t"; done

echo "------------------------------------------------------------"
printf "%b" "$summary" | awk '{print "  "$0}'
if [ $fail -eq 0 ]; then echo "RV32I GHDL REGRESSION OK"; else echo "RV32I GHDL REGRESSION FAILED"; fi
echo "logs: $WORK"
exit $fail
