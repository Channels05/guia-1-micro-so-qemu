#!/usr/bin/env python3
"""Convierte un PNG (8 bits, RGB o RGBA, sin entrelazado) al formato IMG1.

Un PNG está comprimido con DEFLATE y filtrado por fila, así que sus bytes no
son píxeles de framebuffer. Este script lo decodifica con la biblioteca
estándar (zlib) y escribe píxeles sin compresión que el kernel lee directo:

    desplazamiento  tamaño  contenido
    0               4       firma "IMG1"
    4               4       ancho  (uint32 little endian)
    8               4       alto   (uint32 little endian)
    12              4       bytes por píxel = 3
    16              w*h*3   píxeles R, G, B; filas de arriba hacia abajo,
                            cada fila de izquierda a derecha

El canal alfa, si existe, se descarta (se compone sobre negro).

Uso:  python3 png_a_img.py entrada.png salida.img
"""
import struct
import sys
import zlib


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def leer_png(ruta):
    with open(ruta, "rb") as f:
        datos = f.read()
    if datos[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"{ruta}: no es un PNG")
    pos, idat = 8, b""
    while pos < len(datos):
        largo, tipo = struct.unpack(">I4s", datos[pos:pos + 8])
        cuerpo = datos[pos + 8:pos + 8 + largo]
        if tipo == b"IHDR":
            ancho, alto, prof, color, _, _, entrelazado = struct.unpack(">IIBBBBB", cuerpo)
        elif tipo == b"IDAT":
            idat += cuerpo
        elif tipo == b"IEND":
            break
        pos += 12 + largo
    if prof != 8 or color not in (2, 6) or entrelazado:
        sys.exit("Solo se admite PNG de 8 bits por canal, RGB o RGBA, sin entrelazado")
    canales = 3 if color == 2 else 4

    crudo = zlib.decompress(idat)
    paso = ancho * canales
    filas, anterior, i = [], bytearray(paso), 0
    for _ in range(alto):
        filtro = crudo[i]
        fila = bytearray(crudo[i + 1:i + 1 + paso])
        i += 1 + paso
        for x in range(paso):
            a = fila[x - canales] if x >= canales else 0
            b = anterior[x]
            c = anterior[x - canales] if x >= canales else 0
            if filtro == 1:
                fila[x] = (fila[x] + a) & 0xFF
            elif filtro == 2:
                fila[x] = (fila[x] + b) & 0xFF
            elif filtro == 3:
                fila[x] = (fila[x] + (a + b) // 2) & 0xFF
            elif filtro == 4:
                fila[x] = (fila[x] + paeth(a, b, c)) & 0xFF
        filas.append(fila)
        anterior = fila
    return ancho, alto, canales, filas


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    ancho, alto, canales, filas = leer_png(sys.argv[1])
    pixeles = bytearray()
    for fila in filas:
        for x in range(ancho):
            px = fila[x * canales:(x + 1) * canales]
            if canales == 4:
                alfa = px[3] / 255
                px = bytes(int(v * alfa) for v in px[:3])
            pixeles += px[:3]
    with open(sys.argv[2], "wb") as f:
        f.write(b"IMG1" + struct.pack("<III", ancho, alto, 3) + pixeles)
    print(f"{sys.argv[2]}: IMG1 {ancho}x{alto}, RGB888, {16 + len(pixeles)} bytes "
          f"(origen PNG {canales} canales)")


if __name__ == "__main__":
    main()
