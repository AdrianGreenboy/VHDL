#!/usr/bin/env python3
# iss.py - Interprete RV32IM (oraculo capa 4) + ensamblador minimo.
# Modela el SoC RF: core + imem + dmem(scratch) + MMIO del banco RF (0x60000000)
# + DMA maestro a un DDR simulado (0x70000000) + el lazo RF (reusa el modelo
# 1c/rfloop ya verificado). Ejecuta el firmware y produce el contenido esperado
# de DDR (las N palabras I/Q capturadas). El RTL de capa 4 debe reproducirlo.
#
# ISA soportado (subset RV32IM usado por el firmware): lui, auipc, addi, add,
# sub, and, or, xor, sll, srl, sra, slt, sltu, slti, andi, ori, xori, slli,
# srli, srai, lw, sw, lh, lhu, sh, lb, lbu, sb, beq, bne, blt, bge, bltu, bgeu,
# jal, jalr, mul, ecall. Formato de asm: una instr por linea, comentarios ';'.
# Etiquetas 'nombre:'. jalr en formato 'jalr rd, imm(rs1)'.

import sys, re

REG = {'zero':0,'ra':1,'sp':2,'gp':3,'tp':4,'t0':5,'t1':6,'t2':7,
       's0':8,'fp':8,'s1':9,'a0':10,'a1':11,'a2':12,'a3':13,'a4':14,
       'a5':15,'a6':16,'a7':17,'s2':18,'s3':19,'s4':20,'s5':21,'s6':22,
       's7':23,'s8':24,'s9':25,'s10':26,'s11':27,'t3':28,'t4':29,'t5':30,'t6':31}
for i in range(32): REG['x%d'%i]=i

M32=0xFFFFFFFF
def s32(v): 
    v&=M32
    return v-0x100000000 if v&0x80000000 else v

# ---------------- Ensamblador ----------------
def parse_reg(t): 
    t=t.strip().rstrip(',')
    return REG[t]

def asm(lines):
    # dos pasadas: etiquetas -> direcciones de palabra (imem indexado por instr)
    prog=[]; labels={}; pc=0
    clean=[]
    for ln in lines:
        ln=ln.split(';')[0].strip()
        if not ln: continue
        m=re.match(r'^(\w+):\s*(.*)$', ln)
        if m:
            labels[m.group(1)]=len(clean)
            rest=m.group(2).strip()
            if rest: clean.append(rest)
        else:
            clean.append(ln)
    def imm_of(tok, cur):
        tok=tok.strip()
        if tok in labels: return (labels[tok]-cur)  # offset en instrucciones
        return int(tok,0)
    code=[]
    for idx,ln in enumerate(clean):
        parts=ln.replace(',',' ').split()
        op=parts[0]
        code.append((op,parts[1:],idx,ln))
    return code, labels

# ---------------- Modelo del lazo RF (identico al RTL verificado) ----------------
lut=[int(l) for l in open('lut_vals.txt')]
def sat16(v): return 32767 if v>32767 else (-32768 if v<-32768 else v)
def wrap32(v): return ((v+0x80000000)&M32)-0x80000000
def loopmix(bi,bq,s,c,le):
    rf_i=sat16((bi*c-bq*s)>>15); rf_q=sat16((bq*c+bi*s)>>15)
    if not le: rf_i=rf_q=0
    di=sat16((rf_i*c+rf_q*s)>>15); dq=sat16((rf_q*c-rf_i*s)>>15)
    return di,dq
class CicDec:
    def __init__(s,sel): s.R=4<<sel; s.sh=3*(sel+2); s.i1=s.i2=s.i3=0; s.d1=s.d2=s.d3=0; s.cnt=0
    def push(s,x):
        out=None
        if s.cnt==s.R-1:
            v=s.i3; c1=wrap32(v-s.d1); c2=wrap32(c1-s.d2); c3=wrap32(c2-s.d3)
            s.d1,s.d2,s.d3=v,c1,c2; out=sat16(c3>>s.sh); s.cnt=0
        else: s.cnt+=1
        s.i3=wrap32(s.i3+s.i2); s.i2=wrap32(s.i2+s.i1); s.i1=wrap32(s.i1+x)
        return out
class CicInt:
    def __init__(s,sel): s.R=4<<sel; s.sh=2*(sel+2); s.i1=s.i2=s.i3=0; s.d1=s.d2=s.d3=0
    def push(s,x):
        c1=wrap32(x-s.d1); c2=wrap32(c1-s.d2); c3=wrap32(c2-s.d3); s.d1,s.d2,s.d3=x,c1,c2
        outs=[]
        for k in range(s.R):
            u=c3 if k==0 else 0; outs.append(sat16(s.i3>>s.sh))
            s.i3=wrap32(s.i3+s.i2); s.i2=wrap32(s.i2+s.i1); s.i1=wrap32(s.i1+u)
        return outs
COEF_PASS=[32767]+[0]*15
class RFLoop:
    # Genera muestras RX (I:Q de 32 bits) del lazo con banda base DC(20000,0),
    # R=8, FIRs passthrough, AGC off. Alimenta una cola que el MMIO drena.
    def __init__(s):
        s.hist={'txi':[0]*16,'txq':[0]*16,'rxi':[0]*16,'rxq':[0]*16}
        s.itp_i=CicInt(1); s.itp_q=CicInt(1); s.dec_i=CicDec(1); s.dec_q=CicDec(1)
        s.ph=0; s.queue=[]; s.pushes=0; s.enabled=False
    def fir(s,h,x,key):
        b=s.hist[key]; b.insert(0,x); b.pop()
        return sat16(sum(h[k]*b[k] for k in range(16))>>15)
    def enable(s): s.enabled=True
    def step_push(s):
        # un push de banda base -> interpolador directo (sin TX FIR, passthrough)
        hi=s.itp_i.push(20000); hq=s.itp_q.push(0)
        for k in range(len(hi)):
            idx=(s.ph>>22)&0x3FF; sc=lut[idx]; cc=lut[(idx+256)&0x3FF]; s.ph=(s.ph+0x0293A800)&M32
            di,dq=loopmix(hi[k],hq[k],sc,cc,1)
            oi=s.dec_i.push(di); oq=s.dec_q.push(dq)
            if oi is None: continue
            fi=s.fir(COEF_PASS,oi,'rxi'); fq=s.fir(COEF_PASS,oq,'rxq')
            s.queue.append(((fi&0xFFFF)<<16)|(fq&0xFFFF))
        s.pushes+=1

# ---------------- Modelo del SoC / ejecucion ----------------
# Mapa: MMIO base 0x60000000 (offsets del banco). DDR 0x70000000.
# dmem scratch 0x00000000..0x0000FFFF (64KB). El firmware corre desde imem.
RF_BASE=0x60000000
DDR_BASE=0x70000000
OFF_CTRL=0x00; OFF_STATUS=0x04; OFF_FTW=0x08; OFF_RSSI=0x0C; OFF_AGC=0x10
OFF_CFA=0x14; OFF_CFD=0x18; OFF_RXLVL=0x1C; OFF_RXDAT=0x20; OFF_TXDAT=0x24
OFF_IRQEN=0x28; OFF_IRQST=0x2C; OFF_IRQTH=0x30
OFF_DMAA=0x34; OFF_DMAL=0x38; OFF_DMAC=0x3C; OFF_DBG=0x44

class Soc:
    def __init__(s, npush):
        s.reg=[0]*32; s.pc=0; s.halt=False
        s.dmem=bytearray(0x10000)
        s.ddr={}       # dir -> palabra de 32 bits
        s.rf=RFLoop()
        s.npush=npush  # cuantos pushes de banda base alimentar
        s.pushed=0
        # registros MMIO
        s.ctrl=0; s.ftw=0; s.irqen=0; s.irqth=0; s.irqst=0
        s.dma_a=0; s.dma_l=0; s.dma_c=0
    def rf_advance(s):
        # el lazo produce muestras mientras rx_en y haya pushes por hacer
        if (s.ctrl & 1) and s.pushed < s.npush:
            s.rf.step_push(); s.pushed+=1
    def mmio_read(s, off):
        # avanzar el lazo en cada acceso de status/level para simular tiempo real
        if off==OFF_STATUS:
            s.rf_advance()
            rx_e=1 if len(s.rf.queue)==0 else 0
            return (rx_e<<0)
        elif off==OFF_RXLVL:
            s.rf_advance()
            return len(s.rf.queue)&0x3FF
        elif off==OFF_RXDAT:
            return s.rf.queue.pop(0) if s.rf.queue else 0
        elif off==OFF_RSSI: return 0
        elif off==OFF_IRQST:
            # el hardware latch-ea bit0 cuando rx_level>=umbral y esta habilitado.
            # avanzar el lazo para que se llene y evaluar.
            s.rf_advance()
            if (s.irqen & 1) and s.irqth>0 and len(s.rf.queue) >= (s.irqth & 0x3FF):
                s.irqst |= 1
            return s.irqst
        elif off==OFF_DBG: return 0xC0FFEE00
        elif off==OFF_CTRL: return s.ctrl
        return 0
    def mmio_write(s, off, val):
        if off==OFF_CTRL: s.ctrl=val&M32
        elif off==OFF_FTW: s.ftw=val&M32
        elif off==OFF_IRQEN: s.irqen=val&M32
        elif off==OFF_IRQTH: s.irqth=val&M32
        elif off==OFF_DMAA: s.dma_a=val&M32
        elif off==OFF_DMAL: s.dma_l=val&M32
        elif off==OFF_DMAC:
            s.dma_c=val&M32
            if val&1: s.run_dma()
    def run_dma(s):
        # DMA maestro: copia dma_l palabras desde la RX FIFO a DDR[dma_a..].
        # Emula el split en frontera de 4KB (no cambia el contenido, solo el
        # troceo; el resultado en DDR es identico). Drena la cola del lazo,
        # avanzando el lazo si hace falta para tener datos.
        n=s.dma_l; a=s.dma_a
        for i in range(n):
            while len(s.rf.queue)==0 and s.pushed<s.npush:
                s.rf_advance()
            w=s.rf.queue.pop(0) if s.rf.queue else 0
            s.ddr[a]=w; a=(a+4)&M32
        s.irqst|=1  # DMA done
    def load(s, addr):
        addr&=M32
        if addr>=DDR_BASE: return s.ddr.get(addr,0)
        if addr>=RF_BASE: return s.mmio_read(addr-RF_BASE)
        w=int.from_bytes(s.dmem[addr:addr+4],'little'); return w
    def store(s, addr, val, sz=4):
        addr&=M32
        if addr>=DDR_BASE: s.ddr[addr]=val&M32; return
        if addr>=RF_BASE: s.mmio_write(addr-RF_BASE, val); return
        val&=(0xFFFFFFFF if sz==4 else (0xFFFF if sz==2 else 0xFF))
        for b in range(sz):
            s.dmem[addr+b]=(val>>(8*b))&0xFF

def run(code, labels, npush, max_steps=2000000):
    s=Soc(npush)
    def R(i): return s.reg[i] if i else 0
    def setR(i,v):
        if i: s.reg[i]=v&M32
    while not s.halt and s.pc//4 < len(code) and s.pc>=0:
        op,args,idx,raw=code[s.pc//4]
        nxt=s.pc+4
        try:
            if op=='lui': setR(parse_reg(args[0]), (int(args[1],0)&0xFFFFF)<<12)
            elif op=='auipc': setR(parse_reg(args[0]), (s.pc+((int(args[1],0)&0xFFFFF)<<12)))
            elif op in ('addi','andi','ori','xori','slti','sltiu','slli','srli','srai'):
                rd=parse_reg(args[0]); rs=parse_reg(args[1]); imm=int(args[2],0)
                a=R(rs)
                if op=='addi': setR(rd, s32(a)+imm)
                elif op=='andi': setR(rd, a & (imm&M32))
                elif op=='ori': setR(rd, a | (imm&M32))
                elif op=='xori': setR(rd, a ^ (imm&M32))
                elif op=='slti': setR(rd, 1 if s32(a)<imm else 0)
                elif op=='sltiu': setR(rd, 1 if (a&M32)<(imm&M32) else 0)
                elif op=='slli': setR(rd, (a<<(imm&31)))
                elif op=='srli': setR(rd, (a&M32)>>(imm&31))
                elif op=='srai': setR(rd, s32(a)>>(imm&31))
            elif op in ('add','sub','and','or','xor','sll','srl','sra','slt','sltu','mul'):
                rd=parse_reg(args[0]); a=R(parse_reg(args[1])); b=R(parse_reg(args[2]))
                if op=='add': setR(rd,s32(a)+s32(b))
                elif op=='sub': setR(rd,s32(a)-s32(b))
                elif op=='and': setR(rd,a&b)
                elif op=='or': setR(rd,a|b)
                elif op=='xor': setR(rd,a^b)
                elif op=='sll': setR(rd,a<<(b&31))
                elif op=='srl': setR(rd,(a&M32)>>(b&31))
                elif op=='sra': setR(rd,s32(a)>>(b&31))
                elif op=='slt': setR(rd,1 if s32(a)<s32(b) else 0)
                elif op=='sltu': setR(rd,1 if (a&M32)<(b&M32) else 0)
                elif op=='mul': setR(rd,s32(a)*s32(b))
            elif op in ('lw','lh','lhu','lb','lbu'):
                # formato: rd, imm(rs1)
                rd=parse_reg(args[0]); m=re.match(r'(-?\w+)\((\w+)\)', args[1]); 
                imm=int(m.group(1),0); base=R(REG[m.group(2)])
                addr=(s32(base)+imm)&M32; w=s.load(addr)
                if op=='lw': setR(rd,w)
                elif op=='lh': 
                    h=w&0xFFFF; setR(rd, h-0x10000 if h&0x8000 else h)
                elif op=='lhu': setR(rd,w&0xFFFF)
                elif op=='lb':
                    bb=w&0xFF; setR(rd, bb-0x100 if bb&0x80 else bb)
                elif op=='lbu': setR(rd,w&0xFF)
            elif op in ('sw','sh','sb'):
                rs2=parse_reg(args[0]); m=re.match(r'(-?\w+)\((\w+)\)', args[1])
                imm=int(m.group(1),0); base=R(REG[m.group(2)])
                addr=(s32(base)+imm)&M32
                sz=4 if op=='sw' else (2 if op=='sh' else 1)
                s.store(addr, R(rs2), sz)
            elif op in ('beq','bne','blt','bge','bltu','bgeu'):
                a=R(parse_reg(args[0])); b=R(parse_reg(args[1])); off=labels_off(args[2],labels,s.pc//4)
                take=False
                if op=='beq': take=(a==b)
                elif op=='bne': take=(a!=b)
                elif op=='blt': take=(s32(a)<s32(b))
                elif op=='bge': take=(s32(a)>=s32(b))
                elif op=='bltu': take=((a&M32)<(b&M32))
                elif op=='bgeu': take=((a&M32)>=(b&M32))
                if take: nxt=off*4
            elif op=='jal':
                rd=parse_reg(args[0]); off=labels_off(args[1],labels,s.pc//4)
                setR(rd, s.pc+4); nxt=off*4
            elif op=='jalr':
                rd=parse_reg(args[0]); m=re.match(r'(-?\w+)\((\w+)\)', args[1])
                imm=int(m.group(1),0); base=R(REG[m.group(2)])
                t=(s32(base)+imm)&M32; setR(rd,s.pc+4); nxt=t
            elif op=='ecall':
                s.halt=True
            elif op=='nop':
                pass
            else:
                raise Exception('op no soportado: '+op+' en '+raw)
        except Exception as e:
            print('ERROR ISS pc=%d instr=%s: %s'%(s.pc,raw,e)); sys.exit(1)
        s.pc=nxt
    return s

def labels_off(tok, labels, cur):
    tok=tok.strip()
    if tok in labels: return labels[tok]
    return cur + int(tok,0)  # offset relativo (raro)

if __name__=='__main__':
    src=open(sys.argv[1]).read().splitlines()
    npush=int(sys.argv[2]) if len(sys.argv)>2 else 200
    code,labels=asm(src)
    soc=run(code,labels,npush)
    # volcar DDR esperado ordenado por direccion
    n=soc.dma_l; base=soc.dma_a
    words=[soc.ddr.get((base+4*i)&M32,0) for i in range(n)]
    with open('ddr_esperado.txt','w') as f:
        for w in words: f.write('%08X\n'%w)
    chk=0
    for w in words:
        chk=((((chk<<1)&M32)|(chk>>31))^w)&M32
    open('ddr_chk.txt','w').write('%08X\n'%chk)
    print('DMA_N=%d DDR_BASE=0x%08X CHK=0x%08X'%(n,base,chk))
