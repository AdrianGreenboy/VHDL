#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
iss_dsp.py  --  Oraculo ISS de secuencia para la capa 4 del IP DSP.

Emula la MISMA secuencia de accesos MMIO que aplicara tb_dsp_soc.vhd
(y que en silicio hara el firmware RV32IM), y para cada LECTURA emite una
linea "offset_hex valor_hex" en dsp_soc_oracle.txt.

Reutiliza los modelos bit-exactos ya validados de dsp_oracle.py: NO reinventa
la matematica. El TB compara cada rd() contra la siguiente linea del fichero,
bit-identico (estilo tb_ptp_soc.vhd).

Cobertura (N pequenos para TB rapido):
  1. CORDIC rotacion (1 angulo)      -> lee RES_LO/HI
  2. FIR modo bloque (M=16)           -> lee DATA[0..15]
  3. FFT forward N=8                  -> lee DATA[0..7]
  4. FFT real-empacada 2N=8           -> lee DATA[0..4]

Formato del oraculo: cada linea "OOOO VVVVVVVV" (offset byte hex 16b, valor 32b).
Solo se listan las operaciones de LECTURA, en el orden exacto del TB.
"""

import numpy as np
import dsp_oracle as o

# offsets MMIO (byte)
ID     = 0x000
CTRL   = 0x004
STATUS = 0x008
LOG2N  = 0x00C
FIRLEN = 0x010
CORDA  = 0x014
CORDB  = 0x018
RESLO  = 0x01C
RESHI  = 0x020
DATALN = 0x024
COEF0  = 0x080
DATA0  = 0x1000

# FUNC codes (bits[3:1] de CTRL)
F_FFTF = 0b000
F_FFTI = 0b001
F_FIR  = 0b010
F_CROT = 0b011
F_CVEC = 0b100

lines = []   # (offset, value32) de cada lectura esperada
stim  = []   # ("cmd", ...) secuencia de estimulos de entrada para el TB


def emit(off, val):
    lines.append((off & 0xFFFF, val & 0xFFFFFFFF))

def st_wr(off, val):
    stim.append(("WR", off & 0xFFFF, val & 0xFFFFFFFF))

def st_start(func, real_pack=0):
    ctrl = 0x1 | (func << 1) | (real_pack << 4)
    stim.append(("WR", CTRL, ctrl))

def st_poll():
    stim.append(("POLL", 0, 0))

def st_rd(off, tag):
    stim.append(("RD", off & 0xFFFF, 0, tag))

def st_w1c():
    stim.append(("WR", STATUS, 0x2))


def u16(x):
    return int(x) & 0xFFFF

def u32(x):
    return int(x) & 0xFFFFFFFF


# ---------------------------------------------------------------------------
# 1. CORDIC rotacion: angulo -> (cos,sin)
# ---------------------------------------------------------------------------
def seq_cordic_rot(angle_code):
    st_rd(ID, "ID"); emit(ID, 0xD5B10100)
    st_wr(CORDA, u16(angle_code))
    st_start(F_CROT)
    st_poll()
    c, s = o.cordic_rot(angle_code)
    st_rd(STATUS, "CORDIC_STATUS"); emit(STATUS, 0x2)
    st_rd(RESLO, "CORDIC_COS");     emit(RESLO, u32(u16(c)))
    st_rd(RESHI, "CORDIC_SIN");     emit(RESHI, u32(u16(s)))
    st_w1c()


# ---------------------------------------------------------------------------
# 2. FIR modo bloque
# ---------------------------------------------------------------------------
def seq_fir_block(L, M, seed=0x1CE):
    half = (L + 1) // 2
    cf = np.array([int(round((k+1)/half*12000)) for k in range(half)], dtype=np.int64)
    rng = np.random.default_rng(seed)
    xin = rng.integers(-15000, 15000, M, dtype=np.int64)
    y = o.fir_symmetric(xin, cf, L)
    # cargar 32 coeficientes
    for k in range(32):
        cval = int(cf[k]) if k < half else 0
        st_wr(COEF0 + k*4, u16(cval))
    # cargar M muestras
    for t in range(M):
        st_wr(DATA0 + t*4, u16(xin[t]))
    st_wr(FIRLEN, L)
    st_wr(DATALN, M)
    st_start(F_FIR)
    st_poll()
    st_rd(STATUS, "FIR_STATUS"); emit(STATUS, 0x2)
    for t in range(M):
        st_rd(DATA0 + t*4, f"FIR_y{t}"); emit(DATA0 + t*4, u32(u16(y[t])))
    st_w1c()


# ---------------------------------------------------------------------------
# 3. FFT forward N
# ---------------------------------------------------------------------------
def seq_fft_fwd(log2n, seed=0x2B):
    n = 1 << log2n
    rng = np.random.default_rng(seed)
    ri = rng.integers(-8000, 8000, n, dtype=np.int64)
    ii = rng.integers(-8000, 8000, n, dtype=np.int64)
    fr, fi = o.fft_fixed(ri, ii, log2n, inverse=False)
    for t in range(n):
        w = (u16(ii[t]) << 16) | u16(ri[t])
        st_wr(DATA0 + t*4, w)
    st_wr(LOG2N, log2n)
    st_start(F_FFTF)
    st_poll()
    st_rd(STATUS, "FFT_STATUS"); emit(STATUS, 0x2)
    for t in range(n):
        w = (u16(fi[t]) << 16) | u16(fr[t])
        st_rd(DATA0 + t*4, f"FFT_X{t}"); emit(DATA0 + t*4, u32(w))
    st_w1c()


# ---------------------------------------------------------------------------
# 4. FFT real-empacada 2N
# ---------------------------------------------------------------------------
def seq_fft_realpack(log2n2, seed=0x4E):
    n2 = 1 << log2n2
    n = n2 // 2
    rng = np.random.default_rng(seed)
    xr = rng.integers(-8000, 8000, n2, dtype=np.int64)
    Xr, Xi = o.fft_real_packed(xr, log2n2, inverse=False)
    for t in range(n2):
        st_wr(DATA0 + t*4, u16(xr[t]))
    st_wr(LOG2N, log2n2)
    st_wr(DATALN, n2)
    st_start(F_FFTF, real_pack=1)
    st_poll()
    st_rd(STATUS, "RP_STATUS"); emit(STATUS, 0x2)
    for t in range(n+1):
        w = (u16(Xi[t]) << 16) | u16(Xr[t])
        st_rd(DATA0 + t*4, f"RP_X{t}"); emit(DATA0 + t*4, u32(w))
    st_w1c()


# ---------------------------------------------------------------------------
# 1b. CORDIC vectoring: (x,y) -> (magnitud, fase)
# ---------------------------------------------------------------------------
def seq_cordic_vec(xin, yin):
    st_wr(CORDA, u16(xin))
    st_wr(CORDB, u16(yin))
    st_start(F_CVEC)
    st_poll()
    mag, ph = o.cordic_vec(xin, yin)
    st_rd(STATUS, "CVEC_STATUS"); emit(STATUS, 0x2)
    st_rd(RESLO, "CVEC_MAG");     emit(RESLO, u32(u16(mag)))
    st_rd(RESHI, "CVEC_PHASE");   emit(RESHI, u32(u16(ph)))
    st_w1c()


# ---------------------------------------------------------------------------
# 3b. FFT inversa N
# ---------------------------------------------------------------------------
def seq_fft_inv(log2n, seed=0x9C):
    n = 1 << log2n
    rng = np.random.default_rng(seed)
    ri = rng.integers(-8000, 8000, n, dtype=np.int64)
    ii = rng.integers(-8000, 8000, n, dtype=np.int64)
    fr, fi = o.fft_fixed(ri, ii, log2n, inverse=True)
    for t in range(n):
        w = (u16(ii[t]) << 16) | u16(ri[t])
        st_wr(DATA0 + t*4, w)
    st_wr(LOG2N, log2n)
    st_start(F_FFTI)
    st_poll()
    st_rd(STATUS, "IFFT_STATUS"); emit(STATUS, 0x2)
    for t in range(n):
        w = (u16(fi[t]) << 16) | u16(fr[t])
        st_rd(DATA0 + t*4, f"IFFT_X{t}"); emit(DATA0 + t*4, u32(w))
    st_w1c()


def main():
    seq_cordic_rot(0x2000)
    seq_cordic_vec(15000, 15000)      # ~45 grados, magnitud conocida
    seq_fir_block(64, 16, seed=0x1CE)
    seq_fft_fwd(3, seed=0x2B)
    seq_fft_inv(3, seed=0x9C)          # FFT inversa N=8
    seq_fft_realpack(3, seed=0x4E)

    # volcar la secuencia completa como "programa" que el TB ejecuta.
    # formato por linea:
    #   WR   offset_hex  value_hex
    #   POLL
    #   RD   offset_hex  expected_hex  tag
    with open("dsp_soc_prog.txt", "w") as f:
        for s in stim:
            if s[0] == "WR":
                f.write(f"WR {s[1]:04X} {s[2]:08X}\n")
            elif s[0] == "POLL":
                f.write("POLL\n")
            elif s[0] == "RD":
                # buscar el valor esperado emparejado (por orden)
                pass
        # segundo pase: reconstruir con lecturas emparejadas a 'lines'
    # Reescritura limpia: recorrer stim y emparejar RD con lines en orden.
    li = 0
    with open("dsp_soc_prog.txt", "w") as f:
        for s in stim:
            if s[0] == "WR":
                f.write(f"WR {s[1]:04X} {s[2]:08X}\n")
            elif s[0] == "POLL":
                f.write("POLL\n")
            elif s[0] == "RD":
                off, val = lines[li]; li += 1
                f.write(f"RD {off:04X} {val:08X} {s[3]}\n")
    print(f"dsp_soc_prog.txt: {len(stim)} pasos, {len(lines)} lecturas")


if __name__ == "__main__":
    main()
