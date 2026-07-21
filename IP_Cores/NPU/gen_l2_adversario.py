#!/usr/bin/env python3
# HERCOSSNUX NPU - estimulo adversario para Layer 2 (array sistolico 8x8).
# Objetivo: ejercitar los caminos que los datos reales de la red NO tocan:
#   - saturacion a +127 y a -128
#   - acumuladores negativos grandes (ReLU desactivada)
#   - los umbrales exactos de requantize
#   - cada uno de los 64 PEs con una contribucion distinguible
# Determinista: semilla fija. No corresponde a ninguna red entrenada;
# es aritmetica pura para verificar el datapath.
import sys, random

SHIFT = 31

def requant(acc, m, shift, relu):
    if relu and acc < 0: acc = 0
    v = (acc * m + (1 << (shift - 1))) >> shift
    if v > 127: v = 127
    if v < -128: v = -128
    return v

def conv3x3_ref(x, C, H, W, O, wts, bias, m, shift, relu):
    """Referencia independiente: loops explicitos, enteros nativos."""
    out = [[[0]*W for _ in range(H)] for _ in range(O)]
    for o in range(O):
        for y in range(H):
            for xx in range(W):
                acc = bias[o]
                for c in range(C):
                    for ky in range(3):
                        for kx in range(3):
                            iy = y + ky - 1; ix = xx + kx - 1
                            if 0 <= iy < H and 0 <= ix < W:
                                acc += x[c][iy][ix] * wts[((o*C + c)*3 + ky)*3 + kx]
                assert -(1 << 31) <= acc < (1 << 31), "adversario: acc fuera de int32"
                out[o][y][xx] = requant(acc, m, shift, relu)
    return out

def main():
    outdir = sys.argv[1]
    rnd = random.Random(0xADDE45A)

    H = W = 8
    C = 8          # canales de entrada = PE_DIM
    O = 8          # canales de salida  = PE_DIM
    M = 1 << 24    # multiplicador grande: empuja a saturacion con facilidad

    cases = []

    # --- Caso 1: saturacion positiva masiva ---
    # activaciones y pesos al maximo del mismo signo -> acc muy positivo
    x1 = [[[127]*W for _ in range(H)] for _ in range(C)]
    w1 = [127]*(O*C*3*3)
    b1 = [0]*O
    cases.append(("sat_pos", x1, w1, b1, M, 0))

    # --- Caso 2: saturacion negativa masiva (sin ReLU) ---
    x2 = [[[127]*W for _ in range(H)] for _ in range(C)]
    w2 = [-128]*(O*C*3*3)
    b2 = [0]*O
    cases.append(("sat_neg", x2, w2, b2, M, 0))

    # --- Caso 3: signo mixto, ReLU activa (recorta negativos) ---
    x3 = [[[(-128 if (y+xx) % 2 else 127) for xx in range(W)] for y in range(H)] for _ in range(C)]
    w3 = [(-128 if i % 3 else 127) for i in range(O*C*3*3)]
    b3 = [0]*O
    cases.append(("mixto_relu", x3, w3, b3, M, 1))

    # --- Caso 4: signo mixto SIN ReLU (deja pasar negativos) ---
    cases.append(("mixto_sin_relu", x3, w3, b3, M, 0))

    # --- Caso 5: unicidad de PE ---
    # Peso distinto por (canal_out, canal_in): si el array cruza dos PEs o
    # deja uno muerto, la firma cambia. Activacion 1 solo en el centro.
    x5 = [[[0]*W for _ in range(H)] for _ in range(C)]
    for c in range(C):
        x5[c][4][4] = c + 1          # valor distinto por canal de entrada
    w5 = [0]*(O*C*3*3)
    for o in range(O):
        for c in range(C):
            # kernel centro (ky=1,kx=1) con peso unico por par (o,c)
            w5[((o*C + c)*3 + 1)*3 + 1] = (o*C + c) % 127 + 1
    b5 = [0]*O
    cases.append(("unicidad_pe", x5, w5, b5, 1 << 20, 0))

    # --- Caso 6: bias en los extremos ---
    x6 = [[[0]*W for _ in range(H)] for _ in range(C)]
    w6 = [0]*(O*C*3*3)
    b6 = [(1 << 30) if o % 2 == 0 else -(1 << 30) for o in range(O)]
    cases.append(("bias_extremo", x6, w6, b6, 4, 0))

    # --- Caso 7: umbrales exactos de requantize ---
    # bias calibrado para caer justo en +127/-128 y sus vecinos
    thr_hi = ((127 * (1 << SHIFT)) + (1 << (SHIFT-1))) // M
    thr_lo = ((-128 * (1 << SHIFT)) - (1 << (SHIFT-1))) // M
    x7 = [[[0]*W for _ in range(H)] for _ in range(C)]
    w7 = [0]*(O*C*3*3)
    b7 = [thr_hi-1, thr_hi, thr_hi+1, thr_lo-1, thr_lo, thr_lo+1, 0, 1]
    cases.append(("umbral_requant", x7, w7, b7, M, 0))

    # --- Casos 8..12: aleatorios de rango completo ---
    for n in range(5):
        xr = [[[rnd.randint(-128,127) for _ in range(W)] for _ in range(H)] for _ in range(C)]
        wr = [rnd.randint(-128,127) for _ in range(O*C*3*3)]
        br = [rnd.randint(-(1<<20), 1<<20) for _ in range(O)]
        mr = rnd.choice([1<<20, 1<<24, 5064654, 1<<28])
        cases.append((f"aleatorio_{n}", xr, wr, br, mr, n % 2))

    # ---------------- Emision y medicion de cobertura ----------------
    SIGP = 0x01000193
    sig = 0x811C9DC5
    sig_tb = 0x811C9DC5
    def upd(s, v): return (s * SIGP + (v & 0xFF)) & 0xFFFFFFFF

    n_sat_pos = n_sat_neg = n_neg = n_tot = 0
    pe_seen = set()

    fh = open(f"{outdir}/vec_adversario.txt", "w")
    fh.write(f"# HERCOSSNUX NPU estimulo adversario L2 N={len(cases)}\n")
    fh.write(f"# formato por caso: NOMBRE / MULT / RELU / bias[8] / x[8][8][8] / w[8*8*3*3] / y[8][8][8]\n")

    for name, x, w, b, m, relu in cases:
        y = conv3x3_ref(x, C, H, W, O, w, b, m, SHIFT, relu == 1)

        fh.write(f"CASO {name}\n")
        fh.write(f"MULT {m & 0xFFFFFFFF:08x}\n")
        fh.write(f"RELU {relu}\n")
        fh.write("BIAS " + " ".join(f"{v & 0xFFFFFFFF:08x}" for v in b) + "\n")
        for c in range(C):
            for yy in range(H):
                fh.write(" ".join(f"{x[c][yy][xx] & 0xFF:02x}" for xx in range(W)) + "\n")
        for i in range(0, len(w), 9):
            fh.write(" ".join(f"{v & 0xFF:02x}" for v in w[i:i+9]) + "\n")
        # Firma A: orden o -> y -> x (recorrido natural del generador)
        for o in range(O):
            for yy in range(H):
                fh.write(" ".join(f"{y[o][yy][xx] & 0xFF:02x}" for xx in range(W)) + "\n")
                for xx in range(W):
                    v = y[o][yy][xx]
                    sig = upd(sig, v); n_tot += 1
                    if v == 127: n_sat_pos += 1
                    if v == -128: n_sat_neg += 1
                    if v < 0: n_neg += 1

        # Firma B: orden y -> x -> o, que es el recorrido del testbench VHDL
        # (una salida por pixel, los 8 canales en paralelo). Es la que compara L2.
        for yy in range(H):
            for xx in range(W):
                for o in range(O):
                    sig_tb = upd(sig_tb, y[o][yy][xx])

        # cobertura de PE: par (canal_out, canal_in) con peso no nulo
        for o in range(O):
            for c in range(C):
                blk = w[(o*C + c)*9:(o*C + c)*9 + 9]
                if any(v != 0 for v in blk):
                    pe_seen.add((o, c))

    fh.write(f"SIGNATURE {sig:08x}\n")
    fh.write(f"SIGNATURE_TB {sig_tb:08x}\n")
    fh.close()

    with open(f"{outdir}/adversario_cobertura.txt", "w") as f:
        f.write(f"CASOS {len(cases)}\nVALORES {n_tot}\n")
        f.write(f"SAT_POS {n_sat_pos}\nSAT_NEG {n_sat_neg}\nNEGATIVOS {n_neg}\n")
        f.write(f"PES_CUBIERTOS {len(pe_seen)}/64\n")
        f.write(f"SIGNATURE {sig:08x}\n")
        f.write(f"SIGNATURE_TB {sig_tb:08x}\n")

    # Criterios de utilidad del estimulo: si fallan, el estimulo no sirve.
    assert n_sat_pos > 0, "adversario inutil: no fuerza saturacion positiva"
    assert n_sat_neg > 0, "adversario inutil: no fuerza saturacion negativa"
    assert n_neg > 0,     "adversario inutil: no produce salidas negativas"
    assert len(pe_seen) == 64, f"adversario inutil: solo cubre {len(pe_seen)}/64 PEs"

    print(f"L2 ADVERSARIO casos={len(cases)} valores={n_tot} sat+={n_sat_pos} "
          f"sat-={n_sat_neg} neg={n_neg} PEs={len(pe_seen)}/64 SIG=0x{sig:08X} SIG_TB=0x{sig_tb:08X}")

main()
