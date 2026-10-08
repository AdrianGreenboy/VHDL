.section .text._start
.global _start
_start:
    li   sp, 0x00000190     /* pila bajo la palabra 100; resultados 103..127 */
    call main
1:  j 1b
