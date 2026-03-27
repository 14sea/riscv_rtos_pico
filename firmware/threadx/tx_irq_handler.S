/* PicoRV32 ThreadX port — tx_irq_handler.S
 *
 * Contains:
 *   _tx_threadx_irq_handler  — main IRQ dispatcher (context save/restore)
 *   _tx_thread_schedule      — startup scheduler loop
 *   _tx_idle_loop            — idle loop when execute_ptr==NULL
 *
 * Context frame layout (128 bytes, 16-byte aligned, identical to FreeRTOS port):
 *   sp+0x00  x1  (ra)      slot  0
 *   sp+0x04  x3  (gp)      slot  1
 *   sp+0x08  x4  (tp)      slot  2
 *   sp+0x0C  x5  (t0)      slot  3
 *   sp+0x10  x6  (t1)      slot  4
 *   sp+0x14  x7  (t2)      slot  5
 *   sp+0x18  x8  (s0)      slot  6
 *   sp+0x1C  x9  (s1)      slot  7
 *   sp+0x20  x10 (a0)      slot  8
 *   sp+0x24  x11 (a1)      slot  9
 *   sp+0x28  x12 (a2)      slot 10
 *   sp+0x2C  x13 (a3)      slot 11
 *   sp+0x30  x14 (a4)      slot 12
 *   sp+0x34  x15 (a5)      slot 13
 *   sp+0x38  x16 (a6)      slot 14
 *   sp+0x3C  x17 (a7)      slot 15
 *   sp+0x40  x18 (s2)      slot 16
 *   sp+0x44  x19 (s3)      slot 17
 *   sp+0x48  x20 (s4)      slot 18
 *   sp+0x4C  x21 (s5)      slot 19
 *   sp+0x50  x22 (s6)      slot 20
 *   sp+0x54  x23 (s7)      slot 21
 *   sp+0x58  x24 (s8)      slot 22
 *   sp+0x5C  x25 (s9)      slot 23
 *   sp+0x60  x26 (s10)     slot 24
 *   sp+0x64  x27 (s11)     slot 25
 *   sp+0x68  x28 (t3)      slot 26
 *   sp+0x6C  x29 (t4)      slot 27
 *   sp+0x70  x30 (t5)      slot 28
 *   sp+0x74  x31 (t6)      slot 29
 *   sp+0x78  PC  (q0)      slot 30   ← return address saved by IRQ
 *   sp+0x7C  padding        slot 31
 *
 * Design notes:
 *
 * 1. An idle thread (lowest priority) ensures _tx_thread_execute_ptr is
 *    never NULL while any user thread exists.  The idle thread just loops
 *    forever without sleeping.
 *
 * 2. _tx_thread_system_state is incremented before C timer calls so that
 *    _tx_thread_system_preempt_check knows we are in ISR context and does
 *    NOT call _tx_thread_system_return (ecall), which would deadlock since
 *    irq_active=1 when we are already inside the IRQ handler.
 *
 * 3. TX_THREAD->tx_thread_stack_ptr is at offset 8 (NOT 0 like FreeRTOS).
 *
 * PicoRV32 custom instruction encodings (opcode=0x0B):
 *   getq a0, q0 : 0x0000050B  rd=a0, rs1=0=q0, funct7=0
 *   getq a0, q1 : 0x0000850B  rd=a0, rs1=1=q1, funct7=0
 *   setq q0, a0 : 0x0205000B  rd=0=q0, rs1=a0, funct7=1
 *   timer a0,a0 : 0x0A05050B  rd=a0, rs1=a0, funct7=5
 *   maskirq x0,x0: 0x0600000B enable all IRQs (irq_mask=0)
 *   retirq      : 0x0400000B  jump to q0, clear irq_active
 *
 * IRQ bits: 0=timer, 1=ecall/yield, 2=bus-error, 3+=external
 */

#define CONTEXT_SIZE    (32 * 4)    /* 128 bytes */
#define PC_OFFSET       (30 * 4)    /* 0x78 */
#define TIMER_COUNTS    500000      /* 50 MHz / 100 Hz */

/* TCB field offsets (from TX_THREAD_STRUCT in tx_api.h) */
#define TCB_RUN_COUNT   4
#define TCB_STACK_PTR   8
#define TCB_TIME_SLICE  24

/* PicoRV32 custom instruction words */
#define GETQ_A0_Q0      .word 0x0000050B
#define GETQ_A0_Q1      .word 0x0000850B
#define SETQ_Q0_A0      .word 0x0205000B
#define TIMER_A0_A0     .word 0x0A05050B
#define MASKIRQ_ENABLE  .word 0x0600000B
#define RETIRQ          .word 0x0400000B

.section .text
.global _tx_threadx_irq_handler
.global _tx_thread_schedule
.global _tx_idle_loop
.extern _tx_thread_current_ptr
.extern _tx_thread_execute_ptr
.extern _tx_timer_time_slice
.extern _tx_timer_interrupt
.extern _tx_thread_system_state

/* ====================================================================
 * _tx_threadx_irq_handler
 *
 * Called by IRQ vector at 0x00000010.
 * On entry: q0=interrupted PC, q1=IRQ bitmap, irq_active=1.
 *
 * Two cases for current_ptr:
 *   non-NULL: a thread was running → save its context, dispatch, restore
 *   NULL:     idle loop was running → dispatch (timer only), retirq to idle
 * ==================================================================== */
_tx_threadx_irq_handler:

    /* 1 — Allocate context frame on current stack */
    addi    sp, sp, -CONTEXT_SIZE

    /* 2 — Save all GP registers (skip x0=zero, x2=sp implicit) */
    sw      x1,   0*4(sp)
    sw      x3,   1*4(sp)
    sw      x4,   2*4(sp)
    sw      x5,   3*4(sp)
    sw      x6,   4*4(sp)
    sw      x7,   5*4(sp)
    sw      x8,   6*4(sp)
    sw      x9,   7*4(sp)
    sw      x10,  8*4(sp)
    sw      x11,  9*4(sp)
    sw      x12, 10*4(sp)
    sw      x13, 11*4(sp)
    sw      x14, 12*4(sp)
    sw      x15, 13*4(sp)
    sw      x16, 14*4(sp)
    sw      x17, 15*4(sp)
    sw      x18, 16*4(sp)
    sw      x19, 17*4(sp)
    sw      x20, 18*4(sp)
    sw      x21, 19*4(sp)
    sw      x22, 20*4(sp)
    sw      x23, 21*4(sp)
    sw      x24, 22*4(sp)
    sw      x25, 23*4(sp)
    sw      x26, 24*4(sp)
    sw      x27, 25*4(sp)
    sw      x28, 26*4(sp)
    sw      x29, 27*4(sp)
    sw      x30, 28*4(sp)
    sw      x31, 29*4(sp)

    /* 3 — Save interrupted PC (from q0) into frame slot 30 */
    GETQ_A0_Q0
    sw      a0, PC_OFFSET(sp)

    /* 4 — Get IRQ cause bitmap (from q1) into callee-saved s0 */
    GETQ_A0_Q1
    mv      s0, a0

    /* 5 — Check if a thread is running */
    la      a1, _tx_thread_current_ptr
    lw      a1, 0(a1)               /* a1 = current_ptr */
    beqz    a1, _handle_no_thread   /* NULL → idle loop was interrupted */

    /* 6 — Save sp to current thread's TCB->tx_thread_stack_ptr (offset 8) */
    sw      sp, TCB_STACK_PTR(a1)

    /* 7 — Dispatch on IRQ source */
    andi    a2, s0, 1               /* bit 0 = timer */
    bnez    a2, _handle_timer

    andi    a2, s0, 2               /* bit 1 = ecall/yield */
    bnez    a2, _irq_exit           /* execute_ptr already set by ThreadX C */

    /* Unknown IRQ — just return */
    j       _irq_exit

_handle_no_thread:
    /* IRQ while idle_loop running (current_ptr==NULL).
     * Only process timer; yield from idle should not happen. */
    andi    a2, s0, 1
    beqz    a2, _irq_restore_same   /* not a timer, restore idle frame */

_handle_timer_no_thread:
    /* Reload timer */
    li      a0, TIMER_COUNTS
    TIMER_A0_A0
    /* Signal ISR context to ThreadX */
    la      a0, _tx_thread_system_state
    lw      a1, 0(a0)
    addi    a1, a1, 1
    sw      a1, 0(a0)
    call    _tx_timer_interrupt
    la      a0, _tx_thread_system_state
    lw      a1, 0(a0)
    addi    a1, a1, -1
    sw      a1, 0(a0)
    /* After timer, execute_ptr may be set (a thread woke up).
     * If so, switch to it directly from here (current was idle/NULL). */
    la      a0, _tx_thread_execute_ptr
    lw      a0, 0(a0)
    beqz    a0, _irq_restore_same   /* still no thread, back to idle */
    /* A thread is now ready: switch to it */
    la      a1, _tx_thread_current_ptr
    sw      a0, 0(a1)               /* current_ptr = execute_ptr */
    lw      sp, TCB_STACK_PTR(a0)   /* load thread's sp */
    j       _irq_restore_ctx        /* restore and retirq */

_handle_timer:
    /* Reload timer for next tick */
    li      a0, TIMER_COUNTS
    TIMER_A0_A0
    /* Increment _tx_thread_system_state: tells ThreadX we're in ISR context.
     * Prevents _tx_thread_system_preempt_check from calling ecall (deadlock). */
    la      a0, _tx_thread_system_state
    lw      a1, 0(a0)
    addi    a1, a1, 1
    sw      a1, 0(a0)
    call    _tx_timer_interrupt
    /* Decrement _tx_thread_system_state */
    la      a0, _tx_thread_system_state
    lw      a1, 0(a0)
    addi    a1, a1, -1
    sw      a1, 0(a0)
    /* fall through to _irq_exit */

_irq_exit:
    /* Load execute_ptr (may have changed due to timer or yield).
     * With an idle thread present, execute_ptr should never be NULL.
     * If it somehow is NULL (safety net): restore same frame. */
    la      a0, _tx_thread_execute_ptr
    lw      a0, 0(a0)
    beqz    a0, _irq_restore_same   /* safety: should not happen with idle thread */

    /* Update current_ptr = execute_ptr */
    la      a1, _tx_thread_current_ptr
    sw      a0, 0(a1)

    /* Switch to new thread's stack (tx_thread_stack_ptr at TCB offset 8) */
    lw      sp, TCB_STACK_PTR(a0)

_irq_restore_ctx:
    /* Load saved PC into q0 for retirq */
    lw      a0, PC_OFFSET(sp)
    SETQ_Q0_A0

    /* Restore GP registers */
    lw      x1,   0*4(sp)
    lw      x3,   1*4(sp)
    lw      x4,   2*4(sp)
    lw      x5,   3*4(sp)
    lw      x6,   4*4(sp)
    lw      x7,   5*4(sp)
    lw      x8,   6*4(sp)
    lw      x9,   7*4(sp)
    lw      x10,  8*4(sp)
    lw      x11,  9*4(sp)
    lw      x12, 10*4(sp)
    lw      x13, 11*4(sp)
    lw      x14, 12*4(sp)
    lw      x15, 13*4(sp)
    lw      x16, 14*4(sp)
    lw      x17, 15*4(sp)
    lw      x18, 16*4(sp)
    lw      x19, 17*4(sp)
    lw      x20, 18*4(sp)
    lw      x21, 19*4(sp)
    lw      x22, 20*4(sp)
    lw      x23, 21*4(sp)
    lw      x24, 22*4(sp)
    lw      x25, 23*4(sp)
    lw      x26, 24*4(sp)
    lw      x27, 25*4(sp)
    lw      x28, 26*4(sp)
    lw      x29, 27*4(sp)
    lw      x30, 28*4(sp)
    lw      x31, 29*4(sp)

    /* Deallocate frame and return from IRQ */
    addi    sp, sp, CONTEXT_SIZE
    RETIRQ

_irq_restore_same:
    /* Restore the same frame (return to wherever we were — idle loop or
     * the interrupted thread if no switch needed). */
    lw      a0, PC_OFFSET(sp)
    SETQ_Q0_A0

    lw      x1,   0*4(sp)
    lw      x3,   1*4(sp)
    lw      x4,   2*4(sp)
    lw      x5,   3*4(sp)
    lw      x6,   4*4(sp)
    lw      x7,   5*4(sp)
    lw      x8,   6*4(sp)
    lw      x9,   7*4(sp)
    lw      x10,  8*4(sp)
    lw      x11,  9*4(sp)
    lw      x12, 10*4(sp)
    lw      x13, 11*4(sp)
    lw      x14, 12*4(sp)
    lw      x15, 13*4(sp)
    lw      x16, 14*4(sp)
    lw      x17, 15*4(sp)
    lw      x18, 16*4(sp)
    lw      x19, 17*4(sp)
    lw      x20, 18*4(sp)
    lw      x21, 19*4(sp)
    lw      x22, 20*4(sp)
    lw      x23, 21*4(sp)
    lw      x24, 22*4(sp)
    lw      x25, 23*4(sp)
    lw      x26, 24*4(sp)
    lw      x27, 25*4(sp)
    lw      x28, 26*4(sp)
    lw      x29, 27*4(sp)
    lw      x30, 28*4(sp)
    lw      x31, 29*4(sp)
    addi    sp, sp, CONTEXT_SIZE
    RETIRQ


/* ====================================================================
 * _tx_thread_schedule
 *
 * Called by tx_kernel_enter() after tx_application_define().
 * With an idle thread created in tx_application_define(), execute_ptr
 * is guaranteed non-NULL on entry.
 *
 * Starts the highest-priority ready thread and enables IRQs.
 * Does NOT return.
 * ==================================================================== */
_tx_thread_schedule:

    /* Wait for a thread to become ready (guaranteed non-NULL with idle thread) */
    la      t0, _tx_thread_execute_ptr
_schedule_wait:
    lw      t1, 0(t0)
    beqz    t1, _schedule_wait

    /* Set current_ptr = execute_ptr */
    la      t0, _tx_thread_current_ptr
    sw      t1, 0(t0)

    /* Increment run count (TCB offset 4) */
    lw      t2, TCB_RUN_COUNT(t1)
    addi    t2, t2, 1
    sw      t2, TCB_RUN_COUNT(t1)

    /* Load thread's time slice into _tx_timer_time_slice */
    lw      t3, TCB_TIME_SLICE(t1)
    la      t2, _tx_timer_time_slice
    sw      t3, 0(t2)

    /* Switch to thread's stack (TCB offset 8) */
    lw      sp, TCB_STACK_PTR(t1)

    /* Load thread entry point from frame slot 30 into t0 */
    lw      t0, PC_OFFSET(sp)

    /* Restore all GP registers except x5/t0 (holds entry address) */
    lw      x1,   0*4(sp)
    lw      x3,   1*4(sp)
    lw      x4,   2*4(sp)
    /* x5/t0 intentionally NOT restored — holds entry address */
    lw      x6,   4*4(sp)
    lw      x7,   5*4(sp)
    lw      x8,   6*4(sp)
    lw      x9,   7*4(sp)
    lw      x10,  8*4(sp)
    lw      x11,  9*4(sp)
    lw      x12, 10*4(sp)
    lw      x13, 11*4(sp)
    lw      x14, 12*4(sp)
    lw      x15, 13*4(sp)
    lw      x16, 14*4(sp)
    lw      x17, 15*4(sp)
    lw      x18, 16*4(sp)
    lw      x19, 17*4(sp)
    lw      x20, 18*4(sp)
    lw      x21, 19*4(sp)
    lw      x22, 20*4(sp)
    lw      x23, 21*4(sp)
    lw      x24, 22*4(sp)
    lw      x25, 23*4(sp)
    lw      x26, 24*4(sp)
    lw      x27, 25*4(sp)
    lw      x28, 26*4(sp)
    lw      x29, 27*4(sp)
    lw      x30, 28*4(sp)
    lw      x31, 29*4(sp)

    /* Deallocate frame */
    addi    sp, sp, CONTEXT_SIZE

    /* Arm hardware timer for first tick */
    li      a0, TIMER_COUNTS
    TIMER_A0_A0

    /* Enable all IRQs */
    MASKIRQ_ENABLE

    /* Jump to first thread entry (_tx_thread_shell_entry) */
    jr      t0


/* ====================================================================
 * _tx_idle_loop
 *
 * Entered when execute_ptr becomes NULL (safety fallback; with an idle
 * thread this should never be reached in normal operation).
 * Spins with IRQs enabled until timer wakes a thread.
 * ==================================================================== */
_tx_idle_loop:
    MASKIRQ_ENABLE
_idle_spin:
    j       _idle_spin          /* Timer IRQ will break out of this */
