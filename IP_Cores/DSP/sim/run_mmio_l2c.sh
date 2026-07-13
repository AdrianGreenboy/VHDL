#!/usr/bin/env bash
# run_mmio_l2c.sh -- Layer 2c: FIR modo bloque y FFT real-empacada via MMIO.
set -u
RTL=../rtl/dsp_mmio.vhd
TB=tb_dsp_mmio_l2c.vhd
GOLD=/tmp/l2c_golden.vhd
DEPS="../rtl/cordic_dp.vhd ../rtl/fir_dp.vhd ../rtl/fft_dp.vhd ../rtl/fft_unsplit_dp.vhd"

echo ">> regenerando vectores (tb_fir_mmio.mem, tb_rp_mmio.mem)"
python3 dsp_oracle.py --dump >/dev/null || { echo "FALLO oraculo"; exit 1; }

run () {
  ghdl -a --std=08 $DEPS "$RTL" 2>/dev/null || return 2
  ghdl -a --std=08 "$TB" 2>/dev/null || return 2
  ghdl -e --std=08 tb_dsp_mmio_l2c 2>/dev/null || return 2
  timeout 180 ghdl -r --std=08 tb_dsp_mmio_l2c --stop-time=800ms 2>&1 | grep -E "OK|MUTANTE|errores=" | tail -1
}

cp "$RTL" "$GOLD"
echo ""; echo ">> M0 GOLDEN (debe imprimir 'L2C OK')"
echo "   $(run)"

echo ""; echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO')"
sed 's/fir_coef_dat <= coef_r(fir_ci)(15 downto 0);/fir_coef_dat <= coef_r((fir_ci+1) mod 32)(15 downto 0);/' "$GOLD" > "$RTL"
echo "   [M1_coef_shift] $(run)"
sed 's/dr_wdata <= x"0000" & fir_yout;/dr_wdata <= std_logic_vector(resize(signed(fir_yout),32));/' "$GOLD" > "$RTL"
echo "   [M2_fir_signext] $(run)"
sed 's/dr_raddr  <= 2\*xfer_idx + 1;/dr_raddr  <= 2*xfer_idx;/' "$GOLD" > "$RTL"
echo "   [M3_pack_mal] $(run)"
sed 's/uns_wr_zr  <= fft_rd_re;/uns_wr_zr  <= fft_rd_im;/' "$GOLD" > "$RTL"
echo "   [M4_z_swap] $(run)"

cp "$GOLD" "$RTL"
echo ""; echo ">> golden restaurado. Layer 2c lista si M0=OK y M1..M4=VIVO."