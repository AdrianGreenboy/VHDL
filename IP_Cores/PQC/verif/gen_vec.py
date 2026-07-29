#!/usr/bin/env python3
# Generate Keccak-f[1600] permutation vectors + sponge vectors for L1 TB.
import hashlib, struct

RC = [0x0000000000000001,0x0000000000008082,0x800000000000808A,0x8000000080008000,
      0x000000000000808B,0x0000000080000001,0x8000000080008081,0x8000000000008009,
      0x000000000000008A,0x0000000000000088,0x0000000080008009,0x000000008000000A,
      0x000000008000808B,0x800000000000008B,0x8000000000008089,0x8000000000008003,
      0x8000000000008002,0x8000000000000080,0x000000000000800A,0x800000008000000A,
      0x8000000080008081,0x8000000000008080,0x0000000080000001,0x8000000080008008]
R = [[0,36,3,41,18],[1,44,10,45,2],[62,6,43,15,61],[28,55,25,21,56],[27,20,39,8,14]]
M = (1<<64)-1
def rol(x,n): n%=64; return ((x<<n)|(x>>(64-n)))&M if n else x

def keccak_f(A):
    A=[r[:] for r in A]
    for rnd in range(24):
        C=[A[x][0]^A[x][1]^A[x][2]^A[x][3]^A[x][4] for x in range(5)]
        D=[C[(x-1)%5]^rol(C[(x+1)%5],1) for x in range(5)]
        for x in range(5):
            for y in range(5): A[x][y]^=D[x]
        B=[[0]*5 for _ in range(5)]
        for x in range(5):
            for y in range(5): B[y][(2*x+3*y)%5]=rol(A[x][y],R[x][y])
        for x in range(5):
            for y in range(5): A[x][y]=B[x][y]^((~B[(x+1)%5][y])&B[(x+2)%5][y])&M
        A[0][0]^=RC[rnd]
    return A

def flat(A): return [A[i%5][i//5] for i in range(25)]
def unflat(v):
    A=[[0]*5 for _ in range(5)]
    for i,w in enumerate(v): A[i%5][i//5]=w
    return A

vecs=[]
# V0: all-zero state
vecs.append([0]*25)
# V1: result of permuting all-zero (chained)
vecs.append(flat(keccak_f(unflat(vecs[0]))))
# V2: counter pattern
vecs.append([(i*0x0101010101010101)&M for i in range(25)])
# V3: alternating
vecs.append([0xA5A5A5A5A5A5A5A5 if i%2==0 else 0x5A5A5A5A5A5A5A5A for i in range(25)])
# V4: single bit in last lane (checks pi/rho far corner)
v=[0]*25; v[24]=1<<63; vecs.append(v)

with open('keccak_vectors.txt','w') as f:
    f.write("# Keccak-f[1600] permutation vectors: input line then output line\n")
    f.write("# 25 lanes, little-endian lane index 0..24, hex 16 chars each\n")
    for v in vecs:
        o=flat(keccak_f(unflat(v)))
        f.write("".join("%016X"%w for w in v)+"\n")
        f.write("".join("%016X"%w for w in o)+"\n")

# Sponge vectors for the wrapper (mode, rate, msg, outlen, digest)
def mk(name, fn, msg, olen):
    return (name, msg.hex(), fn(msg).hex() if olen is None else fn(msg, olen).hex())

sp=[]
msgs=[b"", b"abc", bytes(range(200)), b"\xa5"*135, b"\xa5"*136, b"\xa5"*137,
      bytes(range(256))*3]
with open('sponge_vectors.txt','w') as f:
    f.write("# mode msglen_bytes outlen_bytes msg_hex digest_hex\n")
    f.write("# mode: 0=SHAKE128 1=SHAKE256 2=SHA3-256 3=SHA3-512\n")
    for m in msgs:
        for mode,fn,olen in [
            (0, lambda b,n: hashlib.shake_128(b).digest(n), 64),
            (1, lambda b,n: hashlib.shake_256(b).digest(n), 64),
            (2, lambda b,n: hashlib.sha3_256(b).digest(), 32),
            (3, lambda b,n: hashlib.sha3_512(b).digest(), 64)]:
            d=fn(m,olen)
            f.write("%d %d %d %s %s\n"%(mode,len(m),len(d),m.hex() if m else "-",d.hex()))
    # incremental squeeze checks: long outputs from SHAKE
    for mode,fn in [(0,hashlib.shake_128),(1,hashlib.shake_256)]:
        for olen in [168,169,336,504,672]:
            m=b"HERCOSSNUX-PQC"
            f.write("%d %d %d %s %s\n"%(mode,len(m),olen,m.hex(),fn(m).digest(olen).hex()))
print("vectors written")
