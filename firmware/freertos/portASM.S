/* PicoRV32 FreeRTOS port — portASM.S
 *
 * Context frame layout (128 bytes, 16-byte aligned):
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
 *   sp+0x78  PC  (q0)      slot 30   ← return address from IRQ
 *   sp+0x7C  padding        slot 31   ← keeps frame 128-byte (16-byte aligned)
 *
 * PicoRV32 IRQ notes:
 *   - When IRQ fires: q0←interrupted_PC, q1←(irq_pending & ~irq_mask), irq_active←1
 *   - IRQs are non-reentrant: irq_active=1 prevents new IRQ until retirq
 *   - retirq: jumps to q0, sets irq_active←0 (does NOT restore irq_mask)
 *   - IRQ bits: 0=timer, 1=ecall/ebreak (portYIELD), 2=bus-error
 */

#define CONTEXT_SIZE    ( 32 * 4 )   /* 128 bytes */
#define PC_OFFSET       ( 30 * 4 )   /* 0x78 — PC slot */

/* PicoRV32 custom instruction encodings */
/* getq  a0, q0 : funct7=0, rs2=0, rs1=0,  funct3=0, rd=10, op=0x0B */
#define GETQ_A0_Q0      .word 0x0000050B
/* getq  a0, q1 : funct7=0, rs2=0, rs1=1,  funct3=0, rd=10, op=0x0B */
#define GETQ_A0_Q1      .word 0x0000850B
/* setq  q0, a0 : funct7=1, rs2=0, rs1=10, funct3=0, rd=0,  op=0x0B */
#define SETQ_Q0_A0      .word 0x0205000B
/* timer a0, a0 : funct7=5, rs2=0, rs1=10, funct3=0, rd=10, op=0x0B */
#define TIMER_A0_A0     .word 0x0A05050B
/* maskirq x0, x0: funct7=3, rs2=0, rs1=0, funct3=0, rd=0, op=0x0B (enable all IRQs) */
#define MASKIRQ_ENABLE  .word 0x0600000B
/* retirq */
#define RETIRQ          .word 0x0400000B

/* Timer countdown: 50 MHz / 100 Hz = 500,000 cycles */
#define TIMER_COUNTS    500000

.section .text
.global _freertos_irq_handler
.global xPortStartFirstTask
.extern pxCurrentTCB
.extern xTaskIncrementTick
.extern vTaskSwitchContext

/* ====================================================================
 * _freertos_irq_handler
 *
 * Called by the IRQ vector jump at 0x00000010.
 * On entry: q0=interrupted PC, q1=IRQ bitmap, irq_active=1, sp=task sp.
 * ==================================================================== */
_freertos_irq_handler:
    /* 1 — Allocate context frame on current task stack */
    addi    sp, sp, -CONTEXT_SIZE

    /* 2 — Save all GP registers except x0 (zero) and x2 (sp, implicit) */
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

    /* 3 — Save interrupted PC (from q0) into frame */
    GETQ_A0_Q0                      /* a0 = return PC */
    sw      a0, PC_OFFSET(sp)

    /* 4 — Get IRQ cause bitmap (from q1) into callee-saved s0 */
    GETQ_A0_Q1                      /* a0 = IRQ bitmap */
    mv      s0, a0                  /* s0 = IRQ bitmap (callee-saved across calls) */

    /* 5 — Save current task sp to TCB->pxTopOfStack (offset 0) */
    la      a1, pxCurrentTCB
    lw      a1, 0(a1)               /* a1 = *pxCurrentTCB */
    sw      sp, 0(a1)               /* pxCurrentTCB->pxTopOfStack = sp */

    /* 6 — Dispatch on IRQ source */
    andi    a2, s0, 1               /* bit 0 = timer */
    bnez    a2, _handle_timer

    andi    a2, s0, 2               /* bit 1 = ecall/yield */
    bnez    a2, _handle_yield

    j       _irq_exit               /* Unknown IRQ — just return */

_handle_timer:
    /* Reload timer for next tick */
    li      a0, TIMER_COUNTS
    TIMER_A0_A0                     /* timer a0, a0: set countdown */

    call    xTaskIncrementTick
    beqz    a0, _irq_exit           /* a0=0: no context switch needed */
    call    vTaskSwitchContext
    j       _irq_exit

_handle_yield:
    call    vTaskSwitchContext
    /* fall through */

_irq_exit:
    /* 7 — Reload sp from (possibly new) current task TCB */
    la      a0, pxCurrentTCB
    lw      a0, 0(a0)               /* a0 = *pxCurrentTCB */
    lw      sp, 0(a0)               /* sp = TCB->pxTopOfStack */

    /* 8 — Load saved PC into q0 for retirq */
    lw      a0, PC_OFFSET(sp)
    SETQ_Q0_A0                      /* q0 = return PC */

    /* 9 — Restore GP registers */
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

    /* 10 — Deallocate frame and return */
    addi    sp, sp, CONTEXT_SIZE
    RETIRQ                          /* Jump to q0, clear irq_active */

/* ====================================================================
 * xPortStartFirstTask
 *
 * Called from xPortStartScheduler (port.c) to launch the first task.
 * pxCurrentTCB already points to the highest-priority ready task.
 *
 * Strategy: load the task's initial frame from TCB->pxTopOfStack,
 * then jump directly to the task entry point.  We skip restoring x5
 * (t0) so we can use it as the jump register without clobbering the
 * task's entry point.  t0 is caller-saved, so the task doesn't rely
 * on a specific initial value.
 * ==================================================================== */
xPortStartFirstTask:
    /* Load first task's frame pointer */
    la      a0, pxCurrentTCB
    lw      a0, 0(a0)               /* a0 = TCB ptr */
    lw      sp, 0(a0)               /* sp = pxTopOfStack (bottom of context frame) */

    /* Load task entry PC into t0 (jump register) from frame slot 30 */
    lw      t0, PC_OFFSET(sp)       /* t0 = task entry point */

    /* Restore GP registers (skip x5/t0 — that holds our jump target) */
    lw      x1,   0*4(sp)           /* ra = prvTaskExitError */
    lw      x3,   1*4(sp)           /* gp */
    lw      x4,   2*4(sp)           /* tp */
    /* x5 (t0): intentionally NOT restored — holds task entry address */
    lw      x6,   4*4(sp)           /* t1 */
    lw      x7,   5*4(sp)           /* t2 */
    lw      x8,   6*4(sp)           /* s0 */
    lw      x9,   7*4(sp)           /* s1 */
    lw      x10,  8*4(sp)           /* a0 = pvParameters */
    lw      x11,  9*4(sp)           /* a1 */
    lw      x12, 10*4(sp)           /* a2 */
    lw      x13, 11*4(sp)           /* a3 */
    lw      x14, 12*4(sp)           /* a4 */
    lw      x15, 13*4(sp)           /* a5 */
    lw      x16, 14*4(sp)           /* a6 */
    lw      x17, 15*4(sp)           /* a7 */
    lw      x18, 16*4(sp)           /* s2 */
    lw      x19, 17*4(sp)           /* s3 */
    lw      x20, 18*4(sp)           /* s4 */
    lw      x21, 19*4(sp)           /* s5 */
    lw      x22, 20*4(sp)           /* s6 */
    lw      x23, 21*4(sp)           /* s7 */
    lw      x24, 22*4(sp)           /* s8 */
    lw      x25, 23*4(sp)           /* s9 */
    lw      x26, 24*4(sp)           /* s10 */
    lw      x27, 25*4(sp)           /* s11 */
    lw      x28, 26*4(sp)           /* t3 */
    lw      x29, 27*4(sp)           /* t4 */
    lw      x30, 28*4(sp)           /* t5 */
    lw      x31, 29*4(sp)           /* t6 */

    /* Deallocate frame — sp is now at task's initial stack top */
    addi    sp, sp, CONTEXT_SIZE

    /* Enable all IRQs: maskirq x0, x0 → irq_mask = 0 */
    MASKIRQ_ENABLE

    /* Jump to first task entry (t0) */
    jr      t0
