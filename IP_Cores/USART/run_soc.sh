#!/bin/bash
# run_soc.sh -- MMUSART layer 4: RV32 + mem_subsys_usart + usart_axi_top.
# Fuentes compartidas del SoC v3 desde ~/rv32i/ (mismo patron de run_xsim.sh)
# y byte_fifo desde ~/spi_ip/. Ensambla usart_test.s con asm.py y genera el
# patron usart_ddr.mem (byte k = k mod 256, little-endian por palabra).
set -e

if ! command -v xvhdl >/dev/null 2>&1; then
  source ~/Xilinx/2025.2.1/Vivado/settings64.sh
fi

RV=~/rv32i
BF=~/spi_ip/byte_fifo.vhd
[ -f "$BF" ] || BF=./byte_fifo.vhd

# --- programa RV32 ---
if [ ! -f usart_test.mem ] || [ usart_test.s -nt usart_test.mem ]; then
  echo "ensamblando usart_test.s..."
  python3 "$RV/asm.py" usart_test.s usart_test.mem || {
    echo "ERROR: ajusta la invocacion de asm.py a tu CLI habitual"; exit 1; }
fi

# --- patron de la DDR del USART (igual al del SPI: byte k = k mod 256) ---
python3 - <<'EOF'
with open('usart_ddr.mem', 'w') as f:
    for k in range(1024):
        b = [(4*k + i) % 256 for i in range(4)]
        f.write('%02X%02X%02X%02X\n' % (b[3], b[2], b[1], b[0]))
EOF
echo "usart_ddr.mem generado (1024 palabras)"

SRCS="$RV/riscv_pkg.vhd $RV/alu.vhd $RV/regfile.vhd $RV/muldiv.vhd \
      $RV/immgen.vhd $RV/control.vhd $RV/csr.vhd $RV/dp_ram.vhd \
      $RV/cpu_pipeline.vhd $RV/dma_burst.vhd $RV/axil_soc.vhd \
      $RV/axi_ddr_sim.vhd $BF \
      usart_engine.vhd usart_mmio.vhd usart_dma.vhd usart_axi_top.vhd \
      mem_subsys_usart.vhd soc_top_usart.vhd tb_usart_soc.vhd"

xvhdl -2008 $SRCS
xelab -debug typical tb_usart_soc -s tb_usart_soc_sim
xsim tb_usart_soc_sim -runall
