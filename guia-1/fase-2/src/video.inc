; =============================================================================
;  video.inc - Colores del modo texto y códigos del formato de dibujo
;
;  Formato de flujo de bytes (el mismo de la Fase 1):
;    0x00            fin
;    0x0A (NL)       salto de línea: fila + 1, columna = margen inicial
;    0x01..0x1F      (excepto 0x0A) avanzar N columnas sin escribir
;    0x80..0xFF      cambiar color: atributo = byte & 0x7F
;    resto           carácter imprimible
;  Por eso los textos no usan tildes: en UTF-8 serían bytes >= 0x80.
; =============================================================================

CAFE        equ 0x06
GRIS        equ 0x07
AZUL_CLARO  equ 0x09
VERDE       equ 0x0A
CIAN        equ 0x0B
ROJO        equ 0x04
ROJO_CLARO  equ 0x0C
AMARILLO    equ 0x0E
BLANCO      equ 0x0F
BARRA_SUP   equ 0x1F            ; blanco sobre azul
BARRA_INF   equ 0x70            ; negro sobre gris

%define C(a)  (0x80 | (a))
%define NL    10
