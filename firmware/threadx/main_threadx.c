/* PicoRV32 ThreadX demo — main_threadx.c
 *
 * Three threads at different priorities print via UART at different rates.
 * The ThreadX kernel provides preemptive scheduling (100 Hz timer tick).
 *
 * UART memory map (uart_periph.v):
 *   0x80000000  W: TX byte   R: RX byte
 *   0x80000004  R: RX byte (alias)
 *   0x80000008  R: status (bit0=TX ready, bit1=RX valid)
 */

#include "tx_api.h"

/* ---- UART helpers ------------------------------------------------- */
#define UART_BASE   0x80000000UL
#define UART_TX     (*(volatile unsigned int *)(UART_BASE + 0x0))
#define UART_STATUS (*(volatile unsigned int *)(UART_BASE + 0x8))
#define UART_TX_RDY (UART_STATUS & 1)

static void uart_putchar(char c)
{
    while (!UART_TX_RDY);
    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *s)
{
    while (*s) uart_putchar(*s++);
}

static void uart_putuint(unsigned int n)
{
    char buf[12];
    int  i = 0;
    if (n == 0) { uart_putchar('0'); return; }
    while (n)   { buf[i++] = '0' + (n % 10); n /= 10; }
    while (i--) uart_putchar(buf[i]);
}

/* ---- Thread stacks and control blocks ----------------------------- */
#define STACK_SIZE       512
#define IDLE_STACK_SIZE  256

static TX_THREAD thread1;
static TX_THREAD thread2;
static TX_THREAD thread3;
static TX_THREAD idle_thread;
static ULONG     stack1[STACK_SIZE / sizeof(ULONG)];
static ULONG     stack2[STACK_SIZE / sizeof(ULONG)];
static ULONG     stack3[STACK_SIZE / sizeof(ULONG)];
static ULONG     idle_stack[IDLE_STACK_SIZE / sizeof(ULONG)];

/* ---- Thread functions --------------------------------------------- */
static void vTask1(ULONG param)
{
    unsigned int tick = 0;
    (void)param;
    for (;;)
    {
        uart_puts("TX1: tick ");
        uart_putuint(tick++);
        uart_puts("\r\n");
        tx_thread_sleep(50);    /* 50 ticks @ 100 Hz = 500 ms */
    }
}

static void vTask2(ULONG param)
{
    unsigned int tick = 0;
    (void)param;
    for (;;)
    {
        uart_puts("TX2: tick ");
        uart_putuint(tick++);
        uart_puts("\r\n");
        tx_thread_sleep(100);   /* 100 ticks = 1000 ms */
    }
}

static void vTask3(ULONG param)
{
    unsigned int tick = 0;
    (void)param;
    for (;;)
    {
        uart_puts("TX3: tick ");
        uart_putuint(tick++);
        uart_puts("\r\n");
        tx_thread_sleep(200);   /* 200 ticks = 2000 ms */
    }
}

static void vIdleTask(ULONG param)
{
    (void)param;
    /* Never sleeps — keeps execute_ptr non-NULL when all other threads sleep.
     * Timer ticks will preempt this and switch to any ready higher-priority
     * thread. */
    for (;;)
    {
        /* Could call tx_thread_relinquish() here but that generates ecall
         * storms. Just spin — preemptive timer handles thread switching. */
    }
}

/* ---- tx_application_define ----------------------------------------
 * Called by tx_kernel_enter() after _tx_initialize_low_level().
 * Create all threads and any other ThreadX objects here.           */
void tx_application_define(void *first_unused_memory)
{
    (void)first_unused_memory;

    uart_puts("\r\n== PicoRV32 ThreadX demo ==\r\n");
    uart_puts("Creating threads...\r\n");

    tx_thread_create(&thread1, "TX1",
                     vTask1, 0,
                     stack1, STACK_SIZE,
                     2,         /* priority */
                     2,         /* preemption threshold */
                     TX_NO_TIME_SLICE,
                     TX_AUTO_START);

    tx_thread_create(&thread2, "TX2",
                     vTask2, 0,
                     stack2, STACK_SIZE,
                     3,
                     3,
                     TX_NO_TIME_SLICE,
                     TX_AUTO_START);

    tx_thread_create(&thread3, "TX3",
                     vTask3, 0,
                     stack3, STACK_SIZE,
                     4,
                     4,
                     TX_NO_TIME_SLICE,
                     TX_AUTO_START);

    /* Idle thread: lowest priority (TX_MAX_PRIORITIES-1 = 31).
     * Ensures execute_ptr is never NULL when user threads sleep. */
    tx_thread_create(&idle_thread, "Idle",
                     vIdleTask, 0,
                     idle_stack, IDLE_STACK_SIZE,
                     TX_MAX_PRIORITIES - 1,    /* priority 31 = lowest */
                     TX_MAX_PRIORITIES - 1,
                     TX_NO_TIME_SLICE,
                     TX_AUTO_START);

    uart_puts("Starting scheduler...\r\n");
}

/* ---- main --------------------------------------------------------- */
int main(void)
{
    /* tx_kernel_enter() never returns:
     * 1. calls _tx_initialize_low_level()
     * 2. calls tx_application_define()
     * 3. calls _tx_thread_schedule() → starts threads, enables IRQs */
    tx_kernel_enter();

    /* Should never reach here */
    for (;;);
    return 0;
}
