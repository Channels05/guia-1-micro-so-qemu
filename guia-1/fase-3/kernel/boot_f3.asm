; =============================================================================
;  boot_f3.asm - Guía 1, Fase 3: cabecera Multiboot2 y punto de entrada
;
;  GRUB busca la cabecera Multiboot2 en los primeros 32 KiB del ELF. En ella
;  el kernel pide un framebuffer lineal de 800x600 a 32 bits por píxel. GRUB
;  carga el kernel en 1 MiB, pasa a modo protegido de 32 bits y salta a
;  _start con:
;     EAX = 0x36D76289 (magic que identifica a un cargador Multiboot2)
;     EBX = dirección física de la estructura de información Multiboot2
;  _start arma una pila y llama a kmain(magic, info) escrito en C.
;
;  Ensamblar: nasm -f elf32 kernel/boot_f3.asm -o build/boot_f3.o
; =============================================================================

MB2_MAGIC     equ 0xE85250D6
MB2_ARQ_I386  equ 0

ANCHO_PEDIDO  equ 800
ALTO_PEDIDO   equ 600
BPP_PEDIDO    equ 32

section .multiboot2
align 8
mb2_inicio:
    dd MB2_MAGIC
    dd MB2_ARQ_I386
    dd mb2_fin - mb2_inicio
    dd 0x100000000 - (MB2_MAGIC + MB2_ARQ_I386 + (mb2_fin - mb2_inicio))

align 8                         ; etiqueta 5: framebuffer preferido
    dw 5                        ; tipo
    dw 1                        ; flags: opcional (permite la prueba en texto)
    dd 20                       ; tamaño de la etiqueta
    dd ANCHO_PEDIDO
    dd ALTO_PEDIDO
    dd BPP_PEDIDO

align 8                         ; etiqueta 0: fin
    dw 0
    dw 0
    dd 8
mb2_fin:

section .text
global _start
extern kmain

_start:
    cli
    mov esp, pila_tope          ; pila propia de 16 KiB
    xor ebp, ebp
    push ebx                    ; 2.º argumento: dirección de la info Multiboot2
    push eax                    ; 1.er argumento: magic del cargador
    call kmain                  ; kmain no debería volver
.detener:
    cli
    hlt
    jmp .detener

section .bss
align 16
pila:
    resb 16384
pila_tope:

section .note.GNU-stack noalloc noexec nowrite progbits   ; pila no ejecutable
