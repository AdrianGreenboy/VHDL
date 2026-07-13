#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dsp_oracle.py  --  Oraculo bit-exacto del IP DSP (familia VHDL RV32IM).

Modela en int16/int32 el comportamiento EXACTO que el RTL debe reproducir,
para firma bit-identica en capa 4 (RTL-vs-ISS) y capa 5 (silicio).

Contrato numerico congelado (scope freeze v1.0):
  - Todo Q1.15 (muestras, coeficientes, twiddles).  int16 en el bus.
  - Redondeo: round-half-up (sumar 0x4000 antes de >>15).
  - Saturacion: a [-32768, 32767] en cada salida de producto/suma final.
  - FFT radix-2 DIT in-place, shift fijo de 1 por etapa (escala total 1/N).
    Inversa = mismo shift por etapa (1/N exacto) + conjugacion de twiddles.
  - FIR: simetrico (fase lineal), pre-suma x[n-k]+x[n-(L-1-k)], 32 coefs.
  - CORDIC: 16 iteraciones, ganancia compensada (mult final por 1/K),
    angulo Q2.14 (+-pi -> rango int16 completo).

NO usa numpy.fft ni float en el datapath: solo enteros, para que el RTL
pueda igualar bit a bit.  numpy se usa solo para arrays/IO.
"""

import numpy as np
import sys
import argparse

# ----------------------------------------------------------------------------
# Primitivas de punto fijo Q1.15
# ----------------------------------------------------------------------------

Q15_ONE = 1 << 15          # 1.0 en Q1.15
ROUND   = 1 << 14          # medio LSB para round-half-up tras >>15
INT16_MIN = -32768
INT16_MAX =  32767


def sat16(x):
    """Satura un entero (o array int64) al rango int16."""
    return np.clip(x, INT16_MIN, INT16_MAX).astype(np.int32)


def qmul(a, b):
    """
    Producto Q1.15 * Q1.15 -> Q1.15, round-half-up, sin saturar el intermedio.
    a, b: int (o arrays). Devuelve int32 ya reducido (aun sin saturar salida).
    """
    a = np.asarray(a, dtype=np.int64)
    b = np.asarray(b, dtype=np.int64)
    p = a * b                       # Q2.30 en int64, exacto
    p = (p + ROUND) >> 15           # -> Q1.15 con round-half-up
    return p.astype(np.int64)


def rshift_round(x, s):
    """Right shift aritmetico con round-half-up (para el shift por etapa FFT)."""
    x = np.asarray(x, dtype=np.int64)
    if s == 0:
        return x
    return (x + (1 << (s - 1))) >> s


# ----------------------------------------------------------------------------
# Twiddles Q1.15 (los mismos valores que la ROM del RTL)
# ----------------------------------------------------------------------------

def twiddle_rom(nmax=1024):
    """
    ROM de twiddles W_N^k = exp(-j 2pi k / N) para el N maximo.
    Devuelve (re, im) int16, k = 0..N/2-1.  Q1.15, round-half-up.
    El RTL subindexa con stride para N<Nmax (dir registrada, sumador aparte).
    """
    half = nmax // 2
    k = np.arange(half)
    ang = -2.0 * np.pi * k / nmax
    re = np.rint(np.cos(ang) * Q15_ONE)
    im = np.rint(np.sin(ang) * Q15_ONE)
    # cos(0)=1.0 -> 32768 no cabe en int16; se satura a 32767 (igual que RTL)
    re = sat16(re)
    im = sat16(im)
    return re.astype(np.int64), im.astype(np.int64)


def bit_reverse(a, log2n):
    """Permutacion bit-reverse in-place (para DIT)."""
    n = 1 << log2n
    out = a.copy()
    for i in range(n):
        r = 0
        x = i
        for _ in range(log2n):
            r = (r << 1) | (x & 1)
            x >>= 1
        if r > i:
            out[i], out[r] = out[r].copy(), out[i].copy()
    return out


# ----------------------------------------------------------------------------
# FFT radix-2 DIT in-place, shift fijo por etapa
# ----------------------------------------------------------------------------

def fft_fixed(re_in, im_in, log2n, inverse=False):
    """
    FFT/IFFT radix-2 DIT in-place, int16 Q1.15, shift de 1 por etapa.
    re_in, im_in: arrays int (len N). Devuelve (re, im) int32 saturados.
    """
    n = 1 << log2n
    assert len(re_in) == n and len(im_in) == n

    re = bit_reverse(np.asarray(re_in, dtype=np.int64), log2n)
    im = bit_reverse(np.asarray(im_in, dtype=np.int64), log2n)

    w_re, w_im = twiddle_rom(n if n > 1 else 2)
    # para N<Nmax el stride seria Nmax//n; aqui generamos ROM de tamano N
    # (equivalente exacto a subindexar la ROM grande con stride).

    m = 2
    while m <= n:
        half = m // 2
        stride = n // m
        for j in range(half):
            widx = j * stride
            wr = w_re[widx]
            wi = w_im[widx]
            if inverse:
                wi = -wi                      # conjugado para IFFT
            for k in range(j, n, m):
                l = k + half
                # butterfly: t = W * x[l]
                tr = qmul(re[l], wr) - qmul(im[l], wi)
                ti = qmul(re[l], wi) + qmul(im[l], wr)
                ur = re[k]
                ui = im[k]
                # shift de 1 por etapa con round-half-up (escala 1/N total)
                re[k] = rshift_round(ur + tr, 1)
                im[k] = rshift_round(ui + ti, 1)
                re[l] = rshift_round(ur - tr, 1)
                im[l] = rshift_round(ui - ti, 1)
        m <<= 1

    return sat16(re), sat16(im)


def fft_real_packed(x_real, log2n2, inverse=False):
    """
    FFT de 2N reales via compleja de N + split.
    x_real: 2N muestras reales int16. log2n2 = log2(2N).
    Empaque z[n] = x[2n] + j x[2n+1], FFT compleja de N, luego unsplit.
    Devuelve (re, im) de longitud N+1 (espectro de senal real, 0..N).
    """
    n2 = 1 << log2n2
    n = n2 // 2
    log2n = log2n2 - 1

    x = np.asarray(x_real, dtype=np.int64)
    zr = x[0::2].copy()
    zi = x[1::2].copy()

    Zr, Zi = fft_fixed(zr, zi, log2n, inverse=False)

    # unsplit: X[k] = 0.5(Z[k]+conj(Z[N-k])) - 0.5 j W_2N^k (Z[k]-conj(Z[N-k]))
    w_re, w_im = twiddle_rom(n2)
    Xr = np.zeros(n + 1, dtype=np.int64)
    Xi = np.zeros(n + 1, dtype=np.int64)
    for k in range(n + 1):
        kk = k % n                      # Z es periodica en N: Z[N]=Z[0]
        km = (n - k) % n
        # conj(Z[N-k])
        cr = Zr[km]
        ci = -Zi[km]
        # A = 0.5(Z[k]+conj(Z[N-k]))
        ar = rshift_round(Zr[kk] + cr, 1)
        ai = rshift_round(Zi[kk] + ci, 1)
        # B = 0.5(Z[k]-conj(Z[N-k]))
        br = rshift_round(Zr[kk] - cr, 1)
        bi = rshift_round(Zi[kk] - ci, 1)
        # -j W^k B
        wr = w_re[k] if k < n else Q15_ONE - 1
        wi = w_im[k] if k < n else 0
        # -j * (wr+jwi) * (br+jbi) = ... 
        # W*B:
        wbr = qmul(br, wr) - qmul(bi, wi)
        wbi = qmul(br, wi) + qmul(bi, wr)
        # -j*(wbr+jwbi) = wbi - j wbr
        Xr[k] = sat16(ar + wbi)
        Xi[k] = sat16(ai - wbr)
    return Xr.astype(np.int32), Xi.astype(np.int32)


# ----------------------------------------------------------------------------
# FIR simetrico (fase lineal), split-buffer
# ----------------------------------------------------------------------------

def fir_symmetric(x, coef_half, length):
    """
    FIR simetrico de 'length' taps (length<=64), coef_half = ceil(length/2)
    coeficientes almacenados c[0..], Q1.15. Pre-suma x[n-k]+x[n-(L-1-k)].
    x: entrada int16 (bloque). Devuelve y int16 saturado, mismo largo.
    Estado inicial cero (muestras previas = 0), igual que el RTL en reset.
    """
    L = length
    x = np.asarray(x, dtype=np.int64)
    N = len(x)
    y = np.zeros(N, dtype=np.int64)
    half = (L + 1) // 2
    for n in range(N):
        acc = np.int64(0)
        for k in range(half):
            j = L - 1 - k
            xa = x[n - k] if n - k >= 0 else 0
            xb = x[n - j] if n - j >= 0 else 0
            if k == j:
                s = xa                      # tap central (L impar)
            else:
                s = xa + xb                 # pre-suma simetrica
            acc += coef_half[k] * s          # Q1.15*Q1.15 -> Q2.30
        acc = (acc + ROUND) >> 15            # -> Q1.15 round-half-up
        y[n] = sat16(acc)
    return y.astype(np.int32)


# ----------------------------------------------------------------------------
# CORDIC 16 iteraciones, rotacion y vectoring
# ----------------------------------------------------------------------------

CORDIC_ITERS = 16

def _atan_table():
    """atan(2^-i) en Q2.14 (mismo formato de angulo)."""
    t = []
    for i in range(CORDIC_ITERS):
        a = np.arctan(2.0 ** (-i))
        # Q2.14: +-pi -> rango. Escala: valor = ang/pi * 32768 (aprox).
        # Usamos Q2.14 con pi -> 2^14*... elegimos: 1.0 rad no; mapeo +-pi.
        # angulo_code = round(ang / pi * 2^15) para +-pi -> +-2^15.
        t.append(int(np.rint(a / np.pi * 32768.0)))
    return t

CORDIC_ATAN = _atan_table()

# 1/K para 16 iters, Q1.15
_K = 1.0
for _i in range(CORDIC_ITERS):
    _K *= np.sqrt(1.0 + 2.0 ** (-2 * _i))
CORDIC_INVK = int(np.rint((1.0 / _K) * Q15_ONE))   # ~0.60725 -> Q1.15


HALF_PI_CODE = 16384    # +pi/2 en el mapeo (+-pi -> +-2^15)

def cordic_rot(angle_code):
    """
    Modo rotacion: entra angulo (Q2.14, +-pi -> +-2^15), sale (cos, sin) Q1.15.
    Prescala x por 1/K. Bit-exacto con el RTL (mismos shifts enteros).
    Pre-rotacion de cuadrante: |ang|>pi/2 se refleja al rango convergente
    negando ejes y restando/sumando pi/2 (el RTL hace lo mismo con muxes).
    """
    z0 = np.int64(angle_code)
    # x0 = 1/K (Q1.15), y0 = 0
    x = np.int64(CORDIC_INVK)
    y = np.int64(0)
    neg = False
    # llevar z0 al rango [-pi/2, pi/2] rotando +-pi/2 (intercambio de ejes)
    if z0 > HALF_PI_CODE:
        z0 = z0 - 2 * HALF_PI_CODE      # -pi
        neg = True
    elif z0 < -HALF_PI_CODE:
        z0 = z0 + 2 * HALF_PI_CODE      # +pi
        neg = True
    z = z0
    for i in range(CORDIC_ITERS):
        dx = x >> i
        dy = y >> i
        if z >= 0:
            x, y = x - dy, y + dx
            z = z - CORDIC_ATAN[i]
        else:
            x, y = x + dy, y - dx
            z = z + CORDIC_ATAN[i]
    if neg:                              # deshacer rotacion de pi -> negar ambos
        x, y = -x, -y
    return int(sat16(np.array([x]))[0]), int(sat16(np.array([y]))[0])


def cordic_vec(xin, yin):
    """
    Modo vectoring: entra (x,y) Q1.15, sale (magnitud Q1.15, fase Q2.14).
    Magnitud compensada por 1/K. Bit-exacto.
    """
    x = np.int64(xin)
    y = np.int64(yin)
    z = np.int64(0)
    # pre-rotacion: x<0 (cuadrantes II/III) -> reflejar al semiplano derecho,
    # acumular +-pi en la fase (el RTL usa muxes con el signo de x e y).
    add_pi = np.int64(0)
    if x < 0:
        # reflejar por el origen al semiplano derecho; fase base +-pi
        # segun el signo de y original (para desambiguar +pi de -pi).
        if y >= 0:
            add_pi = np.int64(2 * HALF_PI_CODE)    # +pi  (cuadrante II)
        else:
            add_pi = np.int64(-2 * HALF_PI_CODE)   # -pi  (cuadrante III)
        x, y = -x, -y
    for i in range(CORDIC_ITERS):
        dx = x >> i
        dy = y >> i
        if y < 0:
            x, y = x - dy, y + dx
            z = z - CORDIC_ATAN[i]
        else:
            x, y = x + dy, y - dx
            z = z + CORDIC_ATAN[i]
    z = z + add_pi
    # normalizar fase a [-pi,pi] (rango int16)
    if z > 32767:
        z -= 65536
    elif z < -32768:
        z += 65536
    mag = qmul(x, CORDIC_INVK)
    return int(sat16(np.array([mag]))[0]), int(sat16(np.array([z]))[0])


# ----------------------------------------------------------------------------
# Firma: FNV-1a 32-bit sobre el stream de int16 (little-endian)
# ----------------------------------------------------------------------------

def signature(int16_stream):
    """FNV-1a 32-bit sobre bytes LE de un stream de int16. Devuelve u32."""
    h = 0x811C9DC5
    for v in np.asarray(int16_stream, dtype=np.int64):
        u = int(v) & 0xFFFF
        for byte in (u & 0xFF, (u >> 8) & 0xFF):
            h ^= byte
            h = (h * 0x01000193) & 0xFFFFFFFF
    return h


# ----------------------------------------------------------------------------
# Vectores dorados deterministas
# ----------------------------------------------------------------------------

def golden_vectors():
    rng = np.random.default_rng(0xD59)
    vecs = {}

    # --- FFT compleja N=1024 forward ---
    n = 1024; log2n = 10
    re = rng.integers(-8000, 8000, n, dtype=np.int64)
    im = rng.integers(-8000, 8000, n, dtype=np.int64)
    fr, fi = fft_fixed(re, im, log2n, inverse=False)
    inter = np.empty(2 * n, dtype=np.int64)
    inter[0::2] = fr; inter[1::2] = fi
    vecs['fft1024_fwd'] = inter

    # --- FFT inversa del resultado anterior ---
    ir, ii = fft_fixed(fr, fi, log2n, inverse=True)
    inter2 = np.empty(2 * n, dtype=np.int64)
    inter2[0::2] = ir; inter2[1::2] = ii
    vecs['ifft1024'] = inter2

    # --- FFT N=256 forward (subindexado stride) ---
    n2 = 256; l2 = 8
    re2 = rng.integers(-8000, 8000, n2, dtype=np.int64)
    im2 = rng.integers(-8000, 8000, n2, dtype=np.int64)
    fr2, fi2 = fft_fixed(re2, im2, l2, inverse=False)
    inter3 = np.empty(2 * n2, dtype=np.int64)
    inter3[0::2] = fr2; inter3[1::2] = fi2
    vecs['fft256_fwd'] = inter3

    # --- FFT real-empacada 2N=512 ---
    xr = rng.integers(-8000, 8000, 512, dtype=np.int64)
    Xr, Xi = fft_real_packed(xr, 9, inverse=False)
    interp = np.empty(2 * len(Xr), dtype=np.int64)
    interp[0::2] = Xr; interp[1::2] = Xi
    vecs['fft_real512'] = interp

    # --- FIR simetrico: varios largos (incl. impar para tap central) ---
    fir_cases = []   # (L, coef_half[], xin[], y[])
    for L in (64, 32, 15, 7):
        half = (L + 1) // 2
        cf = np.array([int(round((k + 1) / half * 12000)) for k in range(half)],
                      dtype=np.int64)
        xin = rng.integers(-15000, 15000, 120, dtype=np.int64)
        y = fir_symmetric(xin, cf, L)
        fir_cases.append((L, cf, xin, y))
        vecs[f'fir{L}'] = y
    # guardar para el volcado del TB
    golden_vectors._fir_cases = fir_cases

    # --- CORDIC rotacion: barrido de angulos ---
    rot = []
    for ac in range(-32768, 32768, 337):
        c, s = cordic_rot(ac)
        rot.append(c); rot.append(s)
    vecs['cordic_rot'] = np.array(rot, dtype=np.int64)

    # --- CORDIC vectoring: barrido de vectores ---
    vec = []
    for xx in range(-30000, 30001, 4111):
        for yy in range(-30000, 30001, 4111):
            m, ph = cordic_vec(xx, yy)
            vec.append(m); vec.append(ph)
    vecs['cordic_vec'] = np.array(vec, dtype=np.int64)

    return vecs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dump', action='store_true',
                    help='volcar vectores a .mem para el testbench')
    args = ap.parse_args()

    vecs = golden_vectors()
    print("=== DSP ORACLE  firma bit-exacta (FNV-1a 32b) ===")
    print(f"CORDIC 1/K (Q1.15) = 0x{CORDIC_INVK:04X}  ({CORDIC_INVK})")
    print(f"CORDIC atan[0..3] Q2.14 = {CORDIC_ATAN[:4]}")
    print("-" * 52)
    total = 0x811C9DC5
    for name in sorted(vecs):
        sig = signature(vecs[name])
        # firma acumulada global
        for byte in sig.to_bytes(4, 'little'):
            total ^= byte
            total = (total * 0x01000193) & 0xFFFFFFFF
        print(f"{name:16s} len={len(vecs[name]):5d}  sig=0x{sig:08X}")
    print("-" * 52)
    print(f"{'GLOBAL':16s}            sig=0x{total:08X}")

    if args.dump:
        for name, arr in vecs.items():
            with open(f"golden_{name}.mem", "w") as f:
                for v in arr:
                    f.write(f"{int(v) & 0xFFFF:04X}\n")
        # volcado dedicado para el TB del CORDIC: estimulo + esperado por linea
        # formato: mode x_in y_in z_in  x_exp y_exp z_exp   (7 hex por linea)
        with open("tb_cordic.mem", "w") as f:
            # rotacion: mode=0, barrido de angulos (mismo que golden_cordic_rot)
            for ac in range(-32768, 32768, 337):
                c, s = cordic_rot(ac)
                f.write(f"0 {0:04X} {0:04X} {ac & 0xFFFF:04X} "
                        f"{c & 0xFFFF:04X} {s & 0xFFFF:04X} {0:04X}\n")
            # vectoring: mode=1, barrido de vectores (mismo que golden_cordic_vec)
            for xx in range(-30000, 30001, 4111):
                for yy in range(-30000, 30001, 4111):
                    m, ph = cordic_vec(xx, yy)
                    f.write(f"1 {xx & 0xFFFF:04X} {yy & 0xFFFF:04X} {0:04X} "
                            f"{m & 0xFFFF:04X} {0:04X} {ph & 0xFFFF:04X}\n")
        print("volcados golden_*.mem y tb_cordic.mem")
        # volcado dedicado para el TB del FIR: un fichero por caso de largo.
        # formato de tb_fir.mem:
        #   linea 1:  NCASES
        #   por caso: "CASE L NX" luego L//2+... no: half coefs, luego NX pares x,y
        fc = getattr(golden_vectors, "_fir_cases", [])
        with open("tb_fir.mem", "w") as f:
            f.write(f"{len(fc)}\n")
            for (L, cf, xin, y) in fc:
                half = (L + 1) // 2
                f.write(f"CASE {L} {half} {len(xin)}\n")
                for c in cf:
                    f.write(f"{int(c) & 0xFFFF:04X}\n")
                for xi, yi in zip(xin, y):
                    f.write(f"{int(xi) & 0xFFFF:04X} {int(yi) & 0xFFFF:04X}\n")
        print("volcado tb_fir.mem")
        # volcado dedicado para el TB de la FFT compleja (entrega 1).
        # formato tb_fft.mem:
        #   linea 1: NCASES
        #   por caso: "CASE LOG2N INV N"  luego N lineas "re_in im_in re_exp im_exp"
        rng2 = np.random.default_rng(0xF71)
        fft_cases = []
        # forward N=1024, 256, 64, 8
        for l2 in (10, 8, 6, 3):
            n = 1 << l2
            ri = rng2.integers(-8000, 8000, n, dtype=np.int64)
            ii = rng2.integers(-8000, 8000, n, dtype=np.int64)
            fr, fi = fft_fixed(ri, ii, l2, inverse=False)
            fft_cases.append((l2, 0, ri, ii, fr, fi))
        # inversa N=256 del forward correspondiente
        n = 256
        ri = rng2.integers(-8000, 8000, n, dtype=np.int64)
        ii = rng2.integers(-8000, 8000, n, dtype=np.int64)
        fr, fi = fft_fixed(ri, ii, 8, inverse=False)
        ir, ii2 = fft_fixed(fr, fi, 8, inverse=True)
        fft_cases.append((8, 1, fr, fi, ir, ii2))
        with open("tb_fft.mem", "w") as f:
            f.write(f"{len(fft_cases)}\n")
            for (l2, inv, ar, ai, er, ei) in fft_cases:
                n = 1 << l2
                f.write(f"CASE {l2} {inv} {n}\n")
                for t in range(n):
                    f.write(f"{int(ar[t])&0xFFFF:04X} {int(ai[t])&0xFFFF:04X} "
                            f"{int(er[t])&0xFFFF:04X} {int(ei[t])&0xFFFF:04X}\n")
        print("volcado tb_fft.mem")
        # volcado para el TB del unsplit real (entrega 2).
        # La FFT compleja ya esta validada; aqui probamos SOLO el unsplit.
        # formato tb_unsplit.mem:
        #   linea 1: NCASES
        #   por caso: "CASE LOG2N2 N"  (N = 2N/2, tamano del Z intermedio)
        #     luego N lineas  "Zr Zi"    (entrada: salida de FFT compleja de N)
        #     luego N+1 lineas "Xr Xi"   (esperado: espectro real 0..N)
        rng3 = np.random.default_rng(0xADC)
        unsplit_cases = []
        for l2n2 in (9, 8, 10):        # 2N = 512, 256, 1024
            n2 = 1 << l2n2
            n = n2 // 2
            log2n = l2n2 - 1
            xr = rng3.integers(-8000, 8000, n2, dtype=np.int64)
            zr = xr[0::2].copy()
            zi = xr[1::2].copy()
            Zr, Zi = fft_fixed(zr, zi, log2n, inverse=False)
            Xr, Xi = fft_real_packed(xr, l2n2, inverse=False)
            unsplit_cases.append((l2n2, n, Zr, Zi, Xr, Xi))
        with open("tb_unsplit.mem", "w") as f:
            f.write(f"{len(unsplit_cases)}\n")
            for (l2n2, n, Zr, Zi, Xr, Xi) in unsplit_cases:
                f.write(f"CASE {l2n2} {n}\n")
                for t in range(n):
                    f.write(f"{int(Zr[t])&0xFFFF:04X} {int(Zi[t])&0xFFFF:04X}\n")
                for t in range(n+1):
                    f.write(f"{int(Xr[t])&0xFFFF:04X} {int(Xi[t])&0xFFFF:04X}\n")
        print("volcado tb_unsplit.mem")
        # volcado para Layer 2b: FFT completa via MMIO. Formato tb_fft_mmio.mem:
        #   linea 1: NCASES
        #   por caso: "CASE LOG2N INV N" luego N lineas "in_word out_word" (hex 8)
        #     donde word = im[31:16] & re[15:0]
        rng4 = np.random.default_rng(0x2B)
        mmio_cases = []
        for l2, inv in ((10,0),(8,0),(6,1)):
            n = 1<<l2
            ri = rng4.integers(-8000,8000,n,dtype=np.int64)
            ii = rng4.integers(-8000,8000,n,dtype=np.int64)
            fr, fi = fft_fixed(ri, ii, l2, inverse=bool(inv))
            mmio_cases.append((l2, inv, n, ri, ii, fr, fi))
        with open("tb_fft_mmio.mem","w") as f:
            f.write(f"{len(mmio_cases)}\n")
            for (l2,inv,n,ri,ii,fr,fi) in mmio_cases:
                f.write(f"CASE {l2} {inv} {n}\n")
                for t in range(n):
                    inw  = ((int(ii[t])&0xFFFF)<<16)|(int(ri[t])&0xFFFF)
                    outw = ((int(fi[t])&0xFFFF)<<16)|(int(fr[t])&0xFFFF)
                    f.write(f"{inw:08X} {outw:08X}\n")
        print("volcado tb_fft_mmio.mem")

        # ------- Layer 2c: FIR modo bloque via MMIO -------
        # formato tb_fir_mmio.mem:
        #   linea 1: NCASES
        #   por caso: "CASE L M" luego 32 coefs (hex4, c[0..31]) luego
        #     M lineas "x_word y_word" (word=valor Q1.15 en [15:0], resto 0)
        rng5 = np.random.default_rng(0x1CE)
        fir_mmio = []
        for (L, M) in ((64, 100), (32, 80), (15, 60)):
            half = (L + 1) // 2
            cf = np.array([int(round((k+1)/half*12000)) for k in range(half)],
                          dtype=np.int64)
            # 32 words de coef: los 'half' utiles, resto 0
            coefs32 = [int(cf[k]) if k < half else 0 for k in range(32)]
            xin = rng5.integers(-15000, 15000, M, dtype=np.int64)
            y = fir_symmetric(xin, cf, L)
            fir_mmio.append((L, M, coefs32, xin, y))
        with open("tb_fir_mmio.mem", "w") as f:
            f.write(f"{len(fir_mmio)}\n")
            for (L, M, coefs32, xin, y) in fir_mmio:
                f.write(f"CASE {L} {M}\n")
                for c in coefs32:
                    f.write(f"{int(c)&0xFFFF:04X}\n")
                for t in range(M):
                    f.write(f"{int(xin[t])&0xFFFF:08X} {int(y[t])&0xFFFF:08X}\n")
        print("volcado tb_fir_mmio.mem")

        # ------- Layer 2c: FFT real-empacada via MMIO -------
        # formato tb_rp_mmio.mem:
        #   linea 1: NCASES
        #   por caso: "CASE LOG2N2 N2 N" luego
        #     N2 lineas "x_word" (real Q1.15 en [15:0])   (entrada)
        #     N+1 lineas "X_word" (X = Xi[31:16] & Xr[15:0])  (esperado)
        rng6 = np.random.default_rng(0x4E)
        rp_mmio = []
        for l2n2 in (9, 8, 10):
            n2 = 1 << l2n2
            n = n2 // 2
            xr = rng6.integers(-8000, 8000, n2, dtype=np.int64)
            Xr, Xi = fft_real_packed(xr, l2n2, inverse=False)
            rp_mmio.append((l2n2, n2, n, xr, Xr, Xi))
        with open("tb_rp_mmio.mem", "w") as f:
            f.write(f"{len(rp_mmio)}\n")
            for (l2n2, n2, n, xr, Xr, Xi) in rp_mmio:
                f.write(f"CASE {l2n2} {n2} {n}\n")
                for t in range(n2):
                    f.write(f"{int(xr[t])&0xFFFF:08X}\n")
                for t in range(n+1):
                    w = ((int(Xi[t])&0xFFFF)<<16)|(int(Xr[t])&0xFFFF)
                    f.write(f"{w:08X}\n")
        print("volcado tb_rp_mmio.mem")


if __name__ == "__main__":
    main()
