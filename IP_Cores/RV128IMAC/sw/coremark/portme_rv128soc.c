/* portme_rv128soc.c - CoreMark support on the RV128IMAC SoC (RV64 mode): console on the
 * 16550 (polled, divisor 1 = the reset value; rv128_soc_load -d 1 on the board), and the
 * libc pieces clang emits. Unlike the RV64IMAC port, nothing goes through tohost except the
 * final verdict: the board watcher latches the first tohost write with bit0 = 1, and an
 * HTIF putchar of an odd character would look like the end of the run. */
#include <stddef.h>
#include <stdint.h>
#define UART ((volatile uint8_t *)0x10000000UL)
void uart_send_char(char c)
{
    if (c == '\n') uart_send_char('\r');
    while ((UART[5] & 0x20) == 0) { }       /* LSR.THRE */
    UART[0] = (uint8_t)c;
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
