# board_smoke.S - prueba de humo en placa (rv64_load board_smoke.bin empty.bin).
#   Programa la UART del SoC a 115200 baud con reloj de 50 MHz (divisor 27, el
#   mismo que el lado host del banco de control) e imprime el resultado de cada
#   comprobacion. Con D$ write-back el tohost no llega a la DDR: aqui todo sale
#   por la UART, que rv64_load muestra en la consola del A72.
#   Comprobaciones: M (mul/div/rem), A (AMO y LR/SC), C (todo el codigo es RVC),
#   caches (64 KiB escritos y releidos: 4x la D$, fuerza writebacks a la DDR),
#   CLINT (mtime avanza) y una medida de CPI de un bucle.
#define UART   0x10000000
#define CLINT  0x02000000
#define DIV    27
#define BUFSZ  (64 * 1024)
  .section .text.init
  .globl _start
_start:
  la sp, stack_top
  la t0, trap
  csrw mtvec, t0
  li s0, UART
  li t0, 0x83
  sb t0, 3(s0)                    # LCR: DLAB
  li t0, DIV
  sb t0, 0(s0)                    # DLL
  sb zero, 1(s0)                  # DLM
  li t0, 0x03
  sb t0, 3(s0)                    # 8N1
  li t0, 0x07
  sb t0, 2(s0)                    # FCR: FIFOs
  li s11, 0                       # fallos
  la a0, s_hello
  call puts
  # ---- M
  li a0, 0x123456789
  li a1, 0x1000
  mul a2, a0, a1
  li a3, 0x123456789000
  la a0, s_mul
  sub a1, a2, a3
  call check
  li a0, -1000000007
  li a1, 97
  div a2, a0, a1
  rem a3, a0, a1
  mul a4, a2, a1
  add a4, a4, a3                  # q*d + r == n
  li a0, -1000000007
  sub a1, a4, a0
  la a0, s_div
  call check
  li a0, 0xFFFFFFFFFFFFFFFF
  li a1, 0xFFFFFFFFFFFFFFFF
  mulhu a2, a0, a1                # = 0xFFFFFFFFFFFFFFFE
  li a3, 0xFFFFFFFFFFFFFFFE
  sub a1, a2, a3
  la a0, s_mulh
  call check
  # ---- A
  la s1, amo_word
  li t0, 40
  sd t0, 0(s1)
  li t1, 2
  amoadd.d t2, t1, (s1)           # t2 = 40, mem = 42
  ld t3, 0(s1)
  addi a1, t3, -42
  addi t2, t2, -40
  or a1, a1, t2
  la a0, s_amo
  call check
1:lr.d t0, (s1)
  addi t0, t0, 1
  sc.d t1, t0, (s1)
  bnez t1, 1b
  ld t0, 0(s1)
  addi a1, t0, -43
  la a0, s_lrsc
  call check
  # ---- caches: 64 KiB con patron, despues relectura (writebacks y refills reales)
  la s2, buf
  li s3, BUFSZ / 8
  li s4, 0x9E3779B97F4A7C15
  mv t0, s2
  mv t1, s3
  mv t2, s4
2:sd t2, 0(t0)
  add t2, t2, s4
  addi t0, t0, 8
  addi t1, t1, -1
  bnez t1, 2b
  mv t0, s2
  mv t1, s3
  mv t2, s4
  li a1, 0
3:ld t3, 0(t0)
  xor t3, t3, t2
  or a1, a1, t3
  add t2, t2, s4
  addi t0, t0, 8
  addi t1, t1, -1
  bnez t1, 3b
  la a0, s_cache
  call check
  # ---- CLINT: mtime avanza
  li t0, CLINT
  li t1, 0xBFF8
  add t0, t0, t1
  ld s5, 0(t0)
  li t2, 200000
4:addi t2, t2, -1
  bnez t2, 4b
  ld s6, 0(t0)
  sltu a1, s5, s6
  xori a1, a1, 1                  # 0 si mtime crecio
  la a0, s_timer
  call check
  # ---- CPI de un bucle de 6 instrucciones x 100000
  csrr s7, mcycle
  csrr s8, minstret
  li t2, 100000
  li t3, 0
5:addi t3, t3, 3
  xor t4, t3, t2
  add t3, t3, t4
  srli t3, t3, 1
  addi t2, t2, -1
  bnez t2, 5b
  csrr s9, mcycle
  csrr s10, minstret
  la a0, s_cyc
  call puts
  sub a0, s9, s7
  call puthex
  la a0, s_ret
  call puts
  sub a0, s10, s8
  call puthex
  la a0, s_nl
  call puts
  # ---- resultado
  la a0, s_pass
  beqz s11, 6f
  la a0, s_fail
6:call puts
  slli t1, s11, 1                 # tohost para simulacion (en placa se queda en la D$)
  ori t1, t1, 1
  la t0, tohost
  sd t1, 0(t0)
7:wfi
  j 7b

# check: a0 = nombre, a1 = 0 si OK
check:
  addi sp, sp, -16
  sd ra, 0(sp)
  sd a1, 8(sp)
  call puts
  ld a1, 8(sp)
  la a0, s_ok
  beqz a1, 1f
  addi s11, s11, 1
  la a0, s_bad
1:call puts
  ld ra, 0(sp)
  addi sp, sp, 16
  ret

# puts: a0 = cadena terminada en 0
puts:
1:lbu t0, 0(a0)
  beqz t0, 3f
2:lbu t1, 5(s0)                   # LSR.THRE
  andi t1, t1, 0x20
  beqz t1, 2b
  sb t0, 0(s0)
  addi a0, a0, 1
  j 1b
3:ret

# puthex: a0 = valor de 64 bit
puthex:
  li t2, 60
1:srl t0, a0, t2
  andi t0, t0, 15
  addi t0, t0, '0'
  li t1, '9' + 1
  blt t0, t1, 2f
  addi t0, t0, 'a' - '9' - 1
2:lbu t1, 5(s0)
  andi t1, t1, 0x20
  beqz t1, 2b
  sb t0, 0(s0)
  addi t2, t2, -4
  bgez t2, 1b
  ret

# cualquier trap: imprime mcause y mepc y se para
trap:
  la a0, s_trap
  call puts
  csrr a0, mcause
  call puthex
  la a0, s_sp
  call puts
  csrr a0, mepc
  call puthex
  la a0, s_nl
  call puts
1:wfi
  j 1b

  .data
s_hello: .asciz "\r\n*** RV64IMAC en silicio: prueba de humo ***\r\n"
s_mul:   .asciz "mul      "
s_div:   .asciz "div/rem  "
s_mulh:  .asciz "mulhu    "
s_amo:   .asciz "amoadd.d "
s_lrsc:  .asciz "lr/sc.d  "
s_cache: .asciz "64 KiB   "
s_timer: .asciz "mtime    "
s_ok:    .asciz "OK\r\n"
s_bad:   .asciz "FALLO\r\n"
s_cyc:   .asciz "bucle: ciclos=0x"
s_ret:   .asciz " instr=0x"
s_nl:    .asciz "\r\n"
s_sp:    .asciz " mepc=0x"
s_trap:  .asciz "\r\nTRAP mcause=0x"
s_pass:  .asciz "RESULTADO: PASS\r\n"
s_fail:  .asciz "RESULTADO: FALLO\r\n"

  .data
  .align 3
amo_word: .dword 0
  .align 6
buf: .space BUFSZ
  .align 4
  .space 2048
stack_top:

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
