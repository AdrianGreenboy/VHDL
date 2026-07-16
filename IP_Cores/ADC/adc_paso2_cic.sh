#!/bin/bash
# ============================================================================
# adc_paso2_cic.sh : ADC delta-sigma soft IP v1 - Paso 2 (capa 1b)
# Decimador CIC sinc3: 3 integradores + 3 combs, OSR {32,64,128,256},
# acumuladores 26 bits (Hogenauer, entrada +/-1), normalizacion Q1.23
# con saturacion. RTL vs modelo bit-bang con corrupciones inyectadas:
# gaps de valid, DC full-scale +/- (estancado), cambio de OSR en caliente,
# tono idle alternante. 164 muestras bit-identicas + 5 mutaciones.
# Uso: bash adc_paso2_cic.sh
# Linea final esperada:
# ADC PASO2 CIC: PASS N=164 CHK=0x148B6E65 MUT=5/5 @ 344565000000 fs
# ============================================================================
(
set -e
DIR="$HOME/adc_ip"
mkdir -p "$DIR"
cd "$DIR"

# ---------------------------------------------------------------- modelo ---
cat > modelo_cic.py << 'EOF_MODELO'
#!/usr/bin/env python3
# Modelo bit-bang independiente del decimador CIC sinc3 (capa 1b)
# Genera estimulo con corrupciones (gaps de valid, DC full-scale +/-,
# bitstream estancado/alternante, cambio de OSR en caliente) y las
# muestras esperadas bit-exactas.
# Escribe: estimulo_cic.txt (lineas "bit valid osr"), muestras_esperadas.txt,
#          resumen_cic.txt (cuenta + CHK)
LUT = [0, 121, 241, 362, 482, 603, 724, 844, 965, 1085, 1206, 1326, 1446, 1567, 1687, 1807, 1927, 2047, 2167, 2287, 2407, 2526, 2646, 2765, 2885, 3004, 3123, 3242, 3361, 3480, 3599, 3717, 3835, 3954, 4072, 4190, 4308, 4425, 4543, 4660, 4777, 4894, 5011, 5127, 5244, 5360, 5476, 5591, 5707, 5822, 5937, 6052, 6167, 6281, 6396, 6510, 6623, 6737, 6850, 6963, 7076, 7188, 7300, 7412, 7524, 7635, 7746, 7857, 7967, 8077, 8187, 8297, 8406, 8515, 8623, 8731, 8839, 8947, 9054, 9161, 9268, 9374, 9480, 9585, 9690, 9795, 9900, 10004, 10107, 10211, 10313, 10416, 10518, 10620, 10721, 10822, 10923, 11023, 11122, 11222, 11320, 11419, 11517, 11614, 11711, 11808, 11904, 12000, 12095, 12190, 12285, 12379, 12472, 12565, 12658, 12750, 12841, 12932, 13023, 13113, 13203, 13292, 13381, 13469, 13556, 13643, 13730, 13816, 13902, 13987, 14071, 14155, 14239, 14322, 14404, 14486, 14567, 14648, 14728, 14808, 14887, 14965, 15043, 15121, 15197, 15274, 15349, 15424, 15499, 15573, 15646, 15719, 15791, 15863, 15934, 16004, 16074, 16143, 16211, 16279, 16347, 16413, 16479, 16545, 16610, 16674, 16738, 16801, 16863, 16925, 16986, 17046, 17106, 17165, 17224, 17281, 17339, 17395, 17451, 17506, 17561, 17615, 17668, 17721, 17772, 17824, 17874, 17924, 17973, 18022, 18070, 18117, 18163, 18209, 18254, 18299, 18343, 18386, 18428, 18470, 18511, 18551, 18591, 18630, 18668, 18705, 18742, 18778, 18813, 18848, 18882, 18915, 18948, 18980, 19011, 19041, 19071, 19100, 19128, 19156, 19182, 19208, 19234, 19258, 19282, 19305, 19328, 19350, 19371, 19391, 19410, 19429, 19447, 19465, 19481, 19497, 19512, 19527, 19540, 19553, 19565, 19577, 19588, 19597, 19607, 19615, 19623, 19630, 19636, 19642, 19647, 19651, 19654, 19657, 19659, 19660, 19660, 19660, 19659, 19657, 19654, 19651, 19647, 19642, 19636, 19630, 19623, 19615, 19607, 19597, 19588, 19577, 19565, 19553, 19540, 19527, 19512, 19497, 19481, 19465, 19447, 19429, 19410, 19391, 19371, 19350, 19328, 19305, 19282, 19258, 19234, 19208, 19182, 19156, 19128, 19100, 19071, 19041, 19011, 18980, 18948, 18915, 18882, 18848, 18813, 18778, 18742, 18705, 18668, 18630, 18591, 18551, 18511, 18470, 18428, 18386, 18343, 18299, 18254, 18209, 18163, 18117, 18070, 18022, 17973, 17924, 17874, 17824, 17772, 17721, 17668, 17615, 17561, 17506, 17451, 17395, 17339, 17281, 17224, 17165, 17106, 17046, 16986, 16925, 16863, 16801, 16738, 16674, 16610, 16545, 16479, 16413, 16347, 16279, 16211, 16143, 16074, 16004, 15934, 15863, 15791, 15719, 15646, 15573, 15499, 15424, 15349, 15274, 15197, 15121, 15043, 14965, 14887, 14808, 14728, 14648, 14567, 14486, 14404, 14322, 14239, 14155, 14071, 13987, 13902, 13816, 13730, 13643, 13556, 13469, 13381, 13292, 13203, 13113, 13023, 12932, 12841, 12750, 12658, 12565, 12472, 12379, 12285, 12190, 12095, 12000, 11904, 11808, 11711, 11614, 11517, 11419, 11320, 11222, 11122, 11023, 10923, 10822, 10721, 10620, 10518, 10416, 10313, 10211, 10107, 10004, 9900, 9795, 9690, 9585, 9480, 9374, 9268, 9161, 9054, 8947, 8839, 8731, 8623, 8515, 8406, 8297, 8187, 8077, 7967, 7857, 7746, 7635, 7524, 7412, 7300, 7188, 7076, 6963, 6850, 6737, 6623, 6510, 6396, 6281, 6167, 6052, 5937, 5822, 5707, 5591, 5476, 5360, 5244, 5127, 5011, 4894, 4777, 4660, 4543, 4425, 4308, 4190, 4072, 3954, 3835, 3717, 3599, 3480, 3361, 3242, 3123, 3004, 2885, 2765, 2646, 2526, 2407, 2287, 2167, 2047, 1927, 1807, 1687, 1567, 1446, 1326, 1206, 1085, 965, 844, 724, 603, 482, 362, 241, 121, 0, -121, -241, -362, -482, -603, -724, -844, -965, -1085, -1206, -1326, -1446, -1567, -1687, -1807, -1927, -2047, -2167, -2287, -2407, -2526, -2646, -2765, -2885, -3004, -3123, -3242, -3361, -3480, -3599, -3717, -3835, -3954, -4072, -4190, -4308, -4425, -4543, -4660, -4777, -4894, -5011, -5127, -5244, -5360, -5476, -5591, -5707, -5822, -5937, -6052, -6167, -6281, -6396, -6510, -6623, -6737, -6850, -6963, -7076, -7188, -7300, -7412, -7524, -7635, -7746, -7857, -7967, -8077, -8187, -8297, -8406, -8515, -8623, -8731, -8839, -8947, -9054, -9161, -9268, -9374, -9480, -9585, -9690, -9795, -9900, -10004, -10107, -10211, -10313, -10416, -10518, -10620, -10721, -10822, -10923, -11023, -11122, -11222, -11320, -11419, -11517, -11614, -11711, -11808, -11904, -12000, -12095, -12190, -12285, -12379, -12472, -12565, -12658, -12750, -12841, -12932, -13023, -13113, -13203, -13292, -13381, -13469, -13556, -13643, -13730, -13816, -13902, -13987, -14071, -14155, -14239, -14322, -14404, -14486, -14567, -14648, -14728, -14808, -14887, -14965, -15043, -15121, -15197, -15274, -15349, -15424, -15499, -15573, -15646, -15719, -15791, -15863, -15934, -16004, -16074, -16143, -16211, -16279, -16347, -16413, -16479, -16545, -16610, -16674, -16738, -16801, -16863, -16925, -16986, -17046, -17106, -17165, -17224, -17281, -17339, -17395, -17451, -17506, -17561, -17615, -17668, -17721, -17772, -17824, -17874, -17924, -17973, -18022, -18070, -18117, -18163, -18209, -18254, -18299, -18343, -18386, -18428, -18470, -18511, -18551, -18591, -18630, -18668, -18705, -18742, -18778, -18813, -18848, -18882, -18915, -18948, -18980, -19011, -19041, -19071, -19100, -19128, -19156, -19182, -19208, -19234, -19258, -19282, -19305, -19328, -19350, -19371, -19391, -19410, -19429, -19447, -19465, -19481, -19497, -19512, -19527, -19540, -19553, -19565, -19577, -19588, -19597, -19607, -19615, -19623, -19630, -19636, -19642, -19647, -19651, -19654, -19657, -19659, -19660, -19660, -19660, -19659, -19657, -19654, -19651, -19647, -19642, -19636, -19630, -19623, -19615, -19607, -19597, -19588, -19577, -19565, -19553, -19540, -19527, -19512, -19497, -19481, -19465, -19447, -19429, -19410, -19391, -19371, -19350, -19328, -19305, -19282, -19258, -19234, -19208, -19182, -19156, -19128, -19100, -19071, -19041, -19011, -18980, -18948, -18915, -18882, -18848, -18813, -18778, -18742, -18705, -18668, -18630, -18591, -18551, -18511, -18470, -18428, -18386, -18343, -18299, -18254, -18209, -18163, -18117, -18070, -18022, -17973, -17924, -17874, -17824, -17772, -17721, -17668, -17615, -17561, -17506, -17451, -17395, -17339, -17281, -17224, -17165, -17106, -17046, -16986, -16925, -16863, -16801, -16738, -16674, -16610, -16545, -16479, -16413, -16347, -16279, -16211, -16143, -16074, -16004, -15934, -15863, -15791, -15719, -15646, -15573, -15499, -15424, -15349, -15274, -15197, -15121, -15043, -14965, -14887, -14808, -14728, -14648, -14567, -14486, -14404, -14322, -14239, -14155, -14071, -13987, -13902, -13816, -13730, -13643, -13556, -13469, -13381, -13292, -13203, -13113, -13023, -12932, -12841, -12750, -12658, -12565, -12472, -12379, -12285, -12190, -12095, -12000, -11904, -11808, -11711, -11614, -11517, -11419, -11320, -11222, -11122, -11023, -10923, -10822, -10721, -10620, -10518, -10416, -10313, -10211, -10107, -10004, -9900, -9795, -9690, -9585, -9480, -9374, -9268, -9161, -9054, -8947, -8839, -8731, -8623, -8515, -8406, -8297, -8187, -8077, -7967, -7857, -7746, -7635, -7524, -7412, -7300, -7188, -7076, -6963, -6850, -6737, -6623, -6510, -6396, -6281, -6167, -6052, -5937, -5822, -5707, -5591, -5476, -5360, -5244, -5127, -5011, -4894, -4777, -4660, -4543, -4425, -4308, -4190, -4072, -3954, -3835, -3717, -3599, -3480, -3361, -3242, -3123, -3004, -2885, -2765, -2646, -2526, -2407, -2287, -2167, -2047, -1927, -1807, -1687, -1567, -1446, -1326, -1206, -1085, -965, -844, -724, -603, -482, -362, -241, -121]

FINC = 0x00193000

def wrap24(v):
    return ((v + (1 << 23)) & 0xFFFFFF) - (1 << 23)

def wrapN(v, n):
    m = (1 << n) - 1
    h = 1 << (n - 1)
    return ((v + h) & m) - h

# --- modulador delta-sigma 2o orden (identico al paso 1) ---
class Mod:
    def __init__(self):
        self.phase = 0; self.x = 0; self.i1 = 0; self.i2 = 0; self.y = 0
    def step(self):
        phase_n = (self.phase + FINC) & 0xFFFFFFFF
        x_n = LUT[(self.phase >> 22) & 0x3FF]
        fb = 32768 if self.y == 1 else -32768
        i1_n = wrap24(self.i1 + self.x - fb)
        i2_n = wrap24(self.i2 + i1_n - fb - fb)
        y_n = 1 if i2_n >= 0 else 0
        self.phase, self.x, self.i1, self.i2, self.y = phase_n, x_n, i1_n, i2_n, y_n
        return y_n

# --- decimador CIC sinc3 (espejo exacto del RTL, ACCW bits) ---
ACCW = 26
QMAX = 8388607
QMIN = -8388608
R_TAB = {0: 32, 1: 64, 2: 128, 3: 256}
SH_TAB = {0: ('L', 8), 1: ('L', 5), 2: ('L', 2), 3: ('R', 1)}

class Cic:
    def __init__(self):
        self.osr_r = 3
        self.clear()
    def clear(self):
        self.i1 = self.i2 = self.i3 = 0
        self.c1 = self.c2 = self.c3 = 0
        self.cnt = 0; self.warm = 0
    def step(self, bit, valid, osr):
        # devuelve muestra o None
        if osr != self.osr_r:
            self.osr_r = osr
            self.clear()
            return None
        if valid != 1:
            return None
        v_in = 1 if bit == 1 else -1
        v_i1 = wrapN(self.i1 + v_in, ACCW)
        v_i2 = wrapN(self.i2 + v_i1, ACCW)
        v_i3 = wrapN(self.i3 + v_i2, ACCW)
        self.i1, self.i2, self.i3 = v_i1, v_i2, v_i3
        if self.cnt == R_TAB[osr] - 1:
            self.cnt = 0
            v_d0 = v_i3
            v_y1 = wrapN(v_d0 - self.c1, ACCW)
            v_y2 = wrapN(v_y1 - self.c2, ACCW)
            v_y3 = wrapN(v_y2 - self.c3, ACCW)
            self.c1, self.c2, self.c3 = v_d0, v_y1, v_y2
            if self.warm != 3:
                self.warm += 1
                return None
            d, s = SH_TAB[osr]
            norm = (v_y3 << s) if d == 'L' else (v_y3 >> s)
            if norm > QMAX:
                norm = QMAX
            elif norm < QMIN:
                norm = QMIN
            return norm
        else:
            self.cnt += 1
            return None

def main():
    mod = Mod()
    cic = Cic()
    stim = []
    samples = []
    lcg = [12345]
    def rnd():
        lcg[0] = (1103515245 * lcg[0] + 12345) & 0x7FFFFFFF
        return (lcg[0] >> 16) & 7

    def run_until(n_samples, src, osr, gaps):
        got = 0
        while got < n_samples:
            if src == 'sin':
                b = mod.step()
            elif src == 'uno':
                b = 1
            elif src == 'cero':
                b = 0
            else:  # alterna
                b = len(stim) & 1
            v = 1
            if gaps and rnd() == 0:
                v = 0
            stim.append((b, v, osr))
            s = cic.step(b, v, osr)
            if s is not None:
                samples.append(s)
                got += 1

    # Fase A: senoidal OSR=256
    run_until(80, 'sin', 3, False)
    # Fase B: senoidal con gaps de valid (corrupcion de flujo)
    run_until(20, 'sin', 3, True)
    # Fase C: DC full-scale positivo (estancado en 1 -> saturacion +)
    run_until(8, 'uno', 3, False)
    # Fase D: DC full-scale negativo (estancado en 0 -> fondo exacto)
    run_until(8, 'cero', 3, False)
    # Fase E: cambio de OSR en caliente 256 -> 64 (reinit) + senoidal
    run_until(40, 'sin', 1, False)
    # Fase F: bitstream alternante 1010 (tono idle, DC ~ 0)
    run_until(8, 'alt', 1, False)

    chk = 0xFFFFFFFF
    for s in samples:
        w = s & 0xFFFFFF
        for k in range(23, -1, -1):
            bit = (w >> k) & 1
            msb = (chk >> 31) & 1
            chk = ((chk << 1) | bit) & 0xFFFFFFFF
            if msb:
                chk ^= 0x04C11DB7

    with open('estimulo_cic.txt', 'w') as f:
        f.write('\n'.join('%d %d %d' % t for t in stim) + '\n')
    with open('muestras_esperadas.txt', 'w') as f:
        f.write('\n'.join(str(s) for s in samples) + '\n')
    with open('resumen_cic.txt', 'w') as f:
        f.write('%d\n%08X\n' % (len(samples), chk))
    dcp = samples[87+8-1] if len(samples) > 95 else 0
    print('MODELO CIC: %d ciclos, %d muestras, CHK=0x%08X' % (len(stim), len(samples), chk))
    print('  ultimas DC+: %s  ultimas DC-: %s' % (samples[105:108], samples[113:116]))

if __name__ == '__main__':
    main()
EOF_MODELO

# ------------------------------------------------------------------- RTL ---
cat > adc_cic.vhd << 'EOF_RTL'
-- ============================================================================
-- adc_cic.vhd : Decimador CIC sinc3 del ADC delta-sigma soft IP v1
-- 3 integradores a tasa PDM + 3 combs a tasa decimada, M=1.
-- OSR configurable {32,64,128,256} por osr_sel_i; cambio en caliente
-- reinicia limpio el datapath (integradores, combs, contador, warmup).
-- Acumuladores de 26 bits con aritmetica modular (Hogenauer:
-- Bmax = 3*log2(256) + 2 bits de entrada con signo +/-1).
-- Normalizacion por barrel shift a Q1.23 con saturacion simetrica.
-- VHDL-2008. Reset asincrono activo bajo.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_cic is
  port (
    clk            : in  std_logic;
    aresetn        : in  std_logic;
    pdm_i          : in  std_logic;
    pdm_valid_i    : in  std_logic;
    osr_sel_i      : in  std_logic_vector(1 downto 0);
    sample_o       : out std_logic_vector(23 downto 0);
    sample_valid_o : out std_logic
  );
end entity adc_cic;

architecture rtl of adc_cic is
  constant C_ACCW : integer := 26;

  signal osr_r  : std_logic_vector(1 downto 0);
  signal i1     : signed(C_ACCW - 1 downto 0);
  signal i2     : signed(C_ACCW - 1 downto 0);
  signal i3     : signed(C_ACCW - 1 downto 0);
  signal c1d    : signed(C_ACCW - 1 downto 0);
  signal c2d    : signed(C_ACCW - 1 downto 0);
  signal c3d    : signed(C_ACCW - 1 downto 0);
  signal cnt    : unsigned(7 downto 0);
  signal warm   : unsigned(1 downto 0);
  signal sample : signed(23 downto 0);
  signal svalid : std_logic;

  function f_rmax (osr : std_logic_vector(1 downto 0)) return unsigned is
  begin
    case osr is
      when "00"   => return to_unsigned(31, 8);
      when "01"   => return to_unsigned(63, 8);
      when "10"   => return to_unsigned(127, 8);
      when others => return to_unsigned(255, 8);
    end case;
  end function f_rmax;

begin

  proc_cic : process (clk, aresetn)
    variable v_in   : signed(C_ACCW - 1 downto 0);
    variable v_i1   : signed(C_ACCW - 1 downto 0);
    variable v_i2   : signed(C_ACCW - 1 downto 0);
    variable v_i3   : signed(C_ACCW - 1 downto 0);
    variable v_d0   : signed(C_ACCW - 1 downto 0);
    variable v_y1   : signed(C_ACCW - 1 downto 0);
    variable v_y2   : signed(C_ACCW - 1 downto 0);
    variable v_y3   : signed(C_ACCW - 1 downto 0);
    variable v_norm : signed(33 downto 0);
  begin
    if aresetn = '0' then
      osr_r  <= "11";
      i1     <= (others => '0');
      i2     <= (others => '0');
      i3     <= (others => '0');
      c1d    <= (others => '0');
      c2d    <= (others => '0');
      c3d    <= (others => '0');
      cnt    <= (others => '0');
      warm   <= (others => '0');
      sample <= (others => '0');
      svalid <= '0';
    elsif rising_edge(clk) then
      svalid <= '0';
      if osr_sel_i /= osr_r then
        -- cambio de OSR en caliente: reinicio limpio del datapath
        osr_r <= osr_sel_i;
        i1    <= (others => '0');
        i2    <= (others => '0');
        i3    <= (others => '0');
        c1d   <= (others => '0');
        c2d   <= (others => '0');
        c3d   <= (others => '0');
        cnt   <= (others => '0');
        warm  <= (others => '0');
      elsif pdm_valid_i = '1' then
        if pdm_i = '1' then
          v_in := to_signed(1, C_ACCW);
        else
          v_in := to_signed(-1, C_ACCW);
        end if;
        -- seccion integradora (tasa PDM, wrap modular)
        v_i1 := i1 + v_in;
        v_i2 := i2 + v_i1;
        v_i3 := i3 + v_i2;
        i1   <= v_i1;
        i2   <= v_i2;
        i3   <= v_i3;
        if cnt = f_rmax(osr_r) then
          cnt <= (others => '0');
          -- seccion comb (tasa decimada, M=1)
          v_d0 := v_i3;
          v_y1 := v_d0 - c1d;
          v_y2 := v_y1 - c2d;
          v_y3 := v_y2 - c3d;
          c1d  <= v_d0;
          c2d  <= v_y1;
          c3d  <= v_y2;
          if warm /= "11" then
            warm <= warm + 1;
          else
            -- normalizacion a Q1.23 y saturacion simetrica
            case osr_r is
              when "00"   => v_norm := shift_left(resize(v_y3, 34), 8);
              when "01"   => v_norm := shift_left(resize(v_y3, 34), 5);
              when "10"   => v_norm := shift_left(resize(v_y3, 34), 2);
              when others => v_norm := shift_right(resize(v_y3, 34), 1);
            end case;
            if v_norm > to_signed(8388607, 34) then
              sample <= to_signed(8388607, 24);
            elsif v_norm < to_signed(-8388608, 34) then
              sample <= to_signed(-8388608, 24);
            else
              sample <= resize(v_norm, 24);
            end if;
            svalid <= '1';
          end if;
        else
          cnt <= cnt + 1;
        end if;
      end if;
    end if;
  end process proc_cic;

  sample_o       <= std_logic_vector(sample);
  sample_valid_o <= svalid;

end architecture rtl;
EOF_RTL

# -------------------------------------------------------------------- TB ---
cat > tb_cic.vhd << 'EOF_TB'
-- ============================================================================
-- tb_cic.vhd : Capa 1b del ADC delta-sigma soft IP v1
-- Reproduce el estimulo con corrupciones del modelo bit-bang
-- (estimulo_cic.txt: "bit valid osr" por ciclo) y compara cada muestra
-- decimada contra muestras_esperadas.txt. Verifica cuenta total y
-- checksum LFSR-32 (resumen_cic.txt).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_cic is
end entity tb_cic;

architecture sim of tb_cic is
  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal pdm     : std_logic := '0';
  signal pdm_v   : std_logic := '0';
  signal osr     : std_logic_vector(1 downto 0) := "11";
  signal smp     : std_logic_vector(23 downto 0);
  signal smp_v   : std_logic;

  signal n_smp   : integer := 0;
  signal chk     : unsigned(31 downto 0) := (others => '1');
begin

  dut : entity work.adc_cic
    port map (
      clk            => clk,
      aresetn        => aresetn,
      pdm_i          => pdm,
      pdm_valid_i    => pdm_v,
      osr_sel_i      => osr,
      sample_o       => smp,
      sample_valid_o => smp_v
    );

  proc_clk : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process proc_clk;

  -- monitor de muestras: compara cada strobe contra el archivo esperado
  proc_mon : process
    file f_smp     : text;
    variable v_l   : line;
    variable v_exp : integer;
    variable v_got : integer;
    variable v_c   : unsigned(31 downto 0) := (others => '1');
    variable v_msb : std_logic;
    variable v_w   : std_logic_vector(23 downto 0);
  begin
    file_open(f_smp, "muestras_esperadas.txt", read_mode);
    loop
      wait until rising_edge(clk);
      if smp_v = '1' then
        readline(f_smp, v_l);
        read(v_l, v_exp);
        v_got := to_integer(signed(smp));
        assert v_got = v_exp
          report "FALLO CIC: muestra " & integer'image(n_smp) &
                 " esperada " & integer'image(v_exp) &
                 " obtenida " & integer'image(v_got)
          severity failure;
        v_w := smp;
        for k in 23 downto 0 loop
          v_msb := v_c(31);
          v_c   := v_c(30 downto 0) & v_w(k);
          if v_msb = '1' then
            v_c := v_c xor x"04C11DB7";
          end if;
        end loop;
        chk   <= v_c;
        n_smp <= n_smp + 1;
      end if;
    end loop;
  end process proc_mon;

  proc_stim : process
    file f_stim    : text;
    file f_res     : text;
    variable v_l   : line;
    variable v_b   : integer;
    variable v_v   : integer;
    variable v_o   : integer;
    variable v_cnt : integer;
    variable v_chk : std_logic_vector(31 downto 0);
  begin
    file_open(f_stim, "estimulo_cic.txt", read_mode);
    file_open(f_res,  "resumen_cic.txt",  read_mode);

    aresetn <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);

    while not endfile(f_stim) loop
      readline(f_stim, v_l);
      read(v_l, v_b);
      read(v_l, v_v);
      read(v_l, v_o);
      if v_b = 1 then
        pdm <= '1';
      else
        pdm <= '0';
      end if;
      if v_v = 1 then
        pdm_v <= '1';
      else
        pdm_v <= '0';
      end if;
      osr <= std_logic_vector(to_unsigned(v_o, 2));
      wait until rising_edge(clk);
    end loop;

    pdm_v <= '0';
    for k in 0 to 7 loop
      wait until rising_edge(clk);
    end loop;

    readline(f_res, v_l);
    read(v_l, v_cnt);
    readline(f_res, v_l);
    hread(v_l, v_chk);

    assert n_smp = v_cnt
      report "FALLO CIC: cuenta de muestras esperada " & integer'image(v_cnt) &
             " obtenida " & integer'image(n_smp)
      severity failure;
    assert std_logic_vector(chk) = v_chk
      report "FALLO CIC CHECKSUM: esperado 0x" & to_hstring(v_chk) &
             " obtenido 0x" & to_hstring(std_logic_vector(chk))
      severity failure;

    report "FIN SIMULACION CIC: PASS N=" & integer'image(n_smp) &
           " CHK=0x" & to_hstring(std_logic_vector(chk)) &
           " @ " & time'image(now);
    finish;
  end process proc_stim;

end architecture sim;
EOF_TB

# ------------------------------------------------- modelo + oro + mutantes -
python3 modelo_cic.py

rm -rf build2 && mkdir build2 && cd build2
cp ../estimulo_cic.txt ../muestras_esperadas.txt ../resumen_cic.txt .
ghdl -a --std=08 --workdir=. ../adc_cic.vhd ../tb_cic.vhd
ghdl -e --std=08 --workdir=. tb_cic
GOLD=$(ghdl -r --std=08 --workdir=. tb_cic 2>&1 | grep -m1 "FIN SIMULACION CIC: PASS" || true)
cd ..
if [ -z "$GOLD" ]; then
  echo "ADC PASO2 CIC: FALLO EN CORRIDA DORADA"
  exit 1
fi
N=$(echo "$GOLD" | sed 's/.*PASS N=\([0-9]*\).*/\1/')
CHK=$(echo "$GOLD" | sed 's/.*CHK=\(0x[0-9A-F]*\).*/\1/')
TS=$(echo "$GOLD" | sed 's/.*@ \(.*\)$/\1/')
GOLDSIG="FIN SIMULACION CIC: PASS N=$N CHK=$CHK @ $TS"

DET=0
for m in 1 2 3 4 5; do
  rm -rf cmut$m && mkdir cmut$m && cp adc_cic.vhd cmut$m/
  case $m in
    1) sed -i 's/c2d  <= v_y1;/c2d  <= v_d0;/' cmut$m/adc_cic.vhd ;;
    2) sed -i 's/C_ACCW : integer := 26/C_ACCW : integer := 24/' cmut$m/adc_cic.vhd ;;
    3) sed -i 's/shift_right(resize(v_y3, 34), 1)/shift_right(resize(v_y3, 34), 2)/' cmut$m/adc_cic.vhd ;;
    4) sed -i 's/> to_signed(8388607, 34)/> to_signed(16777215, 34)/' cmut$m/adc_cic.vhd ;;
    5) sed -i 's/if osr_sel_i \/= osr_r then/if osr_r \/= osr_r then/' cmut$m/adc_cic.vhd ;;
  esac
  if diff -q adc_cic.vhd cmut$m/adc_cic.vhd > /dev/null; then
    echo "CMUT$m: sed no aplico la mutacion"
    exit 1
  fi
  ( cd cmut$m
    cp ../estimulo_cic.txt ../muestras_esperadas.txt ../resumen_cic.txt .
    ghdl -a --std=08 --workdir=. adc_cic.vhd ../tb_cic.vhd > /dev/null 2>&1
    ghdl -e --std=08 --workdir=. tb_cic > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 --workdir=. tb_cic 2>&1 | grep -m1 "FIN SIMULACION CIC: PASS" || true)
    if echo "$OUT" | grep -q "$GOLDSIG"; then exit 1; else exit 0; fi )
  if [ $? -eq 0 ]; then
    DET=$((DET+1))
    echo "CMUT$m: detectada"
  else
    echo "CMUT$m: NO DETECTADA"
  fi
done

if [ "$DET" -ne 5 ]; then
  echo "ADC PASO2 CIC: FALLO EN MUTACIONES ($DET/5)"
  exit 1
fi

echo "ADC PASO2 CIC: PASS N=$N CHK=$CHK MUT=$DET/5 @ $TS"
)
