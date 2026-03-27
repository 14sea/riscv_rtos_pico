/* PicoRV32 ThreadX port — tx_thread_system_return.S
 *
 * _tx_thread_system_return
 *
 * Called by ThreadX internal C functions (tx_thread_sleep, tx_thread_suspend,
 * tx_thread_relinquish, etc.) when the current thread must yield execution.
 * By the time this is called, _tx_thread_execute_ptr has already been updated
 * by the ThreadX C code to point to the next thread to run.
 *
 * Strategy: issue ecall → triggers IRQ bit 1 → IRQ handler saves full
 * context of this thread, then restores from _tx_thread_execute_ptr.
 *
 * When this thread is later resumed, execution continues from the instruction
 * AFTER the ecall (the 'ret'), which returns through tx_thread_sleep (etc.)
 * back into the thread function.
 */

.section .text
.global _tx_thread_system_return

_tx_thread_system_return:
    ecall           /* triggers IRQ bit 1 (ecall/ebreak) */
    ret             /* resumed here when this thread is rescheduled */
