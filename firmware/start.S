/* Boot code for PicoRV32 SoC
 * ROM at 0x00000000, SRAM at 0x20000000
 *
 * PicoRV32 IRQ custom instructions (encoded as .word):
 *   getq rd, qs    -> .insn r 0b0001011, 0, 4, rd, qs, x0
 *   setq qd, rs    -> .insn r 0b0001011, 0, 5, qd, x0, rs
 *   retirq         -> .insn r 0b0001011, 0, 6, x0, x0, x0
 *   maskirq rd, rs -> .insn r 0b0001011, 0, 3, rd, rs, x0
 *   timer rd, rs   -> .insn r 0b0001011, 0, 5, rd, x0, rs
 */

.section .init, "ax"
.global _start

/* Reset vector at 0x00000000 */
_start:
    j _boot          /* jump over IRQ vector */
    nop
    nop
    nop

/* IRQ vector at 0x00000010 (PROGADDR_IRQ) */
.balign 16
_irq_handler:
    /* For bare-metal: just return from IRQ without doing anything */
    /* retirq = opcode 0b0001011, funct7=6, rs2=0, rs1=0, funct3=0, rd=0 */
    .word 0x0400000B    /* retirq (funct7=2, opcode=0x0B) */

.balign 4
_boot:
    /* Set up stack pointer at top of SRAM */
    lui sp, %hi(0x20002000)
    addi sp, sp, %lo(0x20002000)

    /* Clear BSS */
    la a0, _bss_start
    la a1, _bss_end
1:  bge a0, a1, 2f
    sw zero, 0(a0)
    addi a0, a0, 4
    j 1b
2:

    /* Copy .data from ROM (LMA) to SRAM (VMA) */
    la a0, _data_lma
    la a1, _data_start
    la a2, _data_end
3:  bge a1, a2, 4f
    lw a3, 0(a0)
    sw a3, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j 3b
4:

    /* Call main */
    jal ra, main

    /* Halt if main returns */
5:  j 5b
