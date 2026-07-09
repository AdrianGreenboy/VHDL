#!/usr/bin/env bash
# ============================================================================
# run_soc.sh — Capa 4 del IP IIC: RV32 + mem_subsys_i2c + i2c_mmio + DDR sim
# Fuentes compartidas desde ~/rv32i (riscv_pkg, cpu, dma_burst, axi_ddr_sim,
# axil_soc...) y ~/spi_ip/byte_fifo.vhd, con fallback local del FIFO.
# Ensambla i2c_test.s con asm.py antes de compilar.
# Uso: ./run_soc.sh   (requiere xvhdl/xelab/xsim de Vivado en el PATH)
# Éxito esperado: doorbell + 5 checks + "TEST PASSED" y fin ~68 us.
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
python3 "$RV32/asm.py" i2c_test.s i2c_test.mem

# fuentes compartidas del SoC
for f in riscv_pkg alu regfile muldiv immgen control csr dp_ram \
         cpu_pipeline dma_burst axi_ddr_sim axil_soc; do
  xvhdl --2008 "$RV32/$f.vhd"
done

# IP IIC + integración
xvhdl --2008 "$FIFO_SRC"
xvhdl --2008 i2c_master.vhd
xvhdl --2008 i2c_slave.vhd
xvhdl --2008 i2c_mmio.vhd
xvhdl --2008 mem_subsys_i2c.vhd
xvhdl --2008 soc_top_i2c.vhd
xvhdl --2008 tb_i2c_soc.vhd

xelab --debug typical tb_i2c_soc -s i2c_soc_sim
xsim i2c_soc_sim --runall
