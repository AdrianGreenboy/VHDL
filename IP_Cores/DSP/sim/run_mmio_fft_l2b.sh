#!/usr/bin/env bash
# run_mmio_fft_l2b.sh -- Layer 2b: FFT completa via MMIO, golden + mutaciones
# de orquestacion (transferencia DATA<->fft, config, conteo).
set -u
RTL=../rtl/dsp_mmio.vhd
TB=tb_dsp_mmio_fft.vhd
GOLD=/tmp/mmio2_golden.vhd
DEPS="../rtl/cordic_dp.vhd ../rtl/fir_dp.vhd ../rtl/fft_dp.vhd"

echo ">> regenerando vectores (tb_fft_mmio.mem)"
python3 dsp_oracle.py --dump >/dev/null || { echo "FALLO oraculo"; exit 1; }

run () {
  ghdl -a --std=08 $DEPS "$RTL" 2>/dev/null || return 2
  ghdl -a --std=08 "$TB" 2>/dev/null || return 2
  ghdl -e --std=08 tb_dsp_mmio_fft 2>/dev/null || return 2
  timeout 180 ghdl -r --std=08 tb_dsp_mmio_fft --stop-time=2000ms 2>&1 | grep -E "OK|MUTANTE|errores=" | tail -1
}

cp "$RTL" "$GOLD"
echo ""; echo ">> M0 GOLDEN (debe imprimir 'FFT-MMIO OK')"
echo "   $(run)"

echo ""; echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO')"
sed 's/dr_wdata <= fft_rd_im & fft_rd_re;/dr_wdata <= fft_rd_re \& fft_rd_im;/' "$GOLD" > "$RTL"
echo "   [M1_store_swap] $(run)"
sed 's/fft_wr_re  <= dr_rdata(15 downto 0);/fft_wr_re  <= dr_rdata(31 downto 16);/' "$GOLD" > "$RTL"
echo "   [M2_load_reim] $(run)"
sed "s/fft_inv<='1'; fft_log2n<=log2n_r(3 downto 0);/fft_inv<='0'; fft_log2n<=log2n_r(3 downto 0);/" "$GOLD" > "$RTL"
echo "   [M3_inv_mal] $(run)"
sed "s/fft_inv<='0'; fft_log2n<=log2n_r(3 downto 0);/fft_inv<='0'; fft_log2n<=x\"3\";/" "$GOLD" > "$RTL"
echo "   [M4_log2n_fijo] $(run)"

cp "$GOLD" "$RTL"
echo ""; echo ">> golden restaurado. Layer 2b lista si M0=OK y M1..M4=VIVO."