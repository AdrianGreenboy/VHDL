#!/usr/bin/env bash
# ============================================================================
# run_soc.sh - Capa 4 del IP I3C: RV32 + mem_subsys_i3c + i3c_mmio + DDR sim
# Fuentes compartidas desde ~/rv32i (riscv_pkg, cpu, dma_burst, axi_ddr_sim,
# axil_soc...) y ~/spi_ip/byte_fifo.vhd, con fallback local del FIFO.
# Ensambla i3c_test.s con asm.py antes de compilar.
# Uso: ./run_soc.sh   (requiere ghdl >= 4.x con --std=08 y python3)
# Exito esperado: doorbell + 13 checks + "TEST PASSED".
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

RV32="$HOME/rv32i"
if [ ! -d "$RV32" ]; then
  echo "ERROR: no encuentro $RV32 (fuentes compartidas del SoC)" >&2
  exit 1
fi

FIFO_SRC="$HOME/spi_ip/byte_fifo.vhd"
if [ ! -f "$FIFO_SRC" ]; then
  FIFO_SRC="./byte_fifo.vhd"
  echo "AVISO: usando fallback local $FIFO_SRC"
else
  echo "Usando fuente compartida $FIFO_SRC"
fi

# ensamblar el programa de prueba
python3 "$RV32/asm.py" i3c_test.s i3c_test.mem

rm -f work-obj08.cf

# fuentes compartidas del SoC
for f in riscv_pkg alu regfile muldiv immgen control csr dp_ram \
         cpu_pipeline dma_burst axi_ddr_sim axil_soc; do
  ghdl -a --std=08 "$RV32/$f.vhd"
done

# IP I3C + integracion
ghdl -a --std=08 "$FIFO_SRC"
ghdl -a --std=08 i3c_controller.vhd
ghdl -a --std=08 i3c_target.vhd
ghdl -a --std=08 i3c_mmio.vhd
ghdl -a --std=08 mem_subsys_i3c.vhd
ghdl -a --std=08 soc_top_i3c.vhd
ghdl -a --std=08 tb_i3c_soc.vhd
ghdl -e --std=08 tb_i3c_soc
ghdl -r --std=08 tb_i3c_soc

echo "run_soc.sh: PASS"
