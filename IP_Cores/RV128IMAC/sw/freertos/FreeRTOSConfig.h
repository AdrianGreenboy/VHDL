/* FreeRTOSConfig.h - FreeRTOS V11.1.0 on the RV128IMAC SoC, core in RV64 mode (M4).
 * Machine mode only, CLINT tick, heap_4. The same image runs on the ISS (iss64.py),
 * tb_core / tb_cpu / tb_soc and, later, on the board. */
#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

#include <stdint.h>

/* CLINT of the SoC (same map as RV64IMAC). mtime runs at 1 MHz on the board (DTS) and
 * at clk/TIME_DIV in simulation; FreeRTOS only needs mtime ticks per RTOS tick. */
#define configMTIME_BASE_ADDRESS        ( 0x0200BFF8UL )
#define configMTIMECMP_BASE_ADDRESS     ( 0x02004000UL )
#define configCPU_CLOCK_HZ              ( 1000000UL )      /* mtime frequency */
#define configTICK_RATE_HZ              ( 100 )            /* 10000 mtime ticks per RTOS tick: 40000
                                                              * cycles at TIME_DIV 4. A tick where the
                                                              * timer task, two waiters and the periodic
                                                              * task all wake needs ~1500 instructions;
                                                              * with uncached slow memory (CPI ~6) this
                                                              * still leaves a 4x margin. */
#define configISR_STACK_SIZE_WORDS      ( 512 )

#define configUSE_PREEMPTION            1
#define configUSE_TIME_SLICING          1
#define configUSE_PORT_OPTIMISED_TASK_SELECTION 0
#define configMAX_PRIORITIES            ( 6 )
#define configMINIMAL_STACK_SIZE        ( 256 )            /* words (8 B) */
#define configMAX_TASK_NAME_LEN         ( 12 )
#define configTICK_TYPE_WIDTH_IN_BITS   TICK_TYPE_WIDTH_64_BITS
#define configIDLE_SHOULD_YIELD         1

#define configSUPPORT_DYNAMIC_ALLOCATION 1
#define configSUPPORT_STATIC_ALLOCATION  0
#define configTOTAL_HEAP_SIZE           ( 96 * 1024 )

#define configUSE_MUTEXES               1
#define configUSE_RECURSIVE_MUTEXES     1
#define configUSE_COUNTING_SEMAPHORES   1
#define configUSE_TASK_NOTIFICATIONS    1
#define configQUEUE_REGISTRY_SIZE       0
#define configUSE_TIMERS                1
#define configTIMER_TASK_PRIORITY       ( configMAX_PRIORITIES - 1 )
#define configTIMER_QUEUE_LENGTH        8
#define configTIMER_TASK_STACK_DEPTH    ( 512 )

#define configUSE_IDLE_HOOK             0
#define configUSE_TICK_HOOK             0
#define configCHECK_FOR_STACK_OVERFLOW  2
#define configUSE_MALLOC_FAILED_HOOK    1
#define configGENERATE_RUN_TIME_STATS   0
#define configUSE_TRACE_FACILITY        0
#define configUSE_STATS_FORMATTING_FUNCTIONS 0
#define configUSE_CO_ROUTINES           0

#define INCLUDE_vTaskDelay              1
#define INCLUDE_xTaskDelayUntil         1
#define INCLUDE_vTaskDelete             1
#define INCLUDE_vTaskSuspend            1
#define INCLUDE_uxTaskPriorityGet       1
#define INCLUDE_vTaskPrioritySet        1
#define INCLUDE_xTaskGetSchedulerState  1
#define INCLUDE_uxTaskGetStackHighWaterMark 1

/* A failed assert ends the run through tohost with code 2 (see main.c). */
void vAssertCalled( const char * file, int line );
#define configASSERT( x )    do { if( ( x ) == 0 ) vAssertCalled( __FILE__, __LINE__ ); } while( 0 )

#endif /* FREERTOS_CONFIG_H */
