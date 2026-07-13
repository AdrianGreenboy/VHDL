#!/bin/bash
# run_regression.sh — regresion completa del IP ADCS (capas verificadas).
set -u
cd "$(dirname "$0")"
FAIL=0
for r in run_l1a_fma run_l1b_dot run_l1c_engine run_l2_regfile run_l2_dma run_l3_top run_l4_soc; do
    echo "### $r ###"
    ./$r.sh || FAIL=1
    echo
done
echo "=================================================="
[ $FAIL -eq 0 ] && echo "REGRESION ADCS: TODAS LAS CAPAS PASS" || echo "REGRESION ADCS: HAY FALLOS"
exit $FAIL
