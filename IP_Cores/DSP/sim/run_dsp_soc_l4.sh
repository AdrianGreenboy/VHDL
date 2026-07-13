#!/usr/bin/env bash
# run_dsp_soc_l4.sh -- Capa 4: RTL-vs-ISS del IP DSP por MMIO.
# El ISS (iss_dsp.py) genera el programa (estimulos+esperados); el TB lo ejecuta.
set -u
RTL=../rtl/dsp_mmio.vhd
TB=tb_dsp_soc.vhd
GOLD=/tmp/l4_golden.vhd
DEPS="../rtl/cordic_dp.vhd ../rtl/fir_dp.vhd ../rtl/fft_dp.vhd ../rtl/fft_unsplit_dp.vhd"

echo ">> generando programa ISS (dsp_soc_prog.txt)"
python3 iss_dsp.py >/dev/null || { echo "FALLO ISS"; exit 1; }

run () {
  ghdl -a --std=08 $DEPS "$RTL" 2>/dev/null || return 2
  ghdl -a --std=08 "$TB" 2>/dev/null || return 2
  ghdl -e --std=08 tb_dsp_soc 2>/dev/null || return 2
  timeout 90 ghdl -r --std=08 tb_dsp_soc --stop-time=100ms 2>&1 | grep -E "CAPA4 DSP OK|MUTANTE|errores=" | tail -1
}

cp "$RTL" "$GOLD"
echo ""; echo ">> M0 GOLDEN (debe imprimir 'CAPA4 DSP OK')"
echo "   $(run)"

echo ""; echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO')"
sed 's/x"D5B10100"/x"DEADBEEF"/' "$GOLD" > "$RTL"
echo "   [M1_id] $(run)"
sed 's/reslo_r <= std_logic_vector(resize(signed(cor_xout),32)); -- cos/reslo_r <= std_logic_vector(resize(signed(cor_yout),32)); -- cos/' "$GOLD" > "$RTL"
echo "   [M2_cordic_swap] $(run)"
sed 's/dr_wdata <= x"0000" & fir_yout;/dr_wdata <= std_logic_vector(resize(signed(fir_yout),32));/' "$GOLD" > "$RTL"
echo "   [M3_fir_signext] $(run)"
sed 's/dr_raddr  <= 2\*xfer_idx + 1;/dr_raddr  <= 2*xfer_idx;/' "$GOLD" > "$RTL"
echo "   [M4_rp_pack] $(run)"
sed 's/reshi_r <= std_logic_vector(resize(signed(cor_zout),32)); -- fase/reshi_r <= std_logic_vector(resize(signed(cor_yout),32)); -- fase/' "$GOLD" > "$RTL"
echo "   [M5_vec_phase] $(run)"
sed "s/fft_inv<='1'; fft_log2n<=log2n_r(3 downto 0);/fft_inv<='0'; fft_log2n<=log2n_r(3 downto 0);/" "$GOLD" > "$RTL"
echo "   [M6_ifft_noconj] $(run)"

cp "$GOLD" "$RTL"
echo ""; echo ">> golden restaurado. Capa 4 lista si M0=OK y M1..M6=VIVO."