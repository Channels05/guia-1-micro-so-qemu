/* puertos.h - Acceso a puertos de E/S x86 y utilidades sin biblioteca estándar */
#ifndef PUERTOS_H
#define PUERTOS_H

#include <stdint.h>

static inline void outb(uint16_t puerto, uint8_t valor)
{
    __asm__ volatile ("outb %0, %1" : : "a"(valor), "Nd"(puerto));
}

static inline uint8_t inb(uint16_t puerto)
{
    uint8_t valor;
    __asm__ volatile ("inb %1, %0" : "=a"(valor) : "Nd"(puerto));
    return valor;
}

static inline void detener(void)
{
    for (;;)
        __asm__ volatile ("cli; hlt");
}

#endif
