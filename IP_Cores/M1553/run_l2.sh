#!/bin/bash
# Capa 2 del IP MIL-STD-1553: run limpio (firma) + 6 mutaciones del MMIO.
# Requiere bajo ~/m1553_ip:
#   rtl/{m1553_word_tx,m1553_word_rx,m1553_rt_core,m1553_bc_core,m1553_mmio}.vhd
#   tb/tb_m1553_l2.vhd
#   ~/spw_ip/spw_fifo.vhd (o ajusta FIFO abajo)
# Firma esperada: 615665ns.
set -u
cd "$(dirname "$0")"

FIFO="${FIFO:-$HOME/spw_ip/spw_fifo.vhd}"
[ -f "$FIFO" ] || FIFO="./spw_fifo.vhd"
[ -f "$FIFO" ] || { echo "No encuentro spw_fifo.vhd (exporta FIFO=/ruta)"; exit 1; }

echo "=== RUN LIMPIO (firma esperada: 615665ns) ==="
( rm -rf sim_l2 && mkdir -p sim_l2 && cd sim_l2 && \
  ghdl -a --std=08 "$FIFO" ../rtl/m1553_word_tx.vhd ../rtl/m1553_word_rx.vhd \
       ../rtl/m1553_rt_core.vhd ../rtl/m1553_bc_core.vhd ../rtl/m1553_mmio.vhd \
       ../tb/tb_m1553_l2.vhd && \
  ghdl -e --std=08 tb_m1553_l2 && \
  ghdl -r --std=08 tb_m1553_l2 ) || { echo "FALLO RUN LIMPIO"; exit 1; }

echo
echo "=== MUTACIONES DEL MMIO (todas deben FALLAR) ==="
for m in 1 2 3 4 5 6; do
  d=mut/l2_m$m; rm -rf $d; mkdir -p $d; cp rtl/m1553_mmio.vhd $d/
  case $m in
    1) sed -i 's/irq <= or (stat_v and irqen_r);/irq <= or (stat_v and (not irqen_r));/' $d/m1553_mmio.vhd
       desc="mascara IRQ negada";;
    2) sed -i 's/stk <= (others => .0.);           -- limpiar stickies.../null;/' $d/m1553_mmio.vhd
       desc="STAT no limpia stickies";;
    3) sed -i 's/rxf_rd <= sel and (not we) and sel_rxd and (not rxf_empty);/rxf_rd <= '"'"'0'"'"';/' $d/m1553_mmio.vhd
       desc="RXD sin pop-on-read";;
    4) python3 - $d/m1553_mmio.vhd <<'EOF'
import sys
p=sys.argv[1]; s=open(p).read()
old="  rxf_wr <= bc_rxwe or rt0_rxwe or rt1_rxwe or skid_v;"
new="  rxf_wr <= bc_rxwe or rt0_rxwe or rt1_rxwe;  -- MUTACION"
assert old in s; open(p,'w').write(s.replace(old,new))
EOF
       desc="skid del broadcast eliminado";;
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
