#!/usr/bin/env bash
# run_fir_l1a.sh -- Layer 1a: datapath FIR simetrico, golden + mutaciones.
set -u
RTL=../rtl/fir_dp.vhd
TB=tb_fir_dp.vhd
GOLD=/tmp/fir_golden.vhd

echo ">> regenerando vectores dorados (tb_fir.mem)"
python3 dsp_oracle.py --dump >/dev/null || { echo "FALLO oraculo"; exit 1; }

run () {
  ghdl -a --std=08 "$RTL" 2>/dev/null || return 2
  ghdl -a --std=08 "$TB"  2>/dev/null || return 2
  ghdl -e --std=08 tb_fir_dp 2>/dev/null || return 2
  ghdl -r --std=08 tb_fir_dp --stop-time=50ms 2>&1 | grep -E "OK|MUTANTE|errores=" | tail -1
}

cp "$RTL" "$GOLD"
echo ""; echo ">> M0 GOLDEN (debe imprimir 'FIR OK')"
echo "   $(run)"

declare -A MUT=(
  [M1_sin_simetria]='s/pre := resize(dline(ja), 17) + resize(dline(jb), 17);/pre := resize(dline(ja), 17);/'
  [M2_sin_redondeo]='s/red := acc + to_signed(16384, 40);/red := acc;/'
  [M3_shift14]='s/red := shift_right(red, 15);/red := shift_right(red, 14);/'
  [M4_central_dup]='s/if ja = jb then/if false then/'
  [M5_coef_shift]='s/cmem(k mod HALFMAX)/cmem((k+1) mod HALFMAX)/'
)
echo ""; echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO')"
for m in M1_sin_simetria M2_sin_redondeo M3_shift14 M4_central_dup M5_coef_shift; do
  sed "${MUT[$m]}" "$GOLD" > "$RTL"
  echo "   [$m] $(run)"
done

cp "$GOLD" "$RTL"
echo ""; echo ">> golden restaurado. Layer 1a FIR lista si M0=OK y M1..M5=VIVO."