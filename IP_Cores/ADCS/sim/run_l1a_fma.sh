#!/bin/bash
# ============================================================================
# run_l1a_fma.sh — Capa 1a del IP ADCS: FMA fp32 vs oraculo + mutaciones.
# PASS global: corrida genuina con ERRORES=0 y firma == oraculo, y las tres
# mutaciones (MUT=1,2,3) DEBEN fallar.
# ============================================================================
set -u
cd "$(dirname "$0")"
RTL=../rtl
MODEL=../model
WORK=work_l1a
mkdir -p $WORK

echo "== Generando vectores con el oraculo =="
python3 $MODEL/fp32_oracle.py $WORK/vectors_fma.txt | tee $WORK/oracle.log
SIG_ORA=$(grep -o 'FIRMA_ORACULO=0x[0-9A-F]*' $WORK/oracle.log | cut -d= -f2)

echo "== Analisis GHDL =="
ghdl -a --std=08 --workdir=$WORK $RTL/fp32_pkg.vhd $RTL/fp32_fma.vhd tb_fp32_fma.vhd || exit 1
ghdl -e --std=08 --workdir=$WORK tb_fp32_fma || exit 1

echo "== Corrida genuina (MUT=0) =="
(cd $WORK && ghdl -r --std=08 --workdir=. tb_fp32_fma -gMUT=0 -gVEC_FILE=vectors_fma.txt) \
    > $WORK/run_mut0.log 2>&1
RC0=$?
grep -E 'ERRORES=|FALLO' $WORK/run_mut0.log
SIG_RTL=$(grep -o 'FIRMA_L1A=0x[0-9A-F]*' $WORK/run_mut0.log | cut -d= -f2)

FAIL=0
if [ $RC0 -ne 0 ]; then echo "GENUINA: FALLO (rc=$RC0)"; FAIL=1; fi
if [ "$SIG_RTL" != "$SIG_ORA" ]; then
    echo "FIRMAS DIFIEREN: oraculo $SIG_ORA vs RTL $SIG_RTL"; FAIL=1
else
    echo "FIRMA BIT-IDENTICA: $SIG_RTL"
fi

for M in 1 2 3; do
    echo "== Mutacion MUT=$M (debe FALLAR) =="
    (cd $WORK && ghdl -r --std=08 --workdir=. tb_fp32_fma -gMUT=$M -gVEC_FILE=vectors_fma.txt) \
        > $WORK/run_mut$M.log 2>&1
    RC=$?
    grep -o 'ERRORES=[0-9]*' $WORK/run_mut$M.log
    if [ $RC -eq 0 ]; then
        echo "MUT=$M NO FUE DETECTADA — capa insuficiente"; FAIL=1
    else
        echo "MUT=$M detectada correctamente"
    fi
done

echo "=================================================="
if [ $FAIL -eq 0 ]; then
    echo "CAPA 1A: PASS ($(grep -oE 'T=[0-9]+ *[a-z]+' $WORK/run_mut0.log | head -1))"
else
    echo "CAPA 1A: FALLO"
fi
exit $FAIL
