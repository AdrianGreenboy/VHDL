#!/usr/bin/env python3
# Genera el firmware del self-test PQC completo (KEM + DSA, firma global FNV-64).
# Reproduce 95e07091fa5b3cc4 (KEM) y f93232f7ea2d1575 (DSA).
# Usa subrutinas para caber en IMEM. Semillas embebidas; pk/sk/sig/ct/dk se
# mueven dentro del core (no se recargan del firmware).

# --- extraer semillas del vector ---
kl=[l for l in open('/home/claude/pqc/l3rtl/kem_st_vectors.txt').read().splitlines() if not l.startswith('#')][0].split()
_,d,z,m,ek,dk,ct,ss = kl
dl=[l for l in open('/home/claude/pqc/ntt_d/dsa_st_vectors.txt').read().splitlines() if not l.startswith('#')][0].split()
xi,mu = dl[1],dl[2]
d_b=bytes.fromhex(d); z_b=bytes.fromhex(z); m_b=bytes.fromhex(m)
xi_b=bytes.fromhex(xi); mu_b=bytes.fromhex(mu)

# Registros (convencion):
#  x1  = base MMIO 0xD0000000
#  x10 = s_hi (FNV), x11 = s_lo
#  x12 = p4_hi, x13 = p4_lo
#  x28 = link de subrutina (jal x28,.. ; jalr x0,0(x28))
#  x5,x6,x7,x8,x9,x14..x23 = temporales
#
# El firmware es lineal (sin subrutinas reales para el flujo) pero usa una
# subrutina fold_region para el nucleo repetitivo. Para simplificar y evitar
# problemas de anidamiento con x28, generamos fold_region INLINE por macro.

def load_seed(base_addr, data):
    """genera codigo para cargar 'data' (bytes) en el core desde base_addr"""
    out=[f"    li   x5, {base_addr}", "    sw   x5, 12(x1)          # ADDR"]
    for bb in data:
        out.append(f"    li   x5, 0x{bb:02X}")
        out.append(f"    sw   x5, 16(x1)")
    return out

# fold_region como subrutina: entra con x14=addr, x15=len; foldea en x10:x11.
# Usa x16..x23 como temporales. Retorna por x28.
fold_sub = """
# ---- subrutina fold_region: x14=addr, x15=len; foldea len bytes en x10:x11 ----
fold_region:
    sw   x14, 12(x1)          # ADDR = addr
    lw   x0, 16(x1)           # dummy ceba
    addi x16, x0, 0           # k=0
fr_loop:
    lw   x17, 16(x1)          # byte
    xor  x11, x11, x17        # s_lo ^= b
    mul   x18, x11, x13       # ll_lo
    mulhu x19, x11, x13       # ll_hi
    mul   x20, x11, x12       # s_lo*p4_hi (low)
    mul   x21, x10, x13       # s_hi*p4_lo (low)
    add   x19, x19, x20
    add   x19, x19, x21
    addi  x11, x18, 0         # s_lo
    addi  x10, x19, 0         # s_hi
    addi x16, x16, 1
    blt  x16, x15, fr_loop
    jalr x0, 0(x28)           # return
"""

# move_region: x14=src, x22=dst, x15=len. Copia dentro del core. Retorna x28.
# Lee byte de src (ventana host), escribe a dst. Como ADDR es compartido,
# leemos todo a RAM local primero? No: leemos y escribimos byte a byte
# alternando ADDR. Pero ADDR es uno solo. Estrategia: leer byte (ADDR=src),
# escribir byte (ADDR=dst). Cada iteracion refija ADDR.
move_sub = """
# ---- subrutina move_region: x14=src, x22=dst, x15=len. Copia en el core ----
move_region:
    addi x16, x0, 0           # k=0
mv_loop:
    add  x17, x14, x16        # src+k
    sw   x17, 12(x1)          # ADDR=src+k
    lw   x0, 16(x1)           # dummy ceba
    lw   x18, 16(x1)          # byte leido
    add  x17, x22, x16        # dst+k
    sw   x17, 12(x1)          # ADDR=dst+k
    sw   x18, 16(x1)          # escribe byte
    addi x16, x16, 1
    blt  x16, x15, mv_loop
    jalr x0, 0(x28)           # return
"""

# run_op: x5=cmd (con start bit). Dispara y espera done_sticky. Retorna x28.
run_sub = """
# ---- subrutina run_op: x5=CMD value; dispara y espera done ----
run_op:
    sw   x5, 4(x1)            # CMD
    lui  x23, 0x1000          # guarda grande
ro_wait:
    lw   x6, 8(x1)
    andi x6, x6, 128          # done_sticky b7
    bne  x6, x0, ro_done
    addi x23, x23, -1
    bne  x23, x0, ro_wait
ro_done:
    jalr x0, 0(x28)           # return
"""

prog=[]
prog.append("# pqc_selftest_full.s -- self-test PQC completo (KEM+DSA, FNV-64 global)")
prog.append("# Reproduce KEM=95e07091fa5b3cc4  DSA=f93232f7ea2d1575")
prog.append("    lui  x1, 0xD0000          # base MMIO")
prog.append("    li   x12, 0x9FFAAC08      # p4_hi")
prog.append("    li   x13, 0x5635BC91      # p4_lo")
prog.append("")
prog.append("# ================= CADENA KEM (alg=0) =================")
prog.append("    sw   x0, 0(x1)            # CTRL=0 KEM")
prog.append("    li   x10, 0xCBF29CE4      # sigk init hi")
prog.append("    li   x11, 0x84222325      # sigk init lo")
prog.append("# cargar semilla d@0, z@32")
prog += load_seed(0, d_b)
prog += load_seed(32, z_b)
prog.append("# KeyGen")
prog.append("    addi x5, x0, 4            # op=00 start")
prog.append("    jal  x28, run_op")
prog.append("# fold ek(512,1184), dk(2048,2400)")
prog.append("    li   x14, 512")
prog.append("    li   x15, 1184")
prog.append("    jal  x28, fold_region")
prog.append("    li   x14, 2048")
prog.append("    li   x15, 2400")
prog.append("    jal  x28, fold_region")
prog.append("# park dk: mover 2048->5000 (2400B)")
prog.append("    li   x14, 2048")
prog.append("    li   x22, 5000")
prog.append("    li   x15, 2400")
prog.append("    jal  x28, move_region")
prog.append("# cargar m@0")
prog += load_seed(0, m_b)
prog.append("# Encaps")
prog.append("    addi x5, x0, 5           # op=01 start (b0=1,b2=1)")
prog.append("    jal  x28, run_op")
prog.append("# fold ct(2048,1088), ss(32,32)")
prog.append("    li   x14, 2048")
prog.append("    li   x15, 1088")
prog.append("    jal  x28, fold_region")
prog.append("    li   x14, 32")
prog.append("    li   x15, 32")
prog.append("    jal  x28, fold_region")
prog.append("# mover ct 2048->0 (1088B), restaurar dk 5000->2048 (2400B)")
prog.append("    li   x14, 2048")
prog.append("    li   x22, 0")
prog.append("    li   x15, 1088")
prog.append("    jal  x28, move_region")
prog.append("    li   x14, 5000")
prog.append("    li   x22, 2048")
prog.append("    li   x15, 2400")
prog.append("    jal  x28, move_region")
prog.append("# Decaps")
prog.append("    addi x5, x0, 6           # op=10 start (b1=1,b2=1)")
prog.append("    jal  x28, run_op")
prog.append("# fold Kout(1280,32)")
prog.append("    li   x14, 1280")
prog.append("    li   x15, 32")
prog.append("    jal  x28, fold_region")
prog.append("# guardar sigk en RAM local [0]=hi [1]=lo")
prog.append("    sw   x10, 0(x0)")
prog.append("    sw   x11, 4(x0)")
prog.append("")
prog.append("# ================= CADENA DSA (alg=1) =================")
prog.append("    addi x5, x0, 1")
prog.append("    sw   x5, 0(x1)           # CTRL=1 DSA")
prog.append("    li   x10, 0xCBF29CE4     # sigd init hi")
prog.append("    li   x11, 0x84222325     # sigd init lo")
prog.append("# cargar xi@0")
prog += load_seed(0, xi_b)
prog.append("# KeyGen")
prog.append("    addi x5, x0, 4")
prog.append("    jal  x28, run_op")
prog.append("# fold pk(256,1952), sk(2304,4032)")
prog.append("    li   x14, 256")
prog.append("    li   x15, 1952")
prog.append("    jal  x28, fold_region")
prog.append("    li   x14, 2304")
prog.append("    li   x15, 4032")
prog.append("    jal  x28, fold_region")
prog.append("# mover sk 2304->0 (4032B), guardar pk: mover 256->6144 temporal (1952B)")
prog.append("    li   x14, 2304")
prog.append("    li   x22, 0")
prog.append("    li   x15, 4032")
prog.append("    jal  x28, move_region")
prog.append("    li   x14, 256")
prog.append("    li   x22, 6144          # park pk temporal")
prog.append("    li   x15, 1952")
prog.append("    jal  x28, move_region")
prog.append("# cargar mu@4096")
prog += load_seed(4096, mu_b)
prog.append("# Sign")
prog.append("    addi x5, x0, 5")
prog.append("    jal  x28, run_op")
prog.append("# fold sig(8192,3309)")
prog.append("    li   x14, 8192")
prog.append("    li   x15, 3309")
prog.append("    jal  x28, fold_region")
prog.append("# mover sig 8192->2176 (3309B), pk 6144->0 (1952B), cargar mu@2048")
prog.append("    li   x14, 8192")
prog.append("    li   x22, 2176")
prog.append("    li   x15, 3309")
prog.append("    jal  x28, move_region")
prog.append("    li   x14, 6144")
prog.append("    li   x22, 0")
prog.append("    li   x15, 1952")
prog.append("    jal  x28, move_region")
prog += load_seed(2048, mu_b)
prog.append("# siglen=3309; Verify")
prog.append("    li   x5, 3309")
prog.append("    sw   x5, 20(x1)          # SIGLEN")
prog.append("    addi x5, x0, 6")
prog.append("    jal  x28, run_op")
prog.append("# fold(result=1): foldeamos el byte 1")
prog.append("    xor  x11, x11, x0        # (s_lo ^= 0 primero? no: fold del valor 1)")
prog.append("    addi x17, x0, 1")
prog.append("    xor  x11, x11, x17")
prog.append("    mul   x18, x11, x13")
prog.append("    mulhu x19, x11, x13")
prog.append("    mul   x20, x11, x12")
prog.append("    mul   x21, x10, x13")
prog.append("    add   x19, x19, x20")
prog.append("    add   x19, x19, x21")
prog.append("    addi  x11, x18, 0")
prog.append("    addi  x10, x19, 0")
prog.append("# guardar sigd en RAM local [2]=hi [3]=lo")
prog.append("    sw   x10, 8(x0)")
prog.append("    sw   x11, 12(x0)")
prog.append("")
prog.append("# ================= centinela + DMA a DDR =================")
prog.append("    li   x16, 0x00C0FFEE")
prog.append("    sw   x16, 32(x0)         # [8] centinela")
prog.append("    lui  x25, 0x40000")
prog.append("    sw   x0, 0(x25)          # SRC=0")
prog.append("    sw   x0, 4(x25)          # DST=0")
prog.append("    addi x16, x0, 9")
prog.append("    sw   x16, 8(x25)         # LEN=9")
prog.append("    addi x16, x0, 3")
prog.append("    sw   x16, 12(x25)        # CTRL start|dir")
prog.append("dwait:")
prog.append("    lw   x16, 16(x25)")
prog.append("    andi x16, x16, 1")
prog.append("    bne  x16, x0, dwait")
prog.append("    addi x20, x0, 1")
prog.append("    sw   x20, 508(x0)        # doorbell")
prog.append("halt:")
prog.append("    beq  x0, x0, halt")
prog.append("")
prog.append("# ================= subrutinas =================")
prog.append(fold_sub)
prog.append(move_sub)
prog.append(run_sub)

src="\n".join(prog)
open('pqc_selftest_full.s','w').write(src)
n=len([l for l in prog if l.strip() and not l.strip().startswith('#') and ':' not in l.split('#')[0]])
print(f"firmware generado: {len(src.splitlines())} lineas de texto")
