# init.S - /init minimo (sin libc) para validar el arranque de Linux hasta espacio
# de usuario: imprime un mensaje por /dev/console, comprueba que el reloj avanza
# (clock_gettime) y hace eco de lo que llegue por la consola.
  .globl _start
_start:
  li a0, 1
  la a1, msg
  li a2, msg_end - msg
  li a7, 64                     # write
  ecall
  # clock_gettime(CLOCK_MONOTONIC) dos veces
  li a0, 1
  la a1, ts
  li a7, 113
  ecall
  la t0, ts
  ld s0, 8(t0)
  li t1, 200000
1: addi t1, t1, -1
  bnez t1, 1b
  li a0, 1
  la a1, ts
  li a7, 113
  ecall
  la t0, ts
  ld s1, 8(t0)
  la a1, ok_t
  li a2, ok_t_end - ok_t
  bne s0, s1, 2f
  la a1, bad_t
  li a2, bad_t_end - bad_t
2:
  li a0, 1
  li a7, 64
  ecall
loop:
  li a0, 0
  la a1, buf
  li a2, 64
  li a7, 63                     # read (bloquea)
  ecall
  blez a0, loop
  mv a2, a0
  li a0, 1
  la a1, buf
  li a7, 64
  ecall
  j loop
  .data
msg: .ascii "\n*** RV64IMAC propio: Linux en espacio de usuario (/init) ***\n"
msg_end:
ok_t: .ascii "init: el reloj avanza (clock_gettime OK)\n"
ok_t_end:
bad_t: .ascii "init: el reloj NO avanza\n"
bad_t_end:
  .align 3
ts: .zero 16
buf: .zero 64
