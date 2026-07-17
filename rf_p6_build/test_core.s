; programa de prueba del core: aritmetica + memoria + saltos
start:
    addi t0, zero, 10
    addi t1, zero, 20
    add  t2, t0, t1     ; t2 = 30
    sub  t3, t1, t0     ; t3 = 10
    slli t4, t0, 2      ; t4 = 40
    ; guardar en dmem 0x100
    addi s0, zero, 0x100
    sw   t2, 0(s0)      ; [0x100] = 30
    sw   t4, 4(s0)      ; [0x104] = 40
    lw   s1, 0(s0)      ; s1 = 30
    ; bucle: sumar 1..5
    addi a0, zero, 0    ; acc
    addi a1, zero, 1    ; i
    addi a2, zero, 6    ; limite
loop:
    add  a0, a0, a1
    addi a1, a1, 1
    blt  a1, a2, loop   ; while i<6
    sw   a0, 8(s0)      ; [0x108] = 15
    mul  a3, t0, t1     ; 200
    sw   a3, 12(s0)     ; [0x10C] = 200
    ecall
