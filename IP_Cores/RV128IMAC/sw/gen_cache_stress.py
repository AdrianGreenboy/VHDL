#!/usr/bin/env python3
"""gen_cache_stress.py (RV128IMAC) - genera cache_stress.S para el modo RV128 (capa 3b).

Port del cache_stress del RV64IMAC al ensamblador rv128asm.py:
  * D$: 64 KiB de datos (4x la cache) con accesos pseudoaleatorios (LFSR) de todos
    los tamanos (B/H/W/D/Q), AMO .W/.D/.Q y LR/SC .D/.Q sobre lineas que se expulsan
    sucias. Cada paso hace 6 rondas.
  * I$: 384 funciones de 64 B (24 KiB, 1.5x la cache) llamadas en orden pseudoaleatorio
    por una tabla de punteros de 128 bit.
  * Codigo automodificable: se reescribe 'addi a0, x0, imm' con imm variable, fence.i
    (limpieza completa de la D$), se llama y se comprueba el resultado.
  * La mitad del bucle corre en S (RV128 no tiene paginacion: satp es Bare).
El oraculo principal es el lockstep (cada load y cada store comparados con iss128.py).
Uso: gen_cache_stress.py <salida.S>
"""
import sys

NFUNC = 384
ITERS = 1500
ROUNDS = 6


def main():
    o = ["# generado por gen_cache_stress.py (no editar)",
         "_start:",
         "  la t0, m_handler",
         "  csrw mtvec, t0",
         "  la sp, stack_top",
         "  li s11, 0xACE1ACE1                      # LFSR",
         "  la s10, databuf",
         "  la s9, ftable",
         "  li s8, 0                                # checksum",
         f"  li s7, {ITERS}",
         "# primera mitad en M, segunda en S",
         "main_loop:",
         f"  li t0, {ITERS // 2}",
         "  bne s7, t0, do_step",
         "  li t0, 2048                             # MPP = S",
         "  csrs mstatus, t0",
         "  la t0, do_step",
         "  csrw mepc, t0",
         "  mret",
         "do_step:",
         "  call step",
         "  addi s7, s7, -1",
         "  bnez s7, main_loop",
         "  li a0, 0",
         "  j finish",
         "",
         "# ---- un paso: accesos de datos + llamada a funcion + automodificacion",
         "step:",
         "  addi sp, sp, -16",
         "  sq ra, 0(sp)"]
    for _ in range(ROUNDS):
        o += ["  call lfsr",
              "  li t1, 0xFFF0                           # desplazamiento en 64 KiB, alineado a 16",
              "  and t1, a0, t1",
              "  add t2, s10, t1",
              "  lq t3, 0(t2)",
              "  add s8, s8, t3",
              "  sq s8, 0(t2)",
              "  sd a0, 8(t2)",
              "  ld t3, 0(t2)",
              "  xor s8, s8, t3",
              "  sw a0, 4(t2)",
              "  lhu t3, 2(t2)",
              "  xor s8, s8, t3",
              "  sb a0, 15(t2)",
              "  lb t3, 15(t2)",
              "  add s8, s8, t3",
              "  amoadd.q t3, s8, (t2)",
              "  add s8, s8, t3",
              "  addi t4, t2, 8",
              "  amoadd.d t3, s8, (t4)",
              "  add s8, s8, t3",
              "  amoxor.w t3, a0, (t2)",
              "  xor s8, s8, t3",
              "  lr.q t3, (t2)",
              "  addi t3, t3, 1",
              "  sc.q t4, t3, (t2)",
              "  add s8, s8, t4",
              "  lr.d t3, (t2)",
              "  addi t3, t3, 3",
              "  sc.d t4, t3, (t2)",
              "  add s8, s8, t4"]
    o += ["  # llamada indirecta a una funcion pseudoaleatoria (I$)",
          "  call lfsr",
          f"  li t1, {NFUNC}",
          "  remu t1, a0, t1",
          "  slli t1, t1, 4",
          "  add t1, s9, t1",
          "  lq t1, 0(t1)",
          "  jalr ra, 0(t1)",
          "  add s8, s8, a0",
          "  # automodificacion: 'addi a0, x0, imm' con imm = a0 & 0x7ff",
          "  call lfsr",
          "  andi t5, a0, 0x7ff",
          "  la t1, smc_slot",
          "  slli t2, t5, 20",
          "  li t3, 0x00000513                       # addi a0, x0, 0",
          "  or t2, t2, t3",
          "  sw t2, 0(t1)",
          "  fence.i",
          "  call smc_slot",
          "  bne a0, t5, smc_fail",
          "  lq ra, 0(sp)",
          "  addi sp, sp, 16",
          "  ret",
          "smc_fail:",
          "  li a0, 9",
          "  j finish",
          "",
          "lfsr:                                     # Galois 32 bit",
          "  srli a0, s11, 1",
          "  andi t0, s11, 1",
          "  neg t0, t0",
          "  li t1, 0xB4BCD35C",
          "  and t0, t0, t1",
          "  xor s11, a0, t0",
          "  mv a0, s11",
          "  ret",
          "",
          ".align 2",
          "m_handler:                                # nada debe atraparse",
          "  csrr a0, mcause",
          "  addi a0, a0, 100",
          "finish:",
          "  slli a0, a0, 1",
          "  ori a0, a0, 1",
          "  la t0, tohost",
          "  sd a0, 0(t0)",
          "spin:",
          "  j spin",
          "",
          ".align 6",
          "smc_slot:                                 # se reescribe como palabra de 32 bit",
          "  addi a0, x0, 0",
          "  ret",
          ".align 6"]
    for k in range(NFUNC):
        o += [f"func{k}:", f"  li a0, {k * 7 + 1}", f"  xori a0, a0, {k & 0x7ff}",
              f"  addi a0, a0, {k % 13}", "  ret", ".align 6"]
    o += ["tohost:", "  .dword 0, 0", ".align 6", "fromhost:", "  .dword 0, 0",
          ".align 4", "ftable:"]
    o += [f"  .octa func{k}" for k in range(NFUNC)]
    o += [".align 12", "databuf:", "  .zero 65536", "  .zero 4096", "stack_top:"]
    open(sys.argv[1], 'w').write('\n'.join(o) + '\n')


if __name__ == '__main__':
    main()
