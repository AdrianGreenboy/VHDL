#!/bin/bash
# =============================================================================
# HERCOSSNUX Core 19 - PCS 64B/66B @ 25G
# Full GHDL regression (layers 1-4 + audit 2026-11 tests), no Vivado.
#
#   bash sim/run_layers.sh [workdir]        exits 1 if anything fails
#
#   * every oracle-generated testbench is regenerated into the workdir and
#     compared with the committed copy in rtl/ (stale testbench = FAIL)
#   * L1 regbank, L2A dataplane, L2B CDC, L3 scrambler / gearbox / PRBS /
#     datapath / silicon chain, L4 stats_top via AXI and via MMIO bridge
#   * audit tests: tb_pcs_axil (AXI back-pressure, WSTRB, SLVERR),
#     tb_pcs_blocksync (clause-49 lock / hi_ber counts), tb_pcs_cl49
#     (TX bit-exact and RX lock acquisition vs the independent
#     oracle/cl49_ref.py at several bit offsets and header-error bursts),
#     tb_pcs_cdc_ev (event CDC without loss at several clock ratios),
#     tb_pcs_dp_clear (counter clear wins over a same-cycle event)
# Layer 5 (SoC + RV32 firmware) is NOT run here: verif/tb_soc_pcs needs a
# mem_subsys_dma with the PTP master port (p_*) that the RV32i in this
# repository does not provide (pre-existing, see AUDIT_FIXES.md).
# Requires: ghdl >= 4 (--std=08), python3.
# =============================================================================
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
W=${1:-/tmp/pcs25g_sim}
mkdir -p "$W/work" "$W/gen" "$W/run"   # no deletion: ghdl -a re-analyses every unit
GF="--std=08 --workdir=$W/work"
R=$HERE/rtl
O=$HERE/oracle
PASS=0; FAILS=0
ok()  { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL  $1  :: $2"; FAILS=$((FAILS+1)); }

echo "== oracles and generated testbenches"
python3 -I "$O/cl49_ref.py" selftest | grep -q OK && ok "cl49_ref selftest" || bad "cl49_ref" "selftest"
for g in gen_tb.py:tb_pcs_regbank gen_tb_datapath.py:tb_pcs_datapath gen_tb_gearbox.py:tb_pcs_gearbox \
         gen_tb_prbs.py:tb_pcs_prbs31 gen_tb_scrambler.py:tb_pcs_scrambler gen_tb_stats.py:tb_pcs_dataplane; do
  py=${g%%:*}; tb=${g##*:}
  (cd "$O" && python3 "$py" > "$W/gen/$tb.vhd") || bad "$py" "generator error"
  if [ -f "$R/$tb.vhd" ]; then
    cmp -s "$W/gen/$tb.vhd" "$R/$tb.vhd" && ok "$tb == oracle" || bad "$tb" "rtl/$tb.vhd is stale: regenerate with oracle/$py"
  fi
done

RTL="$R/pcs_scrambler.vhd $R/pcs_gearbox_tx.vhd $R/pcs_gearbox_rx.vhd $R/pcs_blocksync.vhd \
     $R/pcs_tx_datapath.vhd $R/pcs_rx_datapath.vhd $R/pcs_prbs31.vhd $R/pcs_silicon_datapath.vhd \
     $R/pcs_regbank.vhd $R/pcs_dataplane.vhd $R/pcs_cdc.vhd $R/pcs_stats_top.vhd $R/pcs_mmio_bridge.vhd"
TBS="$R/tb_pcs_regbank.vhd $R/tb_pcs_dataplane.vhd $R/tb_pcs_cdc.vhd $R/tb_pcs_scrambler.vhd \
     $R/tb_pcs_gearbox.vhd $W/gen/tb_pcs_prbs31.vhd $R/tb_pcs_datapath.vhd $R/tb_pcs_silicon.vhd \
     $R/tb_pcs_stats_top.vhd $R/tb_pcs_mmio.vhd $R/tb_pcs_axil.vhd $R/tb_pcs_blocksync.vhd \
     $R/tb_pcs_cl49.vhd $R/tb_pcs_cdc_ev.vhd $R/tb_pcs_dp_clear.vhd"
ghdl -a $GF $RTL $TBS || { echo "ANALYSIS FAILED"; exit 1; }
cd "$W/run"

echo "== layers 1-4"
run() {  # run <tag> <pass-pattern> <tb> <stop> [generics]
  local tag=$1 pat=$2 tb=$3 st=$4; shift 4
  local out
  out=$(ghdl -r $GF "$tb" --stop-time="$st" "$@" 2>&1 | grep -E "LAYER|TB_PCS|FAIL|failure|mismatch" | head -4)
  if echo "$out" | grep -q "$pat" && ! echo "$out" | grep -qE "FAIL|failure|mismatch"; then
    ok "$tag $(echo "$out" | grep -oE 'FNV32=0x[0-9A-F]+' | head -1)"
  else bad "$tag" "$out"; fi
}
run "L1 regbank"          LAYER1_PASS    tb_pcs_regbank   5ms
run "L2A dataplane"       LAYER2A_PASS   tb_pcs_dataplane 5ms
run "L2B cdc"             LAYER2B_PASS   tb_pcs_cdc       5ms
run "L3 scrambler"        LAYER3PCS_PASS tb_pcs_scrambler 5ms
run "L3 gearbox"          LAYER3GB_PASS  tb_pcs_gearbox   5ms
run "L3 prbs31"           LAYER3PRBS_PASS tb_pcs_prbs31   5ms
run "L3 datapath"         LAYER3DP_PASS  tb_pcs_datapath  5ms
run "L3 silicon chain"    LAYER3TOP_PASS tb_pcs_silicon   10ms
run "L4 stats_top AXI"    LAYER4TOP_PASS tb_pcs_stats_top 50ms
run "L4 stats_top MMIO"   LAYER4MMIO_PASS tb_pcs_mmio     50ms

echo "== audit 2026-11"
run "AXI-Lite B back-pressure / WSTRB / SLVERR" TB_PCS_AXIL_PASS tb_pcs_axil 1ms
run "clause-49 lock + BER monitor counts"       TB_PCS_BLOCKSYNC_PASS tb_pcs_blocksync 1ms
run "CNT_CLEAR / PRBS_RESET vs same-cycle event" TB_PCS_DP_CLEAR_PASS tb_pcs_dp_clear 1ms
python3 -I "$O/cl49_ref.py" tx 600 7 tx_blk.txt tx_words.txt
run "cl49 TX bit-exact vs cl49_ref"             TB_PCS_CL49_TX_PASS tb_pcs_cl49 1ms \
    -gMODE=tx -gFBLK=tx_blk.txt -gFWORDS=tx_words.txt
for c in "0 0 0" "1 0 0" "37 0 0" "65 0 0" "11 600 15" "11 600 31" "40 700 40"; do
  set -- $c
  python3 -I "$O/cl49_ref.py" rx 1500 $(( $1 + 3 )) $1 rx_words.txt rx_blk.txt $2 $3
  run "cl49 RX offset=$1 bad_headers=$3"         TB_PCS_CL49_RX_PASS tb_pcs_cl49 1ms \
      -gMODE=rx -gNBLK=1500 -gBADN=$3 -gFBLK=rx_blk.txt -gFWORDS=rx_words.txt
done
for r in "2560 25000" "2560 6000" "6400 25000" "25000 2560"; do
  set -- $r
  run "event CDC dp=${1}ps axi=${2}ps"           TB_PCS_CDC_EV_PASS tb_pcs_cdc_ev 10ms \
      -gTDP_PS=$1 -gTAXI_PS=$2
done

echo
echo "RESULT: $PASS PASS, $FAILS FAIL"
[ $FAILS -eq 0 ]
