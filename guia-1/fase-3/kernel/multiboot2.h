/*
 * multiboot2.h - Subconjunto de la especificación Multiboot2 que usa el kernel
 * https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html
 */
#ifndef MULTIBOOT2_H
#define MULTIBOOT2_H

#include <stdint.h>

#define MB2_MAGIC_CARGADOR      0x36D76289u

#define MB2_TAG_FIN             0
#define MB2_TAG_CMDLINE         1
#define MB2_TAG_CARGADOR        2
#define MB2_TAG_MODULO          3
#define MB2_TAG_FRAMEBUFFER     8

#define MB2_FB_INDEXADO         0
#define MB2_FB_RGB              1
#define MB2_FB_TEXTO_EGA        2

/* Cabecera de la estructura que GRUB deja en EBX */
struct mb2_info {
    uint32_t tamano_total;
    uint32_t reservado;
};

/* Todas las etiquetas empiezan así y están alineadas a 8 bytes */
struct mb2_tag {
    uint32_t tipo;
    uint32_t tamano;
};

struct mb2_tag_cadena {             /* tipos 1 y 2 */
    uint32_t tipo;
    uint32_t tamano;
    char texto[];
};

struct mb2_tag_modulo {             /* tipo 3 */
    uint32_t tipo;
    uint32_t tamano;
    uint32_t inicio;
    uint32_t fin;
    char cmdline[];
};

struct mb2_tag_framebuffer {        /* tipo 8 */
    uint32_t tipo;
    uint32_t tamano;
    uint64_t direccion;
    uint32_t pitch;                 /* bytes por fila */
    uint32_t ancho;
    uint32_t alto;
    uint8_t  bpp;                   /* bits por píxel */
    uint8_t  tipo_fb;               /* MB2_FB_* */
    uint16_t reservado;
    /* Solo válidos si tipo_fb == MB2_FB_RGB */
    uint8_t  rojo_pos;
    uint8_t  rojo_bits;
    uint8_t  verde_pos;
    uint8_t  verde_bits;
    uint8_t  azul_pos;
    uint8_t  azul_bits;
} __attribute__((packed));

#endif
