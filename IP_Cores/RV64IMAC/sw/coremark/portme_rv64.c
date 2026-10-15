/* portme_rv64.c - soporte minimo de CoreMark en el RV64IMAC bare-metal:
 * consola por HTIF (putchar de riscv-tests) y funciones de libc que clang emite. */
#include <stddef.h>
#include <stdint.h>
extern volatile uint64_t tohost;
void uart_send_char(char c)
{
    tohost = (0x0101ULL << 48) | (uint8_t)c;
}
void *memcpy(void *d, const void *s, size_t n)
{
    char *dd = d; const char *ss = s;
    while (n--) *dd++ = *ss++;
    return d;
}
void *memset(void *d, int c, size_t n)
{
    char *dd = d;
    while (n--) *dd++ = (char)c;
    return d;
}
