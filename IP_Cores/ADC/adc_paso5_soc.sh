#!/bin/bash
# ============================================================================
# adc_paso5_soc.sh : ADC delta-sigma soft IP v1 - Paso 5 (capa 4)
# SoC completo en simulacion: cpu_pipeline RV32IM ejecutando el firmware
# real adc_bringup.s (ensamblado con asm.py del repo) + mem_subsys_adc
# (RAM local + dma_burst con split 4KB + IP ADC en 0x6000_0000) +
# axi_ddr_sim. Firmware: FINC + CTRL(OSR 256) -> espera nivel>=64 ->
# drena 64 muestras -> sentinela 0xADC0FEED -> DMA 65 palabras a DDR[0]
# -> doorbell. Oraculo ISS escrito antes de integrar (iss_adc.py).
# Requiere el repo canonico en ~/vhdl_repo (fuentes RV32i + asm.py).
# 5 mutaciones de integracion.
# Uso: bash adc_paso5_soc.sh
# Linea final esperada:
# ADC PASO5 SOC: PASS N=65 CHK=0x1B8D3FF9 MUT=5/5 @ 178716000000 fs
# ============================================================================
(
set -e
DIR="$HOME/adc_ip"
RV="$HOME/vhdl_repo/IP_Cores/RV32i"
mkdir -p "$DIR"
cd "$DIR"

if [ ! -f "$RV/asm.py" ]; then
  echo "ADC PASO5 SOC: FALTA EL REPO CANONICO EN $RV"
  exit 1
fi
for f in riscv_pkg alu control csr immgen muldiv regfile cpu_pipeline dp_ram dma_burst axi_ddr_sim; do
  cp "$RV/$f.vhd" .
done
cp "$RV/asm.py" .

cat > modelo_core.py << 'EOF_MC'
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
EOF_MC

cat > iss_adc.py << 'EOF_ISS'
#!/usr/bin/env python3
# Oraculo ISS de capa 4 del ADC delta-sigma soft IP v1.
# Modela lo que el firmware adc_bringup.s deja en la DDR:
#   words 0..63 = primeras 64 muestras decimadas (OSR 256, FINC 0x00193000,
#                 fuente interna), etiquetadas [31:24]=0x00, [23:0]=Q1.23
#   word  64    = sentinela 0xADC0FEED
# El orden/valor de las muestras es independiente del timing del firmware
# mientras la FIFO no desborde (capacidad 514 >> ritmo de drenado).
# Escribe iss_adc_oracle.txt (65 lineas hex de 8 digitos).
import modelo_core as mc

def main():
    core = mc.Core()
    palabras = []
    while len(palabras) < 64:
        s, fb, to = core.step(1, 0, 3, 0)
        if s is not None:
            palabras.append(s & 0xFFFFFF)  # tag 0x00 en [31:24]
    palabras.append(0xADC0FEED)
    with open('iss_adc_oracle.txt', 'w') as f:
        f.write('\n'.join('%08X' % w for w in palabras) + '\n')
    chk = 0xFFFFFFFF
    for w in palabras:
        for k in range(31, -1, -1):
            bit = (w >> k) & 1
            msb = (chk >> 31) & 1
            chk = ((chk << 1) | bit) & 0xFFFFFFFF
            if msb:
                chk ^= 0x04C11DB7
    print('ORACULO ISS ADC: 65 palabras, CHK=0x%08X' % chk)

if __name__ == '__main__':
    main()
EOF_ISS

cat > adc_bringup.s << 'EOF_FW'
# adc_bringup.s - bring-up del ADC delta-sigma soft IP v1: el core RV32IM
# configura el IP en 0x6000_0000 (FINC + CTRL en=1/src=0/OSR=256), espera
# nivel >= 64 en la FIFO, drena 64 muestras a RAM local (words 0..63),
# escribe la sentinela 0xADC0FEED en word 64, copia 65 palabras a DDR[0]
# por el DMA del SoC (0x4000_0000) y hace doorbell (word 127).
# Programa IDENTICO en efecto a iss_adc.py (oraculo de capa 4).
#
# Mapa del IP (offset de byte): 0x00 CTRL  0x08 TEST_FINC  0x0C FIFO_LEVEL
#                               0x10 FIFO_DATA (pop en lectura)
# Regs DMA SoC: 0x00 SRC  0x04 DST  0x08 LEN  0x0C CTRL  0x10 STATUS
#
# asm.py: li = 2 palabras; sin la/lbu/.byte; offsets decimales o hex.

    li   x5, 0x60000000        # base IP ADC
    li   x31, 0x40000000       # base regs DMA del SoC

    # ---- configurar generador: FINC explicito ----
    li   x7, 0x00193000
    sw   x7, 8(x5)             # TEST_FINC

    # ---- CTRL: enable=1, src_sel=0, osr_sel=11 (OSR 256) -> 0xD ----
    li   x7, 0xD
    sw   x7, 0(x5)

    # ---- esperar FIFO_LEVEL >= 64 ----
    li   x8, 64
espera:
    lw   x9, 12(x5)            # FIFO_LEVEL
    blt  x9, x8, espera

    # ---- drenar 64 muestras a RAM local words 0..63 ----
    li   x10, 0                # puntero local (bytes)
    li   x11, 64               # contador
drena:
    lw   x9, 16(x5)            # FIFO_DATA (pop)
    sw   x9, 0(x10)
    addi x10, x10, 4
    addi x11, x11, -1
    bne  x11, x0, drena

    # ---- sentinela en word 64 (x10 = 256) ----
    li   x7, 0xADC0FEED
    sw   x7, 0(x10)

    # ---- DMA: 65 palabras local[0] -> DDR[0] (dir=1) ----
    sw   x0, 0(x31)            # SRC = 0 (byte local)
    sw   x0, 4(x31)            # DST = 0 (offset DDR)
    li   x7, 65
    sw   x7, 8(x31)            # LEN
    li   x7, 3                 # start | dir(local->DDR)
    sw   x7, 12(x31)

    # ---- esperar fin del DMA (busy pegajoso) ----
dpoll:
    lw   x9, 16(x31)           # STATUS
    andi x9, x9, 1
    bne  x9, x0, dpoll

    # ---- doorbell: word 127 de la RAM local (byte 508) ----
    li   x7, 0x0000D0ED
    li   x10, 508
    sw   x7, 0(x10)

fin:
    jal  x0, fin
EOF_FW

cat > adc_pdmgen.vhd << 'EOF_adc_pdmgen'
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
EOF_adc_pdmgen

cat > adc_cic.vhd << 'EOF_adc_cic'
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
EOF_adc_cic

cat > adc_core.vhd << 'EOF_adc_core'
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
EOF_adc_core

cat > adc_fifo.vhd << 'EOF_adc_fifo'
-- ============================================================================
-- adc_fifo.vhd : FIFO de muestras del ADC delta-sigma soft IP v1
-- Almacenamiento en BRAM 512x32 con molde SDP canonico (un puerto de
-- escritura sincrona, un puerto de lectura sincrona con enable) + etapa de
-- salida FWFT de 2 registros (rd_word, head). El head esta siempre
-- disponible en rd_data cuando empty='0', lo que permite que el banco MMIO
-- presente FIFO_DATA con rdata COMBINACIONAL (contrato dmem de la familia).
-- Capacidad total: 512 (BRAM) + 2 (etapas) = 514 palabras.
-- rst sincrono activo alto (convencion del banco de registros).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_fifo is
  generic (
    LOG2_DEPTH : natural := 9  -- 512 palabras de BRAM
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    wr_en   : in  std_logic;
    wr_data : in  std_logic_vector(31 downto 0);
    rd_en   : in  std_logic;   -- pop del head (ignorado si empty)
    rd_data : out std_logic_vector(31 downto 0);
    empty   : out std_logic;
    full    : out std_logic;
    level   : out unsigned(LOG2_DEPTH + 1 downto 0)
  );
end entity adc_fifo;

architecture rtl of adc_fifo is
  constant C_DEPTH : natural := 2**LOG2_DEPTH;

  type ram_t is array (0 to C_DEPTH - 1) of std_logic_vector(31 downto 0);
  signal buf : ram_t;
  attribute ram_style : string;
  attribute ram_style of buf : signal is "block";

  signal wr_ptr  : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal rd_ptr  : unsigned(LOG2_DEPTH - 1 downto 0) := (others => '0');
  signal cnt_ram : unsigned(LOG2_DEPTH downto 0) := (others => '0');  -- 0..512

  signal rd_word : std_logic_vector(31 downto 0) := (others => '0');
  signal head    : std_logic_vector(31 downto 0) := (others => '0');
  signal rv      : std_logic := '0';  -- rd_word valido
  signal hv      : std_logic := '0';  -- head valido

  signal full_i  : std_logic;
  signal pop     : std_logic;
  signal adv_h   : std_logic;
  signal adv_r   : std_logic;
  signal wr_ok   : std_logic;
begin

  full_i <= '1' when cnt_ram = to_unsigned(C_DEPTH, cnt_ram'length) else '0';
  pop    <= rd_en and hv;
  adv_h  <= rv and ((not hv) or pop);
  adv_r  <= '1' when (cnt_ram /= 0) and ((rv = '0') or (adv_h = '1')) else '0';
  wr_ok  <= wr_en and (not full_i);

  proc_fifo : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wr_ptr  <= (others => '0');
        rd_ptr  <= (others => '0');
        cnt_ram <= (others => '0');
        rv      <= '0';
        hv      <= '0';
      else
        -- puerto de escritura sincrona (molde SDP)
        if wr_ok = '1' then
          buf(to_integer(wr_ptr)) <= wr_data;
          wr_ptr <= wr_ptr + 1;
        end if;
        -- puerto de lectura sincrona con enable (molde SDP)
        if adv_r = '1' then
          rd_word <= buf(to_integer(rd_ptr));
          rd_ptr  <= rd_ptr + 1;
        end if;
        if (wr_ok = '1') and (adv_r = '0') then
          cnt_ram <= cnt_ram + 1;
        elsif (wr_ok = '0') and (adv_r = '1') then
          cnt_ram <= cnt_ram - 1;
        end if;
        rv <= adv_r or (rv and (not adv_h));
        if adv_h = '1' then
          head <= rd_word;
        end if;
        hv <= adv_h or (hv and (not pop));
      end if;
    end if;
  end process proc_fifo;

  rd_data <= head;
  empty   <= not hv;
  full    <= full_i;

  proc_level : process (all)
    variable v : unsigned(level'length - 1 downto 0);
  begin
    v := resize(cnt_ram, level'length);
    if rv = '1' then
      v := v + 1;
    end if;
    if hv = '1' then
      v := v + 1;
    end if;
    level <= v;
  end process proc_level;

end architecture rtl;
EOF_adc_fifo

cat > adc_regs.vhd << 'EOF_adc_regs'
-- ============================================================================
-- adc_regs.vhd : Banco de registros MMIO del ADC delta-sigma soft IP v1
-- Contrato dmem de la familia: sel/we/addr/wdata sincronos, rdata
-- COMBINACIONAL (un rdata registrado pasa una capa 2 ingenua pero rompe
-- capa 4: cada lw devuelve el dato de la lectura anterior).
--
-- Mapa (congelado en scope freeze, addr de 8 bits, byte-address):
--   0x00 CTRL       rw : b0 enable, b1 src_sel, [3:2] osr_sel
--   0x04 STATUS     ro : b0 ext_timeout, b1 fifo_empty, b2 fifo_full,
--                        b3 dma_busy
--   0x08 TEST_FINC  rw : incremento de fase del generador (reset 0x00193000)
--   0x0C FIFO_LEVEL ro : [9:0] nivel (0..514)
--   0x10 FIFO_DATA  ro : pop en lectura; [31:24] tag/canal, [23:0] muestra;
--                        lectura con FIFO vacia devuelve 0 y no hace pop
--   0x14 IRQ_EN     rw : b0 umbral FIFO, b1 dma_done
--   0x18 IRQ_STAT   w1c: b0 umbral FIFO (flanco de nivel>=umbral), b1 dma_done
--   0x1C IRQ_THRESH rw : [9:0] umbral (0 = deshabilitado)
--   0x20 DMA_ADDR   rw
--   0x24 DMA_LEN    rw
--   0x28 DMA_CTRL   w  : b0=1 dispara dma_go (pulso); lectura: b0 dma_busy
--   0x44 DBG_STATE  ro : dbg_i
--   resto: lee 0, escritura ignorada
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_regs is
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;  -- sincrono, activo alto
    -- bus dmem
    sel           : in  std_logic;
    we            : in  std_logic;
    addr          : in  std_logic_vector(7 downto 0);
    wdata         : in  std_logic_vector(31 downto 0);
    rdata         : out std_logic_vector(31 downto 0);  -- COMBINACIONAL
    irq           : out std_logic;
    -- control hacia adc_core
    enable        : out std_logic;
    src_sel       : out std_logic;
    osr_sel       : out std_logic_vector(1 downto 0);
    finc          : out std_logic_vector(31 downto 0);
    -- interfaz FIFO
    fifo_rd       : out std_logic;
    fifo_rdata    : in  std_logic_vector(31 downto 0);
    fifo_level    : in  unsigned(9 downto 0);
    fifo_empty    : in  std_logic;
    fifo_full     : in  std_logic;
    -- estado del datapath
    ext_timeout_i : in  std_logic;
    -- DMA (motor en paso 5)
    dma_addr      : out std_logic_vector(31 downto 0);
    dma_len       : out std_logic_vector(31 downto 0);
    dma_go        : out std_logic;  -- pulso
    dma_busy_i    : in  std_logic;
    dma_done_p_i  : in  std_logic;  -- pulso
    -- debug
    dbg_i         : in  std_logic_vector(31 downto 0)
  );
end entity adc_regs;

architecture rtl of adc_regs is
  signal ctrl_r   : std_logic_vector(3 downto 0)  := (others => '0');
  signal finc_r   : std_logic_vector(31 downto 0) := x"00193000";
  signal irqen_r  : std_logic_vector(1 downto 0)  := (others => '0');
  signal irqst_r  : std_logic_vector(1 downto 0)  := (others => '0');
  signal thr_r    : unsigned(9 downto 0)          := (others => '0');
  signal daddr_r  : std_logic_vector(31 downto 0) := (others => '0');
  signal dlen_r   : std_logic_vector(31 downto 0) := (others => '0');
  signal dgo_r    : std_logic := '0';

  signal thr_c    : std_logic;  -- condicion nivel >= umbral
  signal thr_cr   : std_logic;  -- registrada (deteccion de flanco)
  signal thr_ev   : std_logic;

  signal rdata_mux : std_logic_vector(31 downto 0);
begin

  thr_c  <= '1' when (thr_r /= 0) and (fifo_level >= thr_r) else '0';
  thr_ev <= thr_c and (not thr_cr);

  proc_regs : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ctrl_r  <= (others => '0');
        finc_r  <= x"00193000";
        irqen_r <= (others => '0');
        irqst_r <= (others => '0');
        thr_r   <= (others => '0');
        daddr_r <= (others => '0');
        dlen_r  <= (others => '0');
        dgo_r   <= '0';
        thr_cr  <= '0';
      else
        dgo_r  <= '0';
        thr_cr <= thr_c;

        -- escrituras
        if (sel = '1') and (we = '1') then
          case addr(7 downto 2) is
            when "000000" => ctrl_r  <= wdata(3 downto 0);            -- 0x00
            when "000010" => finc_r  <= wdata;                        -- 0x08
            when "000101" => irqen_r <= wdata(1 downto 0);            -- 0x14
            when "000111" => thr_r   <= unsigned(wdata(9 downto 0));  -- 0x1C
            when "001000" => daddr_r <= wdata;                        -- 0x20
            when "001001" => dlen_r  <= wdata;                        -- 0x24
            when "001010" => dgo_r   <= wdata(0);                     -- 0x28
            when others   => null;
          end case;
        end if;

        -- IRQ_STAT: eventos ponen, W1C limpia; el evento gana al clear
        if (sel = '1') and (we = '1') and (addr(7 downto 2) = "000110") then
          irqst_r <= irqst_r and (not wdata(1 downto 0));             -- 0x18
        end if;
        if thr_ev = '1' then
          irqst_r(0) <= '1';
        end if;
        if dma_done_p_i = '1' then
          irqst_r(1) <= '1';
        end if;
      end if;
    end if;
  end process proc_regs;

  -- pop de FIFO: lectura de FIFO_DATA (0x10) con FIFO no vacia
  fifo_rd <= sel and (not we) and (not fifo_empty)
             when addr(7 downto 2) = "000100" else '0';

  -- mux de lectura COMBINACIONAL (contrato dmem de la familia)
  proc_rmux : process (all)
  begin
    rdata_mux <= (others => '0');
    case addr(7 downto 2) is
      when "000000" =>                                              -- 0x00
        rdata_mux(3 downto 0) <= ctrl_r;
      when "000001" =>                                              -- 0x04
        rdata_mux(0) <= ext_timeout_i;
        rdata_mux(1) <= fifo_empty;
        rdata_mux(2) <= fifo_full;
        rdata_mux(3) <= dma_busy_i;
      when "000010" =>                                              -- 0x08
        rdata_mux <= finc_r;
      when "000011" =>                                              -- 0x0C
        rdata_mux(9 downto 0) <= std_logic_vector(fifo_level);
      when "000100" =>                                              -- 0x10
        if fifo_empty = '0' then
          rdata_mux <= fifo_rdata;
        end if;
      when "000101" =>                                              -- 0x14
        rdata_mux(1 downto 0) <= irqen_r;
      when "000110" =>                                              -- 0x18
        rdata_mux(1 downto 0) <= irqst_r;
      when "000111" =>                                              -- 0x1C
        rdata_mux(9 downto 0) <= std_logic_vector(thr_r);
      when "001000" =>                                              -- 0x20
        rdata_mux <= daddr_r;
      when "001001" =>                                              -- 0x24
        rdata_mux <= dlen_r;
      when "001010" =>                                              -- 0x28
        rdata_mux(0) <= dma_busy_i;
      when "010001" =>                                              -- 0x44
        rdata_mux <= dbg_i;
      when others =>
        null;
    end case;
  end process proc_rmux;

  rdata <= rdata_mux;

  enable   <= ctrl_r(0);
  src_sel  <= ctrl_r(1);
  osr_sel  <= ctrl_r(3 downto 2);
  finc     <= finc_r;
  dma_addr <= daddr_r;
  dma_len  <= dlen_r;
  dma_go   <= dgo_r;
  irq      <= (irqst_r(0) and irqen_r(0)) or (irqst_r(1) and irqen_r(1));

end architecture rtl;
EOF_adc_regs

cat > adc_mmio.vhd << 'EOF_adc_mmio'
-- ============================================================================
-- adc_mmio.vhd : Subsistema MMIO del ADC delta-sigma soft IP v1
-- adc_regs + adc_fifo cableados. El lado de empuje de la FIFO recibe la
-- muestra etiquetada ([31:24] tag/canal = 0x00 en v1, [23:0] muestra Q1.23);
-- en el top del paso 6 lo alimenta sample_valid de adc_core, en la capa 2
-- lo alimenta el testbench directamente.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_mmio is
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;  -- sincrono, activo alto
    -- bus dmem
    sel           : in  std_logic;
    we            : in  std_logic;
    addr          : in  std_logic_vector(7 downto 0);
    wdata         : in  std_logic_vector(31 downto 0);
    rdata         : out std_logic_vector(31 downto 0);
    irq           : out std_logic;
    -- empuje de muestras (del datapath / TB)
    smp_push_i    : in  std_logic;
    smp_word_i    : in  std_logic_vector(31 downto 0);
    -- control hacia adc_core
    enable        : out std_logic;
    src_sel       : out std_logic;
    osr_sel       : out std_logic_vector(1 downto 0);
    finc          : out std_logic_vector(31 downto 0);
    -- estado del datapath
    ext_timeout_i : in  std_logic;
    -- DMA (motor en paso 5)
    dma_addr      : out std_logic_vector(31 downto 0);
    dma_len       : out std_logic_vector(31 downto 0);
    dma_go        : out std_logic;
    dma_busy_i    : in  std_logic;
    dma_done_p_i  : in  std_logic;
    -- acceso del DMA a la FIFO (paso 5; abierto en capa 2)
    dma_fifo_rd_i : in  std_logic;
    fifo_rdata_o  : out std_logic_vector(31 downto 0);
    fifo_empty_o  : out std_logic;
    -- debug
    dbg_i         : in  std_logic_vector(31 downto 0)
  );
end entity adc_mmio;

architecture rtl of adc_mmio is
  signal f_rd    : std_logic;
  signal f_rdata : std_logic_vector(31 downto 0);
  signal f_level : unsigned(10 downto 0);
  signal f_empty : std_logic;
  signal f_full  : std_logic;
  signal mmio_rd : std_logic;
begin

  u_fifo : entity work.adc_fifo
    generic map (
      LOG2_DEPTH => 9
    )
    port map (
      clk     => clk,
      rst     => rst,
      wr_en   => smp_push_i,
      wr_data => smp_word_i,
      rd_en   => f_rd,
      rd_data => f_rdata,
      empty   => f_empty,
      full    => f_full,
      level   => f_level
    );

  -- pop por MMIO o por el motor DMA (paso 5)
  f_rd <= mmio_rd or dma_fifo_rd_i;

  u_regs : entity work.adc_regs
    port map (
      clk           => clk,
      rst           => rst,
      sel           => sel,
      we            => we,
      addr          => addr,
      wdata         => wdata,
      rdata         => rdata,
      irq           => irq,
      enable        => enable,
      src_sel       => src_sel,
      osr_sel       => osr_sel,
      finc          => finc,
      fifo_rd       => mmio_rd,
      fifo_rdata    => f_rdata,
      fifo_level    => f_level(9 downto 0),
      fifo_empty    => f_empty,
      fifo_full     => f_full,
      ext_timeout_i => ext_timeout_i,
      dma_addr      => dma_addr,
      dma_len       => dma_len,
      dma_go        => dma_go,
      dma_busy_i    => dma_busy_i,
      dma_done_p_i  => dma_done_p_i,
      dbg_i         => dbg_i
    );

  fifo_rdata_o <= f_rdata;
  fifo_empty_o <= f_empty;

end architecture rtl;
EOF_adc_mmio

cat > adc_soc.vhd << 'EOF_adc_soc'
-- ============================================================================
-- adc_soc.vhd : Cara dmem del ADC delta-sigma soft IP v1 (patron tsn_soc)
-- Esclavo dmem de 1 ciclo (rdata combinacional) para colgar del mem_subsys
-- en 0x6000_0000. Une adc_core (datapath, reset asincrono activo bajo) con
-- adc_mmio (banco + FIFO, reset sincrono activo alto): cada sample_valid
-- empuja {0x00, muestra Q1.23} a la FIFO.
-- Los registros DMA del IP (0x20/0x24/0x28) quedan como hooks para
-- integracion standalone; en el SoC v3 el movimiento a DDR usa el
-- dma_burst del mem_subsys (patron de la familia): dma_busy_i='0'.
-- DBG_STATE (0x44): [31:24]=0xAD, [16]=ext_timeout, [10:0]=nivel FIFO.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_soc is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;  -- sincrono, activo alto
    sel     : in  std_logic;
    we      : in  std_logic;
    addr    : in  std_logic_vector(7 downto 0);
    wdata   : in  std_logic_vector(31 downto 0);
    rdata   : out std_logic_vector(31 downto 0);
    ready   : out std_logic;
    irq     : out std_logic;
    -- hook B hacia pines (v2): comparador LVDS + realimentacion RC
    pdm_ext_i : in  std_logic;
    pdm_fb_o  : out std_logic
  );
end entity adc_soc;

architecture rtl of adc_soc is
  signal aresetn   : std_logic;
  signal enable_w  : std_logic;
  signal src_w     : std_logic;
  signal osr_w     : std_logic_vector(1 downto 0);
  signal finc_w    : std_logic_vector(31 downto 0);
  signal tout_w    : std_logic;
  signal smp_w     : std_logic_vector(23 downto 0);
  signal smp_v     : std_logic;
  signal push_word : std_logic_vector(31 downto 0);
  signal dbg_w     : std_logic_vector(31 downto 0);
begin

  aresetn <= not rst;

  u_core : entity work.adc_core
    port map (
      clk            => clk,
      aresetn        => aresetn,
      en_i           => enable_w,
      src_sel_i      => src_w,
      finc_i         => finc_w,
      osr_sel_i      => osr_w,
      pdm_ext_i      => pdm_ext_i,
      pdm_fb_o       => pdm_fb_o,
      ext_timeout_o  => tout_w,
      sample_o       => smp_w,
      sample_valid_o => smp_v
    );

  -- etiqueta de canal (v1: canal unico 0x00) + muestra Q1.23
  push_word <= x"00" & smp_w;

  u_mmio : entity work.adc_mmio
    port map (
      clk           => clk,
      rst           => rst,
      sel           => sel,
      we            => we,
      addr          => addr,
      wdata         => wdata,
      rdata         => rdata,
      irq           => irq,
      smp_push_i    => smp_v,
      smp_word_i    => push_word,
      enable        => enable_w,
      src_sel       => src_w,
      osr_sel       => osr_w,
      finc          => finc_w,
      ext_timeout_i => tout_w,
      dma_addr      => open,
      dma_len       => open,
      dma_go        => open,
      dma_busy_i    => '0',
      dma_done_p_i  => '0',
      dma_fifo_rd_i => '0',
      fifo_rdata_o  => open,
      fifo_empty_o  => open,
      dbg_i         => dbg_w
    );

  -- DBG_STATE: firma 0xAD + timeout en bit 16; [15:0] reservado 0 en v1
  -- (solo diagnostico en silicio; no forma parte del vector del oraculo)
  dbg_w <= x"AD" & "0000000" & tout_w & x"0000";

  ready <= '1';

end architecture rtl;
EOF_adc_soc

cat > mem_subsys_adc.vhd << 'EOF_mem_subsys_adc'
-- =============================================================================
--  mem_subsys_adc.vhd  -  Subsistema de memoria con motor DMA (bursts) + IP ADC
--  Licencia: MIT
--
--  Le da al core:
--    region 0x0000_0000 (bits 31:30 = "00")  -> RAM local, 1 ciclo
--    region 0x4000_0000 (bits 31:28 = "0100")-> registros del DMA, 1 ciclo
--  El DMA es el maestro AXI (owns m_axi) y mueve bloques DDR<->local con bursts.
--
--  Registros DMA (offset desde 0x4000_0000):
--    0x00 SRC   (w)   0x04 DST   (w)   0x08 LEN (w, 1..256)
--    0x0C CTRL  (w)   bit0=start, bit1=dir (0=DDR->local, 1=local->DDR)
--    0x10 STATUS(r)   bit0=busy   (busy PEGAJOSO: alto desde el start hasta que
--                                  el DMA de verdad termina, sin ventana falsa)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_pkg.all;

entity mem_subsys_adc is
  generic (
    DEPTH    : natural := 256;
    INIT_FILE: string  := "";
    ADDR_W   : natural := 40
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;
    ddr_base : in std_logic_vector(ADDR_W-1 downto 0);  -- base DDR (runtime)

    dmem_addr  : in  word_t;
    dmem_wdata : in  word_t;
    dmem_wstrb : in  std_logic_vector(3 downto 0);
    dmem_req   : in  std_logic;
    dmem_rdata : out word_t;
    dmem_ready : out std_logic;

    -- maestro AXI4 hacia la DDR (lo maneja el DMA)
    m_axi_awaddr  : out std_logic_vector(ADDR_W-1 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    m_axi_wdata   : out std_logic_vector(31 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic;
    m_axi_araddr  : out std_logic_vector(ADDR_W-1 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    m_axi_rdata   : in  std_logic_vector(31 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic

  );
end entity mem_subsys_adc;

architecture rtl of mem_subsys_adc is
  signal is_local, is_dmareg, is_adc : std_logic;
  signal adc_rdata : word_t;
  signal loc_rdata  : word_t;
  signal cpu_wstrb  : std_logic_vector(3 downto 0);
  signal dmareg_rdata : word_t;

  -- registros DMA
  signal dma_src, dma_dst : std_logic_vector(31 downto 0) := (others => '0');
  signal dma_len : std_logic_vector(8 downto 0) := (others => '0');
  signal dma_dir : std_logic := '0';
  signal dma_start, dma_busy : std_logic;
  signal dma_go, busy_sticky, dma_started : std_logic := '0';

  -- puerto DMA <-> RAM local
  signal dloc_addr  : std_logic_vector(31 downto 0);
  signal dloc_wdata : word_t;
  signal dloc_we    : std_logic;
  signal dloc_rdata : word_t;
  signal dloc_wstrb : std_logic_vector(3 downto 0);
begin

  is_local  <= '1' when dmem_addr(31 downto 30) = "00"   else '0';
  is_dmareg <= '1' when dmem_addr(31 downto 28) = "0100" else '0';
  is_adc    <= '1' when dmem_addr(31 downto 28) = "0110" else '0';   -- 0x6000_0000

  -- deteccion combinacional del "start" (sw a CTRL con bit0=1)
  dma_go <= '1' when (is_dmareg = '1' and dmem_wstrb /= "0000"
                      and dmem_addr(7 downto 0) = x"0C" and dmem_wdata(0) = '1')
            else '0';

  -- RAM local de doble puerto: cpu=core, axi=DMA
  cpu_wstrb <= dmem_wstrb when is_local = '1' else "0000";
  dloc_wstrb <= "1111" when dloc_we = '1' else "0000";

  u_local : entity work.dp_ram
    generic map (DEPTH => DEPTH, INIT_FILE => INIT_FILE)
    port map (
      clk => clk,
      cpu_addr => dmem_addr, cpu_wdata => dmem_wdata, cpu_wstrb => cpu_wstrb,
      cpu_rdata => loc_rdata,
      axi_addr => dloc_addr, axi_wdata => dloc_wdata, axi_wstrb => dloc_wstrb,
      axi_rdata => dloc_rdata, axi_owns => dma_busy
    );

  u_dma : entity work.dma_burst
    generic map (ADDR_W => ADDR_W)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => ddr_base,
      src => dma_src, dst => dma_dst, len => dma_len, dir => dma_dir,
      start => dma_start, busy => dma_busy,
      loc_addr => dloc_addr, loc_wdata => dloc_wdata, loc_we => dloc_we, loc_rdata => dloc_rdata,
      m_axi_awaddr => m_axi_awaddr, m_axi_awlen => m_axi_awlen, m_axi_awsize => m_axi_awsize,
      m_axi_awburst => m_axi_awburst, m_axi_awvalid => m_axi_awvalid, m_axi_awready => m_axi_awready,
      m_axi_wdata => m_axi_wdata, m_axi_wstrb => m_axi_wstrb, m_axi_wlast => m_axi_wlast,
      m_axi_wvalid => m_axi_wvalid, m_axi_wready => m_axi_wready,
      m_axi_bresp => m_axi_bresp, m_axi_bvalid => m_axi_bvalid, m_axi_bready => m_axi_bready,
      m_axi_araddr => m_axi_araddr, m_axi_arlen => m_axi_arlen, m_axi_arsize => m_axi_arsize,
      m_axi_arburst => m_axi_arburst, m_axi_arvalid => m_axi_arvalid, m_axi_arready => m_axi_arready,
      m_axi_rdata => m_axi_rdata, m_axi_rresp => m_axi_rresp, m_axi_rlast => m_axi_rlast,
      m_axi_rvalid => m_axi_rvalid, m_axi_rready => m_axi_rready
    );



  -- ADC delta-sigma (esclavo dmem directo de 1 ciclo, patron tipo TSN/DSP):
  -- region 0x6000_0000; rst activo alto sincrono <- not aresetn.
  -- rdata combinacional; hook B aterrizado en v1 (pdm_ext_i='0').
  u_adc : entity work.adc_soc
    port map (
      clk   => clk,
      rst   => not aresetn,
      sel   => (dmem_req and is_adc),
      we    => (is_adc and (dmem_wstrb(0) or dmem_wstrb(1) or
                            dmem_wstrb(2) or dmem_wstrb(3))),
      addr  => dmem_addr(7 downto 0),
      wdata => dmem_wdata,
      rdata => adc_rdata,
      ready => open,
      irq   => open,
      pdm_ext_i => '0',
      pdm_fb_o  => open);

  -- escritura de registros DMA + pulso de start + busy pegajoso
  process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        dma_src <= (others => '0'); dma_dst <= (others => '0');
        dma_len <= (others => '0'); dma_dir <= '0'; dma_start <= '0';
        busy_sticky <= '0'; dma_started <= '0';
      else
        dma_start <= '0';
        if is_dmareg = '1' and dmem_wstrb /= "0000" then
          case dmem_addr(7 downto 0) is
            when x"00" => dma_src <= dmem_wdata;
            when x"04" => dma_dst <= dmem_wdata;
            when x"08" => dma_len <= dmem_wdata(8 downto 0);
            when x"0C" => dma_dir <= dmem_wdata(1);
                          if dmem_wdata(0) = '1' then dma_start <= '1'; end if;
            when others => null;
          end case;
        end if;

        -- busy pegajoso: se pone alto al detectar el start (combinacional, mismo
        -- ciclo que el sw CTRL) y se baja solo cuando el DMA de verdad terminó.
        if dma_go = '1' then
          busy_sticky <= '1';
        end if;
        if dma_busy = '1' then
          dma_started <= '1';
        elsif dma_started = '1' then      -- el DMA estuvo activo y ya volvió a idle
          busy_sticky <= '0';
          dma_started <= '0';
        end if;
      end if;
    end if;
  end process;

  -- lectura de STATUS (reporta el busy pegajoso)
  dmareg_rdata <= (0 => busy_sticky, others => '0')
                  when dmem_addr(7 downto 0) = x"10" else (others => '0');

  -- rdata y ready hacia el core (local y registros DMA son de 1 ciclo)
  dmem_rdata <= loc_rdata    when is_local  = '1' else
                dmareg_rdata when is_dmareg = '1' else
                adc_rdata    when is_adc    = '1' else
                (others => '0');
  -- el ADC es esclavo de 1 ciclo (rdata combinacional): sin wait-states.
  dmem_ready <= '1';

end architecture rtl;
EOF_mem_subsys_adc

cat > tb_adc_soc.vhd << 'EOF_tb_adc_soc'
-- ============================================================================
-- tb_adc_soc.vhd : Capa 4 del ADC delta-sigma soft IP v1
-- SoC completo en simulacion: cpu_pipeline RV32IM ejecutando el firmware
-- real adc_bringup.mem (ensamblado con asm.py) + mem_subsys_adc (RAM local
-- + dma_burst + IP ADC en 0x6000_0000) + axi_ddr_sim como LPDDR4.
-- El firmware drena 64 muestras, escribe la sentinela 0xADC0FEED y copia
-- 65 palabras a DDR[0] por DMA. El TB espera la sentinela en DDR word 64
-- (con watchdog) y compara las 65 palabras bit-identicas contra el oraculo
-- ISS (iss_adc_oracle.txt) mas checksum LFSR-32.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

use work.riscv_pkg.all;

entity tb_adc_soc is
end entity tb_adc_soc;

architecture sim of tb_adc_soc is
  constant TCK    : time := 10 ns;
  constant AXI_AW : natural := 40;
  constant C_WDOG : integer := 400000;  -- ciclos de watchdog

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal aresetn : std_logic;

  signal imem_addr, imem_instr : word_t;
  signal dmem_addr, dmem_wdata, dmem_rdata : word_t;
  signal dmem_wstrb : std_logic_vector(3 downto 0);
  signal dmem_req, dmem_ready : std_logic;

  signal aw_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal aw_len  : std_logic_vector(7 downto 0);
  signal aw_size : std_logic_vector(2 downto 0);
  signal aw_burst: std_logic_vector(1 downto 0);
  signal aw_valid, aw_ready : std_logic;
  signal w_data  : std_logic_vector(31 downto 0);
  signal w_strb  : std_logic_vector(3 downto 0);
  signal w_last, w_valid, w_ready : std_logic;
  signal b_resp  : std_logic_vector(1 downto 0);
  signal b_valid, b_ready : std_logic;
  signal ar_addr : std_logic_vector(AXI_AW-1 downto 0);
  signal ar_len  : std_logic_vector(7 downto 0);
  signal ar_size : std_logic_vector(2 downto 0);
  signal ar_burst: std_logic_vector(1 downto 0);
  signal ar_valid, ar_ready : std_logic;
  signal r_data  : std_logic_vector(31 downto 0);
  signal r_resp  : std_logic_vector(1 downto 0);
  signal r_last, r_valid, r_ready : std_logic;

  signal ddr_dbg_addr : natural := 0;
  signal ddr_dbg_data : word_t;
begin

  clk <= not clk after TCK/2;
  aresetn <= not rst;

  u_imem : entity work.dp_ram
    generic map (DEPTH => 256, INIT_FILE => "adc_bringup.mem")
    port map (
      clk => clk,
      cpu_addr => imem_addr, cpu_wdata => ZERO_WORD, cpu_wstrb => "0000",
      cpu_rdata => imem_instr,
      axi_addr => ZERO_WORD, axi_wdata => ZERO_WORD, axi_wstrb => "0000",
      axi_rdata => open, axi_owns => '0'
    );

  u_cpu : entity work.cpu_pipeline
    port map (
      clk => clk, rst => rst,
      imem_addr => imem_addr, imem_instr => imem_instr,
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata,
      dmem_wstrb => dmem_wstrb, dmem_rdata => dmem_rdata,
      dmem_req => dmem_req, dmem_ready => dmem_ready,
      irq_timer => '0', irq_soft => '0', irq_ext => '0',
      dbg_reg_addr => "00000", dbg_reg_data => open, dbg_pc => open
    );

  u_mem : entity work.mem_subsys_adc
    generic map (DEPTH => 256, INIT_FILE => "", ADDR_W => AXI_AW)
    port map (
      clk => clk, aresetn => aresetn, ddr_base => (others => '0'),
      dmem_addr => dmem_addr, dmem_wdata => dmem_wdata, dmem_wstrb => dmem_wstrb,
      dmem_req => dmem_req, dmem_rdata => dmem_rdata, dmem_ready => dmem_ready,
      m_axi_awaddr => aw_addr, m_axi_awlen => aw_len, m_axi_awsize => aw_size,
      m_axi_awburst => aw_burst, m_axi_awvalid => aw_valid, m_axi_awready => aw_ready,
      m_axi_wdata => w_data, m_axi_wstrb => w_strb, m_axi_wlast => w_last,
      m_axi_wvalid => w_valid, m_axi_wready => w_ready,
      m_axi_bresp => b_resp, m_axi_bvalid => b_valid, m_axi_bready => b_ready,
      m_axi_araddr => ar_addr, m_axi_arlen => ar_len, m_axi_arsize => ar_size,
      m_axi_arburst => ar_burst, m_axi_arvalid => ar_valid, m_axi_arready => ar_ready,
      m_axi_rdata => r_data, m_axi_rresp => r_resp, m_axi_rlast => r_last,
      m_axi_rvalid => r_valid, m_axi_rready => r_ready
    );

  u_ddr : entity work.axi_ddr_sim
    generic map (ADDR_W => AXI_AW, DEPTH => 1024, RD_LAT => 4, INIT_FILE => "")
    port map (
      clk => clk, aresetn => aresetn,
      s_axi_awaddr => aw_addr, s_axi_awlen => aw_len,
      s_axi_awvalid => aw_valid, s_axi_awready => aw_ready,
      s_axi_wdata => w_data, s_axi_wstrb => w_strb, s_axi_wlast => w_last,
      s_axi_wvalid => w_valid, s_axi_wready => w_ready,
      s_axi_bresp => b_resp, s_axi_bvalid => b_valid, s_axi_bready => b_ready,
      s_axi_araddr => ar_addr, s_axi_arlen => ar_len,
      s_axi_arvalid => ar_valid, s_axi_arready => ar_ready,
      s_axi_rdata => r_data, s_axi_rresp => r_resp, s_axi_rlast => r_last,
      s_axi_rvalid => r_valid, s_axi_rready => r_ready,
      dbg_addr => ddr_dbg_addr, dbg_data => ddr_dbg_data
    );

  p_main : process
    file f_or       : text;
    variable v_l    : line;
    variable v_exp  : std_logic_vector(31 downto 0);
    variable v_chk  : unsigned(31 downto 0) := (others => '1');
    variable v_msb  : std_logic;
    variable v_ciclo: integer := 0;
    variable v_ok   : boolean := false;
  begin
    rst <= '1';
    for k in 1 to 8 loop
      wait until rising_edge(clk);
    end loop;
    rst <= '0';

    -- watchdog: esperar la sentinela 0xADC0FEED en DDR word 64
    ddr_dbg_addr <= 64;
    while v_ciclo < C_WDOG loop
      wait until rising_edge(clk);
      v_ciclo := v_ciclo + 1;
      if ddr_dbg_data = x"ADC0FEED" then
        v_ok := true;
        exit;
      end if;
    end loop;
    assert v_ok
      report "FALLO SOC: watchdog, sentinela ausente tras " &
             integer'image(C_WDOG) & " ciclos"
      severity failure;

    -- margen para que asiente el B-channel del ultimo burst
    for k in 1 to 32 loop
      wait until rising_edge(clk);
    end loop;

    -- comparar 65 palabras contra el oraculo ISS
    file_open(f_or, "iss_adc_oracle.txt", read_mode);
    for k in 0 to 64 loop
      ddr_dbg_addr <= k;
      wait until rising_edge(clk);
      wait for 1 ns;
      readline(f_or, v_l);
      hread(v_l, v_exp);
      assert ddr_dbg_data = v_exp
        report "FALLO SOC: DDR word " & integer'image(k) &
               " esperada 0x" & to_hstring(v_exp) &
               " obtenida 0x" & to_hstring(ddr_dbg_data)
        severity failure;
      for b in 31 downto 0 loop
        v_msb := v_chk(31);
        v_chk := v_chk(30 downto 0) & ddr_dbg_data(b);
        if v_msb = '1' then
          v_chk := v_chk xor x"04C11DB7";
        end if;
      end loop;
    end loop;

    report "FIN SIMULACION SOC: PASS N=65 CHK=0x" &
           to_hstring(std_logic_vector(v_chk)) & " @ " & time'image(now);
    finish;
  end process p_main;

end architecture sim;
EOF_tb_adc_soc

# --------------------------------------- oraculo + firmware + oro + mutantes -
python3 modelo_core.py > /dev/null
python3 iss_adc.py
python3 asm.py adc_bringup.s adc_bringup.mem > /dev/null

SRCS_RV="riscv_pkg.vhd alu.vhd control.vhd csr.vhd immgen.vhd muldiv.vhd regfile.vhd cpu_pipeline.vhd dp_ram.vhd dma_burst.vhd axi_ddr_sim.vhd"
SRCS_ADC="adc_sin_lut_pkg.vhd adc_pdmgen.vhd adc_cic.vhd adc_core.vhd adc_fifo.vhd adc_regs.vhd adc_mmio.vhd"

rm -rf build5 && mkdir build5 && cd build5
cp ../adc_bringup.mem ../iss_adc_oracle.txt .
for s in $SRCS_RV $SRCS_ADC adc_soc.vhd mem_subsys_adc.vhd tb_adc_soc.vhd; do SL="$SL ../$s"; done
ghdl -a --std=08 --workdir=. $SL
ghdl -e --std=08 --workdir=. tb_adc_soc
GOLD=$(ghdl -r --std=08 --workdir=. tb_adc_soc 2>&1 | grep -m1 "FIN SIMULACION SOC: PASS" || true)
cd ..
if [ -z "$GOLD" ]; then
  echo "ADC PASO5 SOC: FALLO EN CORRIDA DORADA"
  exit 1
fi
N=$(echo "$GOLD" | sed 's/.*PASS N=\([0-9]*\).*/\1/')
CHK=$(echo "$GOLD" | sed 's/.*CHK=\(0x[0-9A-F]*\).*/\1/')
TS=$(echo "$GOLD" | sed 's/.*@ \(.*\)$/\1/')
GOLDSIG="FIN SIMULACION SOC: PASS N=$N CHK=$CHK @ $TS"

DET=0
for m in 1 2 3 4 5; do
  rm -rf smut$m && mkdir smut$m && cp adc_soc.vhd mem_subsys_adc.vhd smut$m/
  case $m in
    1) sed -i 's/push_word <= x"00" \& smp_w;/push_word <= x"01" \& smp_w;/' smut$m/adc_soc.vhd ;;
    2) sed -i 's/osr_sel_i      => osr_w,/osr_sel_i      => "01",/' smut$m/adc_soc.vhd ;;
    3) sed -i 's/dmem_addr(31 downto 28) = "0110"/dmem_addr(31 downto 28) = "0101"/' smut$m/mem_subsys_adc.vhd ;;
    4) sed -i 's/when x"0C" => dma_dir <= dmem_wdata(1);/when x"0C" => dma_dir <= not dmem_wdata(1);/' smut$m/mem_subsys_adc.vhd ;;
    5) sed -i 's/push_word <= x"00" \& smp_w;/push_word <= x"00" \& smp_w(23 downto 1) \& '"'"'0'"'"';/' smut$m/adc_soc.vhd ;;
  esac
  if diff -q adc_soc.vhd smut$m/adc_soc.vhd > /dev/null && diff -q mem_subsys_adc.vhd smut$m/mem_subsys_adc.vhd > /dev/null; then
    echo "SMUT$m: sed no aplico la mutacion"
    exit 1
  fi
  ( cd smut$m
    cp ../adc_bringup.mem ../iss_adc_oracle.txt .
    SM=""
    for s in $SRCS_RV $SRCS_ADC; do SM="$SM ../$s"; done
    ghdl -a --std=08 --workdir=. $SM adc_soc.vhd mem_subsys_adc.vhd ../tb_adc_soc.vhd > /dev/null 2>&1
    ghdl -e --std=08 --workdir=. tb_adc_soc > /dev/null 2>&1
    OUT=$(ghdl -r --std=08 --workdir=. tb_adc_soc 2>&1 | grep -m1 "FIN SIMULACION SOC: PASS" || true)
    if echo "$OUT" | grep -q "$GOLDSIG"; then exit 1; else exit 0; fi )
  if [ $? -eq 0 ]; then
    DET=$((DET+1))
    echo "SMUT$m: detectada"
  else
    echo "SMUT$m: NO DETECTADA"
  fi
done

if [ "$DET" -ne 5 ]; then
  echo "ADC PASO5 SOC: FALLO EN MUTACIONES ($DET/5)"
  exit 1
fi

echo "ADC PASO5 SOC: PASS N=$N CHK=$CHK MUT=$DET/5 @ $TS"
)
