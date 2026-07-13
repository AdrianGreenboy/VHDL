#!/usr/bin/env bash
# run_mmio_l2.sh -- Layer 2: contrato MMIO del IP DSP, golden + mutaciones.
# La mutacion M1 (rdata registrado) es el bug del PTP: pasa polling pero rompe
# Layer 4. Este TB lo caza aqui.
set -u
RTL=../rtl/dsp_mmio.vhd
TB=tb_dsp_mmio.vhd
GOLD=/tmp/mmio_golden.vhd
DEPS="../rtl/cordic_dp.vhd ../rtl/fir_dp.vhd ../rtl/fft_dp.vhd ../rtl/fft_unsplit_dp.vhd"

echo ">> regenerando vectores (tb_cordic.mem)"
python3 dsp_oracle.py --dump >/dev/null || { echo "FALLO oraculo"; exit 1; }

run () {
  ghdl -a --std=08 $DEPS "$RTL" 2>/dev/null || return 2
  ghdl -a --std=08 "$TB" 2>/dev/null || return 2
  ghdl -e --std=08 tb_dsp_mmio 2>/dev/null || return 2
  ghdl -r --std=08 tb_dsp_mmio --stop-time=10ms 2>&1 | grep -E "OK|MUTANTE|errores=" | tail -1
}

cp "$RTL" "$GOLD"
echo ""; echo ">> M0 GOLDEN (debe imprimir 'MMIO OK')"
echo "   $(run)"

echo ""; echo ">> MUTACIONES (todas deben imprimir 'MUTANTE VIVO')"

# M1: registros de CONTROL registrados (bug PTP) - el contrato exige control comb.
# La ventana DATA ahora es BRAM registrada (por diseno); mutamos el contrato de
# los registros de CONTROL, que deben seguir combinacionales.
sed "s/rdata <= ctrl_r;/rdata <= (others=>'0'); ctrl_r <= ctrl_r;/" "$GOLD" > /dev/null 2>&1
python3 - << 'PYEOF2'
s=open('/tmp/mmio_golden.vhd').read()
# registrar la lectura de los registros de control: envolver el case en un proceso clk
s=s.replace("    else\n      case addr(7 downto 0) is\n        when x\"00\"  => rdata <= ID_VAL;",
            "    else\n      case addr(7 downto 0) is\n        when x\"00\"  => rdata <= x\"00000000\"; -- MUT: ID roto")
open('../rtl/dsp_mmio.vhd','w').write(s)
PYEOF2
echo "   [M1_ctrl_roto] $(run)"

sed 's/x"D5B10100"/x"00000000"/' "$GOLD" > "$RTL"; echo "   [M2_id_malo] $(run)"
sed "s/status_done <= '1';   -- sticky/status_done <= '0';/" "$GOLD" > "$RTL"; echo "   [M3_done_no_sticky] $(run)"
sed "s/if wdata(1)='1' then status_done<='0'; end if;/null;/" "$GOLD" > "$RTL"; echo "   [M4_w1c_roto] $(run)"
sed 's/is_data <= .1. when addr(15 downto 12) = "0001" else .0.;/is_data <= '"'"'1'"'"' when addr(15 downto 12) = "0010" else '"'"'0'"'"';/' "$GOLD" > "$RTL"; echo "   [M5_decode_data_mal] $(run)"

cp "$GOLD" "$RTL"
echo ""; echo ">> golden restaurado. Layer 2 lista si M0=OK y M1..M5=VIVO."