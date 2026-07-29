#!/usr/bin/env python3
# Modelo de referencia del self-test PQC completo. Reproduce las firmas del FSM:
#   KEM  sigk = 95e07091fa5b3cc4
#   DSA  sigd = f93232f7ea2d1575
# Las salidas del core (ek,dk,ct,ss,pk,sk,sig) vienen del vector; se foldean con
# FNV-64 en el orden exacto del tb_pqc_core.
mask64=(1<<64)-1; prime=0x00000100000001b3; INIT=0xcbf29ce484222325
def fold(s,byte):
    for k in range(4):
        s^=(byte>>(k*8))&0xFF; s=(s*prime)&mask64
    return s
def fold_bytes(s,data):
    for b in data: s=fold(s,b)
    return s

def kem_sig():
    kl=[l for l in open('/home/claude/pqc/l3rtl/kem_st_vectors.txt').read().splitlines() if not l.startswith('#')][0].split()
    _,d,z,m,ek,dk,ct,ss = kl
    ek=bytes.fromhex(ek);dk=bytes.fromhex(dk);ct=bytes.fromhex(ct);ss=bytes.fromhex(ss)
    s=INIT
    s=fold_bytes(s,ek); s=fold_bytes(s,dk)   # KeyGen: ek(1184)+dk(2400)
    s=fold_bytes(s,ct); s=fold_bytes(s,ss)   # Encaps: ct(1088)+ss(32)
    s=fold_bytes(s,ss)                        # Decaps: Kout=ss(32)
    return s

def dsa_sig():
    dl=[l for l in open('/home/claude/pqc/ntt_d/dsa_st_vectors.txt').read().splitlines() if not l.startswith('#')][0].split()
    xi,mu,pk,sk,sig = dl[1],dl[2],dl[3],dl[4],dl[5]
    pk=bytes.fromhex(pk);sk=bytes.fromhex(sk);sig=bytes.fromhex(sig)
    s=INIT
    s=fold_bytes(s,pk); s=fold_bytes(s,sk)   # KeyGen: pk(1952)+sk(4032)
    s=fold_bytes(s,sig)                       # Sign: sig(3309)
    s=fold(s,1)                               # Verify: result=1
    return s

if __name__=="__main__":
    k=kem_sig(); d=dsa_sig()
    print(f"KEM sigk = {k:016X}  match={k==0x95e07091fa5b3cc4}")
    print(f"DSA sigd = {d:016X}  match={d==0xf93232f7ea2d1575}")
