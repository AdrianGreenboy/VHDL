/* init.c - RTEMS 6.2 self-checking test for the RV128IMAC SoC (RV64 mode, M4).
 *
 * Classic API paths that matter for the core: clock tick (CLINT MTI), context switches,
 * ISR-level services from a timer service routine, message queue, binary semaphore with
 * priority inheritance, counting semaphore, events, rate monotonic periods. A checker
 * task verifies the results and calls exit(); a fatal extension turns the exit status
 * (or any other fatal error) into the tohost verdict: 1 = PASS, (code << 1) | 1 = FAIL.
 * RTEMS: a lower number is a higher priority.
 * Output goes through printk (polled 16550): no console driver, so termios never runs the
 * UART in interrupt mode (the testbench UART stubs raise no interrupts, and tb_soc loops
 * TX back to RX).
 */
#include <rtems.h>
#include <rtems/bspIo.h>
#include <stdlib.h>

extern volatile uint64_t tohost;          /* bsps/riscv/riscv/console/htif.c */

#define N_ITEMS       200U
#define TIMER_PERIOD  2U                  /* ticks */
#define RATE_PERIOD   3U
#define RATE_ROUNDS   6U
#define RUN_TICKS     25U
#define MAX_TICKS     400U

#define PRIO_CHECK    2
#define PRIO_RATE     3
#define PRIO_HIGH     4
#define PRIO_WAITER   5
#define PRIO_PRODCONS 6
#define PRIO_LOW      7

static rtems_id q, mtx, sem, tmr, waiter_id, inh_high_id;
static volatile uint32_t q_sum, q_count, q_done;
static volatile uint32_t timer_count, sem_taken, events_got;
static volatile uint32_t inh_prio_held, inh_prio_after, inh_done;
static volatile uint32_t rate_ok, rate_rounds;
static volatile int timer_stop;

static void fatal_ext(rtems_fatal_source source, bool always_false, rtems_fatal_code code)
{
  uint64_t v;
  (void) always_false;
  if (source == RTEMS_FATAL_SOURCE_EXIT && code == 0) {
    v = 1;
  } else if (source == RTEMS_FATAL_SOURCE_EXIT) {
    v = ((uint64_t) (code & 0xffff) << 1) | 1;
  } else {                                 /* other fatal sources: 0x1000 + source */
    v = ((uint64_t) (0x1000 + (source & 0xff)) << 1) | 1;
  }
  tohost = v;
  for (;;) {
  }
}

static void check(rtems_status_code sc, int where)
{
  if (sc != RTEMS_SUCCESSFUL) {
    printk("status %d at %d\n", (int) sc, where);
    exit(2);
  }
}

static rtems_task producer(rtems_task_argument a)
{
  (void) a;
  for (uint32_t i = 0; i < N_ITEMS; i++) {
    uint32_t v = i * 3U + 1U;
    check(rtems_message_queue_send(q, &v, sizeof(v)), 10);
    if ((i & 31U) == 0U) {
      rtems_task_wake_after(RTEMS_YIELD_PROCESSOR);
    }
  }
  rtems_task_exit();
}

static rtems_task consumer(rtems_task_argument a)
{
  (void) a;
  for (uint32_t i = 0; i < N_ITEMS; i++) {
    uint32_t v;
    size_t sz;
    check(rtems_message_queue_receive(q, &v, &sz, RTEMS_WAIT, RTEMS_NO_TIMEOUT), 11);
    if (sz == sizeof(v)) {
      q_sum += v;
      q_count++;
    }
  }
  q_done = 1;
  rtems_task_exit();
}

/* priority inheritance: the low task holds mtx and wakes the high one, which blocks on
 * mtx; the low task must now run at the high priority, and drop back after release */
static rtems_task inh_high(rtems_task_argument a)
{
  rtems_event_set ev;
  (void) a;
  check(rtems_event_receive(RTEMS_EVENT_1, RTEMS_EVENT_ANY | RTEMS_WAIT, RTEMS_NO_TIMEOUT, &ev), 20);
  check(rtems_semaphore_obtain(mtx, RTEMS_WAIT, RTEMS_NO_TIMEOUT), 21);
  check(rtems_semaphore_release(mtx), 22);
  inh_done = 1;
  rtems_task_exit();
}

static rtems_task inh_low(rtems_task_argument a)
{
  rtems_id sched;
  rtems_task_priority p;
  (void) a;
  check(rtems_task_get_scheduler(RTEMS_SELF, &sched), 23);
  check(rtems_semaphore_obtain(mtx, RTEMS_WAIT, RTEMS_NO_TIMEOUT), 24);
  check(rtems_event_send(inh_high_id, RTEMS_EVENT_1), 25);   /* high runs, blocks, we inherit */
  check(rtems_task_get_priority(RTEMS_SELF, sched, &p), 26);
  inh_prio_held = p;
  check(rtems_semaphore_release(mtx), 27);                  /* high runs and finishes first */
  check(rtems_task_get_priority(RTEMS_SELF, sched, &p), 28);
  inh_prio_after = p;
  rtems_task_exit();
}

/* timer service routine (interrupt context): counts, releases the counting semaphore,
 * sends an event, re-arms itself */
static rtems_timer_service_routine tick_tsr(rtems_id id, void *arg)
{
  (void) arg;
  timer_count++;
  rtems_semaphore_release(sem);
  rtems_event_send(waiter_id, RTEMS_EVENT_0);
  if (!timer_stop) {
    rtems_timer_fire_after(id, TIMER_PERIOD, tick_tsr, NULL);
  }
}

static rtems_task waiter(rtems_task_argument a)
{
  (void) a;
  for (;;) {
    rtems_event_set ev;
    if (rtems_semaphore_obtain(sem, RTEMS_NO_WAIT, 0) == RTEMS_SUCCESSFUL) {
      sem_taken++;
      continue;
    }
    if (rtems_event_receive(RTEMS_EVENT_0, RTEMS_EVENT_ANY | RTEMS_WAIT, RTEMS_NO_TIMEOUT, &ev) ==
        RTEMS_SUCCESSFUL) {
      events_got++;                        /* several sends before a receive count once */
    }
  }
}

static rtems_task rate(rtems_task_argument a)
{
  rtems_id period;
  rtems_interval first;
  (void) a;
  check(rtems_rate_monotonic_create(rtems_build_name('R', 'M', 'O', 'N'), &period), 30);
  check(rtems_rate_monotonic_period(period, RATE_PERIOD), 31);       /* starts the period */
  first = rtems_clock_get_ticks_since_boot();
  for (uint32_t i = 1; i <= RATE_ROUNDS; i++) {
    rtems_status_code sc = rtems_rate_monotonic_period(period, RATE_PERIOD);
    if (sc == RTEMS_SUCCESSFUL && rtems_clock_get_ticks_since_boot() == first + i * RATE_PERIOD) {
      rate_ok++;
    }
    rate_rounds++;
  }
  rtems_rate_monotonic_delete(period);
  rtems_task_exit();
}

static void line(const char *name, uint32_t got, uint32_t want, int ok)
{
  printk("  %s %s: %u (expected %u)\n", ok ? "ok  " : "FAIL", name, (unsigned) got, (unsigned) want);
}

static rtems_task checker(rtems_task_argument a)
{
  (void) a;
  rtems_task_wake_after(RUN_TICKS);
  while (!(q_done && inh_done && inh_prio_after && rate_rounds == RATE_ROUNDS) &&
         rtems_clock_get_ticks_since_boot() < MAX_TICKS) {
    rtems_task_wake_after(10);
  }
  timer_stop = 1;
  rtems_task_wake_after(TIMER_PERIOD + 2U);  /* the last firing does not re-arm */
  rtems_interval t_stop = rtems_clock_get_ticks_since_boot();
  rtems_task_wake_after(3);                  /* let the waiter drain */

  uint32_t want_sum = 0;
  for (uint32_t i = 0; i < N_ITEMS; i++) {
    want_sum += i * 3U + 1U;
  }
  uint32_t texp = (uint32_t) (t_stop / TIMER_PERIOD);
  int ok_q = q_count == N_ITEMS && q_sum == want_sum;
  int ok_i = inh_done && inh_prio_held == PRIO_HIGH && inh_prio_after == PRIO_LOW;
  int ok_t = timer_count + 3U >= texp && timer_count <= texp + 1U;
  int ok_s = sem_taken == timer_count;
  int ok_e = events_got >= 1U && events_got <= timer_count;
  int ok_r = rate_ok == RATE_ROUNDS && rate_rounds == RATE_ROUNDS;
  int ok_k = t_stop >= RUN_TICKS && t_stop < MAX_TICKS;

  printk("\nRTEMS %s on RV128IMAC (RV64 mode)\n", rtems_version());
  line("queue items", q_count, N_ITEMS, ok_q);
  line("queue sum", q_sum, want_sum, ok_q);
  line("inherited priority", inh_prio_held, PRIO_HIGH, ok_i);
  line("priority after release", inh_prio_after, PRIO_LOW, ok_i);
  line("timer routines", timer_count, texp, ok_t);
  line("semaphore takes", sem_taken, timer_count, ok_s);
  line("event receptions", events_got, timer_count, ok_e);
  line("rate periods on time", rate_ok, RATE_ROUNDS, ok_r);
  line("ticks at timer stop", (uint32_t) t_stop, RUN_TICKS, ok_k);
  int ok = ok_q && ok_i && ok_t && ok_s && ok_e && ok_r && ok_k;
  printk(ok ? "RTEMS PASS\n" : "RTEMS FAIL\n");
  exit(ok ? 0 : 10);
}

static rtems_id start(const char *nm, rtems_task_priority prio, rtems_task_entry entry)
{
  rtems_id id;
  check(rtems_task_create(rtems_build_name(nm[0], nm[1], nm[2], nm[3]), prio,
                          RTEMS_MINIMUM_STACK_SIZE * 2, RTEMS_DEFAULT_MODES,
                          RTEMS_DEFAULT_ATTRIBUTES, &id), 1);
  check(rtems_task_start(id, entry, 0), 2);
  return id;
}

static rtems_task Init(rtems_task_argument a)
{
  (void) a;
  printk("RTEMS: Init\n");
  check(rtems_message_queue_create(rtems_build_name('Q', 'U', 'E', 'U'), 8, sizeof(uint32_t),
                                   RTEMS_FIFO, &q), 3);
  check(rtems_semaphore_create(rtems_build_name('M', 'U', 'T', 'X'), 1,
                               RTEMS_BINARY_SEMAPHORE | RTEMS_PRIORITY | RTEMS_INHERIT_PRIORITY,
                               0, &mtx), 4);
  check(rtems_semaphore_create(rtems_build_name('C', 'S', 'E', 'M'), 0,
                               RTEMS_COUNTING_SEMAPHORE | RTEMS_FIFO, 0, &sem), 5);
  check(rtems_timer_create(rtems_build_name('T', 'M', 'R', '1'), &tmr), 6);

  inh_high_id = start("IHIG", PRIO_HIGH, inh_high);
  waiter_id = start("WAIT", PRIO_WAITER, waiter);
  start("PROD", PRIO_PRODCONS, producer);
  start("CONS", PRIO_PRODCONS, consumer);
  start("ILOW", PRIO_LOW, inh_low);
  start("RATE", PRIO_RATE, rate);
  start("CHEK", PRIO_CHECK, checker);
  check(rtems_timer_fire_after(tmr, TIMER_PERIOD, tick_tsr, NULL), 7);
  rtems_task_exit();
}

#define CONFIGURE_APPLICATION_NEEDS_CLOCK_DRIVER
#define CONFIGURE_APPLICATION_DOES_NOT_NEED_CONSOLE_DRIVER
#define CONFIGURE_MICROSECONDS_PER_TICK        10000   /* 10000 mtime ticks, as FreeRTOS */
#define CONFIGURE_MAXIMUM_TASKS                10
#define CONFIGURE_MAXIMUM_SEMAPHORES           4
#define CONFIGURE_MAXIMUM_MESSAGE_QUEUES       2
#define CONFIGURE_MAXIMUM_TIMERS               2
#define CONFIGURE_MAXIMUM_PERIODS              2
#define CONFIGURE_MESSAGE_BUFFER_MEMORY \
  CONFIGURE_MESSAGE_BUFFERS_FOR_QUEUE(8, sizeof(uint32_t))
#define CONFIGURE_INITIAL_EXTENSIONS           { .fatal = fatal_ext }
#define CONFIGURE_RTEMS_INIT_TASKS_TABLE
#define CONFIGURE_INIT_TASK_PRIORITY           1
#define CONFIGURE_INIT
#include <rtems/confdefs.h>
