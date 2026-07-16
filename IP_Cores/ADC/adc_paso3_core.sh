#!/bin/bash
# ============================================================================
# adc_paso3_core.sh : ADC delta-sigma soft IP v1 - Paso 3 (capa 1c)
# Cadena completa RTL->RTL: adc_pdmgen + sync 2FF + mux de fuente (hook B)
# + monitor de actividad externa + adc_cic, contra modelo compuesto
# ciclo-exacto. Plan T1..T5: nominal OSR256, OSR en caliente 256->64,
# ruta externa con modulador determinista, Phase-0 anti-modo-comun
# (entrada inerte -> timeout en ciclo 33222) con ventana en=0, y retorno
# a fuente interna. Checks por-ciclo de pdm_fb_o y ext_timeout_o.
# Incluye sin modificacion los RTL de los pasos 1 y 2. 5 mutaciones.
# Uso: bash adc_paso3_core.sh
# Linea final esperada:
# ADC PASO3 CORE: PASS N=233 CHK=0x7CEE740E MUT=5/5 @ 343685000000 fs
# ============================================================================
(
set -e
DIR="$HOME/adc_ip"
mkdir -p "$DIR"
cd "$DIR"

# ---------------------------------------------------------------- modelo ---
cat > modelo_core.py << 'EOF_MODELO'
#!/usr/bin/env python3
# Modelo compuesto ciclo-exacto de adc_core (capa 1c):
# pdmgen + sync 2FF + mux + monitor de actividad + cic.
# Genera el plan de pruebas T1..T5 (nominal, OSR en caliente, ruta externa,
# Phase-0 anti-modo-comun con entrada inerte y ventana en=0, retorno interno).
# Escribe: estimulo_core.txt ("en src osr extbit fbexp toexp"),
#          muestras_core.txt, resumen_core.txt (cuenta + CHK)
LUT = [0, 121, 241, 362, 482, 603, 724, 844, 965, 1085, 1206, 1326, 1446, 1567, 1687, 1807, 1927, 2047, 2167, 2287, 2407, 2526, 2646, 2765, 2885, 3004, 3123, 3242, 3361, 3480, 3599, 3717, 3835, 3954, 4072, 4190, 4308, 4425, 4543, 4660, 4777, 4894, 5011, 5127, 5244, 5360, 5476, 5591, 5707, 5822, 5937, 6052, 6167, 6281, 6396, 6510, 6623, 6737, 6850, 6963, 7076, 7188, 7300, 7412, 7524, 7635, 7746, 7857, 7967, 8077, 8187, 8297, 8406, 8515, 8623, 8731, 8839, 8947, 9054, 9161, 9268, 9374, 9480, 9585, 9690, 9795, 9900, 10004, 10107, 10211, 10313, 10416, 10518, 10620, 10721, 10822, 10923, 11023, 11122, 11222, 11320, 11419, 11517, 11614, 11711, 11808, 11904, 12000, 12095, 12190, 12285, 12379, 12472, 12565, 12658, 12750, 12841, 12932, 13023, 13113, 13203, 13292, 13381, 13469, 13556, 13643, 13730, 13816, 13902, 13987, 14071, 14155, 14239, 14322, 14404, 14486, 14567, 14648, 14728, 14808, 14887, 14965, 15043, 15121, 15197, 15274, 15349, 15424, 15499, 15573, 15646, 15719, 15791, 15863, 15934, 16004, 16074, 16143, 16211, 16279, 16347, 16413, 16479, 16545, 16610, 16674, 16738, 16801, 16863, 16925, 16986, 17046, 17106, 17165, 17224, 17281, 17339, 17395, 17451, 17506, 17561, 17615, 17668, 17721, 17772, 17824, 17874, 17924, 17973, 18022, 18070, 18117, 18163, 18209, 18254, 18299, 18343, 18386, 18428, 18470, 18511, 18551, 18591, 18630, 18668, 18705, 18742, 18778, 18813, 18848, 18882, 18915, 18948, 18980, 19011, 19041, 19071, 19100, 19128, 19156, 19182, 19208, 19234, 19258, 19282, 19305, 19328, 19350, 19371, 19391, 19410, 19429, 19447, 19465, 19481, 19497, 19512, 19527, 19540, 19553, 19565, 19577, 19588, 19597, 19607, 19615, 19623, 19630, 19636, 19642, 19647, 19651, 19654, 19657, 19659, 19660, 19660, 19660, 19659, 19657, 19654, 19651, 19647, 19642, 19636, 19630, 19623, 19615, 19607, 19597, 19588, 19577, 19565, 19553, 19540, 19527, 19512, 19497, 19481, 19465, 19447, 19429, 19410, 19391, 19371, 19350, 19328, 19305, 19282, 19258, 19234, 19208, 19182, 19156, 19128, 19100, 19071, 19041, 19011, 18980, 18948, 18915, 18882, 18848, 18813, 18778, 18742, 18705, 18668, 18630, 18591, 18551, 18511, 18470, 18428, 18386, 18343, 18299, 18254, 18209, 18163, 18117, 18070, 18022, 17973, 17924, 17874, 17824, 17772, 17721, 17668, 17615, 17561, 17506, 17451, 17395, 17339, 17281, 17224, 17165, 17106, 17046, 16986, 16925, 16863, 16801, 16738, 16674, 16610, 16545, 16479, 16413, 16347, 16279, 16211, 16143, 16074, 16004, 15934, 15863, 15791, 15719, 15646, 15573, 15499, 15424, 15349, 15274, 15197, 15121, 15043, 14965, 14887, 14808, 14728, 14648, 14567, 14486, 14404, 14322, 14239, 14155, 14071, 13987, 13902, 13816, 13730, 13643, 13556, 13469, 13381, 13292, 13203, 13113, 13023, 12932, 12841, 12750, 12658, 12565, 12472, 12379, 12285, 12190, 12095, 12000, 11904, 11808, 11711, 11614, 11517, 11419, 11320, 11222, 11122, 11023, 10923, 10822, 10721, 10620, 10518, 10416, 10313, 10211, 10107, 10004, 9900, 9795, 9690, 9585, 9480, 9374, 9268, 9161, 9054, 8947, 8839, 8731, 8623, 8515, 8406, 8297, 8187, 8077, 7967, 7857, 7746, 7635, 7524, 7412, 7300, 7188, 7076, 6963, 6850, 6737, 6623, 6510, 6396, 6281, 6167, 6052, 5937, 5822, 5707, 5591, 5476, 5360, 5244, 5127, 5011, 4894, 4777, 4660, 4543, 4425, 4308, 4190, 4072, 3954, 3835, 3717, 3599, 3480, 3361, 3242, 3123, 3004, 2885, 2765, 2646, 2526, 2407, 2287, 2167, 2047, 1927, 1807, 1687, 1567, 1446, 1326, 1206, 1085, 965, 844, 724, 603, 482, 362, 241, 121, 0, -121, -241, -362, -482, -603, -724, -844, -965, -1085, -1206, -1326, -1446, -1567, -1687, -1807, -1927, -2047, -2167, -2287, -2407, -2526, -2646, -2765, -2885, -3004, -3123, -3242, -3361, -3480, -3599, -3717, -3835, -3954, -4072, -4190, -4308, -4425, -4543, -4660, -4777, -4894, -5011, -5127, -5244, -5360, -5476, -5591, -5707, -5822, -5937, -6052, -6167, -6281, -6396, -6510, -6623, -6737, -6850, -6963, -7076, -7188, -7300, -7412, -7524, -7635, -7746, -7857, -7967, -8077, -8187, -8297, -8406, -8515, -8623, -8731, -8839, -8947, -9054, -9161, -9268, -9374, -9480, -9585, -9690, -9795, -9900, -10004, -10107, -10211, -10313, -10416, -10518, -10620, -10721, -10822, -10923, -11023, -11122, -11222, -11320, -11419, -11517, -11614, -11711, -11808, -11904, -12000, -12095, -12190, -12285, -12379, -12472, -12565, -12658, -12750, -12841, -12932, -13023, -13113, -13203, -13292, -13381, -13469, -13556, -13643, -13730, -13816, -13902, -13987, -14071, -14155, -14239, -14322, -14404, -14486, -14567, -14648, -14728, -14808, -14887, -14965, -15043, -15121, -15197, -15274, -15349, -15424, -15499, -15573, -15646, -15719, -15791, -15863, -15934, -16004, -16074, -16143, -16211, -16279, -16347, -16413, -16479, -16545, -16610, -16674, -16738, -16801, -16863, -16925, -16986, -17046, -17106, -17165, -17224, -17281, -17339, -17395, -17451, -17506, -17561, -17615, -17668, -17721, -17772, -17824, -17874, -17924, -17973, -18022, -18070, -18117, -18163, -18209, -18254, -18299, -18343, -18386, -18428, -18470, -18511, -18551, -18591, -18630, -18668, -18705, -18742, -18778, -18813, -18848, -18882, -18915, -18948, -18980, -19011, -19041, -19071, -19100, -19128, -19156, -19182, -19208, -19234, -19258, -19282, -19305, -19328, -19350, -19371, -19391, -19410, -19429, -19447, -19465, -19481, -19497, -19512, -19527, -19540, -19553, -19565, -19577, -19588, -19597, -19607, -19615, -19623, -19630, -19636, -19642, -19647, -19651, -19654, -19657, -19659, -19660, -19660, -19660, -19659, -19657, -19654, -19651, -19647, -19642, -19636, -19630, -19623, -19615, -19607, -19597, -19588, -19577, -19565, -19553, -19540, -19527, -19512, -19497, -19481, -19465, -19447, -19429, -19410, -19391, -19371, -19350, -19328, -19305, -19282, -19258, -19234, -19208, -19182, -19156, -19128, -19100, -19071, -19041, -19011, -18980, -18948, -18915, -18882, -18848, -18813, -18778, -18742, -18705, -18668, -18630, -18591, -18551, -18511, -18470, -18428, -18386, -18343, -18299, -18254, -18209, -18163, -18117, -18070, -18022, -17973, -17924, -17874, -17824, -17772, -17721, -17668, -17615, -17561, -17506, -17451, -17395, -17339, -17281, -17224, -17165, -17106, -17046, -16986, -16925, -16863, -16801, -16738, -16674, -16610, -16545, -16479, -16413, -16347, -16279, -16211, -16143, -16074, -16004, -15934, -15863, -15791, -15719, -15646, -15573, -15499, -15424, -15349, -15274, -15197, -15121, -15043, -14965, -14887, -14808, -14728, -14648, -14567, -14486, -14404, -14322, -14239, -14155, -14071, -13987, -13902, -13816, -13730, -13643, -13556, -13469, -13381, -13292, -13203, -13113, -13023, -12932, -12841, -12750, -12658, -12565, -12472, -12379, -12285, -12190, -12095, -12000, -11904, -11808, -11711, -11614, -11517, -11419, -11320, -11222, -11122, -11023, -10923, -10822, -10721, -10620, -10518, -10416, -10313, -10211, -10107, -10004, -9900, -9795, -9690, -9585, -9480, -9374, -9268, -9161, -9054, -8947, -8839, -8731, -8623, -8515, -8406, -8297, -8187, -8077, -7967, -7857, -7746, -7635, -7524, -7412, -7300, -7188, -7076, -6963, -6850, -6737, -6623, -6510, -6396, -6281, -6167, -6052, -5937, -5822, -5707, -5591, -5476, -5360, -5244, -5127, -5011, -4894, -4777, -4660, -4543, -4425, -4308, -4190, -4072, -3954, -3835, -3717, -3599, -3480, -3361, -3242, -3123, -3004, -2885, -2765, -2646, -2526, -2407, -2287, -2167, -2047, -1927, -1807, -1687, -1567, -1446, -1326, -1206, -1085, -965, -844, -724, -603, -482, -362, -241, -121]

FINC1 = 0x00193000
FINC2 = 0x00251000
TOMAX = 4095

def wrap24(v):
    return ((v + (1 << 23)) & 0xFFFFFF) - (1 << 23)

def wrapN(v, n):
    m = (1 << n) - 1
    h = 1 << (n - 1)
    return ((v + h) & m) - h

class Mod:
    # espejo exacto de adc_pdmgen (incluye wcnt/valid y compuerta en)
    def __init__(self, finc):
        self.finc = finc
        self.phase = 0; self.x = 0; self.i1 = 0; self.i2 = 0; self.y = 0
        self.wcnt = 0; self.valid = 0
    def step(self, en):
        if en != 1:
            return
        phase_n = (self.phase + self.finc) & 0xFFFFFFFF
        x_n = LUT[(self.phase >> 22) & 0x3FF]
        fb = 32768 if self.y == 1 else -32768
        i1_n = wrap24(self.i1 + self.x - fb)
        i2_n = wrap24(self.i2 + i1_n - fb - fb)
        y_n = 1 if i2_n >= 0 else 0
        v_n = 1 if self.wcnt >= 2 else 0
        w_n = self.wcnt + 1 if self.wcnt != 3 else 3
        self.phase, self.x, self.i1, self.i2, self.y = phase_n, x_n, i1_n, i2_n, y_n
        self.wcnt, self.valid = w_n, v_n

ACCW = 26
QMAX = 8388607
QMIN = -8388608
R_TAB = {0: 32, 1: 64, 2: 128, 3: 256}
SH_TAB = {0: ('L', 8), 1: ('L', 5), 2: ('L', 2), 3: ('R', 1)}

class Cic:
    # espejo exacto de adc_cic (identico al paso 2)
    def __init__(self):
        self.osr_r = 3
        self.clear()
    def clear(self):
        self.i1 = self.i2 = self.i3 = 0
        self.c1 = self.c2 = self.c3 = 0
        self.cnt = 0; self.warm = 0
    def step(self, bit, valid, osr):
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

class Core:
    # espejo exacto de adc_core: lectura de valores viejos y commit atomico
    def __init__(self):
        self.gen = Mod(FINC1)
        self.cic = Cic()
        self.s1 = 0; self.s2 = 0
        self.prev = 0; self.acnt = 0; self.tout = 0
    def step(self, en, src, osr, extbit):
        y_o = self.gen.y
        gv_o = self.gen.valid
        s2_o = self.s2
        bit = y_o if src == 0 else s2_o
        valid = gv_o if src == 0 else en
        s = self.cic.step(bit, valid, osr)
        if src == 0:
            self.acnt = 0
            self.tout = 0
        elif en == 1:
            if s2_o != self.prev:
                self.acnt = 0
            elif self.acnt == TOMAX:
                self.tout = 1
            else:
                self.acnt += 1
            self.prev = s2_o
        s1_o = self.s1
        self.s1 = extbit
        self.s2 = s1_o
        self.gen.step(en)
        return s, self.s2, self.tout

def escribir_pkg():
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

def main():
    escribir_pkg()
    core = Core()
    ext = Mod(FINC2)  # "front-end analogico" externo determinista
    stim = []
    samples = []

    def extsrc(mode):
        if mode == 'mod':
            ext.step(1)
            return ext.y
        return 0  # inerte

    def run_samples(n, en, src, osr, extmode):
        got = 0
        while got < n:
            eb = extsrc(extmode)
            s, fb, to = core.step(en, src, osr, eb)
            stim.append((en, src, osr, eb, fb, to))
            if s is not None:
                samples.append(s)
                got += 1

    def run_cycles(n, en, src, osr, extmode):
        for _ in range(n):
            eb = extsrc(extmode)
            s, fb, to = core.step(en, src, osr, eb)
            stim.append((en, src, osr, eb, fb, to))
            if s is not None:
                samples.append(s)

    # T1: cadena nominal interna, OSR 256
    run_samples(96, 1, 0, 3, 'mod')
    # T2: cambio de OSR en caliente 256 -> 64 a traves de la cadena
    run_samples(32, 1, 0, 1, 'mod')
    # T3: ruta externa (hook B): modulador externo determinista, OSR 64
    run_samples(24, 1, 1, 1, 'mod')
    # T4: Phase-0 anti-modo-comun: entrada externa inerte -> timeout
    run_cycles(4200, 1, 1, 1, 'inerte')
    # T4b: ventana en=0 con src=1 (cic no consume, timeout se sostiene)
    run_cycles(32, 0, 1, 1, 'inerte')
    # T5: retorno a fuente interna: timeout limpia, senoidal reanuda
    run_samples(16, 1, 0, 1, 'mod')

    chk = 0xFFFFFFFF
    for s in samples:
        w = s & 0xFFFFFF
        for k in range(23, -1, -1):
            bit = (w >> k) & 1
            msb = (chk >> 31) & 1
            chk = ((chk << 1) | bit) & 0xFFFFFFFF
            if msb:
                chk ^= 0x04C11DB7

    to_first = next(i for i, t in enumerate(stim) if t[5] == 1)
    with open('estimulo_core.txt', 'w') as f:
        f.write('\n'.join('%d %d %d %d %d %d' % t for t in stim) + '\n')
    with open('muestras_core.txt', 'w') as f:
        f.write('\n'.join(str(s) for s in samples) + '\n')
    with open('resumen_core.txt', 'w') as f:
        f.write('%d\n%08X\n' % (len(samples), chk))
    print('MODELO CORE: %d ciclos, %d muestras, CHK=0x%08X, timeout en ciclo %d'
          % (len(stim), len(samples), chk, to_first))

if __name__ == '__main__':
    main()
EOF_MODELO

# ------------------------------------------------- RTL paso 1 (sin tocar) --
cat > adc_pdmgen.vhd << 'EOF_RTL1'
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
EOF_RTL1

# ------------------------------------------------- RTL paso 2 (sin tocar) --
cat > adc_cic.vhd << 'EOF_RTL2'
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
EOF_RTL2

# ------------------------------------------------------- RTL nuevo paso 3 --
cat > adc_core.vhd << 'EOF_RTL3'
-- ============================================================================
-- adc_core.vhd : Cadena de datos del ADC delta-sigma soft IP v1 (capa 1c)
-- adc_pdmgen (fuente interna de prueba) + sincronizador de 2 FF para la
-- entrada externa (hook B) + mux de fuente + monitor de actividad externa
-- con timeout + adc_cic. pdm_fb_o expone el bit sincronizado como
-- realimentacion del DAC de 1 bit (topologia sigma-delta LVDS de v2).
-- El timeout de actividad es la prueba Phase-0 anti-modo-comun: con
-- src_sel_i='1' y pdm_ext_i inerte, ext_timeout_o debe activarse.
-- VHDL-2008. Reset asincrono activo bajo.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_core is
  port (
    clk            : in  std_logic;
    aresetn        : in  std_logic;
    en_i           : in  std_logic;
    src_sel_i      : in  std_logic;
    finc_i         : in  std_logic_vector(31 downto 0);
    osr_sel_i      : in  std_logic_vector(1 downto 0);
    pdm_ext_i      : in  std_logic;
    pdm_fb_o       : out std_logic;
    ext_timeout_o  : out std_logic;
    sample_o       : out std_logic_vector(23 downto 0);
    sample_valid_o : out std_logic
  );
end entity adc_core;

architecture rtl of adc_core is
  constant C_TO_MAX : unsigned(11 downto 0) := to_unsigned(4095, 12);

  signal gen_y     : std_logic;
  signal gen_valid : std_logic;
  signal s1        : std_logic;
  signal s2        : std_logic;
  signal prev      : std_logic;
  signal acnt      : unsigned(11 downto 0);
  signal tout      : std_logic;
  signal pdm_mux   : std_logic;
  signal valid_mux : std_logic;
begin

  u_gen : entity work.adc_pdmgen
    port map (
      clk         => clk,
      aresetn     => aresetn,
      en_i        => en_i,
      finc_i      => finc_i,
      pdm_o       => gen_y,
      pdm_valid_o => gen_valid
    );

  -- sincronizador de 2 FF para la entrada externa asincrona (hook B)
  proc_sync : process (clk, aresetn)
  begin
    if aresetn = '0' then
      s1 <= '0';
      s2 <= '0';
    elsif rising_edge(clk) then
      s1 <= pdm_ext_i;
      s2 <= s1;
    end if;
  end process proc_sync;

  -- monitor de actividad externa: timeout pegajoso mientras src_sel='1'
  proc_mon : process (clk, aresetn)
  begin
    if aresetn = '0' then
      prev <= '0';
      acnt <= (others => '0');
      tout <= '0';
    elsif rising_edge(clk) then
      if src_sel_i = '0' then
        acnt <= (others => '0');
        tout <= '0';
      elsif en_i = '1' then
        prev <= s2;
        if s2 /= prev then
          acnt <= (others => '0');
        elsif acnt = C_TO_MAX then
          tout <= '1';
        else
          acnt <= acnt + 1;
        end if;
      end if;
    end if;
  end process proc_mon;

  -- mux de fuente
  pdm_mux   <= gen_y     when src_sel_i = '0' else s2;
  valid_mux <= gen_valid when src_sel_i = '0' else en_i;

  u_cic : entity work.adc_cic
    port map (
      clk            => clk,
      aresetn        => aresetn,
      pdm_i          => pdm_mux,
      pdm_valid_i    => valid_mux,
      osr_sel_i      => osr_sel_i,
      sample_o       => sample_o,
      sample_valid_o => sample_valid_o
    );

  pdm_fb_o      <= s2;
  ext_timeout_o <= tout;

end architecture rtl;
EOF_RTL3

# -------------------------------------------------------------------- TB ---
cat > tb_core.vhd << 'EOF_TB'
-- ============================================================================
-- tb_core.vhd : Capa 1c del ADC delta-sigma soft IP v1
-- Reproduce el plan T1..T5 del modelo compuesto (estimulo_core.txt:
-- "en src osr extbit fbexp toexp" por ciclo). Verifica:
--   * cada muestra decimada contra muestras_core.txt (orden estricto)
--   * pdm_fb_o y ext_timeout_o ciclo a ciclo (contrato del hook B y
--     prueba Phase-0 anti-modo-comun)
--   * cuenta total y checksum LFSR-32 (resumen_core.txt)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_core is
end entity tb_core;

architecture sim of tb_core is
  constant C_FINC : std_logic_vector(31 downto 0) := x"00193000";

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal en      : std_logic := '0';
  signal src     : std_logic := '0';
  signal osr     : std_logic_vector(1 downto 0) := "11";
  signal ext     : std_logic := '0';
  signal fb      : std_logic;
  signal tout    : std_logic;
  signal smp     : std_logic_vector(23 downto 0);
  signal smp_v   : std_logic;

  signal n_smp   : integer := 0;
  signal chk     : unsigned(31 downto 0) := (others => '1');
begin

  dut : entity work.adc_core
    port map (
      clk            => clk,
      aresetn        => aresetn,
      en_i           => en,
      src_sel_i      => src,
      finc_i         => C_FINC,
      osr_sel_i      => osr,
      pdm_ext_i      => ext,
      pdm_fb_o       => fb,
      ext_timeout_o  => tout,
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

  proc_mon : process
    file f_smp     : text;
    variable v_l   : line;
    variable v_exp : integer;
    variable v_got : integer;
    variable v_c   : unsigned(31 downto 0) := (others => '1');
    variable v_msb : std_logic;
    variable v_w   : std_logic_vector(23 downto 0);
  begin
    file_open(f_smp, "muestras_core.txt", read_mode);
    loop
      wait until rising_edge(clk);
      if smp_v = '1' then
        readline(f_smp, v_l);
        read(v_l, v_exp);
        v_got := to_integer(signed(smp));
        assert v_got = v_exp
          report "FALLO CORE: muestra " & integer'image(n_smp) &
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
    file f_stim     : text;
    file f_res      : text;
    variable v_l    : line;
    variable v_en   : integer;
    variable v_src  : integer;
    variable v_osr  : integer;
    variable v_eb   : integer;
    variable v_fbe  : integer;
    variable v_toe  : integer;
    variable v_fbp  : integer := 0;
    variable v_top  : integer := 0;
    variable v_i    : integer := 0;
    variable v_fbg  : integer;
    variable v_tog  : integer;
    variable v_cnt  : integer;
    variable v_chk  : std_logic_vector(31 downto 0);
  begin
    file_open(f_stim, "estimulo_core.txt", read_mode);
    file_open(f_res,  "resumen_core.txt",  read_mode);

    aresetn <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);

    while not endfile(f_stim) loop
      readline(f_stim, v_l);
      read(v_l, v_en);
      read(v_l, v_src);
      read(v_l, v_osr);
      read(v_l, v_eb);
      read(v_l, v_fbe);
      read(v_l, v_toe);
      if v_en = 1 then
        en <= '1';
      else
        en <= '0';
      end if;
      if v_src = 1 then
        src <= '1';
      else
        src <= '0';
      end if;
      osr <= std_logic_vector(to_unsigned(v_osr, 2));
      if v_eb = 1 then
        ext <= '1';
      else
        ext <= '0';
      end if;
      wait until rising_edge(clk);
      -- visible en este instante: estado tras el flanco anterior
      if fb = '1' then
        v_fbg := 1;
      else
        v_fbg := 0;
      end if;
      if tout = '1' then
        v_tog := 1;
      else
        v_tog := 0;
      end if;
      if v_i > 0 then
        assert v_fbg = v_fbp
          report "FALLO CORE FB: ciclo " & integer'image(v_i) &
                 " esperado " & integer'image(v_fbp) &
                 " obtenido " & integer'image(v_fbg)
          severity failure;
        assert v_tog = v_top
          report "FALLO CORE TIMEOUT: ciclo " & integer'image(v_i) &
                 " esperado " & integer'image(v_top) &
                 " obtenido " & integer'image(v_tog)
          severity failure;
      end if;
      v_fbp := v_fbe;
      v_top := v_toe;
      v_i   := v_i + 1;
    end loop;

    en <= '0';
    for k in 0 to 7 loop
      wait until rising_edge(clk);
    end loop;

    readline(f_res, v_l);
    read(v_l, v_cnt);
    readline(f_res, v_l);
    hread(v_l, v_chk);

    assert n_smp = v_cnt
      report "FALLO CORE: cuenta de muestras esperada " & integer'image(v_cnt) &
             " obtenida " & integer'image(n_smp)
      severity failure;
    assert std_logic_vector(chk) = v_chk
      report "FALLO CORE CHECKSUM: esperado 0x" & to_hstring(v_chk) &
             " obtenido 0x" & to_hstring(std_logic_vector(chk))
      severity failure;

    report "FIN SIMULACION CORE: PASS N=" & integer'image(n_smp) &
           " CHK=0x" & to_hstring(std_logic_vector(chk)) &
           " @ " & time'image(now);
    finish;
  end process proc_stim;

end architecture sim;
EOF_TB

# ------------------------------------------------- modelo + oro + mutantes -
python3 modelo_core.py

rm -rf build3 && mkdir build3 && cd build3
cp ../estimulo_core.txt ../muestras_core.txt ../resumen_core.txt .
ghdl -a --std=08 --workdir=. ../adc_sin_lut_pkg.vhd ../adc_pdmgen.vhd ../adc_cic.vhd ../adc_core.vhd ../tb_core.vhd
ghdl -e --std=08 --workdir=. tb_core
GOLD=$(ghdl -r --std=08 --workdir=. tb_core 2>&1 | grep -m1 "FIN SIMULACION CORE: PASS" || true)
cd ..
if [ -z "$GOLD" ]; then
  echo "ADC PASO3 CORE: FALLO EN CORRIDA DORADA"
  exit 1
fi
N=$(echo "$GOLD" | sed 's/.*PASS N=\([0-9]*\).*/\1/')
CHK=$(echo "$GOLD" | sed 's/.*CHK=\(0x[0-9A-F]*\).*/\1/')
TS=$(echo "$GOLD" | sed 's/.*@ \(.*\)$/\1/')
GOLDSIG="FIN SIMULACION CORE: PASS N=$N CHK=$CHK @ $TS"

DET=0
for m in 1 2 3 4 5; do
  rm -rf komut$m && mkdir komut$m && cp adc_core.vhd komut$m/
  case $m in
    1) sed -i "s/pdm_mux   <= gen_y     when src_sel_i = '0' else s2;/pdm_mux   <= gen_y;/" komut$m/adc_core.vhd ;;
    2) sed -i "s/pdm_mux   <= gen_y     when src_sel_i = '0' else s2;/pdm_mux   <= gen_y     when src_sel_i = '0' else s1;/" komut$m/adc_core.vhd ;;
    3) sed -i 's/to_unsigned(4095, 12)/to_unsigned(2047, 12)/' komut$m/adc_core.vhd ;;
    4) sed -i "s/if src_sel_i = '0' then/if src_sel_i = '0' and en_i = '0' then/" komut$m/adc_core.vhd ;;
    5) sed -i "s/valid_mux <= gen_valid when src_sel_i = '0' else en_i;/valid_mux <= gen_valid when src_sel_i = '0' else '1';/" komut$m/adc_core.vhd ;;
  esac
  if diff -q adc_core.vhd komut$m/adc_core.vhd > /dev/null; then
    echo "KMUT$m: sed no aplico la mutacion"
    exit 1
  fi
  ( cd komut$m
    cp ../estimulo_core.txt ../muestras_core.txt ../resumen_core.txt .
    ghdl -a --std=08 --workdir=. ../adc_sin_lut_pkg.vhd ../adc_pdmgen.vhd ../adc_cic.vhd adc_core.vhd ../tb_core.vhd > /dev/null 2>&1
    ghdl -e --std=08 --workdir=. tb_core > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 --workdir=. tb_core 2>&1 | grep -m1 "FIN SIMULACION CORE: PASS" || true)
    if echo "$OUT" | grep -q "$GOLDSIG"; then exit 1; else exit 0; fi )
  if [ $? -eq 0 ]; then
    DET=$((DET+1))
    echo "KMUT$m: detectada"
  else
    echo "KMUT$m: NO DETECTADA"
  fi
done

if [ "$DET" -ne 5 ]; then
  echo "ADC PASO3 CORE: FALLO EN MUTACIONES ($DET/5)"
  exit 1
fi

echo "ADC PASO3 CORE: PASS N=$N CHK=$CHK MUT=$DET/5 @ $TS"
)
