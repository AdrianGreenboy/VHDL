#!/usr/bin/env python3
"""gen_csr_sweep.py - genera csr_sweep.S (Capa 2 dirigida).

Barre las 4096 direcciones de CSR en M, S (TVM=0/1) y U (con counteren
parciales), escribe patrones WARL en cada CSR escribible y ejecuta las
instrucciones privilegiadas en cada modo. El lockstep compara cada lectura
y cada trap contra el ISS: cualquier diferencia de mascara, privilegio o
legalidad aparece como MISMATCH.
"""
import sys

PATS = [0, -1, 0x5555555555555555, -0x5555555555555556, 0x8FFFFFFFFFFFFFFF, 0x0000000080001234]
# CSRs escribibles en M con patrones (se restaura el valor original tras cada uno)
WARL_M = [0x300, 0x302, 0x303, 0x304, 0x305, 0x306, 0x30A, 0x320, 0x323, 0x33F, 0x340, 0x341,
          0x342, 0x343, 0x344, 0x7A0, 0x7A1, 0x7A2, 0x7A3,
          0xB02, 0xB03, 0xB1F, 0x100, 0x104, 0x105, 0x106, 0x10A, 0x140, 0x141, 0x142,
          0x143, 0x144, 0x180]
WARL_S = [0x100, 0x104, 0x105, 0x106, 0x10A, 0x140, 0x141, 0x142, 0x143, 0x144]


SKIP = set()   # --spike: CSR de Sdtrig que Spike expone aunque no haya triggers


def sweep(o, label):
    o.append(f'# ---- barrido de lectura y reescritura: {label}')
    for a in range(4096):
        if a in SKIP:
            continue
        o.append(f'  csrr a0, {a:#x}')
        if (a >> 10) != 3:
            o.append(f'  csrw {a:#x}, a0')


def warl(o, csrs):
    for a in csrs:
        o.append(f'  csrr s0, {a:#x}')
        for p in PATS:
            o.append(f'  li t0, {p}')
            o.append(f'  csrw {a:#x}, t0')
            o.append(f'  csrr a0, {a:#x}')
            o.append(f'  csrs {a:#x}, t0')
            o.append(f'  csrr a0, {a:#x}')
            o.append(f'  csrc {a:#x}, t0')
            o.append(f'  csrr a0, {a:#x}')
        o.append(f'  csrw {a:#x}, s0')


def main():
    if '--spike' in sys.argv:
        SKIP.update({0x5A8, 0x7A4, 0x7A8})
        sys.argv.remove('--spike')
    o = []
    o.append("""  .section .text.init
  .globl _start
_start:
  .irp r, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
  li x\\r, 0
  .endr
  la t0, m_handler
  csrw mtvec, t0
  csrw mie, zero
  csrw medeleg, zero
  csrw mideleg, zero
  li t0, -1                     # PMP abierta: no-op en nuestro core, necesaria en Spike
  csrw pmpaddr0, t0
  li t0, 0x1f
  csrw pmpcfg0, t0""")
    # en M: mtvec se toca en el barrido; el patron rompe el vector, por eso
    # 0x305 no se reescribe con patrones mientras pueda haber traps (no los hay)
    sweep(o, 'M')
    o.append('  la t0, m_handler\n  csrw mtvec, t0')
    warl(o, WARL_M)
    o.append('  la t0, m_handler\n  csrw mtvec, t0\n  csrw satp, zero\n  li t0, 0x1800\n  csrc mstatus, t0')
    # S con TVM=0
    o.append('  li a7, 1\n  la a1, s_part0\n  ecall')
    o.append('s_part0:')
    sweep(o, 'S TVM=0')
    warl(o, WARL_S)
    o.append('  sfence.vma\n  li a7, 4\n  ecall')           # M pone TVM/TW/TSR y vuelve a S
    o.append('s_part1:')
    sweep(o, 'S TVM=1')
    o.append('  sfence.vma\n  sret\n  wfi\n  mret')
    o.append('  li a7, 2\n  la a1, u_part0\n  ecall')
    o.append('u_part0:')
    sweep(o, 'U counteren=0')
    o.append('  wfi\n  sret\n  mret\n  sfence.vma\n  ebreak\n  c.ebreak')
    o.append('  li a7, 5\n  ecall')                       # M fija counteren parciales
    o.append('u_part1:')
    sweep(o, 'U counteren parcial')
    o.append('  li a7, 3\n  ecall')
    o.append("""
  .align 2
m_handler:
  csrr t5, mcause
  li t6, 8
  bltu t5, t6, skip
  li t6, 12
  bgeu t5, t6, skip
  # ecall: a7 = 1 ir a S en a1 | 2 ir a U en a1 | 3 fin | 4 TVM/TW/TSR + S | 5 counteren + U
  li t6, 3
  beq a7, t6, pass
  li t6, 4
  bne a7, t6, 1f
  li t6, (1 << 20) | (1 << 21) | (1 << 22)
  csrs mstatus, t6
  la a1, s_part1
  li a7, 1
1:
  li t6, 5
  bne a7, t6, 2f
  li t6, 0x5
  csrw mcounteren, t6
  li t6, 0x3
  csrw scounteren, t6
  la a1, u_part1
  li a7, 2
2:
  li t6, 0x1800
  csrc mstatus, t6
  li t6, 1
  bne a7, t6, 3f
  li t6, 0x800
  csrs mstatus, t6
3:
  csrw mepc, a1
  mret
skip:
  csrr t5, mepc
  lhu t6, 0(t5)
  andi t6, t6, 3
  addi t5, t5, 2
  li t4, 3
  bne t6, t4, 4f
  addi t5, t5, 2
4:
  csrw mepc, t5
  mret
pass:
  li t0, 1
  la t1, tohost
  sd t0, 0(t1)
5: j 5b

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
""")
    open(sys.argv[1], 'w').write('\n'.join(o) + '\n')


if __name__ == '__main__':
    main()
