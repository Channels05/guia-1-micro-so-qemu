/* serie.c - Salida de texto por COM1 (UART 16550 en 0x3F8) */
#include <stdarg.h>
#include <stdint.h>
#include "puertos.h"
#include "serie.h"

#define COM1 0x3F8

void serie_iniciar(void)
{
    outb(COM1 + 1, 0x00);       /* sin interrupciones */
    outb(COM1 + 3, 0x80);       /* DLAB = 1 para fijar la velocidad */
    outb(COM1 + 0, 0x03);       /* divisor 3 -> 38400 baudios */
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x03);       /* 8 bits, sin paridad, 1 bit de parada */
    outb(COM1 + 2, 0xC7);       /* FIFO habilitada */
}

static void poner(char c)
{
    if (c == '\n')
        poner('\r');
    while (!(inb(COM1 + 5) & 0x20))
        ;                       /* esperar registro de transmisión libre */
    outb(COM1, (uint8_t)c);
}

static void numero(uint32_t v, uint32_t base)
{
    char buf[11];
    int i = 0;
    do {
        uint32_t d = v % base;
        buf[i++] = (char)(d < 10 ? '0' + d : 'A' + d - 10);
        v /= base;
    } while (v);
    while (i)
        poner(buf[--i]);
}

void serie_printf(const char *f, ...)
{
    va_list ap;
    va_start(ap, f);
    for (; *f; f++) {
        if (*f != '%') {
            poner(*f);
            continue;
        }
        switch (*++f) {
        case 's': { const char *s = va_arg(ap, const char *); while (*s) poner(*s++); break; }
        case 'u': numero(va_arg(ap, uint32_t), 10); break;
        case 'x': numero(va_arg(ap, uint32_t), 16); break;
        case 'c': poner((char)va_arg(ap, int)); break;
        case '%': poner('%'); break;
        default:  return;
        }
    }
    va_end(ap);
}
