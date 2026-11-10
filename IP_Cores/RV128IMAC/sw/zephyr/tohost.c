/* tohost.c - HTIF-style end of run for the RV128IMAC testbenches and lockstep scripts:
 * tohost = 1 means PASS, (code << 1) | 1 means FAIL with that code. */
#include <zephyr/kernel.h>

volatile uint64_t tohost __attribute__((aligned(64), used));
volatile uint64_t fromhost __attribute__((aligned(64), used));

void rv_tohost_exit(int result)
{
	(void)arch_irq_lock();
	tohost = (result == 0) ? 1U : (((uint64_t)(unsigned int)result << 1) | 1U);
	for (;;) {
	}
}

/* fatal error (CPU exception, kernel oops, ...): end the run instead of spinning,
 * with code 100 + reason */
FUNC_NORETURN void arch_system_halt(unsigned int reason)
{
	rv_tohost_exit(100 + (int)reason);
	CODE_UNREACHABLE;
}
