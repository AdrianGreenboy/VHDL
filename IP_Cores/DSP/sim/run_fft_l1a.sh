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

cp "$RTL" "$GOLD"
echo ""; echo ">> M0 GOLDEN (debe imprimir 'FFT OK')"
echo "   $(run)"

declare -A MUT=(
  [M1_sin_shift]='s/wd_re1 <= rsr1(resize(ur_r,17) + resize(tr,17));/wd_re1 <= resize(ur_r + tr, 16);/'
  [M2_ifft_sin_conj]='s/wi_v := -wi_v; end if;/wi_v := wi_v; end if;/'
  [M3_qmul_sin_round]='s/p := a\*b; p := p + to_signed(16384,32);/p := a*b; p := p + to_signed(0,32);/'
  [M4_stride_mal]='s/rom_addr<= to_integer(shift_left(to_unsigned(j_r, LOG2MAX+1), log2_stride_r));/rom_addr<= j_r;/'
  [M5_ti_signo]='s/ti := resize(qmul17(lr_r, wi_v) + qmul(li_val, wr_v), 16);/ti := resize(qmul17(lr_r, wi_v) - qmul(li_val, wr_v), 16);/'
)

echo ""; echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO')"
for m in M1_sin_shift M2_ifft_sin_conj M3_qmul_sin_round M4_stride_mal M5_ti_signo; do
  sed "${MUT[$m]}" "$GOLD" > "$RTL"
  echo "   [$m] $(run)"
done

cp "$GOLD" "$RTL"
echo ""; echo ">> golden restaurado. Layer 1a FFT (compleja) lista si M0=OK y M1..M5=VIVO."