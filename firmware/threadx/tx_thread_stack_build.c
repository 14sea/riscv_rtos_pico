/* PicoRV32 ThreadX port — tx_thread_stack_build.c
 *
 * Builds the initial context frame for a new thread.
 * Called by tx_thread_create() with:
 *   thread_ptr   — TX_THREAD control block
 *   function_ptr — always _tx_thread_shell_entry (ThreadX shell)
 *
 * Frame layout (128 bytes = 32 words, growing downward):
 *   frame[0]  = x1  (ra)  = 0  (shell entry never returns)
 *   frame[1]  = x3  (gp)  = current global pointer
 *   frame[2]  = x4  (tp)  = 0
 *   frame[3..29] = 0       (t0-t2, s0-s11, a0-a7, t3-t6)
 *   frame[30] = PC         = function_ptr (_tx_thread_shell_entry)
 *   frame[31] = 0          (padding)
 *
 * TX_THREAD->tx_thread_stack_ptr (offset 8) is set to &frame[0].
 * TX_THREAD->tx_thread_stack_end (offset 16) = stack_start + stack_size - 1.
 */

#define TX_SOURCE_CODE
#include "tx_api.h"

VOID _tx_thread_stack_build(TX_THREAD *thread_ptr, VOID (*function_ptr)(VOID))
{
    ULONG  *frame;
    ULONG   gp_val;
    int     i;

    /* Align the stack top down to a 16-byte boundary, then carve out
     * 128 bytes (32 words) for the initial context frame.              */
    frame = (ULONG *)(((ULONG)thread_ptr->tx_thread_stack_end & ~(ULONG)0xF)
                      - (ULONG)128);

    /* Zero-initialise all 32 slots */
    for (i = 0; i < 32; i++)
        frame[i] = 0;

    /* Capture the current global pointer value — all threads share one GP */
    __asm__ volatile ("mv %0, gp" : "=r"(gp_val));

    frame[1]  = gp_val;                 /* x3  gp  */
    frame[30] = (ULONG)function_ptr;    /* PC  = _tx_thread_shell_entry */
    /* frame[31] = 0 already (padding) */

    /* Store the frame base into the TCB (tx_thread_stack_ptr at offset 8) */
    thread_ptr->tx_thread_stack_ptr = (VOID *)frame;
}
