#!/bin/bash
# Capa 1d del IP MIL-STD-1553 (audit 2026-11): bus dual A/B, comando que
# reemplaza, validacion de mensajes, underflow, flags de status, timeouts.
# Run limpio + 10 mutaciones (cada una revierte UN arreglo; todas deben FALLAR).
# Firma esperada: 1288526ns.
set -u
cd "$(dirname "$0")"

SRC="../rtl/m1553_word_tx.vhd ../rtl/m1553_word_rx.vhd"

echo "=== RUN LIMPIO (firma esperada: 1288526ns) ==="
( rm -rf sim_1d && mkdir -p sim_1d && cd sim_1d && \
  ghdl -a --std=08 $SRC ../rtl/m1553_rt_core.vhd ../rtl/m1553_bc_core.vhd \
       ../tb/tb_m1553_1d.vhd && \
  ghdl -e --std=08 tb_m1553_1d && \
  ghdl -r --std=08 tb_m1553_1d ) || { echo "FALLO RUN LIMPIO"; exit 1; }

echo
echo "=== MUTACIONES (todas deben FALLAR) ==="
for m in 1 2 3 4 5 6 7 8 9 10; do
  d=mut/d_m$m; rm -rf $d; mkdir -p $d
  cp rtl/m1553_rt_core.vhd rtl/m1553_bc_core.vhd $d/
  case $m in
    1) f=m1553_rt_core.vhd; o="          v_sup := true;"; n="          v_sup := false;"
       desc="sin comando que reemplaza en el otro bus";;
    2) f=m1553_rt_core.vhd; o="            if wrx_busy = '1' or v_dat or v_err then"; n="            if false then"
       desc="sin guarda del hueco de respuesta (word count high)";;
    3) f=m1553_rt_core.vhd; o="      v_ign := v_bc and v_tr = '1' and not (v_mode and v_wc = \"00001\");"; n="      v_ign := false;"
       desc="broadcast ilegal no se ignora";;
    4) f=m1553_rt_core.vhd; o="              if n_left > 0 and tx_empty = '1' then"; n="              if false then"
       desc="RT responde con FIFO TX vacio";;
    5) f=m1553_bc_core.vhd; o="              elsif tx_empty = '1' then"; n="              elsif false then"
       desc="BC sin deteccion de underflow";;
    6) f=m1553_rt_core.vhd; o="                             & st_busy & st_ssf & '0' & st_tf;"; n="                             & \"0000\";"
       desc="bits Busy/SSF/TF cableados a 0";;
    7) f=m1553_bc_core.vhd; o="              serr_r <= '1';                          -- word error on the status"; n="              serr_r <= '0'; st <= S_WST1;"
       desc="error de palabra en el status ignorado";;
    8) f=m1553_bc_core.vhd; o="            -- timeout deferred by a word in reception, at most one word time
            if tmo < 4095 then"; n="            if wrx_busy = '1' then
              tmo <= 0;
            elsif tmo < 4095 then"
       desc="timeout bloqueable por basura continua";;
    9) f=m1553_rt_core.vhd; o="              txbus_r <= cbus_r;                      -- answer on the command bus"; n="              txbus_r <= '0';"
       desc="RT responde siempre por el bus A";;
    10) f=m1553_rt_core.vhd; o="              if drop_r = '0' and busy_r = '0' then"; n="              if drop_r = '0' then"
       desc="Busy no suprime el almacenamiento de datos";;
  esac
  python3 - "$d/$f" "$o" "$n" <<'PYEND' || { echo "MD$m: sitio de mutacion no encontrado"; exit 1; }
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
assert s.count(old) == 1, s.count(old)
open(p, 'w').write(s.replace(old, new))
PYEND
  ( cd $d && ghdl -a --std=08 ../../rtl/m1553_word_tx.vhd ../../rtl/m1553_word_rx.vhd \
      m1553_rt_core.vhd m1553_bc_core.vhd ../../tb/tb_m1553_1d.vhd >/dev/null 2>&1 && \
    ghdl -e --std=08 tb_m1553_1d >/dev/null 2>&1 && \
    timeout 600 ghdl -r --std=08 tb_m1553_1d > run.log 2>&1 )
  if [ $? -ne 0 ] && grep -q FALLO $d/run.log; then
    echo "MD$m ($desc): FALLA como debe -> $(grep -m1 -oE 'FALLO[^\"]*' $d/run.log)"
  else
    echo "MD$m ($desc): *** NO FALLO — EL BANCO NO TIENE DIENTES ***"; exit 1
  fi
done
echo
echo "CAPA 1D COMPLETA"
