ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 128K
}

SECTIONS
{
    . = ORIGIN(RAM);

    .text : {
        KEEP(*(.text.start))
        *(.text*)
    } > RAM

    .rodata : {
        *(.rodata*)
        *(.srodata*)
    } > RAM

    .data : {
        *(.data*)
        *(.sdata*)
    } > RAM

    .bss : {
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        __bss_end = .;
    } > RAM

    . = ALIGN(4);
    _end = .;
}
