/*
 * kernel.c - Guía 1, Fase 3: kernel mínimo freestanding (C11, i386)
 *
 * Flujo:
 *   1. Comprueba que lo cargó un cargador Multiboot2 (magic en EAX).
 *   2. Recorre las etiquetas de información: cargador, framebuffer y módulo.
 *   3. Valida dirección, dimensiones, pitch y formato del framebuffer ANTES
 *      de escribir en la memoria de video.
 *   4. Muestra un patrón de prueba de colores durante ~2 segundos.
 *   5. Valida el módulo de imagen (formato IMG1) y lo dibuja escalado.
 * Todo el proceso queda registrado por el puerto serie COM1.
 */
#include <stddef.h>
#include <stdint.h>
#include "multiboot2.h"
#include "pantalla.h"
#include "puertos.h"
#include "serie.h"

/* Formato IMG1 que genera assets/converted/png_a_img.py */
#define IMG_MAGIA       0x31474D49u     /* "IMG1" en little endian */
#define IMG_MAX_LADO    1024

struct img_cabecera {
    uint32_t magia;
    uint32_t ancho;
    uint32_t alto;
    uint32_t bytes_pixel;               /* 3 = R, G, B */
};

/* GCC puede emitir llamadas a estas funciones aun en modo freestanding */
void *memset(void *d, int v, size_t n)
{
    uint8_t *p = d;
    while (n--)
        *p++ = (uint8_t)v;
    return d;
}

void *memcpy(void *d, const void *s, size_t n)
{
    uint8_t *p = d;
    const uint8_t *q = s;
    while (n--)
        *p++ = *q++;
    return d;
}

/* ---------------------------------------------------------------------------
 * Utilidades de texto
 * ------------------------------------------------------------------------ */
static char *agregar(char *d, const char *s)
{
    while (*s)
        *d++ = *s++;
    *d = '\0';
    return d;
}

static char *agregar_num(char *d, uint32_t v)
{
    char buf[11];
    int i = 0;
    do {
        buf[i++] = (char)('0' + v % 10);
        v /= 10;
    } while (v);
    while (i)
        *d++ = buf[--i];
    *d = '\0';
    return d;
}

/* ---------------------------------------------------------------------------
 * Validaciones
 * ------------------------------------------------------------------------ */
static int mascara_valida(uint8_t pos, uint8_t bits, uint8_t bpp)
{
    return bits >= 1 && bits <= 8 && pos + bits <= bpp;
}

static const char *validar_framebuffer(const struct mb2_tag_framebuffer *fb)
{
    if (fb->tipo_fb != MB2_FB_RGB)
        return "EL FRAMEBUFFER NO ES RGB DIRECTO";
    if (fb->tamano < sizeof(*fb))
        return "ETIQUETA DE FRAMEBUFFER INCOMPLETA";
    if (fb->bpp != 24 && fb->bpp != 32)
        return "PROFUNDIDAD DE COLOR NO SOPORTADA";
    if (fb->direccion == 0 || fb->direccion > 0xFFFFFFFFull)
        return "DIRECCION DE FRAMEBUFFER INVALIDA";
    if (fb->ancho < 320 || fb->alto < 200 || fb->ancho > 4096 || fb->alto > 4096)
        return "DIMENSIONES FUERA DE RANGO";
    if (fb->pitch < fb->ancho * (fb->bpp / 8u))
        return "PITCH MENOR QUE ANCHO X BYTES POR PIXEL";
    if (fb->direccion + (uint64_t)fb->pitch * fb->alto > 0x100000000ull)
        return "FRAMEBUFFER EXCEDE EL ESPACIO DE 32 BITS";
    if (!mascara_valida(fb->rojo_pos, fb->rojo_bits, fb->bpp) ||
        !mascara_valida(fb->verde_pos, fb->verde_bits, fb->bpp) ||
        !mascara_valida(fb->azul_pos, fb->azul_bits, fb->bpp))
        return "MASCARAS DE COLOR INVALIDAS";
    return NULL;
}

static const char *validar_imagen(const struct mb2_tag_modulo *mod)
{
    if (!mod)
        return "EL CARGADOR NO ENTREGO EL MODULO DE IMAGEN";
    uint32_t tamano = mod->fin - mod->inicio;
    const struct img_cabecera *img = (const struct img_cabecera *)(uintptr_t)mod->inicio;
    if (mod->fin <= mod->inicio || tamano < sizeof(*img))
        return "MODULO DE IMAGEN VACIO";
    if (img->magia != IMG_MAGIA)
        return "FIRMA IMG1 NO ENCONTRADA";
    if (img->bytes_pixel != 3)
        return "FORMATO DE PIXEL NO SOPORTADO (SE ESPERA RGB888)";
    if (img->ancho == 0 || img->alto == 0 || img->ancho > IMG_MAX_LADO || img->alto > IMG_MAX_LADO)
        return "DIMENSIONES DE IMAGEN FUERA DE RANGO";
    if (tamano != sizeof(*img) + img->ancho * img->alto * 3)
        return "TAMANO DEL MODULO NO COINCIDE CON LA CABECERA";
    if (img->ancho > pantalla_ancho() || img->alto > pantalla_alto())
        return "LA IMAGEN NO CABE EN LA PANTALLA";
    return NULL;
}

/* ---------------------------------------------------------------------------
 * Esperas con el reloj de tiempo real (CMOS)
 * ------------------------------------------------------------------------ */
static uint8_t rtc_segundos(void)
{
    outb(0x70, 0x00);
    return inb(0x71);
}

static void esperar_segundos(int n)
{
    uint8_t s = rtc_segundos();
    while (n > 0) {
        uint8_t t = rtc_segundos();
        if (t != s) {
            s = t;
            n--;
        }
    }
}

/* ---------------------------------------------------------------------------
 * Pantallas
 * ------------------------------------------------------------------------ */
static void patron_de_prueba(void)
{
    static const uint8_t barras[8][3] = {
        {255, 255, 255}, {255, 255, 0}, {0, 255, 255}, {0, 255, 0},
        {255, 0, 255},   {255, 0, 0},   {0, 0, 255},   {0, 0, 0},
    };
    uint32_t w = pantalla_ancho(), h = pantalla_alto();
    pantalla_rect(0, 0, w, h, pantalla_color(20, 20, 60));  /* color uniforme */
    for (uint32_t i = 0; i < 8; i++)
        pantalla_rect(i * w / 8, h / 6, w / 8 + 1, h / 2,
                      pantalla_color(barras[i][0], barras[i][1], barras[i][2]));
    pantalla_texto(20, 20, "PATRON DE PRUEBA: BLANCO AMARILLO CIAN VERDE MAGENTA ROJO AZUL NEGRO",
                   1, pantalla_color(255, 255, 255));
    pantalla_texto(20, h * 3 / 4, "FRAMEBUFFER VALIDADO - CARGANDO IMAGEN...", 2,
                   pantalla_color(255, 255, 255));
}

static void pantalla_error(const char *motivo)
{
    uint32_t w = pantalla_ancho(), h = pantalla_alto();
    pantalla_rect(0, 0, w, h, pantalla_color(110, 0, 0));
    pantalla_texto(30, h / 2 - 40, "ERROR DEL KERNEL (FASE 3)", 3, pantalla_color(255, 255, 255));
    pantalla_texto(30, h / 2 + 10, motivo, 2, pantalla_color(255, 220, 120));
    pantalla_texto(30, h / 2 + 50, "SISTEMA DETENIDO DE FORMA CONTROLADA", 2,
                   pantalla_color(255, 255, 255));
}

static void dibujar_imagen(const struct img_cabecera *img,
                           const struct mb2_tag_framebuffer *fb, const char *cargador)
{
    uint32_t w = pantalla_ancho(), h = pantalla_alto();

    /* Fondo: degradado vertical */
    for (uint32_t y = 0; y < h; y++)
        pantalla_rect(0, y, w, 1, pantalla_color(10, (uint8_t)(10 + 30 * y / h),
                                                 (uint8_t)(40 + 60 * y / h)));

    /* Escala entera máxima que deja espacio al panel inferior */
    uint32_t panel = 110;
    uint32_t escala = (w - 40) / img->ancho;
    if ((h - panel - 20) / img->alto < escala)
        escala = (h - panel - 20) / img->alto;
    if (escala == 0)
        escala = 1;
    uint32_t x0 = (w - img->ancho * escala) / 2;
    uint32_t y0 = 15;

    /* Marco y píxeles: el arreglo está en orden fila a fila, de arriba abajo */
    pantalla_rect(x0 - 4, y0 - 4, img->ancho * escala + 8, img->alto * escala + 8,
                  pantalla_color(230, 230, 240));
    const uint8_t *px = (const uint8_t *)(img + 1);
    for (uint32_t y = 0; y < img->alto; y++)
        for (uint32_t x = 0; x < img->ancho; x++, px += 3)
            pantalla_rect(x0 + x * escala, y0 + y * escala, escala, escala,
                          pantalla_color(px[0], px[1], px[2]));

    /* Panel con los parámetros realmente recibidos */
    char l1[96], l2[96], *p;
    p = agregar(l1, "FB ");
    p = agregar_num(p, fb->ancho);  p = agregar(p, "X");
    p = agregar_num(p, fb->alto);   p = agregar(p, "  PITCH ");
    p = agregar_num(p, fb->pitch);  p = agregar(p, "  ");
    p = agregar_num(p, fb->bpp);
    agregar(p, " BPP RGB - VALIDADO");

    p = agregar(l2, "IMAGEN ");
    p = agregar_num(p, img->ancho); p = agregar(p, "X");
    p = agregar_num(p, img->alto);  p = agregar(p, " RGB888  ESCALA X");
    p = agregar_num(p, escala);     p = agregar(p, "  CARGADOR: ");
    agregar(p, cargador);

    uint32_t yp = h - panel + 10;
    pantalla_rect(0, yp - 10, w, panel, pantalla_color(15, 15, 30));
    pantalla_texto(20, yp, "MICRO S.O. FASE 3 - KERNEL C FREESTANDING (I386, MULTIBOOT2)", 2,
                   pantalla_color(120, 255, 140));
    pantalla_texto(20, yp + 30, l1, 2, pantalla_color(255, 255, 255));
    pantalla_texto(20, yp + 60, l2, 2, pantalla_color(255, 255, 255));
}

/*
 * Si el cargador entregó un framebuffer de texto EGA (por ejemplo con
 * gfxpayload=text), no se dibuja la imagen: se valida ese modo y se informa
 * el motivo en pantalla con caracteres de texto.
 */
static void informar_en_texto(const struct mb2_tag_framebuffer *fb, const char *motivo)
{
    if (fb->tipo_fb != MB2_FB_TEXTO_EGA || fb->direccion != 0xB8000 || fb->bpp != 16 ||
        fb->ancho == 0 || fb->ancho > 132 || fb->alto < 6 || fb->alto > 60 ||
        fb->pitch < fb->ancho * 2) {
        serie_printf("[kernel] tampoco es un modo texto EGA valido: solo registro serie\n");
        return;
    }
    static const char *lineas[] = {
        "Micro S.O. Fase 3 - kernel C freestanding",
        "",
        "El cargador entrego un framebuffer de TEXTO EGA (tipo 2):",
        "", /* motivo */
        "Este kernel requiere un framebuffer RGB directo de 24 o 32 bpp,",
        "por lo que NO dibuja la imagen. Sistema detenido de forma controlada.",
    };
    volatile uint16_t *vga = (volatile uint16_t *)0xB8000;
    for (uint32_t i = 0; i < fb->alto * (fb->pitch / 2); i++)
        vga[i] = 0x1F00 | ' ';
    for (uint32_t f = 0; f < 6; f++) {
        const char *s = (f == 3) ? motivo : lineas[f];
        for (uint32_t c = 0; s[c] && c + 2 < fb->ancho; c++)
            vga[(f + 2) * (fb->pitch / 2) + c + 2] = (uint16_t)((f == 3 ? 0x1E00 : 0x1F00) | (uint8_t)s[c]);
    }
}

/* ---------------------------------------------------------------------------
 * Punto de entrada (llamado desde _start en boot_f3.asm)
 * ------------------------------------------------------------------------ */
void kmain(uint32_t magia, uint32_t dir_info)
{
    serie_iniciar();
    serie_printf("\n[kernel] Micro S.O. Fase 3: kernel C freestanding i386 en ejecucion\n");

    if (magia != MB2_MAGIC_CARGADOR) {
        serie_printf("[kernel] ERROR: magic 0x%x, se esperaba 0x%x\n", magia, MB2_MAGIC_CARGADOR);
        detener();
    }
    if (dir_info == 0 || (dir_info & 7)) {
        serie_printf("[kernel] ERROR: informacion Multiboot2 no alineada (0x%x)\n", dir_info);
        detener();
    }

    const struct mb2_info *info = (const struct mb2_info *)(uintptr_t)dir_info;
    const struct mb2_tag_framebuffer *fb = NULL;
    const struct mb2_tag_modulo *modulo = NULL;
    const char *cargador = "DESCONOCIDO";

    serie_printf("[kernel] info Multiboot2 en 0x%x, %u bytes\n", dir_info, info->tamano_total);
    const uint8_t *fin = (const uint8_t *)info + info->tamano_total;
    for (const struct mb2_tag *t = (const struct mb2_tag *)(info + 1);
         (const uint8_t *)t + sizeof(*t) <= fin && t->tipo != MB2_TAG_FIN && t->tamano >= 8;
         t = (const struct mb2_tag *)((const uint8_t *)t + ((t->tamano + 7) & ~7u))) {
        switch (t->tipo) {
        case MB2_TAG_CARGADOR:
            cargador = ((const struct mb2_tag_cadena *)t)->texto;
            break;
        case MB2_TAG_FRAMEBUFFER:
            fb = (const struct mb2_tag_framebuffer *)t;
            break;
        case MB2_TAG_MODULO:
            if (!modulo)
                modulo = (const struct mb2_tag_modulo *)t;
            break;
        }
    }
    serie_printf("[kernel] cargador: %s\n", cargador);
    if (modulo)
        serie_printf("[kernel] modulo '%s' en 0x%x-0x%x (%u bytes)\n", modulo->cmdline,
                     modulo->inicio, modulo->fin, modulo->fin - modulo->inicio);
    else
        serie_printf("[kernel] sin modulos\n");

    if (!fb) {
        serie_printf("[kernel] ERROR: el cargador no entrego framebuffer; no se escribe en video\n");
        detener();
    }
    serie_printf("[kernel] framebuffer: dir 0x%x, %ux%u, pitch %u, %u bpp, tipo %u\n",
                 (uint32_t)fb->direccion, fb->ancho, fb->alto, fb->pitch, fb->bpp, fb->tipo_fb);
    if (fb->tipo_fb == MB2_FB_RGB)
        serie_printf("[kernel] mascaras: R pos %u/%u bits, G %u/%u, B %u/%u\n",
                     fb->rojo_pos, fb->rojo_bits, fb->verde_pos, fb->verde_bits,
                     fb->azul_pos, fb->azul_bits);

    const char *error = validar_framebuffer(fb);
    if (error) {
        serie_printf("[kernel] ERROR framebuffer: %s\n", error);
        informar_en_texto(fb, error);
        serie_printf("[kernel] sistema detenido\n");
        detener();
    }
    serie_printf("[kernel] framebuffer validado\n");

    pantalla_iniciar(fb);
    patron_de_prueba();
    serie_printf("[kernel] patron de prueba dibujado\n");
    esperar_segundos(2);

    error = validar_imagen(modulo);
    if (error) {
        serie_printf("[kernel] ERROR imagen: %s\n", error);
        pantalla_error(error);
        serie_printf("[kernel] sistema detenido\n");
        detener();
    }
    const struct img_cabecera *img = (const struct img_cabecera *)(uintptr_t)modulo->inicio;
    serie_printf("[kernel] imagen IMG1 validada: %ux%u, %u bytes por pixel\n",
                 img->ancho, img->alto, img->bytes_pixel);

    dibujar_imagen(img, fb, cargador);
    serie_printf("[kernel] imagen desplegada; sistema detenido\n");
    detener();
}
