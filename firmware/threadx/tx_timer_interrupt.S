/* PicoRV32 ThreadX port — tx_timer_interrupt.S
 *
 * _tx_timer_interrupt
 *
 * Ported from the IAR RISC-V32 port to GCC syntax.
 * Called from _tx_threadx_irq_handler on every timer tick.
 *
 * Responsibilities:
 *   1. Increment _tx_timer_system_clock
 *   2. Decrement _tx_timer_time_slice; if expired set _tx_timer_expired_time_slice
 *   3. Check _tx_timer_current_ptr for expired software timers
 *   4. Call _tx_timer_expiration_process() if a timer expired
 *   5. Call _tx_thread_time_slice() if time-slice expired
 *
 * All instructions are standard RISC-V (no CSRs needed).
 * Runs on the calling thread's stack (PicoRV32 IRQ is non-reentrant).
 */

.section .text
.global _tx_timer_interrupt
.extern _tx_timer_system_clock
.extern _tx_timer_time_slice
.extern _tx_timer_expired_time_slice
.extern _tx_timer_current_ptr
.extern _tx_timer_expired
.extern _tx_timer_list_end
.extern _tx_timer_list_start
.extern _tx_timer_expiration_process
.extern _tx_thread_time_slice

_tx_timer_interrupt:

    /* Increment system clock */
    la      t0, _tx_timer_system_clock
    lw      t1, 0(t0)
    la      t2, _tx_timer_time_slice
    lw      t3, 0(t2)
    addi    t1, t1, 1
    sw      t1, 0(t0)
    li      t6, 0                       /* local expired flags (bit0=timeslice, bit1=timer) */

    /* Check time-slice */
    beqz    t3, _tx_timer_no_time_slice
    addi    t3, t3, -1
    sw      t3, 0(t2)
    bgtz    t3, _tx_timer_no_time_slice /* not yet expired */
    li      t1, 1
    la      t4, _tx_timer_expired_time_slice
    sw      t1, 0(t4)
    ori     t6, t6, 1                   /* set local timeslice-expired flag */

_tx_timer_no_time_slice:

    /* Check for expired software timer */
    la      t0, _tx_timer_current_ptr
    lw      t1, 0(t0)                   /* t1 = current ptr */
    lw      t3, 0(t1)                   /* t3 = entry at current ptr */
    la      t2, _tx_timer_expired
    li      t4, 1
    beqz    t3, _tx_timer_no_timer      /* no timer at this slot */

    /* A timer has expired */
    ori     t6, t6, 2
    sw      t4, 0(t2)                   /* _tx_timer_expired = TRUE */
    j       _tx_timer_done

_tx_timer_no_timer:

    /* Advance timer pointer, wrap if at end */
    la      t2, _tx_timer_list_end
    lw      t3, 0(t2)
    addi    t1, t1, 4
    sw      t1, 0(t0)
    bne     t1, t3, _tx_timer_skip_wrap
    la      t2, _tx_timer_list_start
    lw      t4, 0(t2)
    sw      t4, 0(t0)

_tx_timer_skip_wrap:

_tx_timer_done:

    /* If nothing expired, return */
    beqz    t6, _tx_timer_nothing_expired

    /* Save local expired flags and ra across C calls */
    and     t2, t6, 2
    addi    sp, sp, -16
    sw      t6, 0(sp)
    sw      ra, 4(sp)

    /* Call expiration process if a timer expired */
    beqz    t2, _tx_timer_dont_activate
    call    _tx_timer_expiration_process
    lw      t6, 0(sp)

_tx_timer_dont_activate:

    /* Call time-slice handler if time-slice expired */
    and     t2, t6, 1
    beqz    t2, _tx_timer_not_ts_expiration
    call    _tx_thread_time_slice

_tx_timer_not_ts_expiration:

    lw      ra, 4(sp)
    addi    sp, sp, 16

_tx_timer_nothing_expired:

    ret
