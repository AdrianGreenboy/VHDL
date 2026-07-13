#!/bin/bash
# ============================================================================
# run_l2_dma.sh — Capa 2 del IP ADCS: DMA AXI4-Full vs BFM de DDR.
# PASS global: genuina con ERRORES=0; MUT=1 (AxPROT secure) DEBE dar
# TIMEOUT/DEADLOCK (el BFM del NoC lo rechaza, como en silicio); MUT=2
# (off-by-one) y MUT=3 (STORE_U dato viejo) DEBEN fallar.
# ============================================================================
set -u
cd "$(dirname "$0")"
RTL=../rtl
WORK=work_l2dma
mkdir -p $WORK

echo "== Analisis GHDL =="
ghdl -a --std=08 --workdir=$WORK $RTL/adcs_pkg.vhd $RTL/adcs_mem_banks.vhd \
    $RTL/axi_dma_engine.vhd tb_axi_dma_engine.vhd || exit 1
ghdl -e --std=08 --workdir=$WORK tb_axi_dma_engine || exit 1

FAIL=0
run () {  # $1=MUT
    (cd $WORK && ghdl -r --std=08 --workdir=. tb_axi_dma_engine \
        -gMUT=$1 --stop-time=50ms) > $WORK/run_mut$1.log 2>&1
    RC=$?
}

echo "== Genuina (MUT=0) =="
run 0
grep -oE 'ERRORES=[0-9]+ T=[0-9]+ *[a-z]+' $WORK/run_mut0.log
if [ $RC -ne 0 ]; then echo "GENUINA: FALLO"; FAIL=1; else echo "GENUINA: OK"; fi

echo "== MUT=1 AxPROT secure (debe DEADLOCK/timeout) =="
run 1
if grep -q 'TIMEOUT/DEADLOCK' $WORK/run_mut1.log || [ $RC -ne 0 ]; then
    echo "MUT=1 detectada (deadlock por rechazo del NoC, como en silicio)"
else
    echo "MUT=1 NO detectada — capa insuficiente"; FAIL=1
fi

for M in 2 3; do
    echo "== MUT=$M (debe FALLAR) =="
    run $M
    if [ $RC -eq 0 ]; then echo "MUT=$M NO detectada — capa insuficiente"; FAIL=1
    else echo "MUT=$M detectada correctamente"; fi
done

echo "=================================================="
if [ $FAIL -eq 0 ]; then
    echo "CAPA 2 DMA: PASS ($(grep -oE 'T=[0-9]+ *[a-z]+' $WORK/run_mut0.log | tail -1))"
else
    echo "CAPA 2 DMA: FALLO"
fi
exit $FAIL
