/* PicoRV32 ThreadX user configuration — tx_user.h */

#ifndef TX_USER_H
#define TX_USER_H

/* Process timer in ISR context (avoids timer thread overhead).
 * This causes _tx_timer_interrupt() to be called from the timer ISR. */
#define TX_TIMER_PROCESS_IN_ISR

/* Disable trace to save ROM/RAM */
#define TX_DISABLE_TRACE

/* Disable error-checking wrappers (txe_*) to save ROM */
#define TX_DISABLE_ERROR_CHECKING

/* Disable stack error notify (saves code) */
#define TX_DISABLE_STACK_FILLING

/* Tick rate: 100 Hz (10 ms per tick @ 50 MHz) */
#define TX_TIMER_TICKS_PER_SECOND   100

/* CPU clock for timer calculation */
#define TX_CPU_CLOCK_HZ             50000000UL

/* Timer countdown: clock / tick_rate = 50000000 / 100 = 500000 cycles */
#define TX_TIMER_COUNTS             500000UL

/* Maximum priorities (must be multiple of 32, minimum 32) */
#ifndef TX_MAX_PRIORITIES
#define TX_MAX_PRIORITIES           32
#endif

#endif /* TX_USER_H */
