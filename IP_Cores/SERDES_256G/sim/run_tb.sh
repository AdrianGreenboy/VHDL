#!/usr/bin/env bash
#==============================================================================
# SERDES_256G - link testbench (GHDL mcode, --std=08)
# Must print: SERDES256G_TB_PASS
#
# A fresh work directory is created for every run (no stale work-obj08.cf and
# nothing is deleted). Follow the run with:
#   tail -f sim/tb_serdes256g.log
#==============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CORE="$(cd "${HERE}/.." && pwd)"
RTL="${CORE}/rtl"
WORK="${HERE}/work_$(date +%Y%m%d_%H%M%S)"
LOG="${HERE}/tb_serdes256g.log"

mkdir -p "${WORK}"
: > "${LOG}"

ghdl -a --std=08 --workdir="${WORK}" \
  "${RTL}/serdes256g_pkg.vhd" \
  "${RTL}/serdes256g_tx_frame.vhd" \
  "${RTL}/serdes256g_tx_lane.vhd" \
  "${RTL}/serdes256g_rx_lane.vhd" \
  "${RTL}/serdes256g_afifo.vhd" \
  "${RTL}/serdes256g_rx_align.vhd" \
  "${RTL}/serdes256g_rx_frame.vhd" \
  "${RTL}/serdes256g_top.vhd" \
  "${CORE}/tb/tb_serdes256g.vhd" 2>&1 | tee -a "${LOG}"
echo "[ghdl] analysis OK" | tee -a "${LOG}"

ghdl -r --std=08 --workdir="${WORK}" tb_serdes256g --stop-time=20ms 2>&1 \
  | tee -a "${LOG}"

if grep -q "SERDES256G_TB_PASS" "${LOG}"; then
  echo "RESULT: PASS"
else
  echo "RESULT: FAIL"
  exit 1
fi
