; =============================================================================
;  dibujo.inc - Caballo de la Fase 1 (mismo diseño), en formato de flujo
;  14 filas x 39 columnas; las columnas son relativas al margen.
;  Generado desde herramientas/ascii_a_nasm.py (el texto del dibujo está ahí).
; =============================================================================
caballo:
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
    db 1, C(VERDE), ",", 2, ".,", 2, "' , .", 2, ",", 2, "., '", 2, ",", 2, ". ,", 2, ".,", 2, "' ,", C(GRIS), 0
