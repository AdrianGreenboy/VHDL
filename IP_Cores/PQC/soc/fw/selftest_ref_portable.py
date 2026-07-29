#!/usr/bin/env python3
# Modelo de referencia del self-test PQC. Detecta los vectores automaticamente.
# Reproduce KEM=95e07091fa5b3cc4 y DSA=f93232f7ea2d1575.
import os, glob
mask64=(1<<64)-1; prime=0x00000100000001b3; INIT=0xcbf29ce484222325

def fold(s,byte):
    for k in range(4):
        s^=(byte>>(k*8))&0xFF; s=(s*prime)&mask64
    return s
def fold_bytes(s,data):
    for b in data: s=fold(s,b)
    return s

def find_vec(name):
    # busca el vector en ubicaciones tipicas del repo
    for base in [os.path.expanduser('~/vhdl_repo/IP_Cores/PQC/verif'),
                 os.path.expanduser('~/vhdl_repo/IP_Cores/PQC'),
                 '.', '..']:
        hits=glob.glob(os.path.join(base,'**',name), recursive=True)
        if hits: return hits[0]
    raise FileNotFoundError(f"no encontre {name}")

def kem_sig():
    kl=[l for l in open(find_vec('kem_st_vectors.txt')).read().splitlines() if not l.startswith('#')][0].split()
    _,d,z,m,ek,dk,ct,ss = kl
    ek=bytes.fromhex(ek);dk=bytes.fromhex(dk);ct=bytes.fromhex(ct);ss=bytes.fromhex(ss)
    s=INIT
    s=fold_bytes(s,ek); s=fold_bytes(s,dk)
    s=fold_bytes(s,ct); s=fold_bytes(s,ss)
    s=fold_bytes(s,ss)
    return s

def dsa_sig():
    dl=[l for l in open(find_vec('dsa_st_vectors.txt')).read().splitlines() if not l.startswith('#')][0].split()
    xi,mu,pk,sk,sig = dl[1],dl[2],dl[3],dl[4],dl[5]
    pk=bytes.fromhex(pk);sk=bytes.fromhex(sk);sig=bytes.fromhex(sig)
    s=INIT
    s=fold_bytes(s,pk); s=fold_bytes(s,sk)
    s=fold_bytes(s,sig)
    s=fold(s,1)
    return s

if __name__=="__main__":
    k=kem_sig(); d=dsa_sig()
    print(f"KEM sigk = {k:016X}  match={k==0x95e07091fa5b3cc4}")
    print(f"DSA sigd = {d:016X}  match={d==0xf93232f7ea2d1575}")
