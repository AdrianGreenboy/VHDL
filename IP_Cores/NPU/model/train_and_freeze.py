#!/usr/bin/env python3
# HERCOSSNUX NPU - Fase A, Paso 1
# Entrenamiento reproducible (float32) + cuantizacion INT8 (spec HXQ8) +
# vectores dorados con firma de 32 bits.
# Determinista: semilla fija, numpy==2.2.6, un solo hilo.
import numpy as np, sys

np.random.seed(0xC0FFEE % (2**32))
rng = np.random.default_rng(20260719)

# ---------------- Dataset sintetico ----------------
GLYPHS = {
0:"01110 10001 10011 10101 11001 10001 01110",
1:"00100 01100 00100 00100 00100 00100 01110",
2:"01110 10001 00001 00010 00100 01000 11111",
3:"11111 00010 00100 00010 00001 10001 01110",
4:"00010 00110 01010 10010 11111 00010 00010",
5:"11111 10000 11110 00001 00001 10001 01110",
6:"00110 01000 10000 11110 10001 10001 01110",
7:"11111 00001 00010 00100 01000 01000 01000",
8:"01110 10001 10001 01110 10001 10001 01110",
9:"01110 10001 10001 01111 00001 00010 01100"}

def glyph(d):
    rows = GLYPHS[d].split()
    return np.array([[int(c) for c in r] for r in rows], dtype=np.float32)  # 7x5

def render(d, rng):
    g = glyph(d)                       # 7x5
    g = np.kron(g, np.ones((2,2), dtype=np.float32))   # 14x10
    img = np.zeros((16,16), dtype=np.float32)
    oy = rng.integers(0, 3)            # 16-14=2 -> 0..2
    ox = rng.integers(0, 7)            # 16-10=6 -> 0..6
    amp = 0.6 + 0.4*rng.random()
    img[oy:oy+14, ox:ox+10] = g*amp
    img += rng.normal(0.0, 0.08, size=(16,16)).astype(np.float32)
    return np.clip(img, 0.0, 1.0)

def make_set(n, rng):
    X = np.zeros((n,1,16,16), dtype=np.float32); Y = np.zeros(n, dtype=np.int64)
    for i in range(n):
        d = int(rng.integers(0,10)); Y[i]=d; X[i,0]=render(d, rng)
    return X, Y

Xtr, Ytr = make_set(4000, rng)
Xte, Yte = make_set(1000, rng)

# ---------------- Red float32 ----------------
# conv1 3x3 1->8 same, ReLU, maxpool2 -> 8x8x8
# conv2 3x3 8->16 same, ReLU, maxpool2 -> 4x4x16
# fc 256->10
def he(shape, fan_in, rng):
    return (rng.standard_normal(shape)*np.sqrt(2.0/fan_in)).astype(np.float32)

W1 = he((8,1,3,3), 9, rng);    b1 = np.zeros(8, np.float32)
W2 = he((16,8,3,3), 72, rng);  b2 = np.zeros(16, np.float32)
W3 = he((10,256), 256, rng);   b3 = np.zeros(10, np.float32)

def im2col(x, k=3, pad=1, stride=1):
    N,C,H,W = x.shape
    xp = np.pad(x, ((0,0),(0,0),(pad,pad),(pad,pad)))
    Ho = (H+2*pad-k)//stride+1; Wo = (W+2*pad-k)//stride+1
    cols = np.zeros((N, C*k*k, Ho*Wo), dtype=x.dtype)
    idx = 0
    for c in range(C):
        for i in range(k):
            for j in range(k):
                patch = xp[:, c, i:i+Ho*stride:stride, j:j+Wo*stride:stride]
                cols[:, idx, :] = patch.reshape(N, -1); idx += 1
    return cols, Ho, Wo

def conv_f(x, W, b):
    N = x.shape[0]; O,C,k,_ = W.shape
    cols, Ho, Wo = im2col(x, k, 1, 1)
    out = np.einsum('oc,ncp->nop', W.reshape(O,-1), cols) + b[None,:,None]
    return out.reshape(N,O,Ho,Wo), cols

def pool_f(x):
    N,C,H,W = x.shape
    xr = x.reshape(N,C,H//2,2,W//2,2)
    out = xr.max(axis=(3,5))
    return out, xr

def forward(x):
    c1,_ = conv_f(x, W1, b1); r1 = np.maximum(c1,0); p1,_ = pool_f(r1)
    c2,_ = conv_f(p1, W2, b2); r2 = np.maximum(c2,0); p2,_ = pool_f(r2)
    flat = p2.reshape(x.shape[0], -1)
    return flat @ W3.T + b3

def accuracy(X, Y, bs=250):
    ok = 0
    for i in range(0, len(X), bs):
        ok += (forward(X[i:i+bs]).argmax(1) == Y[i:i+bs]).sum()
    return ok/len(X)

# Entrenamiento SGD+momentum con backward manual via im2col
lr, mom, bs = 0.05, 0.9, 64
V = [np.zeros_like(p) for p in (W1,b1,W2,b2,W3,b3)]
order = np.arange(len(Xtr))
for epoch in range(6):
    rng.shuffle(order)
    for s in range(0, len(Xtr), bs):
        idx = order[s:s+bs]; x = Xtr[idx]; y = Ytr[idx]; N = len(idx)
        # forward con caches
        c1, cols1 = conv_f(x, W1, b1); r1 = np.maximum(c1,0); p1, xr1 = pool_f(r1)
        c2, cols2 = conv_f(p1, W2, b2); r2 = np.maximum(c2,0); p2, xr2 = pool_f(r2)
        flat = p2.reshape(N,-1); logits = flat @ W3.T + b3
        # softmax CE
        m = logits.max(1, keepdims=True); e = np.exp(logits-m); p = e/e.sum(1, keepdims=True)
        dl = p.copy(); dl[np.arange(N), y] -= 1; dl /= N
        gW3 = dl.T @ flat; gb3 = dl.sum(0)
        dflat = dl @ W3; dp2 = dflat.reshape(p2.shape)
        # unpool2 (gradiente al maximo)
        mask2 = (xr2 == p2[:,:,:,None,:,None]).astype(np.float32)
        # reparte solo al primer max para exactitud
        dr2 = (mask2 * dp2[:,:,:,None,:,None]).reshape(r2.shape)
        dc2 = dr2 * (c2 > 0)
        O2 = W2.shape[0]
        dW2 = np.einsum('nop,ncp->oc', dc2.reshape(N,O2,-1), cols2).reshape(W2.shape)
        gb2 = dc2.sum(axis=(0,2,3))
        dcols2 = np.einsum('oc,nop->ncp', W2.reshape(O2,-1), dc2.reshape(N,O2,-1))
        # col2im para dp1
        dp1 = np.zeros_like(p1); xp = np.zeros((N,8,10,10), dtype=np.float32)
        idxc = 0
        for cch in range(8):
            for i in range(3):
                for j in range(3):
                    xp[:, cch, i:i+8, j:j+8] += dcols2[:, idxc, :].reshape(N,8,8); idxc += 1
        dp1 = xp[:,:,1:9,1:9]
        mask1 = (xr1 == p1[:,:,:,None,:,None]).astype(np.float32)
        dr1 = (mask1 * dp1[:,:,:,None,:,None]).reshape(r1.shape)
        dc1 = dr1 * (c1 > 0)
        O1 = W1.shape[0]
        dW1 = np.einsum('nop,ncp->oc', dc1.reshape(N,O1,-1), cols1).reshape(W1.shape)
        gb1 = dc1.sum(axis=(0,2,3))
        grads = [dW1, gb1, dW2, gb2, gW3, gb3]
        params = [W1, b1, W2, b2, W3, b3]
        for k in range(6):
            V[k] = mom*V[k] - lr*grads[k]
            params[k] += V[k]
    tr = accuracy(Xtr[:1000], Ytr[:1000]); te = accuracy(Xte, Yte)
    print(f"epoch {epoch} train {tr:.4f} test {te:.4f}", file=sys.stderr)

acc_f = accuracy(Xte, Yte)

# ---------------- Cuantizacion HXQ8 (spec congelada) ----------------
# - pesos: int8 simetrico por tensor, sw = maxabs/127
# - activaciones: int8 simetrico, escala por calibracion (maxabs/127)
# - bias: int32 en escala s_in*sw
# - requantize: acc int32 -> (acc*m + (1<<30)) >> 31 con m int32 = round(M*2^31),
#   producto en int64, saturacion a [-128,127]. ReLU sobre acc int32 antes.
def qw(W):
    s = float(np.abs(W).max())/127.0
    q = np.clip(np.round(W/s), -127, 127).astype(np.int32)
    return q, s

def calib_max(f, X, bs=250):
    mx = 0.0
    for i in range(0, len(X), bs):
        mx = max(mx, float(np.abs(f(X[i:i+bs])).max()))
    return mx

s_in = 1.0/127.0  # entrada ya esta en [0,1]
def f_c1(x):
    c1,_ = conv_f(x, W1, b1); r1 = np.maximum(c1,0); p1,_ = pool_f(r1); return p1
def f_c2(x):
    c2,_ = conv_f(f_c1(x), W2, b2); r2 = np.maximum(c2,0); p2,_ = pool_f(r2); return p2
def f_lg(x):
    return f_c2(x).reshape(len(x),-1) @ W3.T + b3

s1 = calib_max(f_c1, Xtr[:512])/127.0
s2 = calib_max(f_c2, Xtr[:512])/127.0
s3 = calib_max(f_lg, Xtr[:512])/127.0

Q1, sw1 = qw(W1); Q2, sw2 = qw(W2); Q3, sw3 = qw(W3)
B1 = np.round(b1/(s_in*sw1)).astype(np.int32)
B2 = np.round(b2/(s1*sw2)).astype(np.int32)
B3 = np.round(b3/(s2*sw3)).astype(np.int32)

def mshift(M):
    m = int(round(M * (1<<31)))
    assert 0 < m < (1<<31), f"multiplicador fuera de rango: {m}"
    return m

M1 = mshift(s_in*sw1/s1); M2 = mshift(s1*sw2/s2); M3 = mshift(s2*sw3/s3)

def requant(acc, m):
    # acc int32 (np.int64 para el producto), redondeo +2^30, shift 31, sat int8
    v = (acc.astype(np.int64)*m + (1<<30)) >> 31
    return np.clip(v, -128, 127).astype(np.int32)

def conv_q(xq, Q, B, k=3):
    x4 = xq.astype(np.int64)[None] if xq.ndim==3 else xq.astype(np.int64)
    cols, Ho, Wo = im2col(x4.astype(np.float64), k, 1, 1)
    cols = cols.astype(np.int64)
    O = Q.shape[0]
    out = np.einsum('oc,ncp->nop', Q.reshape(O,-1).astype(np.int64), cols) + B[None,:,None].astype(np.int64)
    assert np.abs(out).max() < (1<<31), "overflow acc int32"
    return out.reshape(x4.shape[0],O,Ho,Wo)

def pool_q(x):
    N,C,H,W = x.shape
    return x.reshape(N,C,H//2,2,W//2,2).max(axis=(3,5))

SIGP = 0x01000193  # primo FNV
def sig_update(sig, arr):
    for v in arr.reshape(-1).astype(np.int64):
        sig = (sig*SIGP + int(v & 0xFF)) & 0xFFFFFFFF
    return sig

def infer_q(xq):
    # xq int8 1x16x16 -> (clase, [sig1,sig2,sig3], logits_i8)
    a = conv_q(xq[None], Q1, B1)[0]
    a = np.maximum(a, 0)
    a = requant(a, M1)
    a = pool_q(a[None])[0]
    s1_ = a.copy()
    b = conv_q(a[None], Q2, B2)[0]
    b = np.maximum(b, 0)
    b = requant(b, M2)
    b = pool_q(b[None])[0]
    s2_ = b.copy()
    flat = b.reshape(-1).astype(np.int64)
    acc = Q3.astype(np.int64) @ flat + B3.astype(np.int64)
    assert np.abs(acc).max() < (1<<31)
    lg = requant(acc.astype(np.int64), M3)
    return int(np.argmax(acc)), (s1_, s2_, lg), lg

def quant_in(x):
    return np.clip(np.round(x/s_in), -128, 127).astype(np.int32)

# Precision INT8 sobre el set de prueba
ok = 0
for i in range(len(Xte)):
    c,_,_ = infer_q(quant_in(Xte[i,0]))
    ok += (c == Yte[i])
acc_q = ok/len(Xte)

# ---------------- Emision de artefactos ----------------
def hexline(v, width):
    return format(v & ((1<<width)-1), f'0{width//4}x')

with open("npu_weights.hex","w") as f:
    f.write("# HERCOSSNUX NPU HXQ8 weights v1\n")
    f.write(f"# M1 {M1} M2 {M2} M3 {M3} SHIFT 31\n")
    for name, arr, w in [("W1",Q1,8),("B1",B1,32),("W2",Q2,8),("B2",B2,32),
                          ("W3",Q3,8),("B3",B3,32)]:
        f.write(f"@{name} {arr.size}\n")
        for v in arr.reshape(-1):
            f.write(hexline(int(v), w)+"\n")

# Vectores dorados: 32 imagenes, firma global
GN = 32
sig = 0x811C9DC5  # offset FNV
with open("npu_golden.txt","w") as f:
    f.write(f"# HERCOSSNUX NPU golden vectors v1 N={GN}\n")
    for i in range(GN):
        xq = quant_in(Xte[i,0])
        c, sigs, lg = infer_q(xq)
        for s in sigs: sig = sig_update(sig, s)
        f.write(f"IMG {i} CLASS {c} EXPECT {int(Yte[i])}\n")
        for row in xq:
            f.write(" ".join(hexline(int(v),8) for v in row)+"\n")
        f.write("LOGITS " + " ".join(hexline(int(v),8) for v in lg)+"\n")
    f.write(f"SIGNATURE {sig:08x}\n")

print(f"NPU PASO1 float_acc={acc_f:.4f} int8_acc={acc_q:.4f} M1={M1} M2={M2} M3={M3} SIG=0x{sig:08X}")
