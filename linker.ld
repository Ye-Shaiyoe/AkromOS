
/* linker.ld - Linker script untuk SimpleOS */

OUTPUT_FORMAT(binary)
ENTRY(_start)

SECTIONS
{
    . = 0x1000;

    .text : ALIGN(512)
    {
        *(.text)
    }

    .rodata : ALIGN(512)
    {
        *(.rodata)
    }

    .data : ALIGN(512)
    {
        *(.data)
    }

    .bss : ALIGN(512)
    {
        *(COMMON)
        *(.bss)
    }
}
