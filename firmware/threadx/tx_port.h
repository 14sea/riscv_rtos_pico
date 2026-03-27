/* PicoRV32 Eclipse ThreadX port — tx_port.h
 *
 * Provides all port-specific types and macros required by the ThreadX kernel.
 * PicoRV32 uses custom IRQ instructions (opcode 0x0B) instead of standard
 * RISC-V CSRs.  Interrupt control is via maskirq (funct7=3).
 *
 * maskirq rd, rs  →  rd = old_irq_mask; irq_mask = rs
 *   irq_mask bit=1 means that IRQ is MASKED (disabled).
 *   maskirq a0, a0  with  a0=~0  disables all IRQs.
 *   maskirq x0, x0  (0x0600000B)  enables all IRQs (mask=0).
 */

#ifndef TX_PORT_H
#define TX_PORT_H

/* ---- bare-metal declarations (replaces <string.h>) ---- */
#ifndef NULL
#define NULL ((void *)0)
#endif
extern void *memset(void *dst, int c, unsigned long n);
extern void *memcpy(void *dst, const void *src, unsigned long n);

/* Include user overrides if requested */
#ifdef TX_INCLUDE_USER_DEFINE_FILE
#include "tx_user.h"
#endif

/* ------------------------------------------------------------------ */
/* Basic types                                                         */
/* ------------------------------------------------------------------ */
#define VOID                    void
typedef char                    CHAR;
typedef unsigned char           UCHAR;
typedef int                     INT;
typedef unsigned int            UINT;
typedef long                    LONG;
typedef unsigned long           ULONG;
typedef short                   SHORT;
typedef unsigned short          USHORT;

/* ------------------------------------------------------------------ */
/* Kernel configuration limits                                         */
/* ------------------------------------------------------------------ */
#ifndef TX_MAX_PRIORITIES
#define TX_MAX_PRIORITIES       32
#endif

#ifndef TX_MINIMUM_STACK
#define TX_MINIMUM_STACK        512
#endif

#ifndef TX_TIMER_THREAD_STACK_SIZE
#define TX_TIMER_THREAD_STACK_SIZE  1024
#endif

#ifndef TX_TIMER_THREAD_PRIORITY
#define TX_TIMER_THREAD_PRIORITY    0
#endif

/* ------------------------------------------------------------------ */
/* Interrupt control (PicoRV32 maskirq instruction)                   */
/* maskirq a0, a0  →  a0 = old_mask; irq_mask = a0 (input)           */
/* Encoding: funct7=3, rs2=0, rs1=10(a0), funct3=0, rd=10(a0), op=0x0B
 * = 0000011_00000_01010_000_01010_0001011 = 0x0605050B               */
/* ------------------------------------------------------------------ */

#define TX_INTERRUPT_SAVE_AREA      unsigned int _tx_saved_irq_mask;

/* Disable all IRQs: write ~0 to irq_mask, save old mask.
 * ThreadX uses TX_DISABLE without a trailing ';', so the macro
 * must be a self-contained statement (trailing ';' included). */
#define TX_DISABLE \
    { register unsigned int _m __asm__("a0") = ~0U; \
      __asm__ volatile (".word 0x0605050B\n" : "+r"(_m)); \
      _tx_saved_irq_mask = _m; };

/* Restore saved IRQ mask */
#define TX_RESTORE \
    { register unsigned int _m __asm__("a0") = _tx_saved_irq_mask; \
      __asm__ volatile (".word 0x0605050B\n" : "+r"(_m)); };

/* ------------------------------------------------------------------ */
/* TX_THREAD control block extensions (none needed for this port)     */
/* ------------------------------------------------------------------ */
#define TX_THREAD_EXTENSION_0
#define TX_THREAD_EXTENSION_1
#define TX_THREAD_EXTENSION_2
#define TX_THREAD_EXTENSION_3

/* ------------------------------------------------------------------ */
/* Object control block extensions (all empty for this port)          */
/* ------------------------------------------------------------------ */
#define TX_BLOCK_POOL_EXTENSION
#define TX_BYTE_POOL_EXTENSION
#define TX_EVENT_FLAGS_GROUP_EXTENSION
#define TX_MUTEX_EXTENSION
#define TX_QUEUE_EXTENSION
#define TX_SEMAPHORE_EXTENSION
#define TX_TIMER_EXTENSION

/* ------------------------------------------------------------------ */
/* Object lifecycle extensions (all empty)                            */
/* ------------------------------------------------------------------ */
#define TX_THREAD_CREATE_EXTENSION(t)
#define TX_THREAD_DELETE_EXTENSION(t)
#define TX_THREAD_COMPLETED_EXTENSION(t)
#define TX_THREAD_TERMINATED_EXTENSION(t)

#define TX_BLOCK_POOL_CREATE_EXTENSION(p)
#define TX_BYTE_POOL_CREATE_EXTENSION(p)
#define TX_EVENT_FLAGS_GROUP_CREATE_EXTENSION(g)
#define TX_MUTEX_CREATE_EXTENSION(m)
#define TX_QUEUE_CREATE_EXTENSION(q)
#define TX_SEMAPHORE_CREATE_EXTENSION(s)
#define TX_TIMER_CREATE_EXTENSION(t)

#define TX_BLOCK_POOL_DELETE_EXTENSION(p)
#define TX_BYTE_POOL_DELETE_EXTENSION(p)
#define TX_EVENT_FLAGS_GROUP_DELETE_EXTENSION(g)
#define TX_MUTEX_DELETE_EXTENSION(m)
#define TX_QUEUE_DELETE_EXTENSION(q)
#define TX_SEMAPHORE_DELETE_EXTENSION(s)
#define TX_TIMER_DELETE_EXTENSION(t)

/* ------------------------------------------------------------------ */
/* User thread extension (none)                                        */
/* ------------------------------------------------------------------ */
#ifndef TX_THREAD_USER_EXTENSION
#define TX_THREAD_USER_EXTENSION
#endif

/* ------------------------------------------------------------------ */
/* Inline initialization support                                       */
/* ------------------------------------------------------------------ */
#define TX_INLINE_INITIALIZATION

/* ------------------------------------------------------------------ */
/* Object disable macros (all use TX_DISABLE)                         */
/* ------------------------------------------------------------------ */
#define TX_BLOCK_POOL_DISABLE           TX_DISABLE
#define TX_BYTE_POOL_DISABLE            TX_DISABLE
#define TX_EVENT_FLAGS_GROUP_DISABLE    TX_DISABLE
#define TX_MUTEX_DISABLE                TX_DISABLE
#define TX_QUEUE_DISABLE                TX_DISABLE
#define TX_SEMAPHORE_DISABLE            TX_DISABLE

/* ------------------------------------------------------------------ */
/* Trace (disabled)                                                    */
/* ------------------------------------------------------------------ */
#ifndef TX_TRACE_TIME_SOURCE
#define TX_TRACE_TIME_SOURCE            ++_tx_trace_simulated_time
#endif
#ifndef TX_TRACE_TIME_MASK
#define TX_TRACE_TIME_MASK              0xFFFFFFFFUL
#endif
#define TX_PORT_SPECIFIC_BUILD_OPTIONS  0

/* ------------------------------------------------------------------ */
/* Version string                                                      */
/* ------------------------------------------------------------------ */
#ifdef TX_THREAD_INIT
CHAR _tx_version_id[] =
    "Copyright (c) 2024 Microsoft Corporation.  *  ThreadX PicoRV32/GCC Port v6.4.1 *";
#else
extern CHAR _tx_version_id[];
#endif

#endif /* TX_PORT_H */
