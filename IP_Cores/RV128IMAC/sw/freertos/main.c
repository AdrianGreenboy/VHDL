/* main.c - FreeRTOS self-checking test for the RV128IMAC SoC (RV64 mode, M4).
 *
 * Exercises the kernel paths that matter for the core: tick interrupt (CLINT MTI),
 * ecall yield, context switch of all 31 registers, critical sections (mstatus.MIE),
 * queues, mutex with priority inheritance, counting semaphore, task notifications,
 * software timers and vTaskDelayUntil. A checker task verifies the results and ends
 * the run through tohost (1 = PASS, (code << 1) | 1 = FAIL) after printing a report
 * on the 16550 UART.
 */
#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "timers.h"

volatile uint64_t tohost __attribute__( ( section( ".tohost" ), aligned( 64 ) ) );
volatile uint64_t fromhost __attribute__( ( section( ".tohost" ), aligned( 64 ) ) );

/* ------------------------------------------------------------------ UART 16550 */
#define UART ( ( volatile uint8_t * ) 0x10000000UL )

static void uart_init( void )
{
    UART[ 3 ] = 0x80;                     /* LCR: DLAB */
    UART[ 0 ] = 1;                        /* DLL: fastest rate (simulation) */
    UART[ 1 ] = 0;                        /* DLM */
    UART[ 3 ] = 0x03;                     /* 8N1 */
    UART[ 2 ] = 0x07;                     /* FIFO on, both cleared */
}

static void putc_( char c )
{
    while( ( UART[ 5 ] & 0x20 ) == 0 )    /* LSR.THRE */
    {
    }
    UART[ 0 ] = ( uint8_t ) c;
}

static void puts_( const char * s )
{
    while( *s )
    {
        putc_( *s++ );
    }
}

static void putu( uint64_t v )
{
    char b[ 21 ];
    int i = 20;
    b[ i ] = 0;
    do
    {
        b[ --i ] = ( char ) ( '0' + v % 10 );
        v /= 10;
    } while( v );
    puts_( &b[ i ] );
}

static void line( const char * name, uint64_t got, uint64_t want, int ok )
{
    puts_( ok ? "  ok   " : "  FAIL " );
    puts_( name );
    puts_( ": " );
    putu( got );
    puts_( " (expected " );
    putu( want );
    puts_( ")\n" );
}

/* ------------------------------------------------------------------ end of run */
void finish( uint64_t code ) __attribute__( ( noreturn ) );
void finish( uint64_t code )
{
    __asm volatile ( "csrc mstatus, 8" );  /* no more interrupts */
    tohost = code ? ( ( code << 1 ) | 1 ) : 1;
    for( ; ; )
    {
    }
}

void vAssertCalled( const char * file, int l )
{
    ( void ) file;
    puts_( "assert at line " );
    putu( ( uint64_t ) l );
    puts_( "\n" );
    finish( 2 );
}

void vApplicationStackOverflowHook( TaskHandle_t t, char * name )
{
    ( void ) t;
    puts_( "stack overflow: " );
    puts_( name );
    puts_( "\n" );
    finish( 4 );
}

void vApplicationMallocFailedHook( void )
{
    puts_( "malloc failed\n" );
    finish( 5 );
}

/* unexpected trap / interrupt (the port handles ecall and MTI itself) */
void freertos_risc_v_application_exception_handler( uint64_t mcause )
{
    ( void ) mcause;
    finish( 6 );
}

void freertos_risc_v_application_interrupt_handler( uint64_t mcause )
{
    ( void ) mcause;
    finish( 7 );
}

/* ------------------------------------------------------------------ tests */
#define N_ITEMS        200U
#define N_MUTEX        20U
#define TIMER_PERIOD   2U
#define DELAY_PERIOD   3U
#define DELAY_ROUNDS   6U
#define RUN_TICKS      25U       /* minimum run; longer if the CPU budget per tick is small */
#define MAX_TICKS      400U

static QueueHandle_t q;
static SemaphoreHandle_t mtx, sem;
static TaskHandle_t notify_task;
static volatile uint64_t q_sum, q_count;
static volatile uint64_t shared, mtx_low_done, mtx_high_done, inherit_seen;
static volatile uint64_t sem_taken, notif_count, timer_count;
static volatile uint64_t delay_ok, delay_rounds, q_done;
static TaskHandle_t low_task;
static TimerHandle_t tm;

static void producer( void * p )
{
    ( void ) p;
    for( uint32_t i = 0; i < N_ITEMS; i++ )
    {
        uint32_t v = i * 3U + 1U;
        xQueueSend( q, &v, portMAX_DELAY );
        if( ( i & 31U ) == 0U )
        {
            taskYIELD();                  /* ecall path with a full context */
        }
    }
    vTaskDelete( NULL );
}

static void consumer( void * p )
{
    ( void ) p;
    for( uint32_t i = 0; i < N_ITEMS; i++ )
    {
        uint32_t v;
        if( xQueueReceive( q, &v, portMAX_DELAY ) == pdPASS )
        {
            q_sum += v;
            q_count++;
        }
    }
    q_done = 1;
    vTaskDelete( NULL );
}

/* two tasks of different priority increment a shared counter under a mutex */
static void mutex_low( void * p )
{
    ( void ) p;
    for( uint32_t i = 0; i < N_MUTEX; i++ )
    {
        xSemaphoreTake( mtx, portMAX_DELAY );
        uint64_t s = shared;
        if( ( i % 10U ) == 0U )
        {
            vTaskDelay( 1 );              /* hold the mutex across a tick */
        }
        shared = s + 1;
        xSemaphoreGive( mtx );
    }
    mtx_low_done = 1;
    vTaskDelete( NULL );
}

static void mutex_high( void * p )
{
    ( void ) p;
    for( uint32_t i = 0; i < N_MUTEX; i++ )
    {
        xSemaphoreTake( mtx, portMAX_DELAY );
        uint64_t s = shared;
        taskYIELD();
        shared = s + 1;
        xSemaphoreGive( mtx );
        vTaskDelay( 1 );
    }
    mtx_high_done = 1;
    vTaskDelete( NULL );
}

/* priority inheritance, deterministic: the low task holds mtx2 and wakes the high one,
 * which blocks on mtx2; the low task must now run at the high priority, and drop back
 * to its own after giving the mutex */
static SemaphoreHandle_t mtx2;
static TaskHandle_t inh_high_task;
static volatile uint64_t inh_prio_held, inh_prio_after, inh_high_done;

static void inh_high( void * p )
{
    ( void ) p;
    ulTaskNotifyTake( pdTRUE, portMAX_DELAY );
    xSemaphoreTake( mtx2, portMAX_DELAY );
    xSemaphoreGive( mtx2 );
    inh_high_done = 1;
    vTaskDelete( NULL );
}

static void inh_low( void * p )
{
    ( void ) p;
    xSemaphoreTake( mtx2, portMAX_DELAY );
    xTaskNotifyGive( inh_high_task );    /* high runs, blocks on mtx2, we inherit */
    inh_prio_held = uxTaskPriorityGet( NULL );
    xSemaphoreGive( mtx2 );              /* high runs and finishes before we continue */
    inh_prio_after = uxTaskPriorityGet( NULL );
    inherit_seen = inh_high_done && inh_prio_held == 3 && inh_prio_after == 1;
    vTaskDelete( NULL );
}

/* software timer: counts, gives the semaphore and notifies a task */
static void timer_cb( TimerHandle_t t )
{
    ( void ) t;
    timer_count++;
    xSemaphoreGive( sem );
    xTaskNotifyGive( notify_task );
}

static void sem_waiter( void * p )
{
    ( void ) p;
    for( ; ; )
    {
        if( xSemaphoreTake( sem, portMAX_DELAY ) == pdPASS )
        {
            sem_taken++;
        }
    }
}

static void notif_waiter( void * p )
{
    ( void ) p;
    for( ; ; )
    {
        notif_count += ulTaskNotifyTake( pdTRUE, portMAX_DELAY );   /* returns the pending count and clears it */
    }
}

/* vTaskDelayUntil: every wake-up must land exactly on the period */
static void periodic( void * p )
{
    ( void ) p;
    TickType_t last = xTaskGetTickCount();
    TickType_t first = last;
    for( uint32_t i = 1; i <= DELAY_ROUNDS; i++ )
    {
        xTaskDelayUntil( &last, DELAY_PERIOD );
        if( xTaskGetTickCount() == first + ( TickType_t ) i * DELAY_PERIOD )
        {
            delay_ok++;
        }
        delay_rounds++;
    }
    vTaskDelete( NULL );
}

static void checker( void * p )
{
    ( void ) p;
    vTaskDelay( RUN_TICKS );
    /* wait for the finite tests (with fewer cycles per tick the low-priority tasks
     * need more ticks), then stop the timer and let the waiters drain */
    while( !( q_done && mtx_low_done && mtx_high_done && delay_rounds == DELAY_ROUNDS && inherit_seen ) &&
           xTaskGetTickCount() < MAX_TICKS )
    {
        vTaskDelay( 10 );
    }
    configASSERT( xTimerStop( tm, portMAX_DELAY ) == pdPASS );
    TickType_t t_stop = xTaskGetTickCount();
    vTaskDelay( 3 );
    vTaskSuspendAll();
    TickType_t now = xTaskGetTickCount();
    uint64_t want_sum = 0;
    for( uint32_t i = 0; i < N_ITEMS; i++ )
    {
        want_sum += i * 3U + 1U;
    }
    uint64_t texp = t_stop / TIMER_PERIOD;          /* callbacks expected up to the stop */
    int ok_q = q_count == N_ITEMS && q_sum == want_sum;
    int ok_m = mtx_low_done && mtx_high_done && shared == 2U * N_MUTEX;
    int ok_i = inherit_seen > 0;
    int ok_t = timer_count + 1U >= texp && timer_count <= texp + 1U;
    int ok_s = sem_taken == timer_count;
    int ok_n = notif_count == timer_count;
    int ok_d = delay_ok == DELAY_ROUNDS && delay_rounds == DELAY_ROUNDS;
    int ok_k = t_stop >= RUN_TICKS && t_stop < MAX_TICKS && now >= t_stop + 3U && now <= t_stop + 4U;

    puts_( "\nFreeRTOS " tskKERNEL_VERSION_NUMBER " on RV128IMAC (RV64 mode)\n" );
    line( "queue items", q_count, N_ITEMS, ok_q );
    line( "queue sum", q_sum, want_sum, ok_q );
    line( "mutex counter", shared, 2U * N_MUTEX, ok_m );
    line( "inherited priority", inh_prio_held, 3, ok_i );
    line( "priority after give", inh_prio_after, 1, ok_i );
    line( "timer callbacks", timer_count, texp, ok_t );
    line( "semaphore takes", sem_taken, timer_count, ok_s );
    line( "notifications", notif_count, timer_count, ok_n );
    line( "delay-until on time", delay_ok, DELAY_ROUNDS, ok_d );
    line( "ticks at timer stop", t_stop, RUN_TICKS, ok_k );
    int ok = ok_q && ok_m && ok_i && ok_t && ok_s && ok_n && ok_d && ok_k;
    puts_( ok ? "FREERTOS PASS\n" : "FREERTOS FAIL\n" );
    finish( ok ? 0 : 10 );
}

int main( void )
{
    uart_init();
    puts_( "FreeRTOS: starting scheduler\n" );
    q = xQueueCreate( 8, sizeof( uint32_t ) );
    mtx = xSemaphoreCreateMutex();
    mtx2 = xSemaphoreCreateMutex();
    sem = xSemaphoreCreateCounting( 64, 0 );
    configASSERT( q && mtx && mtx2 && sem );
    tm = xTimerCreate( "tmr", TIMER_PERIOD, pdTRUE, NULL, timer_cb );
    configASSERT( tm );
    configASSERT( xTimerStart( tm, 0 ) == pdPASS );

    xTaskCreate( producer, "prod", configMINIMAL_STACK_SIZE, NULL, 2, NULL );
    xTaskCreate( consumer, "cons", configMINIMAL_STACK_SIZE, NULL, 2, NULL );
    xTaskCreate( mutex_low, "mlow", configMINIMAL_STACK_SIZE, NULL, 1, &low_task );
    xTaskCreate( mutex_high, "mhigh", configMINIMAL_STACK_SIZE, NULL, 3, NULL );
    xTaskCreate( inh_high, "ihigh", configMINIMAL_STACK_SIZE, NULL, 3, &inh_high_task );
    xTaskCreate( inh_low, "ilow", configMINIMAL_STACK_SIZE, NULL, 1, NULL );
    xTaskCreate( sem_waiter, "sem", configMINIMAL_STACK_SIZE, NULL, 3, NULL );
    xTaskCreate( notif_waiter, "notif", configMINIMAL_STACK_SIZE, NULL, 3, &notify_task );
    xTaskCreate( periodic, "per", configMINIMAL_STACK_SIZE, NULL, 4, NULL );
    xTaskCreate( checker, "chk", configMINIMAL_STACK_SIZE * 2, NULL, 4, NULL );
    vTaskStartScheduler();
    return 0;                             /* not reached */
}

/* ------------------------------------------------------------------ libc pieces */
void * memset( void * d, int c, size_t n )
{
    volatile uint8_t * p = d;
    while( n-- )
    {
        *p++ = ( uint8_t ) c;
    }
    return d;
}

void * memcpy( void * d, const void * s, size_t n )
{
    volatile uint8_t * p = d;
    const volatile uint8_t * q8 = s;
    while( n-- )
    {
        *p++ = *q8++;
    }
    return d;
}

size_t strlen( const char * s )
{
    size_t n = 0;
    while( s[ n ] )
    {
        n++;
    }
    return n;
}
