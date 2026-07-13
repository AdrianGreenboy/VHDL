#!/bin/bash
# ============================================================================
# run_l2_regfile.sh — Capa 2 del IP ADCS: contrato MMIO del reg file.
# PASS global: genuina con ERRORES=0 y firma == oraculo; las tres mutaciones
# DEBEN fallar:
#   MUT=1 rdata registrado  -> viola el contrato combinacional (lw desfasado)
#   MUT=2 START no auto-clear-> el pulso se vuelve nivel (relee CTRL con START=1)
#   MUT=3 DONE clear-on-read -> reintroduce la carrera de polling infinito
# ============================================================================
set -u
cd "$(dirname "$0")"
RTL=../rtl
MODEL=../model
WORK=work_l2
mkdir -p $WORK

echo "== Generando secuencia con el oraculo =="
python3 $MODEL/regfile_model.py $WORK/regseq.txt | tee $WORK/oracle.log
SIG_ORA=$(grep -o 'FIRMA_ORACULO=0x[0-9A-F]*' $WORK/oracle.log | cut -d= -f2)

echo "== Analisis GHDL =="
ghdl -a --std=08 --workdir=$WORK $RTL/riscv_pkg.vhd $RTL/adcs_pkg.vhd $RTL/adcs_regfile.vhd \
    tb_adcs_regfile.vhd || exit 1
ghdl -e --std=08 --workdir=$WORK tb_adcs_regfile || exit 1

FAIL=0
run () {  # $1=MUT
    (cd $WORK && ghdl -r --std=08 --workdir=. tb_adcs_regfile \
        -gMUT=$1 -gSEQ_FILE=regseq.txt) > $WORK/run_mut$1.log 2>&1
    RC=$?
    SIG=$(grep -o 'FIRMA_L2=0x[0-9A-F]*' $WORK/run_mut$1.log | cut -d= -f2)
}

echo "== Genuina (MUT=0) =="
run 0
grep -oE 'ERRORES=[0-9]+ FIRMA_L2=0x[0-9A-F]+ T=[0-9]+ *[a-z]+' $WORK/run_mut0.log
if [ $RC -ne 0 ]; then echo "GENUINA: FALLO"; FAIL=1; fi
if [ "$SIG" != "$SIG_ORA" ]; then
    echo "FIRMAS DIFIEREN: oraculo $SIG_ORA vs RTL $SIG"; FAIL=1
else
    echo "FIRMA BIT-IDENTICA: $SIG"
fi

for M in 1 2 3; do
    echo "== MUT=$M (debe FALLAR) =="
    run $M
    if [ $RC -eq 0 ]; then echo "MUT=$M NO detectada — capa insuficiente"; FAIL=1
    else echo "MUT=$M detectada correctamente"; fi
done

echo "=================================================="
if [ $FAIL -eq 0 ]; then
    echo "CAPA 2: PASS ($(grep -oE 'T=[0-9]+ *[a-z]+' $WORK/run_mut0.log | tail -1))"
else
    echo "CAPA 2: FALLO"
fi
exit $FAIL
