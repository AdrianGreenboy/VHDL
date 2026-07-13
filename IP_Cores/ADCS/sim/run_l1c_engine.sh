#!/bin/bash
# ============================================================================
# run_l1c_engine.sh — Capa 1c del IP ADCS: mpc_engine+bancos vs oraculo.
# PASS global: genuina con ERRORES=0 y firma == oraculo; MUT=1 (Gauss-Seidel
# accidental), MUT=2 (clamp sin negativos) y MUT=3 (step sin negar) DEBEN
# fallar.
# ============================================================================
set -u
cd "$(dirname "$0")"
RTL=../rtl
MODEL=../model
WORK=work_l1c
mkdir -p $WORK

echo "== Generando vectores con el oraculo (puede tardar ~1 min) =="
python3 $MODEL/mpc_oracle.py $WORK/vectors_mpc.txt | tee $WORK/oracle.log
SIG_ORA=$(grep -o 'FIRMA_ORACULO=0x[0-9A-F]*' $WORK/oracle.log | cut -d= -f2)

echo "== Analisis GHDL =="
ghdl -a --std=08 --workdir=$WORK \
    $RTL/fp32_pkg.vhd $RTL/fp32_fma.vhd $RTL/adcs_pkg.vhd \
    $RTL/mpc_dot_row.vhd $RTL/mpc_dot_x8.vhd $RTL/adcs_mem_banks.vhd \
    $RTL/mpc_engine.vhd tb_mpc_engine.vhd || exit 1
ghdl -e --std=08 --workdir=$WORK tb_mpc_engine || exit 1

FAIL=0
run_tb () {  # $1=MUT
    (cd $WORK && ghdl -r --std=08 --workdir=. tb_mpc_engine \
        -gMUT=$1 -gVEC_FILE=vectors_mpc.txt) > $WORK/run_mut$1.log 2>&1
    RC=$?
    SIG=$(grep -o 'FIRMA_L1C=0x[0-9A-F]*' $WORK/run_mut$1.log | cut -d= -f2)
}

echo "== Genuina (MUT=0) =="
run_tb 0
grep -oE 'ERRORES=[0-9]+ FIRMA_L1C=0x[0-9A-F]+ T=[0-9]+ *[a-z]+' $WORK/run_mut0.log
if [ $RC -ne 0 ]; then echo "GENUINA: FALLO"; FAIL=1; fi
if [ "$SIG" != "$SIG_ORA" ]; then
    echo "FIRMAS DIFIEREN: oraculo $SIG_ORA vs RTL $SIG"; FAIL=1
else
    echo "FIRMA BIT-IDENTICA: $SIG"
fi

for M in 1 2 3; do
    echo "== MUT=$M (debe FALLAR) =="
    run_tb $M
    if [ $RC -eq 0 ]; then echo "MUT=$M NO detectada — capa insuficiente"; FAIL=1
    else echo "MUT=$M detectada correctamente"; fi
done

echo "=================================================="
if [ $FAIL -eq 0 ]; then
    echo "CAPA 1C: PASS ($(grep -oE 'T=[0-9]+ *[a-z]+' $WORK/run_mut0.log | tail -1))"
else
    echo "CAPA 1C: FALLO"
fi
exit $FAIL
