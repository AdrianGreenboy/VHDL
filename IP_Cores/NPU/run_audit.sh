#!/bin/bash
# HERCOSSNUX NPU - audit 2026-11: DMA error clearing / 0-byte requests,
# AXI slave burst SLVERR + AxSIZE, requant G_SHIFT guard.
(
set -e
cd "$(dirname "$0")"
mkdir -p build_audit
ghdl -a --std=08 --workdir=build_audit \
  rtl/npu_pkg.vhd rtl/npu_axi_pkg.vhd rtl/npu_requant.vhd rtl/npu_dma.vhd \
  rtl/npu_axi_slave.vhd tb/axi_ddr_model.vhd tb/tb_npu_audit.vhd 2>&1 | grep -v "warning" || true
out=$(ghdl -r --std=08 --workdir=build_audit tb_npu_audit 2>&1)
if echo "$out" | grep -q "TB_NPU_AUDIT PASS" && ! echo "$out" | grep -q "assertion failure"; then
  echo "NPU AUDIT OK TB_NPU_AUDIT PASS"
else
  echo "FALLO: $(echo "$out" | tail -5)"; exit 1
fi
)
