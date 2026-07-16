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
