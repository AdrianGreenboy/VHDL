#!/bin/bash
# run_regression.sh - GHDL regression of the PCIe IP (all sim layers + audit
# 2026-11 benches). Build products go to $PCIE_SIM_DIR (default under /tmp).
# Exit code 0 = all PASS.
set -u
P="$(cd "$(dirname "$0")" && pwd)"
W="${PCIE_SIM_DIR:-${TMPDIR:-/tmp}/pcie_sim_$(id -un)}"
mkdir -p "$W"; cd "$W"
FAIL=0
SRC="pcie_8b10b_pkg pcie_phy_pkg pcie_ltssm_pkg pcie_dll_pkg pcie_tl_pkg pcie_mmio_pkg
     pcie_8b10b pcie_scrambler pcie_framer pcie_deframer pcie_ts_gen pcie_ltssm
     pcie_dll_tx pcie_dll_rx pcie_dllp_rx pcie_rx_tlp_fifo pcie_byte_fifo
     pcie_elastic_buf pcie_tl_ep pcie_tlp_frame pcie_rx_adapt pcie_node pcie_mmio
     tb_8b10b tb_phy tb_train tb_dll tb_tl tb_loop tb_mmio tb_soc tb_link tb_eb"
for f in $SRC; do
  ghdl -a --std=08 "$P/$f.vhd" 2>&1 | grep -i ' error' && FAIL=1
done
# name:stop-time:PASS-pattern[:generic]
TESTS="tb_8b10b:50ms:FIN SIMULACION 8B10B: PASS
tb_phy:50ms:FIN SIMULACION PHY: PASS
tb_train:50ms:FIN SIMULACION TRAIN: PASS
tb_dll:200ms:FIN SIMULACION DLL: PASS
tb_tl:50ms:FIN SIMULACION TL: PASS
tb_loop:50ms:FIN SIMULACION LOOP: PASS
tb_mmio:50ms:FIN SIMULACION MMIO: PASS
tb_soc:50ms:FIN SIMULACION SOC: PASS
tb_link:100ms:FIN SIMULACION LINK: PASS
tb_eb:10ms:TB_EB PASS ppm=2000:-gPPM=2000
tb_eb:10ms:TB_EB PASS ppm=-2000:-gPPM=-2000"
while IFS= read -r line; do
  n=${line%%:*}; rest=${line#*:}; st=${rest%%:*}; rest=${rest#*:}
  pat=${rest%%:-g*}; gen=""; [ "$pat" != "$rest" ] && gen="-g${rest#*:-g}"
  ghdl -e --std=08 "$n" >/dev/null 2>&1
  out=$(ghdl -r --std=08 "$n" $gen --stop-time="$st" 2>&1)
  if echo "$out" | grep -qF -- "$pat" && ! echo "$out" | grep -q "assertion failure"; then
    echo "PASS  $n $gen  $(echo "$out" | grep -oE 'PASS @ [0-9]+ fs' | tail -1)"
  else
    echo "FAIL  $n $gen"; echo "$out" | grep -v metavalue | tail -5; FAIL=1
  fi
done <<< "$TESTS"
echo "=================================================="
[ $FAIL -eq 0 ] && echo "PCIE REGRESSION: ALL PASS" || echo "PCIE REGRESSION: FAILURES"
exit $FAIL
