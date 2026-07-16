#!/bin/bash
# ============================================================================
# adc_paso1_pdmgen.sh : ADC delta-sigma soft IP v1 - Paso 1 (capa 1a)
# Generador PDM: acumulador de fase + LUT senoidal 1024x16 + modulador
# delta-sigma digital de 2o orden. RTL vs modelo Python event-driven
# independiente, 65536 bits bit-identicos + checksum LFSR-32 + 4 mutaciones.
# Uso: bash adc_paso1_pdmgen.sh
# Linea final esperada:
# ADC PASO1 PDMGEN: PASS CHK=0x90C8821F MUT=4/4 @ 655595000000 fs
# ============================================================================
(
set -e
DIR="$HOME/adc_ip"
mkdir -p "$DIR"
cd "$DIR"

# ---------------------------------------------------------------- modelo ---
cat > modelo_pdm.py << 'EOF_MODELO'
#!/usr/bin/env python3
# Modelo event-driven independiente del generador PDM delta-sigma 2o orden (capa 1a)
# Genera: adc_sin_lut_pkg.vhd, pdm_esperado.txt, chk_esperado.txt
LUT = [0, 121, 241, 362, 482, 603, 724, 844, 965, 1085, 1206, 1326, 1446, 1567, 1687, 1807, 1927, 2047, 2167, 2287, 2407, 2526, 2646, 2765, 2885, 3004, 3123, 3242, 3361, 3480, 3599, 3717, 3835, 3954, 4072, 4190, 4308, 4425, 4543, 4660, 4777, 4894, 5011, 5127, 5244, 5360, 5476, 5591, 5707, 5822, 5937, 6052, 6167, 6281, 6396, 6510, 6623, 6737, 6850, 6963, 7076, 7188, 7300, 7412, 7524, 7635, 7746, 7857, 7967, 8077, 8187, 8297, 8406, 8515, 8623, 8731, 8839, 8947, 9054, 9161, 9268, 9374, 9480, 9585, 9690, 9795, 9900, 10004, 10107, 10211, 10313, 10416, 10518, 10620, 10721, 10822, 10923, 11023, 11122, 11222, 11320, 11419, 11517, 11614, 11711, 11808, 11904, 12000, 12095, 12190, 12285, 12379, 12472, 12565, 12658, 12750, 12841, 12932, 13023, 13113, 13203, 13292, 13381, 13469, 13556, 13643, 13730, 13816, 13902, 13987, 14071, 14155, 14239, 14322, 14404, 14486, 14567, 14648, 14728, 14808, 14887, 14965, 15043, 15121, 15197, 15274, 15349, 15424, 15499, 15573, 15646, 15719, 15791, 15863, 15934, 16004, 16074, 16143, 16211, 16279, 16347, 16413, 16479, 16545, 16610, 16674, 16738, 16801, 16863, 16925, 16986, 17046, 17106, 17165, 17224, 17281, 17339, 17395, 17451, 17506, 17561, 17615, 17668, 17721, 17772, 17824, 17874, 17924, 17973, 18022, 18070, 18117, 18163, 18209, 18254, 18299, 18343, 18386, 18428, 18470, 18511, 18551, 18591, 18630, 18668, 18705, 18742, 18778, 18813, 18848, 18882, 18915, 18948, 18980, 19011, 19041, 19071, 19100, 19128, 19156, 19182, 19208, 19234, 19258, 19282, 19305, 19328, 19350, 19371, 19391, 19410, 19429, 19447, 19465, 19481, 19497, 19512, 19527, 19540, 19553, 19565, 19577, 19588, 19597, 19607, 19615, 19623, 19630, 19636, 19642, 19647, 19651, 19654, 19657, 19659, 19660, 19660, 19660, 19659, 19657, 19654, 19651, 19647, 19642, 19636, 19630, 19623, 19615, 19607, 19597, 19588, 19577, 19565, 19553, 19540, 19527, 19512, 19497, 19481, 19465, 19447, 19429, 19410, 19391, 19371, 19350, 19328, 19305, 19282, 19258, 19234, 19208, 19182, 19156, 19128, 19100, 19071, 19041, 19011, 18980, 18948, 18915, 18882, 18848, 18813, 18778, 18742, 18705, 18668, 18630, 18591, 18551, 18511, 18470, 18428, 18386, 18343, 18299, 18254, 18209, 18163, 18117, 18070, 18022, 17973, 17924, 17874, 17824, 17772, 17721, 17668, 17615, 17561, 17506, 17451, 17395, 17339, 17281, 17224, 17165, 17106, 17046, 16986, 16925, 16863, 16801, 16738, 16674, 16610, 16545, 16479, 16413, 16347, 16279, 16211, 16143, 16074, 16004, 15934, 15863, 15791, 15719, 15646, 15573, 15499, 15424, 15349, 15274, 15197, 15121, 15043, 14965, 14887, 14808, 14728, 14648, 14567, 14486, 14404, 14322, 14239, 14155, 14071, 13987, 13902, 13816, 13730, 13643, 13556, 13469, 13381, 13292, 13203, 13113, 13023, 12932, 12841, 12750, 12658, 12565, 12472, 12379, 12285, 12190, 12095, 12000, 11904, 11808, 11711, 11614, 11517, 11419, 11320, 11222, 11122, 11023, 10923, 10822, 10721, 10620, 10518, 10416, 10313, 10211, 10107, 10004, 9900, 9795, 9690, 9585, 9480, 9374, 9268, 9161, 9054, 8947, 8839, 8731, 8623, 8515, 8406, 8297, 8187, 8077, 7967, 7857, 7746, 7635, 7524, 7412, 7300, 7188, 7076, 6963, 6850, 6737, 6623, 6510, 6396, 6281, 6167, 6052, 5937, 5822, 5707, 5591, 5476, 5360, 5244, 5127, 5011, 4894, 4777, 4660, 4543, 4425, 4308, 4190, 4072, 3954, 3835, 3717, 3599, 3480, 3361, 3242, 3123, 3004, 2885, 2765, 2646, 2526, 2407, 2287, 2167, 2047, 1927, 1807, 1687, 1567, 1446, 1326, 1206, 1085, 965, 844, 724, 603, 482, 362, 241, 121, 0, -121, -241, -362, -482, -603, -724, -844, -965, -1085, -1206, -1326, -1446, -1567, -1687, -1807, -1927, -2047, -2167, -2287, -2407, -2526, -2646, -2765, -2885, -3004, -3123, -3242, -3361, -3480, -3599, -3717, -3835, -3954, -4072, -4190, -4308, -4425, -4543, -4660, -4777, -4894, -5011, -5127, -5244, -5360, -5476, -5591, -5707, -5822, -5937, -6052, -6167, -6281, -6396, -6510, -6623, -6737, -6850, -6963, -7076, -7188, -7300, -7412, -7524, -7635, -7746, -7857, -7967, -8077, -8187, -8297, -8406, -8515, -8623, -8731, -8839, -8947, -9054, -9161, -9268, -9374, -9480, -9585, -9690, -9795, -9900, -10004, -10107, -10211, -10313, -10416, -10518, -10620, -10721, -10822, -10923, -11023, -11122, -11222, -11320, -11419, -11517, -11614, -11711, -11808, -11904, -12000, -12095, -12190, -12285, -12379, -12472, -12565, -12658, -12750, -12841, -12932, -13023, -13113, -13203, -13292, -13381, -13469, -13556, -13643, -13730, -13816, -13902, -13987, -14071, -14155, -14239, -14322, -14404, -14486, -14567, -14648, -14728, -14808, -14887, -14965, -15043, -15121, -15197, -15274, -15349, -15424, -15499, -15573, -15646, -15719, -15791, -15863, -15934, -16004, -16074, -16143, -16211, -16279, -16347, -16413, -16479, -16545, -16610, -16674, -16738, -16801, -16863, -16925, -16986, -17046, -17106, -17165, -17224, -17281, -17339, -17395, -17451, -17506, -17561, -17615, -17668, -17721, -17772, -17824, -17874, -17924, -17973, -18022, -18070, -18117, -18163, -18209, -18254, -18299, -18343, -18386, -18428, -18470, -18511, -18551, -18591, -18630, -18668, -18705, -18742, -18778, -18813, -18848, -18882, -18915, -18948, -18980, -19011, -19041, -19071, -19100, -19128, -19156, -19182, -19208, -19234, -19258, -19282, -19305, -19328, -19350, -19371, -19391, -19410, -19429, -19447, -19465, -19481, -19497, -19512, -19527, -19540, -19553, -19565, -19577, -19588, -19597, -19607, -19615, -19623, -19630, -19636, -19642, -19647, -19651, -19654, -19657, -19659, -19660, -19660, -19660, -19659, -19657, -19654, -19651, -19647, -19642, -19636, -19630, -19623, -19615, -19607, -19597, -19588, -19577, -19565, -19553, -19540, -19527, -19512, -19497, -19481, -19465, -19447, -19429, -19410, -19391, -19371, -19350, -19328, -19305, -19282, -19258, -19234, -19208, -19182, -19156, -19128, -19100, -19071, -19041, -19011, -18980, -18948, -18915, -18882, -18848, -18813, -18778, -18742, -18705, -18668, -18630, -18591, -18551, -18511, -18470, -18428, -18386, -18343, -18299, -18254, -18209, -18163, -18117, -18070, -18022, -17973, -17924, -17874, -17824, -17772, -17721, -17668, -17615, -17561, -17506, -17451, -17395, -17339, -17281, -17224, -17165, -17106, -17046, -16986, -16925, -16863, -16801, -16738, -16674, -16610, -16545, -16479, -16413, -16347, -16279, -16211, -16143, -16074, -16004, -15934, -15863, -15791, -15719, -15646, -15573, -15499, -15424, -15349, -15274, -15197, -15121, -15043, -14965, -14887, -14808, -14728, -14648, -14567, -14486, -14404, -14322, -14239, -14155, -14071, -13987, -13902, -13816, -13730, -13643, -13556, -13469, -13381, -13292, -13203, -13113, -13023, -12932, -12841, -12750, -12658, -12565, -12472, -12379, -12285, -12190, -12095, -12000, -11904, -11808, -11711, -11614, -11517, -11419, -11320, -11222, -11122, -11023, -10923, -10822, -10721, -10620, -10518, -10416, -10313, -10211, -10107, -10004, -9900, -9795, -9690, -9585, -9480, -9374, -9268, -9161, -9054, -8947, -8839, -8731, -8623, -8515, -8406, -8297, -8187, -8077, -7967, -7857, -7746, -7635, -7524, -7412, -7300, -7188, -7076, -6963, -6850, -6737, -6623, -6510, -6396, -6281, -6167, -6052, -5937, -5822, -5707, -5591, -5476, -5360, -5244, -5127, -5011, -4894, -4777, -4660, -4543, -4425, -4308, -4190, -4072, -3954, -3835, -3717, -3599, -3480, -3361, -3242, -3123, -3004, -2885, -2765, -2646, -2526, -2407, -2287, -2167, -2047, -1927, -1807, -1687, -1567, -1446, -1326, -1206, -1085, -965, -844, -724, -603, -482, -362, -241, -121]

FINC = 0x00193000
NBITS = 65536

def wrap24(v):
    return ((v + (1 << 23)) & 0xFFFFFF) - (1 << 23)

def main():
    # --- escribir paquete VHDL con la LUT ---
    with open('adc_sin_lut_pkg.vhd', 'w') as f:
        f.write('library ieee;\nuse ieee.std_logic_1164.all;\n\n')
        f.write('package adc_sin_lut_pkg is\n')
        f.write('  type t_sin_lut is array (0 to 1023) of integer range -32768 to 32767;\n')
        f.write('  constant C_SIN_LUT : t_sin_lut := (\n')
        for i in range(0, 1024, 8):
            chunk = ', '.join(str(v) for v in LUT[i:i+8])
            sep = ',' if i + 8 < 1024 else ''
            f.write('    ' + chunk + sep + '\n')
        f.write('  );\nend package adc_sin_lut_pkg;\n')

    # --- simulacion ciclo a ciclo (espejo exacto del RTL) ---
    phase = 0; x = 0; i1 = 0; i2 = 0; y = 0
    bits = []
    edge = 0
    while len(bits) < NBITS:
        edge += 1
        # calcular nuevos a partir de viejos (commit atomico)
        phase_n = (phase + FINC) & 0xFFFFFFFF
        x_n = LUT[(phase >> 22) & 0x3FF]
        fb = 32768 if y == 1 else -32768
        i1_n = wrap24(i1 + x - fb)
        i2_n = wrap24(i2 + i1_n - fb - fb)
        y_n = 1 if i2_n >= 0 else 0
        phase, x, i1, i2, y = phase_n, x_n, i1_n, i2_n, y_n
        if edge >= 3:
            bits.append(y)

    chk = 0xFFFFFFFF
    for b in bits:
        msb = (chk >> 31) & 1
        chk = ((chk << 1) | b) & 0xFFFFFFFF
        if msb:
            chk ^= 0x04C11DB7

    with open('pdm_esperado.txt', 'w') as f:
        f.write('\n'.join(str(b) for b in bits) + '\n')
    with open('chk_esperado.txt', 'w') as f:
        f.write('%08X\n' % chk)
    print('MODELO PDM: %d bits, CHK=0x%08X' % (len(bits), chk))

if __name__ == '__main__':
    main()
EOF_MODELO

# ------------------------------------------------------------------- RTL ---
cat > adc_pdmgen.vhd << 'EOF_RTL'
-- ============================================================================
-- adc_pdmgen.vhd : Generador PDM de prueba para el ADC delta-sigma soft IP v1
-- Acumulador de fase 32 bits + LUT senoidal 1024x16 (ROM sincrona, molde BRAM)
-- + modulador delta-sigma digital de 2o orden (CIFB) con cuantizador de 1 bit.
-- Amplitud LUT = 0.6 FS (estabilidad del modulador de 2o orden).
-- VHDL-2008. Reset asincrono activo bajo (convencion de la familia).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adc_sin_lut_pkg.all;

entity adc_pdmgen is
  port (
    clk         : in  std_logic;
    aresetn     : in  std_logic;
    en_i        : in  std_logic;
    finc_i      : in  std_logic_vector(31 downto 0);
    pdm_o       : out std_logic;
    pdm_valid_o : out std_logic
  );
end entity adc_pdmgen;

architecture rtl of adc_pdmgen is
  signal phase : unsigned(31 downto 0);
  signal x     : signed(15 downto 0);
  signal i1    : signed(23 downto 0);
  signal i2    : signed(23 downto 0);
  signal y     : std_logic;
  signal wcnt  : unsigned(1 downto 0);
  signal valid : std_logic;
begin

  proc_pdm : process (clk, aresetn)
    variable v_fb : signed(23 downto 0);
    variable v_i1 : signed(23 downto 0);
    variable v_i2 : signed(23 downto 0);
  begin
    if aresetn = '0' then
      phase <= (others => '0');
      x     <= (others => '0');
      i1    <= (others => '0');
      i2    <= (others => '0');
      y     <= '0';
      wcnt  <= (others => '0');
      valid <= '0';
    elsif rising_edge(clk) then
      if en_i = '1' then
        -- acumulador de fase (fase vieja indexa la LUT)
        phase <= phase + unsigned(finc_i);
        -- lectura sincrona de ROM (inferible como BRAM)
        x <= to_signed(C_SIN_LUT(to_integer(phase(31 downto 22))), 16);
        -- modulador CIFB de 2o orden, realimentacion +/-FS
        if y = '1' then
          v_fb := to_signed(32768, 24);
        else
          v_fb := to_signed(-32768, 24);
        end if;
        v_i1 := i1 + resize(x, 24) - v_fb;
        v_i2 := i2 + v_i1 - v_fb - v_fb;
        if v_i2 >= 0 then
          y <= '1';
        else
          y <= '0';
        end if;
        i1 <= v_i1;
        i2 <= v_i2;
        -- calentamiento del pipeline: fase -> x -> y (2 ciclos)
        if wcnt /= "11" then
          wcnt <= wcnt + 1;
        end if;
        if wcnt >= 2 then
          valid <= '1';
        end if;
      end if;
    end if;
  end process proc_pdm;

  pdm_o       <= y;
  pdm_valid_o <= valid;

end architecture rtl;
EOF_RTL

# -------------------------------------------------------------------- TB ---
cat > tb_pdmgen.vhd << 'EOF_TB'
-- ============================================================================
-- tb_pdmgen.vhd : Capa 1a del ADC delta-sigma soft IP v1
-- Compara bit a bit 65536 bits PDM del RTL contra el modelo Python
-- event-driven independiente (pdm_esperado.txt) y verifica el checksum
-- LFSR-32 (chk_esperado.txt). Criterio de PASS: firma bit-identica.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_pdmgen is
end entity tb_pdmgen;

architecture sim of tb_pdmgen is
  constant C_NBITS : integer := 65536;
  constant C_FINC  : std_logic_vector(31 downto 0) := x"00193000";

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal en      : std_logic := '0';
  signal pdm     : std_logic;
  signal pdm_v   : std_logic;
begin

  dut : entity work.adc_pdmgen
    port map (
      clk         => clk,
      aresetn     => aresetn,
      en_i        => en,
      finc_i      => C_FINC,
      pdm_o       => pdm,
      pdm_valid_o => pdm_v
    );

  proc_clk : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process proc_clk;

  proc_stim : process
    file f_bits      : text;
    file f_chk       : text;
    variable v_line  : line;
    variable v_exp   : integer;
    variable v_n     : integer := 0;
    variable v_chk   : unsigned(31 downto 0) := (others => '1');
    variable v_msb   : std_logic;
    variable v_bit   : unsigned(0 downto 0);
    variable v_chk_e : std_logic_vector(31 downto 0);
  begin
    file_open(f_bits, "pdm_esperado.txt", read_mode);
    file_open(f_chk,  "chk_esperado.txt", read_mode);

    aresetn <= '0';
    en      <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
    en <= '1';

    while v_n < C_NBITS loop
      wait until rising_edge(clk);
      if pdm_v = '1' then
        readline(f_bits, v_line);
        read(v_line, v_exp);
        if pdm = '1' then
          v_bit := "1";
        else
          v_bit := "0";
        end if;
        assert to_integer(v_bit) = v_exp
          report "FALLO PDM: bit " & integer'image(v_n) &
                 " esperado " & integer'image(v_exp) &
                 " obtenido " & integer'image(to_integer(v_bit))
          severity failure;
        v_msb := v_chk(31);
        v_chk := v_chk(30 downto 0) & v_bit(0);
        if v_msb = '1' then
          v_chk := v_chk xor x"04C11DB7";
        end if;
        v_n := v_n + 1;
      end if;
    end loop;

    readline(f_chk, v_line);
    hread(v_line, v_chk_e);
    assert std_logic_vector(v_chk) = v_chk_e
      report "FALLO CHECKSUM: esperado 0x" & to_hstring(v_chk_e) &
             " obtenido 0x" & to_hstring(std_logic_vector(v_chk))
      severity failure;

    report "FIN SIMULACION PDMGEN: PASS CHK=0x" &
           to_hstring(std_logic_vector(v_chk)) & " @ " & time'image(now);
    finish;
  end process proc_stim;

end architecture sim;
EOF_TB

# ------------------------------------------------- modelo + oro + mutantes -
python3 modelo_pdm.py

rm -rf build && mkdir build && cd build
cp ../pdm_esperado.txt ../chk_esperado.txt .
ghdl -a --std=08 --workdir=. ../adc_sin_lut_pkg.vhd ../adc_pdmgen.vhd ../tb_pdmgen.vhd
ghdl -e --std=08 --workdir=. tb_pdmgen
GOLD=$(ghdl -r --std=08 --workdir=. tb_pdmgen 2>&1 | grep -m1 "FIN SIMULACION PDMGEN: PASS" || true)
cd ..
if [ -z "$GOLD" ]; then
  echo "ADC PASO1 PDMGEN: FALLO EN CORRIDA DORADA"
  exit 1
fi
CHK=$(echo "$GOLD" | sed 's/.*CHK=\(0x[0-9A-F]*\).*/\1/')
TS=$(echo "$GOLD" | sed 's/.*@ \(.*\)$/\1/')

DET=0
for m in 1 2 3 4; do
  rm -rf mut$m && mkdir mut$m && cp adc_pdmgen.vhd mut$m/
  case $m in
    1) sed -i 's/phase(31 downto 22)/phase(30 downto 21)/' mut$m/adc_pdmgen.vhd ;;
    2) sed -i 's/- v_fb - v_fb;/- v_fb;/' mut$m/adc_pdmgen.vhd ;;
    3) sed -i 's/32768/32767/g' mut$m/adc_pdmgen.vhd ;;
    4) sed -i 's/v_i2 >= 0/v_i2 > 0/' mut$m/adc_pdmgen.vhd ;;
  esac
  if diff -q adc_pdmgen.vhd mut$m/adc_pdmgen.vhd > /dev/null; then
    echo "MUT$m: sed no aplico la mutacion"
    exit 1
  fi
  ( cd mut$m
    cp ../pdm_esperado.txt ../chk_esperado.txt .
    ghdl -a --std=08 --workdir=. ../adc_sin_lut_pkg.vhd adc_pdmgen.vhd ../tb_pdmgen.vhd > /dev/null 2>&1
    ghdl -e --std=08 --workdir=. tb_pdmgen > /dev/null 2>&1
    ghdl -r --std=08 --workdir=. tb_pdmgen 2>&1 | grep -q "FALLO" )
  if [ $? -eq 0 ]; then
    DET=$((DET+1))
    echo "MUT$m: detectada"
  else
    echo "MUT$m: NO DETECTADA"
  fi
done

if [ "$DET" -ne 4 ]; then
  echo "ADC PASO1 PDMGEN: FALLO EN MUTACIONES ($DET/4)"
  exit 1
fi

echo "ADC PASO1 PDMGEN: PASS CHK=$CHK MUT=$DET/4 @ $TS"
)
