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
run_corner () {
  timeout 120 ghdl -r --std=08 tb_fft_unsplit_dp -gMEMFILE=tb_unsplit_corner.mem --stop-time=200ms 2>&1 | grep -E "OK|MUTANTE|errores=" | tail -1
}

cp "$RTL" "$GOLD"
echo ""; echo ">> M0 GOLDEN (debe imprimir 'UNSPLIT OK')"
echo "   $(run)"
echo ">> M0c CORNER full-scale (debe imprimir 'UNSPLIT OK')"
echo "   $(run_corner)"

declare -A MUT=(
  [M1_sin_conj]='s/ci := -resize(zq_i, 17);/ci := resize(zq_i, 17);/'
  [M2_A_sin_shift]='s/ar_p <= rs1_17(resize(zk_r,17) + cr);/ar_p <= resize(zk_r,17) + cr;/'
  [M3_mj_mal]='s/xr_b(k_r) <= sat16(resize(ar_p,19) + resize(wbi_p,19));/xr_b(k_r) <= sat16(resize(ar_p,19) - resize(wbr_p,19));/'
  [M4_stride_mal]='s/rom_addr_p <= to_integer(shift_left(to_unsigned(k_r,11), log2_stride_r));/rom_addr_p <= k_r;/'
  [M5_km_mal]='s/if k_r = 0 or k_r = n_r then km_r <= 0; else km_r <= n_r - k_r; end if;/km_r <= k_r mod n_r;/'
  # AUDIT 2026-11: the original 16-bit W*B wrap; killed by the corner run.
  [M6_wb_wrap16]='s/            wbr_p <= qmulw(br_p,wr_p) - qmulw(bi_p,wi_p);/            wbr_p <= resize(resize(qmulw(br_p,wr_p) - qmulw(bi_p,wi_p),16),18);/'
)
echo ""; echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO')"
for m in M1_sin_conj M2_A_sin_shift M3_mj_mal M4_stride_mal M5_km_mal M6_wb_wrap16; do
  sed "${MUT[$m]}" "$GOLD" > "$RTL"
  cmp -s "$GOLD" "$RTL" && { echo "   [$m] SED NO APLICO"; continue; }
  r=$(run); case "$r" in *VIVO*) ;; *) r="$r | corner: $(run_corner)";; esac
  echo "   [$m] $r"
done

cp "$GOLD" "$RTL"
echo ""; echo ">> golden restaurado. Layer 1a unsplit lista si M0=OK, M0c=OK y M1..M6=VIVO."