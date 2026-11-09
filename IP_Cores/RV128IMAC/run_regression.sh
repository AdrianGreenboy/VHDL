#!/bin/bash
# run_regression.sh - regresion del RV128IMAC (experimental).
#   Capa 0   ISS: todas las pruebas autoverificables pasan en iss128.py
#   Capa 0b  ISS vs QEMU x-rv128 (oraculo independiente), si hay QEMU
#   Capa 1   unidades: decompresor RV128C exhaustivo, mul/div 128/64/32
#   Capa 2   lockstep RTL vs ISS, memoria ideal
#   Capa 3   lockstep con latencias y ready aleatorios (1..12)
#   Capa 3b  CPU con I$/D$ + AXI4 de 128 bit (retardos aleatorios en los 5 canales), estres de caches
#   Capa 4   prototipo FPGA en simulacion
#   Capa 4b  SoC completo desde la boot ROM (CLINT, PLIC, UART 16550, USART real de IP_Cores)
#   Capa 5   modo RV64 del core dual: lockstep contra iss64.py (sin cambios) con los
#            riscv-tests p/v y los dirigidos del RV64IMAC (necesita ../RV64IMAC/sw/tests,
#            que genera la regresion del RV64IMAC), en core, cpu (caches) y soc
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
{ sw/build_tests.sh && python3 sw/bootrom/build_bootrom.py && sim/build.sh; } >> $LOG 2>&1; r=$?
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

step "capa 1: decompresor RVC exhaustivo (RV128C y RV64C), mul/div y divisor de la UART"
python3 tb/gen_rvc_vectors.py sim/rvc_vectors.txt && python3 tb/gen_rvc_vectors.py sim/rvc64_vectors.txt --rv64 \
  && python3 tb/gen_muldiv_vectors.py sim/muldiv_vectors.txt >> $LOG
(cd sim && ./tb_rvc && ./tb_rvc -gVECTORS=rvc64_vectors.txt -gXLEN64=true && ./tb_muldiv && ./tb_uart) > /tmp/r128_u.txt 2>&1; r=$?
grep -q "tb_uart PASS" /tmp/r128_u.txt || r=1
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

step "capa 3b: CPU con caches + AXI4 128 (modo RV128)"
if [ "$FAST" = rapida ]; then CFGS="1:1"; else CFGS="1:1 6:5 12:6"; fi
for c in $CFGS; do
  lat=${c%%:*}; seed=${c##*:}
  python3 compare128.py --tb cpu --maxlat $lat --seed $seed $ALL > /tmp/r128_c.txt 2>&1; r=$?
  python3 compare128.py --tb cpu --maxlat $lat --seed $seed --timeout 20000000 sw/stress/cache_stress >> /tmp/r128_c.txt 2>&1 || r=1
  cat /tmp/r128_c.txt >> $LOG
  echo "   maxlat=$lat seed=$seed: $(grep -c ^PASS /tmp/r128_c.txt)/$(($(echo "$ALL" | wc -w) + 1)) PASS" | tee -a $LOG
  grep -v ^PASS /tmp/r128_c.txt | head -4
  [ $r -ne 0 ] && fail=1
done

step "capa 4: prototipo FPGA (rv128_proto_top) en simulacion, como lo carga el A72"
python3 fpga/board_check.py sim $ALL > /tmp/r128_l4.txt 2>&1; r=$?
cat /tmp/r128_l4.txt >> $LOG
echo "   $(grep -c ^PASS /tmp/r128_l4.txt)/$(echo "$ALL" | wc -w) PASS"; grep -v ^PASS /tmp/r128_l4.txt | head -6
check $r

if [ -x sim/tb_soc ] && [ sim/tb_soc -nt sim/tb_core ]; then
  step "capa 4b: SoC desde la boot ROM (modo RV128)"
  for c in 1:1 6:7; do
    lat=${c%%:*}; seed=${c##*:}
    python3 compare128.py --tb soc --maxlat $lat --seed $seed --timeout 4000000 $ALL > /tmp/r128_s.txt 2>&1; r=$?
    cat /tmp/r128_s.txt >> $LOG
    echo "   maxlat=$lat seed=$seed: $(grep -c ^PASS /tmp/r128_s.txt)/$(echo "$ALL" | wc -w) PASS" | tee -a $LOG
    grep -v ^PASS /tmp/r128_s.txt | head -4
    [ $r -ne 0 ] && fail=1
  done
else
  step "capa 4b: OMITIDA (tb_soc no compilado en esta build: falta IP_Cores/USART, ver $LOG)"
fi

R64=../RV64IMAC
if ls $R64/sw/tests/rv64ui-p-add > /dev/null 2>&1; then
  step "capa 5: modo RV64 del core dual vs iss64.py (riscv-tests p/v + dirigidos del RV64IMAC)"
  E64=$(ls $R64/sw/tests/rv64* | grep -v '\.s$' | grep -Ev 'pmpaddr|ma_data')
  D64=$(for t in csr_sweep irq_m irq_race mmu_test cbo_test amo_lanes; do [ -f $R64/sw/$t ] && echo $R64/sw/$t; done)
  python3 compare64.py $E64 $D64 > /tmp/r128_m64.txt 2>&1; r=$?
  cat /tmp/r128_m64.txt >> $LOG
  echo "   $(grep -c ^PASS /tmp/r128_m64.txt)/$(echo $E64 $D64 | wc -w) PASS"; grep -v ^PASS /tmp/r128_m64.txt | head -8
  check $r
  if [ "$FAST" != rapida ]; then
    python3 compare64.py --maxlat 7 --seed 21 $E64 $D64 > /tmp/r128_m64l.txt 2>&1; r=$?
    cat /tmp/r128_m64l.txt >> $LOG
    echo "   maxlat=7: $(grep -c ^PASS /tmp/r128_m64l.txt)/$(echo $E64 $D64 | wc -w) PASS" | tee -a $LOG
    grep -v ^PASS /tmp/r128_m64l.txt | head -4; [ $r -ne 0 ] && fail=1
  fi
  # caches + AXI4 128: mismos programas + estres de caches del RV64IMAC
  CS64=$(ls $R64/sw/cache_stress 2>/dev/null)
  if [ "$FAST" = rapida ]; then CFGS="1:1"; else CFGS="1:1 6:5 12:6"; fi
  for c in $CFGS; do
    lat=${c%%:*}; seed=${c##*:}
    python3 compare64.py --tb cpu --maxlat $lat --seed $seed $E64 $D64 > /tmp/r128_m64c.txt 2>&1; r=$?
    [ -n "$CS64" ] && { python3 compare64.py --tb cpu --maxlat $lat --seed $seed --timeout 20000000 $CS64 >> /tmp/r128_m64c.txt 2>&1 || r=1; }
    cat /tmp/r128_m64c.txt >> $LOG
    echo "   cpu maxlat=$lat seed=$seed: $(grep -c ^PASS /tmp/r128_m64c.txt)/$(echo $E64 $D64 $CS64 | wc -w) PASS" | tee -a $LOG
    grep -v ^PASS /tmp/r128_m64c.txt | head -4; [ $r -ne 0 ] && fail=1
  done
  # SoC desde la boot ROM: pruebas soc_* del RV64IMAC (USART real, PLIC, DMA + Zicbom) y riscv-tests p
  if [ -x sim/tb_soc ] && [ sim/tb_soc -nt sim/tb_core ]; then
    S64=$(for t in soc_usart soc_dma soc_timer soc_plic cbo_test; do [ -f $R64/sw/$t ] && echo $R64/sw/$t; done)
    PS64=$(echo "$E64" | grep -- '-p-')                  # el entorno v no arranca en 0x8000_0000
    for c in 1:1 6:7; do
      lat=${c%%:*}; seed=${c##*:}
      python3 compare64.py --tb soc --maxlat $lat --seed $seed --timeout 2000000 $S64 $PS64 > /tmp/r128_m64s.txt 2>&1; r=$?
      cat /tmp/r128_m64s.txt >> $LOG
      echo "   soc maxlat=$lat seed=$seed: $(grep -c ^PASS /tmp/r128_m64s.txt)/$(echo $S64 $PS64 | wc -w) PASS" | tee -a $LOG
      grep -v ^PASS /tmp/r128_m64s.txt | head -4; [ $r -ne 0 ] && fail=1
    done
  fi
else
  step "capa 5: OMITIDA (no hay riscv-tests compilados en $R64/sw/tests: corre antes la regresion del RV64IMAC)"
fi

echo
if [ $fail -eq 0 ]; then echo "REGRESION OK" | tee -a $LOG; else echo "REGRESION CON FALLOS" | tee -a $LOG; fi
exit $fail
