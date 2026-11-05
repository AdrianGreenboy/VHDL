#!/usr/bin/env bash
# run_mmio_l2d.sh -- Layer 2d (AUDIT 2026-11): START validation, FFT_SAT sticky,
# DATA-window read-after-write. Golden + mutations (same pattern as L2/L2b/L2c).
set -u
RTL=../rtl/dsp_mmio.vhd
TB=tb_dsp_mmio_l2d.vhd
GOLD=/tmp/l2d_golden_$$.vhd
DEPS="../rtl/cordic_dp.vhd ../rtl/fir_dp.vhd ../rtl/fft_dp.vhd ../rtl/fft_unsplit_dp.vhd"

echo ">> regenerando vectores (tb_fft_sat_mmio.mem)"
python3 dsp_oracle.py --dump >/dev/null || { echo "FALLO oraculo"; exit 1; }

run () {
  ghdl -a --std=08 $DEPS "$RTL" 2>/dev/null || return 2
  ghdl -a --std=08 "$TB" 2>/dev/null || return 2
  ghdl -e --std=08 tb_dsp_mmio_l2d 2>/dev/null || return 2
  timeout 300 ghdl -r --std=08 tb_dsp_mmio_l2d --stop-time=900ms 2>&1 | grep -E "L2D OK|MUTANTE|FALLO|bound|timeout" | head -1
}

cp "$RTL" "$GOLD"
echo ""; echo ">> M0 GOLDEN (debe imprimir 'L2D OK')"
echo "   $(run)"

echo ""; echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO' o un error de rango)"
declare -A MUT=(
  [M1_sin_validacion]='s/                  if bad then/                  if false then/'
  [M2_sat_no_sticky]='s/if fft_sat=.1. then status_sat <= .1.; end if;/null;/'
  [M3_raw_race]='s/data_rd_ready <= .1. when (dr_raddr_q = widx and data_rd_cnt = 2) else .0.;/data_rd_ready <= '"'"'1'"'"' when (dr_raddr_q = widx) else '"'"'0'"'"';/'
  [M4_sat_w1c_roto]='s/if wdata(3)=.1. then status_sat <=.0.; end if;/null;/'
  [M5_err_sin_done]='s/                    op_state   <= OP_FINISH;      -- DONE+ERR, datapath untouched/                    op_state   <= OP_IDLE;/'
)
for m in M1_sin_validacion M2_sat_no_sticky M3_raw_race M4_sat_w1c_roto M5_err_sin_done; do
  sed "${MUT[$m]}" "$GOLD" > "$RTL"
  cmp -s "$GOLD" "$RTL" && { echo "   [$m] SED NO APLICO"; continue; }
  echo "   [$m] $(run)"
done

cp "$GOLD" "$RTL"; rm -f "$GOLD"
echo ""; echo ">> golden restaurado. Layer 2d lista si M0=OK y M1..M5=VIVO."
