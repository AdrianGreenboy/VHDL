#!/usr/bin/env python3
# Interprete RV32IM minimo para validar eth_bringup.mem contra el ISS.
# Modela el eth_mmio en LOOP_INT (0xD0000000) y la RAM local (0x0).
# NO es ciclo a ciclo; ejecuta las instrucciones y modela el MAC funcional.
import sys

def crc_ok(data):  # el MAC en LOOP_INT sin corrupciones: FCS siempre valido
    return True

class Mac:
    def __init__(self):
        self.mac = [0x02,0xAA,0xBB,0xCC,0xDD,0xEE]
        self.promisc = False
        self.txbuf = []
        self.rxfifo = []   # (byte, eof)
        self.ok=self.crc=self.runt=self.drop=0
    def tx(self, b, eof):
        self.txbuf.append(b & 0xFF)
        if eof:
            self._loop(); self.txbuf=[]
    def _loop(self):
        data = self.txbuf[:]
        if len(data)<60: data += [0]*(60-len(data))
        if len(data)+4 < 64: self.runt=1; return
        dst=data[0:6]
        if not (self.promisc or dst==self.mac or dst==[0xFF]*6):
            self.drop=1; return
        for i,b in enumerate(data):
            self.rxfifo.append((b, 1 if i==len(data)-1 else 0))
        self.ok=1
    def rxd(self):
        if not self.rxfifo: return 0
        b,eof=self.rxfifo.pop(0)
        return (1<<31)|(eof<<8)|b
    def stat(self):
        return (self.ok<<16)|(self.runt<<18)|(self.drop<<19)
    def clear(self):
        self.ok=self.crc=self.runt=self.drop=0

class CPU:
    def __init__(self, mem):
        self.imem=mem
        self.r=[0]*32
        self.pc=0
        self.ram={}       # RAM local (byte addr palabra alineada)
        self.mac=Mac()
        self.maclo=0; self.machi=0
    def ld(self,a):
        a&=0xFFFFFFFF
        if 0xD0000000<=a<0xE0000000:
            off=a&0xFF
            if off==0x10: return self.mac.stat()
            if off==0x18: return self.mac.rxd()
            return 0
        return self.ram.get(a&~3,0)
    def st(self,a,v):
        a&=0xFFFFFFFF; v&=0xFFFFFFFF
        if 0xD0000000<=a<0xE0000000:
            off=a&0xFF
            if off==0x00:
                self.mac.promisc=bool(v&4)
                if not (v&1): self.mac=Mac()  # EN=0 reset (no usado aqui)
            elif off==0x04: self.maclo=v; self.mac.mac=[v&0xFF,(v>>8)&0xFF,(v>>16)&0xFF,(v>>24)&0xFF]+self.mac.mac[4:]
            elif off==0x08: self.machi=v; self.mac.mac=self.mac.mac[0:4]+[v&0xFF,(v>>8)&0xFF]
            elif off==0x14: self.mac.tx(v&0xFF,(v>>8)&1)
            elif off==0x10: self.mac.clear()   # cualquier escritura limpia stickies
            return
        self.ram[a&~3]=v
    def run(self,maxsteps=5000000):
        for _ in range(maxsteps):
            instr=self.imem[self.pc//4] if self.pc//4<len(self.imem) else 0
            if not self.step(instr): return
        raise RuntimeError("timeout de ejecucion")
    def step(self,ins):
        r=self.r; pc=self.pc
        op=ins&0x7f
        rd=(ins>>7)&0x1f; f3=(ins>>12)&7; rs1=(ins>>15)&0x1f; rs2=(ins>>20)&0x1f; f7=(ins>>25)&0x7f
        def s(x): return x-0x100000000 if x&0x80000000 else x
        npc=pc+4
        if op==0x33:  # R
            a=r[rs1]&0xFFFFFFFF; b=r[rs2]&0xFFFFFFFF
            if f7==1:  # M ext
                if f3==0: v=(s(a)*s(b))&0xFFFFFFFF
                elif f3==4: v=(abs(s(a))//abs(s(b))*(1 if (s(a)<0)==(s(b)<0) else -1))&0xFFFFFFFF if b else 0xFFFFFFFF
                elif f3==5: v=(a//b)&0xFFFFFFFF if b else 0xFFFFFFFF
                elif f3==6: v=(abs(s(a))%abs(s(b))*(1 if s(a)>=0 else -1))&0xFFFFFFFF if b else a
                elif f3==7: v=(a%b)&0xFFFFFFFF if b else a
                else: v=0
            else:
                if f3==0: v=(a-b if f7==0x20 else a+b)&0xFFFFFFFF
                elif f3==1: v=(a<<(b&31))&0xFFFFFFFF
                elif f3==4: v=(a^b)&0xFFFFFFFF
                elif f3==5: v=(a>>(b&31)) if f7==0 else ((s(a)>>(b&31))&0xFFFFFFFF)
                elif f3==6: v=(a|b)&0xFFFFFFFF
                elif f3==7: v=(a&b)&0xFFFFFFFF
                else: v=0
            if rd: r[rd]=v
        elif op==0x13:  # I
            imm=s(((ins>>20)&0xFFF)|(0xFFFFF000 if ins&0x80000000 else 0))
            a=r[rs1]&0xFFFFFFFF
            if f3==0: v=(a+imm)&0xFFFFFFFF
            elif f3==1: v=(a<<(imm&31))&0xFFFFFFFF
            elif f3==4: v=(a^(imm&0xFFFFFFFF))&0xFFFFFFFF
            elif f3==5: v=(a>>(imm&31)) if f7==0 else ((s(a)>>(imm&31))&0xFFFFFFFF)
            elif f3==6: v=(a|(imm&0xFFFFFFFF))&0xFFFFFFFF
            elif f3==7: v=(a&(imm&0xFFFFFFFF))&0xFFFFFFFF
            else: v=0
            if rd: r[rd]=v
        elif op==0x03:  # lw
            imm=s(((ins>>20)&0xFFF)|(0xFFFFF000 if ins&0x80000000 else 0))
            if rd: r[rd]=self.ld(r[rs1]+imm)&0xFFFFFFFF
        elif op==0x23:  # sw
            imm=((ins>>25)<<5)|((ins>>7)&0x1f)
            imm=s(imm|(0xFFFFF000 if imm&0x800 else 0))
            self.st(r[rs1]+imm, r[rs2])
        elif op==0x63:  # B
            imm=(((ins>>31)&1)<<12)|(((ins>>7)&1)<<11)|(((ins>>25)&0x3f)<<5)|(((ins>>8)&0xf)<<1)
            imm=s(imm|(0xFFFFE000 if imm&0x1000 else 0))
            a=r[rs1]&0xFFFFFFFF; b=r[rs2]&0xFFFFFFFF
            take={0:a==b,1:a!=b,4:s(a)<s(b),5:s(a)>=s(b),6:a<b,7:a>=b}[f3]
            if take: npc=pc+imm
        elif op==0x6f:  # jal
            imm=(((ins>>31)&1)<<20)|(((ins>>12)&0xff)<<12)|(((ins>>20)&1)<<11)|(((ins>>21)&0x3ff)<<1)
            imm=s(imm|(0xFFE00000 if imm&0x100000 else 0))
            if rd: r[rd]=pc+4
            npc=pc+imm
        elif op==0x67:  # jalr
            imm=s(((ins>>20)&0xFFF)|(0xFFFFF000 if ins&0x80000000 else 0))
            t=(r[rs1]+imm)&0xFFFFFFFE
            if rd: r[rd]=pc+4
            npc=t
        elif op==0x37:  # lui
            if rd: r[rd]=ins&0xFFFFF000
        elif op==0x17:  # auipc
            if rd: r[rd]=(pc+(ins&0xFFFFF000))&0xFFFFFFFF
        else:
            pass
        r[0]=0
        # deteccion de bucle infinito 'done' (beq x0,x0,done -> npc==pc)
        if npc==pc: return False
        self.pc=npc
        return True

def main():
    words=[int(l,16) for l in open("eth_bringup.mem")]
    cpu=CPU(words)
    cpu.run()
    # firma en RAM local words 0..7
    sig=[cpu.ram.get(i*4,0)&0xFFFFFFFF for i in range(8)]
    print("=== FIRMA del firmware (RAM local) ===")
    for i,w in enumerate(sig): print(f"  sig[{i}] = 0x{w:08X}")
    # comparar con iss_signature.txt
    exp=[int(l,16) for l in open("../sim/iss_signature.txt")]
    ok=True
    for i in range(8):
        if sig[i]!=exp[i]:
            print(f"  MISMATCH sig[{i}]: fw=0x{sig[i]:08X} iss=0x{exp[i]:08X}"); ok=False
    print("FIRMWARE == ISS: OK" if ok else "FIRMWARE != ISS: REVISAR")
    # centinela
    print(f"centinela word127 = 0x{cpu.ram.get(508,0):08X} (esperado 0x00C0FFEE)")
    sys.exit(0 if ok else 1)

main()
