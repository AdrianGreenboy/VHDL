#!/usr/bin/env bash
# run_fft_l1a.sh -- Layer 1a entrega 1: FFT compleja, golden + mutaciones.
set -u
RTL=../rtl/fft_dp.vhd
TB=tb_fft_dp.vhd
GOLD=/tmp/fft_golden.vhd

echo ">> regenerando vectores dorados (tb_fft.mem)"
python3 dsp_oracle.py --dump >/dev/null || { echo "FALLO oraculo"; exit 1; }

run () {
  ghdl -a --std=08 "$RTL" 2>/dev/null || return 2
  ghdl -a --std=08 "$TB"  2>/dev/null || return 2
  ghdl -e --std=08 tb_fft_dp 2>/dev/null || return 2
  timeout 180 ghdl -r --std=08 tb_fft_dp --stop-time=500ms 2>&1 | grep -E "OK|MUTANTE|errores=" | tail -1
}
# AUDIT 2026-11: same RTL against the full-scale / corner vectors
run_corner () {
  timeout 300 ghdl -r --std=08 tb_fft_dp -gMEMFILE=tb_fft_corner.mem -gHAS_SAT=true --stop-time=900ms 2>&1 | grep -E "OK|MUTANTE|errores=" | tail -1
}

cp "$RTL" "$GOLD"
echo ""; echo ">> M0 GOLDEN (debe imprimir 'FFT OK')"
echo "   $(run)"
echo ">> M0c CORNER full-scale (debe imprimir 'FFT OK')"
echo "   $(run_corner)"

declare -A MUT=(
  [M1_sin_shift]='s/sr := rs1w(resize(ur_r,19) + resize(tr,19));/sr := resize(ur_r,20) + resize(tr,20);/'
  [M2_ifft_sin_conj]='s/wi_v := -wi_v; end if;/wi_v := wi_v; end if;/'
  [M3_qmul_sin_round]='s/p := a\*b; p := p + to_signed(16384,32);/p := a*b; p := p + to_signed(0,32);/'
  [M4_stride_mal]='s/rom_addr<= to_integer(shift_left(to_unsigned(j_r, LOG2MAX+1), log2_stride_r));/rom_addr<= j_r;/'
  [M5_ti_signo]='s/ti := resize(qmul17(lr_r, wi_v), 18) + resize(qmul(li_val, wr_v), 18);/ti := resize(qmul17(lr_r, wi_v), 18) - resize(qmul(li_val, wr_v), 18);/'
  # AUDIT 2026-11: the original wrap bug and a no-saturation variant; must be
  # killed by the corner run (M0 random +-8000 vectors cannot see them).
  # (qmul(-32768,-32768) itself is unreachable in this DIT dataflow: W=-j only
  #  ever multiplies W=1 difference outputs, bounded to +-32767 -- see AUDIT_FIXES.md)
  [M6_tr_wrap16]='s/tr := resize(qmul(lr_r, wr_v), 18) - resize(qmul17(li_val, wi_v), 18);/tr := resize(resize(qmul(lr_r, wr_v) - qmul17(li_val, wi_v), 16), 18);/'
  [M7_sat_wrap]='s/    if v > to_signed(32767, v.length) then return to_signed(32767,16);/    if false then return to_signed(32767,16);/'
)

echo ""; echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO')"
for m in M1_sin_shift M2_ifft_sin_conj M3_qmul_sin_round M4_stride_mal M5_ti_signo M6_tr_wrap16 M7_sat_wrap; do
  sed "${MUT[$m]}" "$GOLD" > "$RTL"
  cmp -s "$GOLD" "$RTL" && { echo "   [$m] SED NO APLICO"; continue; }
  r=$(run); case "$r" in *VIVO*) ;; *) r="$r | corner: $(run_corner)";; esac
  echo "   [$m] $r"
done

cp "$GOLD" "$RTL"
echo ""; echo ">> golden restaurado. Layer 1a FFT (compleja) lista si M0=OK, M0c=OK y M1..M7=VIVO."