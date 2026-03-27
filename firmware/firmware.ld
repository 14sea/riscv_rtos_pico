/* Linker script for PicoRV32 SoC
 * ROM: 0x00000000 - 0x00001FFF (8 KB)
 * RAM: 0x20000000 - 0x20001FFF (8 KB)
 */

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 8K
}

SECTIONS
{
    /* Code and read-only data in ROM */
    .init : {
        *(.init)
    } > ROM

    .irq_vec 0x00000010 : {
        *(.irq_vec)
    } > ROM

    .text : {
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > ROM

    /* Initialized data: stored in ROM, copied to RAM at boot */
    _data_lma = LOADADDR(.data);
    .data : {
        _data_start = .;
        *(.data .data.*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM AT > ROM

    /* Uninitialized data in RAM */
    .bss : {
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    /* Stack at top of RAM (grows downward) */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
