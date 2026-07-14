#!/bin/bash
# Mutaciones obligatorias capa 2 tsn_regs: las 5 deben FALLAR
cd "$(dirname "$0")"
ok=0
for m in 1 2 3 4 5; do
  cp tsn_regs.vhd mutr.vhd
  case $m in
    1) sed -i 's/  p_rd : process(all)/  p_rd : process(clk)/' mutr.vhd; d="M1 rdata registrado";;
    2) sed -i 's/tbl_port <= mac_hi_r(17 downto 16);/tbl_port <= mac_hi_r(18 downto 17);/' mutr.vhd; d="M2 campo puerto desplazado";;
    3) sed -i "s/if rst = '1' or cnt_clr = '1' then/if rst = '1' then/" mutr.vhd; d="M3 cnt_clear ignorado";;
    4) sed -i 's/pulses <= p_tag \& p_fcs \& p_ovf \& p_tx \& p_rx;/pulses <= p_tag \& p_fcs \& p_ovf \& p_rx \& p_tx;/' mutr.vhd; d="M4 contadores rx-tx cruzados";;
    5) sed -i 's/when 9x"008" => mac_lo_r <= wdata;/when 9x"008" => mac_lo_r <= wdata; tbl_wr_r <= '"'"'1'"'"';/' mutr.vhd; d="M5 MAC_LO dispara tabla";;
  esac
  if diff -q tsn_regs.vhd mutr.vhd >/dev/null; then echo "$d: SED NO APLICO - ERROR"; continue; fi
  ghdl -a --std=08 -Wno-hide mutr.vhd tb_tsn_regs.vhd >/dev/null 2>&1
  ghdl -e --std=08 tb_tsn_regs >/dev/null 2>&1
  if timeout 120 ghdl -r --std=08 tb_tsn_regs >/dev/null 2>&1; then
    echo "$d: PASO (MUTACION NO DETECTADA - TB DEBIL)"
  else
    echo "$d: FALLO como debe"; ok=$((ok+1))
  fi
done
rm -f mutr.vhd
ghdl -a --std=08 -Wno-hide tsn_regs.vhd tb_tsn_regs.vhd >/dev/null 2>&1
[ $ok -eq 5 ] && echo "MUTACIONES 5/5 OK" || { echo "MUTACIONES $ok/5"; exit 1; }
