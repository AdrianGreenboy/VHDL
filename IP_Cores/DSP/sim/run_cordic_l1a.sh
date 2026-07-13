#!/usr/bin/env bash
# run_cordic_l1a.sh -- Layer 1a: datapath CORDIC, golden + mutaciones.
# Uso:  ./run_cordic_l1a.sh
# Requiere: ghdl 4.1.0 (--std=08), python3+numpy, dsp_oracle.py en este dir.
set -u

RTL=../rtl/cordic_dp.vhd
TB=tb_cordic_dp.vhd
GOLD=/tmp/cordic_golden.vhd

echo ">> regenerando vectores dorados (tb_cordic.mem)"
python3 dsp_oracle.py --dump >/dev/null || { echo "FALLO oraculo"; exit 1; }

analyze_run () {
  ghdl -a --std=08 "$RTL" 2>/dev/null || return 2
  ghdl -a --std=08 "$TB"  2>/dev/null || return 2
  ghdl -e --std=08 tb_cordic_dp 2>/dev/null || return 2
  ghdl -r --std=08 tb_cordic_dp --stop-time=20ms 2>&1 | grep -E "OK|MUTANTE|errores=" | tail -1
}

cp "$RTL" "$GOLD"

echo ""
echo ">> M0 GOLDEN (debe imprimir 'CORDIC OK')"
echo "   $(analyze_run)"

declare -A MUT=(
  [M1_sin_prerot]='s/if zin_s > HALF_PI then/if false then/'
  [M2_atan0_LSB]='s/to_signed( 8192, 16)/to_signed( 8193, 16)/'
  [M3_sin_invK]='s/x"4DBA"/x"7FFF"/'
  [M4_shift_mal]='s/shift_right(x_r, iter)/shift_right(x_r, iter+1)/'
  [M5_15_iters]='s/if iter = ITERS - 1 then/if iter = ITERS - 2 then/'
)

echo ""
echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO')"
for m in M1_sin_prerot M2_atan0_LSB M3_sin_invK M4_shift_mal M5_15_iters; do
  sed "${MUT[$m]}" "$GOLD" > "$RTL"
  echo "   [$m] $(analyze_run)"
done

cp "$GOLD" "$RTL"
echo ""
echo ">> golden restaurado. Layer 1a CORDIC lista si M0=OK y M1..M5=VIVO."