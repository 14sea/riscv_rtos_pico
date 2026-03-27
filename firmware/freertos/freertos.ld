/* Linker script for PicoRV32 FreeRTOS build
 *
 * ROM : 16 KB at 0x00000000  (M9K BRAM, read-only after programming)
 * RAM :  8 KB at 0x20000000  (M9K BRAM, read/write)
 * Stack top: 0x20002000 (set in start_freertos.S)
 */

ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 8K
}

SECTIONS
{
    /* Reset vector — must be first in ROM */
    .init : {
        KEEP(*(.init))
    } > ROM

    /* IRQ vector placed at exactly 0x00000010 (PROGADDR_IRQ) */
    .irq_vec 0x00000010 : {
        KEEP(*(.irq_vec))
    } > ROM

    /* Code and read-only data */
    .text : {
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > ROM

    /* Initialised data: stored in ROM, copied to RAM at boot */
    _data_lma = LOADADDR(.data);
    .data : {
        _data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM AT > ROM

    /* Global pointer anchor (must follow .sdata) */
    . = ALIGN(4);
    PROVIDE( __global_pointer$ = . + 0x800 );

    /* Zero-initialised data */
    .bss : {
        _bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    /* Stack symbol (grows downward from top of RAM) */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
