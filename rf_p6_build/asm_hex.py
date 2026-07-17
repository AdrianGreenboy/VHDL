#!/usr/bin/env python3
# asm_hex.py - Ensambla fw_poll.s a hex de 32 bits (una instr/linea) para el imem
# del core RTL. Reusa el ensamblador de iss.py pero EMITE la codificacion binaria
# RV32 real, de modo que el core RTL ejecute exactamente lo mismo que el ISS.
import sys, re
from iss import asm, REG, labels_off

def enc_r(f7,rs2,rs1,f3,rd,op): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def enc_i(imm,rs1,f3,rd,op):
    imm&=0xFFF
    return (imm<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def enc_s(imm,rs2,rs1,f3,op):
    imm&=0xFFF
    return ((imm>>5)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|op
def enc_b(imm,rs2,rs1,f3,op):
    imm&=0x1FFF
    b12=(imm>>12)&1; b11=(imm>>11)&1; b10_5=(imm>>5)&0x3F; b4_1=(imm>>1)&0xF
    return (b12<<31)|(b10_5<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(b4_1<<8)|(b11<<7)|op
def enc_u(imm,rd,op): return ((imm&0xFFFFF)<<12)|(rd<<7)|op
def enc_j(imm,rd,op):
    imm&=0x1FFFFF
    b20=(imm>>20)&1; b10_1=(imm>>1)&0x3FF; b11=(imm>>11)&1; b19_12=(imm>>12)&0xFF
    return (b20<<31)|(b10_1<<21)|(b11<<20)|(b19_12<<12)|(rd<<7)|op

def rr(t): return REG[t.strip().rstrip(',')]
def imm(t): return int(t,0)

def encode(op,args,idx,labels):
    if op=='lui': return enc_u(imm(args[1]),rr(args[0]),0x37)
    if op=='auipc': return enc_u(imm(args[1]),rr(args[0]),0x17)
    if op=='addi': return enc_i(imm(args[2]),rr(args[1]),0x0,rr(args[0]),0x13)
    if op=='andi': return enc_i(imm(args[2]),rr(args[1]),0x7,rr(args[0]),0x13)
    if op=='ori':  return enc_i(imm(args[2]),rr(args[1]),0x6,rr(args[0]),0x13)
    if op=='xori': return enc_i(imm(args[2]),rr(args[1]),0x4,rr(args[0]),0x13)
    if op=='slti': return enc_i(imm(args[2]),rr(args[1]),0x2,rr(args[0]),0x13)
    if op=='sltiu':return enc_i(imm(args[2]),rr(args[1]),0x3,rr(args[0]),0x13)
    if op=='slli': return enc_i(imm(args[2])&0x1F,rr(args[1]),0x1,rr(args[0]),0x13)
    if op=='srli': return enc_i(imm(args[2])&0x1F,rr(args[1]),0x5,rr(args[0]),0x13)
    if op=='srai': return enc_i((imm(args[2])&0x1F)|0x400,rr(args[1]),0x5,rr(args[0]),0x13)
    if op=='add': return enc_r(0,rr(args[2]),rr(args[1]),0x0,rr(args[0]),0x33)
    if op=='sub': return enc_r(0x20,rr(args[2]),rr(args[1]),0x0,rr(args[0]),0x33)
    if op=='and': return enc_r(0,rr(args[2]),rr(args[1]),0x7,rr(args[0]),0x33)
    if op=='or':  return enc_r(0,rr(args[2]),rr(args[1]),0x6,rr(args[0]),0x33)
    if op=='xor': return enc_r(0,rr(args[2]),rr(args[1]),0x4,rr(args[0]),0x33)
    if op=='sll': return enc_r(0,rr(args[2]),rr(args[1]),0x1,rr(args[0]),0x33)
    if op=='srl': return enc_r(0,rr(args[2]),rr(args[1]),0x5,rr(args[0]),0x33)
    if op=='sra': return enc_r(0x20,rr(args[2]),rr(args[1]),0x5,rr(args[0]),0x33)
    if op=='slt': return enc_r(0,rr(args[2]),rr(args[1]),0x2,rr(args[0]),0x33)
    if op=='sltu':return enc_r(0,rr(args[2]),rr(args[1]),0x3,rr(args[0]),0x33)
    if op=='mul': return enc_r(0x01,rr(args[2]),rr(args[1]),0x0,rr(args[0]),0x33)
    if op in ('lw','lh','lhu','lb','lbu'):
        m=re.match(r'(-?\w+)\((\w+)\)',args[1]); im=int(m.group(1),0); rs1=REG[m.group(2)]
        f3={'lb':0,'lh':1,'lw':2,'lbu':4,'lhu':5}[op]
        return enc_i(im,rs1,f3,rr(args[0]),0x03)
    if op in ('sw','sh','sb'):
        m=re.match(r'(-?\w+)\((\w+)\)',args[1]); im=int(m.group(1),0); rs1=REG[m.group(2)]
        f3={'sb':0,'sh':1,'sw':2}[op]
        return enc_s(im,rr(args[0]),rs1,f3,0x23)
    if op in ('beq','bne','blt','bge','bltu','bgeu'):
        tgt=labels[args[2]] if args[2] in labels else idx+int(args[2],0)
        off=(tgt-idx)*4
        f3={'beq':0,'bne':1,'blt':4,'bge':5,'bltu':6,'bgeu':7}[op]
        return enc_b(off,rr(args[1]),rr(args[0]),f3,0x63)
    if op=='jal':
        tgt=labels[args[1]] if args[1] in labels else idx+int(args[1],0)
        off=(tgt-idx)*4; return enc_j(off,rr(args[0]),0x6F)
    if op=='jalr':
        m=re.match(r'(-?\w+)\((\w+)\)',args[1]); im=int(m.group(1),0); rs1=REG[m.group(2)]
        return enc_i(im,rs1,0x0,rr(args[0]),0x67)
    if op=='ecall': return 0x00000073
    if op=='nop': return 0x00000013
    raise Exception('encode: op no soportado '+op)

if __name__=='__main__':
    src=open(sys.argv[1]).read().splitlines()
    code,labels=asm(src)
    out=[]
    for (op,args,idx,raw) in code:
        w=encode(op,args,idx,labels)
        out.append('%08X'%(w&0xFFFFFFFF))
    open('imem.hex','w').write('\n'.join(out)+'\n')
    print('IMEM %d instrucciones'%len(out))
