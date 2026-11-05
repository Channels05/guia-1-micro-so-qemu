#!/usr/bin/env python3
"""Genera la imagen original de la Fase 3: caballo_f3.png (200x150, RGB 8 bits).

Ilustración propia: un caballo al galope dibujado con puntos brillantes, como
una matriz de caracteres encendidos, sobre un atardecer y un potrero
difuminados. La silueta del caballo es la misma que se usó para el dibujo
ASCII de las fases 1 y 2 (función dentro()). Usa solo la biblioteca estándar
de Python (zlib + struct) para escribir el PNG, así que es reproducible sin
dependencias externas.

Uso:  python3 generar_imagen.py [salida.png]
"""
import math
import os
import struct
import sys
import zlib

ANCHO, ALTO = 200, 150
HORIZONTE = 92

# --- Silueta del caballo (mira a la derecha), en coordenadas de 200x150 -------
ELIPSES = [  # cx, cy, rx, ry
    (95, 68, 40, 16),    # cuerpo
    (95, 74, 30, 12),    # vientre
    (126, 66, 15, 15),   # pecho
    (62, 64, 17, 17),    # grupa
]
CAPSULAS = [  # ax, ay, bx, by, radio inicial, radio final
    (124, 60, 146, 36, 12, 8),      # cuello
    (146, 34, 166, 48, 7, 4.5),     # cabeza
    (150, 40, 160, 50, 6, 4),       # mandíbula
    (143, 30, 141, 22, 2.5, 1),     # oreja
    (48, 58, 30, 56, 5, 4),         # cola
    (30, 56, 16, 64, 4, 3),
    (16, 64, 8, 76, 3, 1.5),
    (130, 76, 146, 88, 6, 4),       # mano delantera estirada
    (146, 88, 162, 86, 3.5, 3),
    (162, 86, 167, 89, 3, 3),
    (120, 78, 124, 96, 6, 4),       # mano delantera recogida
    (124, 96, 116, 106, 3.5, 3),
    (55, 72, 40, 90, 8, 4.5),       # pata trasera estirada
    (40, 90, 24, 98, 3.5, 3),
    (70, 76, 82, 92, 7, 4),         # pata trasera bajo el vientre
    (82, 92, 80, 110, 3.5, 3),
]


def _capsula(x, y, ax, ay, bx, by, ra, rb):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
    r = ra + (rb - ra) * t
    return math.hypot(x - (ax + dx * t), y - (ay + dy * t)) <= r


def dentro(x, y, dx=0, dy=0):
    """True si el punto (x, y) cae dentro de la silueta desplazada en (dx, dy)."""
    x, y = x - dx, y - dy
    for cx, cy, rx, ry in ELIPSES:
        if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
            return True
    return any(_capsula(x, y, *c) for c in CAPSULAS)


# --- Utilidades -----------------------------------------------------------------
def mezcla(a, b, t):
    t = max(0.0, min(1.0, t))
    return [a[i] + (b[i] - a[i]) * t for i in range(3)]


def ruido(x, y, semilla):
    """Ruido suave y determinista: suma de senos (sin azar real)."""
    return (math.sin(x * 0.045 + semilla) * math.cos(y * 0.07 + semilla * 1.7)
            + 0.5 * math.sin(x * 0.11 + y * 0.05 + semilla * 3.1))


def hash01(i, j):
    """Valor pseudoaleatorio fijo en [0, 1) para la celda (i, j)."""
    h = (i * 73856093) ^ (j * 19349663) ^ 0x5F3759DF
    h = (h * 1103515245 + 12345) & 0x7FFFFFFF
    return (h % 10000) / 10000


def generar():
    img = [[[0.0, 0.0, 0.0] for _ in range(ANCHO)] for _ in range(ALTO)]

    # Cielo de atardecer con nubes difusas
    for y in range(HORIZONTE):
        base = mezcla((52, 70, 104), (150, 160, 168), y / HORIZONTE)
        for x in range(ANCHO):
            nube = max(0.0, ruido(x, y, 1.3)) * 0.35 * (1 - y / HORIZONTE * 0.6)
            img[y][x] = mezcla(base, (205, 210, 205), nube)

    # Potrero: pasto difuminado que se oscurece hacia abajo
    for y in range(HORIZONTE, ALTO):
        t = (y - HORIZONTE) / (ALTO - HORIZONTE)
        base = mezcla((112, 112, 70), (60, 58, 34), t)
        for x in range(ANCHO):
            img[y][x] = mezcla(base, (140, 130, 80), max(0.0, ruido(x, y, 4.2)) * 0.3)
    for x in range(ANCHO):                          # línea de árboles lejanos
        h = 6 + 3 * math.sin(x * 0.09) + 2 * math.sin(x * 0.23 + 1)
        for y in range(int(HORIZONTE - h), HORIZONTE):
            img[y][x] = mezcla(img[y][x], (55, 62, 45), 0.7)

    # El caballo se desplaza para quedar centrado en el cuadro
    DX, DY = 12, 0

    def caballo(x, y):
        return dentro(x, y, DX, DY)

    # Cuerpo oscuro del caballo, con bordes suaves (cobertura 3x3 por píxel)
    for y in range(10, 125):
        for x in range(0, ANCHO):
            cob = sum(caballo(x + sx / 3, y + sy / 3) for sx in range(3) for sy in range(3)) / 9
            if cob:
                img[y][x] = mezcla(img[y][x], (38, 32, 30), cob * 0.75)

    # Matriz de puntos brillantes: celdas de 3x3 px sobre la silueta
    PASO = 3
    for j in range(10 // PASO, 125 // PASO):
        for i in range(0, ANCHO // PASO):
            cx, cy = i * PASO + 1, j * PASO + 1
            if not caballo(cx, cy):
                continue
            borde = any(not caballo(cx + sx * PASO, cy + sy * PASO)
                        for sx in (-1, 0, 1) for sy in (-1, 0, 1))
            if not (borde or hash01(i, j) < 0.22):
                continue
            # punto: centro y un trazo horizontal, como un carácter encendido
            largo = 2 if hash01(j, i) < 0.5 else 1
            for sx in range(largo):
                x, y = cx + sx, cy
                if x < ANCHO:
                    img[y][x] = mezcla(img[y][x], (255, 244, 210), 1.0)
            for gx in range(-2, largo + 2):         # halo
                for gy in range(-2, 3):
                    x, y = cx + gx, cy + gy
                    if 0 <= x < ANCHO and 0 <= y < ALTO and not (0 <= gx < largo and gy == 0):
                        d = math.hypot(max(0, gx - largo + 1) if gx > 0 else gx, gy)
                        img[y][x] = mezcla(img[y][x], (255, 225, 160), 0.32 / (1 + d * d))

    return img


def escribir_png(img, salida):
    def fragmento(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos +
                struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    crudo = b"".join(b"\x00" + bytes(max(0, min(255, int(v))) for px in fila for v in px)
                     for fila in img)
    png = (b"\x89PNG\r\n\x1a\n" +
           fragmento(b"IHDR", struct.pack(">IIBBBBB", ANCHO, ALTO, 8, 2, 0, 0, 0)) +
           fragmento(b"IDAT", zlib.compress(crudo, 9)) +
           fragmento(b"IEND", b""))
    with open(salida, "wb") as f:
        f.write(png)
    print(f"{salida}: {ANCHO}x{ALTO}, RGB 8 bits por canal, {len(png)} bytes")


if __name__ == "__main__":
    destino = sys.argv[1] if len(sys.argv) > 1 else \
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "caballo_f3.png")
    escribir_png(generar(), destino)
