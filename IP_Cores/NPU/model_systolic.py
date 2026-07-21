#!/usr/bin/env python3
# HERCOSSNUX NPU - modelo del array sistolico 8x8 output-stationary.
# Fija el dataflow ANTES de escribir VHDL y lo valida contra el oraculo.
#
# Mapeo espacial congelado:
#   - Fila r del array  <-> canal de entrada  c = r   (C_IN  = PE_DIM = 8)
#   - Columna k         <-> canal de salida   o = k   (C_OUT = PE_DIM = 8)
#   - PE(r,k) acumula   sum_over_kernel( x[c=r] * w[o=k][c=r] )
#   - Al cerrar una ventana, la columna k reduce sus 8 filas -> acc del canal o=k
#
# Los pesos entran por el borde superior y bajan (skew por columna).
# Las activaciones entran por el borde izquierdo y avanzan (skew por fila).
# Cada PE registra un ciclo -> el dato del PE(r,k) llega en t = base + r + k.
import sys, importlib.util

def load_oracle(path):
    spec = importlib.util.spec_from_file_location("oracle_npu", path)
    mod = importlib.util.module_from_spec(spec)
    saved = sys.argv; sys.argv = ["oracle_npu"]
    try: spec.loader.exec_module(mod)
    except (SystemExit, IndexError): pass
    finally: sys.argv = saved
    return mod

PE_DIM = 8

def requant(acc, m, shift, relu):
    if relu and acc < 0: acc = 0
    v = (acc * m + (1 << (shift - 1))) >> shift
    if v > 127: v = 127
    if v < -128: v = -128
    return v

def systolic_conv(x, C, H, W, O, wts, bias, m, shift, relu):
    """Modelo ciclo-aproximado del array output-stationary.

    Emula explicitamente los 64 PEs y la reduccion por columna, para que el
    RTL tenga una referencia estructural (no solo el resultado final).
    """
    assert C <= PE_DIM and O <= PE_DIM, "capa mayor que el array: requiere tiling"
    out = [[[0]*W for _ in range(H)] for _ in range(O)]

    for y in range(H):
        for xx in range(W):
            # Un "paso de ventana": cada PE(r,k) acumula sus 9 productos.
            pe_acc = [[0]*PE_DIM for _ in range(PE_DIM)]
            for ky in range(3):
                for kx in range(3):
                    iy = y + ky - 1; ix = xx + kx - 1
                    for r in range(C):
                        av = x[r][iy][ix] if (0 <= iy < H and 0 <= ix < W) else 0
                        for k in range(O):
                            wv = wts[((k*C + r)*3 + ky)*3 + kx]
                            pe_acc[r][k] += av * wv
            # Reduccion por columna: suma de las 8 filas + bias del canal k
            for k in range(O):
                acc = bias[k]
                for r in range(C):
                    acc += pe_acc[r][k]
                assert -(1 << 31) <= acc < (1 << 31), "systolic: acc fuera de int32"
                out[k][y][xx] = requant(acc, m, shift, relu)
    return out

def pe_schedule(C, O):
    """Devuelve el ciclo de llegada de cada PE bajo el skew triangular.
    Sirve para dimensionar el pipeline de drenaje en el RTL."""
    sched = {}
    for r in range(C):
        for k in range(O):
            sched[(r, k)] = r + k
    return sched

def main():
    oracle_py, wf, gf = sys.argv[1], sys.argv[2], sys.argv[3]
    Ora = load_oracle(oracle_py)
    T, meta = Ora.load_weights(wf)
    M2, SH = meta["M2"], meta["SHIFT"]

    import random
    rnd = random.Random(4242)
    C = O = 8; H = W = 8
    bad = 0
    for trial in range(8):
        x = [[[rnd.randint(-128,127) for _ in range(W)] for _ in range(H)] for _ in range(C)]
        w = [rnd.randint(-128,127) for _ in range(O*C*9)]
        b = [rnd.randint(-(1<<18), 1<<18) for _ in range(O)]
        m = rnd.choice([1<<20, 5064654, 1<<24])
        ys = systolic_conv(x, C, H, W, O, w, b, m, SH, True)
        yo = Ora.conv3x3(x, C, H, W, O, w, b, m, SH)
        if ys != yo:
            bad += 1
            print(f"DISCREPANCIA dataflow en trial {trial}")

    # Verificacion con los pesos reales de conv2
    lines = open(gf).read().split("\n")
    i = 0; img = None
    while i < len(lines):
        if lines[i].startswith("IMG"):
            i += 1; img = []
            for r in range(16):
                img.append([Ora.sx8(int(h,16)) for h in lines[i].split()]); i += 1
            break
        i += 1
    a = Ora.conv3x3([img], 1, 16, 16, 8, T["W1"], T["B1"], meta["M1"], SH)
    a = Ora.pool2(a, 8, 16, 16)
    ys = systolic_conv(a, 8, 8, 8, 16 if False else 8,
                       T["W2"][:8*8*9], T["B2"][:8], M2, SH, True)
    yo = Ora.conv3x3(a, 8, 8, 8, 8, T["W2"][:8*8*9], T["B2"][:8], M2, SH)
    real_ok = (ys == yo)

    sched = pe_schedule(8, 8)
    drain = max(sched.values())

    print(f"DATAFLOW aleatorios=8 discrepancias={bad} pesos_reales_ok={real_ok} "
          f"ciclos_drenaje={drain}")
    if bad or not real_ok:
        sys.exit(1)

main()
