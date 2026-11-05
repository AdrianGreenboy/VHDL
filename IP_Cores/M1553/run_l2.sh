#!/bin/bash
# Capa 2 del IP MIL-STD-1553: run limpio (firma) + 6 mutaciones del MMIO.
# Requiere bajo ~/m1553_ip:
#   rtl/{m1553_word_tx,m1553_word_rx,m1553_rt_core,m1553_bc_core,m1553_mmio}.vhd
#   tb/tb_m1553_l2.vhd
#   rtl/m1553_fifo.vhd (FIFO propio del IP desde el audit 2026-11)
# Firma esperada: 780885ns.
set -u
cd "$(dirname "$0")"

FIFO="$(pwd)/rtl/m1553_fifo.vhd"

echo "=== RUN LIMPIO (firma esperada: 780885ns) ==="
( rm -rf sim_l2 && mkdir -p sim_l2 && cd sim_l2 && \
  ghdl -a --std=08 "$FIFO" ../rtl/m1553_word_tx.vhd ../rtl/m1553_word_rx.vhd \
       ../rtl/m1553_rt_core.vhd ../rtl/m1553_bc_core.vhd ../rtl/m1553_mmio.vhd \
       ../tb/tb_m1553_l2.vhd && \
  ghdl -e --std=08 tb_m1553_l2 && \
  ghdl -r --std=08 tb_m1553_l2 ) || { echo "FALLO RUN LIMPIO"; exit 1; }

echo
echo "=== MUTACIONES DEL MMIO (todas deben FALLAR) ==="
for m in 1 2 3 4 5 6 7 8; do
  d=mut/l2_m$m; rm -rf $d; mkdir -p $d; cp rtl/m1553_mmio.vhd $d/
  case $m in
    1) sed -i 's/irq <= or (stat_v and irqen_r);/irq <= or (stat_v and (not irqen_r));/' $d/m1553_mmio.vhd
       desc="mascara IRQ negada";;
    2) sed -i 's/stk <= stk and not wdata(28 downto 16);/null;/' $d/m1553_mmio.vhd
       desc="STAT no limpia stickies";;
    3) sed -i 's/rxf_rd <= sel and (not we) and sel_rxd and (not rxf_empty);/rxf_rd <= '"'"'0'"'"';/' $d/m1553_mmio.vhd
       desc="RXD sin pop-on-read";;
    4) python3 - $d/m1553_mmio.vhd <<'EOF'
import sys
p=sys.argv[1]; s=open(p).read()
old="        if rt1_rxwe = '1' and vn < 4 then"
new="        if false then  -- MUTACION"
assert old in s; open(p,'w').write(s.replace(old,new))
EOF
       desc="cola RX: se pierde la copia de RT1 en broadcast";;
    5) python3 - $d/m1553_mmio.vhd <<'EOF'
import sys
p=sys.argv[1]; s=open(p).read()
old="      rxf_head(0) & rxf_head(5 downto 1) & rxf_head(7 downto 6) & rxf_head(23 downto 8)"
new="      rxf_head  -- MUTACION"
assert old in s; open(p,'w').write(s.replace(old,new))
EOF
       desc="desempaquetado de RXD roto";;
    6) sed -i 's/if bc_done = .1. and bc_ok   = .1. then stk(1) <= .1.; end if;/null;/' $d/m1553_mmio.vhd
       desc="sticky OK nunca se pone";;
    7) sed -i 's/stk <= stk and not wdata(28 downto 16);/stk <= (others => '"'"'0'"'"');/' $d/m1553_mmio.vhd
       desc="STAT limpia todo con cualquier escritura (no W1C)";;
    8) sed -i "s/        if bc_rxwe = '1' and vn < 4 then/        if false then/" $d/m1553_mmio.vhd
       desc="cola RX: se pierde la copia monitorizada por el BC (RT->RT)";;
  esac
  ( cd $d && ghdl -a --std=08 "$FIFO" ../../rtl/m1553_word_tx.vhd ../../rtl/m1553_word_rx.vhd \
      ../../rtl/m1553_rt_core.vhd ../../rtl/m1553_bc_core.vhd m1553_mmio.vhd \
      ../../tb/tb_m1553_l2.vhd >/dev/null 2>&1 && \
    ghdl -e --std=08 tb_m1553_l2 >/dev/null 2>&1 && \
    timeout 600 ghdl -r --std=08 tb_m1553_l2 > run.log 2>&1 )
  if [ $? -ne 0 ] && grep -q FALLO $d/run.log; then
    echo "ML2-$m ($desc): FALLA como debe -> $(grep -m1 -oE 'FALLO[^\"]*' $d/run.log)"
  else
    echo "ML2-$m ($desc): *** NO FALLO — SIN DIENTES ***"; exit 1
  fi
done
echo
echo "CAPA 2 COMPLETA"
