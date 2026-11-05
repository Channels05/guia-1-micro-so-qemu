/* pantalla.h - Dibujo sobre el framebuffer lineal ya validado */
#ifndef PANTALLA_H
#define PANTALLA_H

#include <stdint.h>
#include "multiboot2.h"

/* Requiere un framebuffer RGB de 24/32 bpp validado por kernel.c */
void     pantalla_iniciar(const struct mb2_tag_framebuffer *fb);
uint32_t pantalla_ancho(void);
uint32_t pantalla_alto(void);

/* Convierte R, G, B de 8 bits al formato de píxel informado por el cargador */
uint32_t pantalla_color(uint8_t r, uint8_t g, uint8_t b);

void pantalla_pixel(uint32_t x, uint32_t y, uint32_t color);
void pantalla_rect(uint32_t x, uint32_t y, uint32_t w, uint32_t h, uint32_t color);
/* Texto con fuente 5x7 (mayúsculas, dígitos y algunos signos) */
void pantalla_texto(uint32_t x, uint32_t y, const char *s, uint32_t escala, uint32_t color);

#endif
