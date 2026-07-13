#!/usr/bin/env bash
# run_unsplit_l1a.sh -- Layer 1a entrega 2: unsplit real-empacado.
set -u
RTL=../rtl/fft_unsplit_dp.vhd
TB=tb_fft_unsplit_dp.vhd
GOLD=/tmp/uns_golden.vhd

echo ">> regenerando vectores dorados (tb_unsplit.mem)"
python3 dsp_oracle.py --dump >/dev/null || { echo "FALLO oraculo"; exit 1; }

run () {
  ghdl -a --std=08 "$RTL" 2>/dev/null || return 2
  ghdl -a --std=08 "$TB"  2>/dev/null || return 2
  ghdl -e --std=08 tb_fft_unsplit_dp 2>/dev/null || return 2
  timeout 60 ghdl -r --std=08 tb_fft_unsplit_dp --stop-time=100ms 2>&1 | grep -E "OK|MUTANTE|errores=" | tail -1
}

cp "$RTL" "$GOLD"
echo ""; echo ">> M0 GOLDEN (debe imprimir 'UNSPLIT OK')"
echo "   $(run)"

declare -A MUT=(
  [M1_sin_conj]='s/ci := -resize(zi_b(km), 17);/ci := resize(zi_b(km), 17);/'
  [M2_A_sin_shift]='s/ar_p <= rsr1(resize(zr_b(kk),17) + resize(cr,17));/ar_p <= resize(resize(zr_b(kk),17) + resize(cr,17),16);/'
  [M3_mj_mal]='s/xr_b(k_r) <= sat16(resize(ar_p,17) + resize(wbi_p,17));/xr_b(k_r) <= sat16(resize(ar_p,17) - resize(wbr_p,17));/'
  [M4_stride_mal]='s/rom_addr_p <= to_integer(shift_left(to_unsigned(k_r,11), log2_stride_r));/rom_addr_p <= k_r;/'
  [M5_km_mal]='s/if k_r = 0 then km := 0; else km := n_r - k_r; end if;/km := k_r mod n_r;/'
)
echo ""; echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO')"
for m in M1_sin_conj M2_A_sin_shift M3_mj_mal M4_stride_mal M5_km_mal; do
  sed "${MUT[$m]}" "$GOLD" > "$RTL"
  echo "   [$m] $(run)"
done

cp "$GOLD" "$RTL"
echo ""; echo ">> golden restaurado. Layer 1a unsplit lista si M0=OK y M1..M5=VIVO."