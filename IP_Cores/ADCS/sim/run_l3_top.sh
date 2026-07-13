#!/bin/bash
# ============================================================================
# run_l3_top.sh — Capa 3 del IP ADCS: top integrado (regfile+bancos+engine+DMA
# +secuenciador) vs oraculo del solver, via firmware simulado + BFM de DDR.
# PASS global: genuina con ERRORES=0 y firma == oraculo del subconjunto;
# MUT=1 (secuenciador salta STORE_U -> U no llega a DDR) y MUT=2 (DONE
# prematuro antes de STORE_U) DEBEN fallar.
# ============================================================================
set -u
cd "$(dirname "$0")"
RTL=../rtl
MODEL=../model
WORK=work_l3
mkdir -p $WORK

echo "== Generando subconjunto de vectores (small) =="
python3 $MODEL/mpc_oracle.py --small $WORK/vectors_top.txt | tee $WORK/oracle.log
SIG_ORA=$(grep -o 'FIRMA_ORACULO=0x[0-9A-F]*' $WORK/oracle.log | cut -d= -f2)

echo "== Analisis GHDL =="
ghdl -a --std=08 --workdir=$WORK \
    $RTL/riscv_pkg.vhd $RTL/fp32_pkg.vhd $RTL/fp32_fma.vhd $RTL/adcs_pkg.vhd \
    $RTL/mpc_dot_row.vhd $RTL/mpc_dot_x8.vhd $RTL/adcs_mem_banks.vhd \
    $RTL/mpc_engine.vhd $RTL/adcs_regfile.vhd $RTL/axi_dma_engine.vhd \
    $RTL/adcs_accel_top.vhd tb_adcs_top.vhd || exit 1
ghdl -e --std=08 --workdir=$WORK tb_adcs_top || exit 1

FAIL=0
run () {  # $1=MUT
    (cd $WORK && ghdl -r --std=08 --workdir=. tb_adcs_top \
        -gMUT=$1 -gVEC_FILE=vectors_top.txt --stop-time=200ms) \
        > $WORK/run_mut$1.log 2>&1
    RC=$?
    SIG=$(grep -o 'FIRMA_L3=0x[0-9A-F]*' $WORK/run_mut$1.log | cut -d= -f2)
}

echo "== Genuina (MUT=0) =="
run 0
grep -oE 'ERRORES=[0-9]+ FIRMA_L3=0x[0-9A-F]+ T=[0-9]+ *[a-z]+' $WORK/run_mut0.log
if [ $RC -ne 0 ]; then echo "GENUINA: FALLO"; FAIL=1; fi
if [ "$SIG" != "$SIG_ORA" ]; then
    echo "FIRMAS DIFIEREN: oraculo $SIG_ORA vs RTL $SIG"; FAIL=1
else
    echo "FIRMA BIT-IDENTICA: $SIG"
fi

for M in 1 2; do
    echo "== MUT=$M (debe FALLAR) =="
    run $M
    if [ $RC -eq 0 ]; then echo "MUT=$M NO detectada — capa insuficiente"; FAIL=1
    else echo "MUT=$M detectada correctamente"; fi
done

echo "=================================================="
if [ $FAIL -eq 0 ]; then
    echo "CAPA 3: PASS ($(grep -oE 'T=[0-9]+ *[a-z]+' $WORK/run_mut0.log | tail -1))"
else
    echo "CAPA 3: FALLO"
fi
exit $FAIL
