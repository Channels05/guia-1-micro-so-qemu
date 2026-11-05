; =============================================================================
;  boot_f1.asm - Guía 1, Fase 1: sector de arranque BIOS con dibujo ASCII
;  INFB6074 Infraestructura para Ciencia de Datos - UTEM
;
;  El BIOS copia este sector (512 bytes) a la dirección física 0x7C00 y salta
;  a él en modo real de 16 bits. El programa:
;    1. inicializa segmentos y pila,
;    2. pone el modo texto 80x25 (lo que además limpia la pantalla),
;    3. recorre un flujo de bytes que describe un caballo al galope a color y
;       lo dibuja con los servicios de video del BIOS (INT 10h),
;    4. detiene la CPU de forma controlada.
;
;  Formato del flujo de bytes del dibujo:
;    0x00            fin del dibujo
;    0x0A (NL)       salto de línea: fila + 1, columna = MARGEN
;    0x01..0x1F      (excepto 0x0A) avanzar N columnas sin escribir
;    0x80..0xFF      cambiar color: atributo = byte & 0x7F
;    resto           carácter imprimible, se escribe con el color actual
;
;  Ensamblar:  nasm -f bin boot_f1.asm -o build/boot_f1.bin
; =============================================================================

bits 16
org 0x7C00                      ; dirección donde el BIOS deja el sector

MARGEN      equ 20              ; columna izquierda del dibujo (centrado en 80)
FILA_INI    equ 2               ; fila de la primera línea del dibujo

; Atributos de color del modo texto (fondo negro, nibble bajo = color de letra)
CAFE        equ 0x06
GRIS        equ 0x07
VERDE       equ 0x0A
AMARILLO    equ 0x0E
BLANCO      equ 0x0F

%define C(a)  (0x80 | (a))      ; código "cambiar color"
%define NL    10                ; código "salto de línea"

inicio:
    cli                         ; sin interrupciones mientras se arma la pila
    xor ax, ax
    mov ds, ax                  ; DS = ES = SS = 0 -> direcciones = offsets
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00              ; la pila crece hacia abajo desde el sector
    sti
    cld                         ; LODSB avanza SI hacia adelante

    mov ax, 0x0003              ; INT 10h AH=00h: modo texto 80x25, 16 colores
    int 0x10                    ; (cambiar de modo limpia la pantalla)

    mov ah, 0x01                ; INT 10h AH=01h: forma del cursor
    mov cx, 0x2000              ; bit 5 de CH = cursor oculto
    int 0x10

    mov si, dibujo              ; SI recorre el flujo de bytes
    mov bx, GRIS                ; BH = página 0, BL = atributo actual
    mov dx, (FILA_INI << 8) | MARGEN   ; DH = fila, DL = columna

posicionar:
    mov ah, 0x02                ; INT 10h AH=02h: mover cursor a DH:DL
    int 0x10

siguiente:
    lodsb                       ; AL = siguiente byte del dibujo
    test al, al
    jz detener                  ; 0x00 -> fin
    js cambiar_color            ; bit 7 encendido -> color
    cmp al, NL
    je nueva_linea
    cmp al, 0x20
    jb saltar                   ; 0x01..0x1F -> avanzar columnas

    mov ah, 0x09                ; INT 10h AH=09h: escribir carácter + atributo
    mov cx, 1                   ; una repetición, sin mover el cursor
    int 0x10
    inc dl                      ; la columna avanza a mano
    jmp posicionar

saltar:
    add dl, al
    jmp posicionar

nueva_linea:
    inc dh
    mov dl, MARGEN
    jmp posicionar

cambiar_color:
    and al, 0x7F
    mov bl, al
    jmp siguiente

detener:
    cli                         ; nada más que hacer: CPU detenida
.espera:
    hlt
    jmp .espera

; -----------------------------------------------------------------------------
;  Dibujo: caballo al galope sobre el pasto (diseño propio, 14 filas x 39
;  columnas). Las líneas db se generan desde el texto de abajo con
;  herramientas/ascii_a_nasm.py: cada racha de espacios es un byte "avanzar".
;
;                                    _/\
;                                  _/~~ \
;                                _/~~ o  `-._
;                              _/~~   ,-.___)
;                            _/~~    /
;           ___.------------'~~     |
;        ,-'                        |
;      ~(                           /
;      ~~\   .------------------.  /\
;       ~ /  /\                 \  \ `-----.
;        / /  \ \                \  \`-----'
;       / /    \ \               /  /
;      /_/      \_\             /__/
;       ,  .,  ' , .  ,  ., '  ,  . ,  .,  ' ,
; -----------------------------------------------------------------------------
dibujo:
    db 30, C(AMARILLO), "_/\", NL
    db 28, "_/", C(CAFE), "~~ ", C(AMARILLO), "\", NL
    db 26, "_/", C(CAFE), "~~ ", C(BLANCO), "o", 2, C(AMARILLO), "`-._", NL
    db 24, "_/", C(CAFE), "~~", 3, C(AMARILLO), ",-.___)", NL
    db 22, "_/", C(CAFE), "~~", 4, C(AMARILLO), "/", NL
    db 5, "___.------------'", C(CAFE), "~~", 5, C(AMARILLO), "|", NL
    db 2, ",-'", 24, "|", NL
    db C(CAFE), "~", C(AMARILLO), "(", 27, "/", NL
    db C(CAFE), "~~", C(AMARILLO), "\", 3, ".------------------.", 2, "/\", NL
    db 1, C(CAFE), "~ ", C(AMARILLO), "/", 2, "/\", 17, "\", 2, "\ `-----.", NL
    db 2, "/ /", 2, "\ \", 16, "\", 2, "\`-----'", NL
    db 1, "/ /", 4, "\ \", 15, "/", 2, "/", NL
    db "/_/", 6, "\_\", 13, "/__/", NL
    db 1, C(VERDE), ",", 2, ".,", 2, "' , .", 2, ",", 2, "., '", 2, ",", 2, ". ,", 2, ".,", 2, "' ,", NL
    db NL
    db 11, C(BLANCO), "MICRO S.O. FASE 1", NL
    db 8, C(GRIS), "Arranque BIOS 512 bytes", 0

; -----------------------------------------------------------------------------
;  Relleno hasta el byte 510 y firma de arranque 0x55 0xAA (little endian).
;  Si el código crece más allá de 510 bytes, NASM falla con "TIMES value is
;  negative", lo que actúa como comprobación del tamaño en tiempo de ensamblado.
; -----------------------------------------------------------------------------
times 510 - ($ - $$) db 0
dw 0xAA55
