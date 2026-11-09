# generado por gen_cache_stress.py (no editar)
_start:
  la t0, m_handler
  csrw mtvec, t0
  la sp, stack_top
  li s11, 0xACE1ACE1                      # LFSR
  la s10, databuf
  la s9, ftable
  li s8, 0                                # checksum
  li s7, 1500
# primera mitad en M, segunda en S
main_loop:
  li t0, 750
  bne s7, t0, do_step
  li t0, 2048                             # MPP = S
  csrs mstatus, t0
  la t0, do_step
  csrw mepc, t0
  mret
do_step:
  call step
  addi s7, s7, -1
  bnez s7, main_loop
  li a0, 0
  j finish

# ---- un paso: accesos de datos + llamada a funcion + automodificacion
step:
  addi sp, sp, -16
  sq ra, 0(sp)
  call lfsr
  li t1, 0xFFF0                           # desplazamiento en 64 KiB, alineado a 16
  and t1, a0, t1
  add t2, s10, t1
  lq t3, 0(t2)
  add s8, s8, t3
  sq s8, 0(t2)
  sd a0, 8(t2)
  ld t3, 0(t2)
  xor s8, s8, t3
  sw a0, 4(t2)
  lhu t3, 2(t2)
  xor s8, s8, t3
  sb a0, 15(t2)
  lb t3, 15(t2)
  add s8, s8, t3
  amoadd.q t3, s8, (t2)
  add s8, s8, t3
  addi t4, t2, 8
  amoadd.d t3, s8, (t4)
  add s8, s8, t3
  amoxor.w t3, a0, (t2)
  xor s8, s8, t3
  lr.q t3, (t2)
  addi t3, t3, 1
  sc.q t4, t3, (t2)
  add s8, s8, t4
  lr.d t3, (t2)
  addi t3, t3, 3
  sc.d t4, t3, (t2)
  add s8, s8, t4
  call lfsr
  li t1, 0xFFF0                           # desplazamiento en 64 KiB, alineado a 16
  and t1, a0, t1
  add t2, s10, t1
  lq t3, 0(t2)
  add s8, s8, t3
  sq s8, 0(t2)
  sd a0, 8(t2)
  ld t3, 0(t2)
  xor s8, s8, t3
  sw a0, 4(t2)
  lhu t3, 2(t2)
  xor s8, s8, t3
  sb a0, 15(t2)
  lb t3, 15(t2)
  add s8, s8, t3
  amoadd.q t3, s8, (t2)
  add s8, s8, t3
  addi t4, t2, 8
  amoadd.d t3, s8, (t4)
  add s8, s8, t3
  amoxor.w t3, a0, (t2)
  xor s8, s8, t3
  lr.q t3, (t2)
  addi t3, t3, 1
  sc.q t4, t3, (t2)
  add s8, s8, t4
  lr.d t3, (t2)
  addi t3, t3, 3
  sc.d t4, t3, (t2)
  add s8, s8, t4
  call lfsr
  li t1, 0xFFF0                           # desplazamiento en 64 KiB, alineado a 16
  and t1, a0, t1
  add t2, s10, t1
  lq t3, 0(t2)
  add s8, s8, t3
  sq s8, 0(t2)
  sd a0, 8(t2)
  ld t3, 0(t2)
  xor s8, s8, t3
  sw a0, 4(t2)
  lhu t3, 2(t2)
  xor s8, s8, t3
  sb a0, 15(t2)
  lb t3, 15(t2)
  add s8, s8, t3
  amoadd.q t3, s8, (t2)
  add s8, s8, t3
  addi t4, t2, 8
  amoadd.d t3, s8, (t4)
  add s8, s8, t3
  amoxor.w t3, a0, (t2)
  xor s8, s8, t3
  lr.q t3, (t2)
  addi t3, t3, 1
  sc.q t4, t3, (t2)
  add s8, s8, t4
  lr.d t3, (t2)
  addi t3, t3, 3
  sc.d t4, t3, (t2)
  add s8, s8, t4
  call lfsr
  li t1, 0xFFF0                           # desplazamiento en 64 KiB, alineado a 16
  and t1, a0, t1
  add t2, s10, t1
  lq t3, 0(t2)
  add s8, s8, t3
  sq s8, 0(t2)
  sd a0, 8(t2)
  ld t3, 0(t2)
  xor s8, s8, t3
  sw a0, 4(t2)
  lhu t3, 2(t2)
  xor s8, s8, t3
  sb a0, 15(t2)
  lb t3, 15(t2)
  add s8, s8, t3
  amoadd.q t3, s8, (t2)
  add s8, s8, t3
  addi t4, t2, 8
  amoadd.d t3, s8, (t4)
  add s8, s8, t3
  amoxor.w t3, a0, (t2)
  xor s8, s8, t3
  lr.q t3, (t2)
  addi t3, t3, 1
  sc.q t4, t3, (t2)
  add s8, s8, t4
  lr.d t3, (t2)
  addi t3, t3, 3
  sc.d t4, t3, (t2)
  add s8, s8, t4
  call lfsr
  li t1, 0xFFF0                           # desplazamiento en 64 KiB, alineado a 16
  and t1, a0, t1
  add t2, s10, t1
  lq t3, 0(t2)
  add s8, s8, t3
  sq s8, 0(t2)
  sd a0, 8(t2)
  ld t3, 0(t2)
  xor s8, s8, t3
  sw a0, 4(t2)
  lhu t3, 2(t2)
  xor s8, s8, t3
  sb a0, 15(t2)
  lb t3, 15(t2)
  add s8, s8, t3
  amoadd.q t3, s8, (t2)
  add s8, s8, t3
  addi t4, t2, 8
  amoadd.d t3, s8, (t4)
  add s8, s8, t3
  amoxor.w t3, a0, (t2)
  xor s8, s8, t3
  lr.q t3, (t2)
  addi t3, t3, 1
  sc.q t4, t3, (t2)
  add s8, s8, t4
  lr.d t3, (t2)
  addi t3, t3, 3
  sc.d t4, t3, (t2)
  add s8, s8, t4
  call lfsr
  li t1, 0xFFF0                           # desplazamiento en 64 KiB, alineado a 16
  and t1, a0, t1
  add t2, s10, t1
  lq t3, 0(t2)
  add s8, s8, t3
  sq s8, 0(t2)
  sd a0, 8(t2)
  ld t3, 0(t2)
  xor s8, s8, t3
  sw a0, 4(t2)
  lhu t3, 2(t2)
  xor s8, s8, t3
  sb a0, 15(t2)
  lb t3, 15(t2)
  add s8, s8, t3
  amoadd.q t3, s8, (t2)
  add s8, s8, t3
  addi t4, t2, 8
  amoadd.d t3, s8, (t4)
  add s8, s8, t3
  amoxor.w t3, a0, (t2)
  xor s8, s8, t3
  lr.q t3, (t2)
  addi t3, t3, 1
  sc.q t4, t3, (t2)
  add s8, s8, t4
  lr.d t3, (t2)
  addi t3, t3, 3
  sc.d t4, t3, (t2)
  add s8, s8, t4
  # llamada indirecta a una funcion pseudoaleatoria (I$)
  call lfsr
  li t1, 384
  remu t1, a0, t1
  slli t1, t1, 4
  add t1, s9, t1
  lq t1, 0(t1)
  jalr ra, 0(t1)
  add s8, s8, a0
  # automodificacion: 'addi a0, x0, imm' con imm = a0 & 0x7ff
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
  lq ra, 0(sp)
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
spin:
  j spin

.align 6
smc_slot:                                 # se reescribe como palabra de 32 bit
  addi a0, x0, 0
  ret
.align 6
func0:
  li a0, 1
  xori a0, a0, 0
  addi a0, a0, 0
  ret
.align 6
func1:
  li a0, 8
  xori a0, a0, 1
  addi a0, a0, 1
  ret
.align 6
func2:
  li a0, 15
  xori a0, a0, 2
  addi a0, a0, 2
  ret
.align 6
func3:
  li a0, 22
  xori a0, a0, 3
  addi a0, a0, 3
  ret
.align 6
func4:
  li a0, 29
  xori a0, a0, 4
  addi a0, a0, 4
  ret
.align 6
func5:
  li a0, 36
  xori a0, a0, 5
  addi a0, a0, 5
  ret
.align 6
func6:
  li a0, 43
  xori a0, a0, 6
  addi a0, a0, 6
  ret
.align 6
func7:
  li a0, 50
  xori a0, a0, 7
  addi a0, a0, 7
  ret
.align 6
func8:
  li a0, 57
  xori a0, a0, 8
  addi a0, a0, 8
  ret
.align 6
func9:
  li a0, 64
  xori a0, a0, 9
  addi a0, a0, 9
  ret
.align 6
func10:
  li a0, 71
  xori a0, a0, 10
  addi a0, a0, 10
  ret
.align 6
func11:
  li a0, 78
  xori a0, a0, 11
  addi a0, a0, 11
  ret
.align 6
func12:
  li a0, 85
  xori a0, a0, 12
  addi a0, a0, 12
  ret
.align 6
func13:
  li a0, 92
  xori a0, a0, 13
  addi a0, a0, 0
  ret
.align 6
func14:
  li a0, 99
  xori a0, a0, 14
  addi a0, a0, 1
  ret
.align 6
func15:
  li a0, 106
  xori a0, a0, 15
  addi a0, a0, 2
  ret
.align 6
func16:
  li a0, 113
  xori a0, a0, 16
  addi a0, a0, 3
  ret
.align 6
func17:
  li a0, 120
  xori a0, a0, 17
  addi a0, a0, 4
  ret
.align 6
func18:
  li a0, 127
  xori a0, a0, 18
  addi a0, a0, 5
  ret
.align 6
func19:
  li a0, 134
  xori a0, a0, 19
  addi a0, a0, 6
  ret
.align 6
func20:
  li a0, 141
  xori a0, a0, 20
  addi a0, a0, 7
  ret
.align 6
func21:
  li a0, 148
  xori a0, a0, 21
  addi a0, a0, 8
  ret
.align 6
func22:
  li a0, 155
  xori a0, a0, 22
  addi a0, a0, 9
  ret
.align 6
func23:
  li a0, 162
  xori a0, a0, 23
  addi a0, a0, 10
  ret
.align 6
func24:
  li a0, 169
  xori a0, a0, 24
  addi a0, a0, 11
  ret
.align 6
func25:
  li a0, 176
  xori a0, a0, 25
  addi a0, a0, 12
  ret
.align 6
func26:
  li a0, 183
  xori a0, a0, 26
  addi a0, a0, 0
  ret
.align 6
func27:
  li a0, 190
  xori a0, a0, 27
  addi a0, a0, 1
  ret
.align 6
func28:
  li a0, 197
  xori a0, a0, 28
  addi a0, a0, 2
  ret
.align 6
func29:
  li a0, 204
  xori a0, a0, 29
  addi a0, a0, 3
  ret
.align 6
func30:
  li a0, 211
  xori a0, a0, 30
  addi a0, a0, 4
  ret
.align 6
func31:
  li a0, 218
  xori a0, a0, 31
  addi a0, a0, 5
  ret
.align 6
func32:
  li a0, 225
  xori a0, a0, 32
  addi a0, a0, 6
  ret
.align 6
func33:
  li a0, 232
  xori a0, a0, 33
  addi a0, a0, 7
  ret
.align 6
func34:
  li a0, 239
  xori a0, a0, 34
  addi a0, a0, 8
  ret
.align 6
func35:
  li a0, 246
  xori a0, a0, 35
  addi a0, a0, 9
  ret
.align 6
func36:
  li a0, 253
  xori a0, a0, 36
  addi a0, a0, 10
  ret
.align 6
func37:
  li a0, 260
  xori a0, a0, 37
  addi a0, a0, 11
  ret
.align 6
func38:
  li a0, 267
  xori a0, a0, 38
  addi a0, a0, 12
  ret
.align 6
func39:
  li a0, 274
  xori a0, a0, 39
  addi a0, a0, 0
  ret
.align 6
func40:
  li a0, 281
  xori a0, a0, 40
  addi a0, a0, 1
  ret
.align 6
func41:
  li a0, 288
  xori a0, a0, 41
  addi a0, a0, 2
  ret
.align 6
func42:
  li a0, 295
  xori a0, a0, 42
  addi a0, a0, 3
  ret
.align 6
func43:
  li a0, 302
  xori a0, a0, 43
  addi a0, a0, 4
  ret
.align 6
func44:
  li a0, 309
  xori a0, a0, 44
  addi a0, a0, 5
  ret
.align 6
func45:
  li a0, 316
  xori a0, a0, 45
  addi a0, a0, 6
  ret
.align 6
func46:
  li a0, 323
  xori a0, a0, 46
  addi a0, a0, 7
  ret
.align 6
func47:
  li a0, 330
  xori a0, a0, 47
  addi a0, a0, 8
  ret
.align 6
func48:
  li a0, 337
  xori a0, a0, 48
  addi a0, a0, 9
  ret
.align 6
func49:
  li a0, 344
  xori a0, a0, 49
  addi a0, a0, 10
  ret
.align 6
func50:
  li a0, 351
  xori a0, a0, 50
  addi a0, a0, 11
  ret
.align 6
func51:
  li a0, 358
  xori a0, a0, 51
  addi a0, a0, 12
  ret
.align 6
func52:
  li a0, 365
  xori a0, a0, 52
  addi a0, a0, 0
  ret
.align 6
func53:
  li a0, 372
  xori a0, a0, 53
  addi a0, a0, 1
  ret
.align 6
func54:
  li a0, 379
  xori a0, a0, 54
  addi a0, a0, 2
  ret
.align 6
func55:
  li a0, 386
  xori a0, a0, 55
  addi a0, a0, 3
  ret
.align 6
func56:
  li a0, 393
  xori a0, a0, 56
  addi a0, a0, 4
  ret
.align 6
func57:
  li a0, 400
  xori a0, a0, 57
  addi a0, a0, 5
  ret
.align 6
func58:
  li a0, 407
  xori a0, a0, 58
  addi a0, a0, 6
  ret
.align 6
func59:
  li a0, 414
  xori a0, a0, 59
  addi a0, a0, 7
  ret
.align 6
func60:
  li a0, 421
  xori a0, a0, 60
  addi a0, a0, 8
  ret
.align 6
func61:
  li a0, 428
  xori a0, a0, 61
  addi a0, a0, 9
  ret
.align 6
func62:
  li a0, 435
  xori a0, a0, 62
  addi a0, a0, 10
  ret
.align 6
func63:
  li a0, 442
  xori a0, a0, 63
  addi a0, a0, 11
  ret
.align 6
func64:
  li a0, 449
  xori a0, a0, 64
  addi a0, a0, 12
  ret
.align 6
func65:
  li a0, 456
  xori a0, a0, 65
  addi a0, a0, 0
  ret
.align 6
func66:
  li a0, 463
  xori a0, a0, 66
  addi a0, a0, 1
  ret
.align 6
func67:
  li a0, 470
  xori a0, a0, 67
  addi a0, a0, 2
  ret
.align 6
func68:
  li a0, 477
  xori a0, a0, 68
  addi a0, a0, 3
  ret
.align 6
func69:
  li a0, 484
  xori a0, a0, 69
  addi a0, a0, 4
  ret
.align 6
func70:
  li a0, 491
  xori a0, a0, 70
  addi a0, a0, 5
  ret
.align 6
func71:
  li a0, 498
  xori a0, a0, 71
  addi a0, a0, 6
  ret
.align 6
func72:
  li a0, 505
  xori a0, a0, 72
  addi a0, a0, 7
  ret
.align 6
func73:
  li a0, 512
  xori a0, a0, 73
  addi a0, a0, 8
  ret
.align 6
func74:
  li a0, 519
  xori a0, a0, 74
  addi a0, a0, 9
  ret
.align 6
func75:
  li a0, 526
  xori a0, a0, 75
  addi a0, a0, 10
  ret
.align 6
func76:
  li a0, 533
  xori a0, a0, 76
  addi a0, a0, 11
  ret
.align 6
func77:
  li a0, 540
  xori a0, a0, 77
  addi a0, a0, 12
  ret
.align 6
func78:
  li a0, 547
  xori a0, a0, 78
  addi a0, a0, 0
  ret
.align 6
func79:
  li a0, 554
  xori a0, a0, 79
  addi a0, a0, 1
  ret
.align 6
func80:
  li a0, 561
  xori a0, a0, 80
  addi a0, a0, 2
  ret
.align 6
func81:
  li a0, 568
  xori a0, a0, 81
  addi a0, a0, 3
  ret
.align 6
func82:
  li a0, 575
  xori a0, a0, 82
  addi a0, a0, 4
  ret
.align 6
func83:
  li a0, 582
  xori a0, a0, 83
  addi a0, a0, 5
  ret
.align 6
func84:
  li a0, 589
  xori a0, a0, 84
  addi a0, a0, 6
  ret
.align 6
func85:
  li a0, 596
  xori a0, a0, 85
  addi a0, a0, 7
  ret
.align 6
func86:
  li a0, 603
  xori a0, a0, 86
  addi a0, a0, 8
  ret
.align 6
func87:
  li a0, 610
  xori a0, a0, 87
  addi a0, a0, 9
  ret
.align 6
func88:
  li a0, 617
  xori a0, a0, 88
  addi a0, a0, 10
  ret
.align 6
func89:
  li a0, 624
  xori a0, a0, 89
  addi a0, a0, 11
  ret
.align 6
func90:
  li a0, 631
  xori a0, a0, 90
  addi a0, a0, 12
  ret
.align 6
func91:
  li a0, 638
  xori a0, a0, 91
  addi a0, a0, 0
  ret
.align 6
func92:
  li a0, 645
  xori a0, a0, 92
  addi a0, a0, 1
  ret
.align 6
func93:
  li a0, 652
  xori a0, a0, 93
  addi a0, a0, 2
  ret
.align 6
func94:
  li a0, 659
  xori a0, a0, 94
  addi a0, a0, 3
  ret
.align 6
func95:
  li a0, 666
  xori a0, a0, 95
  addi a0, a0, 4
  ret
.align 6
func96:
  li a0, 673
  xori a0, a0, 96
  addi a0, a0, 5
  ret
.align 6
func97:
  li a0, 680
  xori a0, a0, 97
  addi a0, a0, 6
  ret
.align 6
func98:
  li a0, 687
  xori a0, a0, 98
  addi a0, a0, 7
  ret
.align 6
func99:
  li a0, 694
  xori a0, a0, 99
  addi a0, a0, 8
  ret
.align 6
func100:
  li a0, 701
  xori a0, a0, 100
  addi a0, a0, 9
  ret
.align 6
func101:
  li a0, 708
  xori a0, a0, 101
  addi a0, a0, 10
  ret
.align 6
func102:
  li a0, 715
  xori a0, a0, 102
  addi a0, a0, 11
  ret
.align 6
func103:
  li a0, 722
  xori a0, a0, 103
  addi a0, a0, 12
  ret
.align 6
func104:
  li a0, 729
  xori a0, a0, 104
  addi a0, a0, 0
  ret
.align 6
func105:
  li a0, 736
  xori a0, a0, 105
  addi a0, a0, 1
  ret
.align 6
func106:
  li a0, 743
  xori a0, a0, 106
  addi a0, a0, 2
  ret
.align 6
func107:
  li a0, 750
  xori a0, a0, 107
  addi a0, a0, 3
  ret
.align 6
func108:
  li a0, 757
  xori a0, a0, 108
  addi a0, a0, 4
  ret
.align 6
func109:
  li a0, 764
  xori a0, a0, 109
  addi a0, a0, 5
  ret
.align 6
func110:
  li a0, 771
  xori a0, a0, 110
  addi a0, a0, 6
  ret
.align 6
func111:
  li a0, 778
  xori a0, a0, 111
  addi a0, a0, 7
  ret
.align 6
func112:
  li a0, 785
  xori a0, a0, 112
  addi a0, a0, 8
  ret
.align 6
func113:
  li a0, 792
  xori a0, a0, 113
  addi a0, a0, 9
  ret
.align 6
func114:
  li a0, 799
  xori a0, a0, 114
  addi a0, a0, 10
  ret
.align 6
func115:
  li a0, 806
  xori a0, a0, 115
  addi a0, a0, 11
  ret
.align 6
func116:
  li a0, 813
  xori a0, a0, 116
  addi a0, a0, 12
  ret
.align 6
func117:
  li a0, 820
  xori a0, a0, 117
  addi a0, a0, 0
  ret
.align 6
func118:
  li a0, 827
  xori a0, a0, 118
  addi a0, a0, 1
  ret
.align 6
func119:
  li a0, 834
  xori a0, a0, 119
  addi a0, a0, 2
  ret
.align 6
func120:
  li a0, 841
  xori a0, a0, 120
  addi a0, a0, 3
  ret
.align 6
func121:
  li a0, 848
  xori a0, a0, 121
  addi a0, a0, 4
  ret
.align 6
func122:
  li a0, 855
  xori a0, a0, 122
  addi a0, a0, 5
  ret
.align 6
func123:
  li a0, 862
  xori a0, a0, 123
  addi a0, a0, 6
  ret
.align 6
func124:
  li a0, 869
  xori a0, a0, 124
  addi a0, a0, 7
  ret
.align 6
func125:
  li a0, 876
  xori a0, a0, 125
  addi a0, a0, 8
  ret
.align 6
func126:
  li a0, 883
  xori a0, a0, 126
  addi a0, a0, 9
  ret
.align 6
func127:
  li a0, 890
  xori a0, a0, 127
  addi a0, a0, 10
  ret
.align 6
func128:
  li a0, 897
  xori a0, a0, 128
  addi a0, a0, 11
  ret
.align 6
func129:
  li a0, 904
  xori a0, a0, 129
  addi a0, a0, 12
  ret
.align 6
func130:
  li a0, 911
  xori a0, a0, 130
  addi a0, a0, 0
  ret
.align 6
func131:
  li a0, 918
  xori a0, a0, 131
  addi a0, a0, 1
  ret
.align 6
func132:
  li a0, 925
  xori a0, a0, 132
  addi a0, a0, 2
  ret
.align 6
func133:
  li a0, 932
  xori a0, a0, 133
  addi a0, a0, 3
  ret
.align 6
func134:
  li a0, 939
  xori a0, a0, 134
  addi a0, a0, 4
  ret
.align 6
func135:
  li a0, 946
  xori a0, a0, 135
  addi a0, a0, 5
  ret
.align 6
func136:
  li a0, 953
  xori a0, a0, 136
  addi a0, a0, 6
  ret
.align 6
func137:
  li a0, 960
  xori a0, a0, 137
  addi a0, a0, 7
  ret
.align 6
func138:
  li a0, 967
  xori a0, a0, 138
  addi a0, a0, 8
  ret
.align 6
func139:
  li a0, 974
  xori a0, a0, 139
  addi a0, a0, 9
  ret
.align 6
func140:
  li a0, 981
  xori a0, a0, 140
  addi a0, a0, 10
  ret
.align 6
func141:
  li a0, 988
  xori a0, a0, 141
  addi a0, a0, 11
  ret
.align 6
func142:
  li a0, 995
  xori a0, a0, 142
  addi a0, a0, 12
  ret
.align 6
func143:
  li a0, 1002
  xori a0, a0, 143
  addi a0, a0, 0
  ret
.align 6
func144:
  li a0, 1009
  xori a0, a0, 144
  addi a0, a0, 1
  ret
.align 6
func145:
  li a0, 1016
  xori a0, a0, 145
  addi a0, a0, 2
  ret
.align 6
func146:
  li a0, 1023
  xori a0, a0, 146
  addi a0, a0, 3
  ret
.align 6
func147:
  li a0, 1030
  xori a0, a0, 147
  addi a0, a0, 4
  ret
.align 6
func148:
  li a0, 1037
  xori a0, a0, 148
  addi a0, a0, 5
  ret
.align 6
func149:
  li a0, 1044
  xori a0, a0, 149
  addi a0, a0, 6
  ret
.align 6
func150:
  li a0, 1051
  xori a0, a0, 150
  addi a0, a0, 7
  ret
.align 6
func151:
  li a0, 1058
  xori a0, a0, 151
  addi a0, a0, 8
  ret
.align 6
func152:
  li a0, 1065
  xori a0, a0, 152
  addi a0, a0, 9
  ret
.align 6
func153:
  li a0, 1072
  xori a0, a0, 153
  addi a0, a0, 10
  ret
.align 6
func154:
  li a0, 1079
  xori a0, a0, 154
  addi a0, a0, 11
  ret
.align 6
func155:
  li a0, 1086
  xori a0, a0, 155
  addi a0, a0, 12
  ret
.align 6
func156:
  li a0, 1093
  xori a0, a0, 156
  addi a0, a0, 0
  ret
.align 6
func157:
  li a0, 1100
  xori a0, a0, 157
  addi a0, a0, 1
  ret
.align 6
func158:
  li a0, 1107
  xori a0, a0, 158
  addi a0, a0, 2
  ret
.align 6
func159:
  li a0, 1114
  xori a0, a0, 159
  addi a0, a0, 3
  ret
.align 6
func160:
  li a0, 1121
  xori a0, a0, 160
  addi a0, a0, 4
  ret
.align 6
func161:
  li a0, 1128
  xori a0, a0, 161
  addi a0, a0, 5
  ret
.align 6
func162:
  li a0, 1135
  xori a0, a0, 162
  addi a0, a0, 6
  ret
.align 6
func163:
  li a0, 1142
  xori a0, a0, 163
  addi a0, a0, 7
  ret
.align 6
func164:
  li a0, 1149
  xori a0, a0, 164
  addi a0, a0, 8
  ret
.align 6
func165:
  li a0, 1156
  xori a0, a0, 165
  addi a0, a0, 9
  ret
.align 6
func166:
  li a0, 1163
  xori a0, a0, 166
  addi a0, a0, 10
  ret
.align 6
func167:
  li a0, 1170
  xori a0, a0, 167
  addi a0, a0, 11
  ret
.align 6
func168:
  li a0, 1177
  xori a0, a0, 168
  addi a0, a0, 12
  ret
.align 6
func169:
  li a0, 1184
  xori a0, a0, 169
  addi a0, a0, 0
  ret
.align 6
func170:
  li a0, 1191
  xori a0, a0, 170
  addi a0, a0, 1
  ret
.align 6
func171:
  li a0, 1198
  xori a0, a0, 171
  addi a0, a0, 2
  ret
.align 6
func172:
  li a0, 1205
  xori a0, a0, 172
  addi a0, a0, 3
  ret
.align 6
func173:
  li a0, 1212
  xori a0, a0, 173
  addi a0, a0, 4
  ret
.align 6
func174:
  li a0, 1219
  xori a0, a0, 174
  addi a0, a0, 5
  ret
.align 6
func175:
  li a0, 1226
  xori a0, a0, 175
  addi a0, a0, 6
  ret
.align 6
func176:
  li a0, 1233
  xori a0, a0, 176
  addi a0, a0, 7
  ret
.align 6
func177:
  li a0, 1240
  xori a0, a0, 177
  addi a0, a0, 8
  ret
.align 6
func178:
  li a0, 1247
  xori a0, a0, 178
  addi a0, a0, 9
  ret
.align 6
func179:
  li a0, 1254
  xori a0, a0, 179
  addi a0, a0, 10
  ret
.align 6
func180:
  li a0, 1261
  xori a0, a0, 180
  addi a0, a0, 11
  ret
.align 6
func181:
  li a0, 1268
  xori a0, a0, 181
  addi a0, a0, 12
  ret
.align 6
func182:
  li a0, 1275
  xori a0, a0, 182
  addi a0, a0, 0
  ret
.align 6
func183:
  li a0, 1282
  xori a0, a0, 183
  addi a0, a0, 1
  ret
.align 6
func184:
  li a0, 1289
  xori a0, a0, 184
  addi a0, a0, 2
  ret
.align 6
func185:
  li a0, 1296
  xori a0, a0, 185
  addi a0, a0, 3
  ret
.align 6
func186:
  li a0, 1303
  xori a0, a0, 186
  addi a0, a0, 4
  ret
.align 6
func187:
  li a0, 1310
  xori a0, a0, 187
  addi a0, a0, 5
  ret
.align 6
func188:
  li a0, 1317
  xori a0, a0, 188
  addi a0, a0, 6
  ret
.align 6
func189:
  li a0, 1324
  xori a0, a0, 189
  addi a0, a0, 7
  ret
.align 6
func190:
  li a0, 1331
  xori a0, a0, 190
  addi a0, a0, 8
  ret
.align 6
func191:
  li a0, 1338
  xori a0, a0, 191
  addi a0, a0, 9
  ret
.align 6
func192:
  li a0, 1345
  xori a0, a0, 192
  addi a0, a0, 10
  ret
.align 6
func193:
  li a0, 1352
  xori a0, a0, 193
  addi a0, a0, 11
  ret
.align 6
func194:
  li a0, 1359
  xori a0, a0, 194
  addi a0, a0, 12
  ret
.align 6
func195:
  li a0, 1366
  xori a0, a0, 195
  addi a0, a0, 0
  ret
.align 6
func196:
  li a0, 1373
  xori a0, a0, 196
  addi a0, a0, 1
  ret
.align 6
func197:
  li a0, 1380
  xori a0, a0, 197
  addi a0, a0, 2
  ret
.align 6
func198:
  li a0, 1387
  xori a0, a0, 198
  addi a0, a0, 3
  ret
.align 6
func199:
  li a0, 1394
  xori a0, a0, 199
  addi a0, a0, 4
  ret
.align 6
func200:
  li a0, 1401
  xori a0, a0, 200
  addi a0, a0, 5
  ret
.align 6
func201:
  li a0, 1408
  xori a0, a0, 201
  addi a0, a0, 6
  ret
.align 6
func202:
  li a0, 1415
  xori a0, a0, 202
  addi a0, a0, 7
  ret
.align 6
func203:
  li a0, 1422
  xori a0, a0, 203
  addi a0, a0, 8
  ret
.align 6
func204:
  li a0, 1429
  xori a0, a0, 204
  addi a0, a0, 9
  ret
.align 6
func205:
  li a0, 1436
  xori a0, a0, 205
  addi a0, a0, 10
  ret
.align 6
func206:
  li a0, 1443
  xori a0, a0, 206
  addi a0, a0, 11
  ret
.align 6
func207:
  li a0, 1450
  xori a0, a0, 207
  addi a0, a0, 12
  ret
.align 6
func208:
  li a0, 1457
  xori a0, a0, 208
  addi a0, a0, 0
  ret
.align 6
func209:
  li a0, 1464
  xori a0, a0, 209
  addi a0, a0, 1
  ret
.align 6
func210:
  li a0, 1471
  xori a0, a0, 210
  addi a0, a0, 2
  ret
.align 6
func211:
  li a0, 1478
  xori a0, a0, 211
  addi a0, a0, 3
  ret
.align 6
func212:
  li a0, 1485
  xori a0, a0, 212
  addi a0, a0, 4
  ret
.align 6
func213:
  li a0, 1492
  xori a0, a0, 213
  addi a0, a0, 5
  ret
.align 6
func214:
  li a0, 1499
  xori a0, a0, 214
  addi a0, a0, 6
  ret
.align 6
func215:
  li a0, 1506
  xori a0, a0, 215
  addi a0, a0, 7
  ret
.align 6
func216:
  li a0, 1513
  xori a0, a0, 216
  addi a0, a0, 8
  ret
.align 6
func217:
  li a0, 1520
  xori a0, a0, 217
  addi a0, a0, 9
  ret
.align 6
func218:
  li a0, 1527
  xori a0, a0, 218
  addi a0, a0, 10
  ret
.align 6
func219:
  li a0, 1534
  xori a0, a0, 219
  addi a0, a0, 11
  ret
.align 6
func220:
  li a0, 1541
  xori a0, a0, 220
  addi a0, a0, 12
  ret
.align 6
func221:
  li a0, 1548
  xori a0, a0, 221
  addi a0, a0, 0
  ret
.align 6
func222:
  li a0, 1555
  xori a0, a0, 222
  addi a0, a0, 1
  ret
.align 6
func223:
  li a0, 1562
  xori a0, a0, 223
  addi a0, a0, 2
  ret
.align 6
func224:
  li a0, 1569
  xori a0, a0, 224
  addi a0, a0, 3
  ret
.align 6
func225:
  li a0, 1576
  xori a0, a0, 225
  addi a0, a0, 4
  ret
.align 6
func226:
  li a0, 1583
  xori a0, a0, 226
  addi a0, a0, 5
  ret
.align 6
func227:
  li a0, 1590
  xori a0, a0, 227
  addi a0, a0, 6
  ret
.align 6
func228:
  li a0, 1597
  xori a0, a0, 228
  addi a0, a0, 7
  ret
.align 6
func229:
  li a0, 1604
  xori a0, a0, 229
  addi a0, a0, 8
  ret
.align 6
func230:
  li a0, 1611
  xori a0, a0, 230
  addi a0, a0, 9
  ret
.align 6
func231:
  li a0, 1618
  xori a0, a0, 231
  addi a0, a0, 10
  ret
.align 6
func232:
  li a0, 1625
  xori a0, a0, 232
  addi a0, a0, 11
  ret
.align 6
func233:
  li a0, 1632
  xori a0, a0, 233
  addi a0, a0, 12
  ret
.align 6
func234:
  li a0, 1639
  xori a0, a0, 234
  addi a0, a0, 0
  ret
.align 6
func235:
  li a0, 1646
  xori a0, a0, 235
  addi a0, a0, 1
  ret
.align 6
func236:
  li a0, 1653
  xori a0, a0, 236
  addi a0, a0, 2
  ret
.align 6
func237:
  li a0, 1660
  xori a0, a0, 237
  addi a0, a0, 3
  ret
.align 6
func238:
  li a0, 1667
  xori a0, a0, 238
  addi a0, a0, 4
  ret
.align 6
func239:
  li a0, 1674
  xori a0, a0, 239
  addi a0, a0, 5
  ret
.align 6
func240:
  li a0, 1681
  xori a0, a0, 240
  addi a0, a0, 6
  ret
.align 6
func241:
  li a0, 1688
  xori a0, a0, 241
  addi a0, a0, 7
  ret
.align 6
func242:
  li a0, 1695
  xori a0, a0, 242
  addi a0, a0, 8
  ret
.align 6
func243:
  li a0, 1702
  xori a0, a0, 243
  addi a0, a0, 9
  ret
.align 6
func244:
  li a0, 1709
  xori a0, a0, 244
  addi a0, a0, 10
  ret
.align 6
func245:
  li a0, 1716
  xori a0, a0, 245
  addi a0, a0, 11
  ret
.align 6
func246:
  li a0, 1723
  xori a0, a0, 246
  addi a0, a0, 12
  ret
.align 6
func247:
  li a0, 1730
  xori a0, a0, 247
  addi a0, a0, 0
  ret
.align 6
func248:
  li a0, 1737
  xori a0, a0, 248
  addi a0, a0, 1
  ret
.align 6
func249:
  li a0, 1744
  xori a0, a0, 249
  addi a0, a0, 2
  ret
.align 6
func250:
  li a0, 1751
  xori a0, a0, 250
  addi a0, a0, 3
  ret
.align 6
func251:
  li a0, 1758
  xori a0, a0, 251
  addi a0, a0, 4
  ret
.align 6
func252:
  li a0, 1765
  xori a0, a0, 252
  addi a0, a0, 5
  ret
.align 6
func253:
  li a0, 1772
  xori a0, a0, 253
  addi a0, a0, 6
  ret
.align 6
func254:
  li a0, 1779
  xori a0, a0, 254
  addi a0, a0, 7
  ret
.align 6
func255:
  li a0, 1786
  xori a0, a0, 255
  addi a0, a0, 8
  ret
.align 6
func256:
  li a0, 1793
  xori a0, a0, 256
  addi a0, a0, 9
  ret
.align 6
func257:
  li a0, 1800
  xori a0, a0, 257
  addi a0, a0, 10
  ret
.align 6
func258:
  li a0, 1807
  xori a0, a0, 258
  addi a0, a0, 11
  ret
.align 6
func259:
  li a0, 1814
  xori a0, a0, 259
  addi a0, a0, 12
  ret
.align 6
func260:
  li a0, 1821
  xori a0, a0, 260
  addi a0, a0, 0
  ret
.align 6
func261:
  li a0, 1828
  xori a0, a0, 261
  addi a0, a0, 1
  ret
.align 6
func262:
  li a0, 1835
  xori a0, a0, 262
  addi a0, a0, 2
  ret
.align 6
func263:
  li a0, 1842
  xori a0, a0, 263
  addi a0, a0, 3
  ret
.align 6
func264:
  li a0, 1849
  xori a0, a0, 264
  addi a0, a0, 4
  ret
.align 6
func265:
  li a0, 1856
  xori a0, a0, 265
  addi a0, a0, 5
  ret
.align 6
func266:
  li a0, 1863
  xori a0, a0, 266
  addi a0, a0, 6
  ret
.align 6
func267:
  li a0, 1870
  xori a0, a0, 267
  addi a0, a0, 7
  ret
.align 6
func268:
  li a0, 1877
  xori a0, a0, 268
  addi a0, a0, 8
  ret
.align 6
func269:
  li a0, 1884
  xori a0, a0, 269
  addi a0, a0, 9
  ret
.align 6
func270:
  li a0, 1891
  xori a0, a0, 270
  addi a0, a0, 10
  ret
.align 6
func271:
  li a0, 1898
  xori a0, a0, 271
  addi a0, a0, 11
  ret
.align 6
func272:
  li a0, 1905
  xori a0, a0, 272
  addi a0, a0, 12
  ret
.align 6
func273:
  li a0, 1912
  xori a0, a0, 273
  addi a0, a0, 0
  ret
.align 6
func274:
  li a0, 1919
  xori a0, a0, 274
  addi a0, a0, 1
  ret
.align 6
func275:
  li a0, 1926
  xori a0, a0, 275
  addi a0, a0, 2
  ret
.align 6
func276:
  li a0, 1933
  xori a0, a0, 276
  addi a0, a0, 3
  ret
.align 6
func277:
  li a0, 1940
  xori a0, a0, 277
  addi a0, a0, 4
  ret
.align 6
func278:
  li a0, 1947
  xori a0, a0, 278
  addi a0, a0, 5
  ret
.align 6
func279:
  li a0, 1954
  xori a0, a0, 279
  addi a0, a0, 6
  ret
.align 6
func280:
  li a0, 1961
  xori a0, a0, 280
  addi a0, a0, 7
  ret
.align 6
func281:
  li a0, 1968
  xori a0, a0, 281
  addi a0, a0, 8
  ret
.align 6
func282:
  li a0, 1975
  xori a0, a0, 282
  addi a0, a0, 9
  ret
.align 6
func283:
  li a0, 1982
  xori a0, a0, 283
  addi a0, a0, 10
  ret
.align 6
func284:
  li a0, 1989
  xori a0, a0, 284
  addi a0, a0, 11
  ret
.align 6
func285:
  li a0, 1996
  xori a0, a0, 285
  addi a0, a0, 12
  ret
.align 6
func286:
  li a0, 2003
  xori a0, a0, 286
  addi a0, a0, 0
  ret
.align 6
func287:
  li a0, 2010
  xori a0, a0, 287
  addi a0, a0, 1
  ret
.align 6
func288:
  li a0, 2017
  xori a0, a0, 288
  addi a0, a0, 2
  ret
.align 6
func289:
  li a0, 2024
  xori a0, a0, 289
  addi a0, a0, 3
  ret
.align 6
func290:
  li a0, 2031
  xori a0, a0, 290
  addi a0, a0, 4
  ret
.align 6
func291:
  li a0, 2038
  xori a0, a0, 291
  addi a0, a0, 5
  ret
.align 6
func292:
  li a0, 2045
  xori a0, a0, 292
  addi a0, a0, 6
  ret
.align 6
func293:
  li a0, 2052
  xori a0, a0, 293
  addi a0, a0, 7
  ret
.align 6
func294:
  li a0, 2059
  xori a0, a0, 294
  addi a0, a0, 8
  ret
.align 6
func295:
  li a0, 2066
  xori a0, a0, 295
  addi a0, a0, 9
  ret
.align 6
func296:
  li a0, 2073
  xori a0, a0, 296
  addi a0, a0, 10
  ret
.align 6
func297:
  li a0, 2080
  xori a0, a0, 297
  addi a0, a0, 11
  ret
.align 6
func298:
  li a0, 2087
  xori a0, a0, 298
  addi a0, a0, 12
  ret
.align 6
func299:
  li a0, 2094
  xori a0, a0, 299
  addi a0, a0, 0
  ret
.align 6
func300:
  li a0, 2101
  xori a0, a0, 300
  addi a0, a0, 1
  ret
.align 6
func301:
  li a0, 2108
  xori a0, a0, 301
  addi a0, a0, 2
  ret
.align 6
func302:
  li a0, 2115
  xori a0, a0, 302
  addi a0, a0, 3
  ret
.align 6
func303:
  li a0, 2122
  xori a0, a0, 303
  addi a0, a0, 4
  ret
.align 6
func304:
  li a0, 2129
  xori a0, a0, 304
  addi a0, a0, 5
  ret
.align 6
func305:
  li a0, 2136
  xori a0, a0, 305
  addi a0, a0, 6
  ret
.align 6
func306:
  li a0, 2143
  xori a0, a0, 306
  addi a0, a0, 7
  ret
.align 6
func307:
  li a0, 2150
  xori a0, a0, 307
  addi a0, a0, 8
  ret
.align 6
func308:
  li a0, 2157
  xori a0, a0, 308
  addi a0, a0, 9
  ret
.align 6
func309:
  li a0, 2164
  xori a0, a0, 309
  addi a0, a0, 10
  ret
.align 6
func310:
  li a0, 2171
  xori a0, a0, 310
  addi a0, a0, 11
  ret
.align 6
func311:
  li a0, 2178
  xori a0, a0, 311
  addi a0, a0, 12
  ret
.align 6
func312:
  li a0, 2185
  xori a0, a0, 312
  addi a0, a0, 0
  ret
.align 6
func313:
  li a0, 2192
  xori a0, a0, 313
  addi a0, a0, 1
  ret
.align 6
func314:
  li a0, 2199
  xori a0, a0, 314
  addi a0, a0, 2
  ret
.align 6
func315:
  li a0, 2206
  xori a0, a0, 315
  addi a0, a0, 3
  ret
.align 6
func316:
  li a0, 2213
  xori a0, a0, 316
  addi a0, a0, 4
  ret
.align 6
func317:
  li a0, 2220
  xori a0, a0, 317
  addi a0, a0, 5
  ret
.align 6
func318:
  li a0, 2227
  xori a0, a0, 318
  addi a0, a0, 6
  ret
.align 6
func319:
  li a0, 2234
  xori a0, a0, 319
  addi a0, a0, 7
  ret
.align 6
func320:
  li a0, 2241
  xori a0, a0, 320
  addi a0, a0, 8
  ret
.align 6
func321:
  li a0, 2248
  xori a0, a0, 321
  addi a0, a0, 9
  ret
.align 6
func322:
  li a0, 2255
  xori a0, a0, 322
  addi a0, a0, 10
  ret
.align 6
func323:
  li a0, 2262
  xori a0, a0, 323
  addi a0, a0, 11
  ret
.align 6
func324:
  li a0, 2269
  xori a0, a0, 324
  addi a0, a0, 12
  ret
.align 6
func325:
  li a0, 2276
  xori a0, a0, 325
  addi a0, a0, 0
  ret
.align 6
func326:
  li a0, 2283
  xori a0, a0, 326
  addi a0, a0, 1
  ret
.align 6
func327:
  li a0, 2290
  xori a0, a0, 327
  addi a0, a0, 2
  ret
.align 6
func328:
  li a0, 2297
  xori a0, a0, 328
  addi a0, a0, 3
  ret
.align 6
func329:
  li a0, 2304
  xori a0, a0, 329
  addi a0, a0, 4
  ret
.align 6
func330:
  li a0, 2311
  xori a0, a0, 330
  addi a0, a0, 5
  ret
.align 6
func331:
  li a0, 2318
  xori a0, a0, 331
  addi a0, a0, 6
  ret
.align 6
func332:
  li a0, 2325
  xori a0, a0, 332
  addi a0, a0, 7
  ret
.align 6
func333:
  li a0, 2332
  xori a0, a0, 333
  addi a0, a0, 8
  ret
.align 6
func334:
  li a0, 2339
  xori a0, a0, 334
  addi a0, a0, 9
  ret
.align 6
func335:
  li a0, 2346
  xori a0, a0, 335
  addi a0, a0, 10
  ret
.align 6
func336:
  li a0, 2353
  xori a0, a0, 336
  addi a0, a0, 11
  ret
.align 6
func337:
  li a0, 2360
  xori a0, a0, 337
  addi a0, a0, 12
  ret
.align 6
func338:
  li a0, 2367
  xori a0, a0, 338
  addi a0, a0, 0
  ret
.align 6
func339:
  li a0, 2374
  xori a0, a0, 339
  addi a0, a0, 1
  ret
.align 6
func340:
  li a0, 2381
  xori a0, a0, 340
  addi a0, a0, 2
  ret
.align 6
func341:
  li a0, 2388
  xori a0, a0, 341
  addi a0, a0, 3
  ret
.align 6
func342:
  li a0, 2395
  xori a0, a0, 342
  addi a0, a0, 4
  ret
.align 6
func343:
  li a0, 2402
  xori a0, a0, 343
  addi a0, a0, 5
  ret
.align 6
func344:
  li a0, 2409
  xori a0, a0, 344
  addi a0, a0, 6
  ret
.align 6
func345:
  li a0, 2416
  xori a0, a0, 345
  addi a0, a0, 7
  ret
.align 6
func346:
  li a0, 2423
  xori a0, a0, 346
  addi a0, a0, 8
  ret
.align 6
func347:
  li a0, 2430
  xori a0, a0, 347
  addi a0, a0, 9
  ret
.align 6
func348:
  li a0, 2437
  xori a0, a0, 348
  addi a0, a0, 10
  ret
.align 6
func349:
  li a0, 2444
  xori a0, a0, 349
  addi a0, a0, 11
  ret
.align 6
func350:
  li a0, 2451
  xori a0, a0, 350
  addi a0, a0, 12
  ret
.align 6
func351:
  li a0, 2458
  xori a0, a0, 351
  addi a0, a0, 0
  ret
.align 6
func352:
  li a0, 2465
  xori a0, a0, 352
  addi a0, a0, 1
  ret
.align 6
func353:
  li a0, 2472
  xori a0, a0, 353
  addi a0, a0, 2
  ret
.align 6
func354:
  li a0, 2479
  xori a0, a0, 354
  addi a0, a0, 3
  ret
.align 6
func355:
  li a0, 2486
  xori a0, a0, 355
  addi a0, a0, 4
  ret
.align 6
func356:
  li a0, 2493
  xori a0, a0, 356
  addi a0, a0, 5
  ret
.align 6
func357:
  li a0, 2500
  xori a0, a0, 357
  addi a0, a0, 6
  ret
.align 6
func358:
  li a0, 2507
  xori a0, a0, 358
  addi a0, a0, 7
  ret
.align 6
func359:
  li a0, 2514
  xori a0, a0, 359
  addi a0, a0, 8
  ret
.align 6
func360:
  li a0, 2521
  xori a0, a0, 360
  addi a0, a0, 9
  ret
.align 6
func361:
  li a0, 2528
  xori a0, a0, 361
  addi a0, a0, 10
  ret
.align 6
func362:
  li a0, 2535
  xori a0, a0, 362
  addi a0, a0, 11
  ret
.align 6
func363:
  li a0, 2542
  xori a0, a0, 363
  addi a0, a0, 12
  ret
.align 6
func364:
  li a0, 2549
  xori a0, a0, 364
  addi a0, a0, 0
  ret
.align 6
func365:
  li a0, 2556
  xori a0, a0, 365
  addi a0, a0, 1
  ret
.align 6
func366:
  li a0, 2563
  xori a0, a0, 366
  addi a0, a0, 2
  ret
.align 6
func367:
  li a0, 2570
  xori a0, a0, 367
  addi a0, a0, 3
  ret
.align 6
func368:
  li a0, 2577
  xori a0, a0, 368
  addi a0, a0, 4
  ret
.align 6
func369:
  li a0, 2584
  xori a0, a0, 369
  addi a0, a0, 5
  ret
.align 6
func370:
  li a0, 2591
  xori a0, a0, 370
  addi a0, a0, 6
  ret
.align 6
func371:
  li a0, 2598
  xori a0, a0, 371
  addi a0, a0, 7
  ret
.align 6
func372:
  li a0, 2605
  xori a0, a0, 372
  addi a0, a0, 8
  ret
.align 6
func373:
  li a0, 2612
  xori a0, a0, 373
  addi a0, a0, 9
  ret
.align 6
func374:
  li a0, 2619
  xori a0, a0, 374
  addi a0, a0, 10
  ret
.align 6
func375:
  li a0, 2626
  xori a0, a0, 375
  addi a0, a0, 11
  ret
.align 6
func376:
  li a0, 2633
  xori a0, a0, 376
  addi a0, a0, 12
  ret
.align 6
func377:
  li a0, 2640
  xori a0, a0, 377
  addi a0, a0, 0
  ret
.align 6
func378:
  li a0, 2647
  xori a0, a0, 378
  addi a0, a0, 1
  ret
.align 6
func379:
  li a0, 2654
  xori a0, a0, 379
  addi a0, a0, 2
  ret
.align 6
func380:
  li a0, 2661
  xori a0, a0, 380
  addi a0, a0, 3
  ret
.align 6
func381:
  li a0, 2668
  xori a0, a0, 381
  addi a0, a0, 4
  ret
.align 6
func382:
  li a0, 2675
  xori a0, a0, 382
  addi a0, a0, 5
  ret
.align 6
func383:
  li a0, 2682
  xori a0, a0, 383
  addi a0, a0, 6
  ret
.align 6
tohost:
  .dword 0, 0
.align 6
fromhost:
  .dword 0, 0
.align 4
ftable:
  .octa func0
  .octa func1
  .octa func2
  .octa func3
  .octa func4
  .octa func5
  .octa func6
  .octa func7
  .octa func8
  .octa func9
  .octa func10
  .octa func11
  .octa func12
  .octa func13
  .octa func14
  .octa func15
  .octa func16
  .octa func17
  .octa func18
  .octa func19
  .octa func20
  .octa func21
  .octa func22
  .octa func23
  .octa func24
  .octa func25
  .octa func26
  .octa func27
  .octa func28
  .octa func29
  .octa func30
  .octa func31
  .octa func32
  .octa func33
  .octa func34
  .octa func35
  .octa func36
  .octa func37
  .octa func38
  .octa func39
  .octa func40
  .octa func41
  .octa func42
  .octa func43
  .octa func44
  .octa func45
  .octa func46
  .octa func47
  .octa func48
  .octa func49
  .octa func50
  .octa func51
  .octa func52
  .octa func53
  .octa func54
  .octa func55
  .octa func56
  .octa func57
  .octa func58
  .octa func59
  .octa func60
  .octa func61
  .octa func62
  .octa func63
  .octa func64
  .octa func65
  .octa func66
  .octa func67
  .octa func68
  .octa func69
  .octa func70
  .octa func71
  .octa func72
  .octa func73
  .octa func74
  .octa func75
  .octa func76
  .octa func77
  .octa func78
  .octa func79
  .octa func80
  .octa func81
  .octa func82
  .octa func83
  .octa func84
  .octa func85
  .octa func86
  .octa func87
  .octa func88
  .octa func89
  .octa func90
  .octa func91
  .octa func92
  .octa func93
  .octa func94
  .octa func95
  .octa func96
  .octa func97
  .octa func98
  .octa func99
  .octa func100
  .octa func101
  .octa func102
  .octa func103
  .octa func104
  .octa func105
  .octa func106
  .octa func107
  .octa func108
  .octa func109
  .octa func110
  .octa func111
  .octa func112
  .octa func113
  .octa func114
  .octa func115
  .octa func116
  .octa func117
  .octa func118
  .octa func119
  .octa func120
  .octa func121
  .octa func122
  .octa func123
  .octa func124
  .octa func125
  .octa func126
  .octa func127
  .octa func128
  .octa func129
  .octa func130
  .octa func131
  .octa func132
  .octa func133
  .octa func134
  .octa func135
  .octa func136
  .octa func137
  .octa func138
  .octa func139
  .octa func140
  .octa func141
  .octa func142
  .octa func143
  .octa func144
  .octa func145
  .octa func146
  .octa func147
  .octa func148
  .octa func149
  .octa func150
  .octa func151
  .octa func152
  .octa func153
  .octa func154
  .octa func155
  .octa func156
  .octa func157
  .octa func158
  .octa func159
  .octa func160
  .octa func161
  .octa func162
  .octa func163
  .octa func164
  .octa func165
  .octa func166
  .octa func167
  .octa func168
  .octa func169
  .octa func170
  .octa func171
  .octa func172
  .octa func173
  .octa func174
  .octa func175
  .octa func176
  .octa func177
  .octa func178
  .octa func179
  .octa func180
  .octa func181
  .octa func182
  .octa func183
  .octa func184
  .octa func185
  .octa func186
  .octa func187
  .octa func188
  .octa func189
  .octa func190
  .octa func191
  .octa func192
  .octa func193
  .octa func194
  .octa func195
  .octa func196
  .octa func197
  .octa func198
  .octa func199
  .octa func200
  .octa func201
  .octa func202
  .octa func203
  .octa func204
  .octa func205
  .octa func206
  .octa func207
  .octa func208
  .octa func209
  .octa func210
  .octa func211
  .octa func212
  .octa func213
  .octa func214
  .octa func215
  .octa func216
  .octa func217
  .octa func218
  .octa func219
  .octa func220
  .octa func221
  .octa func222
  .octa func223
  .octa func224
  .octa func225
  .octa func226
  .octa func227
  .octa func228
  .octa func229
  .octa func230
  .octa func231
  .octa func232
  .octa func233
  .octa func234
  .octa func235
  .octa func236
  .octa func237
  .octa func238
  .octa func239
  .octa func240
  .octa func241
  .octa func242
  .octa func243
  .octa func244
  .octa func245
  .octa func246
  .octa func247
  .octa func248
  .octa func249
  .octa func250
  .octa func251
  .octa func252
  .octa func253
  .octa func254
  .octa func255
  .octa func256
  .octa func257
  .octa func258
  .octa func259
  .octa func260
  .octa func261
  .octa func262
  .octa func263
  .octa func264
  .octa func265
  .octa func266
  .octa func267
  .octa func268
  .octa func269
  .octa func270
  .octa func271
  .octa func272
  .octa func273
  .octa func274
  .octa func275
  .octa func276
  .octa func277
  .octa func278
  .octa func279
  .octa func280
  .octa func281
  .octa func282
  .octa func283
  .octa func284
  .octa func285
  .octa func286
  .octa func287
  .octa func288
  .octa func289
  .octa func290
  .octa func291
  .octa func292
  .octa func293
  .octa func294
  .octa func295
  .octa func296
  .octa func297
  .octa func298
  .octa func299
  .octa func300
  .octa func301
  .octa func302
  .octa func303
  .octa func304
  .octa func305
  .octa func306
  .octa func307
  .octa func308
  .octa func309
  .octa func310
  .octa func311
  .octa func312
  .octa func313
  .octa func314
  .octa func315
  .octa func316
  .octa func317
  .octa func318
  .octa func319
  .octa func320
  .octa func321
  .octa func322
  .octa func323
  .octa func324
  .octa func325
  .octa func326
  .octa func327
  .octa func328
  .octa func329
  .octa func330
  .octa func331
  .octa func332
  .octa func333
  .octa func334
  .octa func335
  .octa func336
  .octa func337
  .octa func338
  .octa func339
  .octa func340
  .octa func341
  .octa func342
  .octa func343
  .octa func344
  .octa func345
  .octa func346
  .octa func347
  .octa func348
  .octa func349
  .octa func350
  .octa func351
  .octa func352
  .octa func353
  .octa func354
  .octa func355
  .octa func356
  .octa func357
  .octa func358
  .octa func359
  .octa func360
  .octa func361
  .octa func362
  .octa func363
  .octa func364
  .octa func365
  .octa func366
  .octa func367
  .octa func368
  .octa func369
  .octa func370
  .octa func371
  .octa func372
  .octa func373
  .octa func374
  .octa func375
  .octa func376
  .octa func377
  .octa func378
  .octa func379
  .octa func380
  .octa func381
  .octa func382
  .octa func383
.align 12
databuf:
  .zero 65536
  .zero 4096
stack_top:
