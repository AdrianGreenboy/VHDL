#!/bin/bash
# Capa 4 del IP MIL-STD-1553: ISS (oraculo) + SoC RTL contra la firma del ISS.
# Requiere bajo ~/m1553_ip:
#   rtl/{m1553_word_tx,m1553_word_rx,m1553_rt_core,m1553_bc_core,m1553_mmio,
#        mem_subsys_m1553}.vhd
#   tb/{soc_stubs_l4,tb_m1553_l4}.vhd
#   sim/{iss_m1553.py, riscv_pkg.vhd, spw_fifo.vhd}
# riscv_pkg.vhd se copia de ~/rv32i/, spw_fifo.vhd de ~/spw_ip/ si no estan.
# Firma temporal esperada del RTL: 552845ns.
set -u
cd "$(dirname "$0")"

RISCV_PKG="${RISCV_PKG:-$HOME/rv32i/riscv_pkg.vhd}"
FIFO="${FIFO:-$HOME/spw_ip/spw_fifo.vhd}"
mkdir -p sim
[ -f sim/riscv_pkg.vhd ] || cp "$RISCV_PKG" sim/ 2>/dev/null || { echo "Falta riscv_pkg.vhd (exporta RISCV_PKG=/ruta)"; exit 1; }
[ -f sim/spw_fifo.vhd ]  || cp "$FIFO" sim/ 2>/dev/null || { echo "Falta spw_fifo.vhd (exporta FIFO=/ruta)"; exit 1; }

echo "=== ISS (genera la firma de referencia) ==="
( cd sim && python3 iss_m1553.py ) || { echo "FALLO ISS"; exit 1; }

echo
echo "=== SoC RTL vs firma del ISS (firma temporal esperada: 552845ns) ==="
( cd sim && rm -f *.cf && \
  ghdl -a --std=08 riscv_pkg.vhd spw_fifo.vhd \
       ../rtl/m1553_word_tx.vhd ../rtl/m1553_word_rx.vhd \
       ../rtl/m1553_rt_core.vhd ../rtl/m1553_bc_core.vhd ../rtl/m1553_mmio.vhd \
       ../tb/soc_stubs_l4.vhd ../rtl/mem_subsys_m1553.vhd ../tb/tb_m1553_l4.vhd && \
  ghdl -e --std=08 tb_m1553_l4 && \
  ghdl -r --std=08 tb_m1553_l4 2>&1 | grep -vE "metavalue detected" ) \
  || { echo "FALLO RUN LIMPIO"; exit 1; }

echo
echo "=== MUTACIONES (deben divergir de la firma del ISS) ==="
# M1: timing de respuesta del RT fuera de ventana
d=mut/l4_1; rm -rf $d; mkdir -p $d; cp rtl/m1553_rt_core.vhd $d/
sed -i 's/RESP_DELAY : integer := 425/RESP_DELAY : integer := 1600/' $d/m1553_rt_core.vhd
( cd sim && rm -f *.cf && \
  ghdl -a --std=08 riscv_pkg.vhd spw_fifo.vhd ../rtl/m1553_word_tx.vhd ../rtl/m1553_word_rx.vhd \
       ../$d/m1553_rt_core.vhd ../rtl/m1553_bc_core.vhd ../rtl/m1553_mmio.vhd \
       ../tb/soc_stubs_l4.vhd ../rtl/mem_subsys_m1553.vhd ../tb/tb_m1553_l4.vhd >/dev/null 2>&1 && \
  ghdl -e --std=08 tb_m1553_l4 >/dev/null 2>&1 && \
  timeout 120 ghdl -r --std=08 tb_m1553_l4 --stop-time=600us 2>&1 | grep -vE "metavalue detected" > run.log )
if grep -q FALLO sim/run.log; then
  echo "M1 (timing RT): DIVERGE como debe -> $(grep -m1 -oE 'FALLO[^\"]*' sim/run.log)"
else
  echo "M1: *** NO DIVERGIO ***"; exit 1
fi

# M2: decode de region equivocado (IP en 1011 en vez de 1100)
d=mut/l4_2; rm -rf $d; mkdir -p $d; cp rtl/mem_subsys_m1553.vhd $d/
sed -i 's/dmem_addr(31 downto 28) = "1100"/dmem_addr(31 downto 28) = "1011"/' $d/mem_subsys_m1553.vhd
( cd sim && rm -f *.cf && \
  ghdl -a --std=08 riscv_pkg.vhd spw_fifo.vhd ../rtl/m1553_word_tx.vhd ../rtl/m1553_word_rx.vhd \
       ../rtl/m1553_rt_core.vhd ../rtl/m1553_bc_core.vhd ../rtl/m1553_mmio.vhd \
       ../tb/soc_stubs_l4.vhd ../$d/mem_subsys_m1553.vhd ../tb/tb_m1553_l4.vhd >/dev/null 2>&1 && \
  ghdl -e --std=08 tb_m1553_l4 >/dev/null 2>&1 && \
  timeout 120 ghdl -r --std=08 tb_m1553_l4 --stop-time=5ms 2>&1 | grep -vE "metavalue detected" > run.log )
if grep -q FALLO sim/run.log; then
  echo "M2 (region 1011): DIVERGE como debe -> $(grep -m1 -oE 'FALLO[^\"]*' sim/run.log)"
else
  echo "M2: *** NO DIVERGIO ***"; exit 1
fi

# restaurar libreria limpia
( cd sim && rm -f *.cf && ghdl -a --std=08 riscv_pkg.vhd spw_fifo.vhd \
  ../rtl/m1553_word_tx.vhd ../rtl/m1553_word_rx.vhd ../rtl/m1553_rt_core.vhd \
  ../rtl/m1553_bc_core.vhd ../rtl/m1553_mmio.vhd ../tb/soc_stubs_l4.vhd \
  ../rtl/mem_subsys_m1553.vhd ../tb/tb_m1553_l4.vhd >/dev/null 2>&1 )
echo
echo "CAPA 4 COMPLETA"
