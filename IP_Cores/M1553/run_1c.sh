#!/bin/bash
# Capa 1c del IP MIL-STD-1553: run limpio (firma) + 5 mutaciones de los
# nucleos BC/RT. Requiere rtl/{m1553_word_tx,m1553_word_rx,m1553_rt_core,
# m1553_bc_core}.vhd y tb/tb_m1553_1c.vhd bajo ~/m1553_ip.
# OJO: m1553_word_tx.vhd es la version con puerto 'loaded' (la firma de la
# capa 1a NO cambia: 400485ns). Firma esperada de 1c: 1679825ns.
set -u
cd "$(dirname "$0")"

echo "=== RUN LIMPIO (firma esperada: 1679825ns) ==="
( rm -rf sim_1c && mkdir -p sim_1c && cd sim_1c && \
  ghdl -a --std=08 ../rtl/m1553_word_tx.vhd ../rtl/m1553_word_rx.vhd \
       ../rtl/m1553_rt_core.vhd ../rtl/m1553_bc_core.vhd ../tb/tb_m1553_1c.vhd && \
  ghdl -e --std=08 tb_m1553_1c && \
  ghdl -r --std=08 tb_m1553_1c ) || { echo "FALLO RUN LIMPIO"; exit 1; }

echo
echo "=== MUTACIONES DE LOS NUCLEOS (todas deben FALLAR) ==="
for m in 1 2 3 4 5; do
  d=mut/c_m$m; rm -rf $d; mkdir -p $d
  cp rtl/m1553_rt_core.vhd rtl/m1553_bc_core.vhd $d/
  case $m in
    1) sed -i "s/RESP_DELAY : integer := 425/RESP_DELAY : integer := 1600/" $d/m1553_rt_core.vhd
       desc="respuesta del RT fuera de ventana";;
    2) python3 - $d/m1553_rt_core.vhd <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
old = """                elsif bcast_r = '1' then
                  ev_ok <= '1';                       -- broadcast: sin respuesta
                  st    <= S_IDLE;"""
new = """                elsif false then
                  ev_ok <= '1';                       -- MUTACION: responde a broadcast
                  st    <= S_IDLE;"""
assert old in s
open(p,'w').write(s.replace(old,new))
EOF
       desc="el RT responde a broadcast";;
    3) sed -i "s/GAP_CYCLES  : integer := 400/GAP_CYCLES  : integer := 100/" $d/m1553_bc_core.vhd
       desc="hueco intermensaje del BC de ~1us";;
    4) python3 - $d/m1553_bc_core.vhd <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
old = """              if m_rtrt = '1' then
                v_ns := v_ns + 1;"""
new = """              if m_rtrt = '1' then
                null;  -- MUTACION: no emite cmd2"""
assert old in s
open(p,'w').write(s.replace(old,new))
EOF
       desc="BC omite el cmd2 del RT->RT";;
    5) sed -i 's/wtx_data  <= rt_addr \& me_f/wtx_data  <= (not rt_addr) \& me_f/' $d/m1553_rt_core.vhd
       desc="direccion del status invertida";;
  esac
  ( cd $d && ghdl -a --std=08 ../../rtl/m1553_word_tx.vhd ../../rtl/m1553_word_rx.vhd \
      m1553_rt_core.vhd m1553_bc_core.vhd ../../tb/tb_m1553_1c.vhd >/dev/null 2>&1 && \
    ghdl -e --std=08 tb_m1553_1c >/dev/null 2>&1 && \
    timeout 600 ghdl -r --std=08 tb_m1553_1c > run.log 2>&1 )
  if [ $? -ne 0 ] && grep -q FALLO $d/run.log; then
    echo "MC$m ($desc): FALLA como debe -> $(grep -m1 -oE 'FALLO[^\"]*' $d/run.log)"
  else
    echo "MC$m ($desc): *** NO FALLO — EL BANCO NO TIENE DIENTES ***"; exit 1
  fi
done
echo
echo "CAPA 1C COMPLETA"
