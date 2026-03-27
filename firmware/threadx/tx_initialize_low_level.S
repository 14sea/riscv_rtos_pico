/* PicoRV32 ThreadX port — tx_initialize_low_level.S
 *
 * _tx_initialize_low_level
 *
 * Called by tx_kernel_enter() before tx_application_define().
 * Sets up two key ThreadX globals:
 *   _tx_initialize_unused_memory — first available byte after kernel data
 *   _tx_thread_system_stack_ptr  — system stack (top of SRAM; not used in
 *                                  IRQ handler but ThreadX may reference it)
 *
 * The timer is NOT armed here; it is armed in _tx_thread_schedule just
 * before jumping to the first thread.
 */

.section .text
.global _tx_initialize_low_level
.extern _tx_initialize_unused_memory
.extern _tx_thread_system_stack_ptr

_tx_initialize_low_level:
    /* _tx_initialize_unused_memory = &_bss_end (first free SRAM byte) */
    la      t0, _bss_end
    la      t1, _tx_initialize_unused_memory
    sw      t0, 0(t1)

    /* _tx_thread_system_stack_ptr = top of SRAM (0x20002000) */
    lui     t0, %hi(0x20002000)
    addi    t0, t0, %lo(0x20002000)
    la      t1, _tx_thread_system_stack_ptr
    sw      t0, 0(t1)

    ret
