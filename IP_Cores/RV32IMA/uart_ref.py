#!/usr/bin/env python3
# Tabla de referencia: bytes de UART que el ISS ha emitido tras N retiros.
# Sirve para localizar por biseccion donde el core VHDL se separa del ISS,
# sin generar trazas de GB (la UART es un testigo barato del avance real).
import sys, struct, importlib
import iss_ref
importlib.reload(iss_ref)
RAM_SIZE=64*1024*1024; STATE_SZ=48*4
img=open('kernel.img','rb').read(); dtb=open('hercossnux.dtb','rb').read()
dtb_off=RAM_SIZE-len(dtb)-STATE_SZ
if dtb[0x13c:0x140]==bytes.fromhex('03ffc000'):
    dtb=dtb[:0x13c]+struct.pack('>I',dtb_off)+dtb[0x140:]
def fresh_ram():
    # IMPORTANTE: iss_ref.run muta init_ram en sitio; cada corrida necesita
    # una copia limpia o arranca con la RAM que dejo la anterior
    RAM={}
    for blob,base in ((img,0),(dtb,dtb_off)):
        for off in range(0,len(blob),4):
            w=blob[off:off+4]
            if len(w)<4: w=w+b'\x00'*(4-len(w))
            RAM[0x80000000+base+off]=struct.unpack('<I',w)[0]
    return RAM
for arg in sys.argv[1:]:
    N=int(arg)
    # trace_from justo por debajo de N: registra UART completa sin guardar traza
    tr,R,u,c = iss_ref.run([], max_steps=N,
        init_regs={5:0x80000000,10:0,11:0x80000000+dtb_off}, init_ram=fresh_ram(),
        trace_from=N-2)
    print(f"{N} {len(u)}")
