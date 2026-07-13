#!/bin/bash
# ============================================================================
# run_l1b_dot.sh — Capa 1b del IP ADCS: mpc_dot_row vs oraculo + mutaciones.
#
# PASS global:
#   * Genuinas con LAT_FMA=8 y LAT_FMA=20: ERRORES=0 y LA MISMA firma que el
#     oraculo (el orden de acumulacion no depende de la latencia del FMA).
#   * MUT=1 (sin interlock) con LAT=8: PASA — punto ciego documentado, es
#     exactamente el bug sim-OK/silicio-FALLA del Paso 1 de la tesis.
#   * MUT=1 con LAT=20 > NACC: DEBE FALLAR (el interlock es lo unico que
#     protege ante latencia efectiva mayor que NACC).
#   * MUT=2 (terminacion off-by-one) y MUT=3 (reduccion trunca): DEBEN FALLAR.
# ============================================================================
set -u
cd "$(dirname "$0")"
RTL=../rtl
MODEL=../model
WORK=work_l1b
mkdir -p $WORK

echo "== Generando vectores con el oraculo =="
python3 $MODEL/dot_oracle.py $WORK/vectors_dot.txt | tee $WORK/oracle.log
SIG_ORA=$(grep -o 'FIRMA_ORACULO=0x[0-9A-F]*' $WORK/oracle.log | cut -d= -f2)

echo "== Analisis GHDL =="
ghdl -a --std=08 --workdir=$WORK \
    $RTL/fp32_pkg.vhd $RTL/fp32_fma.vhd $RTL/adcs_pkg.vhd $RTL/mpc_dot_row.vhd \
    tb_mpc_dot_row.vhd || exit 1
ghdl -e --std=08 --workdir=$WORK tb_mpc_dot_row || exit 1

FAIL=0
run_tb () {  # $1=MUT $2=LAT  -> rc en $RC, firma en $SIG
    (cd $WORK && ghdl -r --std=08 --workdir=. tb_mpc_dot_row \
        -gMUT=$1 -gLAT_FMA=$2 -gVEC_FILE=vectors_dot.txt) \
        > $WORK/run_m$1_l$2.log 2>&1
    RC=$?
    SIG=$(grep -o 'FIRMA_L1B=0x[0-9A-F]*' $WORK/run_m$1_l$2.log | cut -d= -f2)
}

for L in 8 20; do
    echo "== Genuina (MUT=0, LAT_FMA=$L) =="
    run_tb 0 $L
    grep -oE 'ERRORES=[0-9]+ FIRMA_L1B=0x[0-9A-F]+ T=[0-9]+ *[a-z]+' $WORK/run_m0_l$L.log
    if [ $RC -ne 0 ]; then echo "GENUINA LAT=$L: FALLO"; FAIL=1; fi
    if [ "$SIG" != "$SIG_ORA" ]; then
        echo "FIRMAS DIFIEREN (LAT=$L): oraculo $SIG_ORA vs RTL $SIG"; FAIL=1
    else
        echo "FIRMA BIT-IDENTICA (LAT=$L): $SIG"
    fi
done

echo "== MUT=1 sin interlock, LAT=8 (punto ciego: se espera que PASE) =="
run_tb 1 8
if [ $RC -eq 0 ]; then
    echo "MUT=1/LAT=8 paso, como el bug real en sim — por eso existe LAT=20"
else
    echo "MUT=1/LAT=8 fallo (inesperado pero no es error de capa)"
fi

echo "== MUT=1 sin interlock, LAT=20 (debe FALLAR) =="
run_tb 1 20
if [ $RC -eq 0 ]; then echo "MUT=1 NO detectada con LAT=20 — capa insuficiente"; FAIL=1
else echo "MUT=1 detectada correctamente (hazard RMW con latencia > NACC)"; fi

for M in 2 3; do
    echo "== MUT=$M (debe FALLAR) =="
    run_tb $M 8
    if [ $RC -eq 0 ]; then echo "MUT=$M NO detectada — capa insuficiente"; FAIL=1
    else echo "MUT=$M detectada correctamente"; fi
done

echo "=================================================="
if [ $FAIL -eq 0 ]; then
    echo "CAPA 1B: PASS ($(grep -oE 'T=[0-9]+ *[a-z]+' $WORK/run_m0_l8.log | tail -1))"
else
    echo "CAPA 1B: FALLO"
fi
exit $FAIL
