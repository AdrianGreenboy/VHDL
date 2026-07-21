#!/usr/bin/env python3
# HERCOSSNUX NPU - Oraculo L4 (spec HXQ8)
# Implementacion INDEPENDIENTE del generador: Python puro, enteros nativos,
# loops anidados. Anti modo-comun: cero numpy en la aritmetica.
# Uso: python3 oracle_npu.py npu_weights.hex npu_golden.txt
# Mutaciones (deben FALLAR): variable de entorno NPU_MUT=1..5
import sys, os

MUT = int(os.environ.get("NPU_MUT", "0"))

def sx8(v):   # hex byte -> int8
    return v - 256 if v >= 128 else v
def sx32(v):  # hex u32 -> int32
    return v - (1 << 32) if v >= (1 << 31) else v

def load_weights(path):
    tensors = {}; meta = {}
    with open(path) as f:
        lines = [l.strip() for l in f if l.strip()]
    for l in lines:
        if l.startswith("# M1"):
            t = l.split(); meta = {"M1": int(t[2]), "M2": int(t[4]), "M3": int(t[6]), "SHIFT": int(t[8])}
    i = 0; cur = None
    for l in lines:
        if l.startswith("#"): continue
        if l.startswith("@"):
            name, n = l[1:].split(); cur = name; tensors[cur] = []; continue
        v = int(l, 16)
        tensors[cur].append(sx8(v) if len(l) == 2 else sx32(v))
    return tensors, meta

def requant(acc, m, shift):
    if MUT == 1: shift += 1                       # shift +1
    if MUT == 2: v = (acc * m) >> shift           # sin redondeo
    else:        v = (acc * m + (1 << (shift - 1))) >> shift
    if v > 127: v = 127
    if v < -128: v = -128
    return v

def conv3x3(x, C, H, W, O, wts, bias, m, shift):
    # x: lista plana [c][y][x]; padding same=1 (MUT 3: sin padding en y)
    out = [[[0]*W for _ in range(H)] for _ in range(O)]
    pad = 1
    for o in range(O):
        for y in range(H):
            for xx in range(W):
                acc = bias[o]
                for c in range(C):
                    for ky in range(3):
                        for kx in range(3):
                            iy = y + ky - pad
                            ix = xx + kx - pad
                            if MUT == 3: iy = y + ky  # padding corrido
                            if 0 <= iy < H and 0 <= ix < W:
                                wv = wts[((o*C + c)*3 + ky)*3 + kx]
                                acc += x[c][iy][ix] * wv
                if acc < 0: acc = 0               # ReLU sobre acc int32
                out[o][y][xx] = requant(acc, m, shift)
    return out

def pool2(x, C, H, W):
    out = [[[0]*(W//2) for _ in range(H//2)] for _ in range(C)]
    for c in range(C):
        for y in range(H//2):
            for xx in range(W//2):
                a = x[c][2*y][2*xx];   b = x[c][2*y][2*xx+1]
                d = x[c][2*y+1][2*xx]; e = x[c][2*y+1][2*xx+1]
                if MUT == 4:
                    out[c][y][xx] = (a + b + d + e) // 4   # avg en vez de max
                else:
                    out[c][y][xx] = max(a, b, d, e)
    return out

def fc(flat, O, I, wts, bias):
    acc = []
    for o in range(O):
        s = bias[o]
        for i in range(I):
            if MUT == 5:
                s += flat[i] * wts[i*O + o]        # matriz transpuesta
            else:
                s += flat[i] * wts[o*I + i]
        acc.append(s)
    return acc

SIGP = 0x01000193
def sig_update(sig, vals):
    for v in vals:
        sig = (sig * SIGP + (v & 0xFF)) & 0xFFFFFFFF
    return sig

def flatten_chw(x):
    return [v for ch in x for row in ch for v in row]

def main():
    wf, gf = sys.argv[1], sys.argv[2]
    T, meta = load_weights(wf)
    M1, M2, M3, SH = meta["M1"], meta["M2"], meta["M3"], meta["SHIFT"]
    with open(gf) as f:
        lines = [l.rstrip("\n") for l in f]
    sig = 0x811C9DC5
    i = 0; n_img = 0; ok_cls = 0; golden_sig = None
    while i < len(lines):
        l = lines[i]
        if l.startswith("#"): i += 1; continue
        if l.startswith("SIGNATURE"):
            golden_sig = int(l.split()[1], 16); i += 1; continue
        if l.startswith("IMG"):
            t = l.split(); exp_class = int(t[3]); i += 1
            img = []
            for r in range(16):
                img.append([sx8(int(h, 16)) for h in lines[i].split()]); i += 1
            logits_line = lines[i]; i += 1
            x = [img]  # 1 canal
            a = conv3x3(x, 1, 16, 16, 8, T["W1"], T["B1"], M1, SH)
            a = pool2(a, 8, 16, 16)
            sig = sig_update(sig, flatten_chw(a))
            b = conv3x3(a, 8, 8, 8, 16, T["W2"], T["B2"], M2, SH)
            b = pool2(b, 16, 8, 8)
            sig = sig_update(sig, flatten_chw(b))
            flat = flatten_chw(b)
            acc = fc(flat, 10, 256, T["W3"], T["B3"])
            best = 0
            for k in range(10):
                if acc[k] > acc[best]: best = k
            lg = [requant(v, M3, SH) for v in acc]
            sig = sig_update(sig, lg)
            n_img += 1
            if best == exp_class: ok_cls += 1
            continue
        i += 1
    status = "OK" if (sig == golden_sig and ok_cls == n_img) else "FAIL"
    print(f"ORACULO {status} imgs={n_img} clases={ok_cls}/{n_img} SIG=0x{sig:08X} GOLDEN=0x{golden_sig:08X} MUT={MUT}")
    sys.exit(0 if status == "OK" else 1)

main()
