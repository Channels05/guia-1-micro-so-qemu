/* linker.ld - Disposición del kernel en memoria física (cargado en 1 MiB) */
ENTRY(_start)

SECTIONS
{
    . = 1M;

    /* La cabecera Multiboot2 va primero para quedar en los primeros 32 KiB */
    .text ALIGN(4K) : { *(.multiboot2) *(.text*) }
    .rodata ALIGN(4K) : { *(.rodata*) }
    .data ALIGN(4K) : { *(.data*) }
    .bss ALIGN(4K) : { *(COMMON) *(.bss*) }

    /DISCARD/ : { *(.note*) *(.comment*) *(.eh_frame*) }
}
