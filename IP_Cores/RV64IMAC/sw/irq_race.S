# irq_race.S - carrera entre MTIP y stores a mtimecmp con MIE=1 en modo M.
# Se arma mtimecmp = mtime + k (k variable) y, unos ciclos despues, se aleja.
# Si MTIP sube cuando el store que la baja ya paso D, la instruccion joven
# inyectada con la irq llega a W con MTIP=0: el core debe re-ejecutarla en vez
# de tomar una irq que ya no existe. El oraculo es la comprobacion de legalidad
# de compare.py (toda irq tomada debe estar pendiente+habilitada en el ISS).
#define CLINT_MTIMECMP  0x02004000
#define CLINT_MTIME     0x0200BFF8
  .section .text.init
  .globl _start
_start:
  .irp r, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
  li x\r, 0
  .endr
  la    t0, handler
  csrw  mtvec, t0
  li    t0, 1 << 7
  csrw  mie, t0
  li    s0, CLINT_MTIME
  li    s1, CLINT_MTIMECMP
  li    s2, -1
  sd    s2, 0(s1)
  csrsi mstatus, 8
  li    s3, 3000
loop:
  andi  t1, s3, 3                        # k = 0..3 ticks
  addi  t1, t1, 1
  srli  t2, s3, 2
  andi  t2, t2, 15                       # 0..15 NOPs, independiente de k
  slli  t2, t2, 2
  la    t3, sled_end
  sub   t3, t3, t2
  ld    t0, 0(s0)                        # leer mtime justo antes de armar
  add   t0, t0, t1
  sd    t0, 0(s1)                        # cruzar pronto
  jr    t3
  .option push
  .option norvc
  .rept 15
  nop
  .endr
sled_end:
  .option pop
  sd    s2, 0(s1)                        # alejar: MTIP puede caer con una irq en vuelo
  addi  s4, s4, 1
  addi  s4, s4, 1
  addi  s3, s3, -1
  bnez  s3, loop
  li    t0, 1
  la    t1, tohost
  sd    t0, 0(t1)
3: j 3b

  .align 2
handler:
  sd    s2, 0(s1)
  addi  s5, s5, 1
  mret

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
