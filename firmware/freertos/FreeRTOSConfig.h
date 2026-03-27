#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

/* =====================================================================
 * FreeRTOS configuration for PicoRV32 SoC (AX301, 50 MHz, 8 KB SRAM)
 * ===================================================================== */

/* Core */
#define configUSE_PREEMPTION                    1
#define configUSE_IDLE_HOOK                     0
#define configUSE_TICK_HOOK                     0
#define configCPU_CLOCK_HZ                      ( ( unsigned long ) 50000000 )
#define configTICK_RATE_HZ                      ( ( TickType_t ) 100 )
#define configMAX_PRIORITIES                    5
#define configMINIMAL_STACK_SIZE                ( ( unsigned short ) 128 ) /* words */
#define configTOTAL_HEAP_SIZE                   ( ( size_t ) ( 4 * 1024 ) )
#define configMAX_TASK_NAME_LEN                 8
#define configUSE_TRACE_FACILITY                0
#define configUSE_16_BIT_TICKS                  0
#define configIDLE_SHOULD_YIELD                 1
#define configUSE_MUTEXES                       0
#define configQUEUE_REGISTRY_SIZE               0
#define configCHECK_FOR_STACK_OVERFLOW          0
#define configUSE_RECURSIVE_MUTEXES             0
#define configUSE_MALLOC_FAILED_HOOK            0
#define configUSE_APPLICATION_TASK_TAG          0
#define configUSE_COUNTING_SEMAPHORES           0
#define configGENERATE_RUN_TIME_STATS           0
#define configUSE_TASK_NOTIFICATIONS            1
#define configTASK_NOTIFICATION_ARRAY_ENTRIES   1

/* Software timer: disabled to save code size */
#define configUSE_TIMERS                        0

/* PicoRV32 has no CLINT / MTIME registers; timer is via custom instruction */
#define configMTIME_BASE_ADDRESS                ( 0 )
#define configMTIMECMP_BASE_ADDRESS             ( 0 )

/* ISR stack size (words) — separate stack for interrupt handlers */
#define configISR_STACK_SIZE_WORDS              128

/* Optional API */
#define INCLUDE_vTaskPrioritySet                1
#define INCLUDE_uxTaskPriorityGet               1
#define INCLUDE_vTaskDelete                     1
#define INCLUDE_vTaskCleanUpResources           0
#define INCLUDE_vTaskSuspend                    1
#define INCLUDE_vTaskDelayUntil                 1
#define INCLUDE_vTaskDelay                      1
#define INCLUDE_xTaskGetSchedulerState          1

/* Assert: hang on failure */
#define configASSERT( x )   do { if( ( x ) == 0 ) { for(;;); } } while(0)

#endif /* FREERTOS_CONFIG_H */
