; =============================================================================
;  etapa2_f2.asm - Guía 1, Fase 2: segunda etapa con dibujo ASCII y menú
;
;  La carga la etapa 1 en 0000:8000 (ver disposicion.inc). Muestra una barra
;  que identifica la etapa, el caballo de la Fase 1 y un menú:
;     [1] Información del sistema    (INT 12h, INT 15h AH=88h, INT 10h AH=0Fh)
;     [2] Galope del caballo         (animación: redibuja y avanza 2 columnas)
;     [3] Fecha y hora               (reloj de tiempo real, INT 1Ah)
;     [0] Detener el sistema         (CLI + HLT)
;  Cualquier otra tecla muestra un aviso y se vuelve a pedir la opción.
;
;  Servicios BIOS usados:
;     INT 16h AH=00h  esperar tecla (AL = ASCII, AH = código de rastreo)
;     INT 10h AH=02h  mover cursor        AH=09h  escribir carácter + color
;     INT 10h AH=06h  limpiar una ventana
;
;  Convención de registros en las rutinas de pantalla:
;     DH:DL = fila:columna del cursor, BL = color actual, BH = página 0
; =============================================================================

bits 16

%include "disposicion.inc"
%include "video.inc"

org ETAPA2_OFF

FILA_MSG    equ 17              ; zona de respuestas: filas 17..23
FILA_VOLVER equ 23
COL_MSG     equ 4
FILA_GALOPE equ 5               ; fila superior del caballo en la animación

; ESCRIBIR fila, columna, etiqueta: dibuja un flujo de bytes en esa posición
%macro ESCRIBIR 3
    mov dx, ((%1) << 8) | (%2)
    mov si, %3
    call dibujar
%endmacro

; -----------------------------------------------------------------------------
cabecera:
    dd ETAPA2_FIRMA             ; la etapa 1 verifica estos 4 bytes

entrada:                        ; ETAPA2_OFF + 4
    xor ax, ax
    mov ds, ax
    mov es, ax
    cld
    mov [unidad], dl            ; interfaz: DL = unidad de arranque
    xor bx, bx                  ; BH = página 0 en todas las llamadas

menu:
    call pantalla_principal

leer_tecla:
    mov dx, [pos_prompt]
    call cursor
    xor ah, ah                  ; INT 16h AH=00h: esperar una tecla
    int 0x16
    cmp al, '1'
    je opcion_info
    cmp al, '2'
    je opcion_galope
    cmp al, '3'
    je opcion_reloj
    cmp al, '0'
    je opcion_detener

; --- entrada no válida: avisar y volver a leer sin redibujar ---------------
    mov [tecla], ax
    call limpiar_respuesta
    ESCRIBIR FILA_MSG, COL_MSG, txt_invalida
    mov ax, [tecla]
    cmp al, ' '                 ; ¿carácter imprimible?
    jb .sin_ascii
    cmp al, '~'
    ja .sin_ascii
    push ax
    mov al, "'"
    call poner_car
    pop ax
    call poner_car
    mov al, "'"
    call poner_car
.sin_ascii:
    mov si, txt_scan
    call dibujar
    mov al, [tecla + 1]         ; AH = código de rastreo
    call hex8
    mov al, ')'
    call poner_car
    ESCRIBIR FILA_MSG + 1, COL_MSG, txt_reintento
    jmp leer_tecla

; --- [1] información del sistema -------------------------------------------
opcion_info:
    call limpiar_respuesta
    ESCRIBIR FILA_MSG, COL_MSG, txt_info_titulo
    ESCRIBIR FILA_MSG + 1, COL_MSG, txt_mem_conv
    int 0x12                    ; AX = KB de memoria convencional
    call dec16
    mov si, txt_kb
    call dibujar
    ESCRIBIR FILA_MSG + 2, COL_MSG, txt_mem_ext
    mov ah, 0x88                ; AX = KB sobre 1 MB (máximo informado: 64 MB)
    int 0x15
    call dec16
    mov si, txt_kb
    call dibujar
    ESCRIBIR FILA_MSG + 3, COL_MSG, txt_video
    mov ah, 0x0F                ; AL = modo de video, AH = columnas
    int 0x10
    push ax
    call hex8
    mov si, txt_columnas
    call dibujar
    pop ax
    mov al, ah
    xor ah, ah
    call dec16
    ESCRIBIR FILA_MSG + 4, COL_MSG, txt_etapa2
    mov ax, ETAPA2_USADOS
    call dec16
    mov si, txt_bytes
    call dibujar
    call volver_al_menu
    jmp menu

; --- [2] galope del caballo -----------------------------------------------
opcion_galope:
    call limpiar_pantalla
    ESCRIBIR FILA_GALOPE, 0, caballo
    ESCRIBIR 24, 27, txt_cuenta
    mov al, '3'
.cuenta:
    call poner_car
    push ax
    mov al, ' '
    call poner_car
    mov cx, 18                  ; ~1 segundo
    call esperar_ticks
    pop ax
    dec al
    cmp al, '0'
    jne .cuenta

    mov byte [col_galope], 0
.galope:
    call limpiar_galope         ; borrar la posición anterior
    mov dh, FILA_GALOPE
    mov dl, [col_galope]
    mov si, caballo
    call dibujar                ; lo que pasa de la columna 79 no se escribe
    mov cx, 2                   ; dos ticks (~110 ms) por cuadro
    call esperar_ticks
    add byte [col_galope], 2
    cmp byte [col_galope], 80
    jb .galope
    call limpiar_pantalla

    ESCRIBIR 11, 15, txt_exito
    call volver_al_menu
    jmp menu

; --- [3] fecha y hora del reloj de tiempo real -----------------------------
opcion_reloj:
    call limpiar_respuesta
    mov ah, 0x04                ; INT 1Ah AH=04h: CH siglo, CL año, DH mes, DL día
    int 0x1A
    mov [rtc_fecha], cx
    mov [rtc_fecha + 2], dx
    mov ah, 0x02                ; INT 1Ah AH=02h: CH hora, CL min, DH seg
    int 0x1A
    mov [rtc_hora], cx
    mov [rtc_hora + 2], dx

    ESCRIBIR FILA_MSG, COL_MSG, txt_fecha   ; los valores vienen en BCD:
    mov al, [rtc_fecha + 1]                 ; en hexadecimal se leen tal cual
    call hex8
    mov al, [rtc_fecha]
    call hex8
    mov al, '-'
    call poner_car
    mov al, [rtc_fecha + 3]
    call hex8
    mov al, '-'
    call poner_car
    mov al, [rtc_fecha + 2]
    call hex8

    ESCRIBIR FILA_MSG + 1, COL_MSG, txt_hora
    mov al, [rtc_hora + 1]
    call hex8
    mov al, ':'
    call poner_car
    mov al, [rtc_hora]
    call hex8
    mov al, ':'
    call poner_car
    mov al, [rtc_hora + 3]
    call hex8
    ESCRIBIR FILA_MSG + 2, COL_MSG, txt_rtc_nota
    call volver_al_menu
    jmp menu

; --- [0] detener el sistema ------------------------------------------------
opcion_detener:
    call limpiar_pantalla
    ESCRIBIR 11, 14, txt_detenido
    mov ah, 0x01                ; ocultar el cursor
    mov cx, 0x2000
    int 0x10
    cli
.espera:
    hlt
    jmp .espera

; =============================================================================
;  Pantallas
; =============================================================================
pantalla_principal:
    call limpiar_pantalla
    mov dx, 0x0000              ; barra superior: fila 0 completa en azul
    mov bl, BARRA_SUP
    call cursor
    mov ax, 0x0920
    mov cx, 80
    int 0x10
    ESCRIBIR 0, 2, txt_titulo
    mov ax, ETAPA2_SEG
    call hex16
    mov al, ':'
    call poner_car
    mov ax, ETAPA2_OFF
    call hex16
    mov si, txt_unidad
    call dibujar
    mov al, [unidad]
    call hex8

    mov dx, 0x1800              ; barra inferior: fila 24
    mov bl, BARRA_INF
    call cursor
    mov ax, 0x0920
    mov cx, 80
    int 0x10
    ESCRIBIR 24, 2, txt_pie

    ESCRIBIR 2, 2, caballo
    ESCRIBIR 3, 44, txt_menu
    mov [pos_prompt], dx        ; aquí queda el cursor esperando la opción
    ret

volver_al_menu:
    ESCRIBIR FILA_VOLVER, COL_MSG, txt_volver
    xor ah, ah
    int 0x16
    ret

; =============================================================================
;  Rutinas de pantalla
; =============================================================================

; cursor: mueve el cursor a DH:DL (INT 10h AH=02h); fuera de pantalla no hace nada
cursor:
    cmp dl, 80
    jae .fuera
    push ax
    mov ah, 0x02
    int 0x10
    pop ax
.fuera:
    ret

; poner_car: escribe AL con el color BL en DH:DL y avanza una columna.
; Si la columna pasa de 79 no escribe (recorte para la animación).
poner_car:
    cmp dl, 80
    jae .recortar
    push ax
    push cx
    mov ah, 0x09
    mov cx, 1
    int 0x10
    pop cx
    pop ax
.recortar:
    inc dl
    jmp cursor

; dibujar: interpreta el flujo DS:SI desde DH:DL (DL inicial = margen)
dibujar:
    mov [margen], dl
    call cursor
.siguiente:
    lodsb
    test al, al
    jz .fin
    js .color
    cmp al, NL
    je .nueva_linea
    cmp al, ' '
    jb .saltar
    call poner_car
    jmp .siguiente
.saltar:
    add dl, al
    call cursor
    jmp .siguiente
.nueva_linea:
    inc dh
    mov dl, [margen]
    call cursor
    jmp .siguiente
.color:
    and al, 0x7F
    mov bl, al
    jmp .siguiente
.fin:
    ret

; hex16 / hex8: escriben AX / AL en hexadecimal
hex16:
    push ax
    mov al, ah
    call hex8
    pop ax
hex8:
    push ax
    shr al, 4
    call .digito
    pop ax
    push ax
    and al, 0x0F
    call .digito
    pop ax
    ret
.digito:
    add al, '0'
    cmp al, '9'
    jbe .poner
    add al, 7
.poner:
    jmp poner_car

; dec16: escribe AX en decimal
dec16:
    push ax
    push cx
    push si
    mov si, dx                  ; DX se usa en la división: guardar el cursor
    xor cx, cx
.dividir:
    xor dx, dx
    div word [diez]
    push dx                     ; resto = dígito
    inc cx
    test ax, ax
    jnz .dividir
    mov dx, si
.escribir:
    pop ax
    add al, '0'
    call poner_car
    loop .escribir
    pop si
    pop cx
    pop ax
    ret

limpiar_galope:                 ; filas que ocupa el caballo en la animación
    push cx
    push dx
    mov cx, (FILA_GALOPE << 8) | 0
    mov dx, ((FILA_GALOPE + 13) << 8) | 79
    jmp limpiar
limpiar_pantalla:
    push cx
    push dx
    xor cx, cx
    mov dx, 0x184F
    jmp limpiar
limpiar_respuesta:
    push cx
    push dx
    mov cx, (FILA_MSG << 8) | 0
    mov dx, (FILA_VOLVER << 8) | 79
limpiar:                        ; borra la ventana CH:CL - DH:DL
    push bx
    mov ax, 0x0600
    mov bh, GRIS
    int 0x10
    pop bx
    pop dx
    pop cx
    ret

; esperar_ticks: espera CX ticks del temporizador del BIOS (~55 ms cada uno)
esperar_ticks:
    push ax
.tick:
    mov ax, [0x046C]
.mismo:
    hlt                         ; dormir hasta la próxima interrupción
    cmp ax, [0x046C]
    je .mismo
    loop .tick
    pop ax
    ret

; =============================================================================
;  Datos
; =============================================================================
%include "dibujo.inc"

txt_titulo      db C(BARRA_SUP), "MICRO S.O.  |  ETAPA 2  |  cargada en ", 0
txt_unidad      db " desde LBA 1  |  unidad 0x", 0
txt_pie         db C(BARRA_INF), "Teclado: INT 16h  |  Video: INT 10h  |  Disco: INT 13h AH=02h (CHS)", 0

txt_menu        db C(AMARILLO), "MENU PRINCIPAL", NL
                db C(GRIS), "----------------------------", NL, NL
                db C(CIAN), "[1] ", C(BLANCO), "Informacion del sistema", NL
                db C(CIAN), "[2] ", C(BLANCO), "Galope del caballo", NL
                db C(CIAN), "[3] ", C(BLANCO), "Fecha y hora (RTC)", NL
                db C(CIAN), "[0] ", C(BLANCO), "Detener el sistema", NL, NL
                db C(GRIS), "Seleccione una opcion: ", 0

txt_invalida    db C(ROJO_CLARO), "Opcion no valida: ", 0
txt_scan        db C(ROJO_CLARO), " (codigo de tecla 0x", 0
txt_reintento   db C(GRIS), "Use 1, 2, 3 o 0. Intente nuevamente.", 0

txt_info_titulo db C(AMARILLO), "Informacion del sistema", 0
txt_mem_conv    db C(GRIS), "Memoria convencional (INT 12h) ......... ", C(BLANCO), 0
txt_mem_ext     db C(GRIS), "Memoria extendida (INT 15h AH=88h) ..... ", C(BLANCO), 0
txt_video       db C(GRIS), "Modo de video (INT 10h AH=0Fh) ......... ", C(BLANCO), "0x", 0
txt_columnas    db C(GRIS), ", columnas: ", C(BLANCO), 0
txt_etapa2      db C(GRIS), "Etapa 2: LBA 1, 16 sectores reservados, ", C(BLANCO), 0
txt_kb          db C(GRIS), " KB", 0
txt_bytes       db C(GRIS), " bytes usados", 0

txt_cuenta      db C(AMARILLO), "Partida en: ", 0
txt_exito       db C(VERDE), "Galope completo: el caballo cruzo la pantalla", 0

txt_fecha       db C(GRIS), "Fecha (INT 1Ah AH=04h) ... ", C(BLANCO), 0
txt_hora        db C(GRIS), "Hora  (INT 1Ah AH=02h) ... ", C(BLANCO), 0
txt_rtc_nota    db C(GRIS), "Reloj de tiempo real emulado por QEMU (UTC por defecto)", 0

txt_volver      db C(AZUL_CLARO), "Presione cualquier tecla para volver al menu...", 0
txt_detenido    db C(VERDE), "Sistema detenido de forma controlada. Ya puede cerrar QEMU.", 0

diez            dw 10
unidad          db 0
margen          db 0
col_galope      db 0
tecla           dw 0
pos_prompt      dw 0
rtc_fecha       dd 0
rtc_hora        dd 0

ETAPA2_USADOS   equ $ - $$

; Relleno hasta el tamaño reservado; NASM falla si la etapa 2 lo excede.
times ETAPA2_SECTORES * 512 - ($ - $$) db 0
