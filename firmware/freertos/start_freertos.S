/* Boot code for PicoRV32 FreeRTOS build
 *
 * Reset vector at 0x00000000 → jump to _boot
 * IRQ vector at  0x00000010 → jump to _freertos_irq_handler (portASM.S)
 * Boot code:   set up gp, clear BSS, copy .data, call main()
 */

.section .init, "ax"
.global _start

_start:
    j       _boot           /* jump over IRQ vector */
    nop
    nop
    nop

/* IRQ vector at 0x00000010 (PROGADDR_IRQ) */
.section .irq_vec, "ax"
.balign 16
    j       _freertos_irq_handler

/* Boot sequence */
.section .text
_boot:
    /* Set up global pointer for GP-relative data access */
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    /* Set stack pointer to top of SRAM */
    lui     sp, %hi(0x20002000)
    addi    sp, sp, %lo(0x20002000)

    /* Clear BSS */
    la      a0, _bss_start
    la      a1, _bss_end
1:  bge     a0, a1, 2f
    sw      zero, 0(a0)
    addi    a0, a0, 4
    j       1b
2:
    /* Copy initialised data from ROM (LMA) to SRAM (VMA) */
    la      a0, _data_lma
    la      a1, _data_start
    la      a2, _data_end
3:  bge     a1, a2, 4f
    lw      a3, 0(a0)
    sw      a3, 0(a1)
    addi    a0, a0, 4
    addi    a1, a1, 4
    j       3b
4:
    /* Call main (FreeRTOS application) */
    jal     ra, main

    /* Hang if main returns */
5:  j       5b
