#!/usr/bin/env python3
"""gen_mmu_test.py - genera mmu_test.S (Paso 5, Capa 2 dirigida).

Tablas Sv39 construidas en tiempo de ejecucion por M:
  raiz[2]   gigapagina identidad 0x8000_0000 (RWX AD, S): codigo y datos
  raiz[3]   gigapagina desalineada                       -> page fault
  raiz[1] -> L1 (VA 0x4000_0000):
     L1[0]  megapagina 2 MiB -> PA 0x8020_0000 (RW AD)
     L1[2]  megapagina desalineada                       -> page fault
     L1[1] -> L0 (VA 0x4020_0000 + n*4K), paginas con permisos variados (ver PAGES)
  raiz2 (ASID 2): mismo VA 0x4000_0000 -> otra fisica, para probar ASIDs
Accesos ld/sd/lw/amo/lr/sc/fetch desde S (SUM/MXR 0/1), desde U y desde M con
MPRV. El handler de M salta la instruccion que falla (o vuelve a ra si el
fallo es de fetch). El oraculo es el lockstep: cada causa y tval se compara.
"""
import sys

V, R, W, X, U, G, A, D = 1, 2, 4, 8, 16, 32, 64, 128
# (indice L0, flags, destino) destino: 'data' pagina de datos propia, 'code' stub, 'ucode' codigo U
PAGES = [
    (0, V | R | A, 'data'),                 # solo lectura
    (1, V | R | W | A, 'data'),             # D=0: store -> fallo (Svade)
    (2, V | R | W, 'data'),                 # A=0: todo falla
    (3, V | X | A, 'data'),                 # solo X: load falla salvo MXR
    (4, V | R | W | U | A | D, 'data'),     # pagina U: S necesita SUM
    (5, 0, 'data'),                         # invalida
    (6, V | W | A | D, 'data'),             # W sin R: reservado
    (7, V | R | W | A | D | (1 << 54), 'data'),  # bits reservados
    (8, V | R | X | A, 'code'),             # ejecutable
    (9, V | R | A, 'code'),                 # mismo codigo sin X
    (10, V | R | X | U | A, 'ucode'),       # codigo de U
    (11, V | R | W | A | D, 'data'),        # normal
]
TESTVA = 0x40200000


def acc_block(o, va, tag):
    """Bateria de accesos a una VA (cada uno puede fallar y saltarse)."""
    o.append(f'  # -- {tag} @ {va:#x}')
    o.append(f'  li s2, {va}')
    o += ['  ld a0, 0(s2)', '  lw a0, 8(s2)', '  lbu a0, 3(s2)', '  sd s2, 16(s2)', '  sw s2, 24(s2)',
          '  amoadd.d a0, s2, (s2)', '  lr.d a0, (s2)', '  sc.d a0, s2, (s2)', '  ld a1, 16(s2)']


def main():
    o = []
    o.append("""  .section .text.init
  .globl _start
_start:
  .irp r, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
  li x\\r, 0
  .endr
  la sp, stack_top
  la t0, m_handler
  csrw mtvec, t0
  csrw medeleg, zero
  csrw mideleg, zero
  # ---- tablas (raiz, L1, L0) en paginas alineadas
  la s3, pt_root
  la s4, pt_l1
  la s5, pt_l0
  la s6, pt_root2
  la s7, pt_l1b
  # raiz[2]: gigapagina identidad 0x80000000
  li t0, (0x80000000 >> 12) << 10 | 0xCF
  sd t0, 16(s3)
  sd t0, 16(s6)
  # raiz[3]: gigapagina desalineada (ppn bajo != 0)
  li t0, ((0x80000000 >> 12) + 1) << 10 | 0xCF
  sd t0, 24(s3)
  # raiz[1] -> L1
  srli t0, s4, 12
  slli t0, t0, 10
  ori t0, t0, 1
  sd t0, 8(s3)
  # L1[0]: megapagina -> 0x80200000 RW AD
  li t0, (0x80200000 >> 12) << 10 | 0xC7
  sd t0, 0(s4)
  # L1[2]: megapagina desalineada
  li t0, ((0x80200000 >> 12) + 3) << 10 | 0xC7
  sd t0, 16(s4)
  # L1[1] -> L0
  srli t0, s5, 12
  slli t0, t0, 10
  ori t0, t0, 1
  sd t0, 8(s4)""")
    for idx, fl, dst in PAGES:
        lab = {'data': f'pg_data{idx}', 'code': 'pg_code', 'ucode': 'pg_ucode'}[dst]
        o.append(f"""  la t0, {lab}
  srli t0, t0, 12
  slli t0, t0, 10
  li t1, {fl}
  or t0, t0, t1
  sd t0, {idx * 8}(s5)""")
    o.append("""  # raiz2 (ASID 2): raiz2[1] -> L1b, L1b[0] megapagina -> 0x80400000
  srli t0, s7, 12
  slli t0, t0, 10
  ori t0, t0, 1
  sd t0, 8(s6)
  li t0, (0x80400000 >> 12) << 10 | 0xC7
  sd t0, 0(s7)
  # satp = Sv39, ASID 1, raiz
  srli t0, s3, 12
  li t1, (8 << 60) | (1 << 44)
  or t0, t0, t1
  csrw satp, t0
  sfence.vma
  # ---- M con MPRV: cargas traducidas como S
  li t0, (1 << 17) | (1 << 11)
  csrs mstatus, t0""")
    acc_block(o, TESTVA + 0 * 4096, 'M+MPRV(S) pagina R')
    acc_block(o, 0x40000000, 'M+MPRV(S) megapagina')
    o.append('  li t0, (1 << 17) | (3 << 11)\n  csrc mstatus, t0')
    # a S
    o.append('  li a7, 1\n  la a1, s_main\n  ecall')
    o.append('s_main:')
    for sum_, mxr in ((0, 0), (1, 0), (0, 1), (1, 1)):
        o.append(f'  # ==== SUM={sum_} MXR={mxr}')
        o.append(f'  li a7, 5\n  li a1, {(1 << 18) | (1 << 19)}\n  ecall')          # limpiar
        bits = (sum_ << 18) | (mxr << 19)
        if bits:
            o.append(f'  li a7, 4\n  li a1, {bits}\n  ecall')
        for idx, fl, dst in PAGES:
            if dst == 'data':
                acc_block(o, TESTVA + idx * 4096, f'pagina {idx} flags {fl:#x}')
        acc_block(o, 0x40000000 + 0x1238, 'megapagina')
        acc_block(o, 0x40400000, 'megapagina desalineada')
        acc_block(o, 0xC0000000, 'gigapagina desalineada')
        acc_block(o, 0x0000004000000000, 'no canonica')
        acc_block(o, 0xFFFFFFFFC0000000, 'canonica alta sin mapear')
        # fetch
        o.append(f'  li s2, {TESTVA + 8 * 4096}\n  jalr s2\n  li s2, {TESTVA + 9 * 4096}\n  jalr s2')
        o.append(f'  li s2, {TESTVA + 10 * 4096}\n  jalr s2')                    # pagina U desde S
        o.append(f'  li s2, {TESTVA + 2 * 4096}\n  jalr s2')                     # A=0
    # sfence tras cambiar una PTE: pagina 0 pasa a RW AD
    o.append(f"""  # ==== cambio de PTE + sfence.vma
  li a7, 6
  ecall
  sfence.vma""")
    acc_block(o, TESTVA, 'pagina 0 tras hacerla RW')
    # ASID: alternar raices sin sfence (ASIDs distintos)
    o.append("""  # ==== ASIDs
  li a7, 7
  ecall""")
    acc_block(o, 0x40000000, 'ASID 2')
    o.append('  li a7, 8\n  ecall')
    acc_block(o, 0x40000000, 'ASID 1 otra vez')
    o.append('  li a7, 7\n  ecall')
    acc_block(o, 0x40000000, 'ASID 2 otra vez')
    o.append('  li a7, 8\n  ecall')
    # a U
    o.append(f'  li a7, 2\n  li a1, {TESTVA + 10 * 4096}\n  ecall')
    o.append("""
  .align 2
m_handler:
  csrr t5, mcause
  li t6, 8
  bltu t5, t6, m_skip
  li t6, 12
  bgeu t5, t6, m_fetch
  # ecall: a7 = 1 S en a1 | 2 U en a1 | 3 fin | 4 csrs mstatus,a1 | 5 csrc mstatus,a1
  #        6 pagina 0 -> RW AD | 7 satp ASID 2 | 8 satp ASID 1
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  li t6, 3
  beq a7, t6, pass
  li t6, 4
  bne a7, t6, 1f
  csrs mstatus, a1
  mret
1:
  li t6, 5
  bne a7, t6, 2f
  csrc mstatus, a1
  mret
2:
  li t6, 6
  bne a7, t6, 3f
  ld t5, 0(s5)
  ori t5, t5, 0xC4
  sd t5, 0(s5)
  mret
3:
  li t6, 7
  bne a7, t6, 4f
  srli t5, s6, 12
  li t6, (8 << 60) | (2 << 44)
  or t5, t5, t6
  csrw satp, t5
  mret
4:
  li t6, 8
  bne a7, t6, 5f
  srli t5, s3, 12
  li t6, (8 << 60) | (1 << 44)
  or t5, t5, t6
  csrw satp, t5
  mret
5:
  li t6, 0x1800
  csrc mstatus, t6
  li t6, 1
  bne a7, t6, 6f
  li t6, 0x800
  csrs mstatus, t6
6:
  csrw mepc, a1
  mret
m_fetch:
  li t6, 13
  bgeu t5, t6, m_skip                    # 13, 15: load/store page fault
  csrw mepc, ra                          # 12: fetch page fault -> volver a ra
  mret
m_skip:
  li t6, 1
  beq t5, t6, m_fetch_af
  csrr t5, mepc
  li t4, 1 << 17                         # leer la instruccion con MPRV: VA del modo previo
  csrrs t3, mstatus, t4
  lhu t6, 0(t5)
  csrw mstatus, t3                       # restaurar MPRV tal como estaba
  andi t6, t6, 3
  addi t5, t5, 2
  li t4, 3
  bne t6, t4, 7f
  addi t5, t5, 2
7:
  csrw mepc, t5
  mret
m_fetch_af:
  csrw mepc, ra
  mret
pass:
  li t0, 1
  la t1, tohost
  sd t0, 0(t1)
8: j 8b

  # ---- codigo ejecutable mapeado en paginas de prueba
  .section .text.pages, "ax", @progbits
  .align 12
pg_code:
  addi a2, a2, 1
  ret
  .align 12
pg_ucode:
  li s2, 0x40204000
  ld a0, 0(s2)                           # pagina U: permitido
  sd a0, 8(s2)
  li s2, 0x40200000
  ld a0, 0(s2)                           # pagina S desde U: fallo
  li s2, 0x40000000
  ld a0, 0(s2)                           # megapagina S: fallo
  csrr a0, sstatus                       # ilegal en U
  li a7, 3
  ecall

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0

  .data
  .align 12
pt_root: .zero 4096
pt_l1:   .zero 4096
pt_l0:   .zero 4096
pt_root2: .zero 4096
pt_l1b:  .zero 4096""")
    for idx, fl, dst in PAGES:
        if dst == 'data':
            o.append(f'pg_data{idx}:\n  .rept 512\n  .dword {0x1111111111111111 * (idx + 1) & ((1 << 64) - 1):#x}\n  .endr')
    o.append("""  .zero 4096
stack_top:""")
    open(sys.argv[1], 'w').write('\n'.join(o) + '\n')


if __name__ == '__main__':
    main()
