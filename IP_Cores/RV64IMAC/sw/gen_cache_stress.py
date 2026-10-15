#!/usr/bin/env python3
"""gen_cache_stress.py - genera cache_stress.S (Paso 6).

  * D$: 64 KiB de datos (4x la cache) con accesos pseudoaleatorios (LFSR) de
    todos los tamanos, AMO y LR/SC sobre lineas que se expulsan sucias.
  * I$: 384 funciones de 64 B (24 KiB, 1.5x la cache) llamadas en orden
    pseudoaleatorio por una tabla de saltos.
  * Codigo automodificable: se reescribe una instruccion 'li a0, imm' con imm
    variable, fence.i, se llama y se comprueba el resultado (autoverificado).
  * Paginas: la mitad del bucle corre en S con Sv39 (gigapagina identidad), asi
    el PTW lee PTEs por la D$ mientras se expulsan lineas.
El oraculo principal es el lockstep (cada load y cada store comparados).
"""
import sys

NFUNC = 384
ITERS = 1500


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
  # raiz Sv39: gigapagina identidad 0x8000_0000
  la t0, pt_root
  li t1, (0x80000000 >> 12) << 10 | 0xCF
  sd t1, 16(t0)
  srli t0, t0, 12
  li t1, 8 << 60
  or t0, t0, t1
  csrw satp, t0
  sfence.vma
  li s11, 0xACE1ACE1                      # LFSR
  la s10, databuf
  la s9, ftable
  li s8, 0                                # checksum
  li s7, %d
  # primera mitad en M (sin traduccion), segunda en S (Sv39)
main_loop:
  li t0, %d
  bne s7, t0, 1f
  li t0, 1 << 11                          # MPP = S
  csrs mstatus, t0
  la t0, 1f
  csrw mepc, t0
  mret
1:
  call step
  addi s7, s7, -1
  bnez s7, main_loop
  li a0, 0
  j finish

# ---- un paso: accesos de datos + llamada a funcion + automodificacion
step:
  addi sp, sp, -16
  sd ra, 0(sp)
  .rept 6
  call lfsr
  li t1, 0xFFF8                           # desplazamiento en 64 KiB, alineado a 8
  and t1, a0, t1
  add t2, s10, t1
  ld t3, 0(t2)
  add s8, s8, t3
  sd s8, 0(t2)
  sw a0, 4(t2)
  lhu t3, 2(t2)
  xor s8, s8, t3
  sb a0, 7(t2)
  lb t3, 7(t2)
  add s8, s8, t3
  amoadd.d t3, s8, (t2)
  add s8, s8, t3
  amoxor.w t3, a0, (t2)
  xor s8, s8, t3
  lr.d t3, (t2)
  addi t3, t3, 1
  sc.d t4, t3, (t2)
  add s8, s8, t4
  .endr
  # llamada indirecta a una funcion pseudoaleatoria (I$)
  call lfsr
  li t1, %d
  remu t1, a0, t1
  slli t1, t1, 3
  add t1, s9, t1
  ld t1, 0(t1)
  jalr t1
  add s8, s8, a0
  # automodificacion: 'li a0, imm' con imm = a0 & 0x7ff
  call lfsr
  andi t5, a0, 0x7ff
  la t1, smc_slot
  slli t2, t5, 20
  li t3, 0x00000513                       # addi a0, x0, 0
  or t2, t2, t3
  sw t2, 0(t1)
  fence.i
  call smc_slot
  bne a0, t5, smc_fail
  ld ra, 0(sp)
  addi sp, sp, 16
  ret
smc_fail:
  li a0, 9
  j finish

lfsr:                                     # Galois 32 bit
  srli a0, s11, 1
  andi t0, s11, 1
  neg t0, t0
  li t1, 0xB4BCD35C
  and t0, t0, t1
  xor s11, a0, t0
  mv a0, s11
  ret

  .align 2
m_handler:                                # nada debe atraparse
  csrr a0, mcause
  addi a0, a0, 100
finish:
  slli a0, a0, 1
  ori a0, a0, 1
  la t0, tohost
  sd a0, 0(t0)
2: j 2b

  .align 6
  .option push
  .option norvc                           # el hueco se reescribe como palabra de 32 bit
smc_slot:
  addi a0, x0, 0
  ret
  .option pop
""" % (ITERS, ITERS // 2, NFUNC))
    # funciones de relleno de 64 B cada una
    o.append('  .align 6')
    for k in range(NFUNC):
        o.append(f'func{k}:\n  li a0, {k * 7 + 1}\n  xori a0, a0, {k & 0x7ff}\n  addi a0, a0, {k % 13}')
        o.append('  ret\n  .align 6')
    o.append("""
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
  .align 3
ftable:""")
    for k in range(NFUNC):
        o.append(f'  .dword func{k}')
    o.append("""  .align 12
databuf: .zero 65536
  .zero 4096
stack_top:""")
    open(sys.argv[1], 'w').write('\n'.join(o) + '\n')


if __name__ == '__main__':
    main()
