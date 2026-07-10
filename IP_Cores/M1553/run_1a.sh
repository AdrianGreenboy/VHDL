#!/bin/bash
# Capa 1a del IP MIL-STD-1553: run limpio (firma) + 5 mutaciones con dientes.
# Uso: colocar rtl/m1553_word_tx.vhd y tb/tb_m1553_1a.vhd bajo ~/m1553_ip y
# ejecutar este script desde ~/m1553_ip. Firma esperada: 400485ns.
set -u
cd "$(dirname "$0")"

echo "=== RUN LIMPIO (firma esperada: 400485ns) ==="
( rm -rf sim && mkdir -p sim && cd sim && \
  ghdl -a --std=08 ../rtl/m1553_word_tx.vhd ../tb/tb_m1553_1a.vhd && \
  ghdl -e --std=08 tb_m1553_1a && \
  ghdl -r --std=08 tb_m1553_1a ) || { echo "FALLO RUN LIMPIO"; exit 1; }

echo
echo "=== MUTACIONES (todas deben FALLAR) ==="
for m in 1 2 3 4 5; do
  d=mut/m$m; rm -rf $d; mkdir -p $d; cp rtl/m1553_word_tx.vhd $d/
  case $m in
    1) sed -i "s/variable p : std_logic := '1';/variable p : std_logic := '0';/" $d/m1553_word_tx.vhd
       desc="paridad PAR en vez de IMPAR";;
    2) sed -i "s/CYCLES_PER_HALFBIT : integer := 50/CYCLES_PER_HALFBIT : integer := 49/" $d/m1553_word_tx.vhd
       desc="semibit de 49 ciclos";;
    3) sed -i "s/      return f_wt;                  -- sync: primera mitad/      return not f_wt;              -- sync: primera mitad/" $d/m1553_word_tx.vhd
       desc="sync roto";;
    4) python3 - $d/m1553_word_tx.vhd <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
old = """      if ((nhb - 6) mod 2) = 0 then
        return b;                   -- '1' = alto->bajo
      else
        return not b;
      end if;"""
new = """      if ((nhb - 6) mod 2) = 0 then
        return not b;               -- MUTACION: polaridad invertida
      else
        return b;
      end if;"""
assert old in s
open(p,'w').write(s.replace(old,new))
EOF
       desc="polaridad de bit invertida";;
    5) sed -i "s/if hb = 39 then/if hb = 38 then/" $d/m1553_word_tx.vhd
       desc="palabra corta (39 semibits)";;
  esac
  ( cd $d && ghdl -a --std=08 m1553_word_tx.vhd ../../tb/tb_m1553_1a.vhd >/dev/null 2>&1 && \
    ghdl -e --std=08 tb_m1553_1a >/dev/null 2>&1 && \
    ghdl -r --std=08 tb_m1553_1a > run.log 2>&1 )
  if [ $? -ne 0 ] && grep -q FALLO $d/run.log; then
    echo "M$m ($desc): FALLA como debe -> $(grep -m1 -oE 'FALLO[^\"]*' $d/run.log)"
  else
    echo "M$m ($desc): *** NO FALLO — EL BANCO NO TIENE DIENTES ***"; exit 1
  fi
done
echo
echo "CAPA 1A COMPLETA"
