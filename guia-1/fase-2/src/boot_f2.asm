; =============================================================================
;  boot_f2.asm - Guía 1, Fase 2: etapa 1 (sector de arranque de 512 bytes)
;
;  1. Inicializa segmentos y pila, guarda la unidad de arranque (DL).
;  2. Lee la etapa 2 desde el disquete con INT 13h AH=02h (direccionamiento
;     CHS), con hasta 3 intentos y reinicio de la controladora entre ellos.
;  3. Comprueba la firma "ETP2" al inicio de lo leído.
;  4. Transfiere el control a la etapa 2 (salto lejano a 0000:8004).
;  Ante un error de lectura o de firma muestra un mensaje y detiene la CPU.
; =============================================================================

bits 16
org 0x7C00

%include "disposicion.inc"

INTENTOS    equ 3

inicio:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    cld
    mov [unidad], dl            ; el BIOS informa la unidad de arranque en DL

    mov ax, 0x0003              ; modo texto 80x25 (limpia la pantalla)
    int 0x10

    mov si, msg_carga
    call imprimir

    mov di, INTENTOS
leer:
    mov ax, ETAPA2_SEG
    mov es, ax
    mov bx, ETAPA2_OFF          ; ES:BX = destino
    mov ah, 0x02                ; INT 13h AH=02h: leer sectores (CHS)
    mov al, ETAPA2_SECTORES     ; cantidad de sectores
    mov ch, 0                   ; cilindro 0
    mov cl, ETAPA2_LBA + 1      ; sector (en CHS se numeran desde 1)
    mov dh, 0                   ; cabeza 0
    mov dl, [unidad]
    int 0x13
    jnc leido                   ; CF = 0 -> lectura correcta

    push ax                     ; AH = código de error del BIOS
    xor ah, ah                  ; INT 13h AH=00h: reiniciar la controladora
    mov dl, [unidad]
    int 0x13
    pop ax
    dec di
    jnz leer

    push ax                     ; se agotaron los intentos
    mov si, msg_err_lectura
    call imprimir
    pop ax
    mov al, ah
    call imprimir_hex
    jmp detener

leido:
    cmp dword [ETAPA2_OFF], ETAPA2_FIRMA
    jne firma_invalida

    mov si, msg_ok
    call imprimir

    mov ax, [0x046C]            ; contador de ticks del BIOS (18,2 por segundo)
    add ax, 36                  ; pausa de ~2 s para que el mensaje se vea
.pausa:
    hlt
    cmp ax, [0x046C]
    jne .pausa

    mov dl, [unidad]            ; interfaz: DL = unidad de arranque
    jmp ETAPA2_SEG:ETAPA2_OFF + 4

firma_invalida:
    mov si, msg_err_firma
    call imprimir

detener:
    cli
.espera:
    hlt
    jmp .espera

; --- imprimir: escribe la cadena DS:SI terminada en 0 (INT 10h AH=0Eh) ------
imprimir:
    lodsb
    test al, al
    jz .fin
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    jmp imprimir
.fin:
    ret

; --- imprimir_hex: escribe AL como dos dígitos hexadecimales ----------------
imprimir_hex:
    push ax
    shr al, 4
    call .digito
    pop ax
    and al, 0x0F
.digito:
    add al, '0'
    cmp al, '9'
    jbe .poner
    add al, 7                   ; 'A' - '9' - 1
.poner:
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    ret

unidad          db 0
msg_carga       db "[etapa 1] Sector de arranque en 0000:7C00", 13, 10
                db "[etapa 1] Leyendo etapa 2: LBA 1, 16 sectores -> 0000:8000 ... ", 0
msg_ok          db "OK", 13, 10, "[etapa 1] Firma ETP2 correcta, saltando a 0000:8004", 0
msg_err_lectura db "ERROR", 13, 10, "[etapa 1] Fallo INT 13h, codigo AH=0x", 0
msg_err_firma   db "ERROR", 13, 10, "[etapa 1] Firma ETP2 no encontrada: no hay etapa 2", 13, 10
                db "[etapa 1] Sistema detenido.", 0

times 510 - ($ - $$) db 0
dw 0xAA55
