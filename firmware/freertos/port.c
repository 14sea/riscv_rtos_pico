/* PicoRV32 FreeRTOS port — port.c */

#include "FreeRTOS.h"
#include "task.h"
#include "portmacro.h"

/* Critical nesting counter.  Starts non-zero so accidental portENABLE_INTERRUPTS()
 * calls before the scheduler starts won't enable IRQs prematurely. */
volatile unsigned int xCriticalNesting = 0xaaaaaaaa;

/* Task exit error — called if a task function returns (should never happen). */
static void prvTaskExitError( void )
{
    for( ;; );
}

/* -------------------------------------------------------------------------
 * pxPortInitialiseStack
 *
 * Builds the initial context frame for a new task on its stack.
 * The returned pointer is stored in TCB->pxTopOfStack.
 *
 * Frame layout (32 words = 128 bytes, grows down from pxTopOfStack):
 *   slot  0 : x1  (ra)  = prvTaskExitError
 *   slot  1 : x3  (gp)  = __global_pointer$
 *   slot  2 : x4  (tp)  = 0
 *   slots 3-7:  t0-t2, s0, s1 = 0
 *   slot  8 : x10 (a0)  = pvParameters
 *   slots 9-29: a1-a7, s2-s11, t3-t6 = 0
 *   slot 30 : PC        = pxCode  (task entry point)
 *   slot 31 : padding   = 0       (keeps 128 bytes / 16-byte alignment)
 * ----------------------------------------------------------------------- */
StackType_t *pxPortInitialiseStack( StackType_t *pxTopOfStack,
                                     TaskFunction_t pxCode,
                                     void *pvParameters )
{
    /* Capture current gp (same for all tasks — set once in start_freertos.S) */
    register unsigned int gp_val __asm__("gp");
    __asm__ volatile ( "" : "=r"( gp_val ) );

    /* Allocate 32-word frame (128 bytes) */
    pxTopOfStack -= 32;

    pxTopOfStack[  0 ] = ( StackType_t ) prvTaskExitError;  /* x1  ra  */
    pxTopOfStack[  1 ] = ( StackType_t ) gp_val;            /* x3  gp  */
    pxTopOfStack[  2 ] = 0;                                  /* x4  tp  */
    pxTopOfStack[  3 ] = 0;                                  /* x5  t0  */
    pxTopOfStack[  4 ] = 0;                                  /* x6  t1  */
    pxTopOfStack[  5 ] = 0;                                  /* x7  t2  */
    pxTopOfStack[  6 ] = 0;                                  /* x8  s0  */
    pxTopOfStack[  7 ] = 0;                                  /* x9  s1  */
    pxTopOfStack[  8 ] = ( StackType_t ) pvParameters;       /* x10 a0  */
    pxTopOfStack[  9 ] = 0;                                  /* x11 a1  */
    pxTopOfStack[ 10 ] = 0;                                  /* x12 a2  */
    pxTopOfStack[ 11 ] = 0;                                  /* x13 a3  */
    pxTopOfStack[ 12 ] = 0;                                  /* x14 a4  */
    pxTopOfStack[ 13 ] = 0;                                  /* x15 a5  */
    pxTopOfStack[ 14 ] = 0;                                  /* x16 a6  */
    pxTopOfStack[ 15 ] = 0;                                  /* x17 a7  */
    pxTopOfStack[ 16 ] = 0;                                  /* x18 s2  */
    pxTopOfStack[ 17 ] = 0;                                  /* x19 s3  */
    pxTopOfStack[ 18 ] = 0;                                  /* x20 s4  */
    pxTopOfStack[ 19 ] = 0;                                  /* x21 s5  */
    pxTopOfStack[ 20 ] = 0;                                  /* x22 s6  */
    pxTopOfStack[ 21 ] = 0;                                  /* x23 s7  */
    pxTopOfStack[ 22 ] = 0;                                  /* x24 s8  */
    pxTopOfStack[ 23 ] = 0;                                  /* x25 s9  */
    pxTopOfStack[ 24 ] = 0;                                  /* x26 s10 */
    pxTopOfStack[ 25 ] = 0;                                  /* x27 s11 */
    pxTopOfStack[ 26 ] = 0;                                  /* x28 t3  */
    pxTopOfStack[ 27 ] = 0;                                  /* x29 t4  */
    pxTopOfStack[ 28 ] = 0;                                  /* x30 t5  */
    pxTopOfStack[ 29 ] = 0;                                  /* x31 t6  */
    pxTopOfStack[ 30 ] = ( StackType_t ) pxCode;             /* PC      */
    pxTopOfStack[ 31 ] = 0;                                  /* padding */

    return pxTopOfStack;
}

/* -------------------------------------------------------------------------
 * vPortSetupTimerInterrupt
 *
 * Arms the PicoRV32 built-in countdown timer for the first tick.
 * Timer instruction: timer rd, rs → rd=old_timer; countdown=rs.
 * When countdown reaches 0, IRQ bit 0 fires.
 * ----------------------------------------------------------------------- */
void vPortSetupTimerInterrupt( void )
{
    register unsigned int timer_val __asm__("a0") =
        ( unsigned int )( configCPU_CLOCK_HZ / configTICK_RATE_HZ );
    /* timer a0, a0 */
    __asm__ volatile ( ".word 0x0A05050B\n" : "+r"( timer_val ) );
}

/* -------------------------------------------------------------------------
 * xPortStartScheduler
 *
 * Called by vTaskStartScheduler().  Arms the timer, then jumps to the
 * first task via xPortStartFirstTask() (defined in portASM.S).
 * ----------------------------------------------------------------------- */
BaseType_t xPortStartScheduler( void )
{
    extern void xPortStartFirstTask( void );

    /* Reset critical nesting to 0 — scheduler is now active */
    xCriticalNesting = 0;

    vPortSetupTimerInterrupt();
    xPortStartFirstTask();          /* Does not return */

    return pdFAIL;
}

/* -------------------------------------------------------------------------
 * vPortEndScheduler — not implemented for embedded targets
 * ----------------------------------------------------------------------- */
void vPortEndScheduler( void )
{
    for( ;; );
}
