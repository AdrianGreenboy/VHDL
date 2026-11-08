#!/bin/bash
# run_regression.sh - regresion del RV128IMAC (experimental).
#   Capa 0   ISS: todas las pruebas autoverificables pasan en iss128.py
#   Capa 0b  ISS vs QEMU x-rv128 (oraculo independiente), si hay QEMU
#   Capa 1   unidades: decompresor RV128C exhaustivo, mul/div 128/64/32
#   Capa 2   lockstep RTL vs ISS, memoria ideal
#   Capa 3   lockstep con latencias y ready aleatorios (1..12)
# Uso: ./run_regression.sh [rapida]      Log completo: sim/regression.log
set -u
cd "$(dirname "$0")"
FAST=${1:-}
LOG=sim/regression.log
: > $LOG
fail=0
step() { printf '\n== %s\n' "$1" | tee -a $LOG; }
check() { if [ "$1" -ne 0 ]; then echo "   -> FALLO" | tee -a $LOG; fail=1; else echo "   -> OK" | tee -a $LOG; fi; }

step "build (pruebas + GHDL)"
{ sw/build_tests.sh && sim/build.sh; } >> $LOG 2>&1; r=$?
check $r
[ $r -eq 0 ] || { echo "   build fallido (ver $LOG)"; exit 1; }

T=sw/tests
ALL=$(ls $T/*.bin | sed 's/\.bin$//')
QL=$(sed "s#^#$T/#" $T/QEMU_LIST; ls $T/rndq_*.bin | sed 's/\.bin$//')

step "capa 0: ISS, pruebas autoverificables"
python3 iss128.py $ALL > /tmp/r128_iss.txt 2>&1; r=$?
cat /tmp/r128_iss.txt >> $LOG
echo "   $(grep -c ^PASS /tmp/r128_iss.txt)/$(echo "$ALL" | wc -w) PASS"; grep -v '^PASS' /tmp/r128_iss.txt | grep -E '^(FAIL|TIMEOUT)' | head -5
check $r

QEMU=${QEMU:-$(command -v qemu-system-riscv64 || true)}
if [ -n "$QEMU" ]; then
  step "capa 0b: ISS vs QEMU x-rv128"
  QEMU=$QEMU python3 sw/qemu_check.py $QL > /tmp/r128_q.txt 2>&1; r=$?
  cat /tmp/r128_q.txt >> $LOG
  echo "   $(grep -c ^IGUAL /tmp/r128_q.txt)/$(echo "$QL" | wc -w) iguales"; grep -v ^IGUAL /tmp/r128_q.txt | head -8
  check $r
fi

step "capa 1: decompresor RV128C (exhaustivo) y mul/div"
python3 tb/gen_rvc_vectors.py sim/rvc_vectors.txt && python3 tb/gen_muldiv_vectors.py sim/muldiv_vectors.txt >> $LOG
(cd sim && ./tb_rvc && ./tb_muldiv) > /tmp/r128_u.txt 2>&1; r=$?
cat /tmp/r128_u.txt >> $LOG
grep -o 'tb_[a-z]* [A-Z]* [a-z]*=[0-9]*' /tmp/r128_u.txt | sed 's/^/   /'
check $r

step "capa 2: lockstep RTL vs ISS, memoria ideal"
python3 compare128.py $ALL > /tmp/r128_l2.txt 2>&1; r=$?
cat /tmp/r128_l2.txt >> $LOG
echo "   $(grep -c ^PASS /tmp/r128_l2.txt)/$(echo "$ALL" | wc -w) PASS"; grep -v ^PASS /tmp/r128_l2.txt | head -6
check $r

step "capa 3: lockstep con latencia y ready aleatorios"
if [ "$FAST" = rapida ]; then CFGS="6:1"; else CFGS="3:11 7:21 12:31"; fi
for c in $CFGS; do
  lat=${c%%:*}; seed=${c##*:}
  python3 compare128.py --maxlat $lat --seed $seed $ALL > /tmp/r128_l3.txt 2>&1; r=$?
  cat /tmp/r128_l3.txt >> $LOG
  echo "   maxlat=$lat seed=$seed: $(grep -c ^PASS /tmp/r128_l3.txt)/$(echo "$ALL" | wc -w) PASS" | tee -a $LOG
  grep -v ^PASS /tmp/r128_l3.txt | head -4
  [ $r -ne 0 ] && fail=1
done

step "capa 4: prototipo FPGA (rv128_proto_top) en simulacion, como lo carga el A72"
python3 fpga/board_check.py sim $ALL > /tmp/r128_l4.txt 2>&1; r=$?
cat /tmp/r128_l4.txt >> $LOG
echo "   $(grep -c ^PASS /tmp/r128_l4.txt)/$(echo "$ALL" | wc -w) PASS"; grep -v ^PASS /tmp/r128_l4.txt | head -6
check $r

echo
if [ $fail -eq 0 ]; then echo "REGRESION OK" | tee -a $LOG; else echo "REGRESION CON FALLOS" | tee -a $LOG; fi
exit $fail
