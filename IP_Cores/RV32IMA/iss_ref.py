#!/usr/bin/env python3
# ISS minimo RV32IMA para predecir la traza (estado de ENTRADA por instruccion).
# Solo para validar el programa de lockstep antes de correr el emulador real.
import sys
def s32(x): return x-(1<<32) if x&0x80000000 else x
def u32(x): return x & 0xFFFFFFFF

def run(mem_words, max_steps=200):
    RAM = {}  # dir byte -> valor (palabras alineadas)
    for i,w in enumerate(mem_words):
        RAM[0x80000000 + i*4] = w
    def load(a):
        return RAM.get(a & ~3, 0)
    def store(a, v):
        RAM[a & ~3] = u32(v)
    x = [0]*32
    pc = 0x80000000
    res_valid = False  # reserva lr/sc
    res_addr = 0
    uart_out = []      # bytes emitidos por el UART
    # CSRs M-mode (subconjunto del modulo rv32_csr_trap)
    csr = {0x300:0, 0x304:0, 0x305:0, 0x340:0, 0x341:0, 0x342:0, 0x343:0}
    mst_mie, mst_mpie = 0, 0
    trace = []
    for step in range(max_steps):
        instr = load(pc)
        trace.append((pc, instr, x[:]))  # estado de ENTRADA
        op = instr & 0x7F
        rd = (instr>>7)&0x1F; f3=(instr>>12)&7; rs1=(instr>>15)&0x1F
        rs2=(instr>>20)&0x1F; f7=(instr>>25)&0x7F
        npc = u32(pc+4)
        def wr(r,v):
            if r!=0: x[r]=u32(v)
        if op==0x13:  # OP-IMM
            imm=s32(((instr>>20)|(0xFFFFF000 if instr&0x80000000 else 0)))
            a=x[rs1]
            if f3==0: wr(rd,a+imm)
            elif f3==7: wr(rd,a&u32(imm))
            elif f3==6: wr(rd,a|u32(imm))
            elif f3==4: wr(rd,a^u32(imm))
            elif f3==2: wr(rd,1 if s32(a)<imm else 0)
            elif f3==3: wr(rd,1 if a<u32(imm) else 0)
            elif f3==1: wr(rd,u32(a<<(imm&0x1F)))
            elif f3==5:
                sh=imm&0x1F
                wr(rd, u32(s32(a)>>sh) if (f7&0x20) else a>>sh)
        elif op==0x33:  # OP
            a=x[rs1]; b=x[rs2]
            if f7==1:  # M
                if f3==0: wr(rd,u32(a*b))
                elif f3==4:  # DIV signed, trunca hacia cero
                    if b==0: wr(rd,0xFFFFFFFF)
                    elif s32(a)==-2**31 and s32(b)==-1: wr(rd,u32(-2**31))
                    else: wr(rd,u32(int(s32(a)/s32(b))))
                elif f3==5: wr(rd, u32(a//b) if b else 0xFFFFFFFF)
                elif f3==6:  # REM signed, trunca hacia cero
                    if b==0: wr(rd,a)
                    elif s32(a)==-2**31 and s32(b)==-1: wr(rd,0)
                    else: wr(rd,u32(int(s32(a)-int(s32(a)/s32(b))*s32(b))))
                elif f3==7: wr(rd, u32(a-(a//b)*b) if b else a)
                elif f3==1: wr(rd,u32((s32(a)*s32(b))>>32))  # mulh
                else: wr(rd,0)
            else:
                if f3==0: wr(rd, u32(a-b) if (f7&0x20) else u32(a+b))
                elif f3==7: wr(rd,a&b)
                elif f3==6: wr(rd,a|b)
                elif f3==4: wr(rd,a^b)
                elif f3==1: wr(rd,u32(a<<(b&0x1F)))
                elif f3==2: wr(rd,1 if s32(a)<s32(b) else 0)
                elif f3==3: wr(rd,1 if a<b else 0)
                elif f3==5: wr(rd, u32(s32(a)>>(b&0x1F)) if (f7&0x20) else a>>(b&0x1F))
        elif op==0x37: wr(rd, u32(instr&0xFFFFF000))  # LUI
        elif op==0x17: wr(rd, u32(pc+(instr&0xFFFFF000)))  # AUIPC
        elif op==0x63:  # BRANCH
            imm=((instr>>31)<<12)|(((instr>>7)&1)<<11)|(((instr>>25)&0x3F)<<5)|(((instr>>8)&0xF)<<1)
            if imm&0x1000: imm-=0x2000
            a=x[rs1]; b=x[rs2]; take=False
            if f3==0: take=(a==b)
            elif f3==1: take=(a!=b)
            elif f3==4: take=(s32(a)<s32(b))
            elif f3==5: take=(s32(a)>=s32(b))
            elif f3==6: take=(a<b)
            elif f3==7: take=(a>=b)
            npc=u32(pc+imm) if take else npc
        elif op==0x03:  # LOAD
            imm=s32((instr>>20)|(0xFFFFF000 if instr&0x80000000 else 0))
            a=u32(x[rs1]+imm)
            if (a & ~3)==0x10000004:  # palabra que contiene el LSR (byte 5)
                v=0x60 << 8            # LSR en el lane 1 (byte 0x...05)
            elif a==0x10000000:    # RBR sin dato disponible
                v=0
            elif (a>>16)==0x1110:  # syscon: lecturas devuelven 0
                v=0
            else:
                v=load(a)
            vb=(v>>((a&3)*8))&0xFF          # byte alineado
            vh=(v>>((a&2)*8))&0xFFFF        # half alineado
            if f3==2: wr(rd,v)
            elif f3==0: wr(rd,u32(s32(vb<<24)>>24))   # LB
            elif f3==1: wr(rd,u32(s32(vh<<16)>>16))   # LH
            elif f3==4: wr(rd,vb)                       # LBU
            elif f3==5: wr(rd,vh)                       # LHU
        elif op==0x23:  # STORE
            imm=((instr>>25)<<5)|((instr>>7)&0x1F)
            if imm&0x800: imm-=0x1000
            a=u32(x[rs1]+imm)
            if a==0x10000000:  # UART THR: emitir caracter
                uart_out.append(x[rs2] & 0xFF)
            elif a==0x11100000:  # syscon
                if x[rs2]==0x5555: break  # POWEROFF
            else:
                res_valid = False  # P3: store normal rompe la reserva lr/sc
                if f3==2: store(a,x[rs2])
                elif f3==0:  # SB: byte en el lane a&3
                    sh_n=(a&3)*8; m=0xFF<<sh_n
                    store(a,(load(a)&u32(~m))|((x[rs2]&0xFF)<<sh_n))
                elif f3==1:  # SH: half en el lane (a&2)
                    sh_n=(a&2)*8; m=0xFFFF<<sh_n
                    store(a,(load(a)&u32(~m))|((x[rs2]&0xFFFF)<<sh_n))
        elif op==0x2F:  # AMO
            f5=(instr>>27)&0x1F; a=u32(x[rs1]); v=load(a); res=v
            if f5==0x02:  # lr.w: arma la reserva
                wr(rd,v); res_valid=True; res_addr=a
            elif f5==0x03:  # sc.w: exito solo si la reserva es valida y coincide
                if res_valid and res_addr==a:
                    wr(rd,0); store(a,x[rs2])
                else:
                    wr(rd,1)  # fallo: no escribe
                res_valid=False
            elif f5==0x00: wr(rd,v); store(a,u32(v+x[rs2]))  # amoadd
            elif f5==0x01: wr(rd,v); store(a,x[rs2])  # amoswap
            elif f5==0x04: wr(rd,v); store(a,v^x[rs2])  # amoxor
            elif f5==0x08: wr(rd,v); store(a,v|x[rs2])  # amoor
            elif f5==0x0C: wr(rd,v); store(a,v&x[rs2])  # amoand
            elif f5==0x10: wr(rd,v); store(a,u32(min(s32(v),s32(x[rs2]))))  # amomin
            elif f5==0x14: wr(rd,v); store(a,u32(max(s32(v),s32(x[rs2]))))  # amomax
            elif f5==0x18: wr(rd,v); store(a,min(v,x[rs2]))  # amominu
            elif f5==0x1C: wr(rd,v); store(a,max(v,x[rs2]))  # amomaxu
        elif op==0x6F:  # JAL
            imm=((instr>>31)<<20)|(((instr>>12)&0xFF)<<12)|(((instr>>20)&1)<<11)|(((instr>>21)&0x3FF)<<1)
            if imm&0x100000: imm-=0x200000
            wr(rd,npc); npc=u32(pc+imm)
        elif op==0x67:  # JALR
            imm=s32((instr>>20)|(0xFFFFF000 if instr&0x80000000 else 0))
            t=npc; npc=u32((x[rs1]+imm)&~1); wr(rd,t)
        elif op==0x73:  # SYSTEM: ecall/ebreak/mret y CSR
            f12=(instr>>20)&0xFFF
            if f3==0:
                if f12==0x000:      # ECALL -> trap cause 11
                    csr[0x341]=pc          # mepc
                    csr[0x342]=11          # mcause
                    csr[0x343]=0           # mtval
                    mst_mpie=mst_mie; mst_mie=0
                    npc=csr[0x305]&0xFFFFFFFC   # mtvec (direct)
                elif f12==0x001:    # EBREAK -> trap cause 3
                    csr[0x341]=pc; csr[0x342]=3; csr[0x343]=0
                    mst_mpie=mst_mie; mst_mie=0
                    npc=csr[0x305]&0xFFFFFFFC
                elif f12==0x302:    # MRET
                    mst_mie=mst_mpie; mst_mpie=1
                    npc=csr[0x341]&0xFFFFFFFE   # mepc
                # otros (wfi, etc): nop
            else:
                addr_csr=f12
                # valor fuente: registro o inmediato
                srcv = ((instr>>15)&0x1F) if (f3&4) else x[rs1]
                # lectura del CSR
                if addr_csr==0x300:
                    old=(mst_mpie<<7)|(mst_mie<<3)|(3<<11)  # MPP=11
                elif addr_csr in csr:
                    old=csr[addr_csr]
                else:
                    old=0
                # escritura segun funct3
                wr = True if (f3&3)==1 else (srcv!=0)
                if wr:
                    if (f3&3)==1:   new=srcv                 # csrrw/wi
                    elif (f3&3)==2: new=old|srcv             # csrrs/si
                    else:           new=old&u32(~srcv)       # csrrc/ci
                    if addr_csr==0x300:
                        mst_mpie=(new>>7)&1; mst_mie=(new>>3)&1
                    elif addr_csr in csr:
                        csr[addr_csr]=u32(new)
                wr_rd=rd
                if wr_rd!=0: x[wr_rd]=u32(old)
        else:
            break  # instruccion no manejada -> parar
        pc=npc
    return trace, RAM, uart_out

if __name__=="__main__":
    words=[int(l.strip(),16) for l in open(sys.argv[1]) if l.strip()]
    trace,RAM,uart=run(words)
    print(f"# {len(trace)} pasos ejecutados")
    for pc,instr,regs in trace:
        print(f"PC={pc:08x} I={instr:08x} "+" ".join(f"x{i}={regs[i]:08x}" for i in [1,2,3,5,6,22,24,26,28,30]))
    if uart:
        print("# Salida UART: " + repr("".join(chr(c) for c in uart)))
    print("# Memoria final relevante:")
    for a in [0x80000200,0x80000210,0x80000220]:
        print(f"  [{a:08x}] = {RAM.get(a,0):08x}")
