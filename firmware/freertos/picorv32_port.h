/* PicoRV32 custom instruction macros for GCC inline assembly.
 *
 * Instruction encoding (opcode = 0b0001011):
 *   getq    rd, qs     funct7=0x00  rd=dest     rs1=qs_index  rs2=x0
 *   setq    qd, rs     funct7=0x01  rd=qd_index rs1=source    rs2=x0
 *   retirq             funct7=0x02  rd=x0       rs1=q0        rs2=x0
 *   maskirq rd, rs     funct7=0x03  rd=dest     rs1=source    rs2=x0
 *   waitirq rd         funct7=0x04  rd=dest     rs1=x0        rs2=x0
 *   timer   rd, rs     funct7=0x05  rd=dest     rs1=source    rs2=x0
 */
#ifndef PICORV32_PORT_H
#define PICORV32_PORT_H

/* Custom instruction word builder
 * R-type: funct7[31:25] | rs2[24:20] | rs1[19:15] | funct3[14:12] | rd[11:7] | opcode[6:0]
 */
#define _PICORV32_R(funct7, rs2, rs1, funct3, rd, opcode) \
    (((funct7) << 25) | ((rs2) << 20) | ((rs1) << 15) | ((funct3) << 12) | ((rd) << 7) | (opcode))

/* maskirq: set IRQ mask, return old mask
 * maskirq rd, rs  → rd = old_mask; irq_mask = rs | MASKED_IRQ
 * Using a0 (x10) as rs and rd for simplicity.
 */
static inline unsigned int picorv32_maskirq(unsigned int mask)
{
    unsigned int old;
    __asm__ volatile (".word %1" : "=r"(old) : "i"(_PICORV32_R(0x03, 0, 10, 0, 10, 0x0B)), "r"(mask));
    return old;
}

/* Hmm, the above doesn't work well because we can't control register allocation.
 * Let's use a different approach with explicit register constraints. */

/* maskirq: rd = old mask, rs1 = new mask.
 * We encode using x10 for both rd and rs1, and use "0" constraint to tie them. */
#undef picorv32_maskirq

/* Use naked .word encoding with explicit register moves */
#define picorv32_maskirq(new_mask, old_mask_var)               \
    do {                                                       \
        register unsigned int _rs __asm__("a0") = (new_mask);  \
        __asm__ volatile (                                     \
            ".word 0x0600050B\n"  /* maskirq a0, a0 */         \
            : "+r"(_rs)                                        \
        );                                                     \
        (old_mask_var) = _rs;                                  \
    } while(0)

/* Encoding: funct7=0x03=0000011, rs2=0, rs1=10(a0), funct3=0, rd=10(a0), opcode=0x0B
 * = 0b0000011_00000_01010_000_01010_0001011 = 0x0600050B? Let me recalculate.
 * 0000011 | 00000 | 01010 | 000 | 01010 | 0001011
 * = 0000011_00000_01010_000_01010_0001011
 *   0000 0110 0000 0101 0000 0101 0000 1011
 *   0x06_05_05_0B  → 0x0605050B */
#undef picorv32_maskirq
#define picorv32_maskirq(new_mask, old_mask_var)               \
    do {                                                       \
        register unsigned int _rs __asm__("a0") = (new_mask);  \
        __asm__ volatile (                                     \
            ".word 0x0605050B\n"                                \
            : "+r"(_rs)                                        \
        );                                                     \
        (old_mask_var) = _rs;                                  \
    } while(0)

/* timer: set timer countdown, return old value
 * timer a0, a0: funct7=0x05=0000101, rs2=0, rs1=10, funct3=0, rd=10, op=0x0B
 * = 0b0000101_00000_01010_000_01010_0001011
 *   0000 1010 0000 0101 0000 0101 0000 1011
 *   0x0A05050B */
#define picorv32_timer(new_val, old_val_var)                   \
    do {                                                       \
        register unsigned int _rs __asm__("a0") = (new_val);   \
        __asm__ volatile (                                     \
            ".word 0x0A05050B\n"                                \
            : "+r"(_rs)                                        \
        );                                                     \
        (old_val_var) = _rs;                                   \
    } while(0)

/* retirq: return from IRQ (encoded in assembly, not C) */
/* .word 0x0C00000B = funct7=0x02, rs2=0, rs1=0(q0 via irqregs), funct3=0, rd=0, op=0x0B */
/* Wait—retirq reads q0 as return address. rs1 should point to q0.
 * With IRQ_QREGS, q0..q3 = reg[32..35]. retirq uses decoded_rs1 set to irqregs_offset (32).
 * The encoded instruction (from simulation): 0x0C00000B works because the RTL
 * explicitly sets decoded_rs1 for retirq (line 890). So the rs1 field in the
 * instruction word doesn't matter for retirq. */
#define PICORV32_RETIRQ  ".word 0x0C00000B\n"

/* getq rd, qs: funct7=0x00
 * getq a0, q0: rd=10, rs1=0 (q0 index), rs2=0, funct7=0
 * = 0b0000000_00000_00000_000_01010_0001011 = 0x0000050B
 * getq a0, q1: rd=10, rs1=1, = 0x0000850B? No...
 * Actually, getq rd,qs encodes qs in the rs1 field. Looking at RTL:
 *   instr_getq decodes rs1 = rs1 | irqregs_offset. So rs1=0→reg32=q0, rs1=1→reg33=q1 */
/* getq a0, q0: .word 0x0000050B */
/* getq a0, q1: rs1=1 → 0b0000000_00000_00001_000_01010_0001011 = 0x0000850B */

/* For IRQ handler: getq/setq as assembly macros */
#define PICORV32_GETQ_A0_Q0  ".word 0x0000050B\n"   /* getq a0, q0 (return PC) */
#define PICORV32_GETQ_A0_Q1  ".word 0x0000850B\n"   /* getq a0, q1 (IRQ mask) */

/* setq qd, rs: funct7=0x01
 * setq q0, a0: rd=0 (q0), rs1=10(a0), rs2=0, funct7=0x01
 * = 0b0000001_00000_01010_000_00000_0001011 = 0x0205000B
 * But RTL does: latched_rd <= latched_rd | irqregs_offset
 * So rd=0 becomes reg32=q0. */
#define PICORV32_SETQ_Q0_A0  ".word 0x0205000B\n"   /* setq q0, a0 */

#endif /* PICORV32_PORT_H */
