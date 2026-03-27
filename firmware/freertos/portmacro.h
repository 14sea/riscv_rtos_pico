/* PicoRV32 FreeRTOS port — portmacro.h
 *
 * PicoRV32 uses a custom (non-standard) IRQ mechanism instead of standard
 * RISC-V CSRs (mstatus, mie, mtvec, mcause, mepc, mret).
 * Custom instructions (opcode = 0x0B = 0b0001011):
 *   maskirq rd, rs  funct7=0x03  rd←old_mask; irq_mask←rs
 *   timer   rd, rs  funct7=0x05  rd←old_timer; set_countdown(rs)
 *   retirq          funct7=0x02  jump to q0; irq_active←0
 *   getq    rd, qs  funct7=0x00  rd←q_reg[qs]
 *   setq    qd, rs  funct7=0x01  q_reg[qd]←rs
 *
 * IRQ mask convention: bit=0 → IRQ enabled, bit=1 → IRQ masked.
 * IRQ bits: 0=timer, 1=ebreak/ecall (portYIELD), 2=bus-error, 3+=external.
 */

#ifndef PORTMACRO_H
#define PORTMACRO_H

#ifdef __cplusplus
extern "C" {
#endif

/* ---- Type definitions ---- */
#define portSTACK_TYPE          uint32_t
#define portBASE_TYPE           int32_t
#define portUBASE_TYPE          uint32_t
#define portMAX_DELAY           ( ( TickType_t ) 0xffffffffUL )

typedef portSTACK_TYPE      StackType_t;
typedef portBASE_TYPE       BaseType_t;
typedef portUBASE_TYPE      UBaseType_t;
typedef portUBASE_TYPE      TickType_t;

/* Legacy */
#define portCHAR        char
#define portFLOAT       float
#define portDOUBLE      double
#define portLONG        long
#define portSHORT       short

/* 32-bit tick on 32-bit arch → atomic reads */
#define portTICK_TYPE_IS_ATOMIC     1

/* ---- Architecture ---- */
#define portSTACK_GROWTH            ( -1 )
#define portTICK_PERIOD_MS          ( ( TickType_t ) 1000 / configTICK_RATE_HZ )
#define portBYTE_ALIGNMENT          16
#define portBYTE_ALIGNMENT_MASK     ( portBYTE_ALIGNMENT - 1 )

/* ---- PicoRV32 custom instruction encodings ----
 * R-type: funct7[31:25]|rs2[24:20]|rs1[19:15]|funct3[14:12]|rd[11:7]|opcode[6:0]
 *
 * maskirq a0, a0  (x10←old_mask; irq_mask←x10):
 *   funct7=3, rs2=0, rs1=10, funct3=0, rd=10, op=0x0B  → 0x0605050B
 * maskirq x0, x0  (irq_mask←0; rd=x0 discarded):
 *   funct7=3, rs2=0, rs1=0,  funct3=0, rd=0,  op=0x0B  → 0x0600000B
 */

/* portDISABLE_INTERRUPTS — mask all IRQs (irq_mask = 0xFFFFFFFF) */
#define portDISABLE_INTERRUPTS()                                            \
    do {                                                                    \
        register unsigned int _m __asm__("a0") = 0xFFFFFFFFU;              \
        __asm__ volatile ( ".word 0x0605050B\n" : "+r"(_m) );              \
    } while(0)

/* portENABLE_INTERRUPTS — unmask all IRQs (irq_mask = 0) */
#define portENABLE_INTERRUPTS()                                             \
    do {                                                                    \
        register unsigned int _m __asm__("a0") = 0U;                       \
        __asm__ volatile ( ".word 0x0605050B\n" : "+r"(_m) );              \
    } while(0)

/* Critical section nesting counter (0 = not in critical section) */
extern volatile unsigned int xCriticalNesting;

#define portCRITICAL_NESTING_IN_TCB     0

#define portENTER_CRITICAL()                    \
    do {                                        \
        portDISABLE_INTERRUPTS();               \
        xCriticalNesting++;                     \
    } while(0)

#define portEXIT_CRITICAL()                     \
    do {                                        \
        xCriticalNesting--;                     \
        if( xCriticalNesting == 0 ) {           \
            portENABLE_INTERRUPTS();            \
        }                                       \
    } while(0)

/* ---- Scheduler utilities ---- */
extern void vTaskSwitchContext( void );

/* portYIELD: ecall triggers IRQ bit 1 (irq_ebreak) */
#define portYIELD()     __asm__ volatile ( "ecall" )

#define portEND_SWITCHING_ISR( xSwitchRequired )    \
    do {                                            \
        if( ( xSwitchRequired ) != pdFALSE ) {      \
            vTaskSwitchContext();                    \
        }                                           \
    } while(0)

#define portYIELD_FROM_ISR( x )     portEND_SWITCHING_ISR( x )

/* ---- Optimised task selection (CLZ-based, up to 32 priorities) ---- */
#ifndef configUSE_PORT_OPTIMISED_TASK_SELECTION
    #define configUSE_PORT_OPTIMISED_TASK_SELECTION     1
#endif

#if ( configUSE_PORT_OPTIMISED_TASK_SELECTION == 1 )
    #if ( configMAX_PRIORITIES > 32 )
        #error "configUSE_PORT_OPTIMISED_TASK_SELECTION requires configMAX_PRIORITIES <= 32"
    #endif
    #define portRECORD_READY_PRIORITY( uxPrio, uxBitmap )   \
                ( uxBitmap ) |= ( 1UL << ( uxPrio ) )
    #define portRESET_READY_PRIORITY( uxPrio, uxBitmap )    \
                ( uxBitmap ) &= ~( 1UL << ( uxPrio ) )
    #define portGET_HIGHEST_PRIORITY( uxTop, uxBitmap )     \
                uxTop = ( 31UL - __builtin_clz( uxBitmap ) )
#endif

/* ---- Task function macros ---- */
#define portTASK_FUNCTION_PROTO( vFunc, pvParams )  void vFunc( void * pvParams )
#define portTASK_FUNCTION( vFunc, pvParams )        void vFunc( void * pvParams )

/* ---- Misc ---- */
#define portNOP()               __asm__ volatile ( "nop" )
#define portINLINE              __inline
#ifndef portFORCE_INLINE
    #define portFORCE_INLINE    inline __attribute__( ( always_inline ) )
#endif
#define portMEMORY_BARRIER()    __asm__ volatile ( "" ::: "memory" )

#ifdef __cplusplus
}
#endif

#endif /* PORTMACRO_H */
