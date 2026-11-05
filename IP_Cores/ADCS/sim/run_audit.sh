#!/bin/bash
# ============================================================================
# run_audit.sh — audit 2026-11 benches of the ADCS IP:
#   * tb_fp32_fma_rtl : portable FMA vs fp32_pkg (>= 200k random + directed),
#                       LAT_FMA=8 and 4, and the 3 mutations MUST fail
#   * tb_adcs_audit   : DMA RRESP error, soft-reset drain, watchdog, clamps, NaN
#   * tb_mpc_guard    : engine n_dim=0 / maxiter=0 guards
#   * tb_dma_audit_adcs: CPU store during DMA, LEN>256 split, LEN=0
# N_RAND can be overridden (default 200000).
# ============================================================================
set -u
cd "$(dirname "$0")"
RTL=../rtl
SOC=../soc
WORK=work_audit
N_RAND=${N_RAND:-200000}
mkdir -p $WORK
FAIL=0
ghdl -a --std=08 --workdir=$WORK \
    $RTL/riscv_pkg.vhd $RTL/fp32_pkg.vhd $RTL/fp32_cfg_pkg.vhd $RTL/fp32_fma_rtl.vhd \
    $RTL/fp32_fma.vhd $RTL/adcs_pkg.vhd $RTL/mpc_dot_row.vhd $RTL/mpc_dot_x8.vhd \
    $RTL/adcs_mem_banks.vhd $RTL/mpc_engine.vhd $RTL/adcs_regfile.vhd \
    $RTL/axi_dma_engine.vhd $RTL/adcs_accel_top.vhd \
    $SOC/dp_ram.vhd $SOC/dma_burst.vhd $RTL/mem_subsys_dma_adcs.vhd \
    tb_fp32_fma_rtl.vhd tb_adcs_audit.vhd tb_mpc_guard.vhd tb_dma_audit_adcs.vhd \
    2>&1 | grep -i ' error' && exit 1

chk () {  # $1 tb  $2 pass-pattern  $3.. extra args
    local tb=$1 pat=$2; shift 2
    ghdl -e --std=08 --workdir=$WORK $tb >/dev/null 2>&1
    out=$(cd $WORK && ghdl -r --std=08 --workdir=. $tb "$@" 2>&1)
    if echo "$out" | grep -q "$pat" && ! echo "$out" | grep -q "assertion failure"; then
        echo "PASS  $tb $*"
    else
        echo "FAIL  $tb $*"; echo "$out" | grep -v metavalue | tail -4; FAIL=1
    fi
}
chk_mut () {  # must FAIL
    out=$(cd $WORK && ghdl -r --std=08 --workdir=. tb_fp32_fma_rtl -gN_RAND=4000 -gMUT=$1 2>&1)
    if echo "$out" | grep -q "TB_FP32_FMA_RTL FAIL"; then echo "PASS  MUT=$1 detected"
    else echo "FAIL  MUT=$1 NOT detected"; FAIL=1; fi
}
chk tb_fp32_fma_rtl "TB_FP32_FMA_RTL PASS" -gN_RAND=$N_RAND
chk tb_fp32_fma_rtl "TB_FP32_FMA_RTL PASS" -gN_RAND=20000 -gLAT_FMA=4
for m in 1 2 3; do chk_mut $m; done
chk tb_adcs_audit "TB_ADCS_AUDIT PASS" --stop-time=20ms
chk tb_mpc_guard "TB_MPC_GUARD PASS"
chk tb_dma_audit_adcs "TB_DMA_AUDIT_ADCS PASS"
echo "=================================================="
[ $FAIL -eq 0 ] && echo "AUDIT ADCS: PASS" || echo "AUDIT ADCS: FALLO"
exit $FAIL
