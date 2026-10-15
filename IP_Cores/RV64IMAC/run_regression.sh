#!/bin/bash
# run_regression.sh - regresion completa del RV64IMAC (Pasos 1-7).
#   Capa 0  ISS vs riscv-tests y ISS vs Spike
#   Capa 1  unidades: decompresor RVC exhaustivo, mul/div
#   Capa 2  lockstep RTL vs ISS, memoria ideal
#   Capa 3  lockstep con latencias y ready aleatorios (1..12)
#   Capa 3b CPU con I$/D$ + AXI4 (retardos aleatorios en los 5 canales), estres de caches
#   Capa 4  SoC completo desde la boot ROM: USART real de IP_Cores, PLIC, DMA + Zicbom
#   Dirigidos: barrido de CSRs, tormenta de interrupciones, irq en M, carrera de irq
#   Mutaciones: todas deben morir
# Uso: ./run_regression.sh [rapida]
set -u
cd "$(dirname "$0")"
T=sw/tests
FAST=${1:-}
WAIVE='pmpaddr|ma_data'                 # dependen de PMP / desalineados en HW (spec sec. 3)
MMU='NINGUNO'                                    # Paso 5: Sv39 integrado
fail=0
step() { printf '\n== %s\n' "$1"; }
check() { if [ "$1" -ne 0 ]; then echo "   -> FALLO"; fail=1; else echo "   -> OK"; fi; }

step "build"
RT=${RISCV_TESTS:-}
if [ -z "$RT" ] || [ ! -f "$RT/env/p/link.ld" ]; then
  echo "   falta RISCV_TESTS=<ruta a riscv-tests> (clon con --recursive: env/p/link.ld)"; exit 2
fi
RT=$(realpath "$RT")
{ sw/build_tests.sh "$RT" $T && sw/build_directed.sh "$RT" && python3 sw/bootrom/build_bootrom.py \
  && sim/build.sh; } > /tmp/r_build.txt 2>&1; r=$?
[ $r -ne 0 ] && grep -iE "error|not found|no such" /tmp/r_build.txt | head -10 | sed 's/^/   /'
check $r
[ -x sim/tb_core ] || { echo "   sin simuladores (sim/tb_*): ver /tmp/r_build.txt"; exit 1; }

ALL=$(ls $T/rv64* | grep -v '\.s$')
P=$(echo "$ALL" | grep -Ev "$WAIVE")                 # entornos p y v

step "capa 0: ISS vs riscv-tests (p y v)"
python3 iss64.py $(echo "$ALL" | grep -Ev "$WAIVE") > /tmp/r_iss.txt; r=$?
echo "   $(grep -c ^PASS /tmp/r_iss.txt) PASS"; check $r

SPIKE=${SPIKE:-$(command -v spike || true)}; export SPIKE
CM_ELF=$(ls sw/coremark/coremark_*.elf 2>/dev/null | head -1)   # opcional: sw/coremark/build.sh
if [ -n "$SPIKE" ] && [ -x "$SPIKE" ]; then
  step "capa 0: ISS vs Spike"
  n=0; bad=0
  for t in $(echo "$ALL" | grep -Ev 'ma_fetch|lrsc') sw/csr_sweep_spike sw/mmu_test sw/cbo_test sw/amo_lanes $CM_ELF; do
    python3 compare_spike.py $t > /dev/null || { bad=$((bad+1)); echo "   DIVERGE $t"; }
    n=$((n+1))
  done
  echo "   $((n-bad))/$n iguales a Spike"; check $bad
fi

step "capa 1: decompresor RVC (exhaustivo) y mul/div"
python3 tb/gen_rvc_vectors.py sim/rvc_vectors.txt && python3 tb/gen_muldiv_vectors.py sim/muldiv_vectors.txt > /dev/null
(cd sim && ./tb_rvc && ./tb_muldiv) 2>&1 | grep -o 'tb_[a-z]* [A-Z]* [a-z]*=[0-9]*' | sed 's/^/   /'
(cd sim && ./tb_rvc > /dev/null 2>&1 && ./tb_muldiv > /dev/null 2>&1); check $?

step "capa 2: lockstep RTL vs ISS, memoria ideal"
python3 compare.py $P sw/csr_sweep sw/irq_m sw/irq_race sw/mmu_test sw/cbo_test sw/amo_lanes > /tmp/r_l2.txt; r=$?
echo "   $(grep -c ^PASS /tmp/r_l2.txt)/$(wc -l < /tmp/r_l2.txt | tr -d ' ') PASS"; grep -v ^PASS /tmp/r_l2.txt | head -5; check $r
python3 compare.py --time-div 24 sw/irq_storm; check $?

step "capa 3: lockstep con latencia y ready aleatorios"
if [ "$FAST" = rapida ]; then CFGS="6:1"; else CFGS="3:11 3:12 7:21 7:22 12:31 12:32"; fi
for c in $CFGS; do
  lat=${c%%:*}; seed=${c##*:}
  python3 compare.py --maxlat $lat --seed $seed $P sw/irq_m sw/irq_race sw/mmu_test sw/amo_lanes > /tmp/r_l3.txt; r=$?
  python3 compare.py --maxlat $lat --seed $seed --time-div 24 sw/irq_storm >> /tmp/r_l3.txt || r=1
  echo "   maxlat=$lat seed=$seed: $(grep -c ^PASS /tmp/r_l3.txt)/$(grep -c '' /tmp/r_l3.txt) PASS"
  grep -v ^PASS /tmp/r_l3.txt | head -3
  [ $r -ne 0 ] && fail=1
done

step "capa 3b: CPU con caches + AXI4"
if [ "$FAST" = rapida ]; then CFGS="1:1"; else CFGS="1:1 6:5 12:6"; fi
for c in $CFGS; do
  lat=${c%%:*}; seed=${c##*:}
  python3 compare.py --tb cpu --maxlat $lat --seed $seed $P sw/irq_m sw/irq_race sw/mmu_test sw/cbo_test sw/amo_lanes > /tmp/r_c.txt; r=$?
  python3 compare.py --tb cpu --maxlat $lat --seed $seed --timeout 20000000 sw/cache_stress >> /tmp/r_c.txt || r=1
  echo "   maxlat=$lat seed=$seed: $(grep -c ^PASS /tmp/r_c.txt)/$(grep -c '' /tmp/r_c.txt) PASS"
  grep -v ^PASS /tmp/r_c.txt | head -3
  [ $r -ne 0 ] && fail=1
done

step "capa 4: SoC desde la boot ROM (USART real, PLIC, DMA + Zicbom)"
PS=$(echo "$P" | grep -- '-p-')                     # el entorno v no arranca en 0x8000_0000
for c in 1:1 6:7; do
  lat=${c%%:*}; seed=${c##*:}
  python3 compare.py --tb soc --maxlat $lat --seed $seed --timeout 2000000 sw/soc_usart sw/soc_dma sw/soc_timer sw/soc_plic sw/cbo_test $PS > /tmp/r_s.txt; r=$?
  echo "   maxlat=$lat seed=$seed: $(grep -c ^PASS /tmp/r_s.txt)/$(grep -c '' /tmp/r_s.txt) PASS"
  grep -v ^PASS /tmp/r_s.txt | head -3
  [ $r -ne 0 ] && fail=1
done

if [ "$FAST" != rapida ]; then
  step "mutaciones (todas deben morir)"
  python3 mutate.py; check $?
fi

echo
if [ $fail -eq 0 ]; then echo "REGRESION OK"; else echo "REGRESION CON FALLOS"; fi
exit $fail
