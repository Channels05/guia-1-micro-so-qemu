/* serie.h - Registro por el puerto serie COM1 (QEMU: -serial stdio/file) */
#ifndef SERIE_H
#define SERIE_H

void serie_iniciar(void);
/* Formatos admitidos: %s %u %x %c %% */
void serie_printf(const char *formato, ...);

#endif
