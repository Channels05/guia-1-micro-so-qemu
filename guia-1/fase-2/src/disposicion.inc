; =============================================================================
;  disposicion.inc - Mapa de la imagen de disco e interfaz entre etapas
;  (única fuente de verdad: la incluyen ambas etapas y la lee scripts/build.sh)
;
;  Imagen: disquete de 1,44 MB = 2880 sectores de 512 bytes
;          geometría CHS 80 cilindros x 2 cabezas x 18 sectores por pista
;
;    LBA 0          CHS 0/0/1        etapa 1  (boot_f2.bin, 512 B, firma AA55)
;    LBA 1..16      CHS 0/0/2..17    etapa 2  (etapa2_f2.bin, 16 sectores
;                                              = 8 KiB reservados)
;    LBA 17..2879   resto            sin uso (ceros)
;
;  Interfaz etapa 1 -> etapa 2:
;    - la etapa 2 se carga en ETAPA2_SEG:ETAPA2_OFF (0000:8000)
;    - sus 4 primeros bytes son la firma ETAPA2_FIRMA ("ETP2"); la etapa 1 la
;      comprueba antes de saltar y, si no coincide, muestra un error
;    - el punto de entrada es ETAPA2_OFF + 4
;    - estado de la CPU al entrar: modo real 16 bits, CS = DS = ES = SS = 0,
;      SP = 0x7C00, interrupciones habilitadas, DL = unidad de arranque (BIOS)
; =============================================================================

ETAPA2_LBA       equ 1
ETAPA2_SECTORES  equ 16
ETAPA2_SEG       equ 0x0000
ETAPA2_OFF       equ 0x8000
ETAPA2_FIRMA     equ 'ETP2'

SECTORES_PISTA   equ 18

; La etapa 1 lee con una única llamada CHS (cilindro 0, cabeza 0), así que la
; etapa 2 debe caber en la primera pista.
%if ETAPA2_LBA + ETAPA2_SECTORES > SECTORES_PISTA
    %error "La etapa 2 no cabe en la primera pista del disquete"
%endif
