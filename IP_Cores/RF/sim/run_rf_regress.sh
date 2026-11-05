#!/usr/bin/env bash
# run_rf_regress.sh (AUDIT 2026-11) -- RF regression: per-sample datapath vs
# model/rf_model.py at 3 operating points, rf_word_fifo unit test, full SoC
# (RV32IM firmware + DMA, golden 0x32783005), and a mutation battery.
# Works on copies in a temp dir (the repo RTL is never modified).
# Usage: cd IP_Cores/RF/sim && bash run_rf_regress.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
RF=$(cd "$HERE/.." && pwd)
RV=$(cd "$RF/../RV32i" && pwd)
T=$(mktemp -d /tmp/rf_regress.XXXXXX)
cp "$RF"/rtl/*.vhd "$T"/
cd "$T"
python3 "$RF/model/rf_model.py" --dump rf_oracle.txt >/dev/null || { echo "MODEL FAIL"; exit 1; }
python3 "$RF/model/asm.py" "$RF/fw/fw_rf.s" fw_rf.mem >/dev/null || { echo "ASM FAIL"; exit 1; }
RVS="$RV/riscv_pkg.vhd $RV/alu.vhd $RV/control.vhd $RV/csr.vhd $RV/immgen.vhd $RV/muldiv.vhd $RV/regfile.vhd $RV/cpu_pipeline.vhd $RV/dp_ram.vhd $RV/dma_burst.vhd $RV/axi_ddr_sim.vhd $RV/axil_soc.vhd $RV/axi4_master.vhd"
DP="rf_sincos_pkg.vhd rf_nco.vhd rf_loopmix.vhd rf_cic_dec.vhd rf_cic_int.vhd rf_fir.vhd rf_agc.vhd word_fifo.vhd rf_datapath.vhd"
SOC="rf_regs.vhd rf_dma_axi.vhd mem_subsys_rf.vhd rf_soc_top_master.vhd"

run_all () {   # $1 = directory with the RTL under test; prints 3 results
  ( cd "$1"
    rm -f work-obj08.cf
    ghdl -a --std=08 $RVS $DP $SOC "$RF/sim/tb_datapath.vhd" "$RF/sim/tb_rf_fifo.vhd" "$RF/sim/tb_rf_soc.vhd" >/dev/null 2>&1 || { echo "COMPILE_FAIL"; return; }
    cp "$T/rf_oracle.txt" "$T/fw_rf.mem" . 2>/dev/null
    a=$(timeout 300 ghdl -r --std=08 tb_datapath --stop-time=50ms 2>&1 | grep -oE "FIN SIMULACION DATAPATH: (PASS|FAIL)" | head -1)
    b=$(timeout 300 ghdl -r --std=08 tb_rf_fifo 2>&1 | grep -oE "RF FIFO (PASS|FAIL)" | head -1)
    c=$(timeout 600 ghdl -r --std=08 tb_rf_soc --stop-time=200ms 2>&1 | grep -oE "FIN SIMULACION RFSOC: (PASS|FAIL) CHK=0x[0-9A-F]+" | head -1)
    echo "datapath=[${a:-NONE}] fifo=[${b:-NONE}] soc=[${c:-NONE}]" )
}

echo ">> M0 GOLDEN (all three must PASS)"
echo "   $(run_all "$T")"

declare -A MF=( [M1_cicdec_trunc]=rf_cic_dec.vhd [M2_cicint_trunc]=rf_cic_int.vhd
                [M3_fir_trunc]=rf_fir.vhd [M4_mix_trunc]=rf_loopmix.vhd
                [M5_ovf_not_sticky]=word_fifo.vhd [M6_fifo_order]=word_fifo.vhd )
declare -A MS=(
  [M1_cicdec_trunc]='s/sat16(shift_right(c3_i + shift_left(to_signed(1, 32), sh_v - 1), sh_v))/sat16(shift_right(c3_i, sh_v))/'
  [M2_cicint_trunc]='s/sat16(shift_right(i3_q_r + shift_left(to_signed(1, 32), sh_v - 1), sh_v))/sat16(shift_right(i3_q_r, sh_v))/'
  [M3_fir_trunc]='s/s := shift_right(v + to_signed(16384, 36), 15);/s := shift_right(v, 15);/'
  [M4_mix_trunc]='s/rfi_v := sat16(resize(shift_right(ri_v + 16384, 15), 34));/rfi_v := sat16(resize(shift_right(ri_v, 15), 34));/'
  [M5_ovf_not_sticky]='s/      if wr_en = .1. and full_i = .1. then/      if false then/'
  [M6_fifo_order]='s/head <= rd_word;/head <= buf(to_integer(rd_ptr));/'
)
echo ""; echo ">> MUTATIONS (each must show at least one FAIL)"
for m in M1_cicdec_trunc M2_cicint_trunc M3_fir_trunc M4_mix_trunc M5_ovf_not_sticky M6_fifo_order; do
  D="$T/$m"; mkdir -p "$D"; cp "$T"/*.vhd "$D"/
  sed -i "${MS[$m]}" "$D/${MF[$m]}"
  if cmp -s "$T/${MF[$m]}" "$D/${MF[$m]}"; then echo "   [$m] SED DID NOT APPLY"; continue; fi
  r=$(run_all "$D"); case "$r" in *FAIL*|*NONE*|*COMPILE_FAIL*) k="KILLED";; *) k="SURVIVED";; esac
  echo "   [$m] $k  $r"
done
echo ""; echo ">> temp dir $T (left for inspection)"
