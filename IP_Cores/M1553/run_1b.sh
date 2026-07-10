#!/bin/bash
# Capa 1b del IP MIL-STD-1553: run limpio (firma) + 5 mutaciones del RX.
# Uso: rtl/m1553_word_rx.vhd y tb/tb_m1553_1b.vhd bajo ~/m1553_ip, ejecutar
# desde ~/m1553_ip. Firma esperada: 462205ns.
set -u
cd "$(dirname "$0")"

echo "=== RUN LIMPIO (firma esperada: 462205ns) ==="
( rm -rf sim_1b && mkdir -p sim_1b && cd sim_1b && \
  ghdl -a --std=08 ../rtl/m1553_word_rx.vhd ../tb/tb_m1553_1b.vhd && \
  ghdl -e --std=08 tb_m1553_1b && \
  ghdl -r --std=08 tb_m1553_1b ) || { echo "FALLO RUN LIMPIO"; exit 1; }

echo
echo "=== MUTACIONES DEL RX (todas deben FALLAR) ==="
for m in 1 2 3 4 5; do
  d=mut/rx_m$m; rm -rf $d; mkdir -p $d; cp rtl/m1553_word_rx.vhd $d/
  case $m in
    1) sed -i "s/if par = '1' then/if par = '0' then/" $d/m1553_word_rx.vhd
       desc="aceptacion de paridad invertida";;
    2) sed -i "s/RUN_MIN : integer := 125/RUN_MIN : integer := 60/" $d/m1553_word_rx.vhd
       desc="ventana de sync relajada";;
    3) sed -i "s/              if q2 = wt_i then/              if false then/" $d/m1553_word_rx.vhd
       desc="check de segunda mitad del sync anulado";;
    4) sed -i "s/              if q2 = s0_r then/              if false then/" $d/m1553_word_rx.vhd
       desc="check Manchester anulado";;
    5) sed -i "s/word_type <= wt_i;/word_type <= not wt_i;/" $d/m1553_word_rx.vhd
       desc="tipo de palabra invertido";;
  esac
  ( cd $d && ghdl -a --std=08 m1553_word_rx.vhd ../../tb/tb_m1553_1b.vhd >/dev/null 2>&1 && \
    ghdl -e --std=08 tb_m1553_1b >/dev/null 2>&1 && \
    ghdl -r --std=08 tb_m1553_1b > run.log 2>&1 )
  if [ $? -ne 0 ] && grep -q FALLO $d/run.log; then
    echo "MB$m ($desc): FALLA como debe -> $(grep -m1 -oE 'FALLO[^\"]*' $d/run.log)"
  else
    echo "MB$m ($desc): *** NO FALLO — EL BANCO NO TIENE DIENTES ***"; exit 1
  fi
done
echo
echo "CAPA 1B COMPLETA"
